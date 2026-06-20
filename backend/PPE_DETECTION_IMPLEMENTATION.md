# PPE Detection with Person Mapping - Implementation Guide

## Overview
This implementation applies the PPE detection technique as described, where individual PPE violations are intelligently grouped by person. Instead of drawing multiple scattered boxes for a single person's violations, this system draws **ONE box per person** with all their PPE violations **stacked as labels**.

## Architecture

### Components

#### 1. **Helper Functions** (Global scope in `camera_worker.py`)

##### `_get_person_model()`
- Lazy-loads YOLO nano model (`yolov8n.pt`) on first use
- Caches the model globally to avoid reloading
- Uses nano model for speed optimization
- Returns `None` if model fails to load (graceful degradation)

```python
def _get_person_model():
    """Lazy-load YOLO person detection model (cached)."""
```

##### `_detect_persons(frame: np.ndarray) -> list[list[int]]`
- Detects all persons in a frame using YOLO
- Automatically scales frame down to max 640px on longest side for speed
- Scales bounding boxes back to original frame dimensions
- Returns list of `[x1, y1, x2, y2]` pixel coordinates
- Gracefully returns empty list if detection fails

```python
def _detect_persons(frame: np.ndarray) -> list[list[int]]:
    """Detect persons in frame using YOLO."""
```

**Coordinate Scaling:**
```
Original Frame: 1920x1080 (scaled by 0.33)
Detection runs at: 640x360
Boxes detected at small scale
Boxes scaled back: [coord / scale_factor] 
Final output: Original frame coordinates
```

##### `_group_ppe_by_person(ppe_detections: list, person_boxes: list[list[int]]) -> tuple`
- Maps each PPE violation to the person whose box it overlaps with (by IoU)
- Uses IoU (Intersection over Union) with 0.2 minimum threshold
- Groups all PPE detections by person index
- Separates unassigned PPE violations (no person match)
- Returns: `(ppe_groups_dict, unassigned_ppe_list)`

```python
def _group_ppe_by_person(ppe_detections: list, person_boxes: list[list[int]]):
    """Group PPE violations by person using IoU matching."""
```

**IoU Matching Algorithm:**
```
For each PPE violation bbox:
  - Calculate IoU with each person bbox
  - Select person with highest IoU (if > 0.2)
  - If matched: add to that person's group
  - If no match: add to unassigned list
```

#### 2. **Enhanced `_annotate()` Method**

##### Flow:
1. **Draw safe zone polygon** (unchanged)
2. **Process PPE violations** (NEW):
   - Separate PPE violations from other detections
   - Run person detection if PPE violations present
   - Group PPE by person
   - Draw grouped boxes with stacked labels
   - Draw unassigned PPE individually
3. **Draw other detections** (fire, face, zone violations)
4. **Draw status badge**

##### PPE Drawing Details:

**For Each Person with PPE Violations:**
- **Box**: Thick rectangle (3px) around person
- **Color**: Based on highest severity in violation group
  - `Red` (high): No helmet, dangerous violations
  - `Orange` (medium): No vest, no boots, etc.
  - `Yellow` (low): Minor violations
- **Labels**: Stacked vertically above person box
  - Format: `"No Helmet 95%"`, `"No Vest 87%"`, etc.
  - Each label has colored background matching box color
  - White text for visibility

**Visual Example:**
```
Person with 3 violations:
┌─────────────────────┐
│ No Helmet 95%       │ ← Label 1 (stacked)
│ No Vest 87%         │ ← Label 2 (stacked)
│ No Gloves 82%       │ ← Label 3 (stacked)
├─────────────────────┤
│                     │
│    [Person Box]     │ ← RED box (high severity group)
│    with IoU-matched │
│    violations       │
│                     │
└─────────────────────┘
```

### Detection Pipeline

```
ML API (ml_api service)
    ↓
Returns individual PPE detections:
  - no_helmet
  - no_vest
  - no_mask
  - no_gloves
  - no_boots
  - unsafe_material
    ↓
Backend Camera Worker receives detections
    ↓
During annotation:
  ├─ Separate PPE from other detections
  ├─ Run person detection (YOLO nano)
  ├─ Group PPE by person (IoU-based)
  ├─ Draw grouped boxes with stacked labels
  └─ Handle unassigned violations
    ↓
Final annotated frame with grouped PPE boxes
    ↓
Stream to frontend / Firebase recording
```

## PPE Violation Types

