"""
Integrated webcam tester for Face Recognition + Safe-Zone (YOLO) + Fire/Smoke.

Usage examples:
  python -m models.test_webcam --camera 0 --every 3 --long-side 480 \
      --safe-zone "100,100;540,100;540,380;100,380"
"""

import cv2
import time
import argparse
import numpy as np
from shapely.geometry import Polygon
import os

from models.face_recognition import load_known_embeddings, detect_faces_in_frame
from models.safe_zone import load_yolo_model
from models.fire_smoke_detector import load_fire_smoke_model, annotate_fire_smoke


def parse_polygon(arg: str):
    if not arg:
        return None
    pts = []
    try:
        for pair in arg.split(";"):
            x, y = pair.split(",")
            pts.append((int(float(x)), int(float(y))))
        if len(pts) >= 3:
            return pts
    except Exception:
        pass
    return None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--camera", type=int, default=0, help="Webcam index (default 0)")
    ap.add_argument("--width", type=int, default=640, help="Capture width (0=driver default)")
    ap.add_argument("--height", type=int, default=480, help="Capture height (0=driver default)")
    ap.add_argument("--every", type=int, default=3, help="Process every Nth frame (default 3)")
    ap.add_argument("--long-side", type=int, default=480, help="Resize long side for speed (0=off)")
    ap.add_argument("--safe-zone", type=str, default="", help="Polygon points: 'x1,y1;x2,y2;...' (optional)")
    ap.add_argument("--poly-scale", type=float, default=1.0, help="Uniform scale factor for safe-zone polygon (e.g., 0.8 to reduce size)")
    ap.add_argument("--poly-scale-x", type=float, default=1.0, help="Non-uniform scale factor along X axis (overrides --poly-scale on X if provided)")
    ap.add_argument("--poly-scale-y", type=float, default=1.0, help="Non-uniform scale factor along Y axis (overrides --poly-scale on Y if provided)")
    ap.add_argument("--person-conf", type=float, default=0.50, help="YOLO person confidence threshold")
    ap.add_argument("--fullscreen", action="store_true", help="Display camera window in fullscreen")
    ap.add_argument("--video", type=str, default="", help="Path to a prerecorded video file (overrides --camera)")
    ap.add_argument("--process-fps", type=float, default=0.0, help="Target processing FPS (overrides --every when > 0)")
    ap.add_argument("--output", type=str, default="", help="Optional path to save annotated output video (e.g., output.mp4)")
    args = ap.parse_args()

    safe_zone_pts = parse_polygon(args.safe_zone)
    # Optionally scale polygon around its centroid to reduce/increase size
    if safe_zone_pts:
        # Determine per-axis scaling, defaulting to uniform when provided
        sx = args.poly_scale_x if args.poly_scale_x is not None else 1.0
        sy = args.poly_scale_y if args.poly_scale_y is not None else 1.0
        # If user specified only uniform scale, apply it to both axes unless explicitly overridden
        if args.poly_scale and args.poly_scale != 1.0:
            if sx == 1.0:
                sx = args.poly_scale
            if sy == 1.0:
                sy = args.poly_scale
        # Apply only when scaling differs from identity
        if (sx != 1.0) or (sy != 1.0):
            cx = sum(p[0] for p in safe_zone_pts) / len(safe_zone_pts)
            cy = sum(p[1] for p in safe_zone_pts) / len(safe_zone_pts)
            scaled_pts = []
            for (x, y) in safe_zone_pts:
                nx = cx + (x - cx) * sx
                ny = cy + (y - cy) * sy
                scaled_pts.append((int(round(nx)), int(round(ny))))
            safe_zone_pts = scaled_pts
    polygon = Polygon(safe_zone_pts) if safe_zone_pts else None

    print("Loading models (faces, yolo, fire/smoke)...")
    known_names, known_embs, mtcnn, resnet = load_known_embeddings()
    yolo = load_yolo_model()
    fire_model = load_fire_smoke_model()
    print(f"Loaded {len(known_names)} known faces")

    # Open capture source: video file or webcam
    if args.video:
        cap = cv2.VideoCapture(args.video)
        if not cap.isOpened():
            raise RuntimeError(f"Cannot open video file: {args.video}")
    else:
        # Stable Windows capture settings
        backend = getattr(cv2, 'CAP_DSHOW', None)
        if backend is None:
            backend = getattr(cv2, 'CAP_MSMF', getattr(cv2, 'CAP_ANY', 0))
        cap = cv2.VideoCapture(args.camera, backend)
        if not cap.isOpened():
            cap = cv2.VideoCapture(args.camera, getattr(cv2, 'CAP_ANY', 0))
        if not cap.isOpened():
            raise RuntimeError(f"Cannot open camera index {args.camera}")

        # Configure camera: MJPG, resolution, fps, small buffer (skip for file)
        try:
            cap.set(cv2.CAP_PROP_BUFFERSIZE, 1)
            fourcc = cv2.VideoWriter_fourcc(*'MJPG')
            cap.set(cv2.CAP_PROP_FOURCC, fourcc)
            if args.width > 0: cap.set(cv2.CAP_PROP_FRAME_WIDTH, args.width)
            if args.height > 0: cap.set(cv2.CAP_PROP_FRAME_HEIGHT, args.height)
            cap.set(cv2.CAP_PROP_FPS, 30)
        except Exception:
            pass

    print("Press Q or ESC to quit")
    win_name = "Webcam - Face + SafeZone + Fire/Smoke"
    try:
        cv2.namedWindow(win_name, cv2.WINDOW_NORMAL)
        if args.fullscreen:
            cv2.setWindowProperty(win_name, cv2.WND_PROP_FULLSCREEN, cv2.WINDOW_FULLSCREEN)
    except Exception:
        pass
    # Key delay: sync to video FPS if using a file, otherwise minimal latency
    key_delay = 1
    video_fps = None
    writer = None
    if args.video:
        fps = cap.get(cv2.CAP_PROP_FPS)
        if not fps or fps != fps or fps <= 1:
            fps = 30.0
        key_delay = max(1, int(1000.0 / fps))
        video_fps = fps
    # Timing helpers for process-fps gating
    last_process_ms = -1.0
    last_process_time = 0.0
    start_time = time.time()
    frame_idx = 0
    last_face_results = {}
    while True:
        ok, frame = cap.read()
        if not ok or frame is None:
            print("Frame grab failed, exiting.")
            break

        t0 = time.time()

        # Optional resize for compute speed
        work = frame
        scale = 1.0
        if args.long_side and args.long_side > 0:
            h, w = frame.shape[:2]
            long_side = max(h, w)
            if long_side > args.long_side:
                scale = args.long_side / float(long_side)
                work = cv2.resize(frame, (int(w*scale), int(h*scale)))

        # Decide whether to process this frame
        if args.process_fps and args.process_fps > 0:
            interval_ms = 1000.0 / float(args.process_fps)
            if args.video:
                pos_ms = cap.get(cv2.CAP_PROP_POS_MSEC)
                if not pos_ms or pos_ms != pos_ms or pos_ms <= 0:
                    if video_fps and video_fps > 0:
                        pos_ms = (frame_idx / video_fps) * 1000.0
                    else:
                        pos_ms = (time.time() - start_time) * 1000.0
                do_process = (last_process_ms < 0) or ((pos_ms - last_process_ms) >= interval_ms)
                if do_process:
                    last_process_ms = pos_ms
            else:
                now = time.time()
                do_process = (last_process_time == 0.0) or ((now - last_process_time) >= (interval_ms / 1000.0))
                if do_process:
                    last_process_time = now
        else:
            do_process = (frame_idx % max(1, args.every)) == 0

        # Face recognition (update cache on schedule)
        if do_process:
            face_results, _ = detect_faces_in_frame(work, known_names, known_embs, mtcnn, resnet)
            last_face_results = face_results
        else:
            face_results = last_face_results
        # Draw faces (disabled: we only want combined label on person box)
        if False and face_results:
            for (x1, y1, x2, y2), label in face_results.items():
                if scale != 1.0:
                    X1 = int(x1/scale); Y1 = int(y1/scale); X2 = int(x2/scale); Y2 = int(y2/scale)
                else:
                    X1, Y1, X2, Y2 = x1, y1, x2, y2
                color = (0, 255, 0) if label != "Unknown" else (0, 0, 255)
                cv2.rectangle(frame, (X1, Y1), (X2, Y2), color, 2)
                cv2.putText(frame, label, (X1, max(20, Y1 - 10)), cv2.FONT_HERSHEY_SIMPLEX, 0.7, color, 2)

        # YOLO person detection + safe-zone + face association
        if yolo is not None and do_process:
            results = yolo(work, verbose=False, conf=args.person_conf)
            for r in results:
                for box in getattr(r, 'boxes', []):
                    cls = int(box.cls[0])
                    if yolo.names.get(cls, str(cls)) != "person":
                        continue
                    if scale != 1.0:
                        x1, y1, x2, y2 = [int(v/scale) for v in box.xyxy[0]]
                    else:
                        x1, y1, x2, y2 = [int(v) for v in box.xyxy[0]]
                    # Safe-zone status
                    status = "Unknown"
                    color = (0, 255, 255)
                    if polygon is not None:
                        person_poly = Polygon([(x1, y1), (x2, y1), (x2, y2), (x1, y2)])
                        inside = polygon.intersects(person_poly)
                        status = "Safe" if inside else "Unsafe"
                        color = (0, 255, 0) if inside else (0, 0, 255)
                    # Associate nearest face (prefer faces whose center lies inside the person box)
                    name = "Unknown"
                    min_dist = float("inf")
                    found_inside = False
                    pcx, pcy = (x1 + x2) // 2, (y1 + y2) // 2
                    for (fx1, fy1, fx2, fy2), flabel in (face_results or {}).items():
                        # map face boxes to original scale if needed
                        if scale != 1.0:
                            FX1 = int(fx1/scale); FY1 = int(fy1/scale); FX2 = int(fx2/scale); FY2 = int(fy2/scale)
                        else:
                            FX1, FY1, FX2, FY2 = fx1, fy1, fx2, fy2
                        fcx, fcy = (FX1 + FX2)//2, (FY1 + FY2)//2
                        inside_box = (x1 <= fcx <= x2) and (y1 <= fcy <= y2)
                        dist = (pcx - fcx)**2 + (pcy - fcy)**2
                        if inside_box:
                            found_inside = True
                            if dist < min_dist:
                                min_dist = dist
                                name = flabel
                        elif not found_inside and dist < min_dist:
                            min_dist = dist
                            name = flabel
                    # If nearest face is far away, keep Unknown
                    if not found_inside and min_dist > (0.15 * (x2 - x1) * (x2 - x1)):
                        name = "Unknown"
                    combined = f"{name} [{status}]" if status != "Unknown" else name
                    cv2.rectangle(frame, (x1, y1), (x2, y2), color, 2)
                    cv2.putText(frame, combined, (x1, y1 - 10), cv2.FONT_HERSHEY_SIMPLEX, 0.7, color, 2)
            # Draw polygon
            if polygon is not None and safe_zone_pts is not None:
                cv2.polylines(frame, [np.array(safe_zone_pts, np.int32)], True, (255, 255, 0), 2)

        # Fire/Smoke annotate on the original-size frame
        if do_process:
            annotate_fire_smoke(frame, fire_model)

        dt_ms = (time.time() - t0) * 1000.0
        cv2.putText(frame, f"Proc: {dt_ms:.0f} ms (every {max(1,args.every)})", (10, 30),
                    cv2.FONT_HERSHEY_SIMPLEX, 1, (200, 0, 0), 2)
        # Lazy-init writer and save frames if requested
        if args.output:
            if writer is None:
                try:
                    out_dir = os.path.dirname(args.output)
                    if out_dir and not os.path.exists(out_dir):
                        os.makedirs(out_dir, exist_ok=True)
                except Exception:
                    pass
                fourcc = cv2.VideoWriter_fourcc(*'mp4v')
                fps_val = video_fps if (video_fps and video_fps > 0) else 30.0
                h_out, w_out = frame.shape[:2]
                writer = cv2.VideoWriter(args.output, fourcc, float(fps_val), (w_out, h_out))
            if writer is not None:
                try:
                    writer.write(frame)
                except Exception:
                    pass

        cv2.imshow(win_name, frame)
        key = cv2.waitKey(key_delay) & 0xFF
        if key in (27, ord('q'), ord('Q')):  # ESC or Q
            break

        frame_idx += 1

    cap.release()
    if writer is not None:
        try:
            writer.release()
            print(f"Saved output to: {args.output}")
        except Exception:
            pass
    cv2.destroyAllWindows()


if __name__ == "__main__":
    main()