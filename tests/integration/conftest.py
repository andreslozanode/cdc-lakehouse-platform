import os
import pytest


def pytest_collection_modifyitems(config, items):
    """Skipea la suite E2E si el stack no está accesible."""
    if os.getenv("E2E_SKIP_HEALTHCHECK") == "1":
        return
    import requests

    ch = os.getenv("CH_HTTP_URL", "http://localhost:8123")
    try:
        requests.get(f"{ch}/ping", timeout=3).raise_for_status()
    except Exception:  # noqa: BLE001
        skip = pytest.mark.skip(reason="Stack no disponible (levanta con `make up`).")
        for item in items:
            item.add_marker(skip)
