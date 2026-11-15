typedef Json = Map<String, dynamic>;

String? _str(dynamic value) => value?.toString();
DateTime? _date(dynamic value) =>
    value == null ? null : DateTime.tryParse(value.toString())?.toLocal();
bool _bool(dynamic value, [bool fallback = false]) =>
    value is bool ? value : fallback;
int? _int(dynamic value) =>
    value is int ? value : int.tryParse(value?.toString() ?? '');

class UserProfile {
  const UserProfile({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.cpf,
    this.phone,
    this.profession,
    this.professionalCouncil,
  });

  final String id;
  final String name;
  final String email;
  final String role;
  final String? cpf;
  final String? phone;
  final String? profession;
  final String? professionalCouncil;

  bool get isResponsible => role == 'responsible';
  bool get isProfessional => !isResponsible;
  String get firstName => name.split(' ').first;

  factory UserProfile.fromJson(Json json) => UserProfile(
    id: json['id'] as String,
    name: json['name'] as String,
    email: json['email'] as String,
    role: json['role'] as String,
    cpf: _str(json['cpf']),
    phone: _str(json['phone']),
    profession: _str(json['profession']),
    professionalCouncil: _str(json['professionalCouncil']),
  );
}

/// Autor resumido devolvido pela API nos registros.
class Person {
  const Person({
    required this.id,
    required this.name,
    required this.role,
    this.profession,
    this.professionalCouncil,
  });

  final String id;
  final String name;
  final String role;
  final String? profession;
  final String? professionalCouncil;

  bool get isResponsible => role == 'responsible';

  String get roleLabel {
    if (isResponsible) return 'Responsável';
    final parts = [
      if (profession?.isNotEmpty == true) profession!,
      if (professionalCouncil?.isNotEmpty == true) professionalCouncil!,
    ];
    return parts.isEmpty ? 'Profissional' : parts.join(' · ');
  }

  static Person? maybe(dynamic json) {
    if (json is! Map<String, dynamic>) return null;
    return Person(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Integrante da equipe',
      role: json['role']?.toString() ?? 'professional',
      profession: _str(json['profession']),
      professionalCouncil: _str(json['professionalCouncil']),
    );
  }
}

class PatientPermissions {
  const PatientPermissions({
    this.canViewMedications = true,
    this.canRecordMedications = true,
    this.canManageCarePlan = false,
    this.canRecordActivities = true,
    this.canRecordObservations = true,
    this.canViewHistory = true,
    this.canEditPatient = false,
  });

  final bool canViewMedications;
  final bool canRecordMedications;
  final bool canManageCarePlan;
  final bool canRecordActivities;
  final bool canRecordObservations;
  final bool canViewHistory;
  final bool canEditPatient;

  static const keys = [
    'canViewMedications',
    'canRecordMedications',
    'canManageCarePlan',
    'canRecordActivities',
    'canRecordObservations',
    'canViewHistory',
    'canEditPatient',
  ];

  bool operator [](String key) => toJson()[key] ?? false;

  Map<String, bool> toJson() => {
    'canViewMedications': canViewMedications,
    'canRecordMedications': canRecordMedications,
    'canManageCarePlan': canManageCarePlan,
    'canRecordActivities': canRecordActivities,
    'canRecordObservations': canRecordObservations,
    'canViewHistory': canViewHistory,
    'canEditPatient': canEditPatient,
  };

  factory PatientPermissions.fromJson(dynamic json) {
    if (json is! Map<String, dynamic>) return const PatientPermissions();
    return PatientPermissions(
      canViewMedications: _bool(json['canViewMedications'], true),
      canRecordMedications: _bool(json['canRecordMedications'], true),
      canManageCarePlan: _bool(json['canManageCarePlan']),
      canRecordActivities: _bool(json['canRecordActivities'], true),
      canRecordObservations: _bool(json['canRecordObservations'], true),
      canViewHistory: _bool(json['canViewHistory'], true),
      canEditPatient: _bool(json['canEditPatient']),
    );
  }

  factory PatientPermissions.fromMap(Map<String, bool> map) =>
      PatientPermissions.fromJson(map);
}

