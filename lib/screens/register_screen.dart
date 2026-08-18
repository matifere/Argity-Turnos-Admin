import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:argrity/bloc/auth/auth_bloc.dart';
import 'package:argrity/theme/kali_colors_extension.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:argrity/utils/oauth_helper.dart';
import 'package:argrity/utils/mp_utils.dart';
import 'package:argrity/widgets/kali_text_field.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController nameControl = TextEditingController();
  final TextEditingController emailControl = TextEditingController();
  final TextEditingController contraControl = TextEditingController();
  final TextEditingController confirmContraControl = TextEditingController();
  bool _isPassObscured = true;
  bool _isConfirmPassObscured = true;

  @override
  void dispose() {
    nameControl.dispose();
    emailControl.dispose();
    contraControl.dispose();
    confirmContraControl.dispose();
    super.dispose();
  }

  Future<void> _confirmAdminRole(BuildContext context, VoidCallback onConfirm) async {
    final kaliColors = Theme.of(context).extension<KaliColorsExtension>()!;
    final isTrainer = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: kaliColors.warmWhite,
        title: Text(
          "¿Eres Administrador?",
          style: kaliColors.heading(kaliColors.espresso),
        ),
        content: Text(
          "El registro de usuario está pensado únicamente para los administradores del estudio. Si eres un entrenador, debes esperar a que tu administrador cree tu cuenta y te asigne las credenciales correspondientes.",
          style: kaliColors.body(kaliColors.clayDark, size: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              "Soy entrenador",
              style: kaliColors.label(kaliColors.clayDark),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            style: FilledButton.styleFrom(
              backgroundColor: kaliColors.espresso,
            ),
            child: Text(
              "Soy administrador",
              style: kaliColors.label(kaliColors.warmWhite),
            ),
          ),
        ],
      ),
    );

    if (isTrainer == false) {
      onConfirm();
    } else if (isTrainer == true) {
      if (context.mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  void _handleRegister(BuildContext context) {
    if (nameControl.text.trim().isEmpty ||
        emailControl.text.trim().isEmpty ||
        contraControl.text.isEmpty ||
        confirmContraControl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor llena todos los campos')),
      );
      return;
    }

    if (contraControl.text != confirmContraControl.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Las contraseñas no coinciden')),
      );
      return;
    }

    _confirmAdminRole(context, () {
      context.read<AuthBloc>().add(AuthRegisterRequested(
            fullName: nameControl.text.trim(),
            email: emailControl.text.trim(),
            password: contraControl.text,
          ));
    });
  }

  Future<void> _handleMercadoPagoRegister(BuildContext context) async {
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
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('No se pudo abrir Mercado Pago')));
        }
      }
    } else {
      // Para Escritorio (Win/Mac/Lin) o Móvil usamos un servidor web efímero
      try {
        await handleDesktopOAuth(clientId, redirectUri);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Error: $e')));
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
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  // ── Panel decorativo izquierdo (solo escritorio) ──────────────────────────
  Widget _buildBrandPanel(KaliColorsExtension kaliColors) {
    return Container(
      color: kaliColors.espresso,
      padding: const EdgeInsets.all(48.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Spacer(),
          Text(
            "Crear Perfil\nAdministrativo",
            style: kaliColors.display(kaliColors.warmWhite).copyWith(
                  fontSize: 48,
                  fontStyle: FontStyle.italic,
                ),
          ),
          const SizedBox(height: 24),
          Text(
            "Comienza a gestionar tu institución\nhoy con herramientas diseñadas\npara la administración profesional.",
            style: kaliColors.body(
              kaliColors.clay,
              size: 16,
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }

  // ── Formulario de registro ────────────────────────────────────────────────
  Widget _buildForm(
      BuildContext context, bool isLoading, KaliColorsExtension kaliColors) {
    return Container(
      color: kaliColors.warmWhite,
      padding: const EdgeInsets.all(32.0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Registro de Staff",
              style: kaliColors.heading(
                kaliColors.espresso,
                size: 32,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              "Crea tu cuenta de administrador usando tu correo o con Mercado Pago.",
              style: kaliColors.body(
                kaliColors.clayDark,
                size: 14,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: KaliTextField(
                    label: "NOMBRE COMPLETO",
                    hint: "Juan Pérez",
                    controller: nameControl,
                    suffixIcon: Icons.person_outline,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: KaliTextField(
                    label: "EMAIL",
                    hint: "tu@ejemplo.com",
                    controller: emailControl,
                    suffixIcon: Icons.mail_outline,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: KaliTextField(
                    label: "CONTRASEÑA",
                    hint: "••••••••",
                    controller: contraControl,
                    obscureText: _isPassObscured,
                    suffixIcon: _isPassObscured
                        ? Icons.visibility_off
                        : Icons.visibility,
                    onSuffixTap: () =>
                        setState(() => _isPassObscured = !_isPassObscured),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: KaliTextField(
                    label: "CONFIRMAR",
                    hint: "••••••••",
                    controller: confirmContraControl,
                    obscureText: _isConfirmPassObscured,
                    suffixIcon: _isConfirmPassObscured
                        ? Icons.visibility_off
                        : Icons.visibility,
                    onSuffixTap: () => setState(
                        () => _isConfirmPassObscured = !_isConfirmPassObscured),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: FilledButton(
                onPressed: isLoading ? null : () => _handleRegister(context),
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(27),
                  ),
                ),
                child: isLoading
                    ? SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: kaliColors.warmWhite,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        "CREAR CUENTA",
                        style: kaliColors.label(kaliColors.warmWhite).copyWith(
                              fontSize: 12,
                              letterSpacing: 2,
                            ),
                      ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Expanded(child: Divider()),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    "O",
                    style: kaliColors.body(kaliColors.clayDark, size: 12),
                  ),
                ),
                const Expanded(child: Divider()),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton.icon(
                onPressed: isLoading
                    ? null
                    : () => _confirmAdminRole(context, () => _handleMercadoPagoRegister(context)),
                icon: isLoading
                    ? const SizedBox.shrink()
                    : const Icon(Icons.account_balance_wallet,
                        size: 24), // Ícono representativo de billetera
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
                        "REGISTRARSE CON MERCADO PAGO",
                        style: kaliColors.label(kaliColors.warmWhite).copyWith(
                              fontSize: 12,
                              letterSpacing: 2,
                            ),
                      ),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      const Color(0xFF009EE3), // Azul oficial de Mercado Pago
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
                onPressed: isLoading ? null : () => _confirmAdminRole(context, () => _handleGoogleLogin(context)),
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
                        "REGISTRARSE CON GOOGLE",
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
            const SizedBox(height: 32),
            Center(
              child: InkWell(
                onTap: () => Navigator.of(context).pop(),
                child: RichText(
                  text: TextSpan(
                    style: kaliColors.body(
                      kaliColors.clayDark,
                      size: 14,
                    ),
                    children: [
                      const TextSpan(
                        text: "¿Ya eres parte del equipo? ",
                      ),
                      TextSpan(
                        text: "Iniciar Sesión",
                        style: TextStyle(
                          color: kaliColors.espresso,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final kaliColors = Theme.of(context).extension<KaliColorsExtension>()!;
    return BlocConsumer<AuthBloc, AuthState>(
      listenWhen: (previous, current) =>
          current is AuthSuccess ||
          current is AuthFailure ||
          current is AuthPending,
      listener: (context, state) {
        if (state is AuthSuccess) {
          context.read<AuthBloc>().add(AuthReset());
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Registro exitoso')),
          );
          // La navegación a AuthWrapper es manejada por onAuthStateChange en main.dart
        } else if (state is AuthPending) {
          context.read<AuthBloc>().add(AuthReset());
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Cuenta creada.'),
              duration: Duration(seconds: 5),
            ),
          );
          Navigator.of(context).pop();
        } else if (state is AuthFailure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message)),
          );
        }
      },
      builder: (context, state) {
        final isLoading = state is AuthLoading;
        // En pantallas anchas mostramos el panel decorativo + formulario lado a
        // lado; en celular, una sola columna con el formulario a ancho completo.
        final bool isWide = MediaQuery.of(context).size.width >= 800;
        return Scaffold(
          appBar: AppBar(),
          backgroundColor: kaliColors.background,
          body: Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: isWide ? 900 : 460,
                    maxHeight: isWide ? 600 : double.infinity,
                  ),
                  decoration: BoxDecoration(
                    color: kaliColors.warmWhite,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      )
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: isWide
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                                flex: 4, child: _buildBrandPanel(kaliColors)),
                            Expanded(
                              flex: 6,
                              child: _buildForm(context, isLoading, kaliColors),
                            ),
                          ],
                        )
                      : _buildForm(context, isLoading, kaliColors),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
