import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/app_theme.dart';
import '../core/care_data.dart';
import '../core/session.dart';
import '../models.dart';
import '../widgets/ui.dart';

/// Cartão resumido usado no início do responsável.
class ObservationPreview extends StatelessWidget {
  const ObservationPreview({super.key, required this.observation, this.onTap});
  final Observation observation;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => AppCard(
    onTap: onTap,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _AuthorRow(observation: observation),
        const SizedBox(height: 8),
        Text(
          observation.text,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: body(size: 12, color: AppColors.slate500, height: 1.5),
        ),
        const SizedBox(height: 6),
        Text(
          relativeDateTime(observation.createdAt),
          style: body(size: 12, color: AppColors.slate400),
        ),
      ],
    ),
  );
}

class _AuthorRow extends StatelessWidget {
  const _AuthorRow({required this.observation, this.strong = false});
  final Observation observation;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final author = observation.author;
    return Row(
      children: [
        Avatar(initials: initials(author?.name ?? 'Equipe'), size: 28),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                author?.name ?? 'Integrante da equipe',
                style: body(
                  size: 12,
                  weight: FontWeight.w600,
                  color: strong ? AppColors.slate800 : AppColors.slate700,
                ),
              ),
              Text(
                author?.roleLabel ?? 'Equipe',
                style: body(size: 10, color: AppColors.slate400),
              ),
            ],
          ),
        ),
        LevelBadge(level: observation.level),
      ],
    );
  }
}

class ObservationsScreen extends StatefulWidget {
  const ObservationsScreen({super.key, required this.patientId});
  final String patientId;

  @override
  State<ObservationsScreen> createState() => _ObservationsScreenState();
}

class _ObservationsScreenState extends State<ObservationsScreen> {
  String _filter = 'todos';

  @override
  Widget build(BuildContext context) {
    final session = Session.of(context);
    final store = session.store;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final bundle = store.bundleFor(widget.patientId);
        final items = (bundle?.observations ?? const <Observation>[])
            .where((o) => _filter == 'todos' || o.level == _filter)
            .toList();
        final canCreate =
            bundle?.patient.permissions.canRecordObservations ?? false;
        return AppScreen(
          onRefresh: () => store.refreshPatient(widget.patientId),
          header: GradientHeader(
            onBack: () => Navigator.pop(context),
            child: HeaderTitle(
              'Observações',
              subtitle: bundle?.patient.name,
              trailing: canCreate
                  ? HeaderIconButton(
                      icon: Icons.add,
                      tooltip: session.professional
                          ? 'Registrar evolução'
                          : 'Adicionar observação',
                      onTap: () => go(
                        context,
                        NewObservationScreen(patientId: widget.patientId),
                      ),
                    )
                  : null,
            ),
          ),
          belowHeader: [
            FilterBar(
              options: const [
                ('todos', 'Todas'),
                ('information', 'Informativas'),
                ('attention', 'Atenção'),
                ('urgent', 'Urgentes'),
              ],
              selected: _filter,
              onChanged: (value) => setState(() => _filter = value),
            ),
          ],
          spacing: 0,
          children: [
            const RoleContext(),
            const SizedBox(height: 16),
            if (bundle == null)
              const LoadingView()
            else if (items.isEmpty)
              const EmptyState(
                icon: Icons.note_alt_outlined,
                title: 'Nenhuma observação neste filtro',
              )
            else
              for (var i = 0; i < items.length; i++)
                TimelineItem(
                  isLast: i == items.length - 1,
                  marker: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      color: switch (items[i].level) {
                        'urgent' => AppColors.red600,
                        'attention' => const Color(0xFFF97316),
                        _ => AppColors.teal600,
                      },
                    ),
                  ),
                  child: _ObservationCard(observation: items[i]),
                ),
          ],
        );
      },
    );
  }
}

class _ObservationCard extends StatelessWidget {
  const _ObservationCard({required this.observation});
  final Observation observation;

  @override
  Widget build(BuildContext context) => AppCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _AuthorRow(observation: observation, strong: true),
        const SizedBox(height: 8),
        Pill(
          observation.category,
          bg: AppColors.slate100,
          fg: AppColors.slate500,
        ),
        const SizedBox(height: 8),
        Text(
          observation.text,
          style: body(size: 14, color: AppColors.slate600, height: 1.5),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Text(
                relativeDateTime(observation.createdAt),
                style: body(size: 12, color: AppColors.slate400),
              ),
            ),
            if (observation.notifyResponsible) ...[
              const Icon(
                Icons.notifications_none,
                size: 11,
                color: AppColors.teal600,
              ),
              const SizedBox(width: 4),
              Text(
                'Responsável notificado',
                style: body(size: 12, color: AppColors.teal600),
              ),
            ],
          ],
        ),
      ],
    ),
  );
}

