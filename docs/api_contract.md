# ADVT App - Frontend to Backend API Contract

This document defines the strict API contract between the Flutter client application (`lib/`) and the Node.js / Express backend (`backend/server.js`). All changes to existing routes must preserve response keys, data types, and status codes to maintain 100% backward compatibility for existing client builds.

---

## 1. Authentication & User Profile APIs

### 1.1 `POST /api/send-email-otp`
- **Caller:** `AuthService.sendEmailOtp()` in `lib/services/auth_service.dart`
- **Headers:** `Content-Type: application/json`
- **Request Body:**
  ```json
  { "email": "user@example.com" }
  ```
- **Response (200 OK):**
  ```json
  { "success": true, "message": "Verification OTP sent successfully to your email." }
  ```
- **Error Response (400/429):**
  ```json
  { "success": false, "message": "Please enter a valid email address." }
  ```

### 1.2 `POST /api/resend-email-otp`
- **Caller:** `AuthService.resendOtp()` in `lib/services/auth_service.dart`
- **Headers:** `Content-Type: application/json`
- **Request Body:**
  ```json
  { "email": "user@example.com" }
  ```
- **Response (200 OK):**
  ```json
  { "success": true, "message": "New OTP has been sent." }
  ```

### 1.3 `POST /api/verify-email-otp`
- **Caller:** `AuthService.verifyEmailOtp()` in `lib/services/auth_service.dart`
- **Headers:** `Content-Type: application/json`
- **Request Body:**
  ```json
  { "email": "user@example.com", "otp": "123456" }
  ```
- **Response (200 OK - Existing User):**
  ```json
  {
    "success": true,
    "message": "Email verified successfully!",
    "token": "eyJhbGciOi...",
    "isExistingUser": true,
    "user": {
      "id": 1,
      "userId": "U001",
      "email": "user@example.com",
      "full_name": "Mani Kumar",
      "name": "Mani Kumar",
      "mobile_number": "9876543210",
      "phone": "9876543210",
      "country_code": "+91",
      "full_address": "123 Main St",
      "locality": "Adyar",
      "city": "Chennai",
      "state": "Tamil Nadu",
      "country": "India",
      "latitude": 13.001,
      "longitude": 80.256,
      "isEmailVerified": true
    }
  }
  ```
- **Response (200 OK - New User):**
  ```json
  {
    "success": true,
    "message": "Email verified successfully!",
    "token": "eyJhbGciOi...",
    "isExistingUser": false,
    "user": { "email": "user@example.com", "isEmailVerified": true }
  }
  ```

### 1.4 `POST /api/register-user`
- **Caller:** `AuthService.registerUser()` in `lib/services/auth_service.dart`
- **Headers:** `Content-Type: application/json`
- **Request Body:**
  ```json
  {
    "email": "user@example.com",
    "full_name": "Mani Kumar",
    "full_address": "123 Street",
    "locality": "Adyar",
    "city": "Chennai",
    "state": "Tamil Nadu",
    "country": "India",
    "latitude": 13.001,
    "longitude": 80.256,
    "mobile_number": "9876543210",
    "country_code": "+91"
  }
  ```
- **Response (201 Created):**
  ```json
  {
    "success": true,
    "message": "User registered successfully!",
    "token": "eyJhbGciOi...",
    "user": { "id": 1, "userId": "U001", "email": "...", "full_name": "...", ... }
  }
  ```

### 1.5 `GET /api/user-profile`
- **Caller:** `AuthService.fetchUserProfile()` in `lib/services/auth_service.dart`
- **Query:** `?email=user@example.com`
- **Headers:** `Authorization: Bearer <token>` (New client)
- **Response (200 OK):**
  ```json
  {
    "success": true,
    "user": { "id": 1, "userId": "U001", "email": "...", "full_name": "...", "locality": "...", "city": "...", "state": "...", "latitude": 0.0, "longitude": 0.0 }
  }
  ```

### 1.6 `PUT /api/update-profile`
- **Caller:** `AuthService.updateProfile()` in `lib/services/auth_service.dart`
- **Request Body:**
  ```json
  { "email": "...", "full_name": "...", "full_address": "...", "locality": "...", "city": "...", "state": "...", "country": "...", "latitude": 0.0, "longitude": 0.0 }
  ```
- **Response (200 OK):**
  ```json
  { "success": true, "message": "Profile updated successfully!", "user": { ... } }
  ```

---

## 2. Business Profile APIs

