import '../models.dart';
import 'api_client.dart';

// ─── Datas ───────────────────────────────────────────────────────────────────
const weekdaysShort = ['Dom', 'Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb'];
const _weekdaysLong = [
  'domingo',
  'segunda-feira',
  'terça-feira',
  'quarta-feira',
  'quinta-feira',
  'sexta-feira',
  'sábado',
];
const _months = [
  'janeiro',
  'fevereiro',
  'março',
  'abril',
  'maio',
  'junho',
  'julho',
  'agosto',
  'setembro',
  'outubro',
  'novembro',
  'dezembro',
];

String two(int value) => value.toString().padLeft(2, '0');
DateTime dayOf(DateTime date) => DateTime(date.year, date.month, date.day);
bool sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String hhmm(DateTime date) => '${two(date.hour)}:${two(date.minute)}';
String ddmmyyyy(DateTime date) =>
    '${two(date.day)}/${two(date.month)}/${date.year}';
String isoDate(DateTime date) =>
    '${date.year}-${two(date.month)}-${two(date.day)}';

/// "quinta-feira, 5 de novembro"
String longToday([DateTime? date]) {
  final d = date ?? DateTime.now();
  return '${_weekdaysLong[d.weekday % 7]}, ${d.day} de ${_months[d.month - 1]}';
}

/// "Hoje, 13:45" · "Ontem, 19:20" · "05/09/2026, 08:10"
String relativeDateTime(DateTime date) {
  final now = DateTime.now();
  if (sameDay(date, now)) return 'Hoje, ${hhmm(date)}';
  if (sameDay(date, now.subtract(const Duration(days: 1)))) {
    return 'Ontem, ${hhmm(date)}';
  }
  return '${ddmmyyyy(date)}, ${hhmm(date)}';
}

String greeting() {
  final hour = DateTime.now().hour;
  return hour < 12
      ? 'Bom dia'
      : hour < 18
      ? 'Boa tarde'
      : 'Boa noite';
}

/// Iniciais do primeiro e do último nome ("Maria das Graças Oliveira" → MO).
String initials(String name) {
  final words = name.split(' ').where((part) => part.isNotEmpty).toList();
  final relevant = words.where((part) => part.length > 2).toList();
  final source = relevant.isEmpty ? words : relevant;
  if (source.isEmpty) return '?';
  final last = source.length > 1 ? source.last[0] : '';
  return (source.first[0] + last).toUpperCase();
}

DateTime atTime(DateTime day, String time) {
  final parts = time.split(':');
  return DateTime(
    day.year,
    day.month,
    day.day,
    int.tryParse(parts.first) ?? 0,
    parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0,
  );
}

const lateTolerance = Duration(minutes: 30);

// ─── Agenda de medicamentos ──────────────────────────────────────────────────
enum DoseStatus { pendente, administrado, atrasado, naoAdministrado }

class DoseSlot {
  const DoseSlot({
    required this.patient,
    required this.medication,
    required this.time,
    required this.scheduledAt,
    required this.status,
    this.record,
  });

  final Patient patient;
  final Medication medication;
  final String time;
  final DateTime scheduledAt;
  final DoseStatus status;
  final Administration? record;

  bool get isOpen =>
      status == DoseStatus.pendente || status == DoseStatus.atrasado;
}

bool _medicationRunsOn(Medication medication, DateTime day) {
  final start = dayOf(medication.startDate ?? medication.createdAt);
  if (day.isBefore(start)) return false;
  final end = medication.endDate;
  if (end != null && day.isAfter(dayOf(end))) return false;
  if (medication.frequency == 'Em dias alternados') {
    return day.difference(start).inDays.isEven;
  }
  return true;
}

