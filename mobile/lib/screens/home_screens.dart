import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/app_theme.dart';
import '../core/care_data.dart';
import '../core/session.dart';
import '../models.dart';
import '../widgets/patient_widgets.dart';
import '../widgets/ui.dart';
import 'care_plan_screens.dart';
import 'home_shell.dart';
import 'medications_screens.dart';
import 'notifications_screen.dart';
import 'observations_screens.dart';
import 'patient_detail_screen.dart';
import 'patient_form_screen.dart';
import 'sos_screen.dart';
import 'team_screens.dart';

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({required this.metrics});
  final List<HeaderMetric> metrics;

  @override
  Widget build(BuildContext context) {
    final session = Session.of(context);
    return GradientHeader(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${greeting()},',
                      style: body(size: 14, color: AppColors.teal100),
                    ),
                    Text(
                      '${session.user.firstName} 👋',
                      style: display(size: 20, color: Colors.white),
                    ),
                  ],
                ),
              ),
              ListenableBuilder(
                listenable: session.notifications,
                builder: (context, _) => HeaderIconButton(
                  icon: Icons.notifications_none,
                  tooltip: 'Notificações',
                  badge: session.notifications.unread,
                  onTap: () => go(context, const NotificationsScreen()),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              for (var i = 0; i < metrics.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                metrics[i],
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// Estrutura comum às telas iniciais: cabeçalho + estados de carregamento.
class _HomeBody extends StatelessWidget {
  const _HomeBody({required this.metrics, required this.children});
  final List<HeaderMetric> metrics;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final store = Session.of(context).store;
    return AppScreen(
      header: _HomeHeader(metrics: metrics),
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
      spacing: 20,
      onRefresh: store.load,
      children: !store.loaded && store.loading
          ? const [LoadingView()]
          : !store.loaded && store.error != null
          ? [ErrorView(error: store.error, onRetry: store.load)]
          : children,
    );
  }
}

// ═══ Início do responsável ══════════════════════════════════════════════════
class HomeResponsavelScreen extends StatelessWidget {
  const HomeResponsavelScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = Session.of(context);
    final store = session.store;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final bundles = store.bundles;
        final late = [for (final b in bundles) ...b.lateDoses];
        final alerts = [
          for (final b in bundles)
            for (final a in b.alerts) (b, a),
        ]..sort((x, y) => y.$2.createdAt.compareTo(x.$2.createdAt));
        final active = alerts.where((item) => item.$2.isActive).toList();
        final observations = [
          for (final b in bundles)
            for (final o in b.observations) (b, o),
        ]..sort((x, y) => y.$2.createdAt.compareTo(x.$2.createdAt));
        final professionals = bundles.fold<int>(
          0,
          (sum, b) => sum + b.patient.professionalsCount,
        );

        return _HomeBody(
          metrics: [
            HeaderMetric(value: bundles.length, label: 'Pacientes'),
            HeaderMetric(
              value: late.length,
              label: 'Atrasados',
              alert: late.isNotEmpty,
            ),
            HeaderMetric(value: professionals, label: 'Profissionais'),
          ],
          children: [
            for (final (bundle, alert) in active.take(2))
              AlertRow(
                tone: Tone.orange,
                icon: Icons.sos_outlined,
                title: 'Acionamento recebido',
                subtitle:
                    '${alert.triggeredBy?.name ?? 'Profissional'} acionou você · ${relativeDateTime(alert.createdAt)}'
                    '${alert.reason == null ? '' : ' · ${alert.reason}'}',
                onTap: () => go(
                  context,
                  PatientDetailScreen(patientId: bundle.patient.id),
                ),
                onClose: () => _acknowledge(context, bundle, alert),
              ),
            if (late.isNotEmpty)
              AlertRow(
                icon: Icons.warning_amber_rounded,
                title: late.length == 1
                    ? 'Medicamento atrasado'
                    : '${late.length} medicamentos atrasados',
                subtitle:
                    '${late.first.medication.label} — ${late.first.patient.firstName} · ${late.first.time}',
                onTap: () => go(
                  context,
                  MedicationsScreen(patientId: late.first.patient.id),
                ),
              ),
            if (bundles.isEmpty)
              AppCard(
                child: EmptyState(
                  icon: Icons.group_outlined,
                  title: 'Nenhum paciente cadastrado',
                  subtitle:
                      'Cadastre o primeiro paciente para gerar o convite da equipe.',
                  action: 'Adicionar paciente',
                  onAction: () => go(context, const PatientFormScreen()),
                ),
              )
            else
              _TodaySummary(bundle: bundles.first),
            if (bundles.isNotEmpty)
              Column(
                children: [
                  SectionHeader(
                    title: 'Meus pacientes',
                    action: 'Ver todos',
                    onAction: () => HomeShell.switchTab(context, 1),
                  ),
                  for (final bundle in bundles.take(2)) ...[
                    _ResponsiblePatientCard(bundle: bundle),
                    const SizedBox(height: 12),
                  ],
                ],
              ),
            Row(
              children: [
                Expanded(
                  child: ActionTileButton(
                    icon: Icons.add,
                    label: 'Adicionar paciente',
                    onTap: () => go(context, const PatientFormScreen()),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ActionTileButton(
                    icon: Icons.person_add_alt_1_outlined,
                    label: 'Convidar profissional',
                    color: AppColors.teal600,
                    onTap: () async {
                      final patient = await pickPatient(
                        context,
                        title: 'Convidar profissional',
                      );
                      if (patient != null && context.mounted) {
                        go(context, InviteScreen(patientId: patient.id));
                      }
                    },
                  ),
                ),
              ],
            ),
            if (observations.isNotEmpty)
              Column(
                children: [
                  SectionHeader(
                    title: 'Observações recentes',
                    action: 'Ver todas',
                    onAction: () => go(
                      context,
                      ObservationsScreen(
                        patientId: observations.first.$1.patient.id,
                      ),
                    ),
                  ),
                  for (final (bundle, item) in observations.take(2)) ...[
                    ObservationPreview(
                      observation: item,
                      onTap: () => go(
                        context,
                        ObservationsScreen(patientId: bundle.patient.id),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ],
              ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SectionHeader(title: 'Solicitações de ajuda'),
                if (alerts.isEmpty)
                  AppCard(
                    child: Text(
                      'Nenhuma solicitação de ajuda registrada.',
                      style: body(size: 13, color: AppColors.slate400),
                    ),
                  )
                else
                  for (final (bundle, alert) in alerts.take(3)) ...[
                    _HelpRequestCard(bundle: bundle, alert: alert),
                    const SizedBox(height: 8),
                  ],
              ],
            ),
          ],
        );
      },
    );
  }

  Future<void> _acknowledge(
    BuildContext context,
    PatientBundle bundle,
    EmergencyAlert alert,
  ) async {
    final session = Session.of(context);
    try {
      await session.api.acknowledgeEmergency(alert.id);
      await session.store.refreshPatient(bundle.patient.id);
      if (context.mounted) {
        showToast(context, 'Acionamento marcado como visualizado.');
      }
    } on ApiException catch (error) {
      if (context.mounted) showToast(context, error.message, error: true);
    }
  }
}

class _TodaySummary extends StatelessWidget {
  const _TodaySummary({required this.bundle});
  final PatientBundle bundle;

  @override
  Widget build(BuildContext context) {
    final p = bundle.todayProgress;
    final ratio = p.total == 0 ? 0.0 : p.done / p.total;
    return AppCard(
      onTap: () => go(context, CarePlanScreen(patientId: bundle.patient.id)),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'RESUMO DE HOJE',
                      style: body(
                        size: 10,
                        weight: FontWeight.w700,
                        color: AppColors.slate400,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${p.done} de ${p.total} cuidados realizados',
                      style: display(size: 16),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${p.late} atrasado${p.late == 1 ? '' : 's'} · ${p.pending} pendente${p.pending == 1 ? '' : 's'} · ${p.activities} atividade${p.activities == 1 ? '' : 's'} terapêutica${p.activities == 1 ? '' : 's'}',
                      style: body(size: 12, color: AppColors.slate400),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              ProgressRing(ratio: ratio),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: SizedBox(
              height: 8,
              child: Stack(
                children: [
                  Container(color: AppColors.slate100),
                  FractionallySizedBox(
                    widthFactor: ratio,
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppColors.teal700, AppColors.emerald400],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Plano de ${bundle.patient.firstName}',
                  style: body(size: 12, color: AppColors.slate500),
                ),
              ),
              Text(
                'Ver plano',
                style: body(
                  size: 12,
                  weight: FontWeight.w700,
                  color: AppColors.teal700,
                ),
              ),
              const Icon(
                Icons.chevron_right,
                size: 14,
                color: AppColors.teal700,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class ProgressRing extends StatelessWidget {
  const ProgressRing({super.key, required this.ratio, this.size = 56});
  final double ratio;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(
      painter: _RingPainter(ratio),
      child: Center(
        child: Container(
          width: size * .72,
          height: size * .72,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
          child: Text(
            '${(ratio * 100).round()}%',
            style: body(
              size: 12,
              weight: FontWeight.w900,
              color: AppColors.teal700,
            ),
          ),
        ),
      ),
    ),
  );
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.ratio);
  final double ratio;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawCircle(
      rect.center,
      size.width / 2,
      Paint()..color = AppColors.slate200,
    );
    canvas.drawArc(
      rect,
      -math.pi / 2,
      2 * math.pi * ratio.clamp(0, 1),
      true,
      Paint()..color = const Color(0xFF14B8A6),
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.ratio != ratio;
}

class _ResponsiblePatientCard extends StatelessWidget {
  const _ResponsiblePatientCard({required this.bundle});
  final PatientBundle bundle;

  @override
  Widget build(BuildContext context) {
    final userId = Session.of(context).user.id;
    return AppCard(
      onTap: () =>
          go(context, PatientDetailScreen(patientId: bundle.patient.id)),
      child: Row(
        children: [
          PatientAvatar(
            patient: bundle.patient,
            badge: bundle.recentObservationsFrom(userId),
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
                        bundle.patient.name,
                        style: display(size: 14, height: 1.2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    StatusBadge(status: bundle.displayStatus),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${bundle.patient.age} anos',
                  style: body(size: 12, color: AppColors.slate400),
                ),
                const SizedBox(height: 6),
                NextDoseLine(bundle: bundle, icon: Icons.schedule),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, size: 18, color: AppColors.slate300),
        ],
      ),
    );
  }
}

class _HelpRequestCard extends StatelessWidget {
  const _HelpRequestCard({required this.bundle, required this.alert});
  final PatientBundle bundle;
  final EmergencyAlert alert;

  @override
  Widget build(BuildContext context) => AppCard(
    onTap: () => go(context, const NotificationsScreen()),
    child: Row(
      children: [
        const IconTile(
          icon: Icons.sos_outlined,
          color: AppColors.orange600,
          bg: AppColors.orange100,
          size: 40,
          radius: 12,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${alert.triggeredBy?.name ?? 'Profissional'} — ${alert.reason ?? alert.message ?? 'Contato'}',
                style: body(
                  size: 14,
                  weight: FontWeight.w600,
                  color: AppColors.slate800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${relativeDateTime(alert.createdAt)} · ${bundle.patient.name}',
                style: body(size: 12, color: AppColors.slate400),
              ),
              const SizedBox(height: 6),
              alert.isActive
                  ? const Pill(
                      'Aguardando resposta',
                      bg: AppColors.orange50,
                      fg: AppColors.orange600,
                    )
                  : const Pill(
                      'Visualizado',
                      bg: AppColors.statusGreenBg,
                      fg: AppColors.statusGreen,
                    ),
            ],
          ),
        ),
        const Icon(Icons.chevron_right, size: 16, color: AppColors.slate300),
      ],
    ),
  );
}

// ═══ Início do profissional ═════════════════════════════════════════════════
class HomeProfissionalScreen extends StatelessWidget {
  const HomeProfissionalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = Session.of(context).store;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final bundles = store.bundles;
        final now = DateTime.now();
        final doses = store.dosesOn(now);
        final activities = store.activitiesOn(now);
        final openDoses = doses.where((d) => d.isOpen).toList()
          ..sort((a, b) {
            if (a.status != b.status) {
              return a.status == DoseStatus.atrasado ? -1 : 1;
            }
            return a.scheduledAt.compareTo(b.scheduledAt);
          });
        final openActivities = activities.where((a) => a.isOpen).toList();
        final total = doses.length + activities.length;
        final done =
            doses.where((d) => d.status == DoseStatus.administrado).length +
            activities
                .where((a) => a.status == ActivityStatus.concluida)
                .length;
        final nextActivity = openActivities.isEmpty
            ? null
            : openActivities.first;
        final upcoming = <(DateTime, String, bool)>[
          for (final d in openDoses)
            (
              d.scheduledAt,
              '${d.medication.label} — ${d.patient.firstName}',
              d.status == DoseStatus.atrasado,
            ),
          for (final a in openActivities)
            (
              a.scheduledAt ?? now,
              '${a.activity.type} — ${a.activity.title}',
              a.status == ActivityStatus.atrasada,
            ),
        ]..sort((x, y) => x.$1.compareTo(y.$1));

        return _HomeBody(
          metrics: [
            HeaderMetric(value: bundles.length, label: 'Pacientes'),
            HeaderMetric(
              value: openDoses.length + openActivities.length,
              label: 'Pendentes hoje',
            ),
            HeaderMetric(value: activities.length, label: 'Atividades'),
          ],
          children: [
            if (openDoses.isNotEmpty)
              AlertRow(
                tone: Tone.orange,
                icon: Icons.schedule,
                title: 'Confirmação pendente',
                subtitle:
                    '${openDoses.first.medication.label} — ${openDoses.first.patient.firstName} — ${openDoses.first.time}'
                    '${openDoses.first.status == DoseStatus.atrasado ? ' (atrasado)' : ''}',
                onTap: () => go(
                  context,
                  MedicationsScreen(patientId: openDoses.first.patient.id),
                ),
              ),
            if (bundles.isEmpty)
              AppCard(
                child: EmptyState(
                  icon: Icons.link,
                  title: 'Nenhum paciente vinculado',
                  subtitle: 'Use o código de convite recebido do responsável.',
                  action: 'Vincular paciente',
                  onAction: () => HomeShell.switchTab(context, 1),
                ),
              )
            else
              Material(
                color: AppColors.blue50,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: AppColors.blue200),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () async {
                    final patient = await pickPatient(
                      context,
                      title: 'Plano de cuidados',
                    );
                    if (patient != null && context.mounted) {
                      go(context, CarePlanScreen(patientId: patient.id));
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const IconTile(
                          icon: Icons.assignment_outlined,
                          color: AppColors.blue700,
                          bg: AppColors.blue100,
                          size: 44,
                          radius: 12,
                          iconSize: 21,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Plano de cuidados de hoje',
                                style: display(
                                  size: 14,
                                  color: AppColors.blue900,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '$done de $total realizados'
                                '${nextActivity == null ? '' : ' · ${nextActivity.activity.type.toLowerCase()} às ${nextActivity.activity.timeLabel}'}',
                                style: body(
                                  size: 12,
                                  color: AppColors.blue700.withValues(
                                    alpha: .7,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(99),
                                child: LinearProgressIndicator(
                                  value: total == 0 ? 0 : done / total,
                                  minHeight: 6,
                                  backgroundColor: AppColors.blue100,
                                  color: AppColors.blue600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.chevron_right,
                          size: 18,
                          color: AppColors.blue400,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            if (bundles.isNotEmpty)
              Column(
                children: [
                  SectionHeader(
                    title: 'Meus pacientes',
                    action: 'Ver todos',
                    onAction: () => HomeShell.switchTab(context, 1),
                  ),
                  for (final bundle in bundles.take(2)) ...[
                    AppCard(
                      onTap: () => go(
                        context,
                        PatientDetailScreen(patientId: bundle.patient.id),
                      ),
                      child: Row(
                        children: [
                          PatientAvatar(patient: bundle.patient),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  bundle.patient.name,
                                  style: display(size: 14),
                                ),
                                Text(
                                  '${bundle.patient.age} anos · ${firstCondition(bundle.patient)}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: body(
                                    size: 12,
                                    color: AppColors.slate400,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                NextDoseLine(
                                  bundle: bundle,
                                  prefix: 'Próximo: ',
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right,
                            size: 18,
                            color: AppColors.slate300,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
              ),
            Row(
              children: [
                Expanded(
                  child: ActionTileButton(
                    icon: Icons.note_alt_outlined,
                    label: 'Nova observação',
                    color: AppColors.teal600,
                    onTap: () async {
                      final patient = await pickPatient(
                        context,
                        title: 'Nova evolução',
                      );
                      if (patient != null && context.mounted) {
                        go(
                          context,
                          NewObservationScreen(patientId: patient.id),
                        );
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ActionTileButton(
                    icon: Icons.sos_outlined,
                    label: 'Acionar responsável',
                    gradient: contactButtonGradient,
                    onTap: () async {
                      final patient = await pickPatient(
                        context,
                        title: 'Acionar responsável',
                        trailingIcon: Icons.sos_outlined,
                        trailingColor: AppColors.red600,
                        trailingBg: AppColors.red50,
                      );
                      if (patient != null && context.mounted) {
                        go(context, SosScreen(patientId: patient.id));
                      }
                    },
                  ),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SectionHeader(title: 'Próximas atividades'),
                if (upcoming.isEmpty)
                  _UpcomingRow(
                    time: '',
                    text: 'Tudo em dia por hoje.',
                    late: false,
                  )
                else
                  for (final (at, text, late) in upcoming.take(4)) ...[
                    _UpcomingRow(time: hhmm(at), text: text, late: late),
                    const SizedBox(height: 8),
                  ],
              ],
            ),
          ],
        );
      },
    );
  }
}

class _UpcomingRow extends StatelessWidget {
  const _UpcomingRow({
    required this.time,
    required this.text,
    required this.late,
  });
  final String time;
  final String text;
  final bool late;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.slate100),
    ),
    child: Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: late ? AppColors.red500 : AppColors.teal600,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 40,
          child: Text(
            time,
            style: body(
              size: 12,
              weight: FontWeight.w600,
              color: AppColors.slate500,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(text, style: body(size: 14, color: AppColors.slate700)),
        ),
      ],
    ),
  );
}
