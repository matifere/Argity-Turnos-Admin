import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> _listenForAuth(HttpServer server) async {
  await for (HttpRequest request in server) {
    // Supabase Auth (Google) uses PKCE and returns the code in query parameters
    final code = request.uri.queryParameters['code'];
    if (code != null && code.isNotEmpty) {
      request.response
        ..statusCode = 200
        ..headers.contentType = ContentType.html
        ..write("<html><body style='font-family:sans-serif;text-align:center;padding:50px;background:#f3f4f6;color:#1f2937;'><h2>Autenticación exitosa.</h2><p>Ya podés cerrar esta ventana y volver a Argity.</p><script>setTimeout(() => window.close(), 1500);</script></body></html>");
      await request.response.close();
      await server.close();
      
      try {
        await Supabase.instance.client.auth.exchangeCodeForSession(code);
      } catch (e) {
        debugPrint('Error exchanging code: $e');
      }
      break;
    }

    if (request.uri.path == '/token') {
      final refreshToken = request.uri.queryParameters['refresh_token'];
      
      request.response
        ..statusCode = 200
        ..headers.contentType = ContentType.html
        ..write("<html><body style='font-family:sans-serif;text-align:center;padding:50px;background:#f3f4f6;color:#1f2937;'><h2>Autenticación exitosa.</h2><p>Ya podés volver a Argity.</p><script>setTimeout(() => window.close(), 1500);</script></body></html>");
      await request.response.close();
      await server.close();
      
      if (refreshToken != null && refreshToken.isNotEmpty) {
        await Supabase.instance.client.auth.setSession(refreshToken);
      }
      break;
    } else {
      request.response
        ..statusCode = 200
        ..headers.contentType = ContentType.html
        ..write('''
          <html>
            <body style='font-family:sans-serif;text-align:center;padding:50px;'>
              <h2>Procesando tu sesión...</h2>
              <script>
                const hash = window.location.hash.substring(1);
                const params = new URLSearchParams(hash);
                const refreshToken = params.get('refresh_token');
                
                if (refreshToken) {
                  window.location.href = "/token?refresh_token=" + refreshToken;
                } else {
                  document.body.innerHTML = "<h2>Error: No se encontró el token</h2><p>Por favor intenta de nuevo.</p>";
                }
              </script>
            </body>
          </html>
        ''');
      await request.response.close();
    }
  }
}

Future<void> handleDesktopOAuth(String clientId, String redirectUri) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  final port = server.port;
  
  final Uri url = Uri.https(
    'auth.mercadopago.com',
    '/authorization',
    {
      'client_id': clientId,
      'response_type': 'code',
      'platform_id': 'mp',
      'redirect_uri': redirectUri,
      'state': 'port:$port',
    },
  );

  await launchUrl(url, mode: LaunchMode.externalApplication);
  await _listenForAuth(server);
}

Future<void> handleDesktopGoogleOAuth() async {
  // Usamos un puerto fijo (43210) para que pueda ser añadido a la lista blanca de Redirect URLs en Supabase.
  // Si el puerto está ocupado, lanza un error claro al desarrollador/usuario.
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 43210);
  final port = server.port;
  
  final redirectUri = 'http://localhost:$port';
  
  await Supabase.instance.client.auth.signInWithOAuth(
    OAuthProvider.google,
    redirectTo: redirectUri,
  );

  await _listenForAuth(server);
}
