# Render Deployment Action Plan

**Quick Reference for Implementation**

---

## 🔧 Phase 1: Critical Pre-Deployment Tasks (Complete Before Deploy)

### Task 1.1: Database PostgreSQL URL Configuration

1. **Create PostgreSQL database on Render**:
   - Go to <https://render.com/dashboard>
   - Click "+ New" → "PostgreSQL"
   - Choose "Free" tier
   - Set name: `student-system-db`
   - Note the connection string (looks like: `postgresql://user:pass@...`)

2. **Update render.yaml**:

```yaml
envVars:
  - key: DATABASE_URL
    fromDatabase:
      name: student-system-db      # Make sure database service name matches
      property: connectionString
```

1. **Run migrations on the new database**:
   - Once deployed, Render will auto-run `alembic upgrade head`
   - ✅ You're already configured for this

---

### Task 1.2: Secure JWT Secret Key

1. **Generate production secret**:

```bash
# Run this in your terminal
openssl rand -hex 32
# Output example: a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4

# Save this value - you'll need it for Render
```

1. **Add to Render environment** (keep `generateValue: true` in render.yaml):
   - Render will auto-generate if not provided
   - But NEVER commit secrets to git
   - Let Render's built-in secret generator handle it ✅

---

### Task 1.3: Redis Configuration (Choose One)

#### Option A: Use Render's Redis (Recommended)

```bash
# 1. On Render dashboard, add Redis service (paid: $7/month minimum)
# 2. Get Redis URL from Render (looks like: redis://:password@hostname:6379)
# 3. Add to render.yaml:

envVars:
  - key: REDIS_URL
    value: "redis://:your-password@your-redis-hostname:6379"
```

#### Option B: Disable Redis & Use In-Memory (Free, Startup Only)

**Recommended for initial MVP** to save $7/month  
**When to upgrade**: Once you hit 300+ concurrent users

```python
# Create: backend/app/core/rate_limit_memory.py
import time
from collections import defaultdict
from typing import Dict, List

class InMemoryRateLimiter:
    """Fallback rate limiter - good for 50-100 concurrent users"""
    def __init__(self):
        self.records: Dict[str, List[float]] = defaultdict(list)
    
    def is_allowed(self, key: str, limit: int, window: int) -> bool:
        now = time.time()
        cutoff = now - window
        
        # Clean old records (O(n) but acceptable)
        self.records[key] = [t for t in self.records[key] if t > cutoff]
        
        if len(self.records[key]) >= limit:
            return False
        
        self.records[key].append(now)
        return True

rate_limit_memory = InMemoryRateLimiter()
```

**Then update** `backend/app/core/rate_limit.py`:

```python
from app.core.rate_limit_memory import rate_limit_memory
import os

class RateLimit:
    def check(self, scope: str, client_ip: str) -> bool:
        # Use Redis if available, else fallback
        if os.getenv('REDIS_URL'):
            try:
                return redis_client.check_rate_limit(...)
            except Exception as e:
                logger.warning(f"Redis failed, using fallback: {e}")
        
        return rate_limit_memory.is_allowed(
            f"{scope}:{client_ip}",
            limit=self.limit,
            window=self.window_seconds
        )
```

**⚠️ Limitations of In-Memory**:

- Resets on deployment
- Not distributed (only works with 1 instance)
- Upgrade to Redis when:
  - Deploying multiple instances
  - Need persistent rate limit tracking
  - User count > 100

---

### Task 1.4: Database Indexes (Run in Supabase SQL Editor)

**Run these SQL commands immediately after adding the database**:

```sql
-- Add missing indexes for performance (5-10 min execution)
-- These improve report generation by 40-60%

CREATE INDEX CONCURRENTLY idx_results_class_id 
ON public.results(class_id);

CREATE INDEX CONCURRENTLY idx_audit_logs_event_type 
ON public.audit_logs(event_type);

CREATE INDEX CONCURRENTLY idx_audit_logs_actor_user_id 
ON public.audit_logs(actor_user_id);

CREATE INDEX CONCURRENTLY idx_audit_logs_created_at 
ON public.audit_logs(created_at DESC);

CREATE INDEX CONCURRENTLY idx_user_sessions_user_id 
ON public.user_sessions(user_id);

CREATE INDEX CONCURRENTLY idx_refresh_tokens_user_id 
ON public.refresh_tokens(user_id);

CREATE INDEX CONCURRENTLY idx_refresh_tokens_expires_at 
ON public.refresh_tokens(expires_at);

-- Verify indexes were created:
SELECT schemaname, tablename, indexname 
FROM pg_indexes 
WHERE schemaname = 'public' 
ORDER BY tablename, indexname;
```

