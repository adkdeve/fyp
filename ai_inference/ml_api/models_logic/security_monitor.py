import os
import cv2
import time
import uuid
import numpy as np
import logging
from collections import deque

logger = logging.getLogger(__name__)
from typing import Callable, Dict, Tuple, List, Union
from tqdm import tqdm

from .face_recognition import load_known_embeddings, detect_faces_in_frame
from .fire_smoke_detector import load_fire_smoke_model, annotate_fire_smoke
from .safe_zone import load_yolo_model
from shapely.geometry import Polygon
import threading
import queue



def _resolve_video_source(source: Union[str, int], base_dir: str = None) -> List[Union[str, int]]:
    """Resolve video source path robustly."""
    if isinstance(source, int):
        return [int(source)]
    if isinstance(source, str) and source.isdigit():
        return [int(source)]
    
    if base_dir is None:
        base_dir = os.path.dirname(os.path.dirname(__file__))
        
    candidates = [
        source,
        os.path.join(base_dir, source),
        os.path.join(base_dir, "data", "input_videos", os.path.basename(source)),
    ]
    return candidates

def _open_video_capture(source: Union[str, int, List[Union[str, int]]], backend_preference: int = None) -> cv2.VideoCapture:
    """Try to open a video capture from a source or list of candidate sources."""
    if not isinstance(source, list):
        candidates = [source]
    else:
        candidates = source

    for vp in candidates:
        cap = None
        if isinstance(vp, int):
            # Prefer DSHOW for windows webcam if not specified
            backend = backend_preference
            if backend is None:
                backend = getattr(cv2, 'CAP_DSHOW', getattr(cv2, 'CAP_MSMF', getattr(cv2, 'CAP_ANY', 0)))
            cap = cv2.VideoCapture(vp, backend)
        else:
            # For files/IP cams
            backend = backend_preference
            if backend is None:
                # IP camera - FFmpeg is usually best
                backend = getattr(cv2, 'CAP_FFMPEG', getattr(cv2, 'CAP_ANY', 0))
            cap = cv2.VideoCapture(vp, backend)
            
        if cap.isOpened():
            return cap
        else:
            cap.release()
            
    raise RuntimeError(f"Cannot open video source. Tried: {candidates}")

def _iou_xywh(a, b):
    ax, ay, aw, ah = a
    bx, by, bw, bh = b
    ax2, ay2 = ax + aw, ay + ah
    bx2, by2 = bx + bw, by + bh
    inter_x1, inter_y1 = max(ax, bx), max(ay, by)
    inter_x2, inter_y2 = min(ax2, bx2), min(ay2, by2)
    iw, ih = max(0, inter_x2 - inter_x1), max(0, inter_y2 - inter_y1)
    inter = iw * ih
    union = aw * ah + bw * bh - inter
    if union <= 0:
        return 0.0
    return inter / union

def _iou_xyxy(a, b):
    ax1, ay1, ax2, ay2 = a
    bx1, by1, bx2, by2 = b
    inter_x1, inter_y1 = max(ax1, bx1), max(ay1, by1)
    inter_x2, inter_y2 = min(ax2, bx2), min(ay2, by2)
    iw, ih = max(0, inter_x2 - inter_x1), max(0, inter_y2 - inter_y1)
    inter = iw * ih
    area_a = (ax2 - ax1) * (ay2 - ay1)
    area_b = (bx2 - bx1) * (by2 - by1)
    union = max(area_a + area_b - inter, 1)
    return inter / union


class ThreadedCamera:
    """Read frames in a background thread to eliminate acquisition delay."""
    def __init__(self, source):
        self.source = source
        # Open camera with best backend
        self.cap = _open_video_capture(source)
        
        self.cap.set(cv2.CAP_PROP_BUFFERSIZE, 1)
        self.ok, self.frame = self.cap.read()
        self.stopped = False
        self.lock = threading.Lock()
        self.thread = threading.Thread(target=self.update, args=(), daemon=True)
        self.thread.start()

    def update(self):
        while not self.stopped:
            ok, frame = self.cap.read()
            
            # Reconnection logic for live streams
            if not ok:
                is_live = False
                try:
                    # check for the large value user mentioned (18446744073709551615) which is uint64 -1
                    count = self.cap.get(cv2.CAP_PROP_FRAME_COUNT)
                    if count >= 1.8e19 or count == -1:
                        is_live = True
                except:
                    pass
                
                # Also rely on source type
                if isinstance(self.source, int): 
                    is_live = True
                elif isinstance(self.source, str) and (self.source.startswith("rtsp") or self.source.startswith("http") or self.source.isdigit()):
                    is_live = True

                if is_live:
                    logger.warning("Video stream disconnected/ended. Attempting to reconnect...")
                    time.sleep(1.0)
                    try:
                        self.cap.release()
                        self.cap = _open_video_capture(self.source)
                        self.cap.set(cv2.CAP_PROP_BUFFERSIZE, 1)
                        continue
                    except Exception as e:
                        logger.error(f"Reconnection attempt failed: {e}")
            
            with self.lock:
                self.ok = ok
                if ok:
                    self.frame = frame
            if not ok:
                time.sleep(0.01)

    def read(self):
        with self.lock:
            if self.frame is None:
                return False, None
            return self.ok, self.frame.copy()

    def release(self):
        self.stopped = True
        if self.thread.is_alive():
            self.thread.join(timeout=1.0)
        self.cap.release()


