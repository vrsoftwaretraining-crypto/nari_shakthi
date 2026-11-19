#!/usr/bin/env bash
# Developed by Codesoftwares
# Linux/macOS: run from the backend folder.  Edit the DATABASE_URL password first.
export APP_ENV=development PORT=8080 MEDIA_DIR=media
export DATABASE_URL="postgres://postgres:YOUR_DB_PASSWORD@localhost:5432/nari_shakthi"
export TOKEN_SIGNING_SECRET="$(openssl rand -base64 48)"
dart pub get && dart run bin/server.dart
