import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../core/care_data.dart';
import '../core/session.dart';
import '../widgets/ui.dart';
import 'care_plan_screens.dart';
import 'history_screens.dart';
import 'medications_screens.dart';
import 'observations_screens.dart';
import 'patient_form_screen.dart';
import 'sos_screen.dart';
import 'team_screens.dart';

class PatientDetailScreen extends StatefulWidget {
  const PatientDetailScreen({super.key, required this.patientId});
  final String patientId;

  @override
  State<PatientDetailScreen> createState() => _PatientDetailScreenState();
}

class _PatientDetailScreenState extends State<PatientDetailScreen> {
  String _tab = 'resumo';
  bool _requested = false;

  @override
  Widget build(BuildContext context) {
    final session = Session.of(context);
    final store = session.store;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final bundle = store.bundleFor(widget.patientId);
        if (bundle == null) {
          if (!_requested) {
            _requested = true;
            store
                .refreshPatient(widget.patientId)
                .then((_) {}, onError: (_) {});
          }
          return AppScreen(
            header: GradientHeader(
              onBack: () => Navigator.pop(context),
              child: const HeaderTitle('Paciente'),
            ),
            children: const [LoadingView()],
          );
        }
        final patient = bundle.patient;
        final responsible = !session.professional;
        return AppScreen(
          onRefresh: () => store.refreshPatient(patient.id),
          header: GradientHeader(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            onBack: () => Navigator.pop(context),
            child: Row(
              children: [
                Avatar(
                  initials: initials(patient.name),
                  color: Colors.white.withValues(alpha: .25),
                  size: 64,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        patient.name,
                        style: display(
                          size: 20,
                          color: Colors.white,
                          height: 1.2,
                        ),
                      ),
                      Text(
                        '${patient.age} anos · Resp.: ${patient.responsibleName ?? '—'}',
                        style: body(size: 14, color: AppColors.teal100),
                      ),
                      const SizedBox(height: 6),
                      StatusBadge(status: bundle.displayStatus),
                    ],
                  ),
                ),
                Align(
                  alignment: Alignment.topCenter,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .2),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      responsible ? 'GESTÃO' : 'ASSISTÊNCIA',
                      style: body(
                        size: 10,
                        weight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          belowHeader: [
            _Tabs(
              selected: _tab,
              onChanged: (value) => setState(() => _tab = value),
            ),
          ],
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
          spacing: 16,
          children: [
            const RoleContext(),
            if (_tab == 'resumo')
              ..._summary(context, bundle, responsible)
            else
              ..._data(context, bundle, responsible),
          ],
        );
      },
    );
  }

  List<Widget> _summary(
    BuildContext context,
    PatientBundle bundle,
    bool responsible,
  ) {
    final patient = bundle.patient;
    final id = patient.id;
    final shortcuts = <(String, IconData, Color, Color, Widget Function())>[
      (
        'Plano de cuidados',
        Icons.assignment_outlined,
        AppColors.blueStrong,
        AppColors.blueSoft,
        () => CarePlanScreen(patientId: id),
      ),
      (
        'Medicamentos',
        Icons.medication_outlined,
        AppColors.teal600,
        AppColors.teal50,
        () => MedicationsScreen(patientId: id),
      ),
      (
        'Observações',
        Icons.note_alt_outlined,
        AppColors.statusGreen,
        AppColors.statusGreenBg,
        () => ObservationsScreen(patientId: id),
      ),
      (
        'Histórico',
        Icons.history,
        AppColors.purple,
        AppColors.purpleBg,
        () => PatientHistoryScreen(patientId: id),
      ),
      if (responsible) ...[
        (
          'Equipe',
          Icons.groups_outlined,
          const Color(0xFF00695C),
          const Color(0xFFE0F2F1),
          () => TeamScreen(patientId: id),
        ),
        (
          'Convite',
          Icons.person_add_alt_1_outlined,
          const Color(0xFF4527A0),
          const Color(0xFFEDE7F6),
          () => InviteScreen(patientId: id),
        ),
      ] else ...[
        (
          'Nova evolução',
          Icons.assignment_outlined,
          AppColors.blueStrong,
          AppColors.blueSoft,
          () => NewObservationScreen(patientId: id),
        ),
        (
          'Contatar responsável',
          Icons.phone_outlined,
          AppColors.blue700,
          AppColors.blue100,
          () => SosScreen(patientId: id),
        ),
      ],
    ];

    final next = bundle.nextDose;
    final last = bundle.lastAdministration;
    final lastMed = last == null
        ? null
        : bundle.medicationById(last.medicationId);
    final lastObs = bundle.observations.isEmpty
        ? null
        : bundle.observations.first;
    final alerts = bundle.activeAlertCount;
    final summaryRows = <(String, String, Color, IconData)>[
      (
        'Próximo medicamento',
        bundle.medicationsDenied
            ? 'Sem permissão para consultar'
            : next == null
            ? 'Nenhum pendente hoje'
            : '${next.medication.label} · ${next.time}',
        next?.status == DoseStatus.atrasado
            ? AppColors.statusRed
            : AppColors.teal600,
        Icons.medication_outlined,
      ),
      (
        'Última administração',
        last == null
            ? 'Nenhuma registrada'
            : '${lastMed?.label ?? 'Medicamento'} · ${hhmm(last.administeredAt ?? last.createdAt)}'
                  ' (${last.recordedBy?.name ?? 'equipe'})',
        AppColors.statusGreen,
        Icons.check,
      ),
      (
        'Última observação',
        lastObs == null
            ? 'Nenhuma registrada'
            : '${relativeDateTime(lastObs.createdAt)} — ${lastObs.author?.name ?? 'Equipe'}',
        AppColors.slate500,
        Icons.note_alt_outlined,
      ),
      (
        'Alertas ativos',
        alerts == 0
            ? 'Nenhum alerta'
            : '$alerts alerta${alerts == 1 ? '' : 's'} de atenção',
        alerts == 0 ? AppColors.slate400 : AppColors.statusOrange,
        Icons.warning_amber_rounded,
      ),
    ];

    return [
      if (bundle.displayStatus == 'atencao')
        InfoBanner(
          tone: Tone.orange,
          icon: Icons.warning_amber_rounded,
          title: 'Atenção necessária',
          text: _attentionText(bundle),
        ),
      GridView.count(
        crossAxisCount: 3,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: .95,
        children: [
          for (final (label, icon, color, bg, build) in shortcuts)
            AppCard(
              padding: const EdgeInsets.all(12),
              onTap: () => go(context, build()),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconTile(
                    icon: icon,
                    color: color,
                    bg: bg,
                    size: 48,
                    radius: 12,
                    iconSize: 22,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    style: body(
                      size: 12,
                      weight: FontWeight.w600,
                      color: AppColors.slate700,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Resumo atual', style: display(size: 14)),
            const SizedBox(height: 12),
            for (var i = 0; i < summaryRows.length; i++) ...[
              if (i > 0) const Divider(height: 20, color: AppColors.slate50),
              Builder(
                builder: (context) {
                  final (label, value, color, icon) = summaryRows[i];
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      IconTile(
                        icon: icon,
                        color: color,
                        bg: color.withValues(alpha: .09),
                        size: 24,
                        radius: 8,
                        iconSize: 14,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              label,
                              style: body(size: 12, color: AppColors.slate400),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              value,
                              style: body(
                                size: 14,
                                weight: FontWeight.w600,
                                color: color,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ],
        ),
      ),
      if (responsible) InviteCodeCard(patient: patient, showRotate: true),
    ];
  }

  List<Widget> _data(
    BuildContext context,
    PatientBundle bundle,
    bool responsible,
  ) {
    final p = bundle.patient;
    final birth = DateTime.tryParse(p.birthDate);
    String v(String? value) =>
        value == null || value.trim().isEmpty ? 'Não informado' : value;
    final rows = [
      ('Nome completo', p.name),
      ('Data de nascimento', birth == null ? p.birthDate : ddmmyyyy(birth)),
      ('Condições', v(p.conditions)),
      ('Alergias', v(p.allergies)),
      ('Restrições', v(p.restrictions)),
      ('Contato principal', v(p.contactMain)),
      ('Contato alternativo', v(p.contactAlt)),
      ('Observações gerais', v(p.notes)),
    ];
    final canEdit = responsible || p.permissions.canEditPatient;
    return [
      for (final (label, value) in rows)
        AppCard(
          child: SizedBox(
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: body(size: 12, color: AppColors.slate400)),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: body(
                    size: 14,
                    weight: FontWeight.w500,
                    color: AppColors.slate700,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      if (canEdit)
        PrimaryButton(
          label: 'Editar dados do paciente',
          shadow: false,
          onPressed: () => go(context, PatientFormScreen(patient: p)),
        )
      else
        const InfoBanner(
          tone: Tone.blue,
          icon: Icons.shield_outlined,
          text:
              'Dados cadastrais são somente para consulta. Solicite alterações ao responsável pelo paciente.',
        ),
    ];
  }
}

String _attentionText(PatientBundle bundle) {
  final parts = [
    if (bundle.lateDoses.isNotEmpty) 'medicamento atrasado',
    if (bundle.activeAlerts.isNotEmpty) 'acionamento aguardando resposta',
    if (bundle.hasUrgentToday) 'intercorrência urgente nas últimas 24 h',
  ];
  if (parts.isEmpty) return 'Paciente marcado para acompanhamento especial.';
  final text = parts.join(', ');
  return '${text[0].toUpperCase()}${text.substring(1)}.';
}

class _Tabs extends StatelessWidget {
  const _Tabs({required this.selected, required this.onChanged});
  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => Container(
    color: Colors.white,
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Row(
      children: [
        for (final (value, label) in const [
          ('resumo', 'Resumo'),
          ('dados', 'Dados do paciente'),
        ])
          Expanded(
            child: InkWell(
              onTap: () => onChanged(value),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      width: 2,
                      color: selected == value
                          ? AppColors.teal700
                          : Colors.transparent,
                    ),
                  ),
                ),
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: body(
                    size: 14,
                    weight: FontWeight.w600,
                    color: selected == value
                        ? AppColors.teal700
                        : AppColors.slate400,
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}
