# Data foundation for Sprint 2–5

Design contract only. Sprint 1 does not create business repositories, migrate demo
data, or allow business reads/writes in Firestore Rules.

All IDs are strings. User references are Firebase UIDs. Persist instants as UTC
timestamps; display and resolve operating schedules in Asia/Ho_Chi_Minh. Money is
integer VND. Clients never authoritatively determine price, role or payment status.

| Collection | Identity / relationships | Main fields and authority |
|---|---|---|
| users | document ID = Firebase UID | fullName, email, phone?, avatarUrl?, role CUSTOMER/ADMIN, authProvider LOCAL/GOOGLE, createdAt; client edits only name/phone/avatar |
| venues | generated ID | name, address, timezone, amenities, photos, active; admin through trusted server |
| courts | generated ID, venueId | name/number, operating schedule, base and peak pricing, active; admin through server |
| bookings | generated ID, userId, venueId, courtId | startAt, endAt, expiresAt, price snapshot, total, status; server validates availability and computes price |
| payments | generated ID, bookingId, userId | provider reference, amount, status, timestamps; only verified server/provider results change financial state |
| matches | generated ID, ownerId, venueId, optional bookingId | title, level, startAt, endAt, capacity, fee, status; server validates membership/capacity |
| matches/{id}/members | document ID = member UID | joinedAt, status; server maintains capacity atomically |
| users/{uid}/favorites | document ID = venueId | createdAt; owner-only operations in a later sprint |

Booking lifecycle: HOLD → CONFIRMED → COMPLETED; HOLD → EXPIRED/CANCELLED;
CONFIRMED → CANCELLED subject to policy. Payment lifecycle is independent:
PENDING → SUCCEEDED/FAILED/CANCELLED; SUCCEEDED → REFUND_PENDING → REFUNDED.
Do not interpret cancellation as evidence of refund.

Reservations and payment totals are server-owned. Later sprints must enforce
atomic availability allocation, expiring holds and idempotent provider callbacks.
Role claims in request payloads are never trusted. Collection access remains
denied until the corresponding feature's API and authorization tests are ready.
