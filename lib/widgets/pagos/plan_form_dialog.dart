import 'package:flutter/material.dart';
import 'package:argrity/theme/kali_colors_extension.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Dialog que presenta el formulario de creación o edición de un plan.
class PlanFormDialog extends StatefulWidget {
  final Map<String, dynamic>? plan;
  final VoidCallback? onRefresh;

  const PlanFormDialog({super.key, this.plan, this.onRefresh});

  @override
  State<PlanFormDialog> createState() => _PlanFormDialogState();
}

class _PlanFormDialogState extends State<PlanFormDialog> {
  final _formKey = GlobalKey<FormState>();

  bool _isSaving = false;
  String? _error;

  late String _name;
  String? _description;
  late double _price;
  late String _currency;
  late int _maxReservationsPerMonth;
  late bool _isActive;

  final List<String> _currencies = ['ARS', 'USD'];

  bool get _isEditMode => widget.plan != null;

  @override
  void initState() {
    super.initState();
    if (_isEditMode) {
      final p = widget.plan!;
      _name = p['name'] ?? '';
      _description = p['description'];
      _price = (p['price'] as num?)?.toDouble() ?? 0.0;
      _currency = p['currency'] ?? 'ARS';
      _maxReservationsPerMonth =
          (p['max_reservations_per_month'] as num?)?.toInt() ?? 8;
      _isActive = p['is_active'] ?? true;
    } else {
      _name = '';
      _description = null;
      _price = 0.0;
      _currency = 'ARS';
      _maxReservationsPerMonth = 8;
      _isActive = true;
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      final db = Supabase.instance.client;
      final payload = {
        'name': _name,
        'description': _description,
        'price': _price,
        'currency': _currency,
        'max_reservations_per_month': _maxReservationsPerMonth,
        'is_active': _isActive,
      };

      if (_isEditMode) {
        await db.from('plans').update(payload).eq('id', widget.plan!['id']);
      } else {
        final user = db.auth.currentUser;
        final profile = await db
            .from('profiles')
            .select('institution_id')
            .eq('id', user!.id)
            .maybeSingle();
        final instId = profile?['institution_id'];
        if (instId != null) payload['institution_id'] = instId;

        await db.from('plans').insert(payload);
      }

      if (mounted) {
        widget.onRefresh?.call();
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(_isEditMode
                  ? 'Plan actualizado exitosamente'
                  : 'Plan creado exitosamente')),
        );
      }
    } catch (e) {
      setState(() {
        _isSaving = false;
        _error = 'Error al guardar el plan: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final kaliColors = Theme.of(context).extension<KaliColorsExtension>()!;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: kaliColors.warmWhite,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 450),
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isEditMode ? 'Editar Plan' : 'Crear Nuevo Plan',
                  style: kaliColors.heading(kaliColors.espresso, size: 24),
                ),
                const SizedBox(height: 8),
                Text(
                  _isEditMode
                      ? 'Modifica los datos del plan de pagos.'
                      : 'Define un plan de pagos para los alumnos del estudio.',
                  style: kaliColors
                      .body(kaliColors.espresso.withValues(alpha: 0.6)),
                ),
                const SizedBox(height: 24),

                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: kaliColors.sand,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: kaliColors.clay.withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline_rounded,
                          color: kaliColors.espresso, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Información: Si los alumnos pagan mediante Mercado Pago automatizado, aplicarán comisiones y posibles demoras de liberación. Siempre podés elegir no automatizar y cobrar mediante transferencia bancaria.',
                          style: kaliColors.body(kaliColors.espresso, size: 13),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(_error!,
                        style: const TextStyle(color: Colors.red)),
                  ),

                // Name
                Text('Nombre del Plan',
                    style: kaliColors.label(kaliColors.espresso)),
                const SizedBox(height: 8),
                TextFormField(
                  initialValue: _name,
                  decoration:
                      _inputDecoration('Ej. Plan Mensual 2x', kaliColors),
                  validator: (v) => v == null || v.isEmpty
                      ? 'Requerido'
                      : v.length > 15
                          ? 'Max caract = 15'
                          : null,
                  onSaved: (v) => _name = v!,
                ),
                const SizedBox(height: 16),

                // Description
                Text('Descripción (Opcional)',
                    style: kaliColors.label(kaliColors.espresso)),
                const SizedBox(height: 8),
                TextFormField(
                  initialValue: _description,
                  maxLines: 2,
                  decoration: _inputDecoration(
                      'Ej. Permite hasta 8 reservas por mes', kaliColors),
                  onSaved: (v) => _description = v?.isEmpty == true ? null : v,
                ),
                const SizedBox(height: 16),

                // Price and Currency
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Precio',
                              style: kaliColors.label(kaliColors.espresso)),
                          const SizedBox(height: 8),
                          TextFormField(
                            initialValue: _price == 0.0 && !_isEditMode
                                ? ''
                                : _price.toString(),
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            decoration:
                                _inputDecoration('Ej. 25000', kaliColors),
                            validator: (v) => double.tryParse(v ?? '') == null
                                ? 'Número inválido'
                                : null,
                            onSaved: (v) => _price = double.parse(v!),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 1,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Moneda',
                              style: kaliColors.label(kaliColors.espresso)),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            initialValue: _currency,
                            decoration: _inputDecoration('ARS', kaliColors),
                            items: _currencies.map((c) {
                              return DropdownMenuItem<String>(
                                value: c,
                                child: Text(c,
                                    style:
                                        kaliColors.body(kaliColors.espresso)),
                              );
                            }).toList(),
                            onChanged: (v) {
                              if (v != null) setState(() => _currency = v);
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Max reservations per month
                Text('Máximo de Reservas por Mes',
                    style: kaliColors.label(kaliColors.espresso)),
                const SizedBox(height: 8),
                TextFormField(
                  initialValue: _maxReservationsPerMonth.toString(),
                  keyboardType: TextInputType.number,
                  decoration: _inputDecoration('Ej. 8', kaliColors),
                  validator: (v) =>
                      int.tryParse(v ?? '') == null ? 'Número inválido' : null,
                  onSaved: (v) => _maxReservationsPerMonth = int.parse(v!),
                ),
                const SizedBox(height: 16),

                // Is Active
                SwitchListTile.adaptive(
                  value: _isActive,
                  onChanged: (v) => setState(() => _isActive = v),
                  title: Text('Plan Activo',
                      style: kaliColors.body(kaliColors.espresso, size: 14)),
                  subtitle: Text('Determina si el plan está disponible.',
                      style: kaliColors
                          .caption(kaliColors.espresso.withValues(alpha: 0.6))),
                  activeThumbColor: kaliColors.warmWhite,
                  activeTrackColor: kaliColors.espresso,
                  contentPadding: EdgeInsets.zero,
                ),

                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed:
                          _isSaving ? null : () => Navigator.of(context).pop(),
                      child: Text('Cancelar',
                          style: kaliColors.body(
                              kaliColors.espresso.withValues(alpha: 0.6))),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      onPressed: _isSaving ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kaliColors.espresso,
                        foregroundColor:
                            kaliColors.getContrastColor(kaliColors.espresso),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isSaving
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  color: kaliColors
                                      .getContrastColor(kaliColors.espresso),
                                  strokeWidth: 2))
                          : Text(
                              _isEditMode ? 'Guardar Cambios' : 'Guardar Plan',
                              style: kaliColors.body(
                                  kaliColors
                                      .getContrastColor(kaliColors.espresso),
                                  weight: FontWeight.w600)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(
      String hint, KaliColorsExtension kaliColors) {
    return InputDecoration(
      hintText: hint,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide:
            BorderSide(color: kaliColors.espresso.withValues(alpha: 0.1)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide:
            BorderSide(color: kaliColors.espresso.withValues(alpha: 0.1)),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }
}