List<DoseSlot> dosesFor(PatientBundle bundle, DateTime day) {
  final date = dayOf(day);
  final now = DateTime.now();
  final result = <DoseSlot>[];
  for (final medication in bundle.medications) {
    if (!_medicationRunsOn(medication, date)) continue;
    for (final time in medication.schedule) {
      final scheduledAt = atTime(date, time);
      Administration? record;
      for (final item in bundle.administrations) {
        if (item.medicationId == medication.id &&
            sameDay(item.scheduledAt, scheduledAt) &&
            hhmm(item.scheduledAt) == time) {
          record = item;
          break;
        }
      }
      final DoseStatus status;
      if (record != null) {
        status = record.status == 'administered'
            ? DoseStatus.administrado
            : DoseStatus.naoAdministrado;
      } else if (now.isAfter(scheduledAt.add(lateTolerance))) {
        status = DoseStatus.atrasado;
      } else {
        status = DoseStatus.pendente;
      }
      result.add(
        DoseSlot(
          patient: bundle.patient,
          medication: medication,
          time: time,
          scheduledAt: scheduledAt,
          status: status,
          record: record,
        ),
      );
    }
  }
  result.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
  return result;
}

// ─── Plano de atividades ─────────────────────────────────────────────────────
enum ActivityStatus { concluida, pendente, atrasada, parcial, naoRealizada }

class ActivitySlot {
  const ActivitySlot({
    required this.patient,
    required this.activity,
    required this.status,
    this.scheduledAt,
    this.record,
  });

  final Patient patient;
  final CareActivity activity;
  final ActivityStatus status;
  final DateTime? scheduledAt;
  final ActivityRecord? record;

  bool get isOpen =>
      status == ActivityStatus.pendente || status == ActivityStatus.atrasada;
}

const _dayTokens = {
  'dom': 7,
  'seg': 1,
  'ter': 2,
  'qua': 3,
  'qui': 4,
  'sex': 5,
  'sáb': 6,
  'sab': 6,
};

/// Interpreta rotinas como "Seg, qua e sex" ou "Todos os dias".
bool activityRunsOn(CareActivity activity, DateTime day) {
  if (day.isBefore(dayOf(activity.createdAt))) return false;
  final text = activity.schedule.toLowerCase();
  final days = <int>{
    for (final entry in _dayTokens.entries)
      if (RegExp('\\b${entry.key}').hasMatch(text)) entry.value,
  };
  if (days.isEmpty) return true;
  return days.contains(day.weekday);
}

ActivityStatus _recordStatus(String status) => switch (status) {
  'completed' => ActivityStatus.concluida,
  'partial' => ActivityStatus.parcial,
  _ => ActivityStatus.naoRealizada,
};

ActivitySlot activitySlot(
  PatientBundle bundle,
  CareActivity activity,
  DateTime day,
) {
  final date = dayOf(day);
  ActivityRecord? record;
  for (final item in bundle.activityRecords) {
    if (item.activityId == activity.id && sameDay(item.performedAt, date)) {
      record = item;
      break;
    }
  }
  final time = activity.timeLabel;
  final scheduledAt = time == '--:--' ? null : atTime(date, time);
  final ActivityStatus status;
  if (record != null) {
    status = _recordStatus(record.status);
  } else if (scheduledAt != null &&
      DateTime.now().isAfter(scheduledAt.add(lateTolerance))) {
    status = ActivityStatus.atrasada;
  } else {
    status = ActivityStatus.pendente;
  }
  return ActivitySlot(
    patient: bundle.patient,
    activity: activity,
    status: status,
    scheduledAt: scheduledAt,
    record: record,
  );
}

List<ActivitySlot> activitiesFor(PatientBundle bundle, DateTime day) {
  final result = [
    for (final activity in bundle.activities)
      if (activityRunsOn(activity, day)) activitySlot(bundle, activity, day),
  ];
  result.sort(
    (a, b) => (a.scheduledAt ?? DateTime(9999)).compareTo(
      b.scheduledAt ?? DateTime(9999),
    ),
  );
  return result;
}

// ─── Pacote de dados por paciente ────────────────────────────────────────────
class PatientBundle {
  PatientBundle({
    required this.patient,
    this.medications = const [],
    this.administrations = const [],
    this.activities = const [],
    this.activityRecords = const [],
    this.observations = const [],
    this.alerts = const [],
    this.medicationsDenied = false,
  });