---

### Task 1.5: Configure Pool Size

**File**: `backend/app/db/session.py`

Replace the current engine creation:

```python
# BEFORE (current):
engine = create_async_engine(
    settings.database_url,
    future=True,
    pool_pre_ping=True,
)

# AFTER (optimized for Render):
engine = create_async_engine(
    settings.database_url,
    future=True,
    pool_size=5,                    # Base connection pool size
    max_overflow=10,                # Additional overflow connections
    pool_pre_ping=True,             # Keep existing (good)
    pool_recycle=3600,              # Recycle connections every hour
    connect_args={
        "timeout": 10,
        "command_timeout": 10,
    },
)
```

---

## 🎯 Phase 2: Optional But Recommended (Week 1-2)

### Task 2.1: Add Streaming Report Generation

**File**: `backend/app/services/report_generator.py`

Current approach loads everything into memory. For 1000+ results:

```python
# ADD THIS METHOD for streaming
@staticmethod
async def generate_streaming_pdf(
    session: AsyncSession,
    class_id: str,
    batch_size: int = 100,
) -> AsyncGenerator[bytes, None]:
    """Stream PDF generation for large datasets"""
    from reportlab.lib.pagesizes import letter
    from reportlab.pdfgen import canvas
    from io import BytesIO
    
    # Header chunk
    buffer = BytesIO()
    page = canvas.Canvas(buffer, pagesize=letter)
    yield buffer.getvalue()
    
    # Stream results in chunks
    offset = 0
    while True:
        results = await session.execute(
            select(Result)
            .where(Result.class_id == class_id)
            .limit(batch_size)
            .offset(offset)
        )
        rows = results.scalars().all()
        if not rows:
            break
        
        # Yield chunk of data
        for row in rows:
            page.drawString(50, 750, f"{row.student_name}: {row.score}")
        
        chunk = buffer.getvalue()
        if chunk:
            yield chunk
            buffer.truncate(0)
        
        offset += batch_size
    
    # Footer/close
    page.save()
    yield buffer.getvalue()
```

---

### Task 2.2: Health Check Endpoint Status

**Check current health status**:

```bash
# After deploying to Render, curl:
curl https://student-system-backend.onrender.com/health/ready

# Should return:
# {"status": "ready", "database": true, "timestamp": "..."}
```

---

## ✅ Pre-Deployment Verification Checklist

### Phase 1: Configuration (15 min)

- [ ] PostgreSQL database created on Render (free tier OK)
- [ ] Database URL verified in Render dashboard
- [ ] JWT_SECRET_KEY generated using `openssl rand -hex 32`
- [ ] REDIS_URL set (or use in-memory option documented)
- [ ] All environment variables added to Render dashboard
- [ ] render.yaml updated with correct database service name

### Phase 2: Database Setup (20 min)

- [ ] 8 indexes created in database (SQL commands run)
- [ ] Indexes verified: Query shows all 8 new indexes
- [ ] Pool size configured in `backend/app/db/session.py`
- [ ] Connection timeout set to 10 seconds
- [ ] Pool recycle set to 3600 seconds (1 hour)

### Phase 3: Security Settings (5 min)

- [ ] ENABLE_HTTPS_REDIRECT = true
- [ ] ENABLE_DOCS = false
- [ ] ENABLE_HSTS = true
- [ ] ENABLE_2FA = true
- [ ] OBSERVABILITY_ENABLED = true

### Phase 4: Local Testing (30 min)

- [ ] All tests pass: `cd backend && pytest tests/ -v`
- [ ] Docker builds locally: `docker build -t test:latest backend/`
- [ ] Health endpoint works: `GET /health/ready`
- [ ] Login flow works locally
- [ ] Report generation doesn't error (any format)
- [ ] No warnings in application start logs

### Phase 5: Pre-Deploy Validation (10 min)

