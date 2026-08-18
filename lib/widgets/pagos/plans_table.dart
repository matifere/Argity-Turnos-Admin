import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:argrity/utils/oauth_helper.dart';
import 'package:argrity/utils/mp_utils.dart';
import 'package:argrity/services/profile_cache.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:argrity/theme/kali_colors_extension.dart';
import 'package:argrity/widgets/common/kali_icon_button.dart';
import 'package:argrity/widgets/pagos/plan_form_dialog.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Directorio/Tabla de planes de pago.
class PlansTable extends StatefulWidget {
  const PlansTable({super.key});

  @override
  State<PlansTable> createState() => _PlansTableState();
}

class _PlansTableState extends State<PlansTable> {
  List<Map<String, dynamic>> _plans = [];
  bool _isLoading = true;
  String? _error;
  bool _hasMpToken = true;

  @override
  void initState() {
    super.initState();
    _loadPlans();
  }

  Future<void> _loadPlans() async {
    setState(() => _isLoading = true);
    try {
      final res = await Supabase.instance.client
          .from('plans')
          .select(
              'id, name, description, price, currency, max_reservations_per_month, is_active')
          .order('name', ascending: true);
      final instId = ProfileCache.institutionId;
      bool hasMpToken = true;
      if (instId != null) {
        try {
          final instRes = await Supabase.instance.client
              .from('institutions')
              .select('mp_token_secret_name')
              .eq('id', instId)
              .maybeSingle();
          if (instRes != null) {
            hasMpToken = instRes['mp_token_secret_name'] != null;
          }
        } catch (_) {
          // Si falla por RLS o no existe la columna, asumimos true por defecto o lo manejamos silenciando
        }
      }

      if (mounted) {
        setState(() {
          _plans = List<Map<String, dynamic>>.from(res);
          _hasMpToken = hasMpToken;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Error al cargar planes: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleMercadoPagoLink(BuildContext context) async {
    final String clientId = getMpClientId();
    final String redirectUri = getMpRedirectUri();
    
    if (kIsWeb) {
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
      try {
        await handleDesktopOAuth(clientId, redirectUri);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }

  Future<void> _deletePlan(Map<String, dynamic> plan) async {
    final planName = plan['name'] as String;
    final planId = plan['id'] as String;

    // Verificar si hay suscripciones que referencian este plan
    final subs = await Supabase.instance.client
        .from('subscriptions')
        .select('id')
        .eq('plan_id', planId)
        .limit(1);
    final hasSubscriptions = (subs as List).isNotEmpty;

    if (!mounted) return;

    if (hasSubscriptions) {
      final kaliColors = Theme.of(context).extension<KaliColorsExtension>()!;
      // No se puede eliminar — ofrecer desactivar
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('No se puede eliminar',
              style: kaliColors.heading(kaliColors.espresso, size: 20)),
          content: Text(
            'El plan "$planName" tiene suscripciones asociadas y no puede eliminarse.\n\n¿Querés desactivarlo? No aparecerá al asignar nuevos planes pero las suscripciones existentes se mantienen.',
            style: kaliColors.body(kaliColors.espresso),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text('Cancelar',
                  style: kaliColors
                      .body(kaliColors.espresso.withValues(alpha: 0.6))),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Desactivar',
                  style: TextStyle(
                      color: Color(0xFFD4685C), fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );

      if (confirmed == true && mounted) {
        try {
          await Supabase.instance.client
              .from('plans')
              .update({'is_active': false}).eq('id', planId);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Plan "$planName" desactivado')),
            );
            _loadPlans();
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text(
                      'No se pudo desactivar el plan. Intentá nuevamente.')),
            );
          }
        }
      }
    } else {
      final kaliColors = Theme.of(context).extension<KaliColorsExtension>()!;
      // Sin suscripciones — eliminar normalmente
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Eliminar Plan',
              style: kaliColors.heading(kaliColors.espresso, size: 20)),
          content: Text(
            '¿Estás seguro de que deseas eliminar el plan "$planName"? Esta acción no se puede deshacer.',
            style: kaliColors.body(kaliColors.espresso),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text('Cancelar',
                  style: kaliColors
                      .body(kaliColors.espresso.withValues(alpha: 0.6))),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Eliminar',
                  style: TextStyle(
                      color: Color(0xFFD4685C), fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );

      if (confirmed == true && mounted) {
        try {
          await Supabase.instance.client
              .from('plans')
              .delete()
              .eq('id', planId);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Plan "$planName" eliminado')),
            );
            _loadPlans();
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content:
                      Text('No se pudo eliminar el plan. Intentá nuevamente.')),
            );
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final kaliColors = Theme.of(context).extension<KaliColorsExtension>()!;
    return Container(
      decoration: BoxDecoration(
        color: kaliColors.warmWhite,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: kaliColors.espresso.withValues(alpha: 0.03),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(kaliColors),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 12.0),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: kaliColors.sand,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: kaliColors.clay.withValues(alpha: 0.5)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline_rounded, color: kaliColors.espresso, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Información sobre pagos: Si optas por automatizar cobros con Mercado Pago, tené en cuenta que existen comisiones por transacción y el dinero puede demorar en liberarse según tu cuenta. Siempre tenés la opción de no automatizar y coordinar pagos por transferencia bancaria u otros medios.',
                      style: kaliColors.body(kaliColors.espresso, size: 13),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(40.0),
              child: Center(child: LinearProgressIndicator()),
            )
          else if (_error != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(40.0),
                child: Text(
                  _error!,
                  style: kaliColors.body(kaliColors.espresso),
                ),
              ),
            )
          else if (_plans.isEmpty)
            Padding(
              padding: const EdgeInsets.all(40.0),
              child: Center(
                child: Text(
                  'Aún no hay planes creados.',
                  style: kaliColors
                      .body(kaliColors.espresso.withValues(alpha: 0.65)),
                ),
              ),
            )
          else ...[
            LayoutBuilder(
              builder: (context, constraints) {
                const double minWidth = 700.0;
                final tableRows = Column(
                  children: [
                    _buildColumnHeaders(kaliColors),
                    ..._plans.map((p) => _PlanRow(
                          plan: p,
                          onEdit: () {
                            showDialog(
                              context: context,
                              builder: (context) => PlanFormDialog(
                                plan: p,
                                onRefresh: _loadPlans,
                              ),
                            );
                          },
                          onDelete: () => _deletePlan(p),
                        )),
                    const SizedBox(height: 24),
                  ],
                );
                if (constraints.maxWidth < minWidth) {
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(width: minWidth, child: tableRows),
                  );
                }
                return tableRows;
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader(KaliColorsExtension kaliColors) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 24, 20, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Text(
                'Planes del Estudio',
                style: kaliColors.headingItalic(kaliColors.espresso, size: 22),
              ),
              if (!_hasMpToken && !_isLoading) ...[
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: () => _handleMercadoPagoLink(context),
                  icon: const Icon(Icons.link, size: 16),
                  label: const Text('Vincular Mercado Pago'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF009EE3),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    elevation: 0,
                  ),
                ),
              ],
            ],
          ),
          Row(
            children: [
              _CreatePlanButton(onCreated: _loadPlans),
              const SizedBox(width: 8),
              KaliIconButton(
                Icons.refresh_rounded,
                tooltip: 'Refrescar planes',
                onTap: _loadPlans,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildColumnHeaders(KaliColorsExtension kaliColors) {
    final style = kaliColors.label(kaliColors.espresso.withValues(alpha: 0.6));

    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 20, 28, 12),
      child: Row(
        children: [
          Expanded(flex: 4, child: Text('PLAN', style: style)),
          Expanded(flex: 3, child: Text('PRECIO', style: style)),
          Expanded(flex: 3, child: Text('RESERVAS', style: style)),
          Expanded(flex: 2, child: Text('ESTADO', style: style)),
          Expanded(flex: 2, child: Text('ACCIONES', style: style)),
        ],
      ),
    );
  }
}

class _CreatePlanButton extends StatefulWidget {
  final VoidCallback onCreated;
  const _CreatePlanButton({required this.onCreated});

  @override
  State<_CreatePlanButton> createState() => _CreatePlanButtonState();
}

class _CreatePlanButtonState extends State<_CreatePlanButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final kaliColors = Theme.of(context).extension<KaliColorsExtension>()!;
    return MouseRegion(
      onEnter: (e) {
        if (e.kind == PointerDeviceKind.mouse) setState(() => _hovered = true);
      },
      onExit: (e) {
        if (e.kind == PointerDeviceKind.mouse) setState(() => _hovered = false);
      },
      child: GestureDetector(
        onTap: () async {
          await showDialog(
            context: context,
            builder: (context) => const PlanFormDialog(),
          );
          widget.onCreated();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: _hovered ? kaliColors.espressoL : kaliColors.espresso,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add, size: 15, color: kaliColors.warmWhite),
              const SizedBox(width: 6),
              Text(
                'Crear Plan',
                style: kaliColors.body(kaliColors.warmWhite,
                    weight: FontWeight.w600, size: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlanRow extends StatefulWidget {
  final Map<String, dynamic> plan;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _PlanRow({
    required this.plan,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<_PlanRow> createState() => _PlanRowState();
}

class _PlanRowState extends State<_PlanRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final kaliColors = Theme.of(context).extension<KaliColorsExtension>()!;
    final p = widget.plan;
    final String name = p['name'] ?? '';
    final String? description = p['description'];
    final double price = (p['price'] as num?)?.toDouble() ?? 0.0;
    final String currency = p['currency'] ?? 'ARS';
    final int maxReservations =
        (p['max_reservations_per_month'] as num?)?.toInt() ?? 8;
    final bool isActive = p['is_active'] ?? true;

    return MouseRegion(
      onEnter: (e) {
        if (e.kind == PointerDeviceKind.mouse) setState(() => _hovered = true);
      },
      onExit: (e) {
        if (e.kind == PointerDeviceKind.mouse) setState(() => _hovered = false);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeIn,
        color: _hovered ? kaliColors.warmWhite : kaliColors.warmWhite,
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
        child: Row(
          children: [
            // Plan name + description
            Expanded(
              flex: 4,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: kaliColors.body(
                      kaliColors.espresso,
                      weight: FontWeight.w600,
                      size: 14,
                    ),
                  ),
                  if (description != null && description.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: kaliColors.body(
                        kaliColors.espresso.withValues(alpha: 0.65),
                        size: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Price & Currency
            Expanded(
              flex: 3,
              child: Text(
                '\$${price.toStringAsFixed(2)} $currency',
                style: kaliColors.body(
                  kaliColors.espresso,
                  weight: FontWeight.w500,
                ),
              ),
            ),

            // Reservations
            Expanded(
              flex: 3,
              child: Text(
                '$maxReservations clases / mes',
                style: kaliColors.body(
                  kaliColors.espresso,
                  weight: FontWeight.w400,
                ),
              ),
            ),

            // Status indicator
            Expanded(
              flex: 2,
              child: _StatusIndicator(isActive: isActive),
            ),

            // Actions
            Expanded(
              flex: 2,
              child: Row(
                children: [
                  KaliIconButton.action(
                    Icons.edit_outlined,
                    tooltip: 'Editar',
                    onTap: widget.onEdit,
                  ),
                  const SizedBox(width: 8),
                  KaliIconButton.action(
                    Icons.delete_outline_rounded,
                    tooltip: 'Eliminar',
                    color: const Color(0xFFD4685C),
                    onTap: widget.onDelete,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusIndicator extends StatelessWidget {
  final bool isActive;
  const _StatusIndicator({required this.isActive});

  @override
  Widget build(BuildContext context) {
    final kaliColors = Theme.of(context).extension<KaliColorsExtension>()!;
    final color = isActive ? const Color(0xFF5C9E6C) : const Color(0xFFD4685C);

    return Row(
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(
          isActive ? 'Activo' : 'Inactivo',
          style: kaliColors.body(color, weight: FontWeight.w500),
        ),
      ],
    );
  }
}
