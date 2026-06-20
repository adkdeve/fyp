"""
WebSocket Video Streaming Server

Provides low-latency frame delivery via WebSocket and MJPEG endpoints.
Runs alongside the Streamlit app in a background thread, completely
bypassing Streamlit's rendering pipeline for smooth real-time video.

Architecture:
    StreamingEngine (singleton)
         ThreadedFrameReader   captures latest frame (background thread)
         IntegratedVideoProcessor  processes frame (processing thread)
         VideoStreamServer (singleton)
               /ws/video    binary JPEG frames over WebSocket
               /ws/stats    JSON stats over WebSocket
               /video/mjpeg  MJPEG over HTTP (fallback)

Browser (HTML canvas) connects to WebSocket and renders frames directly.
"""

import asyncio
import cv2
import json
import numpy as np
import socket
import subprocess
import threading
import time
from fractions import Fraction
from typing import Optional, Dict, Any
import shutil
import os
from urllib.parse import urlparse, urlunparse

import av
from aiortc import RTCPeerConnection, RTCSessionDescription, VideoStreamTrack, AudioStreamTrack
from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.responses import StreamingResponse
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import uvicorn


# 
# WebSocket Server
# 


class WebRTCOffer(BaseModel):
    sdp: str
    type: str


def _get_ffmpeg_path() -> Optional[str]:
    """Find ffmpeg executable in system PATH or known Windows installation paths."""
    # Try standard PATH search first
    ffmpeg_path = shutil.which("ffmpeg")
    if ffmpeg_path:
        return ffmpeg_path
    
    # Try known Windows installation paths
    common_paths = [
            r"D:\FYP_FINAL\tools\ffmpeg-8.1-essentials_build\bin\ffmpeg.exe",
        r"C:\ffmpeg-7.1.1-essentials_build\bin\ffmpeg.exe",
        r"C:\ffmpeg\bin\ffmpeg.exe",
        r"C:\Program Files\ffmpeg\bin\ffmpeg.exe",
    ]
    for path in common_paths:
        if os.path.exists(path):
            return path
    
    return None


class SourceAudioReader:
    """Reads PCM mono audio from a stream URL using ffmpeg."""

    def __init__(self, source_url: str, sample_rate: int = 16000, channels: int = 1):
        self.source_url = source_url
        self.sample_rate = sample_rate
        self.channels = channels
        self.bytes_per_sample = 2  # s16le
        self.frame_ms = 20
        self.chunk_size = int(
            self.sample_rate * self.channels * self.bytes_per_sample * (self.frame_ms / 1000.0)
        )
        self._process: Optional[subprocess.Popen] = None
        self._thread: Optional[threading.Thread] = None
        self._running = False
        self._buffer = bytearray()
        self._lock = threading.Lock()

    @staticmethod
    def _is_webcam_index(url: str) -> bool:
        try:
            int(url)
            return True
        except Exception:
            return False

    @staticmethod
    def _resolve_audio_input_url(source_url: str) -> str:
        """Map known camera video URLs to their audio endpoint when needed."""
        try:
            parsed = urlparse(source_url)
            # Android IP Webcam commonly serves MJPEG at /video and audio at /audio.wav.
            if parsed.scheme in {"http", "https"} and parsed.path.rstrip("/").lower() == "/video":
                return urlunparse(parsed._replace(path="/audio.wav", params="", query="", fragment=""))
        except Exception:
            pass
        return source_url

    def start(self) -> bool:
        if not self.source_url or self._is_webcam_index(self.source_url):
            return False

        audio_input_url = self._resolve_audio_input_url(self.source_url)

        ffmpeg_path = _get_ffmpeg_path()
        if not ffmpeg_path:
            print(" ffmpeg not found in PATH or known locations; WebRTC audio disabled")
            print("   Install ffmpeg: winget install FFmpeg")
            return False

        cmd = [
            ffmpeg_path,
            "-nostdin",
            "-loglevel",
            "error",
            "-i",
            audio_input_url,
            "-vn",
            "-ac",
            str(self.channels),
            "-ar",
            str(self.sample_rate),
            "-f",
            "s16le",
            "pipe:1",
        ]

        if audio_input_url != self.source_url:
            print(f" Using mapped audio endpoint: {audio_input_url}")

        try:
            self._process = subprocess.Popen(
                cmd,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                bufsize=0,
            )
        except Exception as e:
            print(f" Failed to start ffmpeg audio reader: {e}")
            return False

        self._running = True
        self._thread = threading.Thread(target=self._reader_loop, daemon=True)
        self._thread.start()
        print(" Audio reader started for WebRTC")
        return True

    def _reader_loop(self):
        if self._process is None or self._process.stdout is None:
            return
        try:
            while self._running:
                data = self._process.stdout.read(4096)
                if not data:
                    break
                with self._lock:
                    self._buffer.extend(data)
                    max_bytes = self.sample_rate * self.channels * self.bytes_per_sample * 4
                    if len(self._buffer) > max_bytes:
                        del self._buffer[: len(self._buffer) - max_bytes]
        except Exception:
            pass

    def read_chunk(self) -> Optional[bytes]:
        with self._lock:
            if len(self._buffer) < self.chunk_size:
                return None
            chunk = bytes(self._buffer[: self.chunk_size])
            del self._buffer[: self.chunk_size]
            return chunk

    def stop(self):
        self._running = False
        if self._process is not None:
            try:
                self._process.terminate()
            except Exception:
                pass
            try:
                self._process.wait(timeout=1)
            except Exception:
                try:
                    self._process.kill()
                except Exception:
                    pass
        self._process = None


