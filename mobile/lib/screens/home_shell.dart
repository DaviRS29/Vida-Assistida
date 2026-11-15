import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../core/session.dart';
import 'agenda_screen.dart';
import 'history_screens.dart';
import 'home_screens.dart';
import 'patients_screen.dart';
import 'profile_screens.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  static void switchTab(BuildContext context, int index) =>
      context.findAncestorStateOfType<_HomeShellState>()?.select(index);

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  void select(int index) => setState(() => _index = index);

  @override
  Widget build(BuildContext context) {
    final session = Session.of(context);
    final professional = session.professional;
    final pages = <Widget>[
      professional
          ? const HomeProfissionalScreen()
          : const HomeResponsavelScreen(),
      const PatientsScreen(),
      const AgendaScreen(),
      const GlobalHistoryScreen(),
      const ProfileScreen(),
    ];
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: ListenableBuilder(
        listenable: session.notifications,
        builder: (context, _) => _BottomNav(
          index: _index,
          professional: professional,
          unread: session.notifications.unread,
          onChanged: select,
        ),
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({
    required this.index,
    required this.professional,
    required this.unread,
    required this.onChanged,
  });

  final int index;
  final bool professional;
  final int unread;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final tabs = [
      (Icons.home_outlined, professional ? 'Plantão' : 'Início'),
      (Icons.group_add_outlined, 'Pacientes'),
      (Icons.calendar_month_outlined, professional ? 'Rotina' : 'Agenda'),
      (Icons.history, professional ? 'Registros' : 'Histórico'),
      (Icons.person_outline, 'Perfil'),
    ];
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.slate100)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              for (var i = 0; i < tabs.length; i++)
                _NavButton(
                  icon: tabs[i].$1,
                  label: tabs[i].$2,
                  active: i == index,
                  badge: i == 0 ? unread : 0,
                  onTap: () => onChanged(i),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.icon,
    required this.label,
    required this.active,
    required this.badge,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final int badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.teal700 : AppColors.slate400;
    return Semantics(
      selected: active,
      button: true,
      label: label,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(icon, size: 24, color: color),
                  if (badge > 0)
                    Positioned(
                      top: -4,
                      right: -4,
                      child: Container(
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          color: AppColors.red600,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          badge > 9 ? '9+' : '$badge',
                          style: body(
                            size: 9,
                            weight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: body(size: 10, weight: FontWeight.w600, color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
