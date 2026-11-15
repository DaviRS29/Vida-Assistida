import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/app_theme.dart';
import '../core/care_data.dart';
import '../core/session.dart';
import '../models.dart';
import '../widgets/ui.dart';
import 'patient_detail_screen.dart';
import 'team_screens.dart';

/// Cadastro (3 etapas, com convite gerado) e edição dos dados do paciente.
class PatientFormScreen extends StatefulWidget {
  const PatientFormScreen({super.key, this.patient});

  /// Quando informado, a tela edita o cadastro existente.
  final Patient? patient;

  @override
  State<PatientFormScreen> createState() => _PatientFormScreenState();
}

class _PatientFormScreenState extends State<PatientFormScreen> {
  int _step = 1;
  late final _name = TextEditingController(text: widget.patient?.name);
  late final _conditions = TextEditingController(
    text: widget.patient?.conditions,
  );
  late final _allergies = TextEditingController(
    text: widget.patient?.allergies,
  );
  late final _restrictions = TextEditingController(
    text: widget.patient?.restrictions,
  );
  late final _contact = TextEditingController(
    text: widget.patient?.contactMain,
  );
  late final _contactAlt = TextEditingController(
    text: widget.patient?.contactAlt,
  );
  late final _notes = TextEditingController(text: widget.patient?.notes);
  late final _birthLabel = TextEditingController();
  DateTime? _birth;
  bool _saving = false;
  String _error = '';
  Patient? _created;

  bool get _editing => widget.patient != null;

