# models/safe_zone.py
import cv2
import numpy as np
from ultralytics import YOLO
from shapely.geometry import Polygon
from tqdm import tqdm
import os
import argparse

BASE_DIR = os.path.dirname(os.path.dirname(__file__))
INPUT_DIR = os.path.join(BASE_DIR, "data", "input_videos")
OUTPUT_DIR = os.path.join(BASE_DIR, "data", "output_videos")
os.makedirs(OUTPUT_DIR, exist_ok=True)


#  Add this function
def load_yolo_model():
    """
    Loads YOLOv8n model for person detection.
    """
    try:
        model = YOLO("yolov8n.pt")
        print(" YOLOv8n model loaded successfully for Safe Zone Detection.")
        return model
    except Exception as e:
        print(f" Failed to load YOLOv8n model: {e}")
        return None


def run_safe_zone(input_video, safe_zone_points, output_name="output_safezone.mp4", progress_callback=None):
    input_path = os.path.join(INPUT_DIR, input_video)
    output_path = os.path.join(OUTPUT_DIR, output_name)

    cap = cv2.VideoCapture(input_path)
    ret, first_frame = cap.read()
    if not ret:
        print(" Could not read video.")
        return None

    h, w = first_frame.shape[:2]
    polygon = Polygon(safe_zone_points)

    model = load_yolo_model()
    if model is None:
        return None

    frame_skip = 3
    resize_width = 640
    scale_factor = resize_width / w if w > resize_width else 1.0

    fourcc = cv2.VideoWriter_fourcc(*'mp4v')
    fps = int(cap.get(cv2.CAP_PROP_FPS)) or 25
    out = cv2.VideoWriter(output_path, fourcc, fps // frame_skip, (w, h))

    total_frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
    print("\n Processing Safe Zone video...\n")

    for i in tqdm(range(0, total_frames, frame_skip), desc="Processing", unit="frame"):
        cap.set(cv2.CAP_PROP_POS_FRAMES, i)
        ret, frame = cap.read()
        if not ret:
            break

        small = cv2.resize(frame, (int(w * scale_factor), int(h * scale_factor)))
        results = model(small, verbose=False)

        for r in results:
            for box in r.boxes:
                cls = int(box.cls[0])
                if model.names[cls] != "person":
                    continue

                x1, y1, x2, y2 = [int(v / scale_factor) for v in box.xyxy[0]]
                person_box = Polygon([(x1, y1), (x2, y1), (x2, y2), (x1, y2)])

                if polygon.intersects(person_box):
                    color, label = (0, 255, 0), "Safe"
                else:
                    color, label = (0, 0, 255), "Unsafe"

                cv2.rectangle(frame, (x1, y1), (x2, y2), color, 2)
                cv2.putText(frame, label, (x1, y1 - 10),
                            cv2.FONT_HERSHEY_SIMPLEX, 0.7, color, 2)

        cv2.polylines(frame, [np.array(safe_zone_points, np.int32)], True, (255, 255, 0), 2)
        out.write(frame)

        if progress_callback:
            progress_callback((i + 1) / total_frames, f"Processing frame {i + 1}/{total_frames}")

    cap.release()
    out.release()
    print(f"\n Saved as {output_path}")
    return output_path


def _draw_polygon_interactive(frame):
    """
    Interactive polygon drawing on a frame.
    Click to add points, press 'Enter' to finish, 'C' to clear, 'ESC' to cancel.
    Returns list of (x, y) points or None if cancelled.
    """
    points = []
    img_copy = frame.copy()
    
    def mouse_callback(event, x, y, flags, param):
        if event == cv2.EVENT_LBUTTONDOWN:
            points.append((x, y))
            cv2.circle(img_copy, (x, y), 5, (0, 255, 0), -1)
            if len(points) > 1:
                cv2.line(img_copy, points[-2], points[-1], (0, 255, 0), 2)
            cv2.imshow("Draw Safe Zone (Click to add points, ENTER to finish, C to clear, ESC to cancel)", img_copy)
    
    cv2.namedWindow("Draw Safe Zone (Click to add points, ENTER to finish, C to clear, ESC to cancel)")
    cv2.setMouseCallback("Draw Safe Zone (Click to add points, ENTER to finish, C to clear, ESC to cancel)", mouse_callback)
    cv2.imshow("Draw Safe Zone (Click to add points, ENTER to finish, C to clear, ESC to cancel)", img_copy)
    
    while True:
        key = cv2.waitKey(0) & 0xFF
        if key == 13:  # Enter
            if len(points) >= 3:
                # Close polygon by connecting last point to first
                cv2.line(img_copy, points[-1], points[0], (0, 255, 0), 2)
                cv2.imshow("Draw Safe Zone (Click to add points, ENTER to finish, C to clear, ESC to cancel)", img_copy)
                cv2.waitKey(500)
                cv2.destroyAllWindows()
                return points
            else:
                print("  Need at least 3 points to define a polygon.")
        elif key == ord('c') or key == ord('C'):
            points.clear()
            img_copy = frame.copy()
            cv2.imshow("Draw Safe Zone (Click to add points, ENTER to finish, C to clear, ESC to cancel)", img_copy)
        elif key == 27:  # ESC
            cv2.destroyAllWindows()
            return None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--camera", type=int, default=0)
    ap.add_argument("--width", type=int, default=640)
    ap.add_argument("--height", type=int, default=480)
    ap.add_argument("--safe-zone", type=str, default="")
    ap.add_argument("--poly-scale", type=float, default=1.0)
    ap.add_argument("--person-conf", type=float, default=0.50)
    ap.add_argument("--fullscreen", action="store_true")
    ap.add_argument("--video", type=str, default=None, help="Process video file instead of camera")
    ap.add_argument("--output", type=str, default=None, help="Output video filename")
    ap.add_argument("--draw", action="store_true", help="Interactively draw polygon on first frame")
    args = ap.parse_args()

    pts = None
    
    # Video processing mode
    if args.video:
        # Try to parse --safe-zone if provided
        if args.safe_zone:
            pts = _parse_polygon(args.safe_zone)
        
        # If no safe-zone provided or parsing failed, offer interactive drawing
        if not pts:
            if args.draw or not args.safe_zone:
                print(" Drawing mode: Click on the video's first frame to define safe zone polygon...")
                input_path = os.path.join(INPUT_DIR, args.video)
                if not os.path.exists(input_path):
                    input_path = args.video
                
                cap = cv2.VideoCapture(input_path)
                ret, first_frame = cap.read()
                cap.release()
                
                if ret and first_frame is not None:
                    pts = _draw_polygon_interactive(first_frame)
                else:
                    print(" Could not read video first frame.")
                    return
                
                if not pts:
                    print(" Polygon drawing cancelled.")
                    return
        
        if not pts:
            print(" Safe zone points required for video processing. Use --safe-zone or --draw")
            return
        
        output_name = args.output or "output_safezone.mp4"
        run_safe_zone(args.video, pts, output_name=output_name)
        return

    # Webcam mode
    polygon = None
    if args.draw:
        # For webcam, allow drawing on first frame
        print(" Drawing mode: Opening webcam to draw safe zone...")
        model = load_yolo_model()
        if model is None:
            raise RuntimeError("YOLO model failed to load")
        
        backend = getattr(cv2, 'CAP_DSHOW', None)
        if backend is None:
            backend = getattr(cv2, 'CAP_MSMF', getattr(cv2, 'CAP_ANY', 0))
        cap = cv2.VideoCapture(args.camera, backend)
        if not cap.isOpened():
            cap = cv2.VideoCapture(args.camera, getattr(cv2, 'CAP_ANY', 0))
        
        if cap.isOpened():
            ret, frame = cap.read()
            cap.release()
            if ret and frame is not None:
                pts = _draw_polygon_interactive(frame)
                if pts:
                    polygon = Polygon(pts)
        
        if not pts:
            print(" Polygon drawing cancelled.")
            return
    else:
        # Parse --safe-zone for webcam mode
        pts = _parse_polygon(args.safe_zone)
        if pts and 0 < args.poly_scale != 1.0:
            cx = sum(p[0] for p in pts) / len(pts)
            cy = sum(p[1] for p in pts) / len(pts)
            scaled = []
            for (x, y) in pts:
                sx = cx + (x - cx) * args.poly_scale
                sy = cy + (y - cy) * args.poly_scale
                scaled.append((int(round(sx)), int(round(sy))))
            pts = scaled
        polygon = Polygon(pts) if pts else None

    # Webcam streaming mode
    model = load_yolo_model()
    if model is None:
        raise RuntimeError("YOLO model failed to load")

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

    win_name = "Webcam - Safe Zone"
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
        results = model(frame, verbose=False, conf=args.person_conf)
        for r in results:
            for box in getattr(r, 'boxes', []):
                cls = int(box.cls[0])
                if model.names.get(cls, str(cls)) != "person":
                    continue
                x1, y1, x2, y2 = [int(v) for v in box.xyxy[0]]
                color = (0, 255, 255)
                label = "Unknown"
                if polygon is not None:
                    person_poly = Polygon([(x1, y1), (x2, y1), (x2, y2), (x1, y2)])
                    inside = polygon.intersects(person_poly)
                    color = (0, 255, 0) if inside else (0, 0, 255)
                    label = "Safe" if inside else "Unsafe"
                cv2.rectangle(frame, (x1, y1), (x2, y2), color, 2)
                if label != "Unknown":
                    cv2.putText(frame, label, (x1, y1 - 10), cv2.FONT_HERSHEY_SIMPLEX, 0.7, color, 2)
        if polygon is not None and pts is not None:
            cv2.polylines(frame, [np.array(pts, np.int32)], True, (255, 255, 0), 2)
        cv2.imshow(win_name, frame)
        key = cv2.waitKey(1) & 0xFF
        if key in (27, ord('q'), ord('Q')):
            break

    cap.release()
    cv2.destroyAllWindows()


if __name__ == "__main__":
    main()
