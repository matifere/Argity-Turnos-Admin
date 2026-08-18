import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const url = new URL(req.url);
    const code = url.searchParams.get("code");
    const errorParam = url.searchParams.get("error");
    let state = url.searchParams.get('state');

    // 4. Determinar a dónde redirigir al usuario final
    let redirectUrl = 'argity://login-callback'; 
    
    if (state) {
      if (state.startsWith('b64:')) {
        try {
          const encodedStr = state.substring(4);
          // Standard JS atob with URI safe base64
          const decodedStr = atob(encodedStr.replace(/-/g, '+').replace(/_/g, '/'));
          redirectUrl = decodedStr;
        } catch (e) {
          console.error("Error decoding state:", e);
        }
      } else if (state.startsWith('http')) {
        redirectUrl = state;
      } else if (state.startsWith('port:')) {
        const port = state.split(':')[1];
        redirectUrl = `http://127.0.0.1:${port}`;
      } else if (state === 'web') {
        // Asumiendo un origin por defecto si pasamos state=web
      }
    }

    if (errorParam) {
      throw new Error(`Error de Mercado Pago: ${errorParam}`);
    }

    if (!code) {
      throw new Error("No se proporcionó el código de autorización");
    }

    const MP_CLIENT_ID = Deno.env.get("MP_CLIENT_ID");
    const MP_CLIENT_SECRET = Deno.env.get("MP_CLIENT_SECRET") || Deno.env.get("MP_ACCESS_TOKEN");
    const SUPABASE_URL = Deno.env.get("SUPABASE_URL");
    const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

    const missingVars = [];
    if (!MP_CLIENT_ID) missingVars.push("MP_CLIENT_ID");
    if (!MP_CLIENT_SECRET) missingVars.push("MP_CLIENT_SECRET (or MP_ACCESS_TOKEN)");
    if (!SUPABASE_URL) missingVars.push("SUPABASE_URL");
    if (!SUPABASE_SERVICE_ROLE_KEY) missingVars.push("SUPABASE_SERVICE_ROLE_KEY");

    if (missingVars.length > 0) {
      return errorHtml(`Variables de entorno incompletas: faltan ${missingVars.join(', ')}`, 500);
    }

    // 1. Obtener Access Token de Mercado Pago
    // Kong proxy puede modificar req.url, así que usamos headers o SUPABASE_PUBLIC_URL para reconstruir la URL original
    let publicUrl = Deno.env.get("SUPABASE_PUBLIC_URL");
    if (!publicUrl) {
      const forwardedHost = req.headers.get("x-forwarded-host");
      const forwardedProto = req.headers.get("x-forwarded-proto") || "https";
      if (forwardedHost) {
        publicUrl = `${forwardedProto}://${forwardedHost}`;
      } else {
        const reqUrl = new URL(req.url);
        publicUrl = `${reqUrl.protocol}//${reqUrl.host}`;
      }
    }
    const redirectUri = `${publicUrl}/functions/v1/mp-auth-callback`;

    const tokenResponse = await fetch("https://api.mercadopago.com/oauth/token", {
      method: "POST",
      headers: {
        "Content-Type": "application/x-www-form-urlencoded",
        "Accept": "application/json",
      },
      body: new URLSearchParams({
        client_id: MP_CLIENT_ID,
        client_secret: MP_CLIENT_SECRET,
        grant_type: "authorization_code",
        code: code,
        redirect_uri: redirectUri,
      }),
    });

    if (!tokenResponse.ok) {
      const errBody = await tokenResponse.text();
      throw new Error(`Error al obtener token de MP: ${errBody}`);
    }

    const tokenData = await tokenResponse.json();
    const mpAccessToken = tokenData.access_token;

    // 2. Obtener datos del usuario de Mercado Pago
    const userResponse = await fetch("https://api.mercadopago.com/users/me", {
      headers: {
        "Authorization": `Bearer ${mpAccessToken}`,
      },
    });

    if (!userResponse.ok) {
      const errBody = await userResponse.text();
      throw new Error(`Error al obtener usuario de MP: ${errBody}`);
    }

    const mpUser = await userResponse.json();
    const mpEmail = mpUser.email;
    const mpFullName = `${mpUser.first_name} ${mpUser.last_name}`.trim();
    const mpUserId = mpUser.id;

    if (!mpEmail) {
      throw new Error("Mercado Pago no proporcionó un email válido para este usuario");
    }

    // 3. Crear o actualizar usuario en Supabase
    const supabaseAdmin = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    const { data: userData, error: createError } = await supabaseAdmin.auth.admin.createUser({
      email: mpEmail,
      email_confirm: true,
      user_metadata: {
        full_name: mpFullName,
        mp_user_id: mpUserId,
        role: "sudo",
        mp_access_token: mpAccessToken
      },
    });

    let userId = userData?.user?.id;

    if (createError && createError.message !== "User already registered") {
      console.error("Error creando usuario en Supabase:", createError);
    } else if (userId) {
      // Upsert al perfil igual que lo hacía la app de Flutter
      await supabaseAdmin.from('profiles').upsert({
        id: userId,
        email: mpEmail,
        full_name: mpFullName,
        role: 'sudo'
      });
    }

    if (createError && createError.message === "User already registered") {
      // Buscar al usuario existente
      const { data: profiles } = await supabaseAdmin.from('profiles').select('id, institution_id').eq('email', mpEmail).limit(1);
      if (profiles && profiles.length > 0) {
        userId = profiles[0].id;
        const institutionId = profiles[0].institution_id;
        
        // Actualizamos sus metadatos con el nuevo token
        await supabaseAdmin.auth.admin.updateUserById(userId, {
          user_metadata: { mp_access_token: mpAccessToken }
        });

        // Si ya tiene institución, actualizamos el token directamente
        if (institutionId) {
          await supabaseAdmin.from('institutions').update({
            mp_token_secret_name: mpAccessToken
          }).eq('id', institutionId);
        }
      }
    }

    // 4. Generar Magic Link para auto-login y redirigir
    const { data: linkData, error: linkError } = await supabaseAdmin.auth.admin.generateLink({
      type: "magiclink",
      email: mpEmail,
      options: {
        redirectTo: redirectUrl,
      },
    });

    if (linkError || !linkData?.properties?.action_link) {
      throw new Error(`No se pudo generar el enlace de inicio de sesión: ${linkError?.message}`);
    }

    return Response.redirect(linkData.properties.action_link, 302);

  } catch (err) {
    const msg = err instanceof Error ? err.message : String(err);
    console.error(`[mp-auth-callback] Error:`, msg);
    
    const htmlError = `
      <html>
        <head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"></head>
        <body style="font-family: sans-serif; text-align: center; padding: 2rem;">
          <h2>Ups, ocurrió un error</h2>
          <p>${msg}</p>
          <a href="argity://login-callback?error=auth_failed" style="display:inline-block; margin-top:20px; padding:10px 20px; background:#009ee3; color:white; text-decoration:none; border-radius:5px;">Volver a la App</a>
        </body>
      </html>
    `;
    return new Response(htmlError, {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "text/html" },
    });
  }
});
