import logging
import os

import firebase_admin
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from firebase_admin import credentials

from app.core.config import settings
from app.core.logging_middleware import LoggingMiddleware
from app.core.middleware import RateLimitMiddleware
from app.routers import export, logs, profile, recommend

logger = logging.getLogger("medtwin")


def _init_firebase():
    if firebase_admin._apps:
        return
    # Skip Firebase Admin entirely when running in local dev mode (DEV_UID set)
    if settings.DEV_UID:
        logger.warning("DEV_UID is set — skipping Firebase Admin init (dev store active).")
        return
    sa_path = settings.FIREBASE_SERVICE_ACCOUNT_PATH
    if os.path.exists(sa_path):
        cred = credentials.Certificate(sa_path)
        firebase_admin.initialize_app(cred)
        logger.info("Firebase Admin initialised from %s", sa_path)
    else:
        # Fallback: use application default credentials (e.g. on Cloud Run)
        firebase_admin.initialize_app()
        logger.warning(
            "Service account file not found at %s — using default credentials.", sa_path
        )


_init_firebase()

app = FastAPI(
    title="MedTwin AI",
    description="Personalised AI health coach backed by your Digital Twin profile.",
    version="1.0.0",
)

# ── Middleware (order matters: outer → inner) ─────────────────────────────────
app.add_middleware(LoggingMiddleware)
app.add_middleware(RateLimitMiddleware)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ── Routers ───────────────────────────────────────────────────────────────────
app.include_router(profile.router)
app.include_router(logs.router)
app.include_router(recommend.router)
app.include_router(export.router)


@app.get("/")
def health_check():
    return {"status": "ok", "service": "MedTwin AI"}
