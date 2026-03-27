import asyncio
import csv
import io

from fastapi import APIRouter, Depends
from fastapi.responses import JSONResponse, Response
from firebase_admin import firestore

from app.routers.auth import get_current_uid

router = APIRouter(prefix="/export", tags=["export"])


def _get_logs_sync(uid: str) -> list[dict]:
    db = firestore.client()
    docs = (
        db.collection("medtwin_profiles")
        .document(uid)
        .collection("logs")
        .order_by("timestamp", direction=firestore.Query.DESCENDING)
        .limit(1000)
        .stream()
    )
    return [{"id": d.id, **d.to_dict()} for d in docs]


def _get_profile_sync(uid: str) -> dict:
    db = firestore.client()
    doc = db.collection("medtwin_profiles").document(uid).get()
    return doc.to_dict() if doc.exists else {}


@router.get("/logs.csv")
async def export_logs_csv(uid: str = Depends(get_current_uid)):
    """Download all health logs as a CSV file."""
    raw = await asyncio.to_thread(_get_logs_sync, uid)

    output = io.StringIO()
    fieldnames = ["id", "type", "label", "value", "unit", "timestamp"]
    writer = csv.DictWriter(output, fieldnames=fieldnames, extrasaction="ignore")
    writer.writeheader()
    for item in raw:
        ts = item.get("timestamp")
        item["timestamp"] = ts.isoformat() if hasattr(ts, "isoformat") else str(ts)
        writer.writerow({k: item.get(k, "") for k in fieldnames})

    return Response(
        content=output.getvalue(),
        media_type="text/csv",
        headers={"Content-Disposition": "attachment; filename=medtwin_logs.csv"},
    )


@router.get("/profile")
async def export_profile(uid: str = Depends(get_current_uid)):
    """Download the health profile as JSON."""
    profile = await asyncio.to_thread(_get_profile_sync, uid)
    # Firestore timestamps are not JSON-serialisable — convert them
    cleaned = {}
    for k, v in profile.items():
        cleaned[k] = v.isoformat() if hasattr(v, "isoformat") else v
    return JSONResponse(content=cleaned)
