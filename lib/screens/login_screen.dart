import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:argrity/bloc/auth/auth_bloc.dart';
import 'package:argrity/screens/register_screen.dart';
import 'package:argrity/theme/kali_colors_extension.dart';
import 'package:argrity/widgets/kali_text_field.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:argrity/utils/oauth_helper.dart';
import 'package:argrity/utils/mp_utils.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController emailControl = TextEditingController();
  final TextEditingController contraControl = TextEditingController();
  bool _isPassObscured = true;

  @override
  void dispose() {
    emailControl.dispose();
    contraControl.dispose();
    super.dispose();
  }

  Future<void> _handleMercadoPagoLogin(BuildContext context) async {
    final String clientId = getMpClientId();
    final String redirectUri = getMpRedirectUri();
    
    if (kIsWeb) {
      // Pasamos la URL pero evitando que empiece con http:// o https:// porque el WAF de MP lo bloquea
      String appRedirect = Uri.base.origin;
      String encodedState = base64Url.encode(utf8.encode(appRedirect));
      final Uri url = Uri.https(
        'auth.mercadopago.com',
        '/authorization',
        {
          'client_id': clientId,
          'response_type': 'code',
          'platform_id': 'mp',
          'redirect_uri': redirectUri,
          'state': 'b64:$encodedState',
        },
      );
      if (!await launchUrl(url, webOnlyWindowName: '_self')) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudo abrir Mercado Pago')));
        }
      }
    } else {
      // Para Escritorio (Win/Mac/Lin) o Móvil usamos un servidor web efímero
      try {
        await handleDesktopOAuth(clientId, redirectUri);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }

  Future<void> _handleGoogleLogin(BuildContext context) async {
    try {
      if (kIsWeb) {
        await Supabase.instance.client.auth.signInWithOAuth(
          OAuthProvider.google,
          redirectTo: Uri.base.origin,
        );
      } else {
        await handleDesktopGoogleOAuth();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _handleForgotPassword() async {
    final kaliColors = Theme.of(context).extension<KaliColorsExtension>()!;
    final emailCtrl = TextEditingController(text: emailControl.text.trim());
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: kaliColors.warmWhite,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: kaliColors.sand,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.lock_reset_rounded,
                    color: kaliColors.clayDark,
                    size: 30,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  '¿Olvidaste tu contraseña?',
                  style: kaliColors.heading(kaliColors.espresso, size: 22),
                ),
                const SizedBox(height: 8),
                Text(
                  'Ingresá tu email y te enviamos un link para crear una nueva contraseña.',
                  style: kaliColors.body(kaliColors.clayDark, size: 14),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  autofocus: true,
                  style: kaliColors.body(kaliColors.espresso),
                  decoration: InputDecoration(
                    hintText: 'tu@email.com',
                    hintStyle: kaliColors.body(kaliColors.clay),
                    prefixIcon:
                        Icon(Icons.mail_outline, color: kaliColors.clay),
                    filled: true,
                    fillColor: kaliColors.sand,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide:
                          BorderSide(color: kaliColors.clay, width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child: Text(
                        'Cancelar',
                        style: kaliColors.body(kaliColors.clayDark),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text('Enviar link'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (confirmed != true) return;
    final email = emailCtrl.text.trim();
    if (email.isEmpty) return;

    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(
        email,
        redirectTo: 'https://admins.argity.com',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Te enviamos un email a $email con el link para restablecer tu contraseña. Revisá también la carpeta de spam.'),
            duration: const Duration(seconds: 6),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text('Ocurrió un error inesperado. Intentá nuevamente.')),
        );
      }
    }
  }

  void _handleLogin(BuildContext context) {
    if (emailControl.text.trim().isEmpty || contraControl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor llena todos los campos')),
      );
      return;
    }
    context.read<AuthBloc>().add(AuthLoginRequested(
          email: emailControl.text.trim(),
          password: contraControl.text,
        ));
  }

  @override
  Widget build(BuildContext context) {
    final kaliColors = Theme.of(context).extension<KaliColorsExtension>()!;
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isSmall = screenWidth < 480;
    // El padding de la tarjeta y el del scroll exterior se descuentan del ancho
    // disponible para que el formulario nunca desborde en pantallas angostas.
    final double cardPadding = isSmall ? 24 : 40;
    final double widthInForm =
        (screenWidth - 32 - cardPadding * 2).clamp(0.0, 360.0);
    return BlocConsumer<AuthBloc, AuthState>(
      // El listener solo se activa cuando hay una transición real
      // (no en rebuilds de hot reload con estado previo ya emitido).
      listenWhen: (previous, current) =>
          current is AuthSuccess || current is AuthFailure,
      listener: (context, state) {
        if (state is AuthSuccess) {
          // Reseteamos ANTES de navegar para que si hay un rebuild
          // posterior (hot reload, etc.) el listener no se re-dispare.
          context.read<AuthBloc>().add(AuthReset());
          // La navegación real es manejada por onAuthStateChange en main.dart
        } else if (state is AuthFailure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message)),
          );
        }
      },
      builder: (context, state) {
        final isLoading = state is AuthLoading;
        return Scaffold(
          backgroundColor: kaliColors.background,
          body: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 16),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Logo + título ──────────────────────────────────────────
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset(
                        'assets/images/logo_naranja.png',
                        width: 88,
                        height: 88,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        "Bienvenid@ de nuevo",
                        style: kaliColors.loginDisplay(kaliColors.espresso),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Accede a tu panel de gestion",
                        style: kaliColors.loginBody(kaliColors.espresso),
                      ),
                    ],
                  ),
                  const SizedBox(height: 48),

                  // ── Formulario ─────────────────────────────────────────────
                  Card(
                    child: Padding(
                      padding: EdgeInsets.all(cardPadding),
                      child: SizedBox(
                        width: widthInForm,
                        child: Column(
                          spacing: 28,
                          mainAxisSize: MainAxisSize.min,
                          children: [

                            KaliTextField(
                              label: "EMAIL",
                              hint: "tu@ejemplo.com",
                              controller: emailControl,
                              suffixIcon: Icons.mail,
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                KaliTextField(
                                  label: "CONTRASEÑA",
                                  hint: "••••••••",
                                  controller: contraControl,
                                  obscureText: _isPassObscured,
                                  suffixIcon: _isPassObscured
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                  onSuffixTap: () => setState(
                                    () => _isPassObscured = !_isPassObscured,
                                  ),
                                ),
                                TextButton(
                                  onPressed: _handleForgotPassword,
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: Text(
                                    '¿Olvidé mi contraseña?',
                                    style:
                                        kaliColors.caption(kaliColors.clayDark),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: FilledButton(
                                onPressed: isLoading
                                    ? null
                                    : () => _handleLogin(context),
                                child: isLoading
                                    ? SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          color: kaliColors.warmWhite,
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Text("ENTRAR"),
                              ),
                            ),
                            Column(
                              children: [
                                const Row(
                                  spacing: 4,
                                  children: [
                                    Expanded(child: Divider()),
                                    Text("o"),
                                    Expanded(child: Divider()),
                                  ],
                                ),
                                const SizedBox(height: 16),

                                SizedBox(
                                  width: double.infinity,
                                  height: 54,
                                  child: ElevatedButton.icon(
                                    onPressed: isLoading ? null : () => _handleMercadoPagoLogin(context),
                                    icon: isLoading
                                        ? const SizedBox.shrink()
                                        : const Icon(Icons.account_balance_wallet, size: 24),
                                    label: isLoading
                                        ? SizedBox(
                                            width: 24,
                                            height: 24,
                                            child: CircularProgressIndicator(
                                              color: kaliColors.warmWhite,
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : Text(
                                            "INICIAR SESIÓN CON MERCADO PAGO",
                                            style: kaliColors.label(kaliColors.warmWhite).copyWith(
                                                  fontSize: 12,
                                                  letterSpacing: 2,
                                                ),
                                          ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF009EE3), // Azul oficial de Mercado Pago
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(27),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                SizedBox(
                                  width: double.infinity,
                                  height: 54,
                                  child: ElevatedButton.icon(
                                    onPressed: isLoading
                                        ? null
                                        : () => _handleGoogleLogin(context),
                                    icon: isLoading
                                        ? const SizedBox.shrink()
                                        : Image.network(
                                            'https://cdn1.iconfinder.com/data/icons/google-s-logo/150/Google_Icons-09-512.png',
                                            height: 24,
                                          ),
                                    label: isLoading
                                        ? SizedBox(
                                            width: 24,
                                            height: 24,
                                            child: CircularProgressIndicator(
                                              color: kaliColors.clay,
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : Text(
                                            "INICIAR SESIÓN CON GOOGLE",
                                            style: kaliColors.label(kaliColors.espresso).copyWith(
                                                  fontSize: 12,
                                                  letterSpacing: 2,
                                                ),
                                          ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      foregroundColor: kaliColors.espresso,
                                      elevation: 0,
                                      side: BorderSide(color: Colors.grey.shade300),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(27),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              children: [
                                const Row(
                                  spacing: 4,
                                  children: [
                                    Expanded(child: Divider()),
                                    Text("o"),
                                    Expanded(child: Divider()),
                                  ],
                                ),
                                Center(
                                  child: TextButton(
                                    onPressed: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              const RegisterScreen(),
                                        ),
                                      );
                                    },
                                    child: const Text("Crear Cuenta"),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
