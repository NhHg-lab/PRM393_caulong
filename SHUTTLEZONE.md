# ShuttleZone customer UI

The customer destination in `lib/main.dart` now opens `lib/screens/shuttlezone/customer_app.dart`. Existing login, OTP, session restoration, logout, Firebase configuration and administrator routing are retained. The previous Courtly customer screens remain available as source but are no longer the customer entry point.

## Reference

Implemented from the six user-supplied Stitch HTML exports: home, venue detail, checkout, ticket, matchmaking, and account. Court photographs are bundled from those exports. Plus Jakarta Sans is bundled with its OFL license. No additional Flutter packages were introduced.

## Behavior

- Five customer tabs: Trang chủ, Tìm sân, Ghép kèo, Lịch & Vé, Tài khoản.
- Search venue names/addresses and combine amenity filters. Saved venues are available through the Đã lưu filter.
- Choose a date, court number and consecutive one-hour slots. Past slots and example occupied slots are disabled. Existing active tickets also block those slots in this running session.
- Rent is calculated per selected hour. Checkout adds racket quantities, shuttles, optional water and an optional demo voucher. The deposit is 50% of the final amount, rounded up. Ticket details retain the selected court, date, hours, extras, payment mode and method.
- Checkout expires after 15 minutes. This is a local demo session timer, not a server-side inventory hold.
- Cancel a ticket at least four hours before its start time. Cancellation releases the demo slots. The four-hour policy is consistent on checkout and ticket screens.
- Create, join and leave demo matches; filter by skill or show owned/joined matches. Match creation does not reserve a court.
- Account identity comes from the signed-in AppUser. Personal stats are based on tickets in this session; unverified UTR and badges remain unverified/locked.

## Demo boundaries

No real money is collected. VietQR, MoMo and card payment choices are presentation state only. Tickets are clearly marked as demo, with no real admission QR. Bookings, saved venues and matches are kept in memory and reset on a full restart. Ticket sharing and location actions copy plain text to the clipboard; there is no automatic calendar, maps, messaging or wallet integration.

## Run and validate

Run the existing Flutter entry point and sign in using the existing authentication flow. After adding assets/fonts, perform a full stop and restart rather than hot reload alone.

```powershell
C:\flutter\bin\flutter.bat pub get
C:\flutter\bin\flutter.bat run
C:\flutter\bin\flutter.bat analyze --no-pub
C:\flutter\bin\flutter.bat test --no-pub
```

Optional rendered mobile previews from widget tests:

```powershell
C:\flutter\bin\flutter.bat test --no-pub test\shuttlezone_test.dart --dart-define=SHUTTLE_PREVIEWS=true
```

Previews are written to `build/shuttlezone/` (ignored build output).
