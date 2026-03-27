import asyncio

from fastapi import APIRouter, Depends, HTTPException

from app.core.config import settings
from app.core import dev_store
from app.schemas.schemas import HealthProfileData
from app.routers.auth import get_current_uid

router = APIRouter(prefix="/profile", tags=["profile"])


def _db():
    from firebase_admin import firestore
    return firestore.client()


def _get_profile_sync(uid: str) -> dict | None:
    doc = _db().collection("medtwin_profiles").document(uid).get()
    return doc.to_dict() if doc.exists else None


def _set_profile_sync(uid: str, data: dict):
    _db().collection("medtwin_profiles").document(uid).set(data, merge=True)


@router.get("")
async def get_profile(uid: str = Depends(get_current_uid)):
    """Return the authenticated user's health profile, or empty dict if none."""
    if settings.DEV_UID:
        return dev_store.get_profile(uid) or {}
    data = await asyncio.to_thread(_get_profile_sync, uid)
    return data or {}


@router.post("", status_code=201)
async def create_profile(
    body: HealthProfileData,
    uid: str = Depends(get_current_uid),
):
    """Replace the health profile with the supplied data."""
    payload = body.model_dump(exclude_none=True)
    if not payload:
        raise HTTPException(status_code=422, detail="No data provided.")
    if settings.DEV_UID:
        dev_store.set_profile(uid, payload)
    else:
        await asyncio.to_thread(_set_profile_sync, uid, payload)
    return {"status": "created"}


@router.patch("")
async def patch_profile(
    body: HealthProfileData,
    uid: str = Depends(get_current_uid),
):
    """Merge the supplied fields into the existing health profile."""
    payload = body.model_dump(exclude_none=True)
    if not payload:
        raise HTTPException(status_code=422, detail="No fields to update.")
    if settings.DEV_UID:
        dev_store.set_profile(uid, payload)
    else:
        await asyncio.to_thread(_set_profile_sync, uid, payload)
    return {"status": "updated"}
