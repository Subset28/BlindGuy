"""Payload generator for simulator test scenarios."""
import time
import math
import json
from typing import List, Dict, Any

def make_object(obj_id: str, cls: str, t: float, phase: float = 0.0) -> Dict[str, Any]:
    pan = math.sin(t * 0.8 + phase) * 0.9
    dist = 6.0 + math.cos(t * 0.6 + phase) * 4.0
    velocity = abs(0.6 * math.sin(t * 0.6 + phase))
    return {
        "object_id": obj_id,
        "class": cls,
        "confidence": 0.9,
        "bbox": {
            "x_center_norm": float((pan + 1.0) / 2.0),
            "y_center_norm": 0.5,
            "width_norm": 0.18,
            "height_norm": 0.14,
        },
        "distance_m": round(max(0.5, dist), 2),
        "pan_value": round(pan, 3),
        "velocity_mps": round(velocity, 2),
        "priority": "HIGH" if dist < 3.0 else "NORMAL",
    }

def make_frame(objects: List[Dict[str, Any]], frame_id: int = 0) -> Dict[str, Any]:
    return {
        "frame_id": frame_id,
        "timestamp_ms": int(time.time() * 1000),
        "vision_duration_ms": 20,
        "objects": objects,
    }

def scenario_moving_car(frame_id: int = 0, t: float = None) -> Dict[str, Any]:
    if t is None:
        t = time.time()
    obj = make_object("car_001", "car", t)
    return make_frame([obj], frame_id=frame_id)

def scenario_multiple(frame_id: int = 0, t: float = None) -> Dict[str, Any]:
    if t is None:
        t = time.time()
    objs = [make_object("car_001", "car", t, 0.0), make_object("person_001", "person", t, 1.5), make_object("bicycle_001", "bicycle", t, 3.0)]
    return make_frame(objs, frame_id=frame_id)

if __name__ == "__main__":
    # simple CLI: print a moving car payload
    frame = scenario_moving_car(frame_id=1)
    print(json.dumps(frame, indent=2))