  @override
  void initState() {
    super.initState();
    _birth = DateTime.tryParse(widget.patient?.birthDate ?? '');
    if (_birth != null) _birthLabel.text = ddmmyyyy(_birth!);
    _name.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    for (final c in [
      _name,
      _conditions,
      _allergies,
      _restrictions,
      _contact,
      _contactAlt,
      _notes,
      _birthLabel,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickBirth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _birth ?? DateTime(1950),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      helpText: 'Data de nascimento',
    );
    if (picked != null) {
      setState(() {
        _birth = picked;
        _birthLabel.text = ddmmyyyy(picked);
      });
    }
  }

  Map<String, String> get _fields => {
    'name': _name.text.trim(),
    if (_birth != null) 'birthDate': isoDate(_birth!),
    'conditions': _conditions.text.trim(),
    'allergies': _allergies.text.trim(),
    'restrictions': _restrictions.text.trim(),
    'contactMain': _contact.text.trim(),
    'contactAlt': _contactAlt.text.trim(),
    'notes': _notes.text.trim(),
  };

  Future<void> _save() async {
    if (_birth == null) {
      setState(() {
        _step = 1;
        _error = 'Informe a data de nascimento.';
      });
      return;
    }
    final session = Session.of(context);
    setState(() {
      _saving = true;
      _error = '';
    });
    try {
      if (_editing) {
        await session.api.updatePatient(widget.patient!.id, _fields);
        await session.store.refreshPatient(widget.patient!.id);
        if (mounted) {
          showToast(context, 'Dados do paciente atualizados.');
          Navigator.pop(context);
        }
        return;
      }
      final fields = Map.of(_fields)..removeWhere((k, v) => v.isEmpty);
      final patient = await session.api.createPatient(fields);
      await session.store.load();
      if (mounted) {
        setState(() {
          _created = patient;
          _step = 3;
        });
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => AppScreen(
    header: GradientHeader(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      onBack: () => Navigator.pop(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StepBars(step: _step, total: _editing ? 2 : 3),
          const SizedBox(height: 16),
          HeaderTitle(
            _editing ? 'Editar paciente' : 'Novo paciente',
            subtitle: _step == 1
                ? 'Informações básicas'
                : _step == 2
                ? 'Contatos e observações'
                : 'Convite gerado',
          ),
        ],
      ),
    ),
    padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
    spacing: 16,
    children: [
      if (_error.isNotEmpty) ErrorBox(_error),
      ...switch (_step) {
        1 => _basic(),
        2 => _contacts(),
        _ => _invite(),
      },
    ],
  );

  List<Widget> _basic() => [
    Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: AppColors.teal100,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.teal300, width: 2),
          ),
          child: const Icon(Icons.add, size: 28, color: AppColors.teal400),
        ),
        const SizedBox(height: 8),
        Text(
          'Adicionar foto (opcional)',
          style: body(size: 12, color: AppColors.slate400),
        ),
      ],
    ),
    AppInput(
      label: 'Nome completo',
      controller: _name,
      hint: 'Nome do paciente',
    ),
    AppInput(
      label: 'Data de nascimento',
      controller: _birthLabel,
      hint: 'dd/mm/aaaa',
      onTap: _pickBirth,
      suffix: const Icon(
        Icons.calendar_today_outlined,
        size: 18,
        color: AppColors.slate400,
      ),
    ),
    AppInput(
      label: 'Condições e informações relevantes',
      controller: _conditions,
      hint: 'Ex: Diabetes tipo 2, Hipertensão...',
      maxLines: 3,
    ),
    AppInput(
      label: 'Alergias',
      controller: _allergies,
      hint: 'Ex: Penicilina, AAS',
    ),
    AppInput(
      label: 'Restrições',
      controller: _restrictions,
      hint: 'Ex: Sem esforço físico intenso',
    ),
    const SizedBox(height: 4),
    PrimaryButton(
      label: 'Continuar',
      onPressed: _name.text.trim().length < 2
          ? null
          : () => setState(() {
              _error = _birth == null ? 'Informe a data de nascimento.' : '';
              if (_birth != null) _step = 2;
            }),
    ),
  ];

  List<Widget> _contacts() => [
    AppInput(
      label: 'Contato principal',
      controller: _contact,
      hint: 'Nome e telefone',
    ),
    AppInput(
      label: 'Contato alternativo',
      controller: _contactAlt,
      hint: 'Nome e telefone (opcional)',
    ),
    AppInput(
      label: 'Observações gerais',
      controller: _notes,
      hint: 'Informações adicionais sobre o paciente...',
      maxLines: 4,
    ),
    if (!_editing)
      const InfoBanner(
        tone: Tone.amber,
        text:
            'Após salvar, um código de convite será gerado automaticamente para você compartilhar com os profissionais de saúde.',
      ),
    Row(
      children: [
        SecondaryButton(
          label: 'Voltar',
          onPressed: () => setState(() => _step = 1),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: PrimaryButton(
            label: _editing ? 'Salvar alterações' : 'Salvar paciente',
            loading: _saving,
            onPressed: _save,
          ),
        ),
      ],
    ),
  ];

  List<Widget> _invite() {
    final patient = _created!;
    return [
      Column(
        children: [
          const SizedBox(height: 8),
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
              color: AppColors.green100,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check, size: 32, color: AppColors.green600),
          ),
          const SizedBox(height: 16),
          Text('Paciente cadastrado!', style: display(size: 20)),
          const SizedBox(height: 4),
          Text(
            '${patient.name} foi adicionado com sucesso.',
            textAlign: TextAlign.center,
            style: body(size: 14, color: AppColors.slate500),
          ),
          const SizedBox(height: 8),
        ],
      ),
      InviteCodeCard(patient: patient, large: true),
      const InfoBanner(
        bordered: false,
        text:
            'Compartilhe este código com os profissionais de saúde que irão cuidar do paciente. Você pode gerenciar as permissões a qualquer momento.',
      ),
      PrimaryButton(
        label: 'Ver detalhes do paciente',
        onPressed: () => Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => PatientDetailScreen(patientId: patient.id),
          ),
        ),
      ),
      TextLinkButton(
        label: 'Voltar à lista',
        onPressed: () => Navigator.pop(context),
      ),
    ];
  }
}
