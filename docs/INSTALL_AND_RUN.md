<!-- Developed by Codesoftwares -->
# Nari Shakthi Matrimony — Installation & Running Guide (తెలుగు)

ఈ గైడ్ లో కమాండ్లు ఇంగ్లీష్ లో, వివరణ తెలుగులో ఉంది. మొదట మీ కంప్యూటర్ లో (Windows/Linux) రన్ చేసి టెస్ట్ చేయండి, తర్వాత సర్వర్ లో పెట్టండి.

> గమనిక: ఈ కోడ్ ని నేను కంపైల్ చేసి రన్ చేయలేదు. మొదట `dart analyze` (backend) మరియు `flutter analyze` (app) చేయండి. ఎర్రర్లు వస్తే సరిచేయాలి.

## 0. కావాల్సినవి
| వస్తువు | ఎందుకు |
|---|---|
| Flutter SDK (ఇందులో Dart కూడా ఉంటుంది) | App మరియు backend రెండింటికీ |
| Android Studio (SDK + Emulator) | Android యాప్ రన్ చేయడానికి |
| PostgreSQL 15 లేదా కొత్తది | Database |
| (ఐచ్ఛికం) ఒక Android ఫోన్, USB debugging ఆన్ | నిజమైన ఫోన్ టెస్ట్ |

Windows లో: Flutter ని `C:\src\flutter` లో unzip చేసి, `C:\src\flutter\bin` ని PATH లో చేర్చండి. PostgreSQL ని EDB installer తో వేసి, `postgres` పాస్‌వర్డ్ గుర్తుంచుకోండి. `C:\Program Files\PostgreSQL\16\bin` ని PATH లో చేర్చండి (psql కోసం).

ఇన్‌స్టాల్ సరిగా అయ్యిందో చూడండి:
```
flutter doctor
flutter doctor --android-licenses
dart --version
psql --version
```

## 1. Database తయారీ
zip ని unzip చేసిన `nari_shakthi` ఫోల్డర్ లో:
```
psql -U postgres -c "CREATE DATABASE nari_shakthi;"
psql -U postgres -d nari_shakthi -f backend/sql/001_init.sql
psql -U postgres -d nari_shakthi -f backend/sql/002_chat.sql
psql -U postgres -d nari_shakthi -f backend/sql/003_safety.sql
```
మూడు ఫైళ్లు ఇదే వరుసలో రన్ చేయాలి. ప్రతి ఒక్కటి ఒక్కసారి మాత్రమే.

## 2. Backend రన్ చేయడం
1. `backend/run_dev.ps1` (Linux లో `run_dev.sh`) ఓపెన్ చేసి `YOUR_DB_PASSWORD` ని మీ postgres పాస్‌వర్డ్ తో మార్చండి. పాస్‌వర్డ్ లో `@ : / #` ఉంటే URL-encode చేయండి.
2. రన్:
```
cd backend
.\run_dev.ps1          # Windows PowerShell
./run_dev.sh           # Linux / macOS
```
3. చెక్ చేయండి: బ్రౌజర్ లో `http://localhost:8080/health` → `{"status":"ok"}` రావాలి.
4. కన్సోల్ లో JSON లాగ్ లైన్లు కనిపిస్తాయి (request id, path, status, ms). పాస్‌వర్డ్, ఫోన్ నంబర్, మెసేజ్ టెక్స్ట్ లాగ్ లో రావు.

డెవలప్‌మెంట్ లో ఇమెయిల్ పంపకపోయినా "Forgot password" కోడ్ ఈ కన్సోల్ లో `dev_mail` లైన్ లో కనిపిస్తుంది. Production లో ఇది కనిపించదు.

`run_dev` ప్రతిసారి కొత్త `TOKEN_SIGNING_SECRET` తయారు చేస్తుంది, కాబట్టి రీస్టార్ట్ చేస్తే అందరూ మళ్ళీ sign in అవ్వాలి. ఇది డెవలప్‌మెంట్ కి మాత్రమే.

