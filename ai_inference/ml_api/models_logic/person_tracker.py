"""
Person Tracker - Tracks persons across frames and maintains face identity mappings
"""
from typing import List, Dict, Tuple, Optional
from deep_sort_realtime.deepsort_tracker import DeepSort


def xyxy_to_xywh(box: Tuple[float, float, float, float]) -> Tuple[int, int, int, int]:
    """Convert (x1, y1, x2, y2) to (x, y, w, h)."""
    x1, y1, x2, y2 = box
    x = int(round(x1))
    y = int(round(y1))
    w = int(round(x2 - x1))
    h = int(round(y2 - y1))
    return (x, y, max(0, w), max(0, h))


class TrackedPerson:
    """Represents a tracked person with identity and persistence"""
    
    def __init__(self, person_id: int, bbox: Tuple[int, int, int, int], 
                 identity: Optional[str] = None, confidence: float = 0.0):
        """
        Initialize tracked person
        
        Args:
            person_id: Unique tracking ID
            bbox: Bounding box as (x, y, w, h)
            identity: Face identity name (None if unknown/not yet identified)
            confidence: Face recognition confidence
        """
        self.person_id = person_id
        self.bbox = bbox  # (x, y, w, h)
        self.identity = identity  # Face name or None
        self.confidence = confidence
        self.frames_tracked = 0
        self.frames_since_face_match = 0
        self.is_identified = identity is not None
        self.last_seen_frame = 0
        self.visible_this_frame = True
        self.consecutive_detections = 1

        # Authorization lock workflow
        self.success_hits = 0
        self.fail_hits = 0
        self.hit_threshold = 30
        self.miss_threshold = 60
        self.auth_state = "pending"  # pending | authorized | unauthorized
        self.recognition_locked = False
        self.unauthorized_alert_sent = False
        self.just_became_unauthorized = False
        self.safe_zone_alert_sent = False
        
    def update_position(self, bbox: Tuple[int, int, int, int]):
        """Update person's bounding box"""
        self.bbox = bbox
        self.frames_tracked += 1
        self.frames_since_face_match += 1
        self.visible_this_frame = True
        self.consecutive_detections += 1

    def mark_missed(self):
        """Mark the track as not detected in the current frame."""
        self.visible_this_frame = False

    def is_confirmed(self, min_detections: int = 2) -> bool:
        """Ignore one-frame false positives before showing a track."""
        return self.consecutive_detections >= min_detections
        
    def set_identity(self, identity: str, confidence: float):
        """Set identity and count a successful recognition hit."""
        if self.recognition_locked:
            return

        self.identity = identity
        self.confidence = confidence
        self.is_identified = True
        self.frames_since_face_match = 0

        self.success_hits += 1
        if self.success_hits >= self.hit_threshold:
            self.auth_state = "authorized"
            self.recognition_locked = True

    def register_miss(self):
        """Count an unsuccessful recognition hit (Unknown)."""
        if self.recognition_locked:
            return

        self.fail_hits += 1
        if self.fail_hits >= self.miss_threshold:
            self.auth_state = "unauthorized"
            self.recognition_locked = True
            self.identity = "Unknown"
            self.confidence = 0.0
            self.is_identified = False
            self.just_became_unauthorized = True

    def needs_recognition(self) -> bool:
        """Whether this person should still run face recognition."""
        return not self.recognition_locked
        
    def should_expire(self, current_frame: int, max_missed_frames: int = 30) -> bool:
        """Expire only if the person was not seen for too many frames."""
        return (current_frame - self.last_seen_frame) > max_missed_frames
    
    def get_label(self) -> str:
        """Get display label for this person"""
        if self.auth_state == "authorized":
            name = self.identity if self.identity else "Known"
            return f"ID:{self.person_id} {name} AUTHORIZED"

        if self.auth_state == "unauthorized":
            return f"ID:{self.person_id} Unknown UNAUTHORIZED"

        base_name = self.identity if self.identity else "Unknown"
        return (
            f"ID:{self.person_id} {base_name} "
            f"(ok:{self.success_hits}/{self.hit_threshold}, "
            f"miss:{self.fail_hits}/{self.miss_threshold})"
        )


