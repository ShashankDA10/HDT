import asyncio
from datetime import datetime, timezone

from fastapi import APIRouter, Depends

from app.core.config import settings
from app.core import dev_store
from app.schemas.schemas import HealthLogCreate, HealthLogResponse
from app.routers.auth import get_current_uid

router = APIRouter(prefix="/logs", tags=["logs"])


def _db():
    from firebase_admin import firestore
    return firestore.client()


def _get_logs_sync(uid: str) -> list[dict]:
    from firebase_admin import firestore
    docs = (
        _db()
        .collection("medtwin_profiles")
        .document(uid)
        .collection("logs")
        .order_by("timestamp", direction=firestore.Query.DESCENDING)
        .limit(200)
        .stream()
    )
    return [{"id": d.id, **d.to_dict()} for d in docs]


def _add_log_sync(uid: str, log: dict) -> str:
    ref = (
        _db()
        .collection("medtwin_profiles")
        .document(uid)
        .collection("logs")
        .document()
    )
    ref.set(log)
    return ref.id


@router.get("", response_model=list[HealthLogResponse])
async def get_logs(uid: str = Depends(get_current_uid)):
    """Return the authenticated user's health logs, newest first."""
    if settings.DEV_UID:
        raw = dev_store.get_logs(uid)
        return [
            HealthLogResponse(
                id=item["id"],
                type=item.get("type", ""),
                label=item.get("label", ""),
                value=float(item.get("value", 0)),
                unit=item.get("unit", ""),
                timestamp=item.get("timestamp", ""),
            )
            for item in reversed(raw)
        ]
    raw = await asyncio.to_thread(_get_logs_sync, uid)
    result = []
    for item in raw:
        ts = item.get("timestamp")
        if hasattr(ts, "isoformat"):
            iso = ts.isoformat()
        else:
            iso = str(ts)
        result.append(
            HealthLogResponse(
                id=item["id"],
                type=item.get("type", ""),
                label=item.get("label", ""),
                value=float(item.get("value", 0)),
                unit=item.get("unit", ""),
                timestamp=iso,
            )
        )
    return result


@router.post("", response_model=HealthLogResponse, status_code=201)
async def add_log(
    body: HealthLogCreate,
    uid: str = Depends(get_current_uid),
):
    """Add a new health log entry."""
    now = datetime.now(timezone.utc)
    payload = {**body.model_dump(), "timestamp": now.isoformat()}
    if settings.DEV_UID:
        entry = dev_store.add_log(uid, payload)
        return HealthLogResponse(
            id=entry["id"],
            **body.model_dump(),
            timestamp=entry["timestamp"],
        )
    firestore_payload = {**body.model_dump(), "timestamp": now}
    log_id = await asyncio.to_thread(_add_log_sync, uid, firestore_payload)
    return HealthLogResponse(
        id=log_id,
        **body.model_dump(),
        timestamp=now.isoformat(),
    )
