import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/app_theme.dart';
import '../core/care_data.dart';
import '../core/session.dart';
import '../widgets/ui.dart';

class MedicationsScreen extends StatelessWidget {
  const MedicationsScreen({super.key, required this.patientId});
  final String patientId;

  @override
  Widget build(BuildContext context) {
    final session = Session.of(context);
    final store = session.store;
    final responsible = !session.professional;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final bundle = store.bundleFor(patientId);
        final slots = bundle == null ? <DoseSlot>[] : bundle.todayDoses;
        final canRecord =
            bundle?.patient.permissions.canRecordMedications ?? false;
        int count(DoseStatus s) => slots.where((d) => d.status == s).length;
        return AppScreen(
          onRefresh: () => store.refreshPatient(patientId),
          header: GradientHeader(
            onBack: () => Navigator.pop(context),
            child: HeaderTitle(
              'Medicamentos',
              subtitle: _capitalize(longToday()),
              trailing: responsible
                  ? HeaderIconButton(
                      icon: Icons.add,
                      tooltip: 'Cadastrar medicamento',
                      onTap: () => go(
                        context,
                        NewMedicationScreen(patientId: patientId),
                      ),
                    )
                  : null,
            ),
          ),
          belowHeader: [
            SummaryBar(
              items: [
                ('Total', slots.length, AppColors.teal600),
                ('Adm.', count(DoseStatus.administrado), AppColors.statusGreen),
                ('Pendentes', count(DoseStatus.pendente), AppColors.teal600),
                ('Atrasados', count(DoseStatus.atrasado), AppColors.statusRed),
              ],
            ),
          ],
          children: [
            const RoleContext(),
            InfoBanner(
              tone: responsible ? Tone.teal : Tone.blue,
              icon: responsible ? Icons.settings_outlined : Icons.check,
              text: responsible
                  ? 'Você gerencia prescrições e horários. As confirmações de administração são registradas pelos profissionais vinculados.'
                  : 'Confirme somente medicamentos realmente administrados. Cada ação ficará identificada no histórico do paciente.',
            ),
            if (bundle == null)
              const LoadingView()
            else if (bundle.medicationsDenied)
              const ErrorView(
                error: 'Sem permissão para consultar medicamentos.',
              )
            else if (slots.isEmpty)
              const EmptyState(
                icon: Icons.medication_outlined,
                title: 'Nenhum medicamento para hoje',
                subtitle: 'Os horários cadastrados aparecerão aqui.',
              )
            else
              for (final slot in slots)
                _DoseCard(slot: slot, canRecord: !responsible && canRecord),
            if (responsible)
              DashedButton(
                icon: Icons.add,
                label: 'Cadastrar medicamento e horários',
                onTap: () =>
                    go(context, NewMedicationScreen(patientId: patientId)),
              ),
          ],
        );
      },
    );
  }
}

String _capitalize(String text) =>
    text.isEmpty ? text : '${text[0].toUpperCase()}${text.substring(1)}';

class _DoseCard extends StatelessWidget {
  const _DoseCard({required this.slot, required this.canRecord});
  final DoseSlot slot;
  final bool canRecord;

