from __future__ import annotations

from dataclasses import dataclass
from time import perf_counter

import numpy as np
from ultralytics import YOLO

from .config import VisualConfig
from .contracts import BBoxNorm, DetectedObject
from .tracker import ObjectTracker


@dataclass(slots=True)
class VisionResult:
    objects: list[DetectedObject]
    duration_ms: int


class VisionEngine:
    def __init__(self, config: VisualConfig) -> None:
        self._config = config
        self._model = YOLO(config.model_path)
        self._tracker = ObjectTracker(
            max_gap_s=config.max_tracking_gap_s,
            max_match_distance_norm=config.max_match_distance_norm,
        )
        self._names = self._model.names

    def process_frame(self, frame: np.ndarray) -> VisionResult:
        start = perf_counter()
        frame_h, frame_w = frame.shape[:2]
        results = self._model.predict(
            source=frame,
            conf=self._config.confidence_threshold,
            verbose=False,
            classes=None,
        )

        detections: list[dict] = []
        for result in results:
            for box in result.boxes:
                confidence = float(box.conf.item())
                class_id = int(box.cls.item())
                class_name = str(self._names[class_id])
                if class_name not in self._config.target_classes:
                    continue
                x1, y1, x2, y2 = [float(v) for v in box.xyxy[0].tolist()]
                bbox_w = max(x2 - x1, 1.0)
                bbox_h = max(y2 - y1, 1.0)
                x_center = (x1 + x2) / 2.0
                y_center = (y1 + y2) / 2.0

                pan_value = (x_center / frame_w - 0.5) * 2.0
                known_height = self._config.known_heights_m.get(class_name, 1.7)
                distance_m = (known_height * self._config.focal_length_px) / bbox_h
                distance_m = round(max(0.1, distance_m), 2)

                detections.append(
                    {
                        "class_name": class_name,
                        "confidence": round(confidence, 2),
                        "bbox": {
                            "x_center_norm": round(x_center / frame_w, 4),
                            "y_center_norm": round(y_center / frame_h, 4),
                            "width_norm": round(bbox_w / frame_w, 4),
                            "height_norm": round(bbox_h / frame_h, 4),
                        },
                        "distance_m": distance_m,
                        "pan_value": round(float(np.clip(pan_value, -1.0, 1.0)), 3),
                    }
                )

        tracked = self._tracker.update(detections)
        objects = [
            DetectedObject(
                object_id=item["object_id"],
                class_name=item["class_name"],
                confidence=item["confidence"],
                bbox=BBoxNorm(**item["bbox"]),
                distance_m=item["distance_m"],
                pan_value=item["pan_value"],
                velocity_mps=item["velocity_mps"],
                priority=item["priority"],
            )
            for item in tracked
        ]
        duration_ms = int((perf_counter() - start) * 1000)
        return VisionResult(objects=objects, duration_ms=duration_ms)

