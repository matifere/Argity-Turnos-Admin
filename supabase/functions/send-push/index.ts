import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

// Envía push a los dispositivos móviles de un usuario vía FCM HTTP v1.
//
// No es invocable por usuarios: la protege un secreto compartido
// (PUSH_WEBHOOK_SECRET) que pasa el trigger de la tabla notifications.
// Se despliega con --no-verify-jwt; la autorización la hace el secreto.

interface ServiceAccount {
  project_id: string;
  client_email: string;
  private_key: string;
  token_uri: string;
}

// ── PEM (PKCS8) → CryptoKey para firmar RS256 ──────────────────────────────
function pemToArrayBuffer(pem: string): ArrayBuffer {
  const b64 = pem
    .replace('-----BEGIN PRIVATE KEY-----', '')
    .replace('-----END PRIVATE KEY-----', '')
    .replace(/\s/g, '');
  const bin = atob(b64);
  const buf = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) buf[i] = bin.charCodeAt(i);
  return buf.buffer;
}

function b64url(data: Uint8Array | string): string {
  const bytes = typeof data === 'string'
    ? new TextEncoder().encode(data)
    : data;
  let str = '';
  for (const b of bytes) str += String.fromCharCode(b);
  return btoa(str).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

// Cachea el access token mientras esté vigente (válido ~1h).
let cachedToken: { token: string; exp: number } | null = null;

async function getAccessToken(sa: ServiceAccount): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  if (cachedToken && cachedToken.exp > now + 60) return cachedToken.token;

  const header = { alg: 'RS256', typ: 'JWT' };
  const claims = {
    iss: sa.client_email,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
    aud: sa.token_uri,
    iat: now,
    exp: now + 3600,
  };
  const unsigned = `${b64url(JSON.stringify(header))}.${b64url(JSON.stringify(claims))}`;

  const key = await crypto.subtle.importKey(
    'pkcs8',
    pemToArrayBuffer(sa.private_key),
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  const sig = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    key,
    new TextEncoder().encode(unsigned),
  );
  const jwt = `${unsigned}.${b64url(new Uint8Array(sig))}`;

  const res = await fetch(sa.token_uri, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=${jwt}`,
  });
  const json = await res.json();
  if (!json.access_token) {
    throw new Error('FCM token error: ' + JSON.stringify(json));
  }
  cachedToken = { token: json.access_token, exp: now + 3600 };
  return json.access_token;
}

Deno.serve(async (req) => {
  try {
    // Autorización por secreto compartido (no JWT de usuario).
    const secret = req.headers.get('x-webhook-secret');
    if (!secret || secret !== Deno.env.get('PUSH_WEBHOOK_SECRET')) {
      return new Response(JSON.stringify({ error: 'unauthorized' }), { status: 401 });
    }

    const { user_id, title, body, data } = await req.json();
    if (!user_id || !title || !body) {
      return new Response(JSON.stringify({ error: 'missing user_id/title/body' }), { status: 400 });
    }

    const sa: ServiceAccount = JSON.parse(Deno.env.get('FCM_SERVICE_ACCOUNT')!);

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    );

    const { data: tokens } = await supabase
      .from('mobile_push_tokens')
      .select('token')
      .eq('user_id', user_id);

    if (!tokens || tokens.length === 0) {
      return new Response(JSON.stringify({ sent: 0, reason: 'no tokens' }), { status: 200 });
    }

    const accessToken = await getAccessToken(sa);
    const endpoint = `https://fcm.googleapis.com/v1/projects/${sa.project_id}/messages:send`;

    // FCM v1 sólo acepta data con valores string.
    const stringData: Record<string, string> = {};
    if (data && typeof data === 'object') {
      for (const [k, v] of Object.entries(data)) stringData[k] = String(v);
    }

    let sent = 0;
    const staleTokens: string[] = [];

    await Promise.all(tokens.map(async ({ token }) => {
      const res = await fetch(endpoint, {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${accessToken}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          message: {
            token,
            notification: { title, body },
            data: stringData,
            android: { priority: 'high' },
            apns: { payload: { aps: { sound: 'default' } } },
          },
        }),
      });
      if (res.ok) {
        sent++;
      } else {
        // Token muerto (app desinstalada / token rotado) → limpiarlo.
        if (res.status === 404 || res.status === 400) staleTokens.push(token);
        console.error('FCM send error', res.status, await res.text());
      }
    }));

    if (staleTokens.length > 0) {
      await supabase.from('mobile_push_tokens').delete().in('token', staleTokens);
    }

    return new Response(JSON.stringify({ sent, total: tokens.length }), {
      status: 200, headers: { 'Content-Type': 'application/json' },
    });

  } catch (e) {
    console.error(e);
    return new Response(JSON.stringify({ error: String(e) }), { status: 500 });
  }
});