// ─── Nova observação / evolução ──────────────────────────────────────────────
class NewObservationScreen extends StatefulWidget {
  const NewObservationScreen({super.key, required this.patientId});
  final String patientId;

  @override
  State<NewObservationScreen> createState() => _NewObservationScreenState();
}

class _NewObservationScreenState extends State<NewObservationScreen> {
  static const _categories = [
    'Observação geral',
    'Alteração no estado do paciente',
    'Alimentação',
    'Mobilidade',
    'Higiene',
    'Medicação',
    'Intercorrência',
    'Outro',
  ];

  String _category = '';
  String _level = 'information';
  final _text = TextEditingController();
  bool _notify = false;
  bool _saving = false;
  bool _saved = false;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _text.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_text.text.trim().length < 3) {
      setState(
        () => _error = 'Descreva a observação com pelo menos 3 caracteres.',
      );
      return;
    }
    final session = Session.of(context);
    setState(() {
      _saving = true;
      _error = '';
    });
    try {
      await session.api.addObservation(
        widget.patientId,
        category: _category,
        level: _level,
        text: _text.text,
        notifyResponsible:
            session.professional && (_notify || _level == 'urgent'),
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
    final session = Session.of(context);
    final professional = session.professional;
    final patient = session.store.bundleFor(widget.patientId)?.patient;
    final responsibleName = patient?.responsibleName ?? 'O responsável';
    if (_saved) {
      return SuccessView(
        title: professional ? 'Evolução registrada!' : 'Observação registrada!',
        message: professional && (_notify || _level == 'urgent')
            ? '$responsibleName foi notificado(a).'
            : null,
      );
    }
    return AppScreen(
      header: GradientHeader(
        onBack: () => Navigator.pop(context),
        child: HeaderTitle(
          professional ? 'Nova evolução' : 'Nova observação',
          subtitle: patient?.name,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      spacing: 16,
      children: [
        if (_error.isNotEmpty) ErrorBox(_error),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const FieldLabel('Categoria'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final item in _categories)
                  AppChip(
                    label: item,
                    selected: _category == item,
                    outlined: true,
                    inactiveBg: Colors.white,
                    onTap: () => setState(() => _category = item),
                  ),
              ],
            ),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const FieldLabel('Nível de atenção'),
            const SizedBox(height: 8),
            SegmentChoice(
              options: const [
                (
                  'information',
                  'Informativo',
                  AppColors.teal600,
                  AppColors.teal50,
                ),
                (
                  'attention',
                  'Atenção',
                  AppColors.statusOrange,
                  AppColors.statusOrangeBg,
                ),
                (
                  'urgent',
                  'Urgente',
                  AppColors.statusRed,
                  AppColors.statusRedBg,
                ),
              ],
              selected: _level,
              onChanged: (value) => setState(() => _level = value),
            ),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppInput(
              label: 'Texto',
              controller: _text,
              hint: 'Descreva a observação ou intercorrência com detalhes...',
              maxLines: 5,
              maxLength: 5000,
            ),
            const SizedBox(height: 4),
            Text(
              '${_text.text.length} caracteres',
              textAlign: TextAlign.right,
              style: body(size: 12, color: AppColors.slate400),
            ),
          ],
        ),
        DashedButton(
          icon: Icons.add,
          label: 'Adicionar foto (opcional)',
          tone: Tone.slate,
          leadingTile: true,
          onTap: () => showToast(
            context,
            'O envio de fotos estará disponível em uma próxima versão.',
            error: true,
          ),
        ),
        if (professional)
          Material(
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: AppColors.slate200),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => setState(() => _notify = !_notify),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    AppCheckbox(
                      value: _notify || _level == 'urgent',
                      size: 24,
                      onChanged: (value) => setState(() => _notify = value),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Notificar o responsável',
                            style: body(
                              size: 14,
                              weight: FontWeight.w600,
                              color: AppColors.slate700,
                            ),
                          ),
                          Text(
                            _level == 'urgent'
                                ? 'Registros urgentes sempre notificam $responsibleName'
                                : '$responsibleName receberá uma notificação',
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
        if (_level == 'urgent')
          const InfoBanner(
            tone: Tone.red,
            icon: Icons.warning_amber_rounded,
            text:
                'Este recurso não substitui serviços de emergência. Em uma emergência real, ligue imediatamente para o SAMU (192) ou Bombeiros (193).',
          ),
        PrimaryButton(
          label: professional ? 'Registrar evolução' : 'Registrar observação',
          loading: _saving,
          onPressed: _category.isEmpty || _text.text.trim().isEmpty
              ? null
              : _save,
        ),
      ],
    );
  }
}
