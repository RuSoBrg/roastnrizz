# Development

## Prerequisites

- Flutter SDK compatible with Dart `3.10.8` or newer
- Android Studio with Android SDK and an emulator or device
- JDK 17 for the Android/Gradle build
- Node.js 20 or newer for the Worker

Check the local Flutter installation with:

```powershell
flutter doctor -v
```

## Flutter workflow

Run from the repository root:

```powershell
flutter pub get
flutter analyze
flutter test
flutter run
```

The default Worker URL is defined in `lib/config/app_config.dart`. Override it
for a local or staging Worker without editing source code:

```powershell
flutter run --dart-define=CLOUDFLARE_WORKER_URL=https://example.workers.dev/roast
```

## Code ownership

- `lib/main.dart`: app bootstrap, theme, and localization delegates.
- `lib/pages/homePage/`: photo selection, mode, persona, and language choice.
- `lib/pages/resultPage/`: result presentation and Android sharing.
- `lib/backend/api_requests/`: HTTP client and response normalization.
- `lib/l10n/`: interface strings for the supported locales.
- `workers/src/index.js`: request validation, prompt construction, and Azure call.

Do not place Azure credentials in Flutter code. They belong in Cloudflare Worker
secrets only.
