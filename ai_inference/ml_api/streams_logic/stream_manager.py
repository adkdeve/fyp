"""
Stream Manager - Handles video file and RTSP camera stream inputs
With threaded frame reading for low-latency streaming
"""
import cv2
import numpy as np
from typing import Optional, Tuple
import queue
import threading
import time
from enum import Enum


class StreamType(Enum):
    """Type of video stream"""
    VIDEO_FILE = "video_file"
    RTSP_CAMERA = "rtsp_camera"
    WEBCAM = "webcam"


class BaseStream:
    """Base class for video streams"""
    
    def __init__(self):
        self.cap = None
        self.is_open = False
        self.width = 0
        self.height = 0
        self.fps = 25
        
    def read(self) -> Tuple[bool, Optional[np.ndarray]]:
        """Read next frame"""
        raise NotImplementedError
    
    def release(self):
        """Release stream resources"""
        if self.cap is not None:
            self.cap.release()
        self.is_open = False
    
    def get_frame_size(self) -> Tuple[int, int]:
        """Get frame dimensions (width, height)"""
        return (self.width, self.height)
    
    def get_fps(self) -> float:
        """Get stream FPS"""
        return self.fps


class VideoFileStream(BaseStream):
    """Stream handler for uploaded video files"""
    
    def __init__(self, video_path: str):
        """
        Initialize video file stream
        
        Args:
            video_path: Path to video file
        """
        super().__init__()
        self.video_path = video_path
        self._open_stream()
    
    def _open_stream(self):
        """Open the video file"""
        try:
            self.cap = cv2.VideoCapture(self.video_path)
            
            if not self.cap.isOpened():
                raise RuntimeError(f"Cannot open video file: {self.video_path}")
            
            self.width = int(self.cap.get(cv2.CAP_PROP_FRAME_WIDTH))
            self.height = int(self.cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
            self.fps = self.cap.get(cv2.CAP_PROP_FPS) or 25
            self.total_frames = int(self.cap.get(cv2.CAP_PROP_FRAME_COUNT))
            self.is_open = True
            
            print(f" Opened video file: {self.video_path}")
            print(f"   Resolution: {self.width}x{self.height}, FPS: {self.fps}, Frames: {self.total_frames}")
            
        except Exception as e:
            print(f" Error opening video file: {str(e)}")
            self.is_open = False
            raise
    
    def read(self) -> Tuple[bool, Optional[np.ndarray]]:
        """Read next frame from video file"""
        if not self.is_open or self.cap is None:
            return False, None
        
        ret, frame = self.cap.read()
        return ret, frame
    
    def get_total_frames(self) -> int:
        """Get total number of frames in video"""
        return self.total_frames
    
    def get_current_frame(self) -> int:
        """Get current frame number"""
        if self.cap is None:
            return 0
        return int(self.cap.get(cv2.CAP_PROP_POS_FRAMES))
    
    def seek(self, frame_number: int):
        """Seek to specific frame"""
        if self.cap is not None:
            self.cap.set(cv2.CAP_PROP_POS_FRAMES, frame_number)


class RTSPStream(BaseStream):
    """Stream handler for RTSP camera feeds"""
    
    def __init__(self, rtsp_url: str, buffer_size: int = 2):
        """
        Initialize RTSP stream
        
        Args:
            rtsp_url: RTSP URL (e.g., rtsp://192.168.1.10:8080/video)
            buffer_size: Frame buffer size to reduce latency
        """
        super().__init__()
        self.rtsp_url = rtsp_url
        self.buffer_size = buffer_size
        self._open_stream()
    
    def _open_stream(self):
        """Open the RTSP stream"""
        try:
            # Try opening with different backends for better RTSP support
            self.cap = cv2.VideoCapture(self.rtsp_url, cv2.CAP_FFMPEG)
            
            if not self.cap.isOpened():
                # Try without backend specification
                self.cap = cv2.VideoCapture(self.rtsp_url)
            
            if not self.cap.isOpened():
                raise RuntimeError(f"Cannot connect to RTSP stream: {self.rtsp_url}")
            
            # Force low-latency capture profile for IP webcam style sources.
            self.cap.set(cv2.CAP_PROP_BUFFERSIZE, self.buffer_size)
            self.cap.set(cv2.CAP_PROP_FRAME_WIDTH, 640)
            self.cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 480)
            self.cap.set(cv2.CAP_PROP_FPS, 15)
            self.cap.set(cv2.CAP_PROP_FOURCC, cv2.VideoWriter_fourcc(*"MJPG"))
            
            # Get stream properties
            self.width = int(self.cap.get(cv2.CAP_PROP_FRAME_WIDTH))
            self.height = int(self.cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
            self.fps = self.cap.get(cv2.CAP_PROP_FPS) or 25
            self.is_open = True
            
            print(f" Connected to RTSP stream: {self.rtsp_url}")
            print(f"   Resolution: {self.width}x{self.height}, FPS: {self.fps}")
            
        except Exception as e:
            print(f" Error connecting to RTSP stream: {str(e)}")
            self.is_open = False
            raise
    
    def read(self) -> Tuple[bool, Optional[np.ndarray]]:
        """Read next frame from RTSP stream"""
        if not self.is_open or self.cap is None:
            return False, None
        
        ret, frame = self.cap.read()
        return ret, frame
    
    def reconnect(self):
        """Attempt to reconnect to the stream"""
        print(" Attempting to reconnect to RTSP stream...")
        self.release()
        try:
            self._open_stream()
            return True
        except Exception:
            return False


class WebcamStream(BaseStream):
    """Stream handler for local webcam"""
    
    def __init__(self, camera_index: int = 0):
        """
        Initialize webcam stream
        
        Args:
            camera_index: Camera device index (default 0)
        """
        super().__init__()
        self.camera_index = camera_index
        self._open_stream()
    
    def _open_stream(self):
        """Open the webcam"""
        try:
            # Try DirectShow backend on Windows for better performance
            backend = getattr(cv2, 'CAP_DSHOW', None)
            if backend is None:
                backend = getattr(cv2, 'CAP_MSMF', getattr(cv2, 'CAP_ANY', 0))
            
            self.cap = cv2.VideoCapture(self.camera_index, backend)
            
            if not self.cap.isOpened():
                self.cap = cv2.VideoCapture(self.camera_index)
            
            if not self.cap.isOpened():
                raise RuntimeError(f"Cannot open webcam at index {self.camera_index}")
            
            # Set buffer size for lower latency
            self.cap.set(cv2.CAP_PROP_BUFFERSIZE, 1)
            
            # Get camera properties
            self.width = int(self.cap.get(cv2.CAP_PROP_FRAME_WIDTH))
            self.height = int(self.cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
            self.fps = self.cap.get(cv2.CAP_PROP_FPS) or 30
            self.is_open = True
            
            print(f" Opened webcam at index {self.camera_index}")
            print(f"   Resolution: {self.width}x{self.height}, FPS: {self.fps}")
            
        except Exception as e:
            print(f" Error opening webcam: {str(e)}")
            self.is_open = False
            raise
    
    def read(self) -> Tuple[bool, Optional[np.ndarray]]:
        """Read next frame from webcam"""
        if not self.is_open or self.cap is None:
            return False, None
        
        ret, frame = self.cap.read()
        return ret, frame


class ThreadedFrameReader:
    """
    Threaded frame reader wrapper for any stream.
    
    Continuously reads frames in a background thread and always
    returns the latest frame, dropping stale ones. This dramatically
    reduces latency for RTSP and webcam streams by decoupling
    frame capture from frame processing.
    
    Usage:
        stream = create_stream("rtsp://...", StreamType.RTSP_CAMERA)
        reader = ThreadedFrameReader(stream).start()
        
        while True:
            ret, frame = reader.read()  # Always gets latest frame
            if ret:
                process(frame)
        
        reader.release()
    """
    
    def __init__(self, stream: BaseStream):
        """
        Args:
            stream: Any BaseStream instance (VideoFile, RTSP, Webcam)
        """
        self.stream = stream
        self._frame = None
        self._ret = False
        self._last_valid_frame = None
        self._lock = threading.Lock()
        self._running = False
        self._thread = None
        self._consecutive_failures = 0
        self._max_consecutive_failures = 30
        self._max_grab_drain = 6

        # Keep source buffer minimal to avoid stale-frame lag.
        if getattr(self.stream, "cap", None) is not None:
            try:
                self.stream.cap.set(cv2.CAP_PROP_BUFFERSIZE, 1)
            except Exception:
                pass
    
    def start(self):
        """Start the background reader thread. Returns self for chaining."""
        self._running = True
        self._thread = threading.Thread(target=self._reader_loop, daemon=True)
        self._thread.start()
        
        # Wait for the first frame (up to 3 seconds)
        timeout = 3.0
        t0 = time.time()
        while time.time() - t0 < timeout:
            with self._lock:
                if self._frame is not None:
                    break
            time.sleep(0.01)
        return self
    
    def _reader_loop(self):
        """Continuously read frames and keep only the latest available frame."""
        while self._running and self.stream.is_open:
            ret, frame = self._read_latest_from_source()

            if ret and frame is not None:
                self._consecutive_failures = 0
                self._last_valid_frame = frame.copy()
            else:
                self._consecutive_failures += 1

                # Reuse last known good frame for stability in downstream display.
                if self._last_valid_frame is not None:
                    frame = self._last_valid_frame.copy()

                # Auto-reconnect for RTSP-like sources after repeated failures.
                if self._consecutive_failures >= self._max_consecutive_failures:
                    self._attempt_reconnect()
                    self._consecutive_failures = 0

            with self._lock:
                self._ret = ret
                self._frame = frame

            time.sleep(0.002)

    def _read_latest_from_source(self) -> Tuple[bool, Optional[np.ndarray]]:
        """Drain capture buffer and retrieve only the latest available frame."""
        cap = getattr(self.stream, "cap", None)

        # Apply grab/retrieve fast-path for live captures (not video files).
        if cap is not None and self.stream.__class__.__name__ != "VideoFileStream":
            try:
                grabbed = cap.grab()
                if not grabbed:
                    return False, None

                # Drain stale frames and keep only the newest in decoder queue.
                for _ in range(self._max_grab_drain):
                    if not cap.grab():
                        break

                ret, frame = cap.retrieve()
                return ret, frame
            except Exception:
                return False, None

        return self.stream.read()

    def _attempt_reconnect(self):
        reconnect = getattr(self.stream, "reconnect", None)
        if callable(reconnect):
            try:
                reconnect()
            except Exception:
                pass
    
    def read(self) -> Tuple[bool, Optional[np.ndarray]]:
        """
        Get the latest frame (non-blocking).

        Returns:
            (ret, frame)
            - ret=True means frame is freshly read from source
            - ret=False with non-None frame means last valid frame reuse
        """
        with self._lock:
            if self._frame is not None:
                return self._ret, self._frame.copy()
            return False, None
    
    def stop(self):
        """Stop the background reader thread."""
        self._running = False
        if self._thread and self._thread.is_alive():
            self._thread.join(timeout=2)
    
    def release(self):
        """Stop reader and release the underlying stream."""
        self.stop()
        self.stream.release()
    
    @property
    def is_open(self):
        return self.stream.is_open
    
    @property
    def width(self):
        return self.stream.width
    
    @property
    def height(self):
        return self.stream.height
    
    @property
    def fps(self):
        return self.stream.fps


def create_stream(source: str, stream_type: StreamType = None) -> Optional[BaseStream]:
    """
    Factory function to create appropriate stream based on source
    
    Args:
        source: Video file path, RTSP URL, or camera index (as string)
        stream_type: Optional explicit stream type
        
    Returns:
        Stream instance or None if creation fails
    """
    try:
        # Auto-detect stream type if not specified
        if stream_type is None:
            if source.startswith("rtsp://") or source.startswith("http://"):
                stream_type = StreamType.RTSP_CAMERA
            elif source.isdigit():
                stream_type = StreamType.WEBCAM
            else:
                stream_type = StreamType.VIDEO_FILE
        
        # Create appropriate stream
        if stream_type == StreamType.VIDEO_FILE:
            return VideoFileStream(source)
        elif stream_type == StreamType.RTSP_CAMERA:
            return RTSPStream(source)
        elif stream_type == StreamType.WEBCAM:
            return WebcamStream(int(source))
        else:
            raise ValueError(f"Unknown stream type: {stream_type}")
            
    except Exception as e:
        print(f" Failed to create stream: {str(e)}")
        return None
