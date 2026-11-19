<!-- Developed by Codesoftwares -->
# Nari Shakthi Matrimony — MVP (Dart Shelf + PostgreSQL + Flutter)

Start here: `docs/INSTALL_AND_RUN.md` (installation, running, testing, server deploy). Release: `docs/ANDROID_RELEASE.md`.

## Backend
1. `psql $DATABASE_URL -f backend/sql/001_init.sql` then `002_chat.sql` and `003_safety.sql`
2. Copy `backend/.env.example` values into your host's secrets (local: export them).
3. `cd backend && dart pub get && dart run bin/server.dart`
4. Health check: `GET /health`

## App
`cd app && flutter create . --platforms=android && flutter pub get`
`flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080`

## Logging
One JSON line per event on stdout (request id, method, path, status, ms). Passwords, phone numbers,
messages and payment screenshots are never logged (per Phase 10 smoke-test rule).

## Included
**API:** email register/login (bcrypt, 12h JWT, rate-limited), profile (18+), search filters, interests send/accept/reject,
mutual phone consent, shortlist, inbox, notifications, chat (accepted interests only), account deletion, photos (max 2, JPG/PNG, 2 MB, private files, access-checked),
payment screenshot upload, admin (member approve/reject/suspend, payment verify/reject, audit log; role re-checked in DB each call).
**App:** login/register, search, inbox (accept/decline/share phone), shortlist, profile + photos, UPI payment + screenshot, notifications,
admin tabs (shown only for admin accounts). One shared button style and gradient background.

## Make your first admin
Register in the app, then: `UPDATE users SET role='admin', status='approved' WHERE email='you@example.com';`

## Release
See `docs/ANDROID_RELEASE.md` (signing, Play Console, smoke tests, payments-policy check).

## Build
`flutter build apk --release --dart-define=API_BASE_URL=https://api.your-domain --dart-define=UPI_ID=name@bank`

## Known gaps / next
Also included: block/report with admin Reports tab, forgot password (emailed 6-digit code). Chat is polling every 4 s, not WebSocket. Media is on local disk (`MEDIA_DIR`); move to private object storage before scale.
Payment does not auto-approve a member (admin approves separately). No automated tests, no Android signing config yet,
Not compiled or run here: run `dart analyze` / `flutter analyze` first.

## Look and feel
Nari Shakthi Matrimony is for second marriages only: sign-up requires confirming Divorced / Widowed / Legally Separated, and no "never married" option exists.
Wedding artwork (marigold garlands, mandala, rings, lotus) is in `app/assets/images/login_bg.jpg` and `app_bg.jpg`. These are original illustrations
made by `tools/make_backgrounds.py`, not photographs. To use real wedding photos, replace those two JPGs (same names, portrait about 1080x2160,
under 500 KB) with photos you own or have licensed, and keep the middle of the picture calm so text stays readable.
Every source file starts with `Developed by Codesoftwares`; files created later by `flutter create` (the android folder) will not have it.