class InferenceThread:
    """Runs YOLO inference in a background thread."""
    def __init__(self, yolo_model, frame_queue_size=1):
        self.yolo = yolo_model
        self.frame_queue = queue.Queue(maxsize=frame_queue_size)
        self.result_lock = threading.Lock()
        self.latest_results = []
        self.stopped = False
        self.thread = threading.Thread(target=self.run, daemon=True)
        self.thread.start()

    def update_frame(self, frame):
        """Put a new frame into the queue, overwriting if full."""
        if not self.frame_queue.empty():
            try:
                self.frame_queue.get_nowait()
            except queue.Empty:
                pass
        self.frame_queue.put(frame)

    def get_results(self):
        with self.result_lock:
            return self.latest_results

    def run(self):
        while not self.stopped:
            try:
                frame = self.frame_queue.get(timeout=0.1)
            except queue.Empty:
                continue
            
            try:
                # Run inference
                results = self.yolo(frame, verbose=False, conf=0.5)
                # Parse results immediately to simple list of boxes
                parsed_results = []
                for r in results:
                    for box in getattr(r, 'boxes', []):
                         parsed_results.append(box)
                
                with self.result_lock:
                    self.latest_results = parsed_results
            except Exception as e:
                logger.error(f"Inference error: {e}")
            
    def stop(self):
        self.stopped = True
        if self.thread.is_alive():
             self.thread.join(timeout=1.0)


class FaceRecognitionThread:
    """Runs face recognition inference in a background thread."""
    def __init__(self, known_names, known_embs, mtcnn, resnet, frame_queue_size=1):
        self.known_names = known_names
        self.known_embs = known_embs
        self.mtcnn = mtcnn
        self.resnet = resnet
        self.frame_queue = queue.Queue(maxsize=frame_queue_size)
        self.result_lock = threading.Lock()
        self.latest_results = {}  # dict of (x1,y1,x2,y2) -> label
        self.stopped = False
        self.thread = threading.Thread(target=self.run, daemon=True)
        self.thread.start()

    def update_frame(self, frame):
        """Put a new frame into the queue, overwriting if full."""
        if not self.frame_queue.empty():
            try:
                self.frame_queue.get_nowait()
            except queue.Empty:
                pass
        self.frame_queue.put(frame)

    def get_results(self):
        with self.result_lock:
            return self.latest_results.copy()

    def run(self):
        while not self.stopped:
            try:
                frame = self.frame_queue.get(timeout=0.1)
            except queue.Empty:
                continue
            
            try:
                # Run face detection and recognition
                face_results, _ = detect_faces_in_frame(
                    frame, self.known_names, self.known_embs, 
                    self.mtcnn, self.resnet, sim_threshold=0.65
                )
                with self.result_lock:
                    self.latest_results = face_results
            except Exception as e:
                logger.error(f"Face recognition error: {e}")
            
    def stop(self):
        self.stopped = True
        if self.thread.is_alive():
             self.thread.join(timeout=1.0)


class FireSmokeThread:
    """Runs fire/smoke detection inference in a background thread."""
    def __init__(self, fire_smoke_model, frame_queue_size=1):
        self.model = fire_smoke_model
        self.frame_queue = queue.Queue(maxsize=frame_queue_size)
        self.result_lock = threading.Lock()
        self.latest_results = []  # list of (x1,y1,x2,y2,label)
        self.stopped = False
        self.thread = threading.Thread(target=self.run, daemon=True)
        self.thread.start()

    def update_frame(self, frame):
        """Put a new frame into the queue, overwriting if full."""
        if not self.frame_queue.empty():
            try:
                self.frame_queue.get_nowait()
            except queue.Empty:
                pass
        self.frame_queue.put(frame)

    def get_results(self):
        with self.result_lock:
            return list(self.latest_results)

    def run(self):
        while not self.stopped:
            try:
                frame = self.frame_queue.get(timeout=0.1)
            except queue.Empty:
                continue
            
            try:
                if self.model is None:
                    continue
                # Run fire/smoke detection
                results = self.model(frame, verbose=False)
                parsed_results = []
                for r in results:
                    for box in getattr(r, 'boxes', []):
                        x1, y1, x2, y2 = map(int, box.xyxy[0])
                        cls = int(box.cls[0])
                        label = self.model.names.get(cls, str(cls))
                        parsed_results.append((x1, y1, x2, y2, label))
                
                with self.result_lock:
                    self.latest_results = parsed_results
            except Exception as e:
                logger.error(f"Fire/smoke detection error: {e}")
            
    def stop(self):
        self.stopped = True
        if self.thread.is_alive():
             self.thread.join(timeout=1.0)