  Patient patient;
  final List<Medication> medications;
  final List<Administration> administrations;
  final List<CareActivity> activities;
  final List<ActivityRecord> activityRecords;
  final List<Observation> observations;
  final List<EmergencyAlert> alerts;
  final bool medicationsDenied;

  List<DoseSlot> get todayDoses => dosesFor(this, DateTime.now());
  List<ActivitySlot> get todayActivities => activitiesFor(this, DateTime.now());

  List<DoseSlot> get lateDoses =>
      todayDoses.where((slot) => slot.status == DoseStatus.atrasado).toList();

  DoseSlot? get nextDose {
    final doses = todayDoses;
    for (final slot in doses) {
      if (slot.status == DoseStatus.atrasado) return slot;
    }
    for (final slot in doses) {
      if (slot.status == DoseStatus.pendente) return slot;
    }
    return null;
  }

  Administration? get lastAdministration {
    for (final item in administrations) {
      if (item.status == 'administered') return item;
    }
    return null;
  }

  Medication? medicationById(String id) {
    for (final item in medications) {
      if (item.id == id) return item;
    }
    return null;
  }

  List<EmergencyAlert> get activeAlerts =>
      alerts.where((alert) => alert.isActive).toList();

  /// Observações das últimas 24 h registradas por outras pessoas.
  int recentObservationsFrom(String userId) {
    final limit = DateTime.now().subtract(const Duration(hours: 24));
    return observations
        .where(
          (item) => item.authorId != userId && item.createdAt.isAfter(limit),
        )
        .length;
  }

  bool get hasUrgentToday => observations.any(
    (item) =>
        item.level == 'urgent' &&
        item.createdAt.isAfter(
          DateTime.now().subtract(const Duration(hours: 24)),
        ),
  );

  /// Status exibido: inativo vem do cadastro; atenção é derivada da rotina.
  String get displayStatus {
    if (patient.status == 'inactive') return 'inativo';
    if (patient.status == 'attention' ||
        lateDoses.isNotEmpty ||
        activeAlerts.isNotEmpty ||
        hasUrgentToday) {
      return 'atencao';
    }
    return 'ativo';
  }

  int get activeAlertCount =>
      activeAlerts.length + lateDoses.length + (hasUrgentToday ? 1 : 0);

  ({int done, int total, int late, int pending, int activities})
  get todayProgress {
    final doses = todayDoses;
    final acts = todayActivities;
    final done =
        doses.where((d) => d.status == DoseStatus.administrado).length +
        acts.where((a) => a.status == ActivityStatus.concluida).length;
    final late =
        doses.where((d) => d.status == DoseStatus.atrasado).length +
        acts.where((a) => a.status == ActivityStatus.atrasada).length;
    final pending =
        doses.where((d) => d.status == DoseStatus.pendente).length +
        acts.where((a) => a.status == ActivityStatus.pendente).length;
    return (
      done: done,
      total: doses.length + acts.length,
      late: late,
      pending: pending,
      activities: acts.length,
    );
  }
}

typedef MedicationData = ({
  List<Medication> medications,
  List<Administration> records,
});

Future<MedicationData?> _medicationsOrNull(
  ApiClient api,
  Patient patient,
) async {
  if (!patient.permissions.canViewMedications) return null;
  try {
    return await api.medications(patient.id);
  } on ApiException catch (error) {
    if (error.isForbidden) return null;
    rethrow;
  }
}

Future<PatientBundle> loadBundle(ApiClient api, Patient patient) async {
  final medsFuture = _medicationsOrNull(api, patient);
  final careFuture = api.careActivities(patient.id);
  final observationsFuture = api.observations(patient.id);
  final alertsFuture = api.emergencyAlerts(patient.id);
  final meds = await medsFuture;
  final care = await careFuture;
  return PatientBundle(
    patient: patient,
    medications: meds?.medications ?? const [],
    administrations: meds?.records ?? const [],
    medicationsDenied: meds == null,
    activities: care.activities,
    activityRecords: care.records,
    observations: await observationsFuture,
    alerts: await alertsFuture,
  );
}

