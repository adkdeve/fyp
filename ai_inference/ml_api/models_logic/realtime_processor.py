# models/realtime_processor.py
import cv2
import numpy as np
import streamlit as st
from typing import Optional, Callable, Any
from models.face_recognition import load_known_embeddings, detect_faces_in_frame
from models.safe_zone import load_yolo_model
from models.fire_smoke_detector import load_fire_smoke_model, annotate_fire_smoke
from models.stream_input_handler import StreamInputHandler
from shapely.geometry import Polygon

class RealTimeProcessor:
    """Real-time video processing with all integrated models"""
    
    def __init__(self):
        # Load all models once (only if not already loaded)
        if not hasattr(self.__class__, '_models_loaded'):
            self.known_names, self.known_embs, self.face_detector, self.face_encoder = load_known_embeddings()
            self.yolo = load_yolo_model()
            self.fire_smoke_model = load_fire_smoke_model()
            self.__class__._models_loaded = True
            print(" Real-time processor initialized with all models!")
        else:
            # Use already loaded models
            from models.integrated_model import known_names, known_embs, face_detector, face_encoder, yolo, fire_smoke_model
            self.known_names, self.known_embs, self.face_detector, self.face_encoder = known_names, known_embs, face_detector, face_encoder
            self.yolo = yolo
            self.fire_smoke_model = fire_smoke_model
        
        self.stream_handler = StreamInputHandler()
        
        # Processing state
        self.safe_zone_points = []
        self.polygon = None
        self.is_processing = False
    
    def set_safe_zone(self, safe_zone_points: list):
        """Set the safe zone polygon for processing"""
        if safe_zone_points and len(safe_zone_points) >= 3:
            self.safe_zone_points = safe_zone_points
            self.polygon = Polygon(safe_zone_points)
            return True
        return False
    
    def process_frame(self, frame: np.ndarray) -> np.ndarray:
        """Process a single frame with all models"""
        if not self.is_processing:
            return frame
        
        import time as _time  # For timing

        # === RESIZE for speed ===
        scale_factor = 0.5  # Reduce frame size for inference
        h, w = frame.shape[:2]
        small_frame = cv2.resize(frame, (int(w*scale_factor), int(h*scale_factor)))

        # Measure inference time
        tic = _time.time()
        try:
            # Face Recognition (on small frame)
            face_results, _ = detect_faces_in_frame(
                small_frame, self.known_names, self.known_embs, 
                self.face_detector, self.face_encoder
            )
            # Map face_results back to original frame coordinates
            face_results_up = {}
            for (fx1, fy1, fx2, fy2), label in face_results.items():
                FX1 = int(fx1/scale_factor)
                FY1 = int(fy1/scale_factor)
                FX2 = int(fx2/scale_factor)
                FY2 = int(fy2/scale_factor)
                face_results_up[(FX1, FY1, FX2, FY2)] = label

            # YOLO Person Detection (on small frame)
            results = self.yolo(small_frame, verbose=False)
            for r in results:
                for box in r.boxes:
                    cls = int(box.cls[0])
                    if self.yolo.names[cls] != "person":
                        continue
                    
                    # Scale box back up
                    x1, y1, x2, y2 = map(lambda v: int(v/scale_factor), box.xyxy[0])
                    person_poly = Polygon([(x1, y1), (x2, y1), (x2, y2), (x1, y2)])
                    
                    # Safe zone check (disabled - no safe zone required)
                    safe_status = "Unknown"  # No safe zone checking
                    color = (0, 255, 255)  # Yellow color for unknown safe status
                    
                    # Associate face with person box (always enabled)
                    name = "Unknown"
                    min_dist = float("inf")
                    found_inside = False
                    person_center = ((x1 + x2) // 2, (y1 + y2) // 2)
                    
                    for (fx1, fy1, fx2, fy2), label in face_results_up.items():
                        face_center = ((fx1 + fx2) // 2, (fy1 + fy2) // 2)
                        
                        is_inside = (x1 <= face_center[0] <= x2) and (y1 <= face_center[1] <= y2)
                        dist = np.linalg.norm(np.array(person_center) - np.array(face_center))
                        
                        if is_inside:
                            found_inside = True
                            if dist < min_dist:
                                min_dist = dist
                                name = label
                        elif not found_inside:
                            if dist < min_dist:
                                min_dist = dist
                                name = label
                    
                    if not found_inside and min_dist > 200:
                        name = "Unknown"
                    
                    # Draw person box with combined label
                    combined_label = f"{name} [{safe_status}]"
                    cv2.rectangle(frame, (x1, y1), (x2, y2), color, 2)
                    cv2.putText(frame, combined_label, (x1, y1 - 10),
                                cv2.FONT_HERSHEY_SIMPLEX, 0.65, color, 2)
            
            # Draw face boxes on upscaled frame
            for (fx1, fy1, fx2, fy2), label in face_results_up.items():
                color = (0, 255, 0) if label != "Unknown" else (0, 0, 255)
                cv2.rectangle(frame, (fx1, fy1), (fx2, fy2), color, 1)
            
            # Draw safe zone polygon (disabled - no safe zone required)
            # if self.safe_zone_points:
            #     cv2.polylines(frame, [np.array(self.safe_zone_points, np.int32)], True, (255, 255, 0), 2)
            
            # Fire/Smoke detection (on small frame)
            fire_frame = annotate_fire_smoke(small_frame, self.fire_smoke_model)
            # Upscale and overlay fire/frame result if needed (optional)
            # Currently not mapped: leave as is or draw indicator on main frame?
            # (Optimally, adapt fire results to original frame as with faces)

        except Exception as e:
            st.error(f"Processing error: {str(e)}")

        toc = _time.time()
        # Display processing time in top left
        cv2.putText(frame, f'Proc: {(toc-tic)*1000:.0f} ms', (10,30), cv2.FONT_HERSHEY_SIMPLEX, 1, (200,0,0), 2)

        return frame
    
    def start_processing(self):
        """Start real-time processing"""
        self.is_processing = True
    
    def stop_processing(self):
        """Stop real-time processing"""
        self.is_processing = False
    
    def cleanup(self):
        """Clean up resources"""
        self.stream_handler.cleanup()


class FaceOnlyProcessor:
    """Lightweight real-time processor that only runs face recognition."""

    def __init__(self):
        # Load face models once
        if not hasattr(self.__class__, '_models_loaded'):
            kn, ke, fd, fe = load_known_embeddings()
            # Cache at class level for reuse across instances
            self.__class__._known_names = kn
            self.__class__._known_embs = ke
            self.__class__._face_detector = fd
            self.__class__._face_encoder = fe
            self.__class__._models_loaded = True
            self.known_names, self.known_embs, self.face_detector, self.face_encoder = kn, ke, fd, fe
        else:
            # Reuse cached models
            self.known_names = getattr(self.__class__, '_known_names', None)
            self.known_embs = getattr(self.__class__, '_known_embs', None)
            self.face_detector = getattr(self.__class__, '_face_detector', None)
            self.face_encoder = getattr(self.__class__, '_face_encoder', None)
            # Fallback if cache missing for any reason
            if self.known_names is None or self.known_embs is None or self.face_detector is None or self.face_encoder is None:
                kn, ke, fd, fe = load_known_embeddings()
                self.__class__._known_names = kn
                self.__class__._known_embs = ke
                self.__class__._face_detector = fd
                self.__class__._face_encoder = fe
                self.known_names, self.known_embs, self.face_detector, self.face_encoder = kn, ke, fd, fe

        # Runtime state
        self.is_processing = False
        self._frame_count = 5
        self._last_results = None  # cache of {(x1,y1,x2,y2): label}
        self.process_every_n = 1   # compute every N frames, reuse in-between
        self.target_long_side = 480  # downscale long side for speed
        self.stream_handler = StreamInputHandler()

    def process_frame(self, frame: np.ndarray) -> np.ndarray:
        """Annotate frame with face boxes and names when enabled."""
        if not self.is_processing:
            return frame

        import time as _time
        tic = _time.time()

        # Optionally resize for speed to target_long_side
        h, w = frame.shape[:2]
        long_side = max(h, w)
        scale = min(1.0, self.target_long_side / float(long_side))
        work_frame = cv2.resize(frame, (int(w*scale), int(h*scale))) if scale != 1.0 else frame

        try:
            # Throttle detection to every Nth frame; reuse last results in between
            if (self._frame_count % self.process_every_n) == 0 or self._last_results is None:
                face_results, _ = detect_faces_in_frame(
                    work_frame, self.known_names, self.known_embs,
                    self.face_detector, self.face_encoder
                )
                self._last_results = face_results
            else:
                face_results = self._last_results

            # Map boxes back to original size if resized
            for (x1, y1, x2, y2), label in face_results.items():
                if scale != 1.0:
                    X1 = int(x1/scale); Y1 = int(y1/scale); X2 = int(x2/scale); Y2 = int(y2/scale)
                else:
                    X1, Y1, X2, Y2 = x1, y1, x2, y2

                color = (0, 255, 0) if label != "Unknown" else (0, 0, 255)
                cv2.rectangle(frame, (X1, Y1), (X2, Y2), color, 2)
                cv2.putText(frame, label, (X1, max(20, Y1 - 10)), cv2.FONT_HERSHEY_SIMPLEX, 0.7, color, 2)

        except Exception as e:
            st.error(f"Face processing error: {str(e)}")

        toc = _time.time()
        self._frame_count += 1
        cv2.putText(frame, f'FaceProc: {(toc-tic)*1000:.0f} ms', (10,30), cv2.FONT_HERSHEY_SIMPLEX, 1, (200,0,0), 2)
        return frame

    def start_processing(self):
        self.is_processing = True

    def stop_processing(self):
        self.is_processing = False

    def cleanup(self):
        self.stream_handler.cleanup()
