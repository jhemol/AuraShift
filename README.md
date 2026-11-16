# AuraShift

A Vue 3 and Ionic wardrobe planner with a customizable outfit calendar, digital closet, outfit builder, weather-aware style ideas, garment-care queue, accessible color controls, and chromatic ambient styling. Outfit data is stored in browser storage by default and can be synchronized to PostgreSQL through the included Express API.

## Run

```sh
npm install
npm run dev
```

The frontend starts with sample pieces and planned looks. To run the API with its temporary in-memory store as well:

```sh
npm run dev:all
```

The frontend is available at `http://localhost:5173`; the API listens at `http://localhost:5174`. Vite forwards `/api` requests to the API. Browser local storage remains the fallback when the API is not running.

## Supabase PostgreSQL

The browser and mobile apps connect to the Express API; the database URL stays on the server and must never be added to frontend variables or committed.

1. In Supabase, open **Project Settings → Database → Connect** and copy a pooler connection string. Use the **Session pooler** for the long-running local API; for Vercel's serverless API, use the **Transaction pooler**. Both avoid requiring an IPv6-only direct connection.
2. For local development, copy `.env.example` to `.env` and set `DATABASE_URL` to the pooler URL. Use the exact host and username shown by Supabase, and URL-encode special characters in the database password. Set `SUPABASE_URL` and `SUPABASE_PUBLISHABLE_KEY` from Project Settings → API; set the `VITE_` equivalents for the web sign-in screen.
3. Keep `PGSSLMODE=require` so the API verifies the TLS certificate. Download the database CA certificate from **Project Settings → Database → SSL Configuration**, save it as `.supabase/prod-ca-2021.crt`, and keep `PGSSLROOTCERT=.supabase/prod-ca-2021.crt` in `.env`. Never disable certificate verification for a hosted database.
4. In Supabase **SQL Editor**, run `server/schema.sql` to create the per-user `wardrobe_user_state` table and enable row-level security. The API also creates it on startup. The old `wardrobe_state` table is retained and locked down; to move its data, first create an account, then set `WARDROBE_LEGACY_OWNER_ID` to that account's user UUID in the server environment and restart the API. Start the app with `npm run dev:all`; the Vite `/api` proxy forwards requests to the database-backed API. Check `http://localhost:5174/api/health` for `{ "ok": true, "storage": "postgres" }` to confirm the API can reach Supabase.

The web app supports email/password account creation and sign-in. Mobile signs in with the same account. Each account's API and database state is isolated by its verified Supabase access token; the browser/native app also keeps a separate local cache per account.

In Supabase **Authentication → URL Configuration**, set the deployed web URL as the Site URL and add it to the Redirect URLs. Enable email/password sign-up; users create their account in the web app, confirm their email if required, then use the same credentials in the Android app.

### Deploy to Vercel

The repository includes Vercel configuration for the Vite site and a serverless `/api` function. Import the GitHub repository into Vercel; it builds with `npm run build` and serves the `dist` output. In the Vercel project's **Settings → Environment Variables**, configure server-side `DATABASE_URL` (Supabase Transaction pooler), `PGSSLMODE=require`, `PGSSLROOTCERT` (contents of the CA certificate), `SUPABASE_URL`, and `SUPABASE_PUBLISHABLE_KEY`. Configure `VITE_SUPABASE_URL` and `VITE_SUPABASE_PUBLISHABLE_KEY` for the frontend build. These public client settings are not database credentials; never use a Supabase secret/service-role key in the browser or mobile build. Redeploy after setting or changing them. Check `/api/health` and expect `{ "ok": true, "storage": "postgres" }`.

Build the Android APK from the **Actions → Build and download app** workflow. Add repository Actions variables `WARDROBE_API_URL` (the deployed Vercel origin, no trailing slash), `SUPABASE_URL`, and `SUPABASE_PUBLISHABLE_KEY`; run the workflow again and install its APK artifact to sync with the web account. These are public client settings; do not add `DATABASE_URL`, the CA certificate, or a Supabase secret key to GitHub Actions variables used by the APK build.