class RoomMonitor:

    def __init__(self,
                 camera_index: Union[int, str] = 0,
                 min_motion_area: int = 500,
                 motion_cooldown_s: float = 1.0,
                 tracker_type: str = "KCF",
                 reid_interval_frames: int = 30,
                 sim_threshold: float = 0.80,
                 snapshot_dir: str = None):
        self.camera_index = camera_index
        self.min_motion_area = min_motion_area
        self.motion_cooldown_s = motion_cooldown_s
        self.reid_interval_frames = reid_interval_frames
        self.sim_threshold = sim_threshold
        self.bgsub = cv2.createBackgroundSubtractorMOG2(history=500, varThreshold=16, detectShadows=True)
        self.last_motion_ts = 0.0
        self.trackers: Dict[int, cv2.Tracker] = {}
        self.track_meta: Dict[int, Dict] = {}
        self.next_track_id = 1
        self.tracker_type = tracker_type.upper()
        self.frame_index = 0

        base_dir = os.path.dirname(os.path.dirname(__file__))
        self.snapshot_dir = snapshot_dir or os.path.join(base_dir, "data", "captures")
        os.makedirs(self.snapshot_dir, exist_ok=True)

        self.snapshot_dir = snapshot_dir or os.path.join(base_dir, "data", "captures")
        os.makedirs(self.snapshot_dir, exist_ok=True)

        # Load YOLO model for Safe Zone / Person Detection
        self.yolo = load_yolo_model()
        self.safe_zone_polygon = None
        self.safe_zone_points_norm = None
        
        # Start Inference Thread for Safe Zone (YOLO person detection)
        self.inference_thread = InferenceThread(self.yolo)
        
        # Load Face Recognition models
        logger.info("Loading face recognition models...")
        try:
            self.known_names, self.known_embs, self.mtcnn, self.resnet = load_known_embeddings()
            self.face_recognition_thread = FaceRecognitionThread(
                self.known_names, self.known_embs, self.mtcnn, self.resnet
            )
            logger.info("Face recognition models loaded successfully")
        except Exception as e:
            logger.error(f"Failed to load face recognition models: {e}")
            self.known_names, self.known_embs, self.mtcnn, self.resnet = [], [], None, None
            self.face_recognition_thread = None
        
        # Load Fire/Smoke detection model
        logger.info("Loading fire/smoke detection model...")
        try:
            self.fire_smoke_model = load_fire_smoke_model()
            if self.fire_smoke_model:
                self.fire_smoke_thread = FireSmokeThread(self.fire_smoke_model)
                logger.info("Fire/smoke detection model loaded successfully")
            else:
                logger.warning("Fire/smoke model not found (weights/best.pt missing)")
                self.fire_smoke_thread = None
        except Exception as e:
            logger.error(f"Failed to load fire/smoke model: {e}")
            self.fire_smoke_model = None
            self.fire_smoke_thread = None
        
        self.active_models = {
            "face_recognition": True,
            "fire_smoke": False,
            "safe_zone": True
        }

    def set_model_status(self, status: Dict[str, bool]):
        self.active_models.update(status)
        logger.info(f"Updated model status: {self.active_models}")

    def release(self):
        """Release resources including background threads."""
        if hasattr(self, 'inference_thread') and self.inference_thread:
            self.inference_thread.stop()
        if hasattr(self, 'face_recognition_thread') and self.face_recognition_thread:
            self.face_recognition_thread.stop()
        if hasattr(self, 'fire_smoke_thread') and self.fire_smoke_thread:
            self.fire_smoke_thread.stop()

    def set_safe_zone(self, points: List[Tuple[float, float]]):
        """Set the safe zone polygon from a list of normalized (0.0-1.0) (x, y) points."""
        if points and len(points) >= 3:
            # Store normalized points, polygon will be created in process loop based on frame size
            self.safe_zone_points_norm = points
            self.safe_zone_polygon = None # Invalidated, will be recreated
            logger.info(f"Safe zone points set (normalized): {len(points)} points.")
        else:
            self.safe_zone_points_norm = None
            self.safe_zone_polygon = None

    def _make_tracker(self):
        # Support for both old and new OpenCV versions
        # In newer OpenCV (4.5+), trackers are in cv2.legacy
        legacy = getattr(cv2, 'legacy', None)
        
        if self.tracker_type == "KCF":
            if legacy and hasattr(legacy, 'TrackerKCF_create'):
                return legacy.TrackerKCF_create()
            elif hasattr(cv2, 'TrackerKCF_create'):
                return cv2.TrackerKCF_create()
        if self.tracker_type == "MOSSE":
            if legacy and hasattr(legacy, 'TrackerMOSSE_create'):
                return legacy.TrackerMOSSE_create()
            elif hasattr(cv2, 'TrackerMOSSE_create'):
                return cv2.TrackerMOSSE_create()
        # Default to CSRT
        if legacy and hasattr(legacy, 'TrackerCSRT_create'):
            return legacy.TrackerCSRT_create()
        elif hasattr(cv2, 'TrackerCSRT_create'):
            return cv2.TrackerCSRT_create()
        
        # Fallback: try MIL tracker which is usually available
        if legacy and hasattr(legacy, 'TrackerMIL_create'):
            return legacy.TrackerMIL_create()
        elif hasattr(cv2, 'TrackerMIL_create'):
            return cv2.TrackerMIL_create()
        
        raise RuntimeError("No suitable OpenCV tracker found. Please install opencv-contrib-python.")

    def _detect_motion(self, frame):
        # Downscale for performance
        h, w = frame.shape[:2]
        scale_width = 320
        if w > scale_width:
            scale = scale_width / float(w)
            small = cv2.resize(frame, (scale_width, int(h * scale)))
        else:
            small = frame
            
        fg = self.bgsub.apply(small)
        _, thresh = cv2.threshold(fg, 244, 255, cv2.THRESH_BINARY)
        kernel = np.ones((3, 3), np.uint8)
        thresh = cv2.morphologyEx(thresh, cv2.MORPH_OPEN, kernel, iterations=1)
        thresh = cv2.dilate(thresh, kernel, iterations=2)
        contours, _ = cv2.findContours(thresh, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
        has_motion = False
        for c in contours:
            if cv2.contourArea(c) >= self.min_motion_area:
                has_motion = True
                # Optional: draw motion rects on frame for debug? 
                # Since we have 'small' frame here but want to draw on 'frame', we need to scale up coords
                # For now let's just return True
                break
        return has_motion

    def _save_snapshot(self, frame, label: str) -> str:
        fname = f"{int(time.time())}_{uuid.uuid4().hex[:8]}_{label.replace(' ', '_')}.jpg"
        fpath = os.path.join(self.snapshot_dir, fname)
        cv2.imwrite(fpath, frame)
        return fpath

    def _init_or_update_tracks(self, frame, detections: Dict[Tuple[int, int, int, int], str]):
        assigned = set()
        frame_h, frame_w = frame.shape[:2]
        
        for (x1, y1, x2, y2), label in detections.items():
            w, h = x2 - x1, y2 - y1
            
            # Validate bounding box - skip if invalid
            if w <= 0 or h <= 0:
                continue
            if w < 10 or h < 10:  # Minimum size for tracker to work
                continue
            
            # Clamp coordinates to frame boundaries
            x1 = max(0, min(x1, frame_w - 1))
            y1 = max(0, min(y1, frame_h - 1))
            w = min(w, frame_w - x1)
            h = min(h, frame_h - y1)
            
            # Skip if clamped bbox is too small
            if w < 10 or h < 10:
                continue
                
            bbox = (x1, y1, w, h)
            best_tid = None
            best_iou = 0.0
            for tid, meta in self.track_meta.items():
                tb = meta.get("bbox", None)
                if tb is None:
                    continue
                iou = self._bbox_iou(bbox, tb)
                if iou > best_iou:
                    best_iou, best_tid = iou, tid
            if best_tid is not None and best_iou > 0.3:
                self.track_meta[best_tid]["bbox"] = bbox
                self.track_meta[best_tid]["last_seen"] = time.time()
                if label != "Unknown":
                    self.track_meta[best_tid]["label"] = label
                    self.track_meta[best_tid]["authorized"] = label in self.authorized_set
                assigned.add(best_tid)
            else:
                try:
                    tracker = self._make_tracker()
                    ok = tracker.init(frame, bbox)
                    if not ok:
                        continue
                except Exception as e:
                    logger.warning(f"Failed to initialize tracker for bbox {bbox}: {e}")
                    continue
                    
                tid = self.next_track_id
                self.next_track_id += 1
                self.trackers[tid] = tracker
                self.track_meta[tid] = {
                    "label": label,
                    "authorized": label in self.authorized_set,
                    "first_seen": time.time(),
                    "last_seen": time.time(),
                    "bbox": bbox,
                    "frames": 0,
                }
                assigned.add(tid)
        return assigned

    @staticmethod
    def _bbox_iou(a, b):
        return _iou_xywh(a, b)

    def generate_frames(self, event_queue=None, lite_mode=True):
        """Generate MJPEG frames for streaming using ThreadedCamera for smoothness."""
        # Optimized configuration
        TARGET_FPS = 20
        MIN_FRAME_INTERVAL = 1.0 / TARGET_FPS
        JPEG_QUALITY = 65
        
        tcap = ThreadedCamera(self.camera_index)
        
        fps_start = time.time()
        fps_frames = 0
        current_fps = 0.0
        
        try:
            while True:
                loop_start = time.time()
                
                ok, frame = tcap.read()
                if not ok or frame is None:
                    # Give it a moment to recover
                    time.sleep(0.1)
                    continue

                # --- Push frames to all active model threads (non-blocking) ---
                
                # Safe Zone / Person Detection (YOLO)
                if self.active_models.get("safe_zone", True):
                    self.inference_thread.update_frame(frame)
                
                # Face Recognition
                if self.active_models.get("face_recognition", False) and self.face_recognition_thread:
                    self.face_recognition_thread.update_frame(frame)
                
                # Fire/Smoke Detection
                if self.active_models.get("fire_smoke", False) and self.fire_smoke_thread:
                    self.fire_smoke_thread.update_frame(frame)
                
                # --- Draw results from all active models ---
                
                person_count = 0
                active_modes = []
                
                # Safe Zone Detection
                if self.active_models.get("safe_zone", True):
                    active_modes.append("SafeZone")
                    self._last_results = self.inference_thread.get_results()
                    
                    # Create/update safe zone polygon BEFORE the person loop
                    if getattr(self, 'safe_zone_points_norm', None):
                        fh, fw = frame.shape[:2]
                        if not hasattr(self, '_sz_poly_cache_dim') or self._sz_poly_cache_dim != (fw, fh):
                            try:
                                scaled_points = [(p[0] * fw, p[1] * fh) for p in self.safe_zone_points_norm]
                                self.safe_zone_polygon = Polygon(scaled_points)
                                self._sz_poly_cache_dim = (fw, fh)
                                logger.info(f"Safe zone polygon created with {len(scaled_points)} points")
                            except Exception as e:
                                logger.error(f"Failed to scale safe zone polygon: {e}")
                                self.safe_zone_polygon = None
                    
                    for box in self._last_results:
                        cls = int(box.cls[0])
                        class_name = self.yolo.names.get(cls, str(cls))
                        
                        if class_name == "person":
                            color = (0, 255, 0)  # Green for person
                            label = "Person"
                            person_count += 1
                        else:
                            continue  # Skip non-persons
                            
                        x1, y1, x2, y2 = [int(v) for v in box.xyxy[0]]
                        
                        # Check if person is inside safe zone
                        if self.safe_zone_polygon:
                            person_poly = Polygon([(x1, y1), (x2, y1), (x2, y2), (x1, y2)])
                            if self.safe_zone_polygon.intersects(person_poly):
                                label = "Safe"
                                color = (0, 255, 0)
                            else:
                                label = "Unsafe"
                                color = (0, 0, 255)
                        
                        cv2.rectangle(frame, (x1, y1), (x2, y2), color, 2)
                        cv2.putText(frame, label, (x1, max(20, y1 - 10)), cv2.FONT_HERSHEY_SIMPLEX, 0.7, color, 2)

                    # Draw Safe Zone Polygon (always draw if it exists)
                    if self.safe_zone_polygon:
                        try:
                            pts = np.array(self.safe_zone_polygon.exterior.coords, np.int32)
                            cv2.polylines(frame, [pts], True, (255, 255, 0), 2)
                        except Exception as e:
                            logger.error(f"Failed to draw safe zone polygon: {e}")
                else:
                    self.safe_zone_polygon = None

                
                # Face Recognition
                if self.active_models.get("face_recognition", False) and self.face_recognition_thread:
                    active_modes.append("FaceRec")
                    face_results = self.face_recognition_thread.get_results()
                    
                    for (x1, y1, x2, y2), label in face_results.items():
                        if label == "Unknown":
                            color = (0, 0, 255)  # Red for unknown
                        else:
                            color = (0, 255, 0)  # Green for recognized
                        
                        cv2.rectangle(frame, (x1, y1), (x2, y2), color, 2)
                        cv2.putText(frame, label, (x1, max(20, y1 - 10)), cv2.FONT_HERSHEY_SIMPLEX, 0.7, color, 2)
                
                # Fire/Smoke Detection
                if self.active_models.get("fire_smoke", False) and self.fire_smoke_thread:
                    active_modes.append("Fire/Smoke")
                    fire_smoke_results = self.fire_smoke_thread.get_results()
                    
                    for (x1, y1, x2, y2, label) in fire_smoke_results:
                        color = (0, 140, 255)  # Orange for fire/smoke
                        cv2.rectangle(frame, (x1, y1), (x2, y2), color, 2)
                        cv2.putText(frame, label, (x1, max(20, y1 - 10)), cv2.FONT_HERSHEY_SIMPLEX, 0.7, color, 2)

                # Update FPS
                fps_frames += 1
                if time.time() - fps_start >= 1.0:
                    current_fps = fps_frames / (time.time() - fps_start)
                    fps_frames = 0
                    fps_start = time.time()

                # Debug Info Overlay
                mode_str = ", ".join(active_modes) if active_modes else "None"
                debug_info = f"FPS: {current_fps:.1f} | Persons: {person_count} | Models: {mode_str}"
                cv2.putText(frame, debug_info, (10, frame.shape[0] - 10), cv2.FONT_HERSHEY_SIMPLEX, 0.6, (0, 255, 255), 2)
                
                # --- Detection Logic End ---
                
                # Standard JPEG encoding
                ret, buffer = cv2.imencode('.jpg', frame, [cv2.IMWRITE_JPEG_QUALITY, JPEG_QUALITY])
                if ret:
                    yield (b'--frame\r\n'
                           b'Content-Type: image/jpeg\r\n\r\n' + buffer.tobytes() + b'\r\n')
                
                # Throttling to maintain consistent heartbeat
                elapsed = time.time() - loop_start
                if elapsed < MIN_FRAME_INTERVAL:
                    time.sleep(MIN_FRAME_INTERVAL - elapsed)
                    
        except GeneratorExit:
            logger.info("Stream consumer disconnected")
        except Exception as e:
            logger.error(f"Streaming error: {e}")
        finally:
            tcap.release()



    def run(self, display: bool = True, on_event: Callable[[str, Dict], None] = None):
        cap = _open_video_capture(self.camera_index)

        try:
            cap.set(cv2.CAP_PROP_BUFFERSIZE, 1)
            fourcc = cv2.VideoWriter_fourcc(*'MJPG')
            cap.set(cv2.CAP_PROP_FOURCC, fourcc)
            cap.set(cv2.CAP_PROP_FPS, 30)
        except Exception:
            pass

        win = "Room Monitor"
        if display:
            try:
                cv2.namedWindow(win, cv2.WINDOW_NORMAL)
            except Exception:
                display = False

        while True:
            ok, frame = cap.read()
            if not ok or frame is None:
                break
            self.frame_index += 1

            motion = self._detect_motion(frame)
            now = time.time()
            do_face = False
            if motion and (now - self.last_motion_ts) >= self.motion_cooldown_s:
                self.last_motion_ts = now
                do_face = True

            for tid in list(self.trackers.keys()):
                tracker = self.trackers[tid]
                ok, new_box = tracker.update(frame)
                if ok:
                    x, y, w, h = new_box
                    self.track_meta[tid]["bbox"] = (int(x), int(y), int(w), int(h))
                    self.track_meta[tid]["last_seen"] = now
                    self.track_meta[tid]["frames"] += 1
                    if self.frame_index % self.reid_interval_frames == 0:
                        x1, y1, w, h = self.track_meta[tid]["bbox"]
                        x2, y2 = x1 + w, y1 + h
                        crop = frame[y1:y2, x1:x2]
                        if crop.size > 0:
                            dets, labels = detect_faces_in_frame(frame, self.known_names, self.known_embs, self.mtcnn, self.resnet, sim_threshold=self.sim_threshold)
                            if labels:
                                label = labels[0]
                                if label != "Unknown":
                                    self.track_meta[tid]["label"] = label
                                    self.track_meta[tid]["authorized"] = label in self.authorized_set
                else:
                    del self.trackers[tid]
                    meta = self.track_meta.pop(tid, None)
                    if meta and on_event:
                        on_event("exit", {"track_id": tid, **meta})

            if do_face and self.active_models.get("face_recognition", True):
                detections, labels = detect_faces_in_frame(frame, self.known_names, self.known_embs, self.mtcnn, self.resnet, sim_threshold=self.sim_threshold)
                assigned = self._init_or_update_tracks(frame, detections)
                if labels:
                    best_label = labels[0]
                    snap_path = self._save_snapshot(frame, best_label)
                    if on_event:
                        for tid in assigned:
                            meta = self.track_meta.get(tid, {}).copy()
                            meta.update({"track_id": tid, "snapshot": snap_path})
                            evt = "enter" if meta.get("frames", 0) == 0 else "update"
                            on_event(evt, meta)
                        if best_label == "Unknown":
                            on_event("unauthorized_detected", {"label": best_label, "snapshot": snap_path})
                        else:
                            on_event("authorized_detected", {"label": best_label, "snapshot": snap_path})

            if display:
                for tid, meta in self.track_meta.items():
                    x, y, w, h = meta.get("bbox", (0, 0, 0, 0))
                    x2, y2 = x + w, y + h
                    label = meta.get("label", "Unknown")
                    color = (0, 255, 0) if meta.get("authorized", False) else (0, 0, 255)
                    cv2.rectangle(frame, (x, y), (x2, y2), color, 2)
                    cv2.putText(frame, f"{label} #{tid}", (x, max(20, y - 10)), cv2.FONT_HERSHEY_SIMPLEX, 0.7, color, 2)
                cv2.imshow(win, frame)
                k = cv2.waitKey(1) & 0xFF
                if k in (27, ord('q'), ord('Q')):
                    break

        cap.release()
        if display:
            cv2.destroyAllWindows()


def run_video_capture(video_path: str, save_dir: str = None, frame_interval: int = 5, sim_threshold: float = 0.65):
    """Process a video file, detect faces, and save cropped face images.

    - video_path: path to input video file
    - save_dir: base directory to save crops (default: data/captures/faces)
    - frame_interval: process every Nth frame to speed up
    """
    base_dir = os.path.dirname(os.path.dirname(__file__))
    out_dir = save_dir or os.path.join(base_dir, "data", "captures", "faces")
    os.makedirs(out_dir, exist_ok=True)

    known_names, known_embs, mtcnn, resnet = load_known_embeddings()

    # Resolve video path robustly
    candidate_paths = _resolve_video_source(video_path)
    cap = _open_video_capture(candidate_paths)

    frame_idx = 0
    saved = 0
    while True:
        ok, frame = cap.read()
        if not ok or frame is None:
            break
        frame_idx += 1
        if frame_interval > 1 and (frame_idx % frame_interval) != 0:
            continue

        detections, labels = detect_faces_in_frame(frame, known_names, known_embs, mtcnn, resnet, sim_threshold=sim_threshold)
        ts = int(time.time())
        for (x1, y1, x2, y2), label in detections.items():
            x1, y1 = max(0, x1), max(0, y1)
            crop = frame[y1:y2, x1:x2]
            if crop.size == 0:
                continue
            safe_label = (label or "Unknown").strip().replace("/", "_").replace("\\", "_").replace(":", "_").replace(" ", "_")
            label_dir = os.path.join(out_dir, safe_label)
            os.makedirs(label_dir, exist_ok=True)
            fname = f"{safe_label}_{ts}_f{frame_idx}.jpg"
            fpath = os.path.join(label_dir, fname)
            cv2.imwrite(fpath, crop)
            saved += 1

    cap.release()
    print(f"Saved {saved} face crops to: {out_dir}")
    return out_dir


def run_video_auth_track(video_source,
                         output_name: str = None,
                         frame_interval: int = 1,
                         face_detect_interval: int = 3,
                         person_conf: float = 0.25,
                         sim_threshold: float = 0.50,
                         recog_threshold: int = 15,
                         unknown_threshold: int = 60,
                         min_face_size: int = 20):
    """Process a video to:
    - perform face recognition
    - once a track gets N successful recognitions (default 15), stop face rec for it
    - switch to YOLO person tracking with the person's name over the body box
    - save annotated output video
    - supports both video file path and integer camera index
    
    
    face_detect_interval: run face detection every N frames to speed up processing (default: 3)
    recog_threshold: number of face recognitions needed before switching to body tracking (default: 15)
    unknown_threshold: number of frames labeled as "Unknown" before switching to body tracking (default: 60)
    """
    base_dir = os.path.dirname(os.path.dirname(__file__))
    out_dir = os.path.join(base_dir, "data", "output_videos")
    os.makedirs(out_dir, exist_ok=True)

    # Resolve video path robustly (reuse logic)
    candidate_paths = _resolve_video_source(video_source)
    is_live = isinstance(candidate_paths[0], int) # heuristic: if resolved to int, it's live
        
    cap = _open_video_capture(candidate_paths)

    # Load models
    known_names, known_embs, mtcnn, resnet = load_known_embeddings()
    yolo = load_yolo_model()
    if yolo is None:
        raise RuntimeError("YOLO model failed to load for person tracking")

    ok, first_frame = cap.read()
    if not ok or first_frame is None:
        cap.release()
        raise RuntimeError("Could not read the first frame of the video")

    h, w = first_frame.shape[:2]
    fps = int(cap.get(cv2.CAP_PROP_FPS)) or 25
    if isinstance(video_source, int):
        basename = f"camera_{video_source}"
    else:
        basename = os.path.splitext(os.path.basename(video_source))[0]
    output_name = output_name or f"{basename}_auth_track.mp4"
    out_path = os.path.join(out_dir, output_name)
    fourcc = cv2.VideoWriter_fourcc(*'mp4v')
    out = cv2.VideoWriter(out_path, fourcc, fps, (w, h))

    # Entity management
    next_id = 1
    entities = {}  # id -> dict(state, name, face_box, body_box, recog_count, last_seen)



    # process first frame (rewind if file)
    if not is_live:
        cap.set(cv2.CAP_PROP_POS_FRAMES, 0)
        
    frame_idx = 0
    total_frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT)) or 0
    pbar = tqdm(total=total_frames, desc="Processing Auth Track", unit="frame") if total_frames > 0 and not is_live else None
    
    if is_live:
        print("\n Webcam started. Press 'q' or ESC to stop.")
        cv2.namedWindow("Auth Tracking (Live)", cv2.WINDOW_NORMAL)
        
    MIN_FACE_SIZE = min_face_size  # minimum width/height for a valid face box
    while True:
        ok, frame = cap.read()
        if not ok or frame is None:
            break
        frame_idx += 1

        # Update progress bar
        if pbar is not None:
            pbar.update(1)
        if frame_interval > 1 and (frame_idx % frame_interval) != 0:
            # still write original frame to maintain fps
            out.write(frame)
            continue

        # reset visibility flags this frame
        for ent in entities.values():
            ent["seen"] = False

        # Pre-compute active body boxes before face detection to suppress overlaps
        body_boxes_active = [ent.get("body_box") for ent in entities.values() if ent.get("state") == "body" and ent.get("body_box") is not None]

        # Track which entities are in face state (need face detection updates)
        face_state_entities = [ent for ent in entities.values() if ent.get("state") == "face"]

        # Run face detection only every N frames to speed up processing
        run_face_detect_this_frame = (frame_idx % face_detect_interval == 0) or len(entities) == 0
        
        detections = {}
        if run_face_detect_this_frame:
            # Create a copy of frame for detection and mask out active body boxes
            detect_frame = frame.copy()
            for (bx1, by1, bx2, by2) in body_boxes_active:
                # Mask out the body region so face detection acts as if it's empty space
                detect_frame[by1:by2, bx1:bx2] = 0

            # Run face detection on the masked frame
            all_detections, labels = detect_faces_in_frame(detect_frame, known_names, known_embs, mtcnn, resnet, sim_threshold=sim_threshold)
            # Filter out small boxes and those overlapping with body boxes
            for (fx1, fy1, fx2, fy2), lbl in all_detections.items():
                fw, fh = fx2 - fx1, fy2 - fy1
                if fw < MIN_FACE_SIZE or fh < MIN_FACE_SIZE:
                    continue
                # Double check overlap with body boxes
                skip_detection = False
                for bb in body_boxes_active:
                    if _iou_xyxy((fx1, fy1, fx2, fy2), bb) > 0.1:
                        skip_detection = True
                        break
                if not skip_detection:
                    detections[(fx1, fy1, fx2, fy2)] = lbl

        used_face = set()
        # Match face detections to existing face-state entities by IOU
        for ent_id, ent in list(entities.items()):
            if ent.get("state", "face") != "face":
                continue
            best = None
            best_iou = 0.0
            for (x1, y1, x2, y2), label in detections.items():
                if ((x1, y1, x2, y2) in used_face):
                    continue
                if ent.get("face_box") is not None:
                    iou = _iou_xyxy(ent["face_box"], (x1, y1, x2, y2))
                else:
                    iou = 0.0
                if iou > best_iou:
                    best_iou = iou
                    best = ((x1, y1, x2, y2), label)
            if best is not None and best_iou > 0.3:
                (x1, y1, x2, y2), label = best
                ent["face_box"] = (x1, y1, x2, y2)
                ent["last_seen"] = frame_idx
                ent["seen"] = True
                used_face.add((x1, y1, x2, y2))
                if label != "Unknown":
                    ent["name"] = label
                    ent["recog_count"] = ent.get("recog_count", 0) + 1
                    ent["unknown_count"] = 0  # Reset unknown count if recognized
                else:
                    # If label is Unknown, increment counter
                    ent["unknown_count"] = ent.get("unknown_count", 0) + 1

            # promote to body tracking after reaching recog_threshold recognitions
            if ent.get("recog_count", 0) >= recog_threshold and ent.get("state") == "face":
                ent["state"] = "body"
            
            # promote to body tracking (Unknown/Red Box) if unknown_threshold reached
            if ent.get("unknown_count", 0) >= unknown_threshold and ent.get("state") == "face":
                 ent["state"] = "body"

        # New face entities for unmatched face detections (after suppression)
        for (x1, y1, x2, y2), label in detections.items():
            if (x1, y1, x2, y2) in used_face:
                continue
            # avoid seeding a new face entity if it overlaps a body track
            skip_new = False
            for bb in body_boxes_active:
                if _iou_xyxy((x1, y1, x2, y2), bb) > 0.2:
                    skip_new = True
                    break
            if skip_new:
                continue
            
            # Check if there's an existing face entity with the same name that can be resumed
            # This preserves recognition progress when a face temporarily disappears
            existing_match = None
            if label != "Unknown":
                for ent_id, ent in entities.items():
                    if ent.get("state") == "face" and ent.get("name") == label and not ent.get("seen"):
                        existing_match = ent_id
                        break
            
            if existing_match is not None:
                # Resume existing entity with same name
                ent = entities[existing_match]
                ent["face_box"] = (x1, y1, x2, y2)
                ent["last_seen"] = frame_idx
                ent["seen"] = True
                ent["miss"] = 0
                ent["recog_count"] = ent.get("recog_count", 0) + 1
                used_face.add((x1, y1, x2, y2))
            else:
                # Create new entity
                ent_id = next_id
                next_id += 1
                entities[ent_id] = {
                    "state": "face",
                    "name": label if label != "Unknown" else None,
                    "face_box": (x1, y1, x2, y2),
                    "body_box": None,
                    "recog_count": 1 if label != "Unknown" else 0,
                    "unknown_count": 1 if label == "Unknown" else 0,
                    "last_seen": frame_idx,
                    "seen": True,
                    "miss": 0,
                }

        # 2) For entities in 'body' state, run YOLO person detection and associate
        if entities:
            yolo_results = yolo(frame, verbose=False, conf=person_conf)
            person_boxes = []
            for r in yolo_results:
                for box in getattr(r, 'boxes', []):
                    cls = int(box.cls[0])
                    name = yolo.names.get(cls, str(cls)) if hasattr(yolo, 'names') else None
                    if name != "person":
                        continue
                    x1, y1, x2, y2 = [int(v) for v in box.xyxy[0]]
                    person_boxes.append((x1, y1, x2, y2))

            for ent_id, ent in entities.items():
                if ent.get("state") != "body":
                    continue
                # associate by IOU with previous body_box, fallback to face_box region inflation
                ref_box = ent.get("body_box")
                if ref_box is None and ent.get("face_box") is not None:
                    # Inflate face box to estimate body region (face is ~1/7 of body height)
                    fx1, fy1, fx2, fy2 = ent["face_box"]
                    face_h = fy2 - fy1
                    face_w = fx2 - fx1
                    # Estimate body box: center on face, expand downward and sideways
                    cx, cy = (fx1 + fx2) // 2, (fy1 + fy2) // 2
                    body_h = face_h * 5  # rough estimate
                    body_w = face_w * 1.5
                    ref_box = (
                        max(0, int(cx - body_w / 2)),
                        max(0, int(cy - face_h / 2)),
                        int(cx + body_w / 2),
                        int(cy + body_h),
                    )
                
                best_pb = None
                best_iou = 0.0
                if ref_box is not None:
                    for pb in person_boxes:
                        iou = _iou_xyxy(ref_box, pb)
                        if iou > best_iou:
                            best_iou, best_pb = iou, pb
                
                if best_pb is not None and best_iou > 0.05:
                    ent["body_box"] = best_pb
                    ent["last_seen"] = frame_idx
                    ent["seen"] = True
                else:
                    # not matched this frame, but keep the body box visible if it was recently seen
                    if ent.get("last_seen", 0) + 3 >= frame_idx:
                        # keep showing body box for up to 3 frames without detection
                        ent["seen"] = True
                    else:
                        # clear body box to avoid lingering rectangle after a while
                        ent["body_box"] = None

        # 2.5) Prune or age entities to avoid lingering boxes
        # Keep face-state entities with recognition progress alive longer
        MAX_MISS_DEFAULT = 15  # frames to keep entities without observation
        MAX_MISS_PARTIAL_RECOG = 90  # keep entities with partial recognition for longer
        for ent_id in list(entities.keys()):
            ent = entities[ent_id]
            if ent.get("seen"):
                ent["miss"] = 0
            else:
                ent["miss"] = ent.get("miss", 0) + 1
            
            # Determine max miss based on entity state and recognition progress
            if ent.get("state") == "face" and ent.get("recog_count", 0) > 0:
                # Entity has partial recognition - keep it longer
                max_miss = MAX_MISS_PARTIAL_RECOG
            else:
                max_miss = MAX_MISS_DEFAULT
            
            # drop if missed too long
            if ent.get("miss", 0) > max_miss:
                del entities[ent_id]

        # 3) Draw and write
        for ent in entities.values():
            name = ent.get("name") or "Unknown"
            color = (0, 255, 0) if ent.get("state") == "body" and name != "Unknown" else (0, 0, 255)
            if ent.get("state") == "body" and ent.get("body_box") is not None:
                x1, y1, x2, y2 = ent["body_box"]
                cv2.rectangle(frame, (x1, y1), (x2, y2), color, 2)
                cv2.putText(frame, name, (x1, max(20, y1 - 10)), cv2.FONT_HERSHEY_SIMPLEX, 0.7, color, 2)
            else:
                if ent.get("face_box") is not None:
                    x1, y1, x2, y2 = ent["face_box"]
                    cv2.rectangle(frame, (x1, y1), (x2, y2), (255, 150, 0), 2)
                    cv2.putText(frame, f"{name or 'Recognizing...'} ({ent.get('recog_count',0)}/{recog_threshold})",
                                (x1, max(20, y1 - 10)), cv2.FONT_HERSHEY_SIMPLEX, 0.7, (255, 150, 0), 2)

        out.write(frame)
        
        if is_live:
            cv2.imshow("Auth Tracking (Live)", frame)
            k = cv2.waitKey(1) & 0xFF
            if k in (27, ord('q'), ord('Q')):
                break

    cap.release()
    out.release()
    if pbar is not None:
        pbar.close()
    print(f"\n Saved authorized tracking video to: {out_path}")
    return out_path


