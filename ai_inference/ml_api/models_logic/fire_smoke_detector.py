

# models/fire_smoke_detector.py
# pyrefly: ignore [missing-import]
from ultralytics import YOLO
import cv2
import os
import argparse
from tqdm import tqdm

BASE_DIR = os.path.dirname(os.path.dirname(__file__))
MODEL_PATH = os.path.join(BASE_DIR, "weights", "fire_best.pt")
OUTPUT_DIR = os.path.join(BASE_DIR, "data", "output_videos")
INPUT_DIR = os.path.join(BASE_DIR, "data", "input_videos")
os.makedirs(OUTPUT_DIR, exist_ok=True)


def load_fire_smoke_model():
    """Load the trained fire/smoke YOLO model once. Returns model or None."""
    try:
        if os.path.exists(MODEL_PATH):
            return YOLO(MODEL_PATH)
        return None
    except Exception:
        return None


def annotate_fire_smoke(frame, model):
    """Annotate a BGR frame in-place with fire/smoke detections using orange boxes."""
    if model is None:
        return frame
    try:
        results = model(frame, verbose=False)
        for r in results:
            for box in r.boxes:
                x1, y1, x2, y2 = map(int, box.xyxy[0])
                cls = int(box.cls[0])
                label = model.names.get(cls, str(cls))
                cv2.rectangle(frame, (x1, y1), (x2, y2), (0, 140, 255), 2)
                cv2.putText(frame, label, (x1, y1 - 10),
                            cv2.FONT_HERSHEY_SIMPLEX, 0.65, (0, 140, 255), 2)
    except Exception:
        pass
    return frame


def detect_fire_smoke(video_path, output_path=None):
    """Standalone helper: process video and save with fire/smoke annotations.
    
    video_path: name of file in data/input_videos or full path
    output_path: custom output path (default: data/output_videos/processed_<name>.mp4)
    """
    # Resolve video path robustly
    candidate_paths = [
        video_path,
        os.path.join(BASE_DIR, video_path),
        os.path.join(INPUT_DIR, os.path.basename(video_path)),
    ]
    
    cap = None
    opened = False
    for vp in candidate_paths:
        cap = cv2.VideoCapture(vp)
        if cap.isOpened():
            video_path = vp
            opened = True
            break
        else:
            try:
                cap.release()
            except Exception:
                pass
    
    if not opened:
        raise RuntimeError(f"Cannot open video. Tried: {candidate_paths}")
    
    model = load_fire_smoke_model()
    if model is None:
        print("  Fire/smoke model not found. Processing without detection.")

    width = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
    height = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
    fps = cap.get(cv2.CAP_PROP_FPS) or 25
    total_frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT)) or 0

    # Set output path
    if output_path is None:
        output_path = os.path.join(OUTPUT_DIR, f"processed_{os.path.basename(video_path)}")
    elif not output_path.endswith('.mp4'):
        output_path = os.path.join(OUTPUT_DIR, output_path)
    
    out = cv2.VideoWriter(output_path, cv2.VideoWriter_fourcc(*'mp4v'), fps, (width, height))

    pbar = tqdm(total=total_frames, desc="Processing Fire/Smoke", unit="frame") if total_frames > 0 else None
    frame_idx = 0
    
    while True:
        ret, frame = cap.read()
        if not ret:
            break
        frame_idx += 1
        if pbar is not None:
            pbar.update(1)
        
        annotate_fire_smoke(frame, model)
        out.write(frame)

    cap.release()
    out.release()
    if pbar is not None:
        pbar.close()
    
    print(f"\n Output saved at: {output_path}")
    return output_path


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--camera", type=int, default=0)
    ap.add_argument("--width", type=int, default=640)
    ap.add_argument("--height", type=int, default=480)
    ap.add_argument("--fullscreen", action="store_true")
    ap.add_argument("--video", type=str, default=None, help="Process video file instead of camera")
    ap.add_argument("--output", type=str, default=None, help="Output video filename")
    args = ap.parse_args()

    # Video processing mode
    if args.video:
        output_name = args.output or f"processed_{args.video}"
        detect_fire_smoke(args.video, output_path=output_name)
        return

    # Webcam mode
    model = load_fire_smoke_model()

    backend = getattr(cv2, 'CAP_DSHOW', None)
    if backend is None:
        backend = getattr(cv2, 'CAP_MSMF', getattr(cv2, 'CAP_ANY', 0))
    cap = cv2.VideoCapture(args.camera, backend)
    if not cap.isOpened():
        cap = cv2.VideoCapture(args.camera, getattr(cv2, 'CAP_ANY', 0))
    if not cap.isOpened():
        raise RuntimeError(f"Cannot open camera index {args.camera}")

    try:
        cap.set(cv2.CAP_PROP_BUFFERSIZE, 1)
        fourcc = cv2.VideoWriter_fourcc(*'MJPG')
        cap.set(cv2.CAP_PROP_FOURCC, fourcc)
        if args.width > 0: cap.set(cv2.CAP_PROP_FRAME_WIDTH, args.width)
        if args.height > 0: cap.set(cv2.CAP_PROP_FRAME_HEIGHT, args.height)
        cap.set(cv2.CAP_PROP_FPS, 30)
    except Exception:
        pass

    win_name = "Webcam - Fire/Smoke"
    try:
        cv2.namedWindow(win_name, cv2.WINDOW_NORMAL)
        if args.fullscreen:
            cv2.setWindowProperty(win_name, cv2.WND_PROP_FULLSCREEN, cv2.WINDOW_FULLSCREEN)
    except Exception:
        pass

    while True:
        ok, frame = cap.read()
        if not ok or frame is None:
            break
        annotate_fire_smoke(frame, model)
        cv2.imshow(win_name, frame)
        key = cv2.waitKey(1) & 0xFF
        if key in (27, ord('q'), ord('Q')):
            break

    cap.release()
    cv2.destroyAllWindows()


if __name__ == "__main__":
    main()