class LatestAudioTrack(AudioStreamTrack):
    """WebRTC audio track sourced from ffmpeg PCM reader with silence fallback."""

    def __init__(self, server: "VideoStreamServer", sample_rate: int = 16000):
        super().__init__()
        self.server = server
        self.sample_rate = sample_rate
        self.channels = 1
        self.samples_per_frame = int(self.sample_rate * 0.02)  # 20 ms
        self.frame_bytes = self.samples_per_frame * self.channels * 2
        self._start_time: Optional[float] = None
        self._samples_sent = 0

    async def recv(self):
        if self._start_time is None:
            self._start_time = time.time()
        else:
            target = self._start_time + (self._samples_sent / self.sample_rate)
            delay = target - time.time()
            if delay > 0:
                await asyncio.sleep(delay)

        chunk = self.server.get_audio_chunk(self.frame_bytes)
        if chunk is None:
            chunk = b"\x00" * self.frame_bytes
        elif len(chunk) < self.frame_bytes:
            chunk = chunk + (b"\x00" * (self.frame_bytes - len(chunk)))
        elif len(chunk) > self.frame_bytes:
            chunk = chunk[: self.frame_bytes]

        frame = av.AudioFrame(format="s16", layout="mono", samples=self.samples_per_frame)
        frame.planes[0].update(chunk)
        frame.sample_rate = self.sample_rate
        frame.pts = self._samples_sent
        frame.time_base = Fraction(1, self.sample_rate)
        self._samples_sent += self.samples_per_frame
        return frame


class LatestFrameTrack(VideoStreamTrack):
    """WebRTC track that serves the latest processed frame from VideoStreamServer."""

    def __init__(self, server: "VideoStreamServer"):
        super().__init__()
        self.server = server
        self._last_frame = None
        self._frames_sent = 0
        self._last_log_ts = time.time()

    async def recv(self):
        pts, time_base = await self.next_timestamp()

        frame = None
        with self.server._frame_lock:
            if self.server._latest_bgr is not None:
                frame = self.server._latest_bgr.copy()

        if frame is None:
            if self._last_frame is None:
                frame = np.zeros((480, 640, 3), dtype=np.uint8)
            else:
                frame = self._last_frame.copy()
        else:
            self._last_frame = frame.copy()

        video_frame = av.VideoFrame.from_ndarray(frame, format="bgr24")
        video_frame.pts = pts
        video_frame.time_base = time_base

        self._frames_sent += 1
        now = time.time()
        if now - self._last_log_ts >= 5:
            print(f"[WebRTC][Track] Frames sent={self._frames_sent} latest_bgr={'yes' if self.server._latest_bgr is not None else 'no'}")
            self._last_log_ts = now
        return video_frame

