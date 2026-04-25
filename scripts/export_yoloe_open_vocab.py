#!/usr/bin/env python3
"""
Export an open-vocabulary (text-prompt) detector to CoreML for the BlindGuy *second* vision pass.

**Shipped in-repo:** we use YOLOv8s-Worldv2 (Ultralytics). YOLOE-26 `model.export(format="coreml")`
currently throws inside `fuse()` on ultralytics 8.4.x; when that is fixed, switch `WEIGHTS` to
`yoloe-26n-seg.pt` and the same `PROMPTS` + app bundle name.

The on-device `OpenVocabularyCoreMLDetector` has no runtime text encoder: `set_classes` order must
match `VisionConfiguration.openVocabularyClassListOrdered` in Swift.
"""

from __future__ import annotations

import os
import shutil

# Order must match `VisionConfiguration.default.openVocabularyClassListOrdered`.
PROMPTS = [
    "computer",
    "trash can",
    "stairs",
]

# YOLOv8s-Worldv2: reliable CoreML + set_classes. Swap to yoloe-26n-seg.pt when export works.
WEIGHTS = "yolov8s-worldv2.pt"
BUNDLE_NAME = "yoloe-26n-seg"  # App loads `yoloe-26n-seg.mlpackage` (name kept for no code change)


def main() -> None:
    from ultralytics import YOLO

    repo = os.path.normpath(os.path.join(os.path.dirname(__file__), ".."))
    app_dir = os.path.join(repo, "App")
    work = os.path.join(repo, "scripts", ".yoloe_export_work")
    os.makedirs(app_dir, exist_ok=True)
    os.makedirs(work, exist_ok=True)
    prev = os.getcwd()
    try:
        os.chdir(work)
        model = YOLO(WEIGHTS)
        model.set_classes(PROMPTS)
        out = model.export(format="coreml", nms=True, imgsz=640)
        out_path = out if isinstance(out, str) else str(out)
        if not os.path.isabs(out_path):
            out_path = os.path.join(work, out_path)
        if not os.path.isdir(out_path) and os.path.isdir(out_path + ".mlpackage"):
            out_path = out_path + ".mlpackage"
        if not os.path.exists(out_path):
            guess = os.path.join(work, WEIGHTS.replace(".pt", ".mlpackage"))
            if os.path.exists(guess):
                out_path = guess
        if not (out_path.endswith(".mlpackage") and os.path.isdir(out_path)):
            raise FileNotFoundError(f"CoreML output not found after export: {out!r}")
        dest = os.path.join(app_dir, f"{BUNDLE_NAME}.mlpackage")
        if os.path.exists(dest):
            shutil.rmtree(dest)
        shutil.copytree(out_path, dest)
        print("Wrote", dest, "for prompts", PROMPTS)
    finally:
        os.chdir(prev)


if __name__ == "__main__":
    main()