class Patient {
  const Patient({
    required this.id,
    required this.name,
    required this.birthDate,
    required this.status,
    required this.joinCode,
    this.inviteExpiresAt,
    this.conditions,
    this.allergies,
    this.restrictions,
    this.contactMain,
    this.contactAlt,
    this.notes,
    this.responsibleId,
    this.responsibleName,
    this.professionalsCount = 0,
    this.permissions = const PatientPermissions(),
  });

  final String id;
  final String name;
  final String birthDate;
  final String status;
  final String joinCode;
  final DateTime? inviteExpiresAt;
  final String? conditions;
  final String? allergies;
  final String? restrictions;
  final String? contactMain;
  final String? contactAlt;
  final String? notes;
  final String? responsibleId;
  final String? responsibleName;
  final int professionalsCount;
  final PatientPermissions permissions;

  String get firstName => name.split(' ').first;

  int get age {
    final birth = DateTime.tryParse(birthDate);
    if (birth == null) return 0;
    final today = DateTime.now();
    var result = today.year - birth.year;
    if (today.month < birth.month ||
        (today.month == birth.month && today.day < birth.day)) {
      result--;
    }
    return result;
  }

  factory Patient.fromJson(Json json) => Patient(
    id: json['id'] as String,
    name: json['name'] as String,
    birthDate: json['birthDate']?.toString() ?? '',
    status: json['status']?.toString() ?? 'active',
    joinCode: json['joinCode']?.toString() ?? '',
    inviteExpiresAt: _date(json['inviteExpiresAt']),
    conditions: _str(json['conditions']),
    allergies: _str(json['allergies']),
    restrictions: _str(json['restrictions']),
    contactMain: _str(json['contactMain']),
    contactAlt: _str(json['contactAlt']),
    notes: _str(json['notes']),
    responsibleId: _str(json['responsibleId']),
    responsibleName: _str(json['responsibleName']),
    professionalsCount: _int(json['professionalsCount']) ?? 0,
    permissions: PatientPermissions.fromJson(json['permissions']),
  );
}

class Medication {
  const Medication({
    required this.id,
    required this.patientId,
    required this.name,
    required this.dosage,
    required this.route,
    required this.schedule,
    required this.createdAt,
    this.frequency,
    this.startDate,
    this.endDate,
    this.instructions,
  });

  final String id;
  final String patientId;
  final String name;
  final String dosage;
  final String route;
  final List<String> schedule;
  final DateTime createdAt;
  final String? frequency;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? instructions;

  String get label => '$name $dosage';

  factory Medication.fromJson(Json json) => Medication(
    id: json['id'] as String,
    patientId: json['patientId']?.toString() ?? '',
    name: json['name']?.toString() ?? 'Medicamento',
    dosage: json['dosage']?.toString() ?? '',
    route: json['route']?.toString() ?? '',
    schedule: [
      for (final item in (json['schedule'] as List<dynamic>? ?? []))
        item.toString(),
    ]..sort(),
    createdAt: _date(json['createdAt']) ?? DateTime.now(),
    frequency: _str(json['frequency']),
    startDate: DateTime.tryParse(json['startDate']?.toString() ?? ''),
    endDate: DateTime.tryParse(json['endDate']?.toString() ?? ''),
    instructions: _str(json['instructions']),
  );
}

class Administration {
  const Administration({
    required this.id,
    required this.medicationId,
    required this.status,
    required this.scheduledAt,
    required this.createdAt,
    this.administeredAt,
    this.notes,
    this.recordedById,
    this.recordedBy,
  });

  final String id;
  final String medicationId;
  final String status;
  final DateTime scheduledAt;
  final DateTime createdAt;
  final DateTime? administeredAt;
  final String? notes;
  final String? recordedById;
  final Person? recordedBy;

  factory Administration.fromJson(Json json) => Administration(
    id: json['id'] as String,
    medicationId: json['medicationId']?.toString() ?? '',
    status: json['status']?.toString() ?? 'administered',
    scheduledAt: _date(json['scheduledAt']) ?? DateTime.now(),
    createdAt: _date(json['createdAt']) ?? DateTime.now(),
    administeredAt: _date(json['administeredAt']),
    notes: _str(json['notes']),
    recordedById: _str(json['recordedById']),
    recordedBy: Person.maybe(json['recordedBy']),
  );
}

