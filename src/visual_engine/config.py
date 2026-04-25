from dataclasses import dataclass, field


@dataclass(slots=True)
class VisualConfig:
    model_path: str = "yolov8n.pt"
    confidence_threshold: float = 0.55
    target_classes: set[str] = field(
        default_factory=lambda: {"person", "car", "bicycle", "motorcycle", "truck", "bus"}
    )
    known_heights_m: dict[str, float] = field(
        default_factory=lambda: {
            "person": 1.7,
            "car": 1.5,
            "bicycle": 1.1,
            "motorcycle": 1.3,
            "truck": 3.5,
            "bus": 3.2,
        }
    )
    focal_length_px: float = 850.0
    emit_hz: float = 15.0
    camera_index: int = 0
    frame_width: int = 640
    frame_height: int = 480
    max_detection_ms: float = 50.0
    max_tracking_gap_s: float = 1.0
    max_match_distance_norm: float = 0.20
    enable_lens_check: bool = True
    lens_laplacian_max_side: int = 400
    lens_laplacian_threshold: float = 100.0
    lens_warn_consecutive: int = 4
    lens_announcement_text: str = (
        "Camera lens may be smudged or dirty. Clean the lens for more reliable detection."
    )

