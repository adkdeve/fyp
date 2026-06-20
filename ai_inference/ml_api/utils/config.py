"""
Configuration settings for AI Video Processing System
"""
import os

# Base directories
BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MODELS_DIR = os.path.join(BASE_DIR, "models")
WEIGHTS_DIR = os.path.join(BASE_DIR, "weights")
DATA_DIR = os.path.join(BASE_DIR, "data")

# Known faces and embeddings
KNOWN_FACES_DIR = os.path.join(BASE_DIR, "known_faces")
EMBEDDINGS_DIR = os.path.join(DATA_DIR, "embeddings")
EMBEDDINGS_FILE = os.path.join(EMBEDDINGS_DIR, "embeddings.pkl")
EMBEDDINGS_METADATA_FILE = os.path.join(EMBEDDINGS_DIR, "embeddings_metadata.json")
INSIGHTFACE_EMBEDDINGS_FILE = os.path.join(EMBEDDINGS_DIR, "insightface_embeddings.pkl")
INSIGHTFACE_EMBEDDINGS_METADATA_FILE = os.path.join(EMBEDDINGS_DIR, "insightface_embeddings_metadata.json")

# Model weights
FIRE_SMOKE_WEIGHTS = os.path.join(WEIGHTS_DIR, "best.pt")
YOLO_PERSON_MODEL = "yolov8n.pt"
# YOLOv8n-face: 7 faster than MTCNN, single-pass face detection
# auto-downloaded by ultralytics on first use, or place in weights/
YOLO_FACE_MODEL = os.path.join(WEIGHTS_DIR, "yolov8n-face.pt")
INSIGHTFACE_MODEL_NAME = "buffalo_sc"  # larger RetinaFace + ArcFace; more accurate but slower than buffalo_sc
INSIGHTFACE_DET_SIZE = (640, 640)

# Processing settings
DEFAULT_DETECTION_WIDTH = 640  # Resize frame width for faster detection
FRAME_SKIP = 1  # Process every N frames (1 = process all)
DEFAULT_SCALE_FACTOR = 0.5  # Scale factor for faster inference

# ML inference resolution: resize ALL model inputs to this size for speed.
# Run inference on 320320 for faster processing on IP camera streams (reduced from 416).
# This cuts inference time by ~50% vs 416416, helping with queue overflow.
ML_INFERENCE_SIZE = 320

# Audio pipeline constants  single source of truth for all audio paths.
# AUDIO_CHUNK_SAMPLES must match the sounddevice InputStream blocksize exactly
# so that the video-file audio path sends identically-shaped chunks to the
# distress model as the live microphone path does.
AUDIO_SAMPLE_RATE = 16000   # Hz  16 kHz mono, matches distress model training
AUDIO_CHUNK_SAMPLES = 32000 # samples per chunk = 2.0 s at 16 kHz (must match mic blocksize)


# Model confidence thresholds
FACE_SIMILARITY_THRESHOLD = 0.52  # lowered from 0.58 for better matching at distance
INSIGHTFACE_SIMILARITY_THRESHOLD = 0.42  # lowered from 0.48  distant faces have lower embedding quality
INSIGHTFACE_SIMILARITY_THRESHOLD_SMALL_FACE = 0.38  # even lower for small/distant faces (face width < 80px)
INSIGHTFACE_AUTH_HIT_THRESHOLD = 5
INSIGHTFACE_UNAUTH_HIT_THRESHOLD = 20
PERSON_CONFIDENCE_THRESHOLD = 0.50
PERSON_CONFIDENCE_THRESHOLD_SMALL = 0.20  # lower for small persons (width < 80px)  catch distant people
FIRE_SMOKE_CONFIDENCE_THRESHOLD = 0.45

# Distress detection settings
# Alert throttling
ALERT_COOLDOWN_SECONDS = 30  # minimum seconds between identical alerts

DISTRESS_EMOTIONS = ["sad", "angry", "fear"]  # Emotions that indicate distress
ALL_EMOTIONS = ["happy", "sad", "angry", "fear", "disgust", "surprise", "neutral"]

# Cry detection model settings
MODELS_LOGIC_DIR = os.path.join(BASE_DIR, "models_logic")
CRY_MODEL_PATH = os.path.join(MODELS_LOGIC_DIR, "cry_model_final_v9.h5")
FACE_DNN_PROTO_PATH = os.path.join(MODELS_LOGIC_DIR, "deploy.prototxt")
FACE_DNN_CAFFE_PATH = os.path.join(MODELS_LOGIC_DIR, "res10_300x300_ssd_iter_140000.caffemodel")
DISTRESS_IMG_SIZE = (96, 96)
DISTRESS_FACE_CONF_THRESH = 0.5     # OpenCV DNN face detection confidence
DISTRESS_MIN_FACE_SIZE = 40         # Minimum face width in pixels
DISTRESS_BUFFER_SIZE = 10           # Rolling average window (smoothing)
DISTRESS_TRIGGER_THRESH = 0.65      # Must exceed this to flag distress
DISTRESS_RESET_THRESH = 0.35        # Must drop below this to clear distress

# Video settings
SUPPORTED_VIDEO_FORMATS = [".mp4", ".avi", ".mov", ".mkv", ".flv", ".wmv"]
DEFAULT_FPS = 25

# UI settings
SIDEBAR_WIDTH = 300
VIDEO_DISPLAY_WIDTH = 800

# Safe zone polygon
DEFAULT_SAFE_ZONE_COLOR = (255, 255, 0)  # Cyan in BGR
SAFE_COLOR = (0, 255, 0)  # Green
UNSAFE_COLOR = (0, 0, 255)  # Red

# Ensure directories exist
os.makedirs(EMBEDDINGS_DIR, exist_ok=True)
os.makedirs(DATA_DIR, exist_ok=True)
