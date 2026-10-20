# Sprint 1: Firebase identity + Spring registration OTP

Status: implemented locally; external integration acceptance is tracked separately.

## Ownership

- Firebase Authentication owns passwords, Google identity and ID tokens.
- Firestore `users/{uid}` owns profile and role. Firebase UID is the canonical user ID.
- Spring owns registration email OTP and provisions Firebase Auth + Firestore with Admin SDK. It must not create a separate SQL identity for this mode.
- Flutter authenticates with Firebase after Spring confirms registration. Spring does not issue application JWTs in this flow.
- `AUTH_MODE=firebase` is the integration target. The default remains mock so offline labs and existing tests keep working. `spring` and `dummyjson` remain compatibility/lab modes, not the chosen production architecture.

## Boundaries

UI → AuthManager → AuthService. Firebase registration delegates to injectable
RegistrationOtpClient; password-reset links also go through AuthManager.
The client never retries registration automatically. A timeout, transport failure,
5xx, malformed success response, or failed post-registration login leaves the
outcome uncertain; the UI directs the user to login/password reset.

Firebase profiles are read from the server before granting admin navigation.
Offline restoration can retain a customer-facing session, but never grants admin
from cached role alone. UI gating is not authorization: future business endpoints
must verify Firebase tokens and server-side roles independently.

## Sessions and compatibility

Persistent storage includes `auth_mode`; missing/mismatched mode clears the old
session. This intentionally logs out existing installations once. Firebase restore
and refresh require the SDK UID to match the stored UID. Missing profiles on restore
invalidate the session; an explicit login may recreate a CUSTOMER profile.

Unremembered logins are not persisted by the app. Firebase may retain an SDK user,
but that alone never authenticates the app on restart. Logout attempts local,
service and Google cleanup independently even if one fails.

Profiles must contain fullName, email, role, authProvider and createdAt. Existing
Firestore data must be audited by an administrator before deploying tightened
Rules; backfill missing fields through a trusted backend/Console, never client
privilege escalation. No automatic migration or live Rules deployment is performed.

## Dependencies

See [OTP contract](SPRINT1_OTP_CONTRACT.md), [data model](DATA_MODEL.md) and
[acceptance evidence](SPRINT1_ACCEPTANCE.md). Android is the acceptance platform;
other generated platform folders do not imply Firebase integration is configured.
