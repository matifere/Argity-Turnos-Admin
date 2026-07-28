import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:argrity/theme/kali_colors_extension.dart';
import 'package:argrity/widgets/kali_text_field.dart';
import 'package:argrity/widgets/auth_wrapper.dart';
import 'package:argrity/screens/login_screen.dart';
import 'package:argrity/services/profile_cache.dart';

class InstitutionSelectionScreen extends StatefulWidget {
  const InstitutionSelectionScreen({super.key});

  @override
  State<InstitutionSelectionScreen> createState() =>
      _InstitutionSelectionScreenState();
}

class _InstitutionSelectionScreenState
    extends State<InstitutionSelectionScreen> {
  final TextEditingController _createNameCtrl = TextEditingController();
  final TextEditingController _createAliasCtrl = TextEditingController();
  final TextEditingController _createPhoneCtrl = TextEditingController();
  final TextEditingController _createAdressCtrl = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _createNameCtrl.dispose();
    _createAliasCtrl.dispose();
    _createPhoneCtrl.dispose();
    _createAdressCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleCreate() async {
    final name = _createNameCtrl.text.trim();
    final alias = _createAliasCtrl.text.trim();
    final phone = _createPhoneCtrl.text.trim();
    final adress = _createAdressCtrl.text.trim();
    if (name.isEmpty || alias.isEmpty || phone.isEmpty || adress.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Todos los campos tienen que ser completados')));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw Exception('No session');

      final slug = name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');

      // Usamos la función RPC que inserta la institución, actualiza el rol
      // y nos devuelve directamente el ID creado, evitando consultas redundantes.
      final instId =
          await Supabase.instance.client.rpc('create_institution', params: {
        'inst_name': name,
        'inst_slug': slug,
        'payment_alias': alias,
        'phone': phone,
        'address': adress,
      });

      // Recuperar el token de MP que la Edge Function guardó en los metadatos
      final mpToken = user.userMetadata?['mp_access_token'];
      if (mpToken != null) {
        await Supabase.instance.client
            .from('institutions')
            .update({'mp_token_secret_name': mpToken})
            .eq('id', instId);
      }

      // Refrescamos el caché para que AuthWrapper enrute con datos actualizados
      // y no vuelva a mostrar esta pantalla mientras re-verifica el perfil.
      ProfileCache.set(
        role: 'sudo',
        institutionId: instId as String?,
        fullName: ProfileCache.fullName,
      );
      ProfileCache.updateIsActive(false);

      if (mounted) {
        // No apagamos _isLoading: mantenemos el indicador hasta que la
        // navegación reemplace esta pantalla por la siguiente.
        Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const AuthWrapper()));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content:
                Text('No se pudo crear la institución. Intentá nuevamente.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final kaliColors = Theme.of(context).extension<KaliColorsExtension>()!;
    return Scaffold(
      backgroundColor: kaliColors.background,
      appBar: AppBar(
        title: const Text('Configuración de Institución'),
        centerTitle: true,
        backgroundColor: kaliColors.espresso,
        foregroundColor: kaliColors.warmWhite,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar sesión',
            onPressed: () async {
              await Supabase.instance.client.auth.signOut();
              if (context.mounted) {
                Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const LoginScreen()));
              }
            },
          )
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 500),
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
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Crea una nueva institución para empezar a gestionar tu estudio.',
                      style: kaliColors.body(kaliColors.clayDark),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    Column(
                      spacing: 16,
                      children: [
                        KaliTextField(
                          label: 'NOMBRE DE LA INSTITUCIÓN',
                          hint: 'Ej. MiInst',
                          controller: _createNameCtrl,
                        ),
                        KaliTextField(
                          label: 'ALIAS',
                          hint: 'Ej. mi.alias.mp',
                          controller: _createAliasCtrl,
                        ),
                        KaliTextField(
                          label: 'CELULAR',
                          hint: 'Ej. +54911001122',
                          controller: _createPhoneCtrl,
                        ),
                        KaliTextField(
                          label: 'DIRECCION',
                          hint: 'Ej. Mi Calle 123',
                          controller: _createAdressCtrl,
                        ),
                      ],
                    ),
                    const SizedBox(
                      height: 48,
                    ),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleCreate,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kaliColors.espresso,
                          foregroundColor:
                              kaliColors.getContrastColor(kaliColors.espresso),
                        ),
                        child: _isLoading
                            ? SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                    color: kaliColors
                                        .getContrastColor(kaliColors.espresso),
                                    strokeWidth: 2))
                            : const Text('CREAR Y CONTINUAR'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
