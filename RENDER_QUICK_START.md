# 🚀 Render Deployment: Quick Reference Guide

**All-in-One Checklist for Production Deployment**

---

## 📋 One-Page Deployment Checklist

### ⏱️ Timeline: 1.5-2 hours to production

```
0 min    → START
15 min   → PostgreSQL provisioned + indexes created
25 min   → Code patches applied and tested locally
50 min   → All environment variables configured
60 min   → Docker builds successfully
90 min   → Deployed to Render (auto or manual push)
100 min  → Health checks pass
120 min  → PRODUCTION LIVE ✅
```

---

## 🎯 Critical Pre-Deployment Tasks (Do These First)

### 1️⃣ Generate & Store Secrets (5 min)

```bash
# Generate JWT secret - SAVE THIS VALUE
openssl rand -hex 32
# Example output: a1b2c3d4e5f6...

# Generate bootstrap password (16+ chars, mixed case, numbers, special)
# Example: SecurePass123!@#
```

**Where to store**:

- JWT_SECRET_KEY → Render dashboard (as secret)
- BOOTSTRAP_ADMIN_PASSWORD → Keep in secure password manager
- Database URL → Render auto-provides (use `fromDatabase`)

### 2️⃣ Provision PostgreSQL on Render (10 min)

1. Go to [https://render.com/dashboard](https://render.com/dashboard)
2. Click "+ New" → "PostgreSQL"
3. Choose "Free" tier
4. Name: `student-system-db`
5. Copy connection string
6. **Don't close this tab** - you'll need the URL

### 3️⃣ Create Indexes in Database (10 min)

Go to Render PostgreSQL dashboard → "Connect" → Run SQL Editor:

```sql
-- Copy-paste all 8 index creation commands
-- (See RENDER_ACTION_PLAN.md Task 1.4)

-- This MUST complete before deployment
```

### 4️⃣ Choose Redis Strategy (5 min)

Pick ONE:

**Option A: Use Redis ($7/month, recommended for scale)**

- Render dashboard → "+ New" → "Redis"
- Copy Redis URL

**Option B: Use In-Memory (free, for MVP)**

- Use rate_limit_fallback.py from RENDER_CODE_PATCHES.md
- Works fine up to 100 concurrent users

---

## 💾 Code Updates Required

### Update 1: Database Pool (CRITICAL)

**File**: `backend/app/db/session.py`

Replace engine creation (3 lines → 8 lines):

```python
engine = create_async_engine(
    settings.database_url,
    future=True,
    pool_size=5,
    max_overflow=10,
    pool_pre_ping=True,
    pool_recycle=3600,
    connect_args={"timeout": 10, "command_timeout": 10},
)
```

### Update 2: Enable HTTPS (CRITICAL)

**File**: `render.yaml`

Change one line:

```yaml
- key: ENABLE_HTTPS_REDIRECT
  value: "true"  # Changed from false
```

### Update 3: Rate Limit Fallback (OPTIONAL)

**File**: `backend/app/core/rate_limit_fallback.py` (create new)

Copy from RENDER_CODE_PATCHES.md Patch 3

---

## 🧪 Local Testing (30 min)

```bash
# Move to backend directory
cd backend

# Run all tests
pytest tests/ -v --tb=short

# Expected output:
# ===== X passed in Y.XXs =====
# If any test fails, fix before deploying!

# Test Docker build
cd ..
docker build -f backend/Dockerfile -t test:latest .

# Should complete without errors
```

If tests fail:

- Check database connection
- Verify all environment variables set locally
- Run `alembic upgrade head` to ensure schema exists

---

## 📝 Environment Variables to Add in Render

Go to Render Dashboard → Service → Environment:

```
# CRITICAL (Must set)
DATABASE_URL=postgresql://...  (auto from database service)
JWT_SECRET_KEY=<your-generated-value>
REDIS_URL=redis://...  (or skip if using fallback)

# IMPORTANT (Render sets automatically)
APP_ENV=production
APP_DEBUG=false
ENABLE_HTTPS_REDIRECT=true

# USER SPECIFIC (Set your values)
BOOTSTRAP_ADMIN_EMAIL=your-email@school.edu
BOOTSTRAP_ADMIN_PASSWORD=SecurePass123!@#
BOOTSTRAP_ADMIN_NAME=System Administrator

# OPTIONAL (Only if using external services)
RESEND_API_KEY=re_...  (if sending emails)
```

---

## 🌐 Deploy to Render

### Option 1: Automatic Deploy (Recommended)

```bash
# In project root:
git add .
git commit -m "chore: prepare for render deployment"
git push origin main

# Render auto-deploys if autoDeploy: true in render.yaml ✅
# Check: https://dashboard.render.com/services/your-service
```

### Option 2: Manual Deploy

1. Go to Render dashboard
2. Select your service
3. Click "Deploy Latest Commit"
4. Watch logs in real-time

---

## ✅ Post-Deployment Verification (10 min)

### Check 1: Health Endpoint

```bash
curl https://student-system-backend.onrender.com/health/ready

# Expected response:
# {"status": "ready", "database": true}
```

### Check 2: Logs (Real-time)

1. Go to Render dashboard
2. Click "Logs" tab
3. Should see: "Application startup complete"
4. No errors in output

### Check 3: Login Test

```bash
curl -X POST https://student-system-backend.onrender.com/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email": "admin@school.edu", "password": "SecurePass123!@#"}'

# Expected: Returns access_token
```

### Check 4: Rate Limiting Works

```bash
# Login 6 times in quick succession
for i in {1..6}; do
  curl -X POST https://student-system-backend.onrender.com/api/v1/auth/login \
    -H "Content-Type: application/json" \
    -d '{"email": "test@test.com", "password": "wrong"}'
  sleep 0.1
done

# Response 6: {"detail": "Too many requests"}
# Status code: 429
```

---

## 🐛 Troubleshooting

| Issue | Fix | Time |
|---|---|---|
| "502 Bad Gateway" | Wait 2 min, logs might show migration running | 2 min |
| "Connection refused" | Check DATABASE_URL is set in Render env | 2 min |
| "Health check timeout" | Increase timeout in render.yaml from 30s to 60s | 3 min |
| "Rate limiting not working" | Verify REDIS_URL set or fallback implemented | 5 min |
| "Migration failed" | Check SQL syntax in Supabase, re-run indexes | 10 min |

**If stuck**: Check [Render docs](https://render.com/docs) or [FastAPI deployment](https://fastapi.tiangolo.com/deployment/)

---

## 📊 Performance Expectations (Week 1)

### Response Times

- Login: 50-100ms ✅
- Load class roster: 20-40ms ✅
- Generate report (100 students): 200-300ms ✅
- Generate report (1000 students): 2-3 seconds ⚠️

### Database Metrics

- Connection pool utilization: 30-50% (normal) ✅
- Query times: Avg 5-20ms ✅
- Slow queries: <1% of requests ✅

### Resource Usage

- CPU: 10-20% at peak ✅
- Memory: 150-250MB ✅
- Disk: <100MB (no action needed) ✅

---

## 🔒 Security Audit Post-Deploy (Week 1)

```bash
# 1. Verify HTTPS works
curl -I https://student-system-backend.onrender.com
# Should show: Strict-Transport-Security header

# 2. Test auth flow
# - Login
# - Refresh token
# - Logout
# All should work without errors

# 3. Check security headers
curl -I https://student-system-backend.onrender.com/api/v1/auth/login | grep -i security

# 4. Verify docs disabled
curl https://student-system-backend.onrender.com/docs
# Should return 404
```

---

## 🎯 Next Steps After Deployment

### Week 1: Monitoring

- [ ] Configure Render alerts (CPU, error rate, response time)
- [ ] Review logs daily for errors
- [ ] Test critical user flows: login → report download
- [ ] Verify database backups working

### Week 2: Optimization

- [ ] Review slow query logs (`/metrics` endpoint)
- [ ] Implement caching if needed
- [ ] Monitor user feedback for performance issues
- [ ] Profile database queries

### Week 3-4: Enhancement

- [ ] Deploy frontend to Vercel
- [ ] Configure Supabase RLS policies
- [ ] Set up automated testing in CI/CD
- [ ] Consider Redis if scaling beyond 100 users

---

## 📞 Support & Documentation

| Resource | Link | Use When |
|---|---|---|
| Render Docs | [render.com/docs](https://render.com/docs) | Platform questions |
| FastAPI Docs | [fastapi.tiangolo.com](https://fastapi.tiangolo.com) | API issues |
| SQLAlchemy Async | [docs.sqlalchemy.org](https://docs.sqlalchemy.org) | Database issues |
| Supabase Docs | [supabase.com/docs](https://supabase.com/docs) | PostgreSQL setup |

---

## 🎉 Go-Live Verification Checklist

Before announcing deployment:

- [ ] All health checks pass
- [ ] Login works end-to-end
- [ ] Report generation completes in <3s
- [ ] No errors in Render logs for 5+ minutes
- [ ] Rate limiting blocks excessive requests
- [ ] Database responds in <20ms for common queries
- [ ] Security headers present in responses
- [ ] HTTPS enforced (HTTP → HTTPS redirect working)

**Once all ✅ checked**: You're live in production! 🚀

---

## 📈 Success Metrics (Track for First Month)

```
Week 1: Deployment Stability
- Uptime: Target 99%+
- Error rate: Target <0.5%
- Avg response time: Target <150ms

Week 2-4: Performance
- P95 response time: Target <500ms
- Database query time: Target <30ms avg
- User login success rate: Target 99.5%+

Month 2: Scale Readiness
- Concurrent users handled: Up to 100
- Peak requests per second: 10-20 RPS
- Database connection pool usage: 30-50%
```

---

**Document Version**: 2.0  
**Last Updated**: 2026-04-21  
**Status**: Ready for Production Deployment

For detailed information, see:

- [RENDER_DEPLOYMENT_AUDIT.md](RENDER_DEPLOYMENT_AUDIT.md) - Full security/performance analysis
- [RENDER_ACTION_PLAN.md](RENDER_ACTION_PLAN.md) - Step-by-step implementation
- [RENDER_CODE_PATCHES.md](RENDER_CODE_PATCHES.md) - Code changes required