class VideoStreamServer:
    """
    Singleton FastAPI WebSocket server for real-time video frame delivery.
    
    Frames are pushed here by StreamingEngine, and delivered to all
    connected WebSocket clients as binary JPEG data.
    """
    
    _instance = None
    _lock = threading.Lock()
    
    @classmethod
    def get_instance(cls):
        with cls._lock:
            if cls._instance is None:
                cls._instance = cls()
        return cls._instance
    
    def __init__(self):
        self._latest_jpeg: Optional[bytes] = None
        self._latest_bgr = None
        self._latest_stats: Dict[str, Any] = {}
        self._frame_seq = 0           # monotonic frame counter
        self._frame_lock = threading.Lock()
        self._is_running = False
        self._server_thread = None
        self._port = 8765
        self._pcs: set[RTCPeerConnection] = set()
        self._audio_reader: Optional[SourceAudioReader] = None
        self._audio_source_url: Optional[str] = None
        self._audio_lock = threading.Lock()
        self.jpeg_quality = 60
        self._target_height = 480
        self._max_output_fps = 20
        self._last_publish_ts = 0.0
        self._app = self._create_app()
    
    def _create_app(self) -> FastAPI:
        app = FastAPI(title="Video Stream Server")
        app.add_middleware(
            CORSMiddleware,
            allow_origins=["*"],
            allow_methods=["*"],
            allow_headers=["*"],
        )
        
        server = self  # closure reference
        
        @app.websocket("/ws/video")
        async def video_websocket(websocket: WebSocket):
            """Stream JPEG frames over WebSocket (binary)."""
            await websocket.accept()
            try:
                last_seq = -1
                while True:
                    with server._frame_lock:
                        frame_data = server._latest_jpeg
                        seq = server._frame_seq
                    
                    # Only send when a genuinely new frame is available
                    if frame_data is not None and seq != last_seq:
                        await websocket.send_bytes(frame_data)
                        last_seq = seq
                    
                    # ~60 FPS max delivery ceiling
                    await asyncio.sleep(0.016)
            except (WebSocketDisconnect, Exception):
                pass
        
        @app.websocket("/ws/stats")
        async def stats_websocket(websocket: WebSocket):
            """Stream processing stats as JSON (2 Hz)."""
            await websocket.accept()
            try:
                while True:
                    with server._frame_lock:
                        stats = server._latest_stats.copy()
                    await websocket.send_text(json.dumps(stats, default=str))
                    await asyncio.sleep(0.5)
            except (WebSocketDisconnect, Exception):
                pass
        
        @app.get("/video/mjpeg")
        async def mjpeg_stream():
            """MJPEG stream over HTTP (fallback for non-WebSocket clients)."""
            async def generate():
                prev_id = None
                while True:
                    with server._frame_lock:
                        frame_data = server._latest_jpeg
                        fid = id(frame_data)
                    
                    if frame_data is not None and fid != prev_id:
                        yield (
                            b"--frame\r\n"
                            b"Content-Type: image/jpeg\r\n\r\n"
                            + frame_data + b"\r\n"
                        )
                        prev_id = fid
                    
                    await asyncio.sleep(0.033)
            
            return StreamingResponse(
                generate(),
                media_type="multipart/x-mixed-replace; boundary=frame",
                headers={
                    "Cache-Control": "no-cache, no-store, must-revalidate",
                    "Pragma": "no-cache",
                    "Expires": "0",
                    "X-Accel-Buffering": "no",
                },
            )
        
        @app.get("/health")
        async def health():
            return {
                "status": "ok",
                "streaming": server._latest_jpeg is not None,
                "port": server._port,
            }

        @app.post("/webrtc/offer")
        async def webrtc_offer(offer: WebRTCOffer):
            pc = RTCPeerConnection()
            server._pcs.add(pc)
            pc_id = f"pc-{id(pc)}"
            print(f"[WebRTC][{pc_id}] Offer received type={offer.type} sdp_len={len(offer.sdp or '')}")

            @pc.on("connectionstatechange")
            async def on_connectionstatechange():
                print(f"[WebRTC][{pc_id}] connectionState={pc.connectionState}")
                if pc.connectionState in {"failed", "closed", "disconnected"}:
                    await pc.close()
                    server._pcs.discard(pc)
                    print(f"[WebRTC][{pc_id}] closed and removed")

            @pc.on("iceconnectionstatechange")
            async def on_iceconnectionstatechange():
                print(f"[WebRTC][{pc_id}] iceConnectionState={pc.iceConnectionState}")

            @pc.on("icegatheringstatechange")
            async def on_icegatheringstatechange():
                print(f"[WebRTC][{pc_id}] iceGatheringState={pc.iceGatheringState}")

            @pc.on("signalingstatechange")
            async def on_signalingstatechange():
                print(f"[WebRTC][{pc_id}] signalingState={pc.signalingState}")

            await pc.setRemoteDescription(
                RTCSessionDescription(sdp=offer.sdp, type=offer.type)
            )
            print(f"[WebRTC][{pc_id}] Remote description set")

            track = LatestFrameTrack(server)
            pc.addTrack(track)
            print(f"[WebRTC][{pc_id}] Track attached via addTrack")

            audio_track = LatestAudioTrack(server)
            pc.addTrack(audio_track)
            print(f"[WebRTC][{pc_id}] Audio track attached via addTrack")

            answer = await pc.createAnswer()
            await pc.setLocalDescription(answer)
            print(f"[WebRTC][{pc_id}] Local answer created")

            # Ensure SDP contains gathered ICE candidates before responding.
            if pc.iceGatheringState != "complete":
                for _ in range(50):
                    if pc.iceGatheringState == "complete":
                        break
                    await asyncio.sleep(0.1)

            print(
                f"[WebRTC][{pc_id}] Answer ready iceGathering={pc.iceGatheringState} "
                f"local_sdp_len={len(pc.localDescription.sdp if pc.localDescription else '')}"
            )

            return {
                "sdp": pc.localDescription.sdp,
                "type": pc.localDescription.type,
            }
        
        return app
    
    #  Public API 
    
    def update_frame(self, frame, results: Optional[Dict] = None):
        """
        Push a new processed frame to all connected clients.
        Called from the processing thread.
        
        Args:
            frame: BGR numpy array (processed/annotated frame)
            results: Optional detection results dict
        """
        now = time.time()
        h, w = frame.shape[:2]
        if h > 0 and h != self._target_height:
            new_w = max(1, int(w * (self._target_height / h)))
            frame = cv2.resize(frame, (new_w, self._target_height))
        
        with self._frame_lock:
            # Always keep latest BGR frame fresh for WebRTC consumers.
            self._latest_bgr = frame.copy()

            # Throttle only MJPEG/JPEG publishing.
            if (now - self._last_publish_ts) >= (1.0 / self._max_output_fps):
                encode_params = [cv2.IMWRITE_JPEG_QUALITY, self.jpeg_quality]
                ok, jpeg = cv2.imencode('.jpg', frame, encode_params)
                if ok:
                    self._latest_jpeg = jpeg.tobytes()
                    self._frame_seq += 1
                    self._last_publish_ts = now

            if results:
                self._latest_stats = {
                    'fps': round(results.get('fps', 0), 1),
                    'process_time_ms': round(results.get('process_time_ms', 0), 1),
                    'tracked_persons': len(results.get('tracked_persons', [])),
                    'unknown_persons': results.get('unknown_persons', 0),
                    'fire_smoke': len(results.get('fire_smoke', [])),
                    'distress': len(results.get('distress', [])),
                    'safe_zone_violations': results.get('safe_zone_violations', 0),
                    'audio_enabled': bool(self._audio_reader is not None),
                }

    def set_audio_source(self, source_url: Optional[str]):
        """Set or clear source URL for WebRTC audio extraction."""
        with self._audio_lock:
            if source_url == self._audio_source_url:
                return

            if self._audio_reader is not None:
                self._audio_reader.stop()
                self._audio_reader = None

            self._audio_source_url = source_url

            if not source_url:
                return

            reader = SourceAudioReader(source_url)
            if reader.start():
                self._audio_reader = reader

    def get_audio_chunk(self, expected_bytes: int) -> Optional[bytes]:
        with self._audio_lock:
            if self._audio_reader is None:
                return None
            chunk = self._audio_reader.read_chunk()
            if chunk is None:
                return None
            if len(chunk) == expected_bytes:
                return chunk
            if len(chunk) < expected_bytes:
                return chunk + (b"\x00" * (expected_bytes - len(chunk)))
            return chunk[:expected_bytes]
    
    @property
    def is_running(self):
        return self._is_running
    
    @property
    def port(self):
        return self._port
    
    def start(self, port: int = 8765):
        """Start the WebSocket server in a background daemon thread."""
        if self._is_running:
            print(f"  WebSocket server already running on port {self._port}")
            return
        
        # Find an available port (don't trust stale servers from old processes)
        chosen_port = port
        while self._is_port_in_use(chosen_port):
            print(f"  Port {chosen_port} occupied  trying next...")
            chosen_port += 1
            if chosen_port > port + 20:
                print(f" No available ports in range {port}-{chosen_port}")
                return
        
        self._port = chosen_port
        self._is_running = True
        self._server_thread = threading.Thread(
            target=self._run_server,
            daemon=True,
        )
        self._server_thread.start()
        time.sleep(0.5)
        print(f" WebSocket server started on ws://localhost:{chosen_port}")
    
    def _run_server(self):
        config = uvicorn.Config(
            self._app,
            host="0.0.0.0",
            port=self._port,
            log_level="warning",
            access_log=False,
        )
        server = uvicorn.Server(config)
        server.run()
    
    @staticmethod
    def _is_port_in_use(port: int) -> bool:
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
            return s.connect_ex(('localhost', port)) == 0
    
    def stop(self):
        self._is_running = False
        self.set_audio_source(None)
        for pc in list(self._pcs):
            try:
                asyncio.run(pc.close())
            except Exception:
                pass
        self._pcs.clear()
        self.clear()
    
    def clear(self):
        """Flush all cached frame data."""
        with self._frame_lock:
            self._latest_bgr = None
            self._latest_jpeg = None
            self._latest_stats = {}
            self._frame_seq = 0