class CareActivity {
  const CareActivity({
    required this.id,
    required this.patientId,
    required this.title,
    required this.type,
    required this.objective,
    required this.instructions,
    required this.schedule,
    required this.createdAt,
    this.time,
    this.duration,
    this.series,
    this.needsAssistance = false,
    this.createdBy,
  });

  final String id;
  final String patientId;
  final String title;
  final String type;
  final String objective;
  final String instructions;
  final String schedule;
  final DateTime createdAt;
  final String? time;
  final String? duration;
  final String? series;
  final bool needsAssistance;
  final Person? createdBy;

  /// Horário explícito ou o primeiro HH:mm encontrado na rotina.
  String get timeLabel {
    if (time?.isNotEmpty == true) return time!;
    final match = RegExp(r'([01]\d|2[0-3]):[0-5]\d').firstMatch(schedule);
    return match?.group(0) ?? '--:--';
  }

  factory CareActivity.fromJson(Json json) => CareActivity(
    id: json['id'] as String,
    patientId: json['patientId']?.toString() ?? '',
    title: json['title']?.toString() ?? 'Atividade',
    type: json['type']?.toString() ?? 'Tarefa geral',
    objective: json['objective']?.toString() ?? '',
    instructions: json['instructions']?.toString() ?? '',
    schedule: json['schedule']?.toString() ?? '',
    createdAt: _date(json['createdAt']) ?? DateTime.now(),
    time: _str(json['time']),
    duration: _str(json['duration']),
    series: _str(json['series']),
    needsAssistance: _bool(json['needsAssistance']),
    createdBy: Person.maybe(json['createdBy']),
  );
}

class ActivityRecord {
  const ActivityRecord({
    required this.id,
    required this.activityId,
    required this.status,
    required this.performedAt,
    this.painBefore,
    this.painAfter,
    this.notes,
    this.performedById,
    this.performedBy,
  });

  final String id;
  final String activityId;
  final String status;
  final DateTime performedAt;
  final int? painBefore;
  final int? painAfter;
  final String? notes;
  final String? performedById;
  final Person? performedBy;

  factory ActivityRecord.fromJson(Json json) => ActivityRecord(
    id: json['id'] as String,
    activityId: json['activityId']?.toString() ?? '',
    status: json['status']?.toString() ?? 'completed',
    performedAt: _date(json['performedAt']) ?? DateTime.now(),
    painBefore: _int(json['painBefore']),
    painAfter: _int(json['painAfter']),
    notes: _str(json['notes']),
    performedById: _str(json['performedById']),
    performedBy: Person.maybe(json['performedBy']),
  );
}

class Observation {
  const Observation({
    required this.id,
    required this.patientId,
    required this.category,
    required this.level,
    required this.text,
    required this.createdAt,
    this.notifyResponsible = false,
    this.authorId,
    this.author,
  });

  final String id;
  final String patientId;
  final String category;

  /// information | attention | urgent
  final String level;
  final String text;
  final DateTime createdAt;
  final bool notifyResponsible;
  final String? authorId;
  final Person? author;

  factory Observation.fromJson(Json json) => Observation(
    id: json['id'] as String,
    patientId: json['patientId']?.toString() ?? '',
    category: json['category']?.toString() ?? 'Observação geral',
    level: json['level']?.toString() ?? 'information',
    text: json['text']?.toString() ?? '',
    createdAt: _date(json['createdAt']) ?? DateTime.now(),
    notifyResponsible: _bool(json['notifyResponsible']),
    authorId: _str(json['authorId']),
    author: Person.maybe(json['author']),
  );
}

class EmergencyAlert {
  const EmergencyAlert({
    required this.id,
    required this.patientId,
    required this.status,
    required this.priority,
    required this.createdAt,
    this.reason,
    this.message,
    this.acknowledgedAt,
    this.triggeredById,
    this.triggeredBy,
    this.acknowledgedBy,
    this.notifiedName,
  });

  final String id;
  final String patientId;
  final String status;
  final String priority;
  final DateTime createdAt;
  final String? reason;
  final String? message;
  final DateTime? acknowledgedAt;
  final String? triggeredById;
  final Person? triggeredBy;
  final Person? acknowledgedBy;
  final String? notifiedName;

  bool get isActive => status == 'active';

