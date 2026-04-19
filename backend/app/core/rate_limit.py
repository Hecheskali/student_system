import asyncio
import time
from collections import defaultdict, deque

from fastapi import HTTPException, Request, status


class InMemoryRateLimiter:
    def __init__(self) -> None:
        self._buckets: dict[str, deque[float]] = defaultdict(deque)
        self._lock = asyncio.Lock()

    async def allow(
        self,
        *,
        key: str,
        limit: int,
        window_seconds: int,
    ) -> tuple[bool, int]:
        now = time.time()
        async with self._lock:
            bucket = self._buckets[key]
            while bucket and now - bucket[0] >= window_seconds:
                bucket.popleft()
            if len(bucket) >= limit:
                retry_after = max(1, int(window_seconds - (now - bucket[0])))
                return False, retry_after
            bucket.append(now)
            return True, 0


limiter = InMemoryRateLimiter()


class RateLimit:
    def __init__(self, *, limit: int, window_seconds: int, scope: str) -> None:
        self.limit = limit
        self.window_seconds = window_seconds
        self.scope = scope

    async def __call__(self, request: Request) -> None:
        client_ip = request.client.host if request.client else "unknown"
        key = f"{self.scope}:{client_ip}"
        allowed, retry_after = await limiter.allow(
            key=key,
            limit=self.limit,
            window_seconds=self.window_seconds,
        )
        if allowed:
            return
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail="Too many requests. Please try again later.",
            headers={"Retry-After": str(retry_after)},
        )