# 
# Streaming Engine
# 

class StreamingEngine:
    """
    Manages the complete capture  process  stream pipeline.
    Runs entirely in background threads, decoupled from Streamlit's
    rerun cycle  so widgets never block on video frames.
    """
    
    _instance = None
    _lock = threading.Lock()
    
    @classmethod
    def get_instance(cls):
        with cls._lock:
            if cls._instance is None:
                cls._instance = cls()
        return cls._instance
    
    def __init__(self):
        self.processor = None
        self.stream = None           # ThreadedFrameReader
        self.ws_server = VideoStreamServer.get_instance()
        self._is_running = False
        self._capture_thread = None
        self._process_thread = None
        self._current_frame = None
        self._current_stats: Dict[str, Any] = {}
        self._frame_lock = threading.Lock()
        self._capture_lock = threading.Lock()
        self._latest_input_frame = None
        self._latest_input_is_real = False
        self._last_real_input_frame = None
        self._latest_input_seq = 0
        self._audio_trigger_reader: Optional[SourceAudioReader] = None
        self._audio_trigger_buffer = bytearray()
        self._audio_trigger_sample_rate = 16000
        self._last_audio_trigger_update_ts = 0.0
        self.max_input_width = 640   # Cap input resolution for performance
        self.max_process_fps = 25.0
    
    def set_processor(self, processor):
        """Set/update the IntegratedVideoProcessor (from Streamlit session)."""
        self.processor = processor
    
    @property
    def is_running(self):
        return self._is_running
    
    def start(self, threaded_reader, source_url: Optional[str] = None):
        """
        Start the processing pipeline.
        
        Args:
            threaded_reader: ThreadedFrameReader wrapping the source stream
        """
        if self._is_running:
            self.stop()
        
        self.stream = threaded_reader

        # Optional audio reader for cascade distress trigger.
        if self._audio_trigger_reader is not None:
            self._audio_trigger_reader.stop()
            self._audio_trigger_reader = None
        self._audio_trigger_buffer = bytearray()
        self._last_audio_trigger_update_ts = 0.0
        if source_url:
            reader = SourceAudioReader(source_url, sample_rate=self._audio_trigger_sample_rate, channels=1)
            if reader.start():
                self._audio_trigger_reader = reader
        
        # Clear any stale frames from previous session
        self.ws_server.clear()
        with self._frame_lock:
            self._current_frame = None
            self._current_stats = {}
        
        # Reset processor frame counter so tracking restarts cleanly
        if self.processor:
            try:
                self.processor.frame_count = 0
                self.processor.person_tracker.reset()
            except Exception:
                pass
        
        # Ensure WebSocket server is up
        if not self.ws_server.is_running:
            self.ws_server.start()
        
        self._is_running = True
        self._capture_thread = threading.Thread(
            target=self._capture_loop, daemon=True
        )
        self._capture_thread.start()
        self._process_thread = threading.Thread(
            target=self._process_loop, daemon=True
        )
        self._process_thread.start()
        print(" Streaming engine started")

    def _capture_loop(self):
        """Capture thread: continuously read and keep only the latest frame."""
        while self._is_running:
            if self.stream is None:
                time.sleep(0.01)
                continue

            ret, frame = self.stream.read()
            if ret and frame is not None:
                with self._capture_lock:
                    self._latest_input_frame = frame
                    self._latest_input_is_real = True
                    self._last_real_input_frame = frame
                    self._latest_input_seq += 1
                continue

            # Reuse last valid frame for display continuity.
            with self._capture_lock:
                if self._last_real_input_frame is not None:
                    self._latest_input_frame = self._last_real_input_frame.copy()
                    self._latest_input_is_real = False
                    self._latest_input_seq += 1
            time.sleep(0.005)
    
    def _process_loop(self):
        """
        Main processing loop (background thread).
        
        Reads latest frame  processes with all enabled ML models 
        pushes JPEG to WebSocket server.
        """
        while self._is_running:
            loop_start = time.time()
            with self._capture_lock:
                if self._latest_input_frame is None:
                    frame = None
                    is_real_frame = False
                    input_seq = -1
                else:
                    frame = self._latest_input_frame.copy()
                    is_real_frame = self._latest_input_is_real
                    input_seq = self._latest_input_seq

            if frame is None:
                time.sleep(0.005)
                continue

            # Feed PCM chunks into distress detector audio trigger (if available).
            if self._audio_trigger_reader is not None and self.processor is not None:
                detector = getattr(self.processor, "distress_detector", None)
                if detector is not None and getattr(detector, "has_audio", False):
                    chunk = self._audio_trigger_reader.read_chunk()
                    if chunk:
                        self._audio_trigger_buffer.extend(chunk)
                        max_bytes = self._audio_trigger_sample_rate * 2 * 6
                        if len(self._audio_trigger_buffer) > max_bytes:
                            del self._audio_trigger_buffer[: len(self._audio_trigger_buffer) - max_bytes]

                    now_ts = time.time()
                    required = self._audio_trigger_sample_rate * 2 * 2  # 2 sec window, mono s16
                    if (
                        len(self._audio_trigger_buffer) >= required
                        and (now_ts - self._last_audio_trigger_update_ts) >= 0.25
                    ):
                        pcm_window = bytes(self._audio_trigger_buffer[-required:])
                        detector.update_audio_trigger_from_pcm(
                            pcm_window,
                            sample_rate=self._audio_trigger_sample_rate,
                        )
                        self._last_audio_trigger_update_ts = now_ts

            # Skip processing when capture has not advanced to a newer frame.
            if not hasattr(self, "_last_processed_input_seq"):
                self._last_processed_input_seq = -1
            if input_seq == self._last_processed_input_seq:
                time.sleep(0.002)
                continue
            self._last_processed_input_seq = input_seq
            
            # Resize high-res input for faster ML processing
            h, w = frame.shape[:2]
            if w > self.max_input_width:
                scale = self.max_input_width / w
                frame = cv2.resize(frame, (self.max_input_width, int(h * scale)))
            
            # Process frame with ML models
            if self.processor:
                try:
                    processed, results = self.processor.process_frame(
                        frame,
                        allow_heavy_models=is_real_frame,
                    )
                    results['interpolated_frame'] = not is_real_frame
                except Exception as e:
                    processed = frame
                    results = {
                        'error': str(e),
                        'fps': 0,
                        'process_time_ms': 0,
                        'tracked_persons': [],
                        'unknown_persons': 0,
                        'interpolated_frame': not is_real_frame,
                    }
            else:
                processed = frame
                results = {
                    'fps': 0,
                    'process_time_ms': 0,
                    'tracked_persons': [],
                    'unknown_persons': 0,
                    'interpolated_frame': not is_real_frame,
                }
            
            # Push to WebSocket server for delivery
            self.ws_server.update_frame(processed, results)
            
            # Store latest frame for Streamlit access (safe zone drawer, etc.)
            with self._frame_lock:
                self._current_frame = processed.copy()
                self._current_stats = results

            # Bound processing cadence to reduce jitter and CPU spikes.
            frame_budget = 1.0 / self.max_process_fps
            elapsed = time.time() - loop_start
            if elapsed < frame_budget:
                time.sleep(frame_budget - elapsed)
    
    def stop(self):
        """Stop the processing pipeline and release resources."""
        self._is_running = False
        if self._audio_trigger_reader is not None:
            self._audio_trigger_reader.stop()
            self._audio_trigger_reader = None
        self._audio_trigger_buffer = bytearray()
        if self._capture_thread and self._capture_thread.is_alive():
            self._capture_thread.join(timeout=3)
        if self._process_thread and self._process_thread.is_alive():
            self._process_thread.join(timeout=3)
        if self.stream:
            self.stream.release()
            self.stream = None
        with self._frame_lock:
            self._current_frame = None
            self._current_stats = {}
        with self._capture_lock:
            self._latest_input_frame = None
            self._latest_input_is_real = False
            self._last_real_input_frame = None
        # Flush stale frame from WebSocket server
        self.ws_server.clear()
        print("  Streaming engine stopped")
    
    def get_current_frame(self):
        """Get the latest processed frame (for safe zone drawer etc.)."""
        with self._frame_lock:
            if self._current_frame is not None:
                return self._current_frame.copy()
            return None
    
    def get_current_stats(self) -> Dict[str, Any]:
        """Get the latest processing stats."""
        with self._frame_lock:
            return self._current_stats.copy()


