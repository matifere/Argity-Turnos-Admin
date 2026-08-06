import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:argrity/bloc/navigation/navigation_bloc.dart';
import 'package:argrity/theme/kali_colors_extension.dart';
import 'package:argrity/widgets/dashboard/chimpy_assistant.dart';
import 'package:argrity/widgets/dashboard/sidebar.dart';
import 'package:argrity/widgets/dashboard/stat_cards.dart';
import 'package:argrity/widgets/dashboard/schedule_list.dart';
import 'package:argrity/widgets/dashboard/join_qr_dialog.dart';
import 'package:argrity/screens/alumnos_screen.dart';
import 'package:argrity/screens/entrenadores_screen.dart';
import 'package:argrity/screens/turnos_screen.dart';
import 'package:argrity/screens/rutinas_screen.dart';
import 'package:argrity/screens/pagos_screen.dart';
import 'package:argrity/screens/notificaciones_screen.dart';
import 'package:argrity/screens/settings/settings_theme_screen.dart';
import 'package:argrity/screens/settings/settings_subscription_screen.dart';
import 'package:argrity/screens/settings/settings_account_screen.dart';
import 'package:argrity/screens/settings/settings_institution_screen.dart';
import 'package:argrity/bloc/dashboard/dashboard_bloc.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  Widget _buildCurrentPage(String page) {
    switch (page) {
      case 'Alumnos':
        return const AlumnosScreen();
      case 'Entrenadores':
        return const EntrenadoresScreen();
      case 'Turnos':
        return const TurnosScreen();
      case 'Rutinas':
        return const RutinasScreen();
      case 'Notificaciones':
        return const NotificacionesScreen();
      case 'Pagos':
        return const PagosScreen(view: PagosView.alumnos);
      case 'Planes':
        return const PagosScreen(view: PagosView.planes);
      case 'Cuenta':
        return const SettingsAccountScreen();
      case 'Institución':
        return const SettingsInstitutionScreen();
      case 'Suscripción':
        return const SettingsSubscriptionScreen();
      case 'Tema':
        return const SettingsThemeScreen();
      default:
        return const _DashboardHome();
    }
  }

  @override
  Widget build(BuildContext context) {
    final kaliColors = Theme.of(context).extension<KaliColorsExtension>()!;
    final bool isMobile = MediaQuery.of(context).size.width < 1100;

    return BlocBuilder<NavigationBloc, NavigationState>(
      builder: (context, navState) {
        return Scaffold(
          backgroundColor: kaliColors.warmWhite,
          appBar: isMobile
              ? AppBar(
                  backgroundColor: kaliColors.warmWhite,
                  elevation: 0,
                  iconTheme: IconThemeData(color: kaliColors.espresso),
                  title: Text(
                    'Argity',
                    style: kaliColors
                        .heading(kaliColors.espresso, size: 20)
                        .copyWith(fontWeight: FontWeight.bold),
                  ),
                )
              : null,
          drawer: isMobile
              ? Drawer(
                  child: DashboardSidebar(
                    currentPage: navState.currentPage,
                    onNavigate: (page) {
                      context.read<NavigationBloc>().add(
                            NavigationPageChanged(page),
                          );
                      Navigator.of(context).pop(); // Cerrar drawer al navegar
                    },
                  ),
                )
              : null,
          body: Row(
            children: [
              if (!isMobile)
                DashboardSidebar(
                  currentPage: navState.currentPage,
                  onNavigate: (page) {
                    context.read<NavigationBloc>().add(
                          NavigationPageChanged(page),
                        );
                  },
                ),
              Expanded(child: _buildCurrentPage(navState.currentPage)),
            ],
          ),
        );
      },
    );
  }
}

// ─── Dashboard home content ───────────────────────────────────────────────────
class _DashboardHome extends StatefulWidget {
  const _DashboardHome();

  @override
  State<_DashboardHome> createState() => _DashboardHomeState();
}

class _DashboardHomeState extends State<_DashboardHome> {
  bool _chimpyOpen = false;

  @override
  void initState() {
    super.initState();
    final bloc = context.read<DashboardBloc>();
    if (!bloc.state.isLoading) {
      bloc.add(DashboardLoadRequested());
    }
  }

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Buenos días,';
    if (hour < 19) return 'Buenas tardes,';
    return 'Buenas noches,';
  }

  Widget _buildJoinCode(
      BuildContext context, String? code, KaliColorsExtension kaliColors) {
    if (code == null) return const SizedBox.shrink();
    final formatted = code;
    return Container(
      margin: const EdgeInsets.only(top: 24),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: kaliColors.sand.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kaliColors.espresso.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: kaliColors.warmWhite,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.qr_code_2_rounded,
                color: kaliColors.espresso.withValues(alpha: 0.8)),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Código de acceso para alumnos',
                  style: kaliColors
                      .label(kaliColors.espresso.withValues(alpha: 0.8))),
              const SizedBox(height: 2),
              SelectableText(
                formatted,
                style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                    color: kaliColors.espresso),
              ),
            ],
          ),
          const SizedBox(width: 32),
          IconButton(
            tooltip: 'Copiar código',
            icon: Icon(Icons.copy_rounded, color: kaliColors.clayDark),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: formatted));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Código copiado al portapapeles')),
                );
              }
            },
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Ver código QR',
            icon:
                Icon(Icons.qr_code_scanner_rounded, color: kaliColors.clayDark),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => JoinQrDialog(joinCode: code),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final kaliColors = Theme.of(context).extension<KaliColorsExtension>()!;
    final bool isSmall = MediaQuery.of(context).size.width < 600;

    return Stack(
      children: [
        Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: isSmall ? 20 : 40,
                  vertical: 32,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AutoSizeText(_greeting,
                        style: kaliColors
                            .heading(kaliColors.espresso,
                                size: isSmall ? 32 : 40)
                            .copyWith(fontWeight: FontWeight.w600),
                        maxLines: 1),
                    const SizedBox(height: 8),
                    Text(
                      'Esto es lo que está pasando hoy.',
                      style: kaliColors.body(
                        kaliColors.espresso.withValues(alpha: 0.6),
                        size: 16,
                      ),
                    ),
                    BlocBuilder<DashboardBloc, DashboardState>(
                      builder: (context, state) {
                        if (state.isLoading) return const SizedBox.shrink();
                        return _buildJoinCode(
                            context, state.joinCode, kaliColors);
                      },
                    ),
                    const SizedBox(height: 32),
                    const DashboardStatCards(),
                    const SizedBox(height: 32),
                    const DashboardScheduleList(),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
        Positioned(
          right: isSmall ? 16 : 24,
          bottom: isSmall ? 16 : 24,
          child: ChimpyAssistant(
            open: _chimpyOpen,
            onToggle: () => setState(() => _chimpyOpen = !_chimpyOpen),
          ),
        ),
      ],
    );
  }
}