  factory EmergencyAlert.fromJson(Json json) => EmergencyAlert(
    id: json['id'] as String,
    patientId: json['patientId']?.toString() ?? '',
    status: json['status']?.toString() ?? 'active',
    priority: json['priority']?.toString() ?? 'normal',
    createdAt: _date(json['createdAt']) ?? DateTime.now(),
    reason: _str(json['reason']),
    message: _str(json['message']),
    acknowledgedAt: _date(json['acknowledgedAt']),
    triggeredById: _str(json['triggeredById']),
    triggeredBy: Person.maybe(json['triggeredBy']),
    acknowledgedBy: Person.maybe(json['acknowledgedBy']),
    notifiedName: _str(json['notifiedName']),
  );
}

class AuditEvent {
  const AuditEvent({
    required this.id,
    required this.action,
    required this.createdAt,
    required this.metadata,
    this.patientId,
    this.actorId,
    this.actor,
  });

  final String id;
  final String action;
  final DateTime createdAt;
  final Json metadata;
  final String? patientId;
  final String? actorId;
  final Person? actor;

  factory AuditEvent.fromJson(Json json) => AuditEvent(
    id: json['id']?.toString() ?? '',
    action: json['action']?.toString() ?? '',
    createdAt: _date(json['createdAt']) ?? DateTime.now(),
    metadata: (json['metadata'] as Map<String, dynamic>?) ?? const {},
    patientId: _str(json['patientId']),
    actorId: _str(json['actorId']),
    actor: Person.maybe(json['actor']),
  );
}

class TeamMember {
  const TeamMember({
    required this.id,
    required this.userId,
    required this.name,
    required this.active,
    required this.createdAt,
    required this.permissions,
    this.email,
    this.profession,
    this.professionalCouncil,
    this.lastAccessAt,
  });

  final String id;
  final String userId;
  final String name;
  final bool active;
  final DateTime createdAt;
  final PatientPermissions permissions;
  final String? email;
  final String? profession;
  final String? professionalCouncil;
  final DateTime? lastAccessAt;

  factory TeamMember.fromJson(Json json) => TeamMember(
    id: json['id'] as String,
    userId: json['userId']?.toString() ?? '',
    name: json['name']?.toString() ?? 'Profissional',
    active: _bool(json['active'], true),
    createdAt: _date(json['createdAt']) ?? DateTime.now(),
    permissions: PatientPermissions.fromJson(json['permissions']),
    email: _str(json['email']),
    profession: _str(json['profession']),
    professionalCouncil: _str(json['professionalCouncil']),
    lastAccessAt: _date(json['lastAccessAt']),
  );
}

class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.read,
    this.patientId,
    this.local = false,
  });

  final String id;
  final String type;
  final String title;
  final String body;
  final DateTime createdAt;
  final bool read;
  final String? patientId;

  /// Gerada no aplicativo (por exemplo, medicamento atrasado).
  final bool local;

  AppNotification copyWith({bool? read}) => AppNotification(
    id: id,
    type: type,
    title: title,
    body: body,
    createdAt: createdAt,
    read: read ?? this.read,
    patientId: patientId,
    local: local,
  );

  factory AppNotification.fromJson(Json json) => AppNotification(
    id: json['id'] as String,
    type: json['type']?.toString() ?? 'info',
    title: json['title']?.toString() ?? 'Notificação',
    body: json['body']?.toString() ?? '',
    createdAt: _date(json['createdAt']) ?? DateTime.now(),
    read: _bool(json['read']),
    patientId: _str(json['patientId']),
  );
}

class TrustedDevice {
  const TrustedDevice({
    required this.id,
    required this.deviceId,
    required this.name,
    required this.createdAt,
    this.lastUsedAt,
  });

  final String id;
  final String deviceId;
  final String name;
  final DateTime createdAt;
  final DateTime? lastUsedAt;

  factory TrustedDevice.fromJson(Json json) => TrustedDevice(
    id: json['id'] as String,
    deviceId: json['deviceId']?.toString() ?? '',
    name: json['name']?.toString() ?? 'Aparelho',
    createdAt: _date(json['createdAt']) ?? DateTime.now(),
    lastUsedAt: _date(json['lastUsedAt']),
  );
}