Future<List<PatientBundle>> loadAllBundles(ApiClient api) async {
  final patients = await api.patients();
  return Future.wait(patients.map((patient) => loadBundle(api, patient)));
}

// ─── Rótulos de auditoria ────────────────────────────────────────────────────
enum EventKind {
  medicamento,
  atividade,
  observacao,
  acionamento,
  profissional,
  outro,
}

EventKind eventKind(String action) {
  if (action.startsWith('medication')) return EventKind.medicamento;
  if (action.startsWith('care_activity')) return EventKind.atividade;
  if (action.startsWith('observation')) return EventKind.observacao;
  if (action.startsWith('emergency')) return EventKind.acionamento;
  if (action.contains('member') || action.contains('professional')) {
    return EventKind.profissional;
  }
  return EventKind.outro;
}

String eventTitle(AuditEvent event) {
  final m = event.metadata;
  String s(String key) => m[key]?.toString() ?? '';
  return switch (event.action) {
    'patient.created' => 'Paciente cadastrado',
    'patient.updated' => 'Dados do paciente alterados',
    'patient.professional_joined' => 'Profissional entrou na equipe',
    'patient.invite_rotated' => 'Novo código de convite gerado',
    'patient.member_permissions_updated' => 'Permissões alteradas',
    'patient.member_suspended' => 'Acesso de profissional suspenso',
    'patient.member_reactivated' => 'Acesso de profissional reativado',
    'patient.member_removed' => 'Profissional removido da equipe',
    'medication.created' => 'Medicamento cadastrado',
    'medication.administration_recorded' =>
      s('status') == 'administered'
          ? '${s('name').isEmpty ? 'Medicamento' : s('name')} administrado'
          : '${s('name').isEmpty ? 'Medicamento' : s('name')} não administrado',
    'observation.created' =>
      s('level') == 'urgent'
          ? 'Intercorrência registrada'
          : 'Observação registrada',
    'care_activity.created' => 'Atividade incluída no plano',
    'care_activity.recorded' => switch (s('status')) {
      'completed' => 'Atividade concluída',
      'partial' => 'Atividade realizada parcialmente',
      _ => 'Atividade não realizada',
    },
    'emergency.triggered' => 'Responsável acionado',
    'emergency.acknowledged' => 'Acionamento visualizado',
    'demo.seeded' => 'Espaço do paciente criado',
    _ => 'Evento do plano de cuidados',
  };
}

String eventDetail(AuditEvent event) {
  final m = event.metadata;
  final who = event.actor?.name ?? 'Equipe';
  final extra = switch (event.action) {
    'medication.created' => '${m['name'] ?? ''} ${m['dosage'] ?? ''}'.trim(),
    'medication.administration_recorded' => m['notes']?.toString() ?? '',
    'observation.created' => m['category']?.toString() ?? '',
    'care_activity.created' ||
    'care_activity.recorded' => m['title']?.toString() ?? '',
    'emergency.triggered' => [
      m['reason'],
      m['message'],
    ].where((v) => v != null && v.toString().isNotEmpty).join(' — '),
    'patient.member_permissions_updated' ||
    'patient.member_suspended' ||
    'patient.member_reactivated' ||
    'patient.member_removed' ||
    'patient.professional_joined' => m['name']?.toString() ?? '',
    _ => '',
  };
  return extra.isEmpty ? who : '$who · $extra';
}

/// "urgente" | "atencao" | "info"
String eventLevel(AuditEvent event) {
  final m = event.metadata;
  if (event.action == 'observation.created') {
    if (m['level'] == 'urgent') return 'urgente';
    if (m['level'] == 'attention') return 'atencao';
  }
  if (event.action == 'emergency.triggered') {
    return m['priority'] == 'critica' ? 'urgente' : 'atencao';
  }
  if (event.action == 'medication.administration_recorded' &&
      m['status'] != 'administered') {
    return 'atencao';
  }
  return 'info';
}
