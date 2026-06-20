"""
AudioCaptureEngine  unified audio feed for all three source types.

All paths push chunks of exactly AUDIO_CHUNK_SAMPLES int16 samples
(as raw bytes) to audio_queue.  This matches the sounddevice InputStream
blocksize exactly, so the distress model receives identically-shaped
tensors regardless of whether the source is a microphone, IP webcam,
or an uploaded video file.

Chunk format (same for every path):
  dtype : int16, little-endian
  shape : (AUDIO_CHUNK_SAMPLES,)  =  (32000,)  =  2.0 s at 16 kHz
  bytes : chunk.tobytes()         =  64 000 bytes per chunk
"""

import queue
import subprocess
import threading
import time
import traceback

import numpy as np
import requests

# Single source of truth for chunk size  must match mic blocksize
try:
    import sys, os
    sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))
    from utils.config import AUDIO_CHUNK_SAMPLES, AUDIO_SAMPLE_RATE
except Exception:
    AUDIO_CHUNK_SAMPLES = 32000  # 2.0 s at 16 kHz
    AUDIO_SAMPLE_RATE = 16000


class AudioCaptureEngine:
    def __init__(self, audio_queue):
        """
        audio_queue: multiprocessing.Queue shared with the ML worker.
                     Receives raw int16 PCM chunks of AUDIO_CHUNK_SAMPLES samples.
        """
        self.audio_queue = audio_queue
        self.is_running = False
        self.thread = None
        self.source = None

    # ------------------------------------------------------------------
    # Public API
    # ------------------------------------------------------------------

    def start(self, source="0"):
        if self.is_running:
            self.stop()
        self.is_running = True
        self.source = source
        self.thread = threading.Thread(target=self._run_capture, daemon=True)
        self.thread.start()
        print(f" AudioCaptureEngine started for source: {source}")

    def stop(self):
        self.is_running = False
        if self.thread and self.thread.is_alive():
            self.thread.join(timeout=2.0)
        print(" AudioCaptureEngine stopped")

    # ------------------------------------------------------------------
    # Internal dispatch
    # ------------------------------------------------------------------

    def _run_capture(self):
        src = str(self.source)

        if src.isdigit():
            self._capture_microphone()
        elif "http" in src:
            self._capture_ip_webcam()
        else:
            self._capture_video_file()

    # ------------------------------------------------------------------
    # Path 1  Hardware microphone via sounddevice
    # ------------------------------------------------------------------

    def _capture_microphone(self):
        try:
            import sounddevice as sd

            def callback(indata, frames, time_info, status):
                if not self.is_running:
                    raise sd.CallbackStop()
                # indata is already int16 (blocksize=AUDIO_CHUNK_SAMPLES samples)
                try:
                    self.audio_queue.put_nowait(indata.tobytes())
                except queue.Full:
                    pass

            with sd.InputStream(
                samplerate=AUDIO_SAMPLE_RATE,
                channels=1,
                dtype="int16",
                callback=callback,
                blocksize=AUDIO_CHUNK_SAMPLES,   #  exact same as video path
            ):
                while self.is_running:
                    time.sleep(0.05)

        except Exception as e:
            print(f" AudioCaptureEngine (mic) failed: {e}")
            traceback.print_exc()

    # ------------------------------------------------------------------
    # Path 2  IP Webcam audio stream
    # ------------------------------------------------------------------

    def _capture_ip_webcam(self):
        import urllib.parse

        parsed = urllib.parse.urlparse(self.source)
        base_url = f"{parsed.scheme}://{parsed.netloc}/audio.wav"
        chunk_bytes = AUDIO_CHUNK_SAMPLES * 2  # 2 bytes per int16 sample

        _MAX_RETRIES = 10        # give up after this many consecutive failures
        _MAX_BACKOFF  = 60.0     # cap back-off at 60 s

        consecutive_failures = 0
        backoff = 1.0

        while self.is_running:
            try:
                with requests.get(base_url, stream=True, timeout=5) as r:
                    r.raise_for_status()
                    consecutive_failures = 0   # reset on successful connection
                    backoff = 1.0
                    print(f" AudioCaptureEngine (IP cam) connected to {base_url}")
                    for chunk in r.iter_content(chunk_size=chunk_bytes):
                        if not self.is_running:
                            return
                        if chunk:
                            try:
                                self.audio_queue.put_nowait(chunk)
                            except queue.Full:
                                pass

            except (requests.exceptions.ConnectTimeout,
                    requests.exceptions.ConnectionError) as e:
                # Camera is unreachable  print ONE clean line, no stack trace
                consecutive_failures += 1
                if consecutive_failures >= _MAX_RETRIES:
                    print(
                        f" AudioCaptureEngine (IP cam): {_MAX_RETRIES} consecutive"
                        f" connection failures  giving up on {base_url}"
                    )
                    return
                print(
                    f" AudioCaptureEngine (IP cam): camera unreachable"
                    f" ({consecutive_failures}/{_MAX_RETRIES}), retrying in {backoff:.0f}s "
                )
                time.sleep(backoff)
                backoff = min(backoff * 2, _MAX_BACKOFF)

            except Exception as e:
                # Unexpected error  log once with trace and back off
                consecutive_failures += 1
                print(f" AudioCaptureEngine (IP cam) unexpected error: {e}")
                if consecutive_failures >= _MAX_RETRIES:
                    print(" AudioCaptureEngine (IP cam): too many errors, stopping.")
                    return
                time.sleep(backoff)
                backoff = min(backoff * 2, _MAX_BACKOFF)

    # ------------------------------------------------------------------
    # Path 3  Uploaded video file (MP4/MOV/AVI/) via ffmpeg
    # ------------------------------------------------------------------

    def _capture_video_file(self):
        """
        Extract audio from a local video file using ffmpeg (no librosa/audioread).
        ffmpeg outputs raw signed 16-bit little-endian PCM at 16 kHz mono,
        which is EXACTLY the same format sounddevice produces  identical to
        what the live microphone path sends to the audio_queue.
        """
        source_path = self.source
        print(f" Video audio: starting ffmpeg extraction from {source_path}")

        try:
            cmd = [
                "ffmpeg",
                "-v", "error",           # suppress non-error output
                "-i", source_path,
                "-ar", str(AUDIO_SAMPLE_RATE),  # resample to 16 kHz
                "-ac", "1",              # mono
                "-f", "s16le",           # signed 16-bit little-endian raw PCM
                "pipe:1",                # write to stdout
            ]

            proc = subprocess.Popen(
                cmd,
                stdout=subprocess.PIPE,
                stderr=subprocess.DEVNULL,
            )

            chunk_bytes = AUDIO_CHUNK_SAMPLES * 2  # 2 bytes per int16 sample
            chunk_count = 0

            while self.is_running:
                raw = proc.stdout.read(chunk_bytes)

                if not raw:
                    # EOF  loop the audio back to start by restarting ffmpeg
                    proc.stdout.close()
                    proc.wait()
                    print(" Video audio: EOF  looping")
                    proc = subprocess.Popen(
                        cmd,
                        stdout=subprocess.PIPE,
                        stderr=subprocess.DEVNULL,
                    )
                    continue

                # Pad if final chunk is short (keeps shape consistent)
                if len(raw) < chunk_bytes:
                    raw = raw + b"\x00" * (chunk_bytes - len(raw))

                # Convert to int16 numpy  identical to mic indata dtype
                chunk_int16 = np.frombuffer(raw, dtype=np.int16)

                chunk_count += 1
                try:
                    self.audio_queue.put_nowait(chunk_int16.tobytes())
                except queue.Full:
                    pass

                # Debug log every 10 chunks (~5 s)
                if chunk_count % 10 == 0:
                    print(
                        f" [video audio] chunk #{chunk_count} "
                        f"shape={chunk_int16.shape} "
                        f"max_amp={np.abs(chunk_int16).max()}"
                    )

                # Pace to real-time: 0.5 s per chunk at 16 kHz
                time.sleep(AUDIO_CHUNK_SAMPLES / AUDIO_SAMPLE_RATE)

            proc.stdout.close()
            proc.wait()
            print(" Video audio: ffmpeg process stopped")

        except FileNotFoundError:
            print(
                " ffmpeg not found  falling back to librosa for video audio.\n"
                "   Install ffmpeg and add it to PATH for best results."
            )
            self._capture_video_file_librosa_fallback()
        except Exception as e:
            print(f" AudioCaptureEngine (video file) failed: {e}")
            traceback.print_exc()

    def _capture_video_file_librosa_fallback(self):
        """librosa fallback if ffmpeg is not available."""
        try:
            import librosa
            print(f" Loading audio via librosa from: {self.source}")
            audio_data, _ = librosa.load(self.source, sr=AUDIO_SAMPLE_RATE, mono=True)
            audio_int16 = (audio_data * 32767).astype(np.int16)
            total = len(audio_int16)
            print(f" Librosa loaded {total/AUDIO_SAMPLE_RATE:.1f}s of audio")

            pos = 0
            chunk_count = 0
            while self.is_running:
                end = pos + AUDIO_CHUNK_SAMPLES
                chunk = audio_int16[pos:end]

                if pos >= total or len(chunk) == 0:
                    pos = 0
                    continue

                # Pad short final chunk to exact size
                if len(chunk) < AUDIO_CHUNK_SAMPLES:
                    chunk = np.pad(chunk, (0, AUDIO_CHUNK_SAMPLES - len(chunk)))

                chunk_count += 1
                try:
                    self.audio_queue.put_nowait(chunk.tobytes())
                except queue.Full:
                    pass

                if chunk_count % 10 == 0:
                    print(
                        f" [video audio librosa] chunk #{chunk_count} "
                        f"shape={chunk.shape} max_amp={np.abs(chunk).max()}"
                    )

                pos = end
                time.sleep(AUDIO_CHUNK_SAMPLES / AUDIO_SAMPLE_RATE)

        except Exception as e:
            print(f" AudioCaptureEngine (librosa fallback) failed: {e}")
            traceback.print_exc()
