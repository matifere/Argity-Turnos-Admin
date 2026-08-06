import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:argrity/services/profile_cache.dart';
import 'package:argrity/theme/kali_colors_extension.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DashboardSidebar extends StatefulWidget {
  final String currentPage;
  final void Function(String page) onNavigate;

  const DashboardSidebar({
    super.key,
    required this.currentPage,
    required this.onNavigate,
  });

  @override
  State<DashboardSidebar> createState() => _DashboardSidebarState();
}

class _DashboardSidebarState extends State<DashboardSidebar> {
  // El rol está en el JWT local — sin round trip a la base de datos.
  late final String _role = ProfileCache.role;

  static const _blockedForAdmin = {'Entrenadores', 'Pagos', 'Planes', 'Institución', 'Tema'};

  @override
  void initState() {
    super.initState();
    if (_role == 'admin' && _blockedForAdmin.contains(widget.currentPage)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onNavigate('Alumnos');
      });
    }
    _loadInstitutionData();
  }

  Future<void> _loadInstitutionData() async {
    final instId = ProfileCache.institutionId;
    if (instId == null) return;
    try {
      final data = await Supabase.instance.client
          .from('institutions')
          .select('name, logo_url')
          .eq('id', instId)
          .single();
      if (mounted) {
        ProfileCache.institutionNameNotifier.value = data['name'];
        ProfileCache.institutionLogoNotifier.value = data['logo_url'];
      }
    } catch (e) {
      debugPrint('Error loading institution for sidebar: $e');
    }
  }

  String get currentPage => widget.currentPage;

  @override
  Widget build(BuildContext context) {
    final kaliColors = Theme.of(context).extension<KaliColorsExtension>()!;
    return Material(
        color: kaliColors.sand,
        child: Container(
          width: 240,
          padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ListenableBuilder(
                                  listenable: Listenable.merge([
                                    ProfileCache.institutionNameNotifier,
                                    ProfileCache.institutionLogoNotifier,
                                  ]),
                                  builder: (context, _) {
                                    final logoUrl = ProfileCache.institutionLogoNotifier.value;
                                    final name = ProfileCache.institutionNameNotifier.value;
                                    final hasCustomLogo = logoUrl != null && logoUrl.isNotEmpty && name != null && ProfileCache.hasCustomLogo;
                                    return Row(
                                      children: [
                                        hasCustomLogo
                                            ? ClipRRect(
                                                borderRadius: BorderRadius.circular(8),
                                                child: Image.network(
                                                  logoUrl,
                                                  width: 40,
                                                  height: 40,
                                                  fit: BoxFit.cover,
                                                ),
                                              )
                                            : Image.asset(
                                                'assets/images/logo_naranja.png',
                                                width: 32,
                                                height: 32,
                                                fit: BoxFit.contain,
                                              ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              AutoSizeText(
                                                hasCustomLogo ? name : 'Argity',
                                                style: kaliColors.heading(kaliColors.espresso, size: 28).copyWith(
                                                  fontWeight: FontWeight.w800, 
                                                  letterSpacing: -0.5, 
                                                  height: 1.1
                                                ),
                                                maxLines: 1,
                                                minFontSize: 14,
                                              ),
                                              if (hasCustomLogo) ...[
                                                const SizedBox(height: 2),
                                                AutoSizeText(
                                                  'usando Argity Turnos',
                                                  style: kaliColors.label(kaliColors.espresso.withValues(alpha: 0.6)).copyWith(fontSize: 11),
                                                  maxLines: 1,
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                                const SizedBox(height: 24),
                                Divider(
                                    color: kaliColors.espresso.withValues(alpha: 0.1),
                                    thickness: 1,
                                    height: 1),
                              ],
                            ),
                          ),
                          const SizedBox(height: 48),
                          _buildMenuItem(Icons.grid_view_rounded, 'Panel'),
                          _buildMenuItem(Icons.people_outline, 'Alumnos'),
                          if (_role != 'admin')
                            _buildMenuItem(Icons.fitness_center_outlined, 'Entrenadores'),
                          _buildMenuItem(Icons.calendar_today_outlined, 'Turnos'),
                          _buildMenuItem(Icons.assignment_outlined, 'Rutinas'),
                          _buildMenuItem(Icons.campaign_outlined, 'Notificaciones'),
                          if (_role != 'admin') _buildPagosMenu(kaliColors),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildBottomMenuItem(Icons.help_outline, 'SOPORTE', kaliColors),
                          _buildSettingsMenu(kaliColors),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ));
  }

  Widget _buildMenuItem(IconData icon, String title) {
    final kaliColors = Theme.of(context).extension<KaliColorsExtension>()!;
    final isActive = currentPage == title;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        tileColor: isActive
            ? kaliColors.espresso.withValues(alpha: 0.05)
            : Colors.transparent,
        leading: Icon(
          icon,
          color: isActive
              ? kaliColors.espresso
              : kaliColors.espresso.withValues(alpha: 0.6),
        ),
        title: AutoSizeText(
          title,
          maxLines: 1,
          style: kaliColors.body(
            isActive
                ? kaliColors.espresso
                : kaliColors.espresso.withValues(alpha: 0.6),
            weight: isActive ? FontWeight.bold : FontWeight.w500,
          ),
        ),
        onTap: () => widget.onNavigate(title),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  /// "Pagos" se despliega en dos secciones: cobros/asignaciones de alumnos
  /// y el catálogo de planes.
  Widget _buildPagosMenu(KaliColorsExtension kaliColors) {
    final isSectionActive = currentPage == 'Pagos' || currentPage == 'Planes';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
        ),
        child: ExpansionTile(
          initiallyExpanded: isSectionActive,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16),
          backgroundColor: isSectionActive
              ? kaliColors.espresso.withValues(alpha: 0.05)
              : Colors.transparent,
          collapsedBackgroundColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          collapsedShape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          collapsedIconColor: kaliColors.espresso.withValues(alpha: 0.6),
          iconColor: kaliColors.espresso.withValues(alpha: 0.6),
          leading: Icon(
            Icons.payment_outlined,
            color: isSectionActive
                ? kaliColors.espresso
                : kaliColors.espresso.withValues(alpha: 0.6),
          ),
          title: AutoSizeText(
            'Pagos',
            maxLines: 1,
            style: kaliColors.body(
              isSectionActive
                  ? kaliColors.espresso
                  : kaliColors.espresso.withValues(alpha: 0.6),
              weight: isSectionActive ? FontWeight.bold : FontWeight.w500,
            ),
          ),
          children: [
            _buildPagosSubItem('Alumnos', 'Pagos', kaliColors),
            _buildPagosSubItem('Planes', 'Planes', kaliColors),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }

  Widget _buildPagosSubItem(
      String label, String page, KaliColorsExtension kaliColors) {
    final isActive = currentPage == page;
    return InkWell(
      onTap: () => widget.onNavigate(page),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.only(left: 56, top: 8, bottom: 8, right: 8),
        child: Row(
          children: [
            Expanded(
              child: AutoSizeText(
                label,
                maxLines: 1,
                style: kaliColors.body(
                  isActive
                      ? kaliColors.espresso
                      : kaliColors.espresso.withValues(alpha: 0.6),
                  weight: isActive ? FontWeight.bold : FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomMenuItem(
      IconData icon, String title, KaliColorsExtension kaliColors) {
    return InkWell(
      onTap: () async {
        final url = Uri.parse('https://argity.com');
        try {
          await launchUrl(url);
        } catch (e) {
          debugPrint('No se pudo abrir el enlace: $e');
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Row(
          children: [
            Icon(icon,
                color: kaliColors.espresso.withValues(alpha: 0.65), size: 18),
            const SizedBox(width: 12),
            Expanded(
              child: AutoSizeText(
                title,
                maxLines: 1,
                style:
                    kaliColors.label(kaliColors.espresso.withValues(alpha: 0.65)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsMenu(KaliColorsExtension kaliColors) {
    return Theme(
      data: Theme.of(context).copyWith(
        dividerColor: Colors.transparent, // Remove border lines
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 8),
        collapsedIconColor: kaliColors.espresso.withValues(alpha: 0.65),
        iconColor: kaliColors.espresso.withValues(alpha: 0.65),
        title: Row(
          children: [
            Icon(Icons.settings_outlined,
                color: kaliColors.espresso.withValues(alpha: 0.65), size: 18),
            const SizedBox(width: 12),
            Expanded(
              child: AutoSizeText(
                'CONFIGURACIÓN',
                maxLines: 1,
                style:
                    kaliColors.label(kaliColors.espresso.withValues(alpha: 0.65)),
              ),
            ),
          ],
        ),
        children: [
          _buildSubMenuItem('Cuenta', kaliColors),
          if (_role != 'admin') _buildSubMenuItem('Institución', kaliColors),
          _buildSubMenuItem('Suscripción', kaliColors),
          if (_role != 'admin') _buildSubMenuItem('Tema', kaliColors),
        ],
      ),
    );
  }

  Widget _buildSubMenuItem(String title, KaliColorsExtension kaliColors) {
    final isActive = currentPage == title;
    return InkWell(
      onTap: () => widget.onNavigate(title),
      child: Padding(
        padding: const EdgeInsets.only(left: 40, top: 8, bottom: 8, right: 8),
        child: Row(
          children: [
            Expanded(
              child: AutoSizeText(
                title,
                maxLines: 1,
                style: kaliColors.body(
                  isActive
                      ? kaliColors.espresso
                      : kaliColors.espresso.withValues(alpha: 0.6),
                  weight: isActive ? FontWeight.bold : FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
