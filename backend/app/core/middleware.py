"""Rate limiting: 10 requests per minute per IP on POST /recommend."""

import time
from collections import defaultdict, deque

from fastapi import HTTPException, Request
from starlette.middleware.base import BaseHTTPMiddleware

RATE_LIMIT = 10
WINDOW_SECONDS = 60

_windows: dict[str, deque] = defaultdict(deque)


class RateLimitMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next):
        if request.method == "POST" and request.url.path == "/recommend":
            key = request.client.host if request.client else "unknown"
            now = time.time()
            window = _windows[key]
            while window and now - window[0] > WINDOW_SECONDS:
                window.popleft()
            if len(window) >= RATE_LIMIT:
                raise HTTPException(
                    status_code=429,
                    detail="Rate limit exceeded. Max 10 requests per minute.",
                )
            window.append(now)
        return await call_next(request)