```python
PPE_VIOLATIONS = [
    "no_helmet",       # Hard hat / helmet missing
    "no_vest",         # Safety vest missing
    "no_mask",         # Protective mask missing
    "no_gloves",       # Safety gloves missing
    "no_boots",        # Safety boots missing
    "unsafe_material"  # Improper equipment
]
```

## Color Scheme

```python
_C_VIOLATION = (0, 0, 220)        # Red (BGR)   - HIGH severity
_C_PPE = (0, 165, 255)            # Orange (BGR) - MEDIUM severity
_C_LOW = (0, 220, 220)            # Yellow (BGR) - LOW severity

_SEVERITY_COLOR = {
    "high":   (0, 0, 220),
    "medium": (0, 165, 255),
    "low":    (0, 220, 220),
}
```

## Performance Characteristics

### Frame Processing
- **Display FPS**: 15 fps (display_interval = 1/15s)
- **Detection Frequency**: Every 10 display frames (~1.5s at 15 fps)
- **Person Detection**: Runs at 640px max scale for speed

### Model Loading
- **YOLO Model**: `yolov8n.pt` (nano - smallest, fastest)
- **Size**: ~6 MB
- **Inference Time**: ~50-100ms per frame (at 640x640)
- **Caching**: Global cache - loads once, reused for all frames

### Graceful Degradation
- If person detection fails: draws PPE individually
- If YOLO model fails to load: falls back to drawing all violations as-is
- All errors are logged but don't crash the system

## Configuration Parameters

### In `_detect_persons()`:
```python
scale = min(1.0, 640 / max(h, w))  # Max dimension capped at 640
conf = 0.40                         # YOLO confidence threshold
```

### In `_group_ppe_by_person()`:
```python
best_iou = 0.2  # Minimum IoU threshold for person-PPE matching
```

### In `_annotate()`:
```python
cv2.rectangle(out, (x1, y1), (x2, y2), color, 3)  # Person box: 3px thick
cv2.rectangle(out, (x1, y1), (x2, y2), color, 2)  # Other boxes: 2px thick
```

## Integration Points

### No Changes Required To:
- ✅ ML API (still returns individual PPE detections)
- ✅ Detection model training
- ✅ Firebase recording logic
- ✅ Violation cooldown deduplication

### What Changed:
- 📝 Camera worker annotation logic
- 📝 Added person detection during visualization
- 📝 Added PPE grouping algorithm

## Error Handling

### Try-Except Blocks:
1. **PPE grouping section** (entire block wrapped)
   - Logs: `[PPE grouping error: {e}]`
   - Fallback: draws PPE individually

2. **Person detection** (in `_detect_persons()`)
   - Logs: `[PPE] Person detection error: {e}`
   - Returns: empty list (graceful fail)

3. **Model loading** (in `_get_person_model()`)
   - Logs: `[PPE] Failed to load person model: {e}`
   - Returns: None

## Testing Checklist

- [ ] PPE violations detected and grouped by person
- [ ] Multiple PPE violations on same person show as single box
- [ ] Labels stack vertically above person box
- [ ] Color reflects highest severity in group
- [ ] Unassigned PPE violations drawn individually (fallback)
- [ ] No person detected: PPE drawn individually
- [ ] Performance: <3 additional fps drop
- [ ] Restart/reload: model caches correctly
- [ ] Error logging: check logs for any exceptions

## Logs to Monitor

```
[PPE] Person detection model loaded
[PPE] Person detection error: ...
[PPE] Failed to load person model: ...
[Cam {camera_id}] PPE grouping error: ...
```

## Future Enhancements

1. **Persist PPE groups in detection object**: Return grouped detections from ML API
2. **Advanced tracking**: Track individual persons across frames for better grouping
3. **Severity-based actions**: Different UI/alert behaviors for high vs medium PPE violations
4. **Deep learning-based person re-identification**: Better person matching across frames
5. **Configurable grouping threshold**: Allow users to adjust IoU matching sensitivity

## References

### Related Files:
- [camera_worker.py](/backend/app/workers/camera_worker.py) - Main implementation
- [detect_router.py](/mlmodels/ml_api/detect_router.py) - ML API detection endpoint
- [firebase_db.py](/backend/app/core/firebase_db.py) - Violation recording

### External Resources:
- YOLO v8 Documentation: https://docs.ultralytics.com/
- IoU (Intersection over Union): Standard object detection metric
- OpenCV Drawing: https://docs.opencv.org/master/d6/d6e/group__imgproc__draw.html
