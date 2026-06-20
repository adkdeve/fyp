import cv2
import numpy as np
import os
import sys
from shapely.geometry import Polygon
from tqdm import tqdm

from models.face_recognition import load_known_embeddings, detect_faces_in_frame
from models.safe_zone import load_yolo_model
from models.fire_smoke_detector import load_fire_smoke_model, annotate_fire_smoke

BASE_DIR = os.path.dirname(os.path.dirname(__file__))
INPUT_DIR = os.path.join(BASE_DIR, "data", "input_videos")
OUTPUT_DIR = os.path.join(BASE_DIR, "data", "output_videos")
os.makedirs(OUTPUT_DIR, exist_ok=True)

# Load models once (only if not already loaded)
if 'models_loaded' not in globals():
    known_names, known_embs, face_detector, face_encoder = load_known_embeddings()
    yolo = load_yolo_model()
    fire_smoke_model = load_fire_smoke_model()
    print(" Models loaded successfully!")
    globals()['models_loaded'] = True


def run_integrated_processing(input_video, safe_zone_points, output_name="output_integrated.mp4", progress_callback=None):
    input_path = os.path.join(INPUT_DIR, input_video)
    output_path = os.path.join(OUTPUT_DIR, output_name)

    cap = cv2.VideoCapture(input_path)
    ret, first_frame = cap.read()
    if not ret:
        print(" Could not read video.")
        return None

    h, w = first_frame.shape[:2]
    polygon = Polygon(safe_zone_points)
    fps = int(cap.get(cv2.CAP_PROP_FPS)) or 25
    total_frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
    fourcc = cv2.VideoWriter_fourcc(*'mp4v')
    out = cv2.VideoWriter(output_path, fourcc, fps, (w, h))

    print(f"\n Processing video ({total_frames} frames)...")

    # Terminal progress bar (only when no UI callback provided)
    pbar = None
    if progress_callback is None:
        pbar = tqdm(total=total_frames, desc="Processing", unit="frame")

    for frame_idx in range(total_frames):
        ret, frame = cap.read()
        if not ret:
            break

        # Progress update
        if progress_callback:
            progress_callback((frame_idx + 1) / total_frames, f"Processing frame {frame_idx + 1}/{total_frames}")
        else:
            if pbar is not None:
                pbar.update(1)


        # --- Face Recognition ---
        face_results, _ = detect_faces_in_frame(frame, known_names, known_embs, face_detector, face_encoder)

        # --- YOLO Person Detection ---
        results = yolo(frame, verbose=False)
        for r in results:
            for box in r.boxes:
                cls = int(box.cls[0])
                if yolo.names[cls] != "person":
                    continue

                x1, y1, x2, y2 = map(int, box.xyxy[0])
                person_poly = Polygon([(x1, y1), (x2, y1), (x2, y2), (x1, y2)])

                #  Safe zone check
                safe_status = "Safe" if polygon.intersects(person_poly) else "Unsafe"
                color = (0, 255, 0) if safe_status == "Safe" else (0, 0, 255)

                #  Associate face with this person box
                # Priority 1: face center inside person box; Priority 2: nearest face within threshold
                name = "Unknown"
                min_dist = float("inf")
                found_inside = False
                person_center = ((x1 + x2) // 2, (y1 + y2) // 2)

                for (fx1, fy1, fx2, fy2), label in face_results.items():
                    face_center = ((fx1 + fx2) // 2, (fy1 + fy2) // 2)

                    # Check if face center lies within person bbox
                    is_inside = (x1 <= face_center[0] <= x2) and (y1 <= face_center[1] <= y2)
                    dist = np.linalg.norm(np.array(person_center) - np.array(face_center))

                    if is_inside:
                        found_inside = True
                        if dist < min_dist:
                            min_dist = dist
                            name = label
                    elif not found_inside:
                        # Fallback candidate: nearest face even if not strictly inside
                        if dist < min_dist:
                            min_dist = dist
                            name = label

                # If the best face was only a fallback, enforce a reasonable distance threshold
                if not found_inside:
                    max_allowed = 200
                    if min_dist == float("inf") or min_dist > max_allowed:
                        name = "Unknown"

                #  Combine into single label (Face + Safe zone)
                combined_label = f"{name} [{safe_status}]"

                # Draw person box with label
                cv2.rectangle(frame, (x1, y1), (x2, y2), color, 2)
                cv2.putText(frame, combined_label, (x1, y1 - 10),
                            cv2.FONT_HERSHEY_SIMPLEX, 0.65, color, 2)

        # --- Draw all detected faces (border only, no text) ---
        for (fx1, fy1, fx2, fy2), label in face_results.items():
            color = (0, 255, 0) if label != "Unknown" else (0, 0, 255)
            cv2.rectangle(frame, (fx1, fy1), (fx2, fy2), color, 1)

        # --- Draw Safe Zone polygon ---
        cv2.polylines(frame, [np.array(safe_zone_points, np.int32)], True, (255, 255, 0), 2)

        # --- Fire/Smoke Detection overlay (if model available) ---
        frame = annotate_fire_smoke(frame, fire_smoke_model)

        out.write(frame)

    cap.release()
    out.release()
    if pbar is not None:
        pbar.close()
    print(f"\n Output saved at: {output_path}")
    return output_path