## 3. మొదటి Admin ఖాతా
యాప్ లో (లేదా curl తో) ఒక ఖాతా register చేసి, తర్వాత:
```
psql -U postgres -d nari_shakthi -c "UPDATE users SET role='admin', status='approved' WHERE email='మీ-ఇమెయిల్';"
```
మళ్ళీ sign in అయితే "Admin" ట్యాబ్ కనిపిస్తుంది.

## 4. Android యాప్ రన్ చేయడం
```
cd app
flutter create . --platforms=android --org com.yourcompany --project-name nari_shakthi
flutter pub get
```
`lib/` లోని మా ఫైళ్లు మారవు (`flutter create` వాటిని ఓవర్‌రైట్ చేయదు; ఒకవేళ `lib/main.dart` మారితే zip లోని దాన్ని తిరిగి పెట్టండి).

**డెవలప్‌మెంట్ లో http కోసం (ఒక్కసారి):** `app/android/app/src/debug/AndroidManifest.xml` ని ఇలా చేయండి (Release లో ఇది పెట్టకండి):
```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-permission android:name="android.permission.INTERNET"/>
    <application android:usesCleartextTraffic="true"/>
</manifest>
```

**Emulator లో:**
```
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080 --dart-define=UPI_ID=test@upi
```
(Emulator లో `10.0.2.2` అంటే మీ PC.)

**నిజమైన ఫోన్ లో:** ఫోన్ మరియు PC ఒకే Wi-Fi లో ఉండాలి. PC IP చూడండి (`ipconfig`, ఉదా. 192.168.1.20). Windows firewall లో పోర్ట్ తెరవండి (Admin PowerShell):
```
netsh advfirewall firewall add rule name="NariShakthi API" dir=in action=allow protocol=TCP localport=8080
flutter run --dart-define=API_BASE_URL=http://192.168.1.20:8080 --dart-define=UPI_ID=test@upi
```

## 5. పూర్తి టెస్ట్ (3 ఖాతాలతో)
1. **A** (male), **B** (female), **Admin** ఖాతాలు తయారు చేయండి. A మరియు B యాప్ లో Profile నింపి Save చేయండి, ఒక ఫోటో జోడించండి.
2. A తో Search చేస్తే "awaiting admin approval" వస్తుంది. Admin ట్యాబ్ → Members → Pending నుండి A, B ని Approve చేయండి.
3. A: B ని Search చేసి "Send interest". B: Inbox లో Accept.
4. ఇద్దరూ Inbox లో "Chat" తెరిచి మెసేజ్ లు పంపుకోండి. "Phone" బటన్ ఇద్దరూ నొక్కితేనే నంబర్ కనిపిస్తుంది.
5. Payment ట్యాబ్ లో screenshot అప్‌లోడ్ → Admin → Payments → Verify. నోటిఫికేషన్ (గంట గుర్తు) వస్తుంది.
6. B ప్రొఫైల్ కార్డ్ లో ⋮ → Report చేస్తే Admin → Reports లో కనిపిస్తుంది. Block చేస్తే వారు ఒకరికొకరు కనిపించరు.
7. Sign in స్క్రీన్ లో "Forgot password?" → కోడ్ (కన్సోల్ లో) → కొత్త పాస్‌వర్డ్.
8. Profile → Delete my account తో ఖాతా తొలగింపు చెక్ చేయండి.

