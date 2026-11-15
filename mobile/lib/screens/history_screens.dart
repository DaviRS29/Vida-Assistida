import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/app_theme.dart';
import '../core/care_data.dart';
import '../core/session.dart';
import '../models.dart';
import '../widgets/patient_widgets.dart';
import '../widgets/ui.dart';

IconData eventIcon(EventKind kind) => switch (kind) {
  EventKind.medicamento => Icons.medication_outlined,
  EventKind.atividade => Icons.assignment_outlined,
  EventKind.observacao => Icons.note_alt_outlined,
  EventKind.profissional => Icons.groups_outlined,
  EventKind.acionamento => Icons.sos_outlined,
  EventKind.outro => Icons.history,
};

Color eventColor(AuditEvent event) {
  final level = eventLevel(event);
  if (level == 'urgente') return AppColors.red600;
  if (level == 'atencao') return const Color(0xFFF57C00);
  return switch (eventKind(event.action)) {
    EventKind.medicamento => AppColors.statusGreen,
    EventKind.atividade => AppColors.blueStrong,
    EventKind.observacao => AppColors.teal600,
    EventKind.profissional => const Color(0xFF00695C),
    EventKind.acionamento => const Color(0xFFD32F2F),
    EventKind.outro => AppColors.purple,
  };
}

bool _inPeriod(DateTime date, String period) {
  final now = DateTime.now();
  return switch (period) {
    'hoje' => sameDay(date, now),
    'semana' => !date.isBefore(
      dayOf(now).subtract(Duration(days: now.weekday % 7)),
    ),
    'mes' => date.year == now.year && date.month == now.month,
    _ => true,
  };
}

// ─── Histórico do paciente ───────────────────────────────────────────────────
class PatientHistoryScreen extends StatefulWidget {
  const PatientHistoryScreen({super.key, required this.patientId});
  final String patientId;

  @override
  State<PatientHistoryScreen> createState() => _PatientHistoryScreenState();
}

