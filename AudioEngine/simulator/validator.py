"""Validate payloads against the PRD schema."""
import json
from jsonschema import validate, Draft7Validator, exceptions
from pathlib import Path

SCHEMA_PATH = Path(__file__).parent / "schema.json"


def load_schema():
    with open(SCHEMA_PATH, "r", encoding="utf-8") as f:
        return json.load(f)


def validate_payload(payload: dict) -> None:
    schema = load_schema()
    validator = Draft7Validator(schema)
    errors = sorted(validator.iter_errors(payload), key=lambda e: e.path)
    if errors:
        msgs = [f"{list(e.path)}: {e.message}" for e in errors]
        raise ValueError("Payload validation errors:\n" + "\n".join(msgs))


if __name__ == "__main__":
    # simple local test
    sample = {
        "frame_id": 1,
        "timestamp_ms": 123456789,
        "vision_duration_ms": 20,
        "objects": [
            {
                "object_id": "car_001",
                "class": "car",
                "confidence": 0.9,
                "bbox": {"x_center_norm": 0.5, "y_center_norm": 0.5, "width_norm": 0.2, "height_norm": 0.1},
                "distance_m": 4.2,
                "pan_value": 0.0,
                "velocity_mps": None,
                "priority": "NORMAL",
            }
        ],
    }
    validate_payload(sample)
    print("OK")