  @override
  Widget build(BuildContext context) {
    final late = slot.status == DoseStatus.atrasado;
    final done = slot.status == DoseStatus.administrado;
    final skipped = slot.status == DoseStatus.naoAdministrado;
    final (tileBg, tileFg) = late
        ? (AppColors.red100, AppColors.red600)
        : done
        ? (AppColors.green100, AppColors.green700)
        : skipped
        ? (AppColors.slate100, AppColors.slate400)
        : (AppColors.teal50, AppColors.teal700);
    final med = slot.medication;
    final record = slot.record;
    return AppCard(
      accent: late ? AppColors.red500 : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconTile(
                icon: Icons.medication_outlined,
                color: tileFg,
                bg: tileBg,
                size: 40,
                radius: 12,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(med.name, style: display(size: 14)),
                    Text(
                      '${med.dosage} · ${med.route}',
                      style: body(size: 12, color: AppColors.slate400),
                    ),
                  ],
                ),
              ),
              MedStatusBadge(status: slot.status),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                Icons.schedule,
                size: 13,
                color: late ? AppColors.red500 : AppColors.slate400,
              ),
              const SizedBox(width: 8),
              Text(
                '${slot.time}${late ? ' — ATRASADO' : ''}',
                style: body(
                  size: 12,
                  weight: FontWeight.w600,
                  color: late ? AppColors.red600 : AppColors.slate500,
                ),
              ),
            ],
          ),
          if (med.instructions?.isNotEmpty == true) ...[
            const SizedBox(height: 4),
            Text(
              med.instructions!,
              style: body(size: 12, color: AppColors.slate400),
            ),
          ],
          if (done && record != null)
            _RecordNote(
              icon: Icons.check,
              bg: AppColors.green50,
              fg: AppColors.green700,
              text:
                  '${record.recordedBy?.name ?? 'Equipe'} · ${relativeDateTime(record.administeredAt ?? record.createdAt)}',
            ),
          if (skipped && record != null)
            _RecordNote(
              icon: Icons.close,
              bg: AppColors.slate100,
              fg: AppColors.slate500,
              text:
                  'Não administrado · ${record.notes ?? 'Sem motivo informado'} · ${record.recordedBy?.name ?? 'Equipe'}',
            ),
          if (canRecord && slot.isOpen) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: PrimaryButton(
                    label: 'Confirmar',
                    icon: Icons.check,
                    height: 40,
                    fontSize: 12,
                    radius: 12,
                    shadow: false,
                    onPressed: () => _confirm(context),
                  ),
                ),
                const SizedBox(width: 8),
                Material(
                  color: AppColors.slate100,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => _skip(context),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 11,
                      ),
                      child: Text(
                        'Não adm.',
                        style: body(
                          size: 12,
                          weight: FontWeight.w600,
                          color: AppColors.slate600,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _record(
    BuildContext context,
    String status, {
    String? notes,
  }) async {
    final session = Session.of(context);
    try {
      await session.api.recordMedication(
        slot.medication.id,
        scheduledAt: slot.scheduledAt,
        status: status,
        notes: notes,
      );
      await session.store.refreshPatient(slot.patient.id);
      if (context.mounted) {
        showToast(
          context,
          status == 'administered'
              ? 'Administração confirmada com sucesso!'
              : 'Registro salvo.',
        );
      }
    } on ApiException catch (error) {
      if (context.mounted) showToast(context, error.message, error: true);
    }
  }

  Future<void> _confirm(BuildContext context) async {
    final future = DateTime.now().isBefore(slot.scheduledAt);
    final ok = await showAppSheet<bool>(
      context,
      builder: (sheet) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Center(
            child: IconTile(
              icon: Icons.medication_outlined,
              color: AppColors.green700,
              bg: AppColors.green100,
              size: 56,
              radius: 16,
              iconSize: 28,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Confirmar administração?',
            textAlign: TextAlign.center,
            style: display(size: 20),
          ),
          const SizedBox(height: 4),
          Text(
            '${slot.medication.label} · ${slot.time}',
            textAlign: TextAlign.center,
            style: body(size: 14, color: AppColors.slate500),
          ),
          if (future) ...[
            const SizedBox(height: 12),
            InfoBanner(
              tone: Tone.amber,
              icon: Icons.warning_amber_rounded,
              text:
                  'Este medicamento está programado para ${slot.time}, que ainda não chegou. Você está confirmando com antecedência — prosseguir mesmo assim?',
            ),
            const SizedBox(height: 16),
          ] else ...[
            const SizedBox(height: 8),
            Text(
              'Será registrado no histórico com data, hora e seu nome.',
              textAlign: TextAlign.center,
              style: body(size: 12, color: AppColors.slate400),
            ),
            const SizedBox(height: 24),
          ],
          PrimaryButton(
            label: future ? 'Confirmar com antecedência' : 'Sim, confirmar',
            color: future ? AppColors.amber500 : AppColors.teal700,
            shadow: false,
            onPressed: () => Navigator.pop(sheet, true),
          ),
          TextLinkButton(
            label: 'Cancelar',
            onPressed: () => Navigator.pop(sheet, false),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) await _record(context, 'administered');
  }

  Future<void> _skip(BuildContext context) async {
    const reasons = [
      'Paciente recusou',
      'Medicamento indisponível',
      'Paciente dormindo',
      'Orientação médica',
      'Outro motivo',
    ];
    String? reason;
    final ok = await showAppSheet<bool>(
      context,
      builder: (sheet) => StatefulBuilder(
        builder: (sheet, setSheet) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Não administrado', style: display(size: 20)),
            const SizedBox(height: 16),
            for (final item in reasons) ...[
              OptionTile(
                label: item,
                selected: reason == item,
                onTap: () => setSheet(() => reason = item),
              ),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: 8),
            PrimaryButton(
              label: 'Registrar',
              color: AppColors.slate700,
              shadow: false,
              onPressed: reason == null
                  ? null
                  : () => Navigator.pop(sheet, true),
            ),
            TextLinkButton(
              label: 'Cancelar',
              onPressed: () => Navigator.pop(sheet, false),
            ),
          ],
        ),
      ),
    );
    if (ok == true && context.mounted) {
      await _record(context, 'not_administered', notes: reason);
    }
  }
}

class _RecordNote extends StatelessWidget {
  const _RecordNote({
    required this.icon,
    required this.bg,
    required this.fg,
    required this.text,
  });

  final IconData icon;
  final Color bg;
  final Color fg;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(top: 8),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      children: [
        Icon(icon, size: 13, color: fg),
        const SizedBox(width: 6),
        Expanded(
          child: Text(text, style: body(size: 12, color: fg)),
        ),
      ],
    ),
  );
}

