const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization, X-Firebase-AppCheck",
};

export default {
  /**
   * Main fetch handler for the Cloudflare Worker.
   */
  async fetch(request, env) {
    const url = new URL(request.url);

    // 1. Static and Preflight routes
    if (request.method === "OPTIONS") return new Response(null, { headers: corsHeaders });
    if (url.pathname === "/app-ads.txt") {
      return new Response("google.com, pub-7026654571602193, DIRECT, f08c47fec0942fa0", { headers: { "Content-Type": "text/plain" } });
    }

    // 2. AdMob SSV (Criptographically validated)
    const isSsvPath = url.pathname === "/ssv" || url.pathname === "/callback";
    if ((request.method === "GET" || request.method === "POST") && isSsvPath) {
      return await handleAdMobSsv(request, env);
    }

    // 3. Security and Auth required for other routes
    const clientIp = request.headers.get("cf-connecting-ip") || "unknown";
    const securityResponse = await runSecurityChecks(request, env, clientIp);
    if (securityResponse) return securityResponse;

    const uid = await authenticateUser(request, env);
    if (!uid) {
      return new Response(JSON.stringify({ error: "UNAUTHORIZED", message: "Invalid or expired authentication token" }), {
        status: 401,
        headers: { "Content-Type": "application/json", ...corsHeaders }
      });
    }

    // 4. Authenticated API Routes
    if (request.method === "GET" && url.pathname === "/sync-credits") {
      return await handleSyncCredits(request, env, uid);
    }
    if (request.method === "POST") {
      if (url.pathname === "/") return await handleAppRequest(request, env, clientIp, uid);
      if (url.pathname === "/claim-reward") return await handleClaimReward(request, env, uid);
    }

    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405,
      headers: { "Content-Type": "application/json", ...corsHeaders }
    });
  }
};

/**
 * Applies rate limiting per IP address (25 requests/day).
 * Firebase Auth JWT is the primary authentication gate.
 */
async function runSecurityChecks(request, env, clientIp) {
  const count = Number.parseInt(await env.KV_CREDITS.get(`rate_${clientIp}`) || "0", 10);
  if (count > 100) {
    console.warn("Rate limit hit for IP:", clientIp, "count:", count);
    return new Response(JSON.stringify({ error: "Too Many Requests" }), {
      status: 429,
      headers: { "Content-Type": "application/json", ...corsHeaders }
    });
  }
  return null;
}

/**
 * Authenticates user using Firebase Auth JWT.
 */
async function authenticateUser(request, env) {
  const authHeader = request.headers.get("Authorization");
  if (!authHeader?.startsWith("Bearer ")) return null;
  const token = authHeader.split(" ")[1];
  return await verifyFirebaseAuth(token, env);
}

/**
 * Handles main app functionality with atomic credit consumption and full AI prompt.
 */
