import logging
import time

from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request

logger = logging.getLogger("medtwin")
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
)


class LoggingMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next):
        start = time.time()
        response = await call_next(request)
        elapsed_ms = round((time.time() - start) * 1000)
        logger.info(
            "%s %s → %s (%dms)",
            request.method,
            request.url.path,
            response.status_code,
            elapsed_ms,
        )
        return response
