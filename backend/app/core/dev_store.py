"""In-memory Firestore substitute used when DEV_UID is set.

Only active during local development — never in production.
"""

import uuid
from datetime import datetime, timezone
from typing import Any

_profiles: dict[str, dict] = {}
_logs: dict[str, list[dict]] = {}  # uid -> list of log dicts


def get_profile(uid: str) -> dict | None:
    return _profiles.get(uid)


def set_profile(uid: str, data: dict) -> None:
    existing = _profiles.get(uid, {})
    existing.update(data)
    _profiles[uid] = existing


def get_logs(uid: str) -> list[dict]:
    return list(_logs.get(uid, []))


def add_log(uid: str, data: dict) -> dict:
    log_id = str(uuid.uuid4())
    entry = {
        "id": log_id,
        "timestamp": datetime.now(timezone.utc).isoformat(),
        **data,
    }
    _logs.setdefault(uid, []).append(entry)
    return entry
