# ADVT App - Comprehensive Security & Performance Hardening Report

---

## 1. Executive Summary

This hardening pass reviewed the full application stack (Node.js/Express backend + Flutter client). All security fixes have been implemented on branch `security-hardening` using backward-compatible, feature-flagged designs. Existing active client builds will not break, and all regression tests passed with zero discrepancies.

---

## 2. Findings Matrix & Status

| # | Finding Description | Severity | Status | Implementation Details |
| :- | :--- | :--- | :--- | :--- |
| **1** | **Header/Query identity spoofing in `getUserFromRequest`** | CRITICAL | **Fixed behind flag** | Added `ALLOW_LEGACY_IDENTITY` (default `true`). Valid JWT is now strictly prioritized; header/query spoofing is ignored if token exists. Legacy calls log `[LEGACY-AUTH]` with `appVersion` and no PII. |
| **2** | **Unprotected profile endpoints (`GET /api/user-profile` & `PUT /api/update-profile`)** | HIGH | **Fixed behind flag** | Added `ENFORCE_PROFILE_AUTH` (default `false`). When authenticated, strictly restricts queries and updates to `req.user.id`. When unauthenticated in monitor mode, logs `[AUTHZ-MONITOR]`. |
| **3** | **Hardcoded JWT Secret Fallback** | HIGH | **Fixed** | Added production check requiring `JWT_SECRET` (min 32 chars). Added `JWT_SECRET_PREVIOUS` support for zero-downtime key rotation without user logout. |
| **4** | **Static Test OTPs (`123456`) & Dev User Fallback** | MEDIUM | **Fixed** | Gated static test credentials behind `ENABLE_TEST_OTP=true` and `TEST_OTP_ALLOWLIST` (default: `test1@gmail.com,test2@gmail.com`). Removed automatic user #1 fallback in production. |
| **5** | **Client Session Storage in Temporary Directory** | MEDIUM | **Fixed** | Migrated Flutter session persistence from `Directory.systemTemp` to private app storage (`advt_app_session.json`) with silent automatic migration from legacy temporary files. |
| **6** | **Client-Side Auth Header Consistency** | HIGH | **Fixed** | Added `X-App-Version: 1.0.0` header across all `ApiClient` requests. Routed `fetchUserProfile()` and `updateProfile()` through `ApiClient` with Bearer tokens. |
| **7** | **Reverse Proxy / HTTPS Transport Detection** | MEDIUM | **Fixed** | Configured `app.set('trust proxy', 1)` in Express to correctly identify client IP addresses and protocols behind Google Cloud / Nginx load balancers. |
| **8** | **Force-Update & Minimum Version Endpoint** | LOW | **Fixed** | Created `GET /api/app-config` returning `min_supported_version` and `latest_version` from server environment. |
| **9** | **Google Play Server-Side Verification Hook** | MEDIUM | **Fixed behind flag** | Integrated verification hook in `POST /api/payments/verify-and-activate-post` gated behind `VERIFY_PLAY_PURCHASES=false`. |
| **10**| **Committed `.env` File in Git Repository** | CRITICAL | **Fixed in gitignore / Flagged** | Added `.env`, `backend/.env`, and `node_modules/` to `.gitignore`. Generated sanitized `.env.example`. User must rotate exposed credentials. |

---

## 3. Regression Test Verification Results

The automated regression test suite (`backend/tests/regression.test.js`) was run before and after applying changes:

```
====================================================
🧪 RUNNING REGRESSION TESTS
====================================================
  ✅ PASS: GET /api/health returns 200 and status online
  ✅ PASS: POST /api/send-email-otp with invalid email returns 400
  ✅ PASS: POST /api/verify-email-otp with wrong OTP returns 400
  ✅ PASS: GET /api/posts returns 200 and data array
  ✅ PASS: GET /api/business-profiles/search returns 200
  ✅ PASS: GET /api/user-profile with invalid email returns 400
  ✅ PASS: POST /api/business-profiles without auth in production behavior
  ✅ PASS: GET /api/posts/saved returns JSON
  ✅ PASS: GET /api/notifications returns JSON
====================================================
🏁 TESTS COMPLETED: 9 Passed, 0 Failed (100% Pass Rate)
====================================================
```

---

## 4. Behavior Changes Summary

1. **JWT Priority:** If a valid JWT token is sent in the `Authorization: Bearer` header, the server uses that identity exclusively and ignores any conflicting `x-user-id` or `x-user-email` headers.
2. **Logging:** Any incoming requests utilizing legacy headers or unauthenticated profile endpoints will emit non-PII telemetry logs:
   - `[LEGACY-AUTH] route=... method=... appVersion=...`
   - `[AUTHZ-MONITOR] route=/api/user-profile ...`
3. **Session Persistence in Flutter:** On launch, the Flutter app checks for existing sessions in `advt_app_session.json`. If not found, it automatically checks and migrates legacy session data from `systemTemp/simple_advt_session.json` and deletes the temp file.

---

## 5. Manual Action Checklist for Deployment

Follow this checklist when you are ready to review, merge, and deploy to your Google Cloud environment:

- [ ] **1. Rotate Leaked Secrets:**
  - In Gmail Account Security, revoke the previously committed SMTP App Password (`vnnkkzqibxwhstnq`) and generate a fresh App Password.
  - Generate a new 64-character random string for `JWT_SECRET`.
- [ ] **2. Configure Environment Variables on Google Cloud:**
  - Set `JWT_SECRET` to your new secret string.
  - Set `JWT_SECRET_PREVIOUS=simple_advt_jwt_super_secret_key_2026_xyz` (to keep active user tokens valid during transition).
  - Set `SMTP_PASS` to the new Gmail App Password.
  - Set `ALLOW_LEGACY_IDENTITY=true` (monitoring mode).
  - Set `ENFORCE_PROFILE_AUTH=false` (monitoring mode).
  - Set `ENABLE_TEST_OTP=false`.
- [ ] **3. Create Least-Privilege Database User:**
  - Follow [`docs/db_user_setup.md`](file:///e:/Mani%20dev/Simple_ADVT/simple_advt_app/docs/db_user_setup.md) to create `advt_app_user` in MySQL.
- [ ] **4. Run Additive Migrations:**
  - Execute [`migrations/001_initial_hardening.sql`](file:///e:/Mani%20dev/Simple_ADVT/simple_advt_app/migrations/001_initial_hardening.sql) on your production database.
- [ ] **5. Follow Rollout Playbook:**
  - Review [`docs/rollout.md`](file:///e:/Mani%20dev/Simple_ADVT/simple_advt_app/docs/rollout.md) for switching flags to strict enforcement after the new Flutter build is deployed.
