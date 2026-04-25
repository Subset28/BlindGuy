from dataclasses import dataclass, field

# COCO-80 class names; filter to this allowlist (Ultralytics `yolov8n.pt` pretrained).
_DEFAULT_TARGET: frozenset[str] = frozenset(
    {
        "person",
        "car",
        "bicycle",
        "motorcycle",
        "truck",
        "bus",
        "dog",
        "cat",
        "chair",
        "couch",
        "dining table",
        "potted plant",
        "backpack",
        "handbag",
        "suitcase",
        "cell phone",
        "laptop",
        "bottle",
        "cup",
        "umbrella",
        "traffic light",
        "fire hydrant",
        "stop sign",
        "bench",
    }
)


@dataclass(slots=True)
class VisualConfig:
    model_path: str = "yolov8n.pt"
    target_classes: set[str] = field(default_factory=lambda: set(_DEFAULT_TARGET))
    suppressed_classes: set[str] = field(
        default_factory=lambda: {"clock", "vase", "wine glass", "teddy bear", "toothbrush"}
    )
    confidence_threshold: float = 0.58
    # Minimum fraction of the bbox that must lie inside the frame (0–1). Drops edge/OOB false positives.
    min_bbox_area_fraction_in_frame: float = 0.7
    known_heights_m: dict[str, float] = field(
        default_factory=lambda: {
            "person": 1.7,
            "car": 1.5,
            "bicycle": 1.1,
            "motorcycle": 1.3,
            "truck": 3.5,
            "bus": 3.2,
            "dog": 0.6,
            "cat": 0.3,
            "chair": 0.9,
            "couch": 0.9,
            "dining table": 0.8,
            "potted plant": 0.6,
            "backpack": 0.5,
            "handbag": 0.3,
            "suitcase": 0.7,
            "cell phone": 0.15,
            "laptop": 0.24,
            "bottle": 0.25,
            "cup": 0.15,
            "umbrella": 1.0,
            "traffic light": 1.0,
            "fire hydrant": 0.8,
            "stop sign": 0.8,
            "bench": 0.9,
        }
    )
    # Horizontal physical size (m) for width-dominated bboxes; matches BlindGuy `knownWidthsM`.
    known_widths_m: dict[str, float] = field(
        default_factory=lambda: {
            "person": 0.5,
            "car": 1.8,
            "bicycle": 1.7,
            "motorcycle": 1.0,
            "truck": 2.4,
            "bus": 2.5,
            "dog": 0.8,
            "cat": 0.45,
            "chair": 0.55,
            "couch": 1.6,
            "dining table": 1.2,
            "potted plant": 0.45,
            "backpack": 0.4,
            "handbag": 0.4,
            "suitcase": 0.5,
            "cell phone": 0.08,
            "laptop": 0.32,
            "bottle": 0.08,
            "cup": 0.1,
            "umbrella": 0.9,
            "traffic light": 0.4,
            "fire hydrant": 0.45,
            "stop sign": 0.6,
            "bench": 1.5,
        }
    )
    # Eval / webcam: derive f_x, f_y from horizontal FOV (no device intrinsics). Optional override: single calibrated f in pixels.
    horizontal_field_of_view_deg: float = 63.0
    focal_length_px: float | None = None
    emit_hz: float = 15.0
    camera_index: int = 0
    frame_width: int = 640
    frame_height: int = 480
    max_detection_ms: float = 50.0
    max_tracking_gap_s: float = 1.0
    max_match_distance_norm: float = 0.20
    enable_lens_check: bool = False
    lens_laplacian_max_side: int = 400
    lens_laplacian_threshold: float = 100.0
    lens_warn_consecutive: int = 4
    lens_announcement_text: str = ""
