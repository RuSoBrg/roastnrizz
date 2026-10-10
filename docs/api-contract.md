# API Contract

The Flutter client sends a `POST` request to the Cloudflare Worker `/roast`
endpoint with `Content-Type: application/json`.

## Request

```json
{
  "photoBase64": "...",
  "language": "en",
  "persona": "Gordon Ramsay",
  "isRizz": false,
  "mode": "Roast"
}
```

`photoBase64` and `persona` are required. Supported languages are `en`,
`pt-PT`, `pt-BR`, `es`, and `fr`. `isRizz` is required and determines the
mode; `mode` is descriptive metadata sent by the client.

The Worker accepts request bodies up to 9 MB and persona values up to 80
characters. The Flutter image picker limits images to 6 MB before encoding.

## Success

```json
{ "result": "Generated response" }
```

The Worker asks Azure OpenAI for one paragraph with no more than 35 words. The
client reads `result` through `GetRoastCall.roastText()`.

## Errors

Errors use this shape:

```json
{ "error": "Description" }
```

Common statuses are `400` for invalid input, `413` for an oversized request,
`415` for the wrong content type, `502` for an upstream failure, and `503` when
Azure credentials are not configured. The Flutter client shows a generic error
and uses a local result fallback when the request fails.
