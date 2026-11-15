import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../core/care_data.dart';
import '../core/session.dart';
import '../models.dart';
import '../widgets/ui.dart';
import 'medications_screens.dart';
import 'patient_detail_screen.dart';

Color _colorFor(String type) {
  if (type == 'med_atrasado' ||
      type == 'atividade_atrasada' ||
      type == 'acionamento' ||
      type == 'med_nao_administrado') {
    return const Color(0xFFD32F2F);
  }
  if (type == 'obs_urgente') return const Color(0xFFF57C00);
  if (type == 'profissional_vinculado') return const Color(0xFF059669);
  if (type == 'permissao') return AppColors.purple;
  return AppColors.teal600;
}

IconData _iconFor(String type) {
  if (type.startsWith('atividade') || type == 'plano_atualizado') {
    return Icons.assignment_outlined;
  }
  if (type.startsWith('med')) return Icons.medication_outlined;
  if (type == 'obs_urgente') return Icons.warning_amber_rounded;
  if (type.startsWith('obs')) return Icons.note_alt_outlined;
  if (type == 'profissional_vinculado') return Icons.groups_outlined;
  if (type.startsWith('acionamento')) return Icons.sos_outlined;
  if (type == 'permissao') return Icons.shield_outlined;
  return Icons.notifications_none;
}

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = Session.of(context);
    final center = session.notifications;
    return ListenableBuilder(
      listenable: center,
      builder: (context, _) {
        final items = center.items;
        final unread = items.where((n) => !n.read).toList();
        final read = items.where((n) => n.read).toList();
        return AppScreen(
          onRefresh: () => center.refresh(bundles: session.store.bundles),
          header: GradientHeader(
            onBack: () => Navigator.pop(context),
            child: HeaderTitle(
              'Notificações',
              subtitle: unread.isEmpty ? null : '${unread.length} não lidas',
              trailing: unread.isEmpty
                  ? null
                  : Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: InkWell(
                        onTap: center.markAll,
                        child: Text(
                          'Marcar todas como lidas',
                          style: body(
                            size: 12,
                            weight: FontWeight.w600,
                            color: AppColors.teal100,
                          ),
                        ),
                      ),
                    ),
            ),
          ),
          spacing: 8,
          children: [
            if (items.isEmpty)
              const EmptyState(
                icon: Icons.notifications_none,
                title: 'Sem notificações',
                subtitle: 'Você está em dia com tudo!',
              ),
            if (unread.isNotEmpty) const _Section('Não lidas'),
            for (final item in unread)
              _NotificationTile(
                item: item,
                onTap: () {
                  center.markRead(item);
                  _open(context, item);
                },
              ),
            if (read.isNotEmpty) const _Section('Anteriores', top: 12),
            for (final item in read)
              _NotificationTile(item: item, onTap: () => _open(context, item)),
            const SizedBox(height: 8),
            Text(
              'Por privacidade, as notificações não exibem informações clínicas detalhadas.',
              textAlign: TextAlign.center,
              style: body(size: 11, color: AppColors.slate400),
            ),
          ],
        );
      },
    );
  }

  void _open(BuildContext context, AppNotification item) {
    final patientId = item.patientId;
    if (patientId == null) return;
    if (item.type.startsWith('med')) {
      go(context, MedicationsScreen(patientId: patientId));
    } else {
      go(context, PatientDetailScreen(patientId: patientId));
    }
  }
}

class _Section extends StatelessWidget {
  const _Section(this.text, {this.top = 4});
  final String text;
  final double top;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(4, top, 4, 4),
    child: Text(
      text.toUpperCase(),
      style: body(
        size: 12,
        weight: FontWeight.w700,
        color: AppColors.slate400,
        letterSpacing: .8,
      ),
    ),
  );
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.item, required this.onTap});
  final AppNotification item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final unread = !item.read;
    final color = _colorFor(item.type);
    return Material(
      color: unread ? AppColors.teal50 : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: unread ? AppColors.teal100 : AppColors.slate100,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Opacity(
                opacity: unread ? 1 : .7,
                child: IconTile(
                  icon: _iconFor(item.type),
                  color: Colors.white,
                  bg: color,
                  size: 40,
                  radius: 12,
                  iconSize: 16,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            style: body(
                              size: 14,
                              weight: unread
                                  ? FontWeight.w700
                                  : FontWeight.w600,
                              color: unread
                                  ? AppColors.slate800
                                  : AppColors.slate600,
                            ),
                          ),
                        ),
                        if (unread)
                          Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.only(top: 6, left: 8),
                            decoration: const BoxDecoration(
                              color: AppColors.teal600,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.body,
                      style: body(
                        size: 12,
                        color: unread ? AppColors.slate500 : AppColors.slate400,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      relativeDateTime(item.createdAt),
                      style: body(
                        size: 12,
                        color: unread ? AppColors.slate400 : AppColors.slate300,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
