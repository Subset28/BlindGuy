from flask import Flask, jsonify
import time
import math

app = Flask(__name__)

start = time.time()


def make_object(t):
    # Simple oscillating object that moves left/right and toward/away
    # pan_value in [-1,1], distance in meters
    pan = math.sin(t * 0.8) * 0.7
    dist = 6.0 + math.cos(t * 0.6) * 3.0  # between ~3 and 9
    velocity = 1.2 * math.cos(t * 0.6)  # not physics-accurate; for demo
    return {
        "object_id": "car_001",
        "class": "car",
        "confidence": 0.87,
        "bbox": {
            "x_center_norm": float((pan + 1.0) / 2.0),
            "y_center_norm": 0.6,
            "width_norm": 0.18,
            "height_norm": 0.14,
        },
        "distance_m": round(dist, 2),
        "pan_value": round(pan, 3),
        "velocity_mps": round(abs(velocity), 2),
        "priority": "HIGH" if dist < 3.0 else "NORMAL",
    }


@app.route('/payload')
def payload():
    t = time.time() - start
    frame = {
        "frame_id": int(t * 15),
        "timestamp_ms": int(time.time() * 1000),
        "vision_duration_ms": 20,
        "objects": [make_object(t)],
    }
    return jsonify(frame)


if __name__ == '__main__':
    app.run(host='127.0.0.1', port=8765)