Without `DATABASE_URL`, the API uses temporary in-memory storage and is not persistent across Vercel function instances. Do not use that mode for a production wardrobe.

For local PostgreSQL, use its connection string in `DATABASE_URL` and set `PGSSLMODE=disable`. Without `DATABASE_URL`, the API uses temporary in-memory storage. API tests do not require a live Supabase project.

Keep the Supabase database password in the API host's server-side secret settings. Supabase Auth email confirmation and redirect URLs should be configured for the deployed Vercel domain before account signup.

## Verify

```sh
npm test
npm run build
```

Tests cover color palette scoring and API read, write, and input validation. API tests use an in-memory store and do not require PostgreSQL.

## GitHub Downloads

The workflow in `.github/workflows/build-download.yml` runs tests and builds the web app and an Android debug APK on pushes to `main`, pull requests, or manual runs. In GitHub, open the repository's **Actions** tab, select **Build and download app**, open a successful run, and download either `thread-wardrobe-android-debug` (APK) or `thread-wardrobe-web` (web build) from **Artifacts**. Artifacts are retained for 14 days. The APK is a debug build for testing and is not a signed Play Store release.

## Mobile App

The installed mobile app is a separate native Flutter application in `mobile_app/`; it does not render the Vue site in a WebView. It includes the outfit calendar with event details, photo-based closet, weather-aware outfit ideas, interactive 3D outfit preview, laundry state tracking, morning timer, reminders, color accessibility preferences, and chromatic styling. Data is stored on-device and can optionally sync with the Express/PostgreSQL API by building with `--dart-define=WARDROBE_API_URL=https://your-api-host`.

Install the Flutter SDK to run it locally:

```sh
cd mobile_app
flutter create --org com.thread --project-name thread_wardrobe --platforms android,ios .
flutter pub get
dart run flutter_launcher_icons
flutter test
flutter run
```

The Android launcher icon uses the AuraShift mark in `public/aura-mark.png`; run `dart run flutter_launcher_icons` after `flutter pub get` to generate it. GitHub Actions generates a temporary Android Flutter project, runs `flutter test`, builds a native debug APK, and publishes it as the `thread-wardrobe-android-debug` artifact. The separate Vue app remains available as the web version. iOS builds require macOS and Xcode.

For locally generated iOS projects, add `NSCameraUsageDescription` and `NSPhotoLibraryUsageDescription` entries to `ios/Runner/Info.plist` before using photo capture and gallery import.

## AuraShift features

- **Calendar and outfit planning:** save layered looks to dates with appointment names and times; mark the day's clean garments as worn.
- **Garment care:** garments move through `Clean → Worn → Laundry → Clean`. Laundry cycles default to 45 minutes and update when the app is open. The former web morning-routine page is now the laundry queue.
- **Weather:** enter a city in preferences for current temperature and precipitation. The web app recommends clean closet pieces for rain, cold, or hot conditions and lets you add them to a planned look. Both apps use Open-Meteo geocoding and forecast endpoints without an API key; the city is sent to that service to retrieve local conditions.
- **Reports and analytics:** review wardrobe totals, care-state counts, and category breakdowns in web Settings, then download a CSV report with item, outfit, and current-weather details.
- **Inventory:** store photos, brand, season, color, and tags. Photo capture/gallery import is supported; background removal is a local flat-background color-key tool and works best with a plain backdrop.
- **Personalization:** choose a style preference, a color accessibility mode, and Aura intensity. Weather-tagged clean garments influence outfit suggestions and filters.

Browser notifications require permission and the web app to remain open; they are not server-delivered web push. Flutter reminders use local notifications. Laundry completion is checked while the app is open, and elapsed cycles are reconciled on launch.

The web version's walkthrough covers the digital closet, closet-based style ideas, outfit building with a live preview, calendar planning, and color notes. Style ideas are local wardrobe pairings, not an external AI service.
