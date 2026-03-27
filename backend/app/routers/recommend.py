import asyncio
import logging

from fastapi import APIRouter, Depends, HTTPException

from app.core.config import settings
from app.core import dev_store
from app.routers.auth import get_current_uid
from app.schemas.schemas import AIRecommendationResponse, RecommendRequest
from app.services.ai_engine import call_gemini
from app.services.safety import run_safety_checks

logger = logging.getLogger("medtwin")
router = APIRouter(prefix="/recommend", tags=["recommend"])


def _get_profile_sync(uid: str) -> dict:
    from firebase_admin import firestore
    db = firestore.client()
    doc = db.collection("medtwin_profiles").document(uid).get()
    return doc.to_dict() if doc.exists else {}


@router.post("", response_model=AIRecommendationResponse)
async def recommend(
    body: RecommendRequest,
    uid: str = Depends(get_current_uid),
):
    """Run safety checks + call MedTwin AI and return a structured recommendation."""
    if not body.question.strip():
        raise HTTPException(status_code=422, detail="Question must not be empty.")

    # Fetch MedTwin profile
    if settings.DEV_UID:
        profile = dev_store.get_profile(uid) or {}
    else:
        profile = await asyncio.to_thread(_get_profile_sync, uid)

    # Safety checks always run before AI
    safety_flags = run_safety_checks(profile)

    # Call Groq with profile + app context (medications, reports, appointments)
    try:
        result = await call_gemini(profile, body.question, body.app_context)
    except Exception as exc:
        logger.error("Groq call failed: %s", exc)
        raise HTTPException(
            status_code=502,
            detail="AI service temporarily unavailable. Please try again.",
        )

    result["warnings"] = safety_flags + (result.get("warnings") or [])

    return AIRecommendationResponse(
        key_issues=result.get("key_issues", []),
        root_causes=result.get("root_causes", []),
        action_plan=result.get("action_plan", {"diet": [], "training": [], "lifestyle": []}),
        otc_suggestions=result.get("otc_suggestions", []),
        expected_timeline=result.get("expected_timeline", ""),
        warnings=result["warnings"],
        suggest_appointment=result.get("suggest_appointment", False),
    )