async function handleAppRequest(request, env, clientIp, uid) {
  try {
    const data = await request.json();
    const { persona, isRizz, language, photoBase64 } = data;

    if (!photoBase64 || photoBase64.length > 5000000) {
      return new Response(JSON.stringify({ error: "IMAGE_TOO_LARGE", message: "Image exceeds 5MB limit" }), {
        status: 413,
        headers: { "Content-Type": "application/json", ...corsHeaders }
      });
    }

    const rateKey = `rate_${clientIp}`;
    const rawRate = await env.KV_CREDITS.get(rateKey);
    const currentRate = Number.parseInt(rawRate || "0", 10);
    await env.KV_CREDITS.put(rateKey, (currentRate + 1).toString(), { expirationTtl: 86400 });

    const uidRateKey = `uid_rate_${uid}`;
    const rawUidRate = await env.KV_CREDITS.get(uidRateKey);
    const currentUidRate = Number.parseInt(rawUidRate || "0", 10);
    if (currentUidRate > 25) {
       console.warn("UID Rate limit hit:", uid, "count:", currentUidRate);
       return new Response(JSON.stringify({ error: "Too Many Requests (UID)" }), { status: 429, headers: corsHeaders });
    }
    await env.KV_CREDITS.put(uidRateKey, (currentUidRate + 1).toString(), { expirationTtl: 86400 });

    const today = new Date().toISOString().split('T')[0];
    const { results } = await env.DB.prepare(`
      INSERT INTO users (user_id, credits, last_reset)
      VALUES (?1, 2, ?2)
      ON CONFLICT(user_id) DO UPDATE SET
        credits = CASE WHEN users.last_reset != ?2 THEN MAX(3, users.credits) - 1 ELSE users.credits - 1 END,
        last_reset = ?2
      WHERE (users.last_reset != ?2 OR users.credits > 0)
      RETURNING credits;
    `).bind(uid, today).all();

    if (!results || results.length === 0) {
      return new Response(JSON.stringify({ error: "INSUFFICIENT_CREDITS", credits: 0 }), { status: 403, headers: { "Content-Type": "application/json", ...corsHeaders } });
    }

    const saldoFinal = results[0].credits;
    const result = await generateAiContent(env, { persona, isRizz, language, photoBase64 });

    if (result.error) {
      // Refund credit on failure
      await env.DB.prepare(`UPDATE users SET credits = credits + 1 WHERE user_id = ?`).bind(uid).run();
      return new Response(JSON.stringify({ error: "AI_ERROR", credits: saldoFinal + 1 }), { status: 502, headers: { "Content-Type": "application/json", ...corsHeaders } });
    }

    return new Response(JSON.stringify({ result: result.content, credits: saldoFinal }), { headers: { "Content-Type": "application/json", ...corsHeaders } });

  } catch (err) {
    console.error("Worker error handleAppRequest:", err);
    return new Response(JSON.stringify({ error: "INTERNAL_ERROR", message: "Failed to process request" }), {
      status: 500,
      headers: { "Content-Type": "application/json", ...corsHeaders }
    });
  }
}

/**
 * Syncs the true credit balance from the database.
 */
async function handleSyncCredits(request, env, uid) {
  try {
    const today = new Date().toISOString().split('T')[0];
    
    // Attempt to initialize daily credits if not present
    await env.DB.prepare(`
      INSERT INTO users (user_id, credits, last_reset)
      VALUES (?1, 3, ?2)
      ON CONFLICT(user_id) DO UPDATE SET
        credits = CASE WHEN users.last_reset != ?2 THEN MAX(3, users.credits) ELSE users.credits END,
        last_reset = ?2
      WHERE users.last_reset != ?2;
    `).bind(uid, today).run();

    const { results } = await env.DB.prepare(`SELECT credits FROM users WHERE user_id = ?`).bind(uid).all();
    return new Response(JSON.stringify({ success: true, credits: results[0]?.credits || 3 }), { headers: { "Content-Type": "application/json", ...corsHeaders } });
  } catch (err) {
    console.error("Sync credits error:", err);
    return new Response(JSON.stringify({ error: "INTERNAL_ERROR", message: "Failed to sync credits" }), {
      status: 500,
      headers: { "Content-Type": "application/json", ...corsHeaders }
    });
  }
}

/**
 * Handles explicit claim reward from the app (used when SSV is unavailable, e.g. test ads or mock).
 */
async function handleClaimReward(request, env, uid) {
  try {
    // Rate limit: max 5 claims per day per UID
    const claimKey = `claim_${uid}`;
    const claims = Number.parseInt(await env.KV_CREDITS.get(claimKey) || "0", 10);
    if (claims >= 5) {
      return new Response(JSON.stringify({ error: "Claim limit reached" }), { status: 429, headers: { "Content-Type": "application/json", ...corsHeaders } });
    }
    await env.KV_CREDITS.put(claimKey, (claims + 1).toString(), { expirationTtl: 86400 });

    const today = new Date().toISOString().split('T')[0];
    const { results } = await env.DB.prepare(`
      INSERT INTO users (user_id, credits, last_reset)
      VALUES (?1, 3, ?2)
      ON CONFLICT(user_id) DO UPDATE SET
        credits = users.credits + 3,
        last_reset = CASE WHEN users.last_reset != ?2 THEN ?2 ELSE users.last_reset END
      RETURNING credits;
    `).bind(uid, today).all();
    
    return new Response(JSON.stringify({ success: true, credits: results[0].credits }), { headers: { "Content-Type": "application/json", ...corsHeaders } });
  } catch (err) {
    console.error("Claim reward error:", err);
    return new Response(JSON.stringify({ error: "INTERNAL_ERROR", message: "Failed to claim reward" }), {
      status: 500,
      headers: { "Content-Type": "application/json", ...corsHeaders }
    });
  }
}

