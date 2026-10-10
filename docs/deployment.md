# Deployment

## Cloudflare Worker

From `workers/`:

```powershell
npm install
npx wrangler login
npx wrangler secret put AZURE_ENDPOINT
npx wrangler secret put AZURE_DEPLOYMENT
npx wrangler secret put AZURE_API_KEY
npm run deploy
```

The Worker uses the `KV_CREDITS` binding for daily balances and rewarded-ad
transaction keys. Configure the AdMob rewarded-ad server-side verification
callback as:

```text
https://roast-rizz-api.rusobrg.workers.dev/ssv
```

The callback must be configured in AdMob before production rewards are
enabled. The Flutter app sends its local UUID as the ad `custom_data` value;
the Worker verifies the AdMob signature before adding three credits.

Use the deployed `/roast` URL in Flutter through a build-time define:

```powershell
flutter run --dart-define=CLOUDFLARE_WORKER_URL=https://roast-rizz-api.rusobrg.workers.dev/roast
```

Never commit Azure secrets. The public Worker should have rate limiting and an
abuse-control strategy before paid traffic is enabled.

## Android debug build

```powershell
flutter clean
flutter pub get
flutter build apk --debug
```

## Android release build

Before publishing, configure a real release keystore in the Android Gradle
configuration or CI secret store. Keep the keystore and passwords outside Git,
then run:

```powershell
flutter build apk --release --build-name=1.0.0 --build-number=1
```

Increment `build-number` for every Play Store upload. Update `build-name` for a
user-visible release version. Confirm the Android `applicationId` is the final
product identity before publishing; it is currently a development-style id.

## Pre-release checklist

- `flutter analyze` passes.
- `flutter test` passes.
- Worker secrets are configured in the target Cloudflare account.
- The app points to the intended Worker environment.
- The Worker endpoint responds with `{ "result": "..." }` for a valid request.
- AdMob SSV is configured for the deployed `/ssv` callback.
- The `KV_CREDITS` binding points to the production credits namespace.
- Rate limiting and monitoring are enabled for public or paid traffic.