### 2.1 `GET /api/business-profiles/my`
- **Caller:** `BusinessService.fetchUserBusinesses()` in `lib/services/business_service.dart`
- **Query:** `?user_id=U001` (Legacy fallback)
- **Headers:** `Authorization: Bearer <token>`
- **Response (200 OK):**
  ```json
  {
    "success": true,
    "data": [
      {
        "business_id": 1,
        "businessProfileId": "BP001",
        "business_name": "Mani Bakery",
        "category": "Food & Beverage",
        "business_phone": "9876543210",
        "country_code": "+91",
        "profile_image": "https://...",
        "images": ["https://..."],
        "about": "Fresh bakes daily",
        "created_at": "2026-10-01T..."
      }
    ]
  }
  ```

### 2.2 `POST /api/business-profiles`
- **Caller:** `BusinessService.createBusinessProfile()`
- **Headers:** `Authorization: Bearer <token>`
- **Request Body:**
  ```json
  {
    "business_name": "Mani Bakery",
    "category": "Food",
    "business_phone": "9876543210",
    "country_code": "+91",
    "profile_image": "https://...",
    "images": ["https://..."],
    "about": "..."
  }
  ```
- **Response (201 Created):**
  ```json
  { "success": true, "message": "Business profile created successfully!", "data": { "business_id": 1, ... } }
  ```

### 2.3 `PUT /api/business-profiles/:id` & `DELETE /api/business-profiles/:id`
- **Caller:** `BusinessService.updateBusinessProfile()`, `BusinessService.deleteBusinessProfile()`
- **Headers:** `Authorization: Bearer <token>`

---

## 3. Post Creation, Payments & Feed APIs

### 3.1 `GET /api/posts` (Explore Feed)
- **Caller:** `PostService.fetchPosts()` in `lib/services/post_service.dart`
- **Query Parameters:** `city`, `locality`, `state`, `category`, `days`
- **Response (200 OK):**
  ```json
  {
    "success": true,
    "data": [
      {
        "post_id": 10,
        "id": "P010",
        "business_id": 1,
        "businessProfileId": "BP001",
        "bizName": "Mani Bakery",
        "title": "50% Off Croissants",
        "subtitle": "Weekend Special",
        "description": "Valid till Sunday",
        "target_location": "Chennai",
        "images": ["https://..."],
        "status": "active",
        "duration_days": 7,
        "published_at": "2026-10-01T...",
        "expires_at": "2026-10-08T...",
        "timeAgo": "2h ago"
      }
    ]
  }
  ```

### 3.2 `POST /api/posts` / `POST /api/posts/create-pending`
- **Caller:** `PostService.createPost()` & `InAppPurchaseService.initiatePostCreation()`
- **Headers:** `Authorization: Bearer <token>`
- **Request Body:**
  ```json
  {
    "business_id": 1,
    "title": "Croissant Sale",
    "subtitle": "Fresh Daily",
    "description": "...",
    "target_location": "Chennai",
    "images": ["https://..."],
    "duration_days": 7,
    "status": "pending"
  }
  ```
- **Response (201 Created):**
  ```json
  {
    "success": true,
    "message": "Post created successfully in pending status.",
    "post_id": 10,
    "postId": "P010",
    "data": { ... }
  }
  ```

### 3.3 `POST /api/payments/verify-and-activate-post`
- **Caller:** `InAppPurchaseService._handleSuccessfulPurchase()`
- **Headers:** `Authorization: Bearer <token>`
- **Request Body:**
  ```json
  {
    "post_id": 10,
    "business_id": 1,
    "product_id": "advt_post_7_days",
    "duration_days": 7,
    "platform": "android",
    "transaction_id": "GPA.3312-9842-1102",
    "purchase_token": "token_string_here",
    "raw_payload": { ... }
  }
  ```
- **Response (200 OK):**
  ```json
  {
    "success": true,
    "message": "Post payment verified and activated successfully!",
    "post": { "post_id": 10, "status": "active", "duration_days": 7, "expires_at": "..." },
    "transaction": { "transaction_id": "GPA.3312-..." }
  }
  ```

---

## 4. Bookmarks, Follows & Notifications APIs

- `GET /api/posts/saved` $\rightarrow$ Returns bookmarked posts for authenticated user.
- `POST /api/posts/:id/save` $\rightarrow$ Toggles post bookmark.
- `POST /api/posts/:id/more-info-click` $\rightarrow$ Increments click analytics.
- `GET /api/business-profiles/:id/follow-status` $\rightarrow$ Returns `{ isFollowed: true/false }`.
- `POST /api/business-profiles/:id/follow` $\rightarrow$ Toggles following status.
- `GET /api/business-profiles/followed` $\rightarrow$ List of followed businesses.
- `GET /api/notifications` $\rightarrow$ User's notification inbox.
- `PUT /api/notifications/:id/read` & `PUT /api/notifications/mark-all-read`
- `DELETE /api/notifications/:id` & `DELETE /api/notifications` (Batch delete).
