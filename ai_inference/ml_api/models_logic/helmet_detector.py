"""
Helmet Detection Model
Detects no_helmet and no_vest violations using YOLO model.
"""

import os
from typing import Optional

# Global model instance
_helmet_model = None
_model_path = os.path.join(os.path.dirname(os.path.dirname(__file__)), "models", "helmet", "helmet_model.pt")


def load_helmet_model():
    """
    Load the helmet detection YOLO model.
    Returns the model instance or None if loading fails.
    """
    global _helmet_model
    
    if _helmet_model is not None:
        return _helmet_model
    
    try:
        from ultralytics import YOLO
        import torch
        
        # Optimize for CPU inference
        torch.set_num_threads(os.cpu_count() or 4)
        
        if not os.path.exists(_model_path):
            print(f"    Helmet model not found at {_model_path}")
            return None
        
        _helmet_model = YOLO(_model_path)
        print(f"    Helmet model loaded from {_model_path}")
        print(f"    Model classes: {list(_helmet_model.names.values())}")
        return _helmet_model
        
    except Exception as e:
        print(f"    Failed to load helmet model: {e}")
        return None


def detect_helmet_violations(frame, model=None, confidence_threshold=0.4):
    """
    Detect helmet violations in a frame.
    
    Args:
        frame: Input image (numpy array)
        model: YOLO model instance (optional, will load if not provided)
        confidence_threshold: Minimum confidence for detections
        
    Returns:
        List of detections: [{"type": "no_helmet"|"no_vest", "bbox": [x1,y1,x2,y2], "confidence": float}]
    """
    if model is None:
        model = load_helmet_model()
    
    if model is None:
        return []
    
    try:
        results = model(frame, verbose=False)
        detections = []
        
        # Class name normalization
        def normalize(name):
            return name.strip().lower().replace("-", "_").replace(" ", "_")
        
        # Violation class map
        class_map = {
            # No-helmet variants
            "no_helmet": "no_helmet",
            "no_hardhat": "no_helmet",
            "no_hard_hat": "no_helmet",
            "without_helmet": "no_helmet",
            "without_hardhat": "no_helmet",
            "no_safety_helmet": "no_helmet",
            "head": "no_helmet",
            "no_hardhat": "no_helmet",
            "no-hardhat": "no_helmet",
            # No-vest variants
            "no_vest": "no_vest",
            "no_safety_vest": "no_vest",
            "no_reflective_vest": "no_vest",
            "without_vest": "no_vest",
            "no_jacket": "no_vest",
            "no_safety_vest": "no_vest",
            "no-safety_vest": "no_vest",
        }
        
        for result in results:
            for box in result.boxes:
                conf = float(box.conf[0])
                raw_name = result.names[int(box.cls[0])]
                norm = normalize(raw_name)
                bbox = [int(x) for x in box.xyxy[0].tolist()]
                
                # Debug: print all detections above threshold
                if conf >= 0.25:
                    print(f"      Helmet model raw: '{raw_name}' -> '{norm}' (conf={conf:.2f})")
                
                if conf < confidence_threshold:
                    continue
                
                # Map to violation type
                violation_type = class_map.get(norm)
                if violation_type:
                    print(f"      -> Mapped to violation: {violation_type}")
                    detections.append({
                        "type": violation_type,
                        "bbox": bbox,
                        "confidence": conf
                    })
        
        return detections
        
    except Exception as e:
        print(f"    Error in helmet detection: {e}")
        return []
