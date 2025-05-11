// supabase/functions/sendFcm.ts
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { decode, encode } from "https://deno.land/std@0.168.0/encoding/base64.ts";

// 1) Supabase 클라이언트
const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
);


// 2) 서비스 계정 키 파싱
const serviceAccountJson = JSON.parse(
  Deno.env.get("FCM_SERVICE_ACCOUNT_KEY")!
);
const FCM_PROJECT_ID = serviceAccountJson.project_id;
const CLIENT_EMAIL = serviceAccountJson.client_email;
const PRIVATE_KEY = serviceAccountJson.private_key;

/** JWT 기반 OAuth2 Access Token 발급 함수 */
async function getAccessToken(): Promise<string> {
  const header = { alg: "RS256", typ: "JWT" };
  const iat = Math.floor(Date.now() / 1000);
  const exp = iat + 3600;

  // JWT ClaimSet
  const claimSet = {
    iss: CLIENT_EMAIL,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    iat,
    exp,
  };

  // JWT 직렬화
  const toSign = [
    encode(JSON.stringify(header)),
    encode(JSON.stringify(claimSet)),
  ].join(".");

  // PEM → DER 디코딩
  const pemLines = PRIVATE_KEY.split(/\r?\n/);
  const b64 = pemLines
    .filter((l) => l && !l.startsWith("-----"))
    .join("");
  const der = decode(b64);

  // RS256 키 임포트
  const cryptoKey = await crypto.subtle.importKey(
    "pkcs8",
    der,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );

  // 서명 생성
  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    cryptoKey,
    new TextEncoder().encode(toSign),
  );
  const jwt = `${toSign}.${encode(new Uint8Array(signature))}`;

  // OAuth2 토큰 요청
  console.log(">>> FCM client_email:", CLIENT_EMAIL);
  const resp = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });
  const data = await resp.json();
  console.log("OAuth 응답 상태:", resp.status, resp.statusText);
  if (!resp.ok) {
    console.error("OAuth 오류:", data);
  }
  return data.access_token;
}

serve(async (req) => {
  try {
    // Accept either a single object or an array of notification requests
    const payload = await req.json();
    const items = Array.isArray(payload) ? payload : [payload];
    const aggregateResults: Array<any> = [];

    for (const item of items) {
      const { userId, title, body, notiId, action, data } = item;
      if (!notiId) {
        aggregateResults.push({ notiId, error: 'notiId is required' });
        continue;
      }

      // 1) Fetch FCM tokens
      const { data: userRecord, error: fetchErr } = await supabase
        .from("users")
        .select("fcm_tokens")
        .eq("id", userId)
        .single();
      if (fetchErr || !userRecord.fcm_tokens?.length) {
        console.log(`sendFcm: no FCM tokens for userId=${userId}, notiId=${notiId}`);
        // mark as sent to avoid retries
        await supabase
          .from('notifications')
          .update({ sent: true })
          .eq('id', notiId);
        aggregateResults.push({ notiId, error: '등록된 FCM 토큰이 없습니다.' });
        continue;
      }

      // 2) Obtain OAuth2 access token
      const accessToken = await getAccessToken();

      // 3) Send to each token
      const sendResults: Array<any> = [];
      for (const token of userRecord.fcm_tokens as string[]) {
        const res = await fetch(
          `https://fcm.googleapis.com/v1/projects/${FCM_PROJECT_ID}/messages:send`,
          {
            method: "POST",
            headers: {
              Authorization: `Bearer ${accessToken}`,
              "Content-Type": "application/json",
            },
            body: JSON.stringify({
              message: {
                token,
                notification: { title, body },
                data: {
                  action,
                  ...(data || {}),
                },
              },
            }),
          },
        );
        const json = await res.json();
        sendResults.push({ token, ok: res.ok, response: json });
      }

      // 4) Mark notification record as sent
      await supabase
        .from('notifications')
        .update({ sent: true })
        .eq('id', item.notiId);

      aggregateResults.push({ notiId, results: sendResults });
    }

    // Return aggregated results
    return new Response(JSON.stringify({ results: aggregateResults }), {
      status: 200,
      headers: { 'Content-Type': 'application/json' },
    });
  } catch (e) {
    console.error(e);
    return new Response(JSON.stringify({ error: e.message || e.toString() }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' },
    });
  }
});