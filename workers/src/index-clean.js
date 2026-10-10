const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type",
};

const USER_ID_PATTERN = /^[A-Za-z0-9_-]{20,128}$/;

export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);

    if (request.method === "OPTIONS") {
      return new Response(null, { headers: corsHeaders });
    }

    // 1. ROTA ADMOB SSV - GET/POST /ssv ou /callback
    if ((request.method === "GET" || request.method === "POST") && (url.pathname === "/ssv" || url.pathname === "/callback")) {
      return await handleAdMobSsv(request, env);
    }

    // 2. ROTA POST DA APP - POST /
    if (request.method === "POST") {
      try {
        const data = await request.json();
        const { persona, isRizz, language, photoBase64, userId } = data;

        if (!userId || !USER_ID_PATTERN.test(userId)) {
          return new Response(JSON.stringify({ error: "Invalid userId" }), {
            status: 400,
            headers: { "Content-Type": "application/json", ...corsHeaders }
          });
        }

        let saldo = await env.KV_CREDITS.get(userId);
        saldo = saldo ? Number.parseInt(saldo) : 3;

        if (saldo <= 0) {
          return new Response(JSON.stringify({ error: "INSUFFICIENT_CREDITS" }), {
            status: 403,
            headers: { "Content-Type": "application/json", ...corsHeaders }
          });
        }

        await env.KV_CREDITS.put(userId, (saldo - 1).toString());

        const mode = isRizz
          ? "Rizz (smooth, charming, clever, playful flirting or compliments)"
          : "Roast (funny, witty, brutal and sarcastic criticism)";

        const langInstruction = language && language.trim() !== ""
          ? `The final response MUST be written strictly in this language: ${language}.`
          : `Automatically detect the source language of the persona, search for the persona and use the origin language used by the persona, and output the response in that exact same language.`;

        const systemPrompt = `You are an expert actor and roleplayer. 
        You must fully adopt the following persona and embody its voice, tone, and traits: "${persona}".
        Your goal is to generate a ${mode}.
        ${langInstruction}
        Make sure the text has strong, easily identifiable characteristics of this chosen persona, search online for most recognized words or expressions. Use things that are clearly visible on the image and use it on the text. Do not break character.`;

        const userContent = [
          { type: "text", text: `Analyze the provided image and generate a creative ${mode} following the persona traits and use less than 50 words on the response.` }
        ];

        if (photoBase64) {
          userContent.push({
            type: "image_url",
            image_url: {
              url: `data:image/jpeg;base64,${photoBase64}`
            }
          });
        }

        const azureResponse = await fetch(`${env.AZURE_ENDPOINT}/openai/deployments/${env.AZURE_DEPLOYMENT}/chat/completions?api-version=2024-02-15-preview`, {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            "api-key": env.AZURE_API_KEY
          },
          body: JSON.stringify({
            messages: [
              { role: "system", content: systemPrompt },
              { role: "user", content: userContent }
            ],
            max_tokens: 600,
            temperature: 0.9
          })
        });

        const result = await azureResponse.json();

        if (!azureResponse.ok) {
          await env.KV_CREDITS.put(userId, (saldo).toString());
          return new Response(JSON.stringify({ error: result }), {
            status: 500,
            headers: { "Content-Type": "application/json", ...corsHeaders }
          });
        }

        const outputText = result.choices[0].message.content;
        return new Response(JSON.stringify({ result: outputText, credits: saldo - 1 }), {
          headers: { "Content-Type": "application/json", ...corsHeaders }
        });

      } catch (err) {
        console.error("Worker error:", err);
        return new Response(JSON.stringify({ error: "Internal Server Error" }), {
          status: 500,
          headers: { "Content-Type": "application/json", ...corsHeaders }
        });
      }
    }

    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405,
      headers: { "Content-Type": "application/json", ...corsHeaders }
    });
  }
};

async function handleAdMobSsv(request, env) {
  try {
    const url = new URL(request.url);
    const { params, fullQueryString } = await parseSsvParams(request, url);

    const userId = params.get("custom_data");
    const transactionId = params.get("transaction_id");
    const keyId = params.get("key_id");
    const signature = params.get("signature");

    if (!userId && !transactionId && !keyId && !signature) {
      return new Response("OK", { status: 200 });
    }

    if (!userId || !transactionId || !keyId || !signature) {
      return new Response("Missing parameters", { status: 400 });
    }

    const isValid = await verifyAdMobSignature(fullQueryString, signature, keyId);
    if (!isValid) {
      return new Response("Invalid signature", { status: 403 });
    }

    const txExists = await env.KV_CREDITS.get(`tx_${transactionId}`);
    if (txExists) return new Response("OK", { status: 200 });

    await env.KV_CREDITS.put(`tx_${transactionId}`, "1", { expirationTtl: 86400 * 30 });

    let saldoAtual = await env.KV_CREDITS.get(userId);
    saldoAtual = saldoAtual ? Number.parseInt(saldoAtual) : 0;
    await env.KV_CREDITS.put(userId, (saldoAtual + 3).toString());

    return new Response("OK", { status: 200, headers: corsHeaders });
  } catch (error) {
    console.error("SSV Error:", error);
    return new Response("Internal Error", { status: 500 });
  }
}

async function parseSsvParams(request, url) {
  let params = url.searchParams;
  let fullQueryString = url.search.substring(1);

  if (request.method === "POST") {
    const contentType = request.headers.get("content-type") || "";
    if (contentType.includes("application/x-www-form-urlencoded")) {
      fullQueryString = await request.text();
      params = new URLSearchParams(fullQueryString);
    }
  }
  return { params, fullQueryString };
}

async function verifyAdMobSignature(fullQueryString, signature, keyId) {
  try {
    const keysRes = await fetch("https://www.gstatic.com/admob/reward/verifier-keys.json");
    const { keys } = await keysRes.json();
    const keyObj = keys.find(k => k.keyId === keyId);
    if (!keyObj) return false;

    const messageToVerify = fullQueryString
      .split("&")
      .filter(part => !part.startsWith("signature="))
      .join("&");

    const signatureBytes = Uint8Array.from(atob(signature.replaceAll('-', "+").replaceAll('_', "/")), c => c.codePointAt(0));
    const pemContent = keyObj.pem.replace(/-----BEGIN PUBLIC KEY-----|-----END PUBLIC KEY-----|\n/g, "");
    const keyBytes = Uint8Array.from(atob(pemContent), c => c.codePointAt(0));

    const cryptoKey = await crypto.subtle.importKey(
      "spki",
      keyBytes,
      { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
      false,
      ["verify"]
    );

    return await crypto.subtle.verify(
      "RSASSA-PKCS1-v1_5",
      cryptoKey,
      signatureBytes,
      new TextEncoder().encode(messageToVerify)
    );
  } catch (err) {
    console.error("Crypto verification failed:", err);
    return false;
  }
}
