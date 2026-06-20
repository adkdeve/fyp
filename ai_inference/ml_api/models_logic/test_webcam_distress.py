import cv2
import tensorflow as tf
import numpy as np
import os
from collections import defaultdict, deque
from keras.applications.mobilenet_v2 import preprocess_input

# ================= CONFIGURATION =================
# Resolve paths relative to this script's location
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.dirname(SCRIPT_DIR)

# 1. Webcam index (0 = default camera, 1 = second camera, etc.)
WEBCAM_INDEX = 0

# 2. Where the recorded output will be saved
OUTPUT_DIR = os.path.join(PROJECT_ROOT, "data", "output_videos")
OUTPUT_PATH = os.path.join(OUTPUT_DIR, "webcam_test_output.mp4")

# 3. Model path
MODEL_PATH = os.path.join(SCRIPT_DIR, "cry_model_final_v9.h5")

# Config Settings
IMG_SIZE = (96, 96)
FACE_CONF_THRESH = 0.5   # DNN face detector confidence threshold
MIN_FACE_SIZE = 40
BUFFER_SIZE = 10   # Averages the last 10 frames (~0.3 seconds) to stop flickering

# The "Sticky" Logic (Hysteresis)
TRIGGER_THRESH = 0.65  # Confidence must hit 65% to trigger distress alarm
RESET_THRESH = 0.35    # Confidence must drop below 35% to turn the alarm off

# Set to True to save the webcam output as a video file
SAVE_OUTPUT = True
# =================================================

os.makedirs(OUTPUT_DIR, exist_ok=True)

print(f"Loading model from {MODEL_PATH}...")
if not os.path.exists(MODEL_PATH):
    print(f"ERROR: Model file not found at {MODEL_PATH}")
    print("Please ensure 'cry_model_final_v9.h5' is in the models/ directory.")
    exit()

try:
    model = tf.keras.models.load_model(MODEL_PATH)
    print("Model loaded successfully.")
except Exception as e:
    print(f"Error loading model: {e}")
    exit()

# --- OpenCV DNN Face Detector (no MTCNN / no tf.keras conflict) ---
print("Initializing OpenCV DNN Face Detector...")
PROTO_PATH = os.path.join(SCRIPT_DIR, "deploy.prototxt")
CAFFEMODEL_PATH = os.path.join(SCRIPT_DIR, "res10_300x300_ssd_iter_140000.caffemodel")

# Auto-download the face detection model if missing
if not os.path.exists(PROTO_PATH) or not os.path.exists(CAFFEMODEL_PATH):
    print("Downloading OpenCV face detection model (~5MB)...")
    import urllib.request
    PROTO_URL = "https://raw.githubusercontent.com/opencv/opencv/master/samples/dnn/face_detector/deploy.prototxt"
    CAFFE_URL = "https://raw.githubusercontent.com/opencv/opencv_3rdparty/dnn_samples_face_detector_20170830/res10_300x300_ssd_iter_140000.caffemodel"
    urllib.request.urlretrieve(PROTO_URL, PROTO_PATH)
    urllib.request.urlretrieve(CAFFE_URL, CAFFEMODEL_PATH)
    print("Face detection model downloaded.")

face_net = cv2.dnn.readNetFromCaffe(PROTO_PATH, CAFFEMODEL_PATH)
print("Face detector ready.")

print(f"Opening webcam (index {WEBCAM_INDEX})...")
cap = cv2.VideoCapture(WEBCAM_INDEX)
if not cap.isOpened():
    print(f"Error: Could not open webcam at index {WEBCAM_INDEX}")
    print("Try changing WEBCAM_INDEX to 1 or 2 if you have multiple cameras.")
    exit()

# Get webcam properties
W = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
H = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
fps = cap.get(cv2.CAP_PROP_FPS)
if fps == 0 or fps > 60:
    fps = 30.0  # Default FPS for webcams that don't report properly

print(f"Webcam opened: {W}x{H} @ {fps:.0f} FPS")

out = None
if SAVE_OUTPUT:
    out = cv2.VideoWriter(OUTPUT_PATH, cv2.VideoWriter_fourcc(*"mp4v"), fps, (W, H))
    print(f"Recording output to: {OUTPUT_PATH}")

# --- State Management for Smoothing ---
cry_buffers = defaultdict(lambda: deque(maxlen=BUFFER_SIZE))
child_states = defaultdict(bool)
tracked_children = {}
child_id_counter = 0


