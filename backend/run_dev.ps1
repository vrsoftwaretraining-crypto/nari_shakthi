# Developed by Codesoftwares
# Windows PowerShell: run from the backend folder.  Edit the DATABASE_URL password first.
$env:APP_ENV = "development"
$env:PORT = "8080"
$env:DATABASE_URL = "postgres://postgres:postgres@localhost:5432/nari_shakthi"
$env:TOKEN_SIGNING_SECRET = ([guid]::NewGuid().ToString('N') + [guid]::NewGuid().ToString('N'))
$env:MEDIA_DIR = "media"
# Razorpay TEST keys from dashboard.razorpay.com (Account & Settings > API keys). Leave empty to hide "Pay online".
# Website origin (production only; localhost is allowed automatically in dev)
$env:CORS_ORIGINS = ""
$env:RAZORPAY_KEY_ID = ""
$env:RAZORPAY_KEY_SECRET = ""
$env:RAZORPAY_WEBHOOK_SECRET = ""
dart pub get
dart run bin/server.dart
