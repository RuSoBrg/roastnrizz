# Production checklist

## 1. Cloudflare Worker
- Run `npm install` inside `workers/`
- Authenticate with `npx wrangler login`
- Set secrets:
  - `npx wrangler secret put AZURE_ENDPOINT`
  - `npx wrangler secret put AZURE_DEPLOYMENT`
  - `npx wrangler secret put AZURE_API_KEY`
- Deploy: `npm run deploy`

## 2. App configuration
- Make sure the Flutter app points to the production worker URL.
- Use `flutter run --dart-define=CLOUDFLARE_WORKER_URL=https://<worker>/roast`
- Keep real values in local `.env` and never commit them.

## 3. AdMob
- Configure the production app ID and rewarded ad unit ID in AdMob.
- Configure the rewarded callback on the deployed worker: `https://<worker>/ssv`
- Validate the AdMob SSV flow with the credit system.

## 4. KV credits
- Create a Cloudflare KV namespace.
- Bind it as `KV_CREDITS` in the worker.

## 5. Android release
- Generate a real keystore.
- Configure Gradle signing env vars:
  - `RELEASE_STORE_FILE`
  - `RELEASE_STORE_PASSWORD`
  - `RELEASE_KEY_ALIAS`
  - `RELEASE_KEY_PASSWORD`
- Build the release APK:
  - `flutter build apk --release --build-name=1.0.0 --build-number=1`

## 6. Final validation
- `flutter analyze`
- `flutter test`
- Confirm the production worker `/roast` route works.
- Confirm AdMob reward flow works.
- Confirm the app is using production worker URL.

## 7. Publish
- Upload the generated APK to Google Play.
- Keep secrets out of Git and out of source control.
