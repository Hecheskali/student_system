# Deployment Hardening Checklist

This repo now includes code-level hooks for stronger production security, but
the following platform settings must still be completed in Vercel, Render, and
Supabase.

## Vercel

- Enable Vercel WAF for the production project
- Add bot protection / attack challenge rules for auth-heavy routes
- Restrict preview deployments if they expose sensitive admin flows
- Set production environment variables for frontend-to-backend API URLs

## Render

- Set a real `REDIS_URL`
- Configure SMTP or Twilio secrets for the outbox worker
- Set `ALERT_WEBHOOK_URL` for Slack, Discord, PagerDuty webhook relay, or similar
- Restrict access to admin tools with team RBAC in the Render dashboard

## Supabase

- Apply all migrations, including `20260419172000_harden_rls.sql`
- Verify RLS rules against your actual district/school role matrix
- Keep `SUPABASE_SERVICE_ROLE_KEY` only on the backend, never in Flutter
- Review storage bucket policies separately if you add file uploads

## External providers

- Email: configure SMTP or replace the provider with SendGrid/Postmark/etc.
- SMS: configure Twilio or swap in your preferred SMS gateway
- Alerts: connect webhook notifications to a monitored destination

## Recommended next setup

1. Provision Redis
2. Provision SMTP or transactional email provider
3. Provision alert webhook target
4. Apply Supabase migrations in staging
5. Run login / refresh / password reset flows end to end
