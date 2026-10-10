# RoastNRizz: AI Photo Roast

Android-only Flutter app that sends a selected photo to a Cloudflare Worker
backed by Azure OpenAI Vision to generate a playful Rizz or Roast response.
The app keeps a local response fallback when the service is unavailable.

## Requirements

- Flutter SDK compatible with Dart `3.10.8` or newer
- Android Studio with an Android SDK and emulator or physical device
- JDK 17, required by the Android Gradle configuration
- Node.js and npm, required by the Cloudflare Worker tooling
- A deployed Cloudflare Worker URL, passed with
  `--dart-define=CLOUDFLARE_WORKER_URL=https://...` (the configured Worker URL
  is used by default)

## Project structure

```text
lib/
  backend/       HTTP client and response parsing
  config/        compile-time app configuration
  l10n/          interface translations
  pages/         HomePage and ResultPage UI
workers/
  src/            Cloudflare Worker and Azure OpenAI integration
android/          Android runner and Gradle configuration
test/             Flutter widget tests
docs/             development, deployment, and API notes
```

## Run and test

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

Build a debug APK with `flutter build apk --debug`. Release builds require the
Gradle signing properties supplied through local properties or CI secrets. See
[docs/deployment.md](docs/deployment.md). The keystore and passwords must never
be committed.

## Cloudflare Worker

The Worker source and Wrangler configuration are in `workers/`. See
`workers/README.md` for local development, deployment, and upstream service
configuration. The HTTP client is ready to send requests to its `/roast`
endpoint using the existing `http` package. Local sample responses are used
only as a fallback when the Worker cannot respond.

## Code map

- `lib/main.dart` starts the Material theme.
- `lib/pages/homePage/home_page_widget.dart` owns mode, persona, language, and
  photo selection. The phone locale controls the interface; result language is
  Auto by persona until the user selects an override.
- `lib/pages/resultPage/result_page_widget.dart` displays the photo, logo,
  persona, response, and Android share action.
- `lib/backend/api_requests/api_calls.dart` defines the HTTP contract for the
  Cloudflare Worker. Configure its URL only in `lib/config/app_config.dart`.
- `assets/images/roast_n_rizz_logo.png` is the shared in-app and launcher logo.

## Android permissions

The app requests internet access for the future roast service. Photo selection
uses Android's system picker, so broad storage and camera permissions are not
needed by the current implementation.

## Scope

Only the Android runner is kept in this repository. iOS, web, macOS, Linux,
and Windows runners were removed until those targets are planned and tested.