// ─── Cadastro de medicamento ─────────────────────────────────────────────────
class NewMedicationScreen extends StatefulWidget {
  const NewMedicationScreen({super.key, required this.patientId});
  final String patientId;

  @override
  State<NewMedicationScreen> createState() => _NewMedicationScreenState();
}

class _NewMedicationScreenState extends State<NewMedicationScreen> {
  final _name = TextEditingController();
  final _dosage = TextEditingController();
  final _instructions = TextEditingController();
  final _startLabel = TextEditingController();
  final _endLabel = TextEditingController();
  String _unit = 'mg';
  String _route = 'Oral';
  String _frequency = '1x ao dia';
  final Set<String> _times = {};
  DateTime _start = dayOf(DateTime.now());
  DateTime? _end;
  bool _saving = false;
  bool _saved = false;
  String _error = '';

  static const _presetTimes = [
    '06:00',
    '08:00',
    '10:00',
    '12:00',
    '14:00',
    '16:00',
    '18:00',
    '20:00',
    '22:00',
  ];

  @override
  void initState() {
    super.initState();
    _startLabel.text = ddmmyyyy(_start);
    _name.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    for (final c in [_name, _dosage, _instructions, _startLabel, _endLabel]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate(bool start) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: start ? _start : (_end ?? _start),
      firstDate: start ? DateTime(2020) : _start,
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      if (start) {
        _start = picked;
        _startLabel.text = ddmmyyyy(picked);
        if (_end != null && _end!.isBefore(picked)) {
          _end = null;
          _endLabel.clear();
        }
      } else {
        _end = picked;
        _endLabel.text = ddmmyyyy(picked);
      }
    });
  }

  Future<void> _addCustomTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 9, minute: 0),
    );
    if (picked != null) {
      setState(() => _times.add('${two(picked.hour)}:${two(picked.minute)}'));
    }
  }

  Future<void> _save() async {
    if (_dosage.text.trim().isEmpty) {
      setState(() => _error = 'Informe a dosagem.');
      return;
    }
    if (_times.isEmpty) {
      setState(() => _error = 'Selecione ao menos um horário.');
      return;
    }
    final session = Session.of(context);
    setState(() {
      _saving = true;
      _error = '';
    });
    try {
      await session.api.createMedication(
        widget.patientId,
        name: _name.text,
        dosage: '${_dosage.text.trim()} $_unit',
        route: _route,
        schedule: _times.toList()..sort(),
        frequency: _frequency,
        startDate: isoDate(_start),
        endDate: _end == null ? null : isoDate(_end!),
        instructions: _instructions.text,
      );
      await session.store.refreshPatient(widget.patientId);
      if (!mounted) return;
      setState(() => _saved = true);
      await Future<void>.delayed(const Duration(milliseconds: 1500));
      if (mounted) Navigator.pop(context);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_saved) {
      return const SuccessView(
        title: 'Medicamento salvo!',
        message:
            'O medicamento foi adicionado à lista e ficará disponível no horário programado.',
      );
    }
    final patient = Session.of(
      context,
    ).store.bundleFor(widget.patientId)?.patient;
    return AppScreen(
      header: GradientHeader(
        onBack: () => Navigator.pop(context),
        child: HeaderTitle('Novo medicamento', subtitle: patient?.name),
      ),
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      spacing: 16,
      children: [
        const InfoBanner(
          tone: Tone.amber,
          text:
              'Cadastre somente informações previamente orientadas pelo profissional habilitado responsável.',
        ),
        if (_error.isNotEmpty) ErrorBox(_error),
        AppInput(
          label: 'Nome do medicamento',
          controller: _name,
          hint: 'Ex: Metformina',
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: AppInput(
                label: 'Dosagem',
                controller: _dosage,
                hint: 'Ex: 500',
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AppSelect<String>(
                label: 'Unidade',
                value: _unit,
                items: const ['mg', 'mL', 'UI', 'mcg', 'g', 'comp.', 'gota(s)'],
                onChanged: (value) => setState(() => _unit = value),
              ),
            ),
          ],
        ),
        AppSelect<String>(
          label: 'Via de administração',
          value: _route,
          items: const [
            'Oral',
            'Subcutânea',
            'Intramuscular',
            'Intravenosa',
            'Tópica',
            'Inalatória',
            'Sublingual',
          ],
          onChanged: (value) => setState(() => _route = value),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const FieldLabel('Horários'),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final time in {
                  ..._presetTimes,
                  ..._times,
                }.toList()..sort())
                  _TimeChip(
                    label: time,
                    selected: _times.contains(time),
                    onTap: () => setState(
                      () => _times.contains(time)
                          ? _times.remove(time)
                          : _times.add(time),
                    ),
                  ),
                _TimeChip(
                  label: '+ Outro',
                  selected: false,
                  onTap: _addCustomTime,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Toque para selecionar os horários',
              style: body(size: 12, color: AppColors.slate400),
            ),
          ],
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: AppInput(
                label: 'Data inicial',
                controller: _startLabel,
                onTap: () => _pickDate(true),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AppInput(
                label: 'Data final',
                controller: _endLabel,
                hint: 'dd/mm/aaaa',
                helper: 'Opcional',
                onTap: () => _pickDate(false),
              ),
            ),
          ],
        ),
        AppSelect<String>(
          label: 'Frequência',
          value: _frequency,
          items: const [
            '1x ao dia',
            '2x ao dia',
            '3x ao dia',
            '4x ao dia',
            'A cada 8h',
            'A cada 12h',
            'Conforme necessário',
            'Em dias alternados',
          ],
          onChanged: (value) => setState(() => _frequency = value),
        ),
        AppInput(
          label: 'Orientações',
          controller: _instructions,
          hint: 'Ex: Tomar após as refeições. Não partir o comprimido.',
          maxLines: 3,
        ),
        PrimaryButton(
          label: 'Salvar medicamento',
          loading: _saving,
          onPressed: _name.text.trim().length < 2 ? null : _save,
        ),
      ],
    );
  }
}

class _TimeChip extends StatelessWidget {
  const _TimeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: selected ? AppColors.teal50 : Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
      side: BorderSide(
        color: selected ? AppColors.teal400 : AppColors.slate200,
      ),
    ),
    child: InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Text(
          label,
          style: body(
            size: 12,
            weight: FontWeight.w500,
            color: selected ? AppColors.teal700 : AppColors.slate600,
          ),
        ),
      ),
    ),
  );
}