def assign_child_id(cx, cy):
    global child_id_counter
    for cid, (px, py) in tracked_children.items():
        if abs(cx - px) < 50 and abs(cy - py) < 50:
            tracked_children[cid] = (cx, cy)
            return cid
    child_id_counter += 1
    tracked_children[child_id_counter] = (cx, cy)
    return child_id_counter


print("\n" + "=" * 50)
print("  ChildSense AI - Webcam Distress Detection")
print("  Press 'q' to quit")
print("=" * 50 + "\n")

frame_count = 0

while True:
    ret, frame = cap.read()
    if not ret:
        print("Failed to read frame from webcam. Retrying...")
        continue

    frame_count += 1

    # 1. Face detection using OpenCV DNN (fast, no TF dependency)
    blob = cv2.dnn.blobFromImage(frame, 1.0, (300, 300), (104.0, 177.0, 123.0))
    face_net.setInput(blob)
    detections = face_net.forward()

    for i in range(detections.shape[2]):
        confidence = detections[0, 0, i, 2]
        if confidence < FACE_CONF_THRESH:
            continue

        # 2. Get face coordinates
        box = detections[0, 0, i, 3:7] * np.array([W, H, W, H])
        x1, y1, x2, y2 = box.astype("int")
        x1, y1 = max(0, x1), max(0, y1)
        x2, y2 = min(W, x2), min(H, y2)

        w = x2 - x1
        h = y2 - y1
        if w < MIN_FACE_SIZE:
            continue

        ratio = h / (w + 1e-5)
        if ratio < 0.8 or ratio > 1.8:
            continue

        # 3. Tracking
        cx, cy = x1 + w // 2, y1 + h // 2
        child_id = assign_child_id(cx, cy)

        # 4. Face Extraction (with Padding to catch the chin/forehead)
        pad = int(w * 0.15)
        px1, py1 = max(0, x1 - pad), max(0, y1 - pad)
        px2, py2 = min(W, x2 + pad), min(H, y2 + pad)

        face_img = frame[py1:py2, px1:px2]
        if face_img.size == 0:
            continue

        # 5. Preprocessing specifically for MobileNetV2 Model
        face_input = cv2.resize(face_img, IMG_SIZE)
        face_input = cv2.cvtColor(face_input, cv2.COLOR_BGR2RGB)
        face_input = face_input.astype(np.float32)
        face_input = preprocess_input(face_input)
        face_batch = np.expand_dims(face_input, axis=0)

        # 6. Prediction
        cry_prob = model.predict(face_batch, verbose=0)[0][0]

        cry_buffers[child_id].append(cry_prob)
        cry_avg = np.mean(cry_buffers[child_id])

        # 7. Smoothing Logic (Hysteresis)
        currently_distressed = child_states[child_id]
        if not currently_distressed:
            if cry_avg > TRIGGER_THRESH:
                child_states[child_id] = True
        else:
            if cry_avg < RESET_THRESH:
                child_states[child_id] = False

        is_distressed = child_states[child_id]

        # 8. Draw UI
        color = (0, 0, 255) if is_distressed else (0, 255, 0)
        status_text = "DISTRESSED" if is_distressed else "NORMAL"
        conf_percent = int(cry_avg * 100)

        cv2.rectangle(frame, (px1, py1), (px2, py2), color, 2)

        label = f"ID:{child_id} | {status_text} {conf_percent}%"
        (text_w, text_h), _ = cv2.getTextSize(label, cv2.FONT_HERSHEY_SIMPLEX, 0.6, 2)
        cv2.rectangle(frame, (px1, py1 - 25), (px1 + text_w, py1), color, -1)
        cv2.putText(frame, label, (px1, py1 - 8), cv2.FONT_HERSHEY_SIMPLEX, 0.6, (255, 255, 255), 2)

    # Save frame if recording is enabled
    if out is not None:
        out.write(frame)

    # Show the frame live
    cv2.imshow("ChildSense AI - Webcam Distress Detection", frame)

    if cv2.waitKey(1) & 0xFF == ord('q'):
        print("\nStopped by user.")
        break

cap.release()
if out is not None:
    out.release()
cv2.destroyAllWindows()

print(f"\nSession ended after {frame_count} frames.")
if SAVE_OUTPUT:
    print(f"Recording saved to: {OUTPUT_PATH}")