class _PatientHistoryScreenState extends State<PatientHistoryScreen> {
  late Future<List<AuditEvent>> _future;
  String _type = 'todos';
  String _period = 'todos';
  String _author = 'todos';
  String _level = 'todos';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future = Session.of(context).api.audit(widget.patientId);
  }

  Future<void> _reload() async {
    setState(() => _future = Session.of(context).api.audit(widget.patientId));
    await _future;
  }

  Future<void> _openFilters(List<AuditEvent> events) async {
    final authors = {
      for (final e in events)
        if (e.actor != null) e.actor!.id: e.actor!.name,
    };
    var author = _author;
    var level = _level;
    final apply = await showAppSheet<bool>(
      context,
      builder: (sheet) => StatefulBuilder(
        builder: (sheet, setSheet) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Filtrar histórico', style: display(size: 20)),
            const SizedBox(height: 16),
            const FieldLabel('Autor'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                AppChip(
                  label: 'Todos',
                  selected: author == 'todos',
                  onTap: () => setSheet(() => author = 'todos'),
                ),
                for (final entry in authors.entries)
                  AppChip(
                    label: entry.value,
                    selected: author == entry.key,
                    onTap: () => setSheet(() => author = entry.key),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            const FieldLabel('Nível de atenção'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final (value, label) in const [
                  ('todos', 'Todos'),
                  ('info', 'Informativo'),
                  ('atencao', 'Atenção'),
                  ('urgente', 'Urgente'),
                ])
                  AppChip(
                    label: label,
                    selected: level == value,
                    onTap: () => setSheet(() => level = value),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            PrimaryButton(
              label: 'Aplicar filtros',
              shadow: false,
              onPressed: () => Navigator.pop(sheet, true),
            ),
            TextLinkButton(
              label: 'Limpar filtros',
              onPressed: () {
                author = 'todos';
                level = 'todos';
                Navigator.pop(sheet, true);
              },
            ),
          ],
        ),
      ),
    );
    if (apply == true) {
      setState(() {
        _author = author;
        _level = level;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final patient = Session.of(
      context,
    ).store.bundleFor(widget.patientId)?.patient;
    return FutureBuilder<List<AuditEvent>>(
      future: _future,
      builder: (context, snapshot) {
        final events = snapshot.data ?? const <AuditEvent>[];
        final filtered = events.where((e) {
          final kind = eventKind(e.action);
          final typeOk = switch (_type) {
            'medicamento' => kind == EventKind.medicamento,
            'atividade' => kind == EventKind.atividade,
            'observacao' => kind == EventKind.observacao,
            'acionamento' => kind == EventKind.acionamento,
            _ => true,
          };
          return typeOk &&
              _inPeriod(e.createdAt, _period) &&
              (_author == 'todos' || e.actorId == _author) &&
              (_level == 'todos' || eventLevel(e) == _level);
        }).toList();
        final filtersOn = _author != 'todos' || _level != 'todos';
        return AppScreen(
          onRefresh: _reload,
          header: GradientHeader(
            onBack: () => Navigator.pop(context),
            child: HeaderTitle(
              'Histórico',
              subtitle: patient?.name,
              trailing: HeaderIconButton(
                icon: Icons.filter_alt_outlined,
                tooltip: 'Filtrar por autor e nível',
                badge: filtersOn ? 1 : 0,
                onTap: () => _openFilters(events),
              ),
            ),
          ),
          belowHeader: [
            FilterBar(
              options: const [
                ('todos', 'Todos'),
                ('medicamento', 'Medicamentos'),
                ('atividade', 'Atividades'),
                ('observacao', 'Observações'),
                ('acionamento', 'Acionamentos'),
              ],
              selected: _type,
              onChanged: (value) => setState(() => _type = value),
            ),
            FilterBar(
              secondary: true,
              options: const [
                ('todos', 'Todo período'),
                ('hoje', 'Hoje'),
                ('semana', 'Esta semana'),
                ('mes', 'Este mês'),
              ],
              selected: _period,
              onChanged: (value) => setState(() => _period = value),
            ),
          ],
          spacing: 0,
          children: [
            if (snapshot.connectionState == ConnectionState.waiting)
              const LoadingView()
            else if (snapshot.hasError)
              ErrorView(error: snapshot.error, onRetry: _reload)
            else if (filtered.isEmpty)
              const EmptyState(
                icon: Icons.history,
                title: 'Nenhum evento encontrado',
                subtitle: 'Tente ajustar os filtros',
              )
            else
              for (var i = 0; i < filtered.length; i++)
                TimelineItem(
                  isLast: i == filtered.length - 1,
                  indent: 48,
                  markerLeft: 10,
                  markerTop: 10,
                  marker: IconTile(
                    icon: eventIcon(eventKind(filtered[i].action)),
                    color: Colors.white,
                    bg: eventColor(filtered[i]),
                    size: 28,
                    radius: 12,
                    iconSize: 16,
                  ),
                  child: _EventCard(event: filtered[i]),
                ),
          ],
        );
      },
    );
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard({required this.event});
  final AuditEvent event;

  @override
  Widget build(BuildContext context) {
    final level = eventLevel(event);
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  eventTitle(event),
                  style: body(
                    size: 14,
                    weight: FontWeight.w600,
                    color: AppColors.slate800,
                    height: 1.2,
                  ),
                ),
              ),
              if (level != 'info') ...[
                const SizedBox(width: 8),
                LevelBadge(level: level),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text(
            eventDetail(event),
            style: body(size: 12, color: AppColors.slate400),
          ),
          const SizedBox(height: 4),
          Text(
            relativeDateTime(event.createdAt),
            style: body(size: 12, color: AppColors.slate300),
          ),
        ],
      ),
    );
  }
}

// ─── Aba Histórico / Registros ───────────────────────────────────────────────
class GlobalHistoryScreen extends StatefulWidget {
  const GlobalHistoryScreen({super.key});

  @override
  State<GlobalHistoryScreen> createState() => _GlobalHistoryScreenState();
}

class _GlobalHistoryScreenState extends State<GlobalHistoryScreen> {
  final Map<String, Future<DateTime?>> _lastEvent = {};

  Future<DateTime?> _last(ApiClient api, String patientId) =>
      _lastEvent.putIfAbsent(patientId, () async {
        try {
          final events = await api.audit(patientId);
          return events.isEmpty ? null : events.first.createdAt;
        } on ApiException catch (error) {
          if (error.isForbidden) return DateTime(0);
          rethrow;
        }
      });