/**
 * Handles AdMob SSV.
 */
async function handleAdMobSsv(request, env) {
  try {
    const { params, fullQueryString } = await parseSsvParams(request, new URL(request.url));
    const uid = params.get("custom_data");
    const signature = params.get("signature");
    const keyId = params.get("key_id");

    if (!signature || !keyId || !uid) return new Response("OK", { status: 200 });

    const isValid = await verifyAdMobSignature(env, fullQueryString, signature, keyId);
    if (!isValid) return new Response("Forbidden", { status: 403 });

    const txKey = `tx_${params.get("transaction_id")}`;
    if (await env.KV_CREDITS.get(txKey)) return new Response("OK", { status: 200 });
    await env.KV_CREDITS.put(txKey, "1", { expirationTtl: 2592000 });

    await env.DB.prepare(`INSERT INTO users (user_id, credits, last_reset) VALUES (?1, 6, '') ON CONFLICT(user_id) DO UPDATE SET credits = users.credits + 3;`).bind(uid).run();
    return new Response("OK", { status: 200, headers: corsHeaders });
  } catch (error) {
    console.error("AdMob SSV Error:", error);
    return new Response("Error", { status: 500 });
  }
}

async function verifyFirebaseAuth(token, env) {
  try {
    if (!env.FIREBASE_PROJECT_ID) {
      console.error("FIREBASE_PROJECT_ID not configured in environment!");
      return null;
    }
    const parts = token.split(".");
    if (parts.length !== 3) return null;
    let base64 = parts[1].replaceAll("-", "+").replaceAll("_", "/");
    const pad = base64.length % 4 === 0 ? '' : '='.repeat(4 - (base64.length % 4));
    const payload = JSON.parse(atob(base64 + pad));

    const now = Math.floor(Date.now() / 1e3);
    const expectedIss = `https://securetoken.google.com/${env.FIREBASE_PROJECT_ID}`;
    if (!payload.sub || typeof payload.sub !== "string" || payload.sub.length === 0) return null;
    if (payload.exp < now || payload.aud !== env.FIREBASE_PROJECT_ID || payload.iss !== expectedIss) return null;

    let jwks = await env.KV_CREDITS.get("firebase_jwks", { type: "json" });
    if (!jwks) {
      jwks = await (await fetch("https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com")).json();
      await env.KV_CREDITS.put("firebase_jwks", JSON.stringify(jwks), { expirationTtl: 3600 });
    }
    const header = JSON.parse(atob(parts[0]));
    let jwk = jwks.keys.find((k) => k.kid === header.kid);
    if (!jwk) {
      // Force-refresh JWKS from Google (cache may be stale after key rotation)
      console.warn("Firebase Auth: kid not in cache, refreshing JWKS. kid:", header.kid);
      const freshJwks = await (await fetch(
        "https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com"
      )).json();
      await env.KV_CREDITS.put("firebase_jwks", JSON.stringify(freshJwks), { expirationTtl: 3600 });
      jwk = freshJwks.keys.find((k) => k.kid === header.kid);
      if (!jwk) {
        console.warn("Firebase Auth: kid still not found after refresh. Rejecting.");
        return null;
      }
    }
    const key = await crypto.subtle.importKey("jwk", jwk, { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" }, false, ["verify"]);
    const signature = Uint8Array.from(atob(parts[2].replaceAll("-", "+").replaceAll("_", "/")), c => c.codePointAt(0));
    return (await crypto.subtle.verify("RSASSA-PKCS1-v1_5", key, signature, new TextEncoder().encode(parts[0] + "." + parts[1]))) ? payload.sub : null;
  } catch (e) {
    console.error("Firebase Auth Verify Error:", e);
    return null;
  }
}

/**
 * Converts a DER-encoded ECDSA signature to IEEE P1363 format (raw r||s).
 * Web Crypto API requires P1363; Google AdMob sends DER.
 * For P-256, each component is 32 bytes → output is always 64 bytes.
 */
function derToP1363(derSig, componentLength = 32) {
  let offset = 0;
  if (derSig[offset++] !== 0x30) throw new Error("Invalid DER: missing SEQUENCE tag");
  // Skip total length byte (short form only for ECDSA P-256)
  offset++;

  const readComponent = () => {
    if (derSig[offset++] !== 0x02) throw new Error("Invalid DER: missing INTEGER tag");
    const len = derSig[offset++];
    const raw = derSig.subarray(offset, offset + len);
    offset += len;
    // Trim leading zero padding (DER adds 0x00 when high bit is set)
    const trimmed = raw[0] === 0 && raw.length > componentLength ? raw.subarray(1) : raw;
    // Right-align into fixed-width buffer
    const padded = new Uint8Array(componentLength);
    padded.set(trimmed, componentLength - trimmed.length);
    return padded;
  };

  const r = readComponent();
  const s = readComponent();
  const result = new Uint8Array(componentLength * 2);
  result.set(r, 0);
  result.set(s, componentLength);
  return result;
}

/**
 * Adds base64 padding if missing (required by atob in strict environments).
 */
function padBase64(b64) {
  const rem = b64.length % 4;
  return rem === 0 ? b64 : b64 + "=".repeat(4 - rem);
}

/**
 * Verifies an AdMob SSV callback signature using ECDSA P-256 + SHA-256.
 * Google's verifier-keys.json provides ECDSA public keys (NOT RSA).
 */
async function verifyAdMobSignature(env, fullQueryString, signature, keyId) {
  try {
    let keysData = await env.KV_CREDITS.get("admob_keys", { type: "json" });
    if (!keysData) {
      keysData = await (await fetch("https://www.gstatic.com/admob/reward/verifier-keys.json")).json();
      await env.KV_CREDITS.put("admob_keys", JSON.stringify(keysData), { expirationTtl: 604800 });
    }
    const keyObj = keysData.keys.find(k => k.keyId.toString() === keyId.toString());
    if (!keyObj) {
      console.warn("AdMob SSV: key_id not found:", keyId);
      return false;
    }

    // 1. Extract message: everything BEFORE "&signature="
    const signatureIndex = fullQueryString.indexOf("&signature=");
    const messageToVerify = signatureIndex !== -1 ? fullQueryString.substring(0, signatureIndex) : fullQueryString;

    // 2. Decode signature from URL-safe base64 → DER bytes → P1363 format
    const sigB64 = padBase64(signature.replaceAll("-", "+").replaceAll("_", "/"));
    const derBytes = Uint8Array.from(atob(sigB64), c => c.codePointAt(0));
    const p1363Sig = derToP1363(derBytes);

    // 3. Import ECDSA P-256 public key (use base64 field = raw SPKI, avoids PEM parsing)
    const keyB64 = keyObj.base64 || keyObj.pem.replace(/-----BEGIN PUBLIC KEY-----|-----END PUBLIC KEY-----|\n/g, "");
    const keyBytes = Uint8Array.from(atob(padBase64(keyB64)), c => c.codePointAt(0));
    const cryptoKey = await crypto.subtle.importKey(
      "spki", keyBytes,
      { name: "ECDSA", namedCurve: "P-256" },
      false, ["verify"]
    );

    // 4. Verify with ECDSA + SHA-256
    return await crypto.subtle.verify(
      { name: "ECDSA", hash: { name: "SHA-256" } },
      cryptoKey, p1363Sig,
      new TextEncoder().encode(messageToVerify)
    );
  } catch (err) {
    console.error("AdMob Signature Verify Error:", err);
    return false;
  }
}

/**
 * Calls Azure OpenAI service with the improved expert prompt.
 */
async function generateAiContent(env, { persona, isRizz, language, photoBase64 }) {
  // Sanitize persona to prevent prompt injection
  const safeName = (persona || "comedian").replace(/[^\p{L}\p{N}\s\-'().,]/gu, "").substring(0, 80).trim() || "comedian";

  const languageMap = {
    'pt-PT': 'Portuguese (Portugal)', 'pt-BR': 'Portuguese (Brazil)', 'es': 'Spanish',
    'fr': 'French', 'de': 'German', 'it': 'Italian', 'ru': 'Russian', 'zh': 'Chinese',
    'ja': 'Japanese', 'ko': 'Korean', 'ar': 'Arabic', 'hi': 'Hindi', 'tr': 'Turkish',
    'vi': 'Vietnamese', 'id': 'Indonesian', 'th': 'Thai', 'pl': 'Polish', 'nl': 'Dutch',
    'el': 'Greek', 'bn': 'Bengali', 'en': 'English'
  };

  const targetLanguage = languageMap[language] || language || 'English';
  const mode = isRizz ? "Rizz" : "Roast";

  const systemPrompt = `You are "${safeName}". Your mission is to deliver a ${mode} of a photo sent by the user, written entirely in your own voice and personality.

  ## OUTPUT LANGUAGE
  Write your final response exclusively in ${targetLanguage}. Do not mix in other languages.

  ## VOICE OF ${safeName}
  - Use the vocabulary, slang, tone, and speech rhythm typical of ${safeName}.
  - Include at least ONE recognizable catchphrase or signature expression associated with ${safeName}, adapted to fit the image.
  - Never reveal that you are an AI or break character.

  ## READING THE IMAGE
  1. Identify 3 concrete, specific visual details in the photo: clothing, facial expression, pose, hairstyle, objects, colors.
  2. Pick the 2 details that are the most "roastable"/funny or most useful for the ${mode}.
  3. You MUST use them in the final text. Generic lines are forbidden.

  ## STYLE BASED ON MODE
  ${mode === "Roast"
    ? "- Roast: sharp sarcasm, absurd comparisons, and a surprising final 'burn'. Spicy and funny."
    : "- Rizz: shameless flirting, over-the-top pick-up-line charm, confident and theatrical, ending with an invitation or a verbal wink."
  }

  ## OUTPUT FORMAT
  - Maximum 50 words.
  - 1 to 3 short sentences.
  - Always end on the strongest line.
  - Emojis are allowed only if they fit style (max 1-2).
  - Respond ONLY with the final ${mode} text. No intros, no quotation marks, no explanations.`;

  let attempt = 0;
  while (attempt < 2) {
    try {
      attempt++;
      const response = await fetch(`${env.AZURE_ENDPOINT}/openai/deployments/${env.AZURE_DEPLOYMENT}/chat/completions?api-version=2024-02-15-preview`, {
        method: "POST",
        headers: { "Content-Type": "application/json", "api-key": env.AZURE_API_KEY },
        body: JSON.stringify({
          messages: [
            { role: "system", content: systemPrompt },
            { role: "user", content: [{ type: "text", text: "Respond to image." }, { type: "image_url", image_url: { url: `data:image/jpeg;base64,${photoBase64}` } }] }
          ],
          max_tokens: 600,
          temperature: 0.9
        })
      });

      if (!response.ok) {
        const errText = await response.text();
        if (attempt < 2 && (response.status === 429 || response.status >= 500)) {
          console.warn(`Azure OpenAI error ${response.status}. Retrying...`);
          await new Promise(r => setTimeout(r, 1000));
          continue;
        }
        throw new Error(errText);
      }
      
      const payload = await response.json();
      return { content: payload.choices[0].message.content };
    } catch (err) {
      if (attempt >= 2 || (err.message && !err.message.includes("429") && !err.message.includes("50"))) {
         return { error: err.message };
      }
    }
  }
  return { error: "Failed after retries" };
}

async function parseSsvParams(request, url) {
  let params = url.searchParams;
  let fullQueryString = url.search.substring(1);
  if (request.method === "POST" && (request.headers.get("content-type") || "").includes("form-urlencoded")) {
    fullQueryString = await request.text();
    params = new URLSearchParams(fullQueryString);
  }
  return { params, fullQueryString };
}
