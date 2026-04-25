import pytest
import requests
from . import generator as gen
from . import validator as val
import socket


def is_server_running(host='127.0.0.1', port=8765, timeout=0.5):
    try:
        with socket.create_connection((host, port), timeout=timeout):
            return True
    except Exception:
        return False


def test_generated_payload_valid():
    payload = gen.scenario_moving_car(frame_id=1, t=1.23)
    # Should not raise
    val.validate_payload(payload)


def test_multiple_payloads_valid():
    payload = gen.scenario_multiple(frame_id=2, t=2.34)
    val.validate_payload(payload)


def test_server_payload_matches_schema():
    if not is_server_running():
        pytest.skip("Simulator server not running on 127.0.0.1:8765")
    resp = requests.get("http://127.0.0.1:8765/payload", timeout=2.0)
    assert resp.status_code == 200
    payload = resp.json()
    val.validate_payload(payload)