# 
# HTML/JS WebSocket Viewer Component
# 

def get_ws_viewer_html(ws_port: int = 8765, height: int = 480) -> str:
    """
    Returns an HTML/JS snippet that connects to the WebSocket server
    and renders video frames on an HTML5 canvas.
    
    Embed in Streamlit with:
        import streamlit.components.v1 as components
        components.html(get_ws_viewer_html(port), height=500)
    """
    return f"""
    <!DOCTYPE html>
    <html>
    <head>
    <style>
        * {{ margin: 0; padding: 0; box-sizing: border-box; }}
        body {{ background: #0e1117; overflow: hidden; }}
        #container {{
            position: relative;
            width: 100%;
            height: {height}px;
            background: #0e1117;
            display: flex;
            align-items: center;
            justify-content: center;
        }}
        #video-canvas {{
            max-width: 100%;
            max-height: 100%;
            display: block;
            border-radius: 6px;
        }}
        #status {{
            position: absolute;
            top: 8px;
            right: 8px;
            padding: 4px 12px;
            border-radius: 4px;
            font-family: 'Segoe UI', monospace;
            font-size: 12px;
            color: #fff;
            background: rgba(0,0,0,0.6);
            backdrop-filter: blur(4px);
            z-index: 10;
        }}
        #stats {{
            position: absolute;
            bottom: 8px;
            left: 8px;
            padding: 4px 12px;
            border-radius: 4px;
            font-family: 'Segoe UI Mono', 'Consolas', monospace;
            font-size: 12px;
            color: #0f0;
            background: rgba(0,0,0,0.6);
            backdrop-filter: blur(4px);
            z-index: 10;
            display: none;
        }}
        .connecting {{ color: #ffa500; }}
        .live {{ color: #00ff00; }}
        .disconnected {{ color: #ff4444; }}
    </style>
    </head>
    <body>
    <div id="container">
        <canvas id="video-canvas"></canvas>
        <div id="status" class="connecting">&#9679; Connecting...</div>
        <div id="stats"></div>
    </div>
    <script>
    (function() {{
        const WS_VIDEO = 'ws://localhost:{ws_port}/ws/video';
        const WS_STATS = 'ws://localhost:{ws_port}/ws/stats';
        
        const canvas = document.getElementById('video-canvas');
        const ctx = canvas.getContext('2d');
        const statusEl = document.getElementById('status');
        const statsEl = document.getElementById('stats');
        
        let frameCount = 0;
        let lastFpsTime = performance.now();
        let displayFps = 0;
        let reconnectDelay = 500;
        
        //  VIDEO WEBSOCKET 
        function connectVideo() {{
            const ws = new WebSocket(WS_VIDEO);
            ws.binaryType = 'arraybuffer';
            
            ws.onopen = () => {{
                statusEl.innerHTML = '&#9679; Live';
                statusEl.className = 'live';
                reconnectDelay = 500;
            }};
            
            ws.onmessage = (event) => {{
                const blob = new Blob([event.data], {{type: 'image/jpeg'}});
                const url = URL.createObjectURL(blob);
                const img = new Image();
                img.onload = () => {{
                    if (canvas.width !== img.width || canvas.height !== img.height) {{
                        canvas.width = img.width;
                        canvas.height = img.height;
                    }}
                    ctx.drawImage(img, 0, 0);
                    URL.revokeObjectURL(url);
                    
                    // Track display FPS
                    frameCount++;
                    const now = performance.now();
                    if (now - lastFpsTime >= 1000) {{
                        displayFps = frameCount;
                        frameCount = 0;
                        lastFpsTime = now;
                    }}
                }};
                img.src = url;
            }};
            
            ws.onclose = () => {{
                statusEl.innerHTML = '&#9679; Disconnected';
                statusEl.className = 'disconnected';
                setTimeout(connectVideo, reconnectDelay);
                reconnectDelay = Math.min(reconnectDelay * 1.5, 5000);
            }};
            
            ws.onerror = () => {{
                statusEl.innerHTML = '&#9679; Connection Error';
                statusEl.className = 'disconnected';
            }};
        }}
        
        //  STATS WEBSOCKET 
        function connectStats() {{
            const ws = new WebSocket(WS_STATS);
            
            ws.onopen = () => {{
                statsEl.style.display = 'block';
            }};
            
            ws.onmessage = (event) => {{
                try {{
                    const s = JSON.parse(event.data);
                    let html = 
                        'Display: ' + displayFps + ' fps | ' +
                        'Process: ' + (s.fps || 0) + ' fps (' + (s.process_time_ms || 0) + 'ms) | ' +
                        'Tracked: ' + (s.tracked_persons || 0);
                    
                    if (s.unknown_persons > 0) html += ' | Unknown: ' + s.unknown_persons;
                    if (s.fire_smoke > 0) html += ' | Fire: ' + s.fire_smoke;
                    if (s.distress > 0) html += ' | Distress: ' + s.distress;
                    if (s.safe_zone_violations > 0) html += ' | Unsafe: ' + s.safe_zone_violations;
                    
                    statsEl.innerHTML = html;
                }} catch(e) {{}}
            }};
            
            ws.onclose = () => {{
                statsEl.style.display = 'none';
                setTimeout(connectStats, 3000);
            }};
        }}
        
        connectVideo();
        connectStats();
    }})();
    </script>
    </body>
    </html>
    """
