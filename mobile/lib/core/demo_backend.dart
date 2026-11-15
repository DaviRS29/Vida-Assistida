// Modo demonstração do Vida Assistida.
//
// Ativado com `--dart-define=DEMO=true`. Substitui a API por um servidor em
// memória que responde às mesmas rotas e no mesmo formato JSON, com dados
// fictícios. Usado no teste de usabilidade: cada recarga da página recomeça
// do mesmo estado, sem banco de dados, e-mail ou dados reais.
import 'dart:math';

import 'api_client.dart';

typedef _J = Map<String, dynamic>;

class DemoBackend {
  DemoBackend._() {
    _seed();
  }

  static const enabled = bool.fromEnvironment('DEMO');
  static final instance = DemoBackend._();

  /// Código fixo do segundo fator exibido na tela durante a demonstração.
  static const code = '123456';
  static const _password = 'Demo@123';

  final _users = <_J>[];
  final _patients = <_J>[];
  final _members = <_J>[];
  final _medications = <_J>[];
  final _administrations = <_J>[];
  final _activities = <_J>[];
  final _activityRecords = <_J>[];
  final _observations = <_J>[];
  final _alerts = <_J>[];
  final _audit = <_J>[];
  final _reads = <String>{};
  final _devices = <_J>[];
  _J? _current;
  int _seq = 0;
  final _random = Random();

  // ─── Utilidades ───────────────────────────────────────────────────────────
  String _id() => 'demo-${++_seq}-${_random.nextInt(1000000)}';
  String _now() => DateTime.now().toUtc().toIso8601String();
  String _ago(Duration d) =>
      DateTime.now().subtract(d).toUtc().toIso8601String();
  Never _fail(String message, int status) =>
      throw ApiException(message, statusCode: status);

  _J get _me => _current ?? _fail('Sessão expirada. Entre novamente.', 401);

  _J? _person(String? id) {
    final user = _users.where((u) => u['id'] == id).firstOrNull;
    if (user == null) return null;
    return {
      'id': user['id'],
      'name': user['name'],
      'role': user['role'],
      'profession': user['profession'],
      'professionalCouncil': user['professionalCouncil'],
    };
  }

  _J _publicUser(_J user) => {
    for (final e in user.entries)
      if (e.key != 'password') e.key: e.value,
  };

  void _record(
    String action,
    String? patientId,
    String entityType,
    String? entityId,
    _J metadata,
  ) {
    _audit.insert(0, {
      'id': _id(),
      'actorId': _me['id'],
      'patientId': patientId,
      'action': action,
      'entityType': entityType,
      'entityId': entityId,
      'metadata': metadata,
      'createdAt': _now(),
    });
  }

  static const _permissionKeys = [
    'canViewMedications',
    'canRecordMedications',
    'canManageCarePlan',
    'canRecordActivities',
    'canRecordObservations',
    'canViewHistory',
    'canEditPatient',
  ];

  static const _permissionMessages = {
    'canViewMedications': 'Sem permissão para consultar medicamentos.',
    'canRecordMedications': 'Sem permissão para registrar medicamentos.',
    'canManageCarePlan': 'Sem permissão para alterar o plano de cuidados.',
    'canRecordActivities': 'Sem permissão para registrar atividades.',
    'canRecordObservations': 'Sem permissão para registrar observações.',
    'canViewHistory': 'Sem permissão para visualizar o histórico.',
    'canEditPatient': 'Sem permissão para editar os dados do paciente.',
  };

  _J _permissionsOf(_J? member) => {
    for (final key in _permissionKeys)
      key: member == null || member[key] == true,
  };

  // ─── Acesso aos pacientes ─────────────────────────────────────────────────
  _J? _membership(String patientId, String userId) => _members
      .where(
        (m) =>
            m['patientId'] == patientId &&
            m['userId'] == userId &&
            m['active'] == true,
      )
      .firstOrNull;

  ({_J patient, _J? member}) _access(String patientId) {
    final patient =
        _patients.where((p) => p['id'] == patientId).firstOrNull ??
        _fail('Paciente não encontrado.', 404);
    if (patient['responsibleId'] == _me['id']) {
      return (patient: patient, member: null);
    }
    final member =
        _membership(patientId, _me['id'] as String) ??
        _fail('Você não possui acesso a este paciente.', 403);
    member['lastAccessAt'] = _now();
    return (patient: patient, member: member);
  }

  _J _assertPermission(String patientId, String permission) {
    final access = _access(patientId);
    if (access.member != null && access.member![permission] != true) {
      _fail(_permissionMessages[permission]!, 403);
    }
    return access.patient;
  }

