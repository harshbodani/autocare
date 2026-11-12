# AutoCare — Vehicle Service Management

Flutter app (Android + web) with a Node.js / Express API on **PostgreSQL**, hosted on **Render**.

## How data is stored ("both")
| Where | What |
|---|---|
| **PostgreSQL on Render** | The shared source of truth: users, customers, vehicles, bookings, invoices, reminders. |
| **On the phone** (SharedPreferences) | A copy of everything the app has loaded, so screens open offline. Changes made offline are queued and sent automatically when the server is reachable again (a banner shows the state). |

Passwords are hashed (scrypt) and the API requires a signed token.

## 1. Deploy the backend + database on Render
1. Push this project to a GitHub repository.
2. Create a free Postgres database at [neon.tech](https://neon.tech) and copy its connection string (starts with `postgresql://`).
3. Render dashboard → **New → Blueprint** → select the repo. `render.yaml` creates the web service `autocare-api` and generates `JWT_SECRET`. When asked for `DATABASE_URL`, paste the Neon connection string.
4. When it is live, open `https://<your-service>.onrender.com/health` — you should see `{"ok":true}`. Tables and demo data are created automatically on first start.

Notes: on Render's free plan the API sleeps when idle (first request takes ~1 minute) and Neon's free database pauses when idle and wakes on the next request.

## 2. Get the Android app onto a phone
**Option A — build in the cloud (no Flutter install needed):**
1. In the same GitHub repo, set a repository variable `API_URL` = your Render address (Settings → Secrets and variables → Actions → Variables).
2. Actions tab → **Build Android APK** → Run workflow. Download the `autocare-apk` artifact (`app-release.apk`).
3. Copy the APK to the phone, open it, and allow "Install unknown apps" when asked.

**Option B — build locally** (Flutter + Android SDK installed):
```bash
flutter pub get
flutter build apk --release --dart-define=API_URL=https://<your-service>.onrender.com
# -> build/app/outputs/flutter-apk/app-release.apk
```
The server address can also be changed inside the app (Login screen or Profile → **Server settings**).

## Demo login
`admin@autocare.com` / `password` (change it after first deploy). New sign-ups get role `USER`.

## Run the backend locally
```bash
cd backend
cp .env.example .env      # edit DATABASE_URL
npm install
npm start                 # creates tables, seeds demo data, listens on :3000
```
Debug builds of the app may use plain `http://` servers (e.g. `http://192.168.x.x:3000`); release builds require `https`.

## Signing for Play Store / updates
Without setup, release APKs are signed with the debug key (fine for installing). To use your own key, create `android/key.properties`:
```
storeFile=/path/to/upload.jks
storePassword=...
keyAlias=upload
keyPassword=...
```
Application id: `com.autocare.app`.

## API
`POST /api/auth/login|register`, then (Bearer token) `GET/POST /api/{customers,vehicles,bookings,invoices,reminders}`, `PUT|DELETE /api/<table>/:id`, `PUT /api/bookings/:id/status`, `PUT /api/reminders/:id/done`, `GET /api/vehicles/:id/history`, `GET /api/dashboard`, `GET /health`.