def _print_event(event: str, payload: Dict):
    print(f"[{event}] {payload}")


def main():
    import argparse
    ap = argparse.ArgumentParser()
    ap.add_argument("--video", type=str, default=None)
    ap.add_argument("--save-dir", type=str, default=None)
    ap.add_argument("--frame-interval", type=int, default=0)
    ap.add_argument("--no-display", action="store_true")
    ap.add_argument("--camera", type=int, default=0)
    ap.add_argument("--auth-track", action="store_true", help="Enable face recognition then body tracking pipeline and save video")
    ap.add_argument("--output-name", type=str, default=None)
    ap.add_argument("--person-conf", type=float, default=0.25)
    ap.add_argument("--sim-threshold", type=float, default=0.65)
    ap.add_argument("--recog-threshold", type=int, default=15, help="Number of face recognitions needed before switching to body tracking (default: 15)")
    ap.add_argument("--unknown-threshold", type=int, default=60, help="Number of Unknown frames before switching to body tracking (default: 60)")
    ap.add_argument("--face-detect-interval", type=int, default=3, help="Run face detection every N frames (default: 3, higher = faster)")
    ap.add_argument("--min-face-size", type=int, default=20, help="Minimum face box size in pixels (default: 20)")
    args = ap.parse_args()

    if args.auth_track:
        # Determine source: video file or camera
        source = args.video if args.video else args.camera
        run_video_auth_track(
            source,
            output_name=args.output_name,
            frame_interval=args.frame_interval,
            face_detect_interval=args.face_detect_interval,
            person_conf=args.person_conf,
            sim_threshold=args.sim_threshold,
            recog_threshold=args.recog_threshold,
            unknown_threshold=args.unknown_threshold,
            min_face_size=args.min_face_size
        )
    elif args.video:
        run_video_capture(args.video, save_dir=args.save_dir, frame_interval=args.frame_interval, sim_threshold=args.sim_threshold)
    else:
        monitor = RoomMonitor(camera_index=args.camera, sim_threshold=args.sim_threshold)
        monitor.run(display=not args.no_display, on_event=_print_event)


if __name__ == "__main__":
    main()
