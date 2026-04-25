from dataclasses import dataclass, field


@dataclass(slots=True)
class VisualConfig:
    model_path: str = "yolov8n.pt"
    confidence_threshold: float = 0.58
    target_classes: set[str] = field(
        default_factory=lambda: {"person", "car", "bicycle", "motorcycle", "truck", "bus", "dog", "cat", "chair", "couch", "dining table", "potted plant", "backpack", "handbag", "suitcase", "cell phone", "laptop", "bottle", "cup", "umbrella", "traffic light", "fire hydrant", "stop sign", "bench"}
    )
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
            "laptop": 0.3,
            "bottle": 0.25,
            "cup": 0.15,
            "umbrella": 1.0,
            "traffic light": 1.0,
            "fire hydrant": 0.8,
            "stop sign": 0.8,
            "bench": 0.9,
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
    enable_lens_check: bool = False
    lens_laplacian_max_side: int = 400
    lens_laplacian_threshold: float = 100.0
    lens_warn_consecutive: int = 4
    lens_announcement_text: str = ""

