import asyncio
import inspect
import time
from collections import defaultdict, deque
from typing import Protocol

from fastapi import HTTPException, Request, status

from app.core.config import get_settings


class RateLimitBackend(Protocol):
    async def allow(
        self,
        *,
        key: str,
        limit: int,
        window_seconds: int,
    ) -> tuple[bool, int]: ...


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


class RedisRateLimiter:
    def __init__(self, redis_url: str, prefix: str) -> None:
        from redis.asyncio import Redis

        self._redis = Redis.from_url(redis_url, encoding="utf-8", decode_responses=True)
        self._prefix = prefix

    async def allow(
        self,
        *,
        key: str,
        limit: int,
        window_seconds: int,
    ) -> tuple[bool, int]:
        now = time.time()
        bucket_key = f"{self._prefix}:{key}"
        await self._redis.zremrangebyscore(bucket_key, 0, now - window_seconds)
        count = await self._redis.zcard(bucket_key)
        if count >= limit:
            oldest = await self._redis.zrange(bucket_key, 0, 0, withscores=True)
            retry_after = 1
            if oldest:
                retry_after = max(1, int(window_seconds - (now - oldest[0][1])))
            return False, retry_after

        await self._redis.zadd(bucket_key, {str(now): now})
        await self._redis.expire(bucket_key, window_seconds)
        return True, 0

    async def ping(self) -> bool:
        try:
            result = self._redis.ping()
            if inspect.isawaitable(result):
                return bool(await result)
            return bool(result)
        except Exception:
            return False


def _build_backend() -> RateLimitBackend:
    settings = get_settings()
    if settings.redis_url:
        try:
            return RedisRateLimiter(
                settings.redis_url,
                settings.redis_rate_limit_prefix,
            )
        except Exception:
            return InMemoryRateLimiter()
    return InMemoryRateLimiter()


limiter = _build_backend()


async def check_rate_limit_backend_health() -> bool:
    if isinstance(limiter, RedisRateLimiter):
        return await limiter.ping()
    return True


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