  @override
  Widget build(BuildContext context) {
    final session = Session.of(context);
    final store = session.store;
    final responsible = !session.professional;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) => AppScreen(
        onRefresh: () async {
          _lastEvent.clear();
          await store.load();
        },
        header: GradientHeader(
          child: HeaderTitle(
            responsible ? 'Histórico do cuidado' : 'Registros assistenciais',
            subtitle: responsible
                ? 'Auditoria dos pacientes sob sua gestão'
                : 'Atividades dos pacientes vinculados',
          ),
        ),
        children: [
          const RoleContext(),
          if (!store.loaded && store.loading)
            const LoadingView()
          else if (store.bundles.isEmpty)
            const EmptyState(
              icon: Icons.history,
              title: 'Nenhum histórico disponível',
              subtitle:
                  'Os registros aparecerão quando houver pacientes vinculados.',
            )
          else
            for (final bundle in store.bundles)
              AppCard(
                onTap: () => go(
                  context,
                  PatientHistoryScreen(patientId: bundle.patient.id),
                ),
                child: Row(
                  children: [
                    PatientAvatar(patient: bundle.patient, size: 44),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(bundle.patient.name, style: display(size: 16)),
                          Text(
                            '${bundle.patient.age} anos',
                            style: body(size: 12, color: AppColors.slate400),
                          ),
                          const SizedBox(height: 4),
                          FutureBuilder<DateTime?>(
                            future: _last(session.api, bundle.patient.id),
                            builder: (context, snapshot) => Text(
                              snapshot.connectionState ==
                                      ConnectionState.waiting
                                  ? 'Carregando último evento...'
                                  : snapshot.data == null
                                  ? 'Nenhum evento registrado'
                                  : snapshot.data!.year == 0
                                  ? 'Histórico restrito pelo responsável'
                                  : 'Último evento: ${relativeDateTime(snapshot.data!)}',
                              style: body(size: 12, color: AppColors.slate400),
                            ),
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
        ],
      ),
    );
  }
}

// ─── Meu histórico (profissional) ────────────────────────────────────────────
class MyHistoryScreen extends StatefulWidget {
  const MyHistoryScreen({super.key});

  @override
  State<MyHistoryScreen> createState() => _MyHistoryScreenState();
}

class _MyHistoryScreenState extends State<MyHistoryScreen> {
  late Future<List<(String, AuditEvent)>> _future;
  String _filter = 'todos';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future = _load();
  }

  Future<List<(String, AuditEvent)>> _load() async {
    final session = Session.of(context);
    final groups = await Future.wait(
      session.store.bundles.map((bundle) async {
        try {
          final events = await session.api.audit(bundle.patient.id);
          return [
            for (final e in events)
              if (e.actorId == session.user.id) (bundle.patient.firstName, e),
          ];
        } on ApiException {
          return <(String, AuditEvent)>[];
        }
      }),
    );
    final all = groups.expand((g) => g).toList()
      ..sort((a, b) => b.$2.createdAt.compareTo(a.$2.createdAt));
    return all;
  }

  @override
  Widget build(BuildContext context) {
    final user = Session.of(context).user;
    return FutureBuilder<List<(String, AuditEvent)>>(
      future: _future,
      builder: (context, snapshot) {
        final items = (snapshot.data ?? const <(String, AuditEvent)>[]).where((
          item,
        ) {
          final kind = eventKind(item.$2.action);
          return switch (_filter) {
            'med' => kind == EventKind.medicamento,
            'obs' => kind == EventKind.observacao,
            _ => true,
          };
        }).toList();
        return AppScreen(
          onRefresh: () async {
            setState(() => _future = _load());
            await _future;
          },
          header: GradientHeader(
            onBack: () => Navigator.pop(context),
            child: HeaderTitle('Meu histórico', subtitle: user.name),
          ),
          belowHeader: [
            FilterBar(
              options: const [
                ('todos', 'Tudo'),
                ('med', 'Medicamentos'),
                ('obs', 'Observações'),
              ],
              selected: _filter,
              onChanged: (value) => setState(() => _filter = value),
            ),
          ],
          spacing: 0,
          children: [
            if (snapshot.connectionState == ConnectionState.waiting)
              const LoadingView()
            else if (items.isEmpty)
              const EmptyState(
                icon: Icons.history,
                title: 'Nenhum registro seu ainda',
                subtitle:
                    'Confirmações e observações feitas por você aparecerão aqui.',
              )
            else
              for (var i = 0; i < items.length; i++)
                _MyEventRow(
                  patient: items[i].$1,
                  event: items[i].$2,
                  isLast: i == items.length - 1,
                ),
          ],
        );
      },
    );
  }
}

class _MyEventRow extends StatelessWidget {
  const _MyEventRow({
    required this.patient,
    required this.event,
    required this.isLast,
  });
  final String patient;
  final AuditEvent event;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final color = eventColor(event);
    final kind = eventKind(event.action);
    final detail = eventDetail(event).split(' · ').skip(1).join(' · ');
    return Stack(
      children: [
        if (!isLast)
          Positioned(
            left: 19,
            top: 36,
            bottom: 0,
            child: Container(width: 2, color: AppColors.slate100),
          ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IconTile(
              icon: eventIcon(kind),
              color: color,
              bg: color.withValues(alpha: .13),
              size: 40,
              radius: 12,
              iconSize: 18,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      eventTitle(event),
                      style: body(
                        size: 14,
                        weight: FontWeight.w600,
                        color: AppColors.slate800,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      patient,
                      style: body(size: 12, color: AppColors.slate400),
                    ),
                    if (detail.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        '"$detail"',
                        style: body(
                          size: 12,
                          color: AppColors.slate500,
                          style: FontStyle.italic,
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      relativeDateTime(event.createdAt),
                      style: body(size: 12, color: AppColors.slate300),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
