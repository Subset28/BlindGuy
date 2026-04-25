#!/usr/bin/env python3
"""Export Ultralytics YOLOv8n (COCO) to CoreML with NMS for Vision (iOS).

Run from repo root: pip install -r requirements.txt && python3 scripts/export_coreml.py

Output: yolov8n.mlpackage (renamed in cwd if the exporter returns a different stem).
Add to the Xcode app target Copy Bundle Resources.
"""

from __future__ import annotations

import shutil
from pathlib import Path

from ultralytics import YOLO

PT_FILE = "yolov8n.pt"
BUNDLE_STEM = "yolov8n"


def main() -> None:
    model = YOLO(PT_FILE)
    out = model.export(
        format="coreml",
        nms=True,
        imgsz=640,
    )
    out_path = Path(out).resolve()
    print("Exported:", out_path)
    if not out_path.exists():
        return
    dest = out_path.parent / f"{BUNDLE_STEM}.mlpackage"
    if out_path != dest:
        if dest.exists():
            shutil.rmtree(dest)
        out_path.rename(dest)
        print("Renamed to:", dest)
    print(
        f"Add {BUNDLE_STEM}.mlpackage to the iOS app target (Copy Bundle Resources), "
        f"or BlindGuyKit Resources if you bundle the model in the package."
    )


if __name__ == "__main__":
    main()
