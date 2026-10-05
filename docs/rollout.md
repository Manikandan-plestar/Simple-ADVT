# Production Hardening & Safe Rollout Playbook

This rollout guide ensures zero-downtime and zero client breakage while transitioning the live system from permissive development mode to zero-trust production security.

---

## Phase 1: Deploy Hardened Backend with Safe Monitor Defaults

1. **Configure Environment Variables in Production (Cloud Run / App Engine / Compute Engine):**
   - Ensure `JWT_SECRET` is set to a secure string (minimum 32 characters).
   - If rotating an existing secret, set `JWT_SECRET_PREVIOUS` to the previous secret so existing active client tokens remain valid.
   - Set feature flags to safe monitor defaults:
     ```env
     ALLOW_LEGACY_IDENTITY=true
     ENFORCE_PROFILE_AUTH=false
     ENABLE_TEST_OTP=false
     VERIFY_PLAY_PURCHASES=false
     MIN_SUPPORTED_APP_VERSION=1.0.0
     ```

2. **Deploy the Backend Server:**
   - Verify deployment using health check:
     ```bash
     curl -s https://<your-backend-domain>/api/health
     ```
   - Monitor backend logs for any legacy traffic:
     - `[LEGACY-AUTH] route=... method=... appVersion=...`
     - `[AUTHZ-MONITOR] route=... unauthenticated access ...`

---

## Phase 2: Release Flutter App Update (v1.0.1+)

1. **Publish the updated Flutter app to Google Play Store and Apple App Store.**
   - The new app build includes `X-App-Version: 1.0.0` header and routes all profile requests with `Authorization: Bearer <token>`.
   - Includes silent session migration from legacy temporary files to application storage.

2. **Monitor App Adoption:**
   - Watch Google Play Console / Firebase analytics until older client builds drop below 5% of active traffic.

---

## Phase 3: Incremental Zero-Trust Security Enforcement

Flip the backend flags sequentially (one by one) in your production environment settings:

### Step 3.1: Enforce Authenticated Profiles
- Set in backend environment:
  ```env
  ENFORCE_PROFILE_AUTH=true
  ```
- **Result:** `GET /api/user-profile` and `PUT /api/update-profile` strictly require a valid JWT token matching the requesting user ID. Anonymous data scraping is blocked.
- **Rollback:** Set `ENFORCE_PROFILE_AUTH=false` if any legacy clients fail.

### Step 3.2: Disable Legacy Header/Query Auth Fallbacks
- Set in backend environment:
  ```env
  ALLOW_LEGACY_IDENTITY=false
  ```
- **Result:** Custom headers `x-user-id`, `x-user-email` and query string parameters `?user_id=` cannot be used to spoof accounts. All requests must carry a signed JWT.
- **Rollback:** Set `ALLOW_LEGACY_IDENTITY=true`.

### Step 3.3: Activate Server-Side Play Store Purchase Verification
- Once the Google Play Developer API service account credentials are added to environment:
  ```env
  VERIFY_PLAY_PURCHASES=true
  ```
- **Result:** Receipts are validated against Google Play Developer API in real time.

---

## Phase 4: Key Rotation & Cleanup

1. After all issued 30-day JWT tokens have cycled (30 days post-deployment), remove `JWT_SECRET_PREVIOUS` from the production `.env`.
