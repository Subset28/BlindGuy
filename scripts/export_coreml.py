#!/usr/bin/env python3
"""Export Ultralytics YOLOv8n to CoreML with NMS for Vision (iOS).

Run from repo root after: pip install ultralytics

Output: yolov8n.mlpackage in the current directory (add to Xcode / Swift package resources).
"""

from pathlib import Path

from ultralytics import YOLO


def main() -> None:
    model = YOLO("yolov8n.pt")
    out = model.export(
        format="coreml",
        nms=True,
        imgsz=640,
    )
    print("Exported:", out)
    p = Path(out)
    if p.exists():
        print("Place the .mlpackage in your iOS app target (or BlindGuyKit Resources) as yolov8n.mlpackage")


if __name__ == "__main__":
    main()