## 6. Production సర్వర్ (Linux VPS, Ubuntu)
1. **ప్యాకేజీలు:** `sudo apt install postgresql nginx certbot python3-certbot-nginx`, Dart SDK ని dart.dev సూచనల ప్రకారం వేయండి.
2. **DB వినియోగదారు (postgres superuser వాడకండి):**
```
sudo -u postgres psql -c "CREATE USER si_app WITH PASSWORD 'STRONG_PASSWORD';"
sudo -u postgres psql -c "CREATE DATABASE nari_shakthi OWNER si_app;"
psql "postgres://si_app:STRONG_PASSWORD@localhost/nari_shakthi" -f backend/sql/001_init.sql   # తర్వాత 002, 003
```
3. **Build:**
```
cd backend && dart pub get && dart compile exe bin/server.dart -o /opt/nari_shakthi/server
sudo mkdir -p /var/lib/nari_shakthi/media && sudo chown www-data /var/lib/nari_shakthi/media
```
4. **`/etc/nari_shakthi.env`** (`chmod 600`): `.env.example` లోని పేర్లు, నిజమైన విలువలతో. `APP_ENV=production`, `TOKEN_SIGNING_SECRET=$(openssl rand -base64 48)`, SMTP వివరాలు (పాస్‌వర్డ్ రీసెట్ కోడ్ ఇమెయిల్ కోసం తప్పనిసరి).
5. **systemd** `/etc/systemd/system/nari_shakthi.service`:
```
[Unit]
Description=Nari Shakthi Matrimony API
After=network.target postgresql.service
[Service]
User=www-data
EnvironmentFile=/etc/nari_shakthi.env
ExecStart=/opt/nari_shakthi/server
Restart=always
[Install]
WantedBy=multi-user.target
```
`sudo systemctl enable --now nari_shakthi`
6. **nginx** (HTTPS తప్పనిసరి): `server_name api.your-domain;` లో
```
client_max_body_size 4m;
location / {
    proxy_pass http://127.0.0.1:8080;
    proxy_set_header X-Forwarded-For $remote_addr;
    proxy_set_header Host $host;
}
```
తర్వాత `sudo certbot --nginx -d api.your-domain`. పోర్ట్ 8080 ని బయటకు తెరవకండి (firewall లో 80, 443 మాత్రమే).
7. **చెక్:** `curl https://api.your-domain/health`
8. **లాగ్స్:** `journalctl -u nari_shakthi -f`
9. **బ్యాకప్ (రోజూ):** `pg_dump` + `/var/lib/nari_shakthi/media` ఫోల్డర్ కాపీ. ఒకసారి restore చేసి చూడండి.
10. **అప్‌డేట్:** కొత్త కోడ్ తో మళ్ళీ build → `sudo systemctl restart nari_shakthi`. కొత్త SQL ఫైళ్లు ఉంటే ముందే రన్ చేయండి.
11. Android release కోసం `docs/ANDROID_RELEASE.md` చూడండి.

## 7. సమస్యలు మరియు పరిష్కారాలు
| సమస్య | కారణం / పరిష్కారం |
|---|---|
| `TOKEN_SIGNING_SECRET missing` | env వేరియబుల్ సెట్ కాలేదు. `run_dev` ద్వారా రన్ చేయండి. |
| `password authentication failed` | DATABASE_URL లో పాస్‌వర్డ్ తప్పు, లేదా URL-encode చేయలేదు. |
| `database ... does not exist` | 1వ దశ లో `CREATE DATABASE` రన్ చేయలేదు. |
| యాప్ లో "Cannot reach the server" | Emulator లో `10.0.2.2`, ఫోన్ లో PC IP వాడండి. debug manifest లో cleartext జోడించండి. Firewall 8080 తెరవండి. Backend రన్ అవుతోందో చూడండి. |
| "awaiting admin approval" | Admin ట్యాబ్ లో ఆ సభ్యుడిని Approve చేయండి. |
| "Too many attempts" | login/reset కి 10 నిమిషాలకు 20 ప్రయత్నాల పరిమితి. కొంచెం ఆగండి. |
| ఫోటో అప్‌లోడ్ లో 413 | ఫోటో 2 MB కంటే పెద్దది, లేదా nginx లో `client_max_body_size` పెంచలేదు. |
| Production లో DB SSL ఎర్రర్ | production లో DB కి SSL తప్పనిసరి. Postgres లో `ssl = on` చూడండి, లేదా managed DB వాడండి. |
| Reset కోడ్ ఇమెయిల్ రావడం లేదు | SMTP env విలువలు తప్పు. `journalctl` లో `mail_failed` లేదా `smtp_not_configured` చూడండి. |
| `flutter doctor` లో Android licenses | `flutter doctor --android-licenses` రన్ చేసి అన్నిటికీ `y` ఇవ్వండి. |
