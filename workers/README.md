# Roast N Rizz Worker

Cloudflare Worker endpoint used by the Flutter app.

## Local development

```bash
npm install
npm run dev
```

The Worker exposes `POST /roast` (`POST /` is retained for backwards
compatibility), forwarding validated JSON requests to Azure OpenAI Vision.
Configure these values as secrets before deploying:

```bash
npx wrangler secret put AZURE_ENDPOINT
npx wrangler secret put AZURE_DEPLOYMENT
npx wrangler secret put AZURE_API_KEY
```

The endpoint enforces JSON content, a 9 MB request limit, supported languages
and modes, a required Base64 photo, and a 20-second Azure timeout. Add Cloudflare
rate limiting and an authenticated edge in production before enabling paid AI
traffic; the mobile app must not contain a private API secret.

Successful responses use this shape:

```json
{ "result": "Generated response" }
```

Supported languages are `en`, `pt-PT`, `pt-BR`, `es`, and `fr`. The prompt asks
for one paragraph with no more than 35 words. The Flutter client uses a local
fallback when the Worker cannot respond.

## Deploy

```bash
npx wrangler login
npm run deploy
```

The Flutter URL is configured in `lib/config/app_config.dart`. For temporary
overrides, run Flutter with:

```bash
flutter run --dart-define=CLOUDFLARE_WORKER_URL=https://roast-rizz-api.rusobrg.workers.dev/roast
```

See `../docs/deployment.md` for the full deployment and release checklist.
