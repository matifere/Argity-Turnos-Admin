import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:argrity/screens/dashboard_screen.dart';
import 'package:argrity/screens/institution_selection_screen.dart';
import 'package:argrity/screens/inactive_screen.dart';
import 'package:argrity/screens/admin_onboarding_screen.dart';
import 'package:argrity/services/profile_cache.dart';
import 'package:argrity/widgets/kali_splash.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:argrity/cubits/theme/theme_cubit.dart';
import 'package:argrity/services/update_service.dart';
import 'package:argrity/screens/force_update_screen.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  // Si ProfileCache ya tiene datos (re-montaje en la misma sesión),
  // renderizamos sin ninguna espera. Si no, esperamos silenciosamente
  // (scaffold en blanco, imperceptible) hasta que _checkProfile() confirme.
  bool _profileChecked = ProfileCache.isLoaded;
  bool _hasInstitution = ProfileCache.institutionId != null;
  // Arrancamos con el último valor conocido: si el usuario ya estaba activo,
  // un remount no debe mostrar InactiveScreen mientras se re-verifica.
  bool _isActive = ProfileCache.isActive;
  bool _hasPlans = true;

  /// true una vez que _checkProfile() completó la verificación de suscripción.
  /// Mientras sea false, el stream listener NO puede sobreescribir _isActive
  /// para evitar la race condition que causa bypass del paywall.
  bool _subscriptionChecked = false;
  
  bool _updateChecked = false;
  AppUpdateInfo? _updateInfo;

  StreamSubscription<List<Map<String, dynamic>>>? _profileSub;
  StreamSubscription<List<Map<String, dynamic>>>? _subscriptionSub;

  @override
  void initState() {
    super.initState();
    // 1. Primero chequeamos actualizaciones bloqueantes
    UpdateService.checkForUpdates().then((info) {
      if (!mounted) return;
      setState(() {
        _updateChecked = true;
        _updateInfo = info;
      });

      // 2. Si NO hay actualización obligatoria, continuamos el flujo normal
      if (info == null) {
        _checkProfile().then((_) {
          _listenProfileChanges();
        });
      }
    });
  }

  void _listenProfileChanges() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    _profileSub = Supabase.instance.client
        .from('profiles')
        .stream(primaryKey: ['id'])
        .eq('id', user.id)
        .listen((data) async {
          if (data.isNotEmpty && mounted && _subscriptionChecked) {
            final profile = data.first;
            final profileIsActive = profile['is_active'] as bool? ?? true;
            ProfileCache.updateIsProfileDisabled(!profileIsActive);

            // Re-verificar la validez de la suscripción antes de decidir
            // si el usuario puede acceder al dashboard.
            final shouldBeActive =
                profileIsActive && await _isSubscriptionValid();

            ProfileCache.updateIsActive(shouldBeActive);
            if (mounted && shouldBeActive != _isActive) {
              setState(() => _isActive = shouldBeActive);
            }
          }
        });

    final institutionId = ProfileCache.institutionId;
    if (institutionId != null && ProfileCache.role == 'sudo') {
      _subscriptionSub = Supabase.instance.client
          .from('tenant_subscriptions')
          .stream(primaryKey: ['id'])
          .eq('institution_id', institutionId)
          .listen((_) async {
            if (mounted && _subscriptionChecked) {
              await _checkProfile();
            }
          });
    }
  }

  /// Verifica si la suscripción de la institución es válida.
  /// Retorna true solo para estados explícitamente activos.
  Future<bool> _isSubscriptionValid() async {
    final isSudo = ProfileCache.role == 'sudo';
    final institutionId = ProfileCache.institutionId;
    if (!isSudo || institutionId == null) return true;

    try {
      final subData = await Supabase.instance.client
          .from('tenant_subscriptions')
          .select('status, current_period_end, saas_plans(features)')
          .eq('institution_id', institutionId)
          .maybeSingle();

      if (subData == null) {
        ProfileCache.updateHasCustomThemes(false);
        ProfileCache.updateHasCustomLogo(false);
        return false;
      }

      // Procesar features del plan (ej. custom_themes)
      final saasPlans = subData['saas_plans'];
      if (saasPlans != null && saasPlans['features'] != null) {
        final features = saasPlans['features'] as Map<String, dynamic>;
        ProfileCache.updateHasCustomThemes(features['custom_themes'] == true);
        ProfileCache.updateHasCustomLogo(features['custom_logo'] == true);
      } else {
        ProfileCache.updateHasCustomThemes(false);
        ProfileCache.updateHasCustomLogo(false);
      }

      final status = subData['status'] as String?;
      if (status == 'active' || status == 'authorized') {
        return true;
      } else if (status == 'cancelled' &&
          subData['current_period_end'] != null) {
        final end = DateTime.tryParse(subData['current_period_end'].toString());
        return end != null && DateTime.now().isBefore(end);
      }
      return false;
    } catch (_) {
      // Fail-closed: ante cualquier error, denegar acceso
      ProfileCache.updateHasCustomThemes(false);
      ProfileCache.updateHasCustomLogo(false);
      return false;
    }
  }

  @override
  void dispose() {
    _profileSub?.cancel();
    _subscriptionSub?.cancel();
    super.dispose();
  }

  Future<void> _checkProfile() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        // Sin sesión: no tocar el estado para no mostrar InstitutionSelectionScreen.
        // _KaliAppViewState manejará la navegación a LoginScreen.
        return;
      }

      final data = await Supabase.instance.client
          .from('profiles')
          .select('role, institution_id, full_name, is_active, institutions(theme_id)')
          .eq('id', user.id)
          .maybeSingle();

      if (data != null) {
        ProfileCache.set(
          role: data['role'] as String? ?? 'sudo',
          institutionId: data['institution_id'] as String?,
          fullName: data['full_name'] as String?,
        );
        ProfileCache.updateIsProfileDisabled(
            !(data['is_active'] as bool? ?? true));
            
        final instData = data['institutions'];
        if (instData != null && instData['theme_id'] != null) {
          if (mounted) {
            context.read<ThemeCubit>().syncTheme(instData['theme_id'] as String);
          }
        }
      }

      final isSubValid = await _isSubscriptionValid();

      // Si no tiene el feature y está usando un tema premium, lo forzamos a default
      if (!ProfileCache.hasCustomThemes && mounted) {
        final currentTheme = context.read<ThemeCubit>().state.themeId;
        if (currentTheme != 'default') {
          await context.read<ThemeCubit>().changeTheme('default');
        }
      }

      final isActive = data != null
          ? ((data['is_active'] as bool? ?? true) && isSubValid)
          : false;
      ProfileCache.updateIsActive(isActive);

      bool hasPlans = true;
      if (isActive && ProfileCache.role == 'sudo' && ProfileCache.institutionId != null) {
        try {
          final plansRes = await Supabase.instance.client
              .from('plans')
              .select('id')
              .limit(1);
          hasPlans = (plansRes as List).isNotEmpty;
        } catch (_) {
          hasPlans = true;
        }
      }

      if (mounted) {
        setState(() {
          _isActive = isActive;
          _hasInstitution = data != null && data['institution_id'] != null;
          _hasPlans = hasPlans;
          _profileChecked = true;
          _subscriptionChecked = true;
        });
      }
    } catch (e, stack) {
      debugPrint('CRASH IN _checkProfile: $e\n$stack');
      if (e is PostgrestException && e.code == '401') {
        // Token inválido (ej. base de datos reiniciada o token revocado). 
        // Cerramos sesión para que el AuthState listener nos lleve al LoginScreen.
        await Supabase.instance.client.auth.signOut();
        return;
      }
      // Fail-closed: ante cualquier error, marcar como inactivo.
      ProfileCache.updateIsActive(false);
      if (mounted) {
        setState(() {
          _profileChecked = true;
          _subscriptionChecked = true;
          _isActive = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 1. Esperamos a que termine el chequeo de actualizaciones
    if (!_updateChecked) {
      return const KaliSplash();
    }

    // 2. Si hay actualización, bloqueamos la app entera
    if (_updateInfo != null) {
      return ForceUpdateScreen(updateInfo: _updateInfo!);
    }

    // 3. Flujo normal de auth
    // Hasta que el perfil esté confirmado mostramos el splash con branding
    // en lugar de un scaffold en blanco.
    if (!_profileChecked) {
      return const KaliSplash();
    }

    if (!_hasInstitution) return const InstitutionSelectionScreen();
    if (!_isActive) return const InactiveScreen();
    if (!_hasPlans) {
      return AdminOnboardingScreen(
        onCompleted: () {
          setState(() {
            _hasPlans = true;
          });
        },
      );
    }
    return const DashboardScreen();
  }
}
