import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../core/care_data.dart';
import '../core/session.dart';
import '../widgets/ui.dart';
import 'care_plan_screens.dart';
import 'medications_screens.dart';

class AgendaScreen extends StatefulWidget {
  const AgendaScreen({super.key});

  @override
  State<AgendaScreen> createState() => _AgendaScreenState();
}

class _AgendaScreenState extends State<AgendaScreen> {
  /// Índice do dia na semana atual (0 = domingo).
  late int _selected = DateTime.now().weekday % 7;

  @override
  Widget build(BuildContext context) {
    final session = Session.of(context);
    final store = session.store;
    final responsible = !session.professional;
    final today = dayOf(DateTime.now());
    final todayIndex = today.weekday % 7;
    final weekStart = today.subtract(Duration(days: todayIndex));
    final day = weekStart.add(Duration(days: _selected));

    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final doses = store.dosesOn(day);
        final activities = store.activitiesOn(day);
        final items = <_AgendaItem>[
          for (final d in doses) _AgendaItem.dose(d),
          for (final a in activities) _AgendaItem.activity(a),
        ]..sort((a, b) => a.time.compareTo(b.time));
        final done = items.where((i) => i.done).length;
        final late = items.where((i) => i.late).length;
        final pending = items.where((i) => i.open).length;

        return AppScreen(
          onRefresh: store.load,
          header: GradientHeader(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  responsible ? 'Agenda do cuidado' : 'Minha rotina',
                  style: display(size: 24, color: Colors.white),
                ),
                const SizedBox(height: 4),
                Text(
                  responsible
                      ? 'Visão geral de horários e pendências'
                      : 'Atividades que exigem sua ação',
                  style: body(size: 12, color: AppColors.teal100),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    for (var i = 0; i < 7; i++) ...[
                      if (i > 0) const SizedBox(width: 4),
                      Expanded(
                        child: _DayButton(
                          label: weekdaysShort[i],
                          date: weekStart.add(Duration(days: i)).day,
                          selected: i == _selected,
                          today: i == todayIndex,
                          onTap: () => setState(() => _selected = i),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          belowHeader: [
            SummaryBar(
              valueSize: 16,
              items: [
                ('Total', items.length, AppColors.teal600),
                ('Feitos', done, AppColors.statusGreen),
                ('Pendentes', pending, AppColors.slate500),
                ('Atrasados', late, AppColors.statusRed),
              ],
            ),
          ],
          children: [
            const RoleContext(),
            if (!store.loaded && store.loading)
              const LoadingView()
            else if (items.isEmpty)
              const EmptyState(
                icon: Icons.calendar_month_outlined,
                title: 'Nenhuma atividade',
                subtitle:
                    'Sem medicamentos ou atividades programadas para este dia.',
              )
            else
              for (final item in items)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 56,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 14),
                        child: Text(
                          item.timeLabel,
                          textAlign: TextAlign.right,
                          style: body(
                            size: 12,
                            weight: FontWeight.w700,
                            color: AppColors.slate500,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppCard(
                        padding: const EdgeInsets.all(14),
                        onTap: () => go(
                          context,
                          item.activityId == null
                              ? MedicationsScreen(patientId: item.patientId)
                              : ActivityDetailScreen(
                                  patientId: item.patientId,
                                  activityId: item.activityId!,
                                ),
                        ),
                        child: Row(
                          children: [
                            IconTile(
                              icon: item.activityId == null
                                  ? Icons.medication_outlined
                                  : Icons.assignment_outlined,
                              color: item.done
                                  ? AppColors.green700
                                  : item.late
                                  ? AppColors.red600
                                  : item.activityId == null
                                  ? AppColors.teal700
                                  : AppColors.blue700,
                              bg: item.done
                                  ? AppColors.green100
                                  : item.late
                                  ? AppColors.red100
                                  : item.activityId == null
                                  ? AppColors.teal50
                                  : AppColors.blue50,
                              size: 36,
                              radius: 8,
                              iconSize: 16,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.title,
                                    style: body(
                                      size: 14,
                                      weight: FontWeight.w600,
                                      color: AppColors.slate800,
                                    ),
                                  ),
                                  Text(
                                    '${item.patient} · ${item.activityId == null ? 'Medicamento' : 'Atividade'}',
                                    style: body(
                                      size: 12,
                                      color: AppColors.slate400,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            item.badge,
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
          ],
        );
      },
    );
  }
}

class _AgendaItem {
  _AgendaItem.dose(DoseSlot slot)
    : time = slot.scheduledAt,
      timeLabel = slot.time,
      title = slot.medication.label,
      patient = slot.patient.firstName,
      patientId = slot.patient.id,
      activityId = null,
      done = slot.status == DoseStatus.administrado,
      late = slot.status == DoseStatus.atrasado,
      open = slot.isOpen,
      badge = MedStatusBadge(status: slot.status);

  _AgendaItem.activity(ActivitySlot slot)
    : time = slot.scheduledAt ?? DateTime(9999),
      timeLabel = slot.activity.timeLabel,
      title = [slot.activity.title, ?slot.activity.series].join(' '),
      patient = slot.patient.firstName,
      patientId = slot.patient.id,
      activityId = slot.activity.id,
      done = slot.status == ActivityStatus.concluida,
      late = slot.status == ActivityStatus.atrasada,
      open = slot.isOpen,
      badge = ActivityStatusBadge(status: slot.status);

  final DateTime time;
  final String timeLabel;
  final String title;
  final String patient;
  final String patientId;
  final String? activityId;
  final bool done;
  final bool late;
  final bool open;
  final Widget badge;
}

class _DayButton extends StatelessWidget {
  const _DayButton({
    required this.label,
    required this.date,
    required this.selected,
    required this.today,
    required this.onTap,
  });

  final String label;
  final int date;
  final bool selected;
  final bool today;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: selected ? Colors.white : Colors.white.withValues(alpha: .15),
    borderRadius: BorderRadius.circular(12),
    child: InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: [
            Text(
              label,
              style: body(
                size: 10,
                weight: FontWeight.w600,
                color: selected ? AppColors.teal700 : AppColors.teal100,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '$date',
              style: body(
                size: 14,
                weight: FontWeight.w700,
                color: selected ? AppColors.teal700 : Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: today
                    ? (selected ? AppColors.teal700 : AppColors.teal200)
                    : Colors.transparent,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