  _J _assertResponsible(String patientId) {
    final access = _access(patientId);
    if (access.member != null) {
      _fail('Somente o responsável pode realizar esta ação.', 403);
    }
    return access.patient;
  }

  int _activeCount(String patientId) => _members
      .where((m) => m['patientId'] == patientId && m['active'] == true)
      .length;

  _J _patientView(_J patient, _J? member) {
    final owner = patient['responsibleId'] == _me['id'];
    return {
      ...patient,
      'joinCode': owner ? patient['joinCode'] : '',
      'inviteExpiresAt': owner ? patient['inviteExpiresAt'] : null,
      'responsibleName': _person(patient['responsibleId'] as String)?['name'],
      'professionalsCount': _activeCount(patient['id'] as String),
      'permissions': _permissionsOf(member),
    };
  }

  _J _memberView(_J member) {
    final user = _users.firstWhere((u) => u['id'] == member['userId']);
    return {
      'id': member['id'],
      'userId': member['userId'],
      'name': user['name'],
      'email': user['email'],
      'profession': user['profession'],
      'professionalCouncil': user['professionalCouncil'],
      'active': member['active'],
      'lastAccessAt': member['lastAccessAt'],
      'createdAt': member['createdAt'],
      'permissions': {for (final k in _permissionKeys) k: member[k] == true},
    };
  }

  String _newInviteCode() {
    const hex = '0123456789ABCDEF';
    return 'VID-${List.generate(4, (_) => hex[_random.nextInt(16)]).join()}';
  }

  // ─── Roteamento ───────────────────────────────────────────────────────────
  Future<dynamic> handle(
    String method,
    String path,
    Map<String, dynamic>? body,
  ) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    final b = body ?? const {};
    final s = path
        .split('?')
        .first
        .split('/')
        .where((p) => p.isNotEmpty)
        .toList();
    String seg(int i) => i < s.length ? s[i] : '';
    final route =
        '$method ${s.map((p) => p.startsWith('demo-') || p.length > 20 ? ':id' : p).join('/')}';