class PersonTracker:
    """
    Tracks persons across frames and maintains face identity mappings
    """
    
    def __init__(self, iou_threshold: float = 0.3, max_tracking_frames: int = 15, center_dist_threshold: int = 120):
        """
        Initialize person tracker
        
        Args:
            iou_threshold: Minimum IoU to match persons across frames
            max_tracking_frames: Maximum missed frames before deleting a track
            center_dist_threshold: Fallback pixel threshold for center-distance matching
        """
        self.iou_threshold = iou_threshold
        self.max_tracking_frames = max_tracking_frames
        self.center_dist_threshold = center_dist_threshold
        self.tracked_persons: List[TrackedPerson] = []
        self._persons_by_track_id: Dict[int, TrackedPerson] = {}
        self.current_frame = 0

        # DeepSORT tracker backend; IDs remain stable across short occlusions.
        self._deepsort = DeepSort(
            max_age=max_tracking_frames,
            n_init=3,
            max_cosine_distance=0.1,
            max_iou_distance=0.4,
            embedder="mobilenet",
        )
        
    def update(self, person_detections: List[Tuple[int, int, int, int]], 
               face_detections: List[Dict] = None,
               frame=None) -> List[TrackedPerson]:
        """
        Update tracking with new frame detections
        
        Args:
            person_detections: List of person bounding boxes as (x, y, w, h)
            face_detections: List of face detection dicts with keys:
                - bbox: (x, y, w, h)
                - name: Face identity
                - confidence: Recognition confidence
                
        Returns:
            List of tracked persons with identities
        """
        self.current_frame += 1

        for tracked in self._persons_by_track_id.values():
            tracked.mark_missed()

        # DeepSORT expects detections as: ([left, top, width, height], confidence, class_name)
        ds_detections = []
        for det in person_detections:
            if len(det) < 4:
                continue
            x, y, w, h = det[:4]
            if w <= 0 or h <= 0:
                continue
            conf = float(det[4]) if len(det) > 4 else 0.90
            ds_detections.append(([float(x), float(y), float(w), float(h)], conf, "person"))

        ds_tracks = self._deepsort.update_tracks(ds_detections, frame=frame)

        active_track_ids = set()
        updated_tracks: List[TrackedPerson] = []

        for ds_track in ds_tracks:
            # Only use tracks updated by current detections.
            if getattr(ds_track, "time_since_update", 0) > 0:
                continue

            track_id = int(ds_track.track_id)
            active_track_ids.add(track_id)
            ltrb = ds_track.to_ltrb()
            bbox_xywh = xyxy_to_xywh((ltrb[0], ltrb[1], ltrb[2], ltrb[3]))

            tracked = self._persons_by_track_id.get(track_id)
            if tracked is None:
                tracked = TrackedPerson(
                    person_id=track_id,
                    bbox=bbox_xywh,
                    identity=None,
                    confidence=0.0,
                )
                tracked.last_seen_frame = self.current_frame
                self._persons_by_track_id[track_id] = tracked
            else:
                tracked.update_position(bbox_xywh)
                tracked.last_seen_frame = self.current_frame

            updated_tracks.append(tracked)

        # Keep recently-missed tracks alive until DeepSORT drops them.
        stale_ids = []
        for track_id, tracked in self._persons_by_track_id.items():
            if track_id not in active_track_ids:
                if tracked.should_expire(self.current_frame, self.max_tracking_frames):
                    stale_ids.append(track_id)
                else:
                    updated_tracks.append(tracked)

        for track_id in stale_ids:
            self._persons_by_track_id.pop(track_id, None)
        
        # Match faces to tracked persons
        if face_detections:
            for face in face_detections:
                face_box = face.get('bbox', None)
                face_name = face.get('name', 'Unknown')
                face_conf = face.get('confidence', 0.0)
                
                if face_box is None:
                    continue
                
                # Find which person bbox contains this face
                face_center_x = face_box[0] + face_box[2] // 2
                face_center_y = face_box[1] + face_box[3] // 2
                
                for tracked in updated_tracks:
                    px, py, pw, ph = tracked.bbox
                    
                    # Check if face center is inside person bbox
                    if (px <= face_center_x <= px + pw and 
                        py <= face_center_y <= py + ph):
                        
                        if tracked.recognition_locked:
                            break

                        if face_name and face_name != "Unknown":
                            # Once a person is AUTHORIZED on one track, do not reuse that
                            # identity on a different track in the same scene.
                            if self._is_identity_already_authorized(face_name, tracked.person_id):
                                tracked.register_miss()
                                break

                            # Keep the highest confidence identity for display quality.
                            if not tracked.is_identified or face_conf >= tracked.confidence:
                                tracked.set_identity(face_name, face_conf)
                            else:
                                # Still count as successful recognition attempt.
                                tracked.success_hits += 1
                                if tracked.success_hits >= tracked.hit_threshold:
                                    tracked.auth_state = "authorized"
                                    tracked.recognition_locked = True
                        else:
                            tracked.register_miss()
                        break
        
        self.tracked_persons = updated_tracks
        return self.tracked_persons

    def _is_identity_already_authorized(self, identity: str, current_person_id: int) -> bool:
        """Check whether this identity is already AUTHORIZED on another visible track."""
        for tracked in self._persons_by_track_id.values():
            if tracked.person_id == current_person_id:
                continue
            if not tracked.visible_this_frame:
                continue
            if tracked.auth_state == "authorized" and tracked.identity == identity:
                return True
        return False
    
    def get_unidentified_persons(self) -> List[TrackedPerson]:
        """Get list of persons that still need face recognition."""
        return [p for p in self.tracked_persons if p.needs_recognition()]
    
    def get_all_tracked(self) -> List[TrackedPerson]:
        """Get all currently tracked persons"""
        return self.tracked_persons

    def get_visible_tracked(self) -> List[TrackedPerson]:
        """Get tracks that were actually seen in the current frame and confirmed."""
        return [p for p in self.tracked_persons if p.visible_this_frame and p.is_confirmed()]
    
    def get_person_by_id(self, person_id: int) -> Optional[TrackedPerson]:
        """Get tracked person by ID"""
        for person in self.tracked_persons:
            if person.person_id == person_id:
                return person
        return None
    
    def reset(self):
        """Reset all tracking"""
        self.tracked_persons = []
        self._persons_by_track_id = {}
        self._deepsort = DeepSort(
            max_age=self.max_tracking_frames,
            n_init=1,
            max_cosine_distance=0.1,
            max_iou_distance=0.7,
            embedder="mobilenet",
        )
        self.current_frame = 0
