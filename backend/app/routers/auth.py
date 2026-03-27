"""Firebase ID token verification using Google's public JWKS.

No service account file required. Tokens are verified against Google's
public keys fetched from the well-known endpoint and cached for 1 hour.
"""

import time
from typing import Optional

import httpx
import jwt
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

from app.core.config import settings

# ── Public key cache ──────────────────────────────────────────────────────────

_JWKS_URL = (
    "https://www.googleapis.com/service_accounts/v1/jwk/"
    "securetoken@system.gserviceaccount.com"
)
_CACHE_TTL = 3600  # seconds

_key_cache: dict = {}
_cache_fetched_at: float = 0.0


def _get_public_keys() -> dict:
    global _key_cache, _cache_fetched_at
    if _key_cache and (time.time() - _cache_fetched_at) < _CACHE_TTL:
        return _key_cache
    resp = httpx.get(_JWKS_URL, timeout=10)
    resp.raise_for_status()
    jwks = resp.json()
    _key_cache = {k["kid"]: jwt.algorithms.RSAAlgorithm.from_jwk(k) for k in jwks["keys"]}
    _cache_fetched_at = time.time()
    return _key_cache


# ── Dependency ────────────────────────────────────────────────────────────────

bearer = HTTPBearer(auto_error=False)

FIREBASE_PROJECT_ID = "bodyclone-ai"


async def get_current_uid(
    creds: Optional[HTTPAuthorizationCredentials] = Depends(bearer),
) -> str:
    # DEV_UID bypass: set DEV_UID=any-string in .env for local testing
    if settings.DEV_UID:
        return settings.DEV_UID

    if creds is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Authorization header missing.",
        )

    token = creds.credentials
    try:
        header = jwt.get_unverified_header(token)
        kid = header.get("kid", "")
        keys = _get_public_keys()
        if kid not in keys:
            raise ValueError(f"Unknown key id: {kid}")

        payload = jwt.decode(
            token,
            keys[kid],
            algorithms=["RS256"],
            audience=FIREBASE_PROJECT_ID,
            issuer=f"https://securetoken.google.com/{FIREBASE_PROJECT_ID}",
            leeway=30,
        )
        uid: str = payload["sub"]
        if not uid:
            raise ValueError("Empty UID in token")
        return uid

    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Invalid or expired Firebase token: {exc}",
        )