    switch (route) {
      // Autenticação
      case 'POST auth/login':
        return _login(b);
      case 'POST auth/login/verify-code':
        return _verifyCode(b);
      case 'POST auth/login/verify-device':
        return _verifyDevice(b);
      case 'POST auth/login/send-code':
        return _codeStep(_pendingUser(b['loginToken']));
      case 'GET auth/devices':
        return _devices.where((d) => d['userId'] == _me['id']).toList();
      case 'DELETE auth/devices/:id':
        _devices.removeWhere((d) => d['id'] == seg(2));
        return null;
      case 'POST auth/register':
        return _register(b);
      case 'POST auth/forgot-password':
        return {'sent': true};
      case 'PATCH auth/me':
        _me.addAll({
          for (final e in b.entries)
            if (e.value != null) e.key: e.value,
        });
        return _publicUser(_me);
      case 'POST auth/change-password':
        if (b['currentPassword'] != (_me['password'] ?? _password)) {
          _fail('Senha atual incorreta.', 401);
        }
        _me['password'] = b['newPassword'];
        return {'changed': true};

      // Pacientes
      case 'GET patients':
        return _listPatients();
      case 'POST patients':
        return _createPatient(b);
      case 'POST patients/invite/validate':
        _findByCode(b['code']);
        return {'valid': true};
      case 'POST patients/join':
        return _join(b['code']);
      case 'GET patients/:id':
        final a = _access(seg(1));
        return _patientView(a.patient, a.member);
      case 'PATCH patients/:id':
        return _updatePatient(seg(1), b);
      case 'POST patients/:id/invite-code':
        final patient = _assertResponsible(seg(1));
        patient['joinCode'] = _newInviteCode();
        patient['inviteExpiresAt'] = DateTime.now()
            .add(const Duration(days: 7))
            .toUtc()
            .toIso8601String();
        _record(
          'patient.invite_rotated',
          patient['id'],
          'patient',
          patient['id'],
          {},
        );
        return _patientView(patient, null);
      case 'GET patients/:id/members':
        _assertResponsible(seg(1));
        return _members
            .where((m) => m['patientId'] == seg(1))
            .map(_memberView)
            .toList();
      case 'PATCH patients/:id/members/:id':
        return _updateMember(seg(1), seg(3), b);
      case 'DELETE patients/:id/members/:id':
        return _removeMember(seg(1), seg(3));

      // Medicamentos
      case 'GET patients/:id/medications':
        _assertPermission(seg(1), 'canViewMedications');
        return {
          'medications': _medications
              .where((m) => m['patientId'] == seg(1))
              .toList(),
          'administrations': _administrations
              .where((a) => a['patientId'] == seg(1))
              .map((a) => {...a, 'recordedBy': _person(a['recordedById'])})
              .toList(),
        };
      case 'POST patients/:id/medications':
        _assertPermission(seg(1), 'canManageCarePlan');
        final med = {
          'id': _id(),
          'patientId': seg(1),
          ...b,
          'schedule': ((b['schedule'] as List?) ?? []).toSet().toList()..sort(),
          'active': true,
          'createdAt': _now(),
        };
        _medications.add(med);
        _record('medication.created', seg(1), 'medication', med['id'], {
          'name': med['name'],
          'dosage': med['dosage'],
        });
        return med;
      case 'POST medications/:id/administrations':
        return _recordMedication(seg(1), b);

      // Observações
      case 'GET patients/:id/observations':
        _access(seg(1));
        return _observations
            .where((o) => o['patientId'] == seg(1))
            .map((o) => {...o, 'author': _person(o['authorId'])})
            .toList();
      case 'POST patients/:id/observations':
        _assertPermission(seg(1), 'canRecordObservations');
        final obs = {
          'id': _id(),
          'patientId': seg(1),
          'authorId': _me['id'],
          ...b,
          'notifyResponsible': b['notifyResponsible'] ?? false,
          'createdAt': _now(),
        };
        _observations.insert(0, obs);
        _record('observation.created', seg(1), 'observation', obs['id'], {
          'category': obs['category'],
          'level': obs['level'],
          'notifyResponsible': obs['notifyResponsible'],
        });
        return {...obs, 'author': _person(_me['id'])};

      // Plano de cuidados
      case 'GET patients/:id/care-activities':
        _access(seg(1));
        return {
          'activities': _activities
              .where((a) => a['patientId'] == seg(1))
              .map((a) => {...a, 'createdBy': _person(a['createdById'])})
              .toList(),
          'records': _activityRecords
              .where((r) => r['patientId'] == seg(1))
              .map((r) => {...r, 'performedBy': _person(r['performedById'])})
              .toList(),
        };
      case 'POST patients/:id/care-activities':
        _assertPermission(seg(1), 'canManageCarePlan');
        final act = {
          'id': _id(),
          'patientId': seg(1),
          'createdById': _me['id'],
          ...b,
          'active': true,
          'createdAt': _now(),
        };
        _activities.insert(0, act);
        _record('care_activity.created', seg(1), 'care_activity', act['id'], {
          'title': act['title'],
          'type': act['type'],
        });
        return act;
      case 'POST care-activities/:id/records':
        return _recordActivity(seg(1), b);

      // Histórico, acionamentos e notificações
      case 'GET patients/:id/audit':
        _assertPermission(seg(1), 'canViewHistory');
        return _audit
            .where((e) => e['patientId'] == seg(1))
            .map((e) => {...e, 'actor': _person(e['actorId'])})
            .toList();
      case 'GET patients/:id/emergency-alerts':
        _access(seg(1));
        return _alerts
            .where((a) => a['patientId'] == seg(1))
            .map(_alertView)
            .toList();
      case 'POST patients/:id/emergency-alerts':
        final patient = _access(seg(1)).patient;
        final alert = {
          'id': _id(),
          'patientId': seg(1),
          'triggeredById': _me['id'],
          'status': 'active',
          'priority': b['priority'] ?? 'normal',
          'reason': b['reason'],
          'message': b['message'],
          'createdAt': _now(),
        };
        _alerts.insert(0, alert);
        _record('emergency.triggered', seg(1), 'emergency_alert', alert['id'], {
          'reason': alert['reason'],
          'priority': alert['priority'],
          'message': alert['message'],
        });
        return {
          ..._alertView(alert),
          'notifiedName': _person(patient['responsibleId'])?['name'],
        };
      case 'PATCH emergency-alerts/:id/acknowledge':
        final alert =
            _alerts.where((a) => a['id'] == seg(1)).firstOrNull ??
            _fail('Alerta não encontrado.', 404);
        _assertResponsible(alert['patientId'] as String);
        alert
          ..['status'] = 'acknowledged'
          ..['acknowledgedById'] = _me['id']
          ..['acknowledgedAt'] = _now();
        _record(
          'emergency.acknowledged',
          alert['patientId'],
          'emergency_alert',
          alert['id'],
          {'triggeredById': alert['triggeredById']},
        );
        return _alertView(alert);
      case 'GET notifications':
        return _notifications();
      case 'POST notifications/:id/read':
        _reads.add('${_me['id']}:${seg(1)}');
        return {'read': true};
      case 'POST notifications/read-all':
        for (final n in _notifications()) {
          _reads.add('${_me['id']}:${n['id']}');
        }
        return {'read': true};
    }
    _fail('Recurso não disponível no modo demonstração.', 404);
  }

  // ─── Autenticação ─────────────────────────────────────────────────────────
  _J? _findUser(String login) {
    final digits = login.replaceAll(RegExp(r'\D'), '');
    return _users
        .where(
          (u) =>
              (u['email'] as String).toLowerCase() == login.toLowerCase() ||
              (digits.length == 11 && u['cpf'] == digits),
        )
        .firstOrNull;
  }

  _J _pendingUser(dynamic token) {
    final id = token?.toString().replaceFirst('demo-login:', '');
    return _users.where((u) => u['id'] == id).firstOrNull ??
        _fail('Sessão de login expirada. Entre novamente.', 401);
  }

  _J _codeStep(_J user) => {
    'status': 'code',
    'loginToken': 'demo-login:${user['id']}',
    'emailHint': _maskEmail(user['email'] as String),
  };

  String _maskEmail(String email) {
    final at = email.indexOf('@');
    return at < 2
        ? email
        : '${email.substring(0, 2)}${'*' * (at - 2)}${email.substring(at)}';
  }

  _J _login(_J b) {
    final user = _findUser(b['email']?.toString().trim() ?? '');
    if (user == null || b['password'] != (user['password'] ?? _password)) {
      _fail('CPF/e-mail ou senha inválidos.', 401);
    }
    final trusted = _devices.any(
      (d) => d['userId'] == user['id'] && d['deviceId'] == b['deviceId'],
    );
    if (trusted) {
      return {
        'status': 'device',
        'loginToken': 'demo-login:${user['id']}',
        'challenge': 'vida-assistida-login:demo:${_random.nextInt(1000000)}',
      };
    }
    return _codeStep(user);
  }

  _J _session(_J user) {
    _current = user;
    return {
      'status': 'authenticated',
      'accessToken': 'demo-token:${user['id']}',
      'expiresIn': '1h',
      'user': _publicUser(user),
    };
  }

  _J _verifyCode(_J b) {
    final user = _pendingUser(b['loginToken']);
    if (b['code'] != code) _fail('Código incorreto. Use o código $code.', 401);
    _devices.removeWhere(
      (d) => d['userId'] == user['id'] && d['deviceId'] == b['deviceId'],
    );
    _devices.add({
      'id': _id(),
      'userId': user['id'],
      'deviceId': b['deviceId'],
      'name': b['deviceName'] ?? 'Navegador',
      'createdAt': _now(),
      'lastUsedAt': _now(),
    });
    return _session(user);
  }

  _J _verifyDevice(_J b) => _session(_pendingUser(b['loginToken']));

  _J _register(_J b) {
    if (_findUser(b['email'] as String) != null) {
      _fail('E-mail já cadastrado.', 409);
    }
    final user = {
      'id': _id(),
      'name': b['name'],
      'email': b['email'],
      'role': b['role'],
      'cpf': b['cpf'],
      'phone': b['phone'],
      'profession': b['profession'],
      'professionalCouncil': b['professionalCouncil'],
      'password': b['password'],
    };
    _users.add(user);
    final device = b['device'];
    if (device is Map) {
      _devices.add({
        'id': _id(),
        'userId': user['id'],
        'deviceId': device['deviceId'],
        'name': device['deviceName'] ?? 'Navegador',
        'createdAt': _now(),
        'lastUsedAt': _now(),
      });
    }
    return _session(user);
  }

  // ─── Pacientes ────────────────────────────────────────────────────────────
  List<_J> _listPatients() {
    if (_me['role'] == 'responsible') {
      return _patients
          .where((p) => p['responsibleId'] == _me['id'])
          .map((p) => _patientView(p, null))
          .toList();
    }
    return [
      for (final m in _members.where(
        (m) => m['userId'] == _me['id'] && m['active'] == true,
      ))
        _patientView(_patients.firstWhere((p) => p['id'] == m['patientId']), m),
    ];
  }

  _J _createPatient(_J b) {
    final patient = {
      'id': _id(),
      ...b,
      'responsibleId': _me['id'],
      'status': 'active',
      'joinCode': _newInviteCode(),
      'inviteExpiresAt': DateTime.now()
          .add(const Duration(days: 7))
          .toUtc()
          .toIso8601String(),
      'createdAt': _now(),
    };
    _patients.add(patient);
    _record('patient.created', patient['id'], 'patient', patient['id'], {
      'name': patient['name'],
    });
    return _patientView(patient, null);
  }

  _J _updatePatient(String id, _J b) {
    final access = _access(id);
    if (access.member != null && access.member!['canEditPatient'] != true) {
      _fail(_permissionMessages['canEditPatient']!, 403);
    }
    final changed = <String>[];
    for (final e in b.entries) {
      if (access.patient[e.key] != e.value) {
        access.patient[e.key] = e.value;
        changed.add(e.key);
      }
    }
    if (changed.isNotEmpty) {
      _record('patient.updated', id, 'patient', id, {'fields': changed});
    }
    return _patientView(access.patient, access.member);
  }

  _J _findByCode(dynamic code) {
    final patient =
        _patients
            .where(
              (p) =>
                  (p['joinCode'] as String).toUpperCase() ==
                  code.toString().trim().toUpperCase(),
            )
            .firstOrNull ??
        _fail('Código de convite inválido.', 404);
    if (DateTime.parse(
      patient['inviteExpiresAt'] as String,
    ).isBefore(DateTime.now())) {
      _fail(
        'Este convite expirou. Solicite um novo código ao responsável.',
        410,
      );
    }
    return patient;
  }

  _J _join(dynamic code) {
    final patient = _findByCode(code);
    final existing = _members
        .where(
          (m) => m['patientId'] == patient['id'] && m['userId'] == _me['id'],
        )
        .firstOrNull;
    if (existing != null && existing['active'] != true) {
      _fail(
        'Seu acesso a este paciente está suspenso. Fale com o responsável.',
        403,
      );
    }
    if (existing == null) {
      _members.add({
        'id': _id(),
        'patientId': patient['id'],
        'userId': _me['id'],
        'active': true,
        'createdAt': _now(),
        'lastAccessAt': _now(),
        'canViewMedications': true,
        'canRecordMedications': true,
        'canManageCarePlan': false,
        'canRecordActivities': true,
        'canRecordObservations': true,
        'canViewHistory': true,
        'canEditPatient': false,
      });
      _record(
        'patient.professional_joined',
        patient['id'],
        'patient_member',
        null,
        {'userId': _me['id'], 'name': _me['name']},
      );
    }
    return _patientView(
      patient,
      _membership(patient['id'] as String, _me['id'] as String),
    );
  }

  _J _updateMember(String patientId, String memberId, _J b) {
    _assertResponsible(patientId);
    final member =
        _members
            .where((m) => m['id'] == memberId && m['patientId'] == patientId)
            .firstOrNull ??
        _fail('Profissional não encontrado.', 404);
    final wasActive = member['active'] == true;
    for (final key in [..._permissionKeys, 'active']) {
      if (b[key] != null) member[key] = b[key];
    }
    final action = b['active'] == false && wasActive
        ? 'patient.member_suspended'
        : b['active'] == true && !wasActive
        ? 'patient.member_reactivated'
        : 'patient.member_permissions_updated';
    _record(action, patientId, 'patient_member', memberId, {
      'userId': member['userId'],
      'name': _person(member['userId'])?['name'],
    });
    return _memberView(member);
  }

  _J _removeMember(String patientId, String memberId) {
    _assertResponsible(patientId);
    final member =
        _members
            .where((m) => m['id'] == memberId && m['patientId'] == patientId)
            .firstOrNull ??
        _fail('Profissional não encontrado.', 404);
    _members.remove(member);
    _record('patient.member_removed', patientId, 'patient_member', null, {
      'userId': member['userId'],
      'name': _person(member['userId'])?['name'],
    });
    return {'removed': true};
  }

  // ─── Registros do cuidado ─────────────────────────────────────────────────
  _J _recordMedication(String medicationId, _J b) {
    final med =
        _medications.where((m) => m['id'] == medicationId).firstOrNull ??
        _fail('Medicamento não encontrado.', 404);
    _assertPermission(med['patientId'] as String, 'canRecordMedications');
    final record = {
      'id': _id(),
      'medicationId': medicationId,
      'patientId': med['patientId'],
      'recordedById': _me['id'],
      'scheduledAt': b['scheduledAt'],
      'administeredAt': b['administeredAt'],
      'status': b['status'],
      'notes': b['notes'],
      'createdAt': _now(),
    };
    _administrations.insert(0, record);
    _record(
      'medication.administration_recorded',
      med['patientId'],
      'medication_administration',
      record['id'],
      {
        'medicationId': medicationId,
        'name': '${med['name']} ${med['dosage']}',
        'status': b['status'],
        'scheduledAt': b['scheduledAt'],
        'notes': b['notes'],
      },
    );
    return {...record, 'recordedBy': _person(_me['id'])};
  }

  _J _recordActivity(String activityId, _J b) {
    final act =
        _activities.where((a) => a['id'] == activityId).firstOrNull ??
        _fail('Atividade não encontrada.', 404);
    _assertPermission(act['patientId'] as String, 'canRecordActivities');
    final record = {
      'id': _id(),
      'activityId': activityId,
      'patientId': act['patientId'],
      'performedById': _me['id'],
      ...b,
    };
    _activityRecords.insert(0, record);
    _record(
      'care_activity.recorded',
      act['patientId'],
      'activity_record',
      record['id'],
      {
        'activityId': activityId,
        'title': act['title'],
        'status': b['status'],
        'performedAt': b['performedAt'],
      },
    );
    return {...record, 'performedBy': _person(_me['id'])};
  }

  _J _alertView(_J alert) => {
    ...alert,
    'triggeredBy': _person(alert['triggeredById']),
    'acknowledgedBy': _person(alert['acknowledgedById']),
  };

  // ─── Notificações (mesmas regras da API) ──────────────────────────────────
  static const _forResponsible = {
    'emergency.triggered',
    'observation.created',
    'patient.professional_joined',
    'medication.administration_recorded',
    'care_activity.recorded',
    'care_activity.created',
    'patient.updated',
  };
  static const _forProfessional = {
    'emergency.acknowledged',
    'observation.created',
    'medication.created',
    'care_activity.created',
    'patient.updated',
    'patient.member_permissions_updated',
    'patient.member_reactivated',
  };

  List<_J> _notifications() {
    final mine = {for (final p in _listPatients()) p['id']: p['name']};
    final allowed = _me['role'] == 'responsible'
        ? _forResponsible
        : _forProfessional;
    final result = <_J>[];
    for (final e in _audit) {
      if (!mine.containsKey(e['patientId']) ||
          e['actorId'] == _me['id'] ||
          !allowed.contains(e['action'])) {
        continue;
      }
      final built = _describe(
        e,
        _person(e['actorId'])?['name'] ?? 'Um integrante da equipe',
        mine[e['patientId']] as String,
      );
      if (built == null) continue;
      result.add({
        'id': e['id'],
        ...built,
        'patientId': e['patientId'],
        'patientName': mine[e['patientId']],
        'createdAt': e['createdAt'],
        'read': _reads.contains('${_me['id']}:${e['id']}'),
      });
    }
    return result.take(50).toList();
  }

  _J? _describe(_J e, String actor, String patient) {
    final m = (e['metadata'] as _J?) ?? const {};
    String t(dynamic v) => v is String ? v : '';
    switch (e['action']) {
      case 'emergency.triggered':
        return {
          'type': 'acionamento',
          'title': 'Acionamento do responsável',
          'body':
              '$actor acionou você${t(m['reason']).isNotEmpty ? ' · ${m['reason']}' : ''} — $patient',
        };
      case 'emergency.acknowledged':
        if (m['triggeredById'] != null && m['triggeredById'] != _me['id']) {
          return null;
        }
        return {
          'type': 'acionamento_visto',
          'title': 'Acionamento visualizado',
          'body': '$actor visualizou o seu acionamento — $patient',
        };
      case 'observation.created':
        final level = t(m['level']);
        return {
          'type': level == 'urgent' ? 'obs_urgente' : 'obs_nova',
          'title': level == 'urgent'
              ? 'Intercorrência urgente'
              : level == 'attention'
              ? 'Observação que pede atenção'
              : 'Nova observação',
          'body':
              '$actor registrou ${t(m['category']).isEmpty ? 'uma observação' : t(m['category']).toLowerCase()} — $patient',
        };
      case 'patient.professional_joined':
        return {
          'type': 'profissional_vinculado',
          'title': 'Novo profissional vinculado',
          'body':
              '${t(m['name']).isEmpty ? actor : m['name']} entrou na equipe de $patient',
        };
      case 'medication.administration_recorded':
        if (m['status'] != 'not_administered') return null;
        return {
          'type': 'med_nao_administrado',
          'title': 'Medicamento não administrado',
          'body':
              '${t(m['name']).isEmpty ? 'Medicamento' : m['name']} — $patient',
        };
      case 'care_activity.recorded':
        if (m['status'] == 'completed') return null;
        return {
          'type': 'atividade_atrasada',
          'title': m['status'] == 'partial'
              ? 'Atividade realizada parcialmente'
              : 'Atividade não realizada',
          'body':
              '${t(m['title']).isEmpty ? 'Atividade' : m['title']} — $patient · $actor',
        };
      case 'care_activity.created':
      case 'medication.created':
        return {
          'type': 'plano_atualizado',
          'title': 'Plano de cuidados atualizado',
          'body':
              '$actor incluiu ${t(m['title']).isNotEmpty
                  ? m['title']
                  : t(m['name']).isNotEmpty
                  ? m['name']
                  : 'um item'} — $patient',
        };
      case 'patient.updated':
        return {
          'type': 'dados_atualizados',
          'title': 'Dados do paciente atualizados',
          'body': '$actor alterou o cadastro de $patient',
        };
      case 'patient.member_permissions_updated':
      case 'patient.member_reactivated':
        if (m['userId'] != _me['id']) return null;
        return {
          'type': 'permissao',
          'title': e['action'] == 'patient.member_reactivated'
              ? 'Acesso reativado'
              : 'Alteração de permissão',
          'body': '$actor atualizou o seu acesso — $patient',
        };
    }
    return null;
  }

  // ─── Dados fictícios (os mesmos do seed da API) ───────────────────────────
  void _seed() {
    const ana = '11111111-1111-4111-8111-111111111111';
    const carlos = '22222222-2222-4222-8222-222222222222';
    const maria = '33333333-3333-4333-8333-333333333333';
    const jose = '33333333-3333-4333-8333-333333333334';
    final created = _ago(const Duration(days: 30));
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final startDate = DateTime.now()
        .subtract(const Duration(days: 30))
        .toIso8601String()
        .substring(0, 10);
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    String at(DateTime day, int h, int m) =>
        DateTime(day.year, day.month, day.day, h, m).toUtc().toIso8601String();

    _users.addAll([
      {
        'id': ana,
        'name': 'Ana Souza',
        'email': 'responsavel@vidaassistida.app',
        'cpf': '12345678900',
        'phone': '(79) 99234-5678',
        'role': 'responsible',
      },
      {
        'id': carlos,
        'name': 'Carlos Lima',
        'email': 'profissional@vidaassistida.app',
        'cpf': '98765432100',
        'phone': '(79) 98765-4321',
        'profession': 'Enfermeiro',
        'professionalCouncil': 'COREN-SE 45.678',
        'role': 'professional',
      },
    ]);
    _patients.addAll([
      {
        'id': maria,
        'responsibleId': ana,
        'status': 'active',
        'joinCode': 'VIDA2026',
        'inviteExpiresAt': '2099-12-31T23:59:59.000Z',
        'name': 'Maria Oliveira',
        'birthDate': '1946-03-15',
        'conditions': 'Hipertensão arterial e diabetes tipo 2.',
        'allergies': 'Penicilina.',
        'restrictions': 'Evitar esforço físico intenso. Dieta hipossódica.',
        'contactMain': 'Ana Souza — (79) 99234-5678',
        'contactAlt': 'João Oliveira (filho) — (79) 98111-2233',
        'notes': 'Dados fictícios para demonstração acadêmica.',
        'createdAt': created,
      },
      {
        'id': jose,
        'responsibleId': ana,
        'status': 'active',
        'joinCode': 'VID-JS26',
        'inviteExpiresAt': '2099-12-31T23:59:59.000Z',
        'name': 'José Santos',
        'birthDate': '1961-07-22',
        'conditions': 'Sequela de AVC isquêmico e dislipidemia.',
        'allergies': 'Dipirona.',
        'restrictions': 'Fisioterapia três vezes por semana.',
        'contactMain': 'Ana Souza — (79) 99234-5678',
        'notes': 'Dados fictícios para demonstração acadêmica.',
        'createdAt': created,
      },
    ]);
    _members.add({
      'id': 'demo-member-carlos',
      'patientId': maria,
      'userId': carlos,
      'active': true,
      'createdAt': created,
      'lastAccessAt': _ago(const Duration(hours: 20)),
      'canViewMedications': true,
      'canRecordMedications': true,
      'canManageCarePlan': true,
      'canRecordActivities': true,
      'canRecordObservations': true,
      'canViewHistory': true,
      'canEditPatient': false,
    });
    _J med(
      String id,
      String patient,
      String name,
      String dosage,
      List<String> schedule,
      String frequency, [
      String? instructions,
    ]) => {
      'id': id,
      'patientId': patient,
      'name': name,
      'dosage': dosage,
      'route': 'Oral',
      'schedule': schedule,
      'frequency': frequency,
      'startDate': startDate,
      'instructions': instructions,
      'active': true,
      'createdAt': created,
    };
    _medications.addAll([
      med(
        'demo-med-losartana',
        maria,
        'Losartana',
        '50 mg',
        ['08:00', '20:00'],
        '2x ao dia',
        'Administrar conforme orientação profissional.',
      ),
      med(
        'demo-med-metformina',
        maria,
        'Metformina',
        '500 mg',
        ['08:00', '14:00', '20:00'],
        '3x ao dia',
        'Tomar após as refeições.',
      ),
      med('demo-med-folico', maria, 'Ácido Fólico', '5 mg', [
        '12:00',
      ], '1x ao dia'),
      med('demo-med-atorva', jose, 'Atorvastatina', '40 mg', [
        '15:30',
      ], '1x ao dia'),
    ]);
    _activities.addAll([
      {
        'id': 'demo-act-caminhada',
        'patientId': maria,
        'createdById': carlos,
        'title': 'Caminhada assistida',
        'type': 'Fisioterapia',
        'objective': 'Estimular equilíbrio e autonomia funcional.',
        'instructions': 'Realizar percurso curto com supervisão contínua.',
        'schedule': 'Todos os dias',
        'time': '10:30',
        'duration': '10 minutos',
        'needsAssistance': true,
        'active': true,
        'createdAt': created,
      },
      {
        'id': 'demo-act-perna',
        'patientId': maria,
        'createdById': carlos,
        'title': 'Elevação assistida da perna',
        'type': 'Fisioterapia',
        'objective':
            'Fortalecer a musculatura e manter a amplitude de movimento.',
        'instructions':
            'Elevar a perna estendida com apoio. Interromper em caso de dor.',
        'schedule': 'Seg, qua e sex',
        'time': '15:00',
        'duration': '15 minutos',
        'series': '3 × 10',
        'needsAssistance': true,
        'active': true,
        'createdAt': created,
      },
    ]);

    // Histórico do dia anterior, para o histórico não começar vazio.
    void past(
      String actor,
      String action,
      String entityType,
      _J metadata,
      String when,
    ) => _audit.add({
      'id': _id(),
      'actorId': actor,
      'patientId': maria,
      'action': action,
      'entityType': entityType,
      'entityId': null,
      'metadata': metadata,
      'createdAt': when,
    });
    _observations.addAll([
      {
        'id': 'demo-obs-1',
        'patientId': maria,
        'authorId': carlos,
        'category': 'Alteração no estado do paciente',
        'level': 'attention',
        'text':
            'Relatou leve tontura ao se levantar. Orientado repouso e hidratação.',
        'notifyResponsible': true,
        'createdAt': at(yesterday, 16, 20),
      },
      {
        'id': 'demo-obs-2',
        'patientId': maria,
        'authorId': carlos,
        'category': 'Observação geral',
        'level': 'information',
        'text': 'Paciente apresentou-se bem-disposta durante a visita.',
        'createdAt': at(yesterday, 9, 10),
      },
    ]);
    _administrations.addAll([
      {
        'id': 'demo-adm-1',
        'medicationId': 'demo-med-losartana',
        'patientId': maria,
        'recordedById': carlos,
        'scheduledAt': at(yesterday, 20, 0),
        'administeredAt': at(yesterday, 20, 5),
        'status': 'administered',
        'createdAt': at(yesterday, 20, 5),
      },
      {
        'id': 'demo-adm-2',
        'medicationId': 'demo-med-losartana',
        'patientId': maria,
        'recordedById': carlos,
        'scheduledAt': at(yesterday, 8, 0),
        'administeredAt': at(yesterday, 8, 4),
        'status': 'administered',
        'createdAt': at(yesterday, 8, 4),
      },
    ]);
    _activityRecords.add({
      'id': 'demo-rec-1',
      'activityId': 'demo-act-caminhada',
      'patientId': maria,
      'performedById': carlos,
      'status': 'completed',
      'performedAt': at(yesterday, 10, 40),
    });
    past(
      carlos,
      'medication.administration_recorded',
      'medication_administration',
      {
        'medicationId': 'demo-med-losartana',
        'name': 'Losartana 50 mg',
        'status': 'administered',
        'scheduledAt': at(yesterday, 20, 0),
      },
      at(yesterday, 20, 5),
    );
    past(carlos, 'observation.created', 'observation', {
      'category': 'Alteração no estado do paciente',
      'level': 'attention',
      'notifyResponsible': true,
    }, at(yesterday, 16, 20));
    past(carlos, 'care_activity.recorded', 'activity_record', {
      'activityId': 'demo-act-caminhada',
      'title': 'Caminhada assistida',
      'status': 'completed',
      'performedAt': at(yesterday, 10, 40),
    }, at(yesterday, 10, 40));
    past(carlos, 'observation.created', 'observation', {
      'category': 'Observação geral',
      'level': 'information',
      'notifyResponsible': false,
    }, at(yesterday, 9, 10));
    past(
      carlos,
      'medication.administration_recorded',
      'medication_administration',
      {
        'medicationId': 'demo-med-losartana',
        'name': 'Losartana 50 mg',
        'status': 'administered',
        'scheduledAt': at(yesterday, 8, 0),
      },
      at(yesterday, 8, 4),
    );
    _audit.sort(
      (a, b) => (b['createdAt'] as String).compareTo(a['createdAt'] as String),
    );
    // Evita aviso de variável não usada quando a data de hoje não é necessária.
    assert(today.isNotEmpty);
  }
}
