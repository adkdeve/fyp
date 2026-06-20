"""
Integrated Video Processor - Combines all ML models for real-time processing
With person tracking and face identity persistence
"""
import cv2
import numpy as np
from typing import Optional, Dict, Any, Tuple, List
import time

# Import all model components
from models.face_recognition import load_known_embeddings, detect_faces_in_frame, load_embeddings_from_file
from models.fire_smoke_detector import load_fire_smoke_model, annotate_fire_smoke
from models.safe_zone import load_yolo_model
from models.distress_detector import DistressDetector
from models.person_tracker import PersonTracker
from shapely.geometry import Polygon
from utils.alert_manager import AlertManager
from utils.config import (
    FACE_SIMILARITY_THRESHOLD,
    DEFAULT_SCALE_FACTOR,
    SAFE_COLOR,
    UNSAFE_COLOR,
    DEFAULT_SAFE_ZONE_COLOR
)


class IntegratedVideoProcessor:
    """Unified video processor with all ML models and person tracking"""
    
    def __init__(self, use_embeddings_file: bool = True):
        """
        Initialize all models
        
        Args:
            use_embeddings_file: If True, load from embeddings file (faster)
        """
        print("\n Initializing Integrated Video Processor...")
        
        # Load face recognition models
        if use_embeddings_file:
            print("Loading face embeddings from file...")
            self.known_names, self.known_embs, self.face_detector, self.face_encoder = load_embeddings_from_file()
        else:
            print("Loading face embeddings from folders...")
            self.known_names, self.known_embs, self.face_detector, self.face_encoder = load_known_embeddings()
        
        # Load YOLO for person detection (safe zone)
        self.yolo_model = load_yolo_model()
        
        # Load fire/smoke detection model
        self.fire_smoke_model = load_fire_smoke_model()
        
        # Load distress detector
        try:
            self.distress_detector = DistressDetector()
        except Exception as e:
            print(f" Distress detector not available: {e}")
            self.distress_detector = None
        
        # Initialize person tracker
        self.person_tracker = PersonTracker(iou_threshold=0.3, max_tracking_frames=120, center_dist_threshold=140)
        
        # Alert manager
        self.alert_manager = AlertManager()
        
        # Model enable/disable flags
        self.models_enabled = {
            'face_recognition': False,
            'safe_zone': False,
            'fire_smoke': False,
            'distress': False
        }
        
        # Safe zone polygon
        self.safe_zone_polygon = None
        self.safe_zone_points = []
        
        # Processing stats
        self.frame_count = 0
        self.last_process_time = 0
        self._last_frame_ts = None
        self._fps_ema = None
        
        print(" Integrated Video Processor initialized successfully!")
    
    def enable_model(self, model_name: str, enabled: bool = True):
        """Enable or disable a specific model"""
        if model_name in self.models_enabled:
            if self.models_enabled[model_name] == enabled:
                return
            self.models_enabled[model_name] = enabled
            status = "enabled" if enabled else "disabled"
            print(f" {model_name} {status}")
    
    def set_safe_zone(self, polygon_points: list):
        """
        Set safe zone polygon
        
        Args:
            polygon_points: List of (x, y) tuples defining the polygon
        """
        if polygon_points and len(polygon_points) >= 3:
            self.safe_zone_points = polygon_points
            self.safe_zone_polygon = Polygon(polygon_points)
            print(f" Safe zone set with {len(polygon_points)} points")
            return True
        else:
            print(" Safe zone requires at least 3 points")
            return False
    
    def clear_safe_zone(self):
        """Clear the safe zone polygon"""
        self.safe_zone_polygon = None
        self.safe_zone_points = []
        print(" Safe zone cleared")
    
    def process_frame(self, frame: np.ndarray, allow_heavy_models: bool = True) -> Tuple[np.ndarray, Dict[str, Any]]:
        """
        Process a single frame with all enabled models and person tracking
        
        Args:
            frame: BGR image frame from video
            
        Returns:
            Tuple of (annotated_frame, detection_results)
        """
        start_time = time.time()
        self.frame_count += 1

        # Tiered scheduling: light every frame, medium every 5, heavy every 15.
        # Exception: unauthorized detection (face recognition path) runs every real frame.
        run_medium_models = (self.frame_count % 5 == 0)
        run_heavy_models = allow_heavy_models and (self.frame_count % 15 == 0)
        
        # Distress: gate is handled internally by analyze_frame now.
        run_unauthorized_every_frame = allow_heavy_models
        
        # Debug logging on first frame
        if self.frame_count == 1:
            enabled_models = [k for k, v in self.models_enabled.items() if v]
            print(f" Processing started | Enabled models: {enabled_models or 'NONE'} | Heavy models allowed: {allow_heavy_models}")
        
        detection_results = {
            'faces': [],
            'persons': [],
            'tracked_persons': [],
            'fire_smoke': [],
            'distress': [],
            'safe_zone_violations': 0,
            'unknown_persons': 0
        }
        
        h, w = frame.shape[:2]
        scale = DEFAULT_SCALE_FACTOR
        small_frame = cv2.resize(frame, (int(w * scale), int(h * scale)))
        
        # Step 1: Detect all persons using YOLO (always run if safe_zone or face_recognition enabled)
        person_detections = []
        if (self.models_enabled['safe_zone'] or self.models_enabled['face_recognition'] or self.models_enabled['distress']) and self.yolo_model is not None:
            try:
                yolo_results = self.yolo_model(small_frame, verbose=False)
                
                for r in yolo_results:
                    for box in r.boxes:
                        cls = int(box.cls[0])
                        if self.yolo_model.names[cls] != "person":
                            continue
                        
                        # Scale box back to original and convert to xywh
                        x1, y1, x2, y2 = map(lambda v: int(v / scale), box.xyxy[0])
                        conf = float(box.conf[0]) if hasattr(box, 'conf') else 0.90
                        person_box = (x1, y1, x2 - x1, y2 - y1, conf)  # xywhc format
                        person_detections.append(person_box)
                        
            except Exception as e:
                print(f" Person detection error: {e}")
        
        # Step 2: Run face recognition only for unidentified persons
        face_detections = []
        if self.models_enabled['face_recognition'] and self.face_detector is not None and run_unauthorized_every_frame:
            try:
                # Get unidentified persons from tracker
                unidentified_persons = self.person_tracker.get_unidentified_persons()
                
                # Only run face recognition if we have new/unidentified persons
                # OR if this is first few frames (tracker empty)
                should_run_face_recognition = (
                    len(unidentified_persons) > 0 or 
                    len(self.person_tracker.get_visible_tracked()) < len(person_detections)
                )
                
                if should_run_face_recognition:
                    if self.frame_count % 30 == 0:
                        print(f" Face recognition running (frame {self.frame_count}) | People: {len(person_detections)}")
                    face_results, face_labels = detect_faces_in_frame(
                        frame,
                        self.known_names,
                        self.known_embs,
                        self.face_detector,
                        self.face_encoder,
                        sim_threshold=FACE_SIMILARITY_THRESHOLD
                    )
                    
                    # Convert face results to list format for tracker
                    for (x1, y1, x2, y2), label in face_results.items():
                        # Face recognition already ran on the original frame.
                        X1 = x1
                        Y1 = y1
                        X2 = x2
                        Y2 = y2
                        
                        # Parse name from any label format and keep confidence optional.
                        confidence = 0.0
                        if label.startswith("Unknown") or " UNAUTHORIZED" in label:
                            name = "Unknown"
                        elif "(" in label:
                            name = label.split("(")[0].strip()
                        else:
                            name = label.strip()
                        
                        face_detections.append({
                            'bbox': (X1, Y1, X2 - X1, Y2 - Y1),  # xywh format
                            'name': name,
                            'confidence': confidence
                        })
                        
                        detection_results['faces'].append({
                            'bbox': (X1, Y1, X2, Y2),
                            'label': label
                        })
                
            except Exception as e:
                print(f" Face recognition error: {e}")
        
        # Step 3: Update person tracker with detections
        self.person_tracker.update(person_detections, face_detections, frame=frame)
        # Emit alert exactly when a track first becomes unauthorized.
        for tracked in self.person_tracker.get_all_tracked():
            if tracked.just_became_unauthorized and not tracked.unauthorized_alert_sent:
                self.alert_manager.add_unknown_person_alert(
                    details=f"Track ID {tracked.person_id} locked as UNAUTHORIZED"
                )
                        # Also push to StreamManager alert queue so frontend can fetch via /stream/alerts
                        try:
                            from stream.router import stream_mgr
                            if getattr(stream_mgr, '_alert_queue', None) is not None:
                                stream_mgr._alert_queue.put_nowait({
                                    'type': 'unknown_person',
                                    'message': f"Track ID {tracked.person_id} locked as UNAUTHORIZED",
                                    'severity': 'warning',
                                    'timestamp': time.time(),
                                })
                        except Exception:
                            pass
        tracked_persons = self.person_tracker.get_visible_tracked()
        
        # Step 4: Annotate tracked persons
        for tracked in tracked_persons:
            x, y, w, h = tracked.bbox
            label = tracked.get_label()
            
            # Determine state for color/stats
            is_authorized = tracked.auth_state == "authorized"
            is_unauthorized = tracked.auth_state == "unauthorized"
            is_known = tracked.identity is not None and tracked.identity != "Unknown"

            if is_unauthorized and not tracked.unauthorized_alert_sent:
                self.alert_manager.add_unknown_person_alert(
                    details=f"Track ID {tracked.person_id} locked as UNAUTHORIZED"
                )
                tracked.unauthorized_alert_sent = True
            
            # Default color (yellow for person detection)
            color = (0, 255, 255)
            
            # Step 5: Check safe zone if enabled
            if self.models_enabled['safe_zone'] and self.safe_zone_polygon is not None:
                person_poly = Polygon([(x, y), (x+w, y), (x+w, y+h), (x, y+h)])
                is_safe = self.safe_zone_polygon.intersects(person_poly)
                
                if is_safe:
                    color = SAFE_COLOR
                    status_text = "Safe"
                    tracked.safe_zone_alert_sent = False
                else:
                    color = UNSAFE_COLOR
                    status_text = "UNSAFE"
                    detection_results['safe_zone_violations'] += 1

                    # Emit a single unsafe-zone alert per tracked person when they
                    # transition out of the safe zone. Include identity when available
                    # so authorized persons also generate alerts.
                    if not tracked.safe_zone_alert_sent:
                            # Prefer a clean name if available, otherwise fall back
                            # to a generic description.
                            if tracked.identity and tracked.identity != "Unknown":
                                person_name = tracked.identity
                                alert_msg = f"{person_name} left the safe zone"
                            else:
                                person_name = "unknown person"
                                alert_msg = f"Unknown person (Track #{tracked.person_id}) left the safe zone"
                            self.alert_manager.add_unsafe_zone_alert(person_name=person_name, action="left the safe zone")
                            print(f" Safe-zone violation: {person_name} (track_id={tracked.person_id}, auth={tracked.auth_state})")
                            # Also push to StreamManager alert queue so frontend can fetch via /stream/alerts
                            try:
                                from stream.router import stream_mgr
                                if getattr(stream_mgr, '_alert_queue', None) is not None:
                                    stream_mgr._alert_queue.put_nowait({
                                        'type': 'unsafe_zone',
                                        'message': alert_msg,
                                        'severity': 'warning',
                                        'timestamp': time.time(),
                                    })
                                    print(f" Alert pushed to queue: {alert_msg}")
                                else:
                                    print(f"  stream_mgr._alert_queue is None")
                            except Exception as e:
                                print(f" Failed to push alert: {e}")
                            tracked.safe_zone_alert_sent = True
            elif self.frame_count % 60 == 0:
                # Debug log every 60 frames to understand state
                print(f" SafeZone check: enabled={self.models_enabled['safe_zone']}, polygon_set={self.safe_zone_polygon is not None}")
                # Update label with safe zone status
                label = f"{label} [{status_text}]"
            else:
                tracked.safe_zone_alert_sent = False
                # Color based on identity if no safe zone
                if is_unauthorized:
                    color = (0, 0, 255)  # Red for unauthorized lock
                elif is_authorized or is_known:
                    color = (0, 255, 0)  # Green for known
                else:
                    color = (0, 165, 255)  # Orange for unknown
            
            # Draw person bounding box
            cv2.rectangle(frame, (x, y), (x+w, y+h), color, 2)
            
            # Draw label
            label_size, _ = cv2.getTextSize(label, cv2.FONT_HERSHEY_SIMPLEX, 0.6, 2)
            cv2.rectangle(frame, (x, y - label_size[1] - 10), 
                         (x + label_size[0], y), color, -1)
            cv2.putText(frame, label, (x, y - 5),
                       cv2.FONT_HERSHEY_SIMPLEX, 0.6, (255, 255, 255), 2)
            
            # Track statistics
            if not is_known:
                detection_results['unknown_persons'] += 1
            
            detection_results['tracked_persons'].append({
                'person_id': tracked.person_id,
                'bbox': (x, y, w, h),
                'identity': tracked.identity,
                'confidence': tracked.confidence,
                'frames_tracked': tracked.frames_tracked,
                'success_hits': tracked.success_hits,
                'fail_hits': tracked.fail_hits,
                'auth_state': tracked.auth_state,
                'recognition_locked': tracked.recognition_locked,
            })
        
        # Draw safe zone polygon if set
        if self.safe_zone_polygon is not None and self.safe_zone_points:
            cv2.polylines(frame, [np.array(self.safe_zone_points, np.int32)],
                         True, DEFAULT_SAFE_ZONE_COLOR, 2)
        
        # FIRE/SMOKE DETECTION
        if self.models_enabled['fire_smoke'] and self.fire_smoke_model is not None and run_medium_models:
            try:
                fire_results = self.fire_smoke_model(small_frame, verbose=False)
                
                for r in fire_results:
                    for box in r.boxes:
                        x1, y1, x2, y2 = map(lambda v: int(v / scale), box.xyxy[0])
                        cls = int(box.cls[0])
                        label = self.fire_smoke_model.names.get(cls, str(cls))
                        conf = float(box.conf[0])
                        
                        cv2.rectangle(frame, (x1, y1), (x2, y2), (0, 140, 255), 2)
                        cv2.putText(frame, f"{label} {conf:.2f}", (x1, y1 - 10),
                                  cv2.FONT_HERSHEY_SIMPLEX, 0.65, (0, 140, 255), 2)
                        
                        detection_results['fire_smoke'].append({
                            'bbox': (x1, y1, x2, y2),
                            'label': label,
                            'confidence': conf
                        })
                        
                        # Generate alert (throttled)
                        if self.frame_count % 30 == 0:
                            self.alert_manager.add_fire_alert(label)
                
            except Exception as e:
                print(f" Fire/smoke detection error: {e}")
        
        # DISTRESS DETECTION
        if self.models_enabled['distress'] and self.distress_detector is not None:
            try:
                # analyze_frame handles target locking and gate keeping to maintain high fps.
                emotion_results = self.distress_detector.analyze_frame(
                    frame, 
                    tracked_persons=tracked_persons,
                    run_visual_search=run_heavy_models
                )
                
                for result in emotion_results:
                    box = result.get('box')
                    if box is None:
                        continue
                    
                    x, y, w, h = box
                    top_emotion = result['top_emotion']
                    confidence = result['top_emotion_confidence']
                    is_distress = result['is_distress']
                    
                    if is_distress:
                        color = (0, 0, 255)
                        label = f"DISTRESS: {top_emotion}"
                        
                        detection_results['distress'].append({
                            'bbox': (x, y, x + w, y + h),
                            'emotion': top_emotion,
                            'confidence': confidence
                        })
                        
                        # Generate alert (throttled)
                        if self.frame_count % 30 == 0:
                            self.alert_manager.add_distress_alert(emotion=top_emotion)
                    else:
                        color = (255, 255, 0)
                        label = top_emotion
                    
                    # Draw distressed box highlight - thicker
                    cv2.rectangle(frame, (x, y), (x + w, y + h), color, 3)
                    
                    # Add label background for readability
                    label_size, _ = cv2.getTextSize(label, cv2.FONT_HERSHEY_SIMPLEX, 0.6, 2)
                    cv2.rectangle(frame, (x, y - label_size[1] - 10), 
                                 (x + label_size[0], y), color, -1)
                    cv2.putText(frame, label, (x, y - 5),
                              cv2.FONT_HERSHEY_SIMPLEX, 0.6, (255, 255, 255), 2)
                
            except Exception as e:
                print(f" Distress detection error: {e}")
        
        # Add processing time and stable FPS estimate
        now_ts = time.time()
        process_time = (now_ts - start_time) * 1000
        self.last_process_time = process_time

        # FPS should be based on frame-to-frame wall clock, then smoothed.
        if self._last_frame_ts is None:
            instant_fps = 0.0
        else:
            dt = max(1e-3, now_ts - self._last_frame_ts)
            instant_fps = 1.0 / dt

        if self._fps_ema is None:
            self._fps_ema = instant_fps
        else:
            self._fps_ema = (0.2 * instant_fps) + (0.8 * self._fps_ema)

        # Align displayed FPS with delivery cap to avoid misleading spikes.
        fps = max(0.0, min(self._fps_ema, 20.0))
        self._last_frame_ts = now_ts
        
        # Display stats
        stats_text = f"FPS: {fps:.1f} | Tracked: {len(tracked_persons)} | Unknown: {detection_results['unknown_persons']}"
        cv2.putText(frame, stats_text,
                   (10, 30), cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 255, 0), 2)
        
        detection_results['process_time_ms'] = process_time
        detection_results['fps'] = fps
        detection_results['tiered'] = {
            'light_models': True,
            'medium_models': run_medium_models,
            'heavy_models': run_heavy_models,
            'heavy_allowed_for_frame': allow_heavy_models,
            'unauthorized_every_frame': run_unauthorized_every_frame,
        }
        
        return frame, detection_results
    
    def get_stats(self) -> Dict[str, Any]:
        """Get processing statistics"""
        return {
            'frame_count': self.frame_count,
            'last_process_time_ms': self.last_process_time,
            'models_enabled': dict(self.models_enabled),
            'known_faces_count': len(self.known_names),
            'alerts': self.alert_manager.get_stats()
        }
    
    def reload_face_embeddings(self):
        """Reload face embeddings (e.g., after creating new ones)"""
        print("\n Reloading face embeddings...")
        self.known_names, self.known_embs, self.face_detector, self.face_encoder = load_embeddings_from_file()
        print(f" Reloaded {len(self.known_names)} face embeddings")
    
    def reset(self):
        """Reset processor state"""
        self.frame_count = 0
        self.person_tracker.reset()
        self.alert_manager.clear_alerts()
        print(" Processor reset")
