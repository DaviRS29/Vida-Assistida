import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/app_theme.dart';
import '../core/care_data.dart';
import '../core/session.dart';
import '../widgets/ui.dart';
import 'medications_screens.dart';

class CarePlanScreen extends StatelessWidget {
  const CarePlanScreen({super.key, required this.patientId});
  final String patientId;

  @override
  Widget build(BuildContext context) {
    final session = Session.of(context);
    final store = session.store;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final bundle = store.bundleFor(patientId);
        final professional = session.professional;
        final canCreate =
            professional &&
            (bundle?.patient.permissions.canManageCarePlan ?? false);
        final doses = bundle?.todayDoses ?? const <DoseSlot>[];
        final slots = [
          for (final activity in bundle?.activities ?? const [])
            activitySlot(bundle!, activity, DateTime.now()),
        ];
        final todaySlots = bundle == null
            ? <ActivitySlot>[]
            : bundle.todayActivities;
        final done =
            doses.where((d) => d.status == DoseStatus.administrado).length +
            todaySlots
                .where((a) => a.status == ActivityStatus.concluida)
                .length;
        final open =
            doses.where((d) => d.isOpen).length +
            todaySlots.where((a) => a.isOpen).length;
        final lateDoses = doses
            .where((d) => d.status == DoseStatus.atrasado)
            .length;
        void newActivity() =>
            go(context, NewActivityScreen(patientId: patientId));

        return AppScreen(
          onRefresh: () => store.refreshPatient(patientId),
          header: GradientHeader(
            onBack: () => Navigator.pop(context),
            child: HeaderTitle(
              'Plano de cuidados',
              overline: 'Plano individual',
              subtitle: bundle?.patient.name,
              trailing: canCreate
                  ? HeaderIconButton(
                      icon: Icons.add,
                      tooltip: 'Nova atividade',
                      onTap: newActivity,
                    )
                  : null,
            ),
          ),
          belowHeader: [
            SummaryBar(
              items: [
                (
                  'Cuidados',
                  doses.length + todaySlots.length,
                  AppColors.teal700,
                ),
                ('Realizados', done, AppColors.green700),
                (
                  'Pendentes',
                  open,
                  open > 0 ? AppColors.amber700 : AppColors.slate500,
                ),
              ],
            ),
          ],
          spacing: 16,
          children: [
            const RoleContext(),
            if (bundle == null)
              const LoadingView()
            else ...[
              AppCard(
                onTap: () =>
                    go(context, MedicationsScreen(patientId: patientId)),
                child: Row(
                  children: [
                    const IconTile(
                      icon: Icons.medication_outlined,
                      color: AppColors.teal700,
                      bg: AppColors.teal50,
                      size: 48,
                      radius: 16,
                      iconSize: 23,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text('Medicamentos', style: display(size: 16)),
                              const SizedBox(width: 8),
                              const Pill(
                                'ROTINA CLÍNICA',
                                bg: AppColors.teal50,
                                fg: AppColors.teal700,
                                size: 9,
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${bundle.medications.length} prescriç${bundle.medications.length == 1 ? 'ão' : 'ões'}'
                            ' · ${lateDoses == 0 ? 'nenhuma administração atrasada' : '$lateDoses administraç${lateDoses == 1 ? 'ão atrasada' : 'ões atrasadas'}'}',
                            style: body(size: 12, color: AppColors.slate400),
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SectionHeader(
                    title: 'Atividades terapêuticas',
                    action: canCreate ? 'Nova atividade' : null,
                    onAction: newActivity,
                  ),
                  if (slots.isEmpty)
                    const EmptyState(
                      icon: Icons.assignment_outlined,
                      title: 'Nenhuma atividade no plano',
                      subtitle:
                          'As orientações dos profissionais aparecerão aqui.',
                    )
                  else
                    for (final slot in slots) ...[
                      _ActivityCard(
                        slot: slot,
                        today: activityRunsOn(slot.activity, DateTime.now()),
                        onTap: () => go(
                          context,
                          ActivityDetailScreen(
                            patientId: patientId,
                            activityId: slot.activity.id,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                ],
              ),
            ],
            const InfoBanner(
              tone: Tone.amber,
              text:
                  'Atividades clínicas devem seguir a orientação do profissional habilitado. O aplicativo registra a rotina, mas não substitui avaliação ou prescrição.',
            ),
          ],
        );
      },
    );
  }
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({
    required this.slot,
    required this.today,
    required this.onTap,
  });
  final ActivitySlot slot;
  final bool today;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final a = slot.activity;
    final physio = a.type.toLowerCase().contains('fisio');
    final late = today && slot.status == ActivityStatus.atrasada;
    return AppCard(
      onTap: onTap,
      accent: late ? AppColors.red500 : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconTile(
            icon: Icons.assignment_outlined,
            color: physio ? AppColors.blue700 : AppColors.violet700,
            bg: physio ? AppColors.blue50 : AppColors.violet50,
            size: 44,
            radius: 12,
            iconSize: 20,
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
                        a.title,
                        style: display(size: 14, height: 1.2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (today)
                      ActivityStatusBadge(status: slot.status)
                    else
                      const Pill(
                        'Fora do dia',
                        bg: AppColors.slate100,
                        fg: AppColors.slate500,
                        size: 10,
                        bold: true,
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  [a.type, if (a.duration != null) a.duration!].join(' · '),
                  style: body(size: 12, color: AppColors.slate400),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.schedule,
                      size: 13,
                      color: AppColors.slate500,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${a.timeLabel} · ${a.schedule}',
                        style: body(
                          size: 12,
                          weight: FontWeight.w600,
                          color: AppColors.slate500,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, size: 17, color: AppColors.slate300),
        ],
      ),
    );
  }
}

// ─── Nova atividade ──────────────────────────────────────────────────────────
class NewActivityScreen extends StatefulWidget {
  const NewActivityScreen({super.key, required this.patientId});
  final String patientId;

  @override
  State<NewActivityScreen> createState() => _NewActivityScreenState();
}

class _NewActivityScreenState extends State<NewActivityScreen> {
  String _type = 'Fisioterapia';
  final _title = TextEditingController();
  final _objective = TextEditingController();
  final _instructions = TextEditingController();
  final _schedule = TextEditingController(text: 'Seg, qua e sex');
  final _time = TextEditingController(text: '15:00');
  final _duration = TextEditingController(text: '15 minutos');
  final _series = TextEditingController();
  bool _assistance = true;
  bool _saving = false;
  bool _saved = false;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _title.addListener(() => setState(() {}));
    _instructions.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    for (final c in [
      _title,
      _objective,
      _instructions,
      _schedule,
      _time,
      _duration,
      _series,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickTime() async {
    final parts = _time.text.split(':');
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: int.tryParse(parts.first) ?? 15,
        minute: parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0,
      ),
    );
    if (picked != null) {
      _time.text = '${two(picked.hour)}:${two(picked.minute)}';
    }
  }

  Future<void> _save() async {
    if (_objective.text.trim().length < 3) {
      setState(() => _error = 'Descreva o objetivo da atividade.');
      return;
    }
    final session = Session.of(context);
    setState(() {
      _saving = true;
      _error = '';
    });
    try {
      await session.api.createCareActivity(
        widget.patientId,
        title: _title.text,
        type: _type,
        objective: _objective.text,
        instructions: _instructions.text,
        schedule: _schedule.text.trim().isEmpty
            ? 'Todos os dias'
            : _schedule.text,
        time: _time.text,
        duration: _duration.text,
        series: _series.text,
        needsAssistance: _assistance,
      );
      await session.store.refreshPatient(widget.patientId);
      if (mounted) setState(() => _saved = true);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_saved) {
      return SuccessView(
        title: 'Atividade adicionada',
        message:
            'A orientação entrou no plano de cuidados e será registrada no histórico.',
        action: 'Voltar ao plano',
        onAction: () => Navigator.pop(context),
      );
    }
    final patient = Session.of(
      context,
    ).store.bundleFor(widget.patientId)?.patient;
    return AppScreen(
      header: GradientHeader(
        onBack: () => Navigator.pop(context),
        child: HeaderTitle('Nova atividade', subtitle: patient?.name),
      ),
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      spacing: 16,
      children: [
        const InfoBanner(
          tone: Tone.blue,
          icon: Icons.shield_outlined,
          text:
              'Seu nome, profissão e registro ficarão associados a esta orientação clínica.',
        ),
        if (_error.isNotEmpty) ErrorBox(_error),
        AppSelect<String>(
          label: 'Tipo de cuidado',
          value: _type,
          items: const [
            'Fisioterapia',
            'Mobilidade',
            'Posicionamento',
            'Alongamento',
            'Caminhada assistida',
            'Tarefa geral',
          ],
          onChanged: (value) => setState(() => _type = value),
        ),
        AppInput(
          label: 'Nome da atividade',
          controller: _title,
          hint: 'Ex: Elevação assistida da perna',
        ),
        AppInput(
          label: 'Objetivo',
          controller: _objective,
          hint: 'Resultado esperado para o paciente',
        ),
        AppInput(
          label: 'Instruções e cuidados',
          controller: _instructions,
          hint: 'Explique como realizar e quando interromper...',
          maxLines: 4,
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: AppInput(
                label: 'Dias ou frequência',
                controller: _schedule,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AppInput(
                label: 'Horário',
                controller: _time,
                onTap: _pickTime,
              ),
            ),
          ],
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: AppInput(label: 'Duração', controller: _duration),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AppInput(
                label: 'Séries/repetições',
                controller: _series,
                hint: '3 × 10',
              ),
            ),
          ],
        ),
        Material(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppColors.slate200),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => setState(() => _assistance = !_assistance),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  AppSwitch(
                    value: _assistance,
                    width: 44,
                    onChanged: (value) => setState(() => _assistance = value),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Exige acompanhamento',
                          style: body(
                            size: 14,
                            weight: FontWeight.w600,
                            color: AppColors.slate700,
                          ),
                        ),
                        Text(
                          'Não deve ser realizada pelo paciente sozinho.',
                          style: body(size: 12, color: AppColors.slate400),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        PrimaryButton(
          label: 'Adicionar ao plano',
          loading: _saving,
          shadow: false,
          onPressed:
              _title.text.trim().length < 2 ||
                  _instructions.text.trim().length < 3
              ? null
              : _save,
        ),
      ],
    );
  }
}

// ─── Detalhe da atividade ────────────────────────────────────────────────────
class ActivityDetailScreen extends StatelessWidget {
  const ActivityDetailScreen({
    super.key,
    required this.patientId,
    required this.activityId,
  });

  final String patientId;
  final String activityId;

  @override
  Widget build(BuildContext context) {
    final session = Session.of(context);
    final store = session.store;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final bundle = store.bundleFor(patientId);
        final activity = bundle?.activities
            .where((a) => a.id == activityId)
            .firstOrNull;
        if (bundle == null || activity == null) {
          return AppScreen(
            header: GradientHeader(
              onBack: () => Navigator.pop(context),
              child: const HeaderTitle('Atividade'),
            ),
            children: const [
              EmptyState(
                icon: Icons.assignment_outlined,
                title: 'Atividade não encontrada',
                subtitle: 'Ela pode ter sido removida do plano de cuidados.',
              ),
            ],
          );
        }
        final slot = activitySlot(bundle, activity, DateTime.now());
        final lastRecord = bundle.activityRecords
            .where((r) => r.activityId == activity.id)
            .firstOrNull;
        final canRecord =
            session.professional &&
            bundle.patient.permissions.canRecordActivities;
        final info = [
          ('Objetivo', activity.objective),
          ('Como realizar', activity.instructions),
          ('Frequência', '${activity.schedule} · ${activity.timeLabel}'),
          (
            'Dose da atividade',
            [activity.series, activity.duration]
                .whereType<String>()
                .where((v) => v.isNotEmpty)
                .join(' · ')
                .ifEmpty('Não informado'),
          ),
          (
            'Orientado por',
            activity.createdBy == null
                ? 'Equipe'
                : '${activity.createdBy!.name} · ${activity.createdBy!.roleLabel}',
          ),
        ];
        return AppScreen(
          header: GradientHeader(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            onBack: () => Navigator.pop(context),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        activity.type.toUpperCase(),
                        style: body(
                          size: 12,
                          weight: FontWeight.w600,
                          color: AppColors.teal100,
                          letterSpacing: 1.4,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        activity.title,
                        style: display(
                          size: 20,
                          color: Colors.white,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                if (activityRunsOn(activity, DateTime.now()))
                  ActivityStatusBadge(status: slot.status),
              ],
            ),
          ),
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
          spacing: 16,
          children: [
            const RoleContext(),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < info.length; i++) ...[
                    if (i > 0) const SizedBox(height: 16),
                    Text(
                      info[i].$1.toUpperCase(),
                      style: body(
                        size: 10,
                        weight: FontWeight.w700,
                        color: AppColors.slate400,
                        letterSpacing: .8,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      info[i].$2,
                      style: body(
                        size: 14,
                        color: AppColors.slate700,
                        height: 1.5,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (activity.needsAssistance)
              const InfoBanner(
                tone: Tone.amber,
                icon: Icons.warning_amber_rounded,
                title: 'Acompanhamento obrigatório.',
                text:
                    'Não orientar o paciente a realizar esta atividade sozinho.',
              ),
            AppCard(
              child: SizedBox(
                width: double.infinity,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Último registro', style: display(size: 14)),
                    const SizedBox(height: 4),
                    Text(
                      lastRecord == null
                          ? 'Nenhuma execução registrada ainda.'
                          : '${_recordLabel(lastRecord.status)} · ${relativeDateTime(lastRecord.performedAt)} · ${lastRecord.performedBy?.name ?? 'Equipe'}'
                                '${lastRecord.notes == null ? '' : '\n${lastRecord.notes}'}',
                      style: body(size: 12, color: AppColors.slate500),
                    ),
                    if (lastRecord?.painBefore != null ||
                        lastRecord?.painAfter != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Dor: ${lastRecord?.painBefore ?? '-'}/10 antes · ${lastRecord?.painAfter ?? '-'}/10 depois',
                        style: body(size: 12, color: AppColors.slate400),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (canRecord)
              PrimaryButton(
                label: 'Registrar realização',
                icon: Icons.check,
                color: AppColors.blue700,
                shadow: false,
                onPressed: () => _record(context, activity.id),
              )
            else
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.slate100,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  session.professional
                      ? 'Você não possui permissão para registrar esta atividade. Solicite ao responsável pelo paciente.'
                      : 'Somente profissionais autorizados podem alterar esta orientação ou registrar sua execução. Você pode acompanhar todos os registros pelo histórico.',
                  style: body(size: 12, color: AppColors.slate500, height: 1.5),
                ),
              ),
          ],
        );
      },
    );
  }

  Future<void> _record(BuildContext context, String activityId) async {
    final session = Session.of(context);
    var outcome = 'completed';
    final painBefore = TextEditingController(text: '2');
    final painAfter = TextEditingController(text: '2');
    final note = TextEditingController();
    final ok = await showAppSheet<bool>(
      context,
      builder: (sheet) => StatefulBuilder(
        builder: (sheet, setSheet) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Registrar atividade', style: display(size: 20)),
            const SizedBox(height: 4),
            Text(
              'O registro será associado ao seu perfil e horário atual.',
              style: body(size: 12, color: AppColors.slate400),
            ),
            const SizedBox(height: 16),
            SegmentChoice(
              options: const [
                ('completed', 'Concluída', AppColors.blue700, AppColors.blue50),
                ('partial', 'Parcial', AppColors.blue700, AppColors.blue50),
                (
                  'not_performed',
                  'Não realizada',
                  AppColors.blue700,
                  AppColors.blue50,
                ),
              ],
              selected: outcome,
              onChanged: (value) => setSheet(() => outcome = value),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: AppInput(
                    label: 'Dor antes (0–10)',
                    controller: painBefore,
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppInput(
                    label: 'Dor depois (0–10)',
                    controller: painAfter,
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            AppInput(
              label: 'Observação',
              controller: note,
              hint:
                  'Descreva dificuldades, desconforto ou resposta do paciente...',
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            PrimaryButton(
              label: 'Salvar no histórico',
              color: AppColors.blue700,
              shadow: false,
              onPressed: () => Navigator.pop(sheet, true),
            ),
            TextLinkButton(
              label: 'Cancelar',
              onPressed: () => Navigator.pop(sheet, false),
            ),
          ],
        ),
      ),
    );
    int? pain(TextEditingController c) {
      final value = int.tryParse(c.text.trim());
      return value?.clamp(0, 10);
    }

    final before = pain(painBefore);
    final after = pain(painAfter);
    final notes = note.text;
    // Libera os campos depois da animação de fechamento da folha.
    Future<void>.delayed(const Duration(milliseconds: 600), () {
      painBefore.dispose();
      painAfter.dispose();
      note.dispose();
    });
    if (ok != true) return;
    try {
      await session.api.recordActivity(
        activityId,
        status: outcome,
        painBefore: before,
        painAfter: after,
        notes: notes,
      );
      await session.store.refreshPatient(patientId);
      if (context.mounted) {
        showToast(context, 'Atividade registrada no histórico.');
      }
    } on ApiException catch (error) {
      if (context.mounted) showToast(context, error.message, error: true);
    }
  }
}

String _recordLabel(String status) => switch (status) {
  'completed' => 'Concluída',
  'partial' => 'Parcial',
  _ => 'Não realizada',
};

extension on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}
