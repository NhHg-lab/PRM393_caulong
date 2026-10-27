# Spring registration OTP contract

Base URL: `API_BASE_URL` without `/api` or trailing slash. Flutter adds `/api`.
Android emulator defaults to `http://10.0.2.2:8080`; a physical device needs a
reachable host address. Use HTTPS for deployed environments.

## Send OTP

`POST /api/auth/register/send-otp`, JSON:

```json
{"email":"player@example.com"}
```

200 response:

```json
{"message":"Đã gửi mã OTP","expiresIn":300,"resendAfter":60}
```

Both timers are integer seconds; expiresIn > 0 and resendAfter >= 0.
The app uses these values rather than inventing a successful response.

## Register Firebase account

`POST /api/auth/register/firebase`, JSON:

```json
{"fullName":"Test Player","email":"player@example.com","phone":"0901234567","password":"ExampleOnly@123","otp":"123456"}
```

`phone` is optional. Success: 201 (200 accepted for existing backend compatibility):

```json
{"message":"Đã tạo tài khoản"}
```

No token or role is accepted from this response. Flutter then calls Firebase
email/password sign-in and reads `users/{uid}` from Firestore.

## Errors

JSON error body uses `message`, with optional `fieldErrors`.

| HTTP | Meaning |
|---|---|
| 400 | Invalid input, invalid/expired OTP |
| 409 | Email already registered |
| 429 | OTP send/attempt limit reached |
| 503 | Mail/provisioning service unavailable |

Flutter displays controlled errors. Registration 5xx/timeout/network failure or
malformed success is treated as an uncertain outcome, not an invitation to retry
blindly. Send-OTP failures retain normal error messages.

## Backend implementation requirements / handoff

- Validate name/email/password/phone and normalize email consistently.
- Store OTP securely with expiry, rate limits and bounded failed attempts;
  consume it once and prevent concurrent reuse.
- Create Firebase account only after valid OTP; set emailVerified = true.
- Create `users/{uid}` with fullName, lowercase email, role CUSTOMER,
  authProvider LOCAL, createdAt server timestamp and optional phone/avatarUrl.
- Ignore/reject supplied role and other privileged fields.
- Handle partial Auth/Firestore provisioning safely: repair or compensate;
  never report success before the account and profile are ready.
- Do not store plaintext passwords or log password/OTP/token/request bodies.
- Configure Firebase Admin credentials only on the backend.
- Verify using a real email: success, duplicate, expiry, wrong code, resend
  throttling, concurrent submit, mail failure, and partial provisioning.

These are obligations for the separate backend repository, not proof that the
backend already implements them. This repository contains client contract tests.