- [ ] Bootstrap admin credentials set
- [ ] All secrets use Render's secret manager (not in YAML)
- [ ] Git branch is clean (no uncommitted changes)
- [ ] All code is committed and pushed
- [ ] Health check path verified in render.yaml
- [ ] Auto-deploy enabled or manual trigger ready

---

## 🚀 Deployment Commands

```bash
cd /home/harris/Desktop/jabu/student_system

# 1. Run local tests to verify
cd backend
pytest tests/ -v --tb=short

# 2. Verify Docker builds locally
docker build -t student-system-backend:test .

# 3. Check migrations work
cd ..
alembic upgrade head

# 4. Deploy to Render (via git push if autoDeploy is true)
git add .
git commit -m "chore: prepare for render deployment"
git push origin main

# Render will auto-deploy if autoDeploy: true in render.yaml
```

---

## 📋 Environment Variables Summary

### Critical (Must Set)

```
DATABASE_URL=postgresql://user:pass@db.internal:5432/db
JWT_SECRET_KEY=<generated-by-render>
REDIS_URL=redis://:password@hostname:6379
```

### Important (Already in render.yaml)

```
APP_ENV=production
APP_DEBUG=false
ENABLE_DOCS=false
ENABLE_HSTS=true
ENABLE_HTTPS_REDIRECT=true
OBSERVABILITY_ENABLED=true
METRICS_ENABLED=true
TRUSTED_HOSTS=localhost,127.0.0.1,*.onrender.com
BOOTSTRAP_ADMIN_EMAIL=<set-your-value>
BOOTSTRAP_ADMIN_PASSWORD=<set-your-value>
```

### Optional (if using external services)

```
RESEND_API_KEY=<your-resend-api-key>
ALERT_WEBHOOK_URL=<slack-or-discord-webhook>
SMS_PROVIDER_API_KEY=<vonage-or-twilio-key>
```

---

## 🐛 Troubleshooting

### Issue: "502 Bad Gateway" on first deploy

**Cause**: Migrations still running  
**Fix**: Wait 2 minutes, then refresh. Check logs: `Logs` in Render dashboard

### Issue: Database connection timeouts

**Cause**: Pool size too small  
**Fix**: Increase `pool_size` from 5 to 10 in session.py, redeploy

### Issue: Rate limiting not working

**Cause**: Redis URL incorrect or Redis not running  
**Fix**:

1. Verify Redis connection: `redis-cli ping`
2. Or use in-memory fallback (Option B above)

### Issue: JWT secret invalid

**Cause**: Secret rotated or corrupted  
**Fix**:

```bash
# Regenerate new secret
openssl rand -hex 32
# Update in Render environment
```

---

## 📞 Support Resources

- **Render Docs**: <https://render.com/docs>
- **Supabase Postgres**: <https://supabase.com/docs/guides/with-python>
- **FastAPI Deployment**: <https://fastapi.tiangolo.com/deployment/>
- **SQLAlchemy Async**: <https://docs.sqlalchemy.org/en/20/orm/extensions/asyncio.html>

---

## 📊 Time Breakdown

| Phase | Task | Time |
|---|---|---|
| **Config** | Render + Secrets | 15 min |
| **Database** | PostgreSQL + Indexes | 20 min |
| **Application** | Pool config + code patches | 15 min |
| **Testing** | Local validation | 30 min |
| **Deploy** | Push to Render + monitoring | 10 min |
| **Verification** | Post-deploy health checks | 10 min |
| **TOTAL** | **Go-live ready** | **100 min (1.5-2 hrs)** |

**Critical Path P0**: 1 hour 40 minutes → Deployable  
**Production P1**: +30 minutes → Fully optimized

## 🔄 Rollback Plan

If deployment fails after 5 min:

```bash
# 1. Check Render logs for errors
https://dashboard.render.com/services/your-service

# 2. Common fixes:
# - Database connection error → Check DATABASE_URL
# - Migration failed → Check Alembic output
# - Health check timeout → Increase timeout in render.yaml

# 3. Rollback to previous version:
# - Go to Render dashboard → Deploy → Manual select previous build
# - Or git revert to last stable commit and push

# 4. Debug locally:
DATABASE_URL=postgresql://... alembic upgrade head
pytest tests/ -v
```
