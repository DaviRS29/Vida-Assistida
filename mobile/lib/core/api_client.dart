import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models.dart';
import 'demo_backend.dart';

class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  bool get isForbidden => statusCode == 403;
  bool get isOffline => statusCode == null;
  bool get isExpired => statusCode == 410;
  bool get isNotFound => statusCode == 404;

  @override
  String toString() => message;
}

class ApiClient {
  static const _configuredUrl = String.fromEnvironment('API_URL');
  static const _timeout = Duration(seconds: 15);
  String? _token;

  String get baseUrl {
    if (_configuredUrl.isNotEmpty) return _configuredUrl;
    return kIsWeb
        ? 'http://localhost:3000/api/v1'
        : 'http://10.0.2.2:3000/api/v1';
  }

  void clearSession() => _token = null;

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (_token != null) 'Authorization': 'Bearer $_token',
  };

  Future<dynamic> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    if (DemoBackend.enabled) {
      return DemoBackend.instance.handle(method, path, body);
    }
    final uri = Uri.parse('$baseUrl$path');
    final encodedBody = body == null ? null : jsonEncode(body);
    late http.Response response;
    try {
      final future = switch (method) {
        'GET' => http.get(uri, headers: _headers),
        'POST' => http.post(uri, headers: _headers, body: encodedBody),
        'PATCH' => http.patch(uri, headers: _headers, body: encodedBody),
        'DELETE' => http.delete(uri, headers: _headers),
        _ => throw ArgumentError('Método HTTP não suportado.'),
      };
      response = await future.timeout(_timeout);
    } on TimeoutException {
      throw const ApiException(
        'Sem conexão com o servidor. Verifique sua internet e tente novamente.',
      );
    } on http.ClientException {
      throw const ApiException(
        'Sem conexão com o servidor. Verifique sua internet e tente novamente.',
      );
    }
    final data = response.body.isEmpty ? null : jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      var message = 'Não foi possível concluir a operação.';
      if (data is Map<String, dynamic>) {
        final raw = data['message'];
        message = raw is List ? raw.join('\n') : (raw?.toString() ?? message);
      }
      if (response.statusCode == 429) {
        message = 'Muitas tentativas. Aguarde um instante e tente novamente.';
      }
      throw ApiException(message, statusCode: response.statusCode);
    }
    return data;
  }

  List<T> _list<T>(dynamic data, T Function(Json) parse) => [
    for (final item in (data as List<dynamic>? ?? [])) parse(item as Json),
  ];

  // ─── Autenticação ──────────────────────────────────────────────────────────
  /// Etapa 1 do login: senha. A resposta indica qual segundo fator usar.
  Future<LoginStep> login(
    String login,
    String password, {
    String? deviceId,
  }) async {
    final data =
        await _request(
              'POST',
              '/auth/login',
              body: {
                'email': login.trim(),
                'password': password,
                'deviceId': ?deviceId,
              },
            )
            as Json;
    return _step(data);
  }

  LoginStep _step(Json data) => switch (data['status']) {
    'device' => DeviceChallenge(
      loginToken: data['loginToken'] as String,
      challenge: data['challenge'] as String,
    ),
    'code' => CodeChallenge(
      loginToken: data['loginToken'] as String,
      emailHint: data['emailHint']?.toString() ?? 'seu e-mail',
    ),
    _ => Authenticated(_session(data)),
  };

  UserProfile _session(Json data) {
    _token = data['accessToken'] as String;
    return UserProfile.fromJson(data['user'] as Json);
  }

  /// Etapa 2: aparelho reconhecido assina o desafio.
  Future<UserProfile> verifyDevice(String loginToken, String signature) async =>
      _session(
        await _request(
              'POST',
              '/auth/login/verify-device',
              body: {'loginToken': loginToken, 'signature': signature},
            )
            as Json,
      );

  /// Etapa 2: aparelho novo informa o código e passa a ser confiável.
  Future<UserProfile> verifyCode(
    String loginToken,
    String code,
    Map<String, String> device,
  ) async => _session(
    await _request(
          'POST',
          '/auth/login/verify-code',
          body: {'loginToken': loginToken, 'code': code, ...device},
        )
        as Json,
  );

  Future<CodeChallenge> sendCode(String loginToken) async =>
      _step(
            await _request(
                  'POST',
                  '/auth/login/send-code',
                  body: {'loginToken': loginToken},
                )
                as Json,
          )
          as CodeChallenge;

  Future<List<TrustedDevice>> devices() async =>
      _list(await _request('GET', '/auth/devices'), TrustedDevice.fromJson);

  Future<void> revokeDevice(String id) =>
      _request('DELETE', '/auth/devices/$id');

  Future<UserProfile> register({
    required String name,
    required String email,
    required String password,
    required String role,
    String? cpf,
    String? phone,
    String? profession,
    String? professionalCouncil,
    Map<String, String>? device,
  }) async {
    final data =
        await _request(
              'POST',
              '/auth/register',
              body: {
                'name': name.trim(),
                'email': email.trim(),
                'password': password,
                'role': role,
                if (cpf?.trim().isNotEmpty == true) 'cpf': cpf!.trim(),
                if (phone?.trim().isNotEmpty == true) 'phone': phone!.trim(),
                if (profession?.trim().isNotEmpty == true)
                  'profession': profession!.trim(),
                if (professionalCouncil?.trim().isNotEmpty == true)
                  'professionalCouncil': professionalCouncil!.trim(),
                'device': ?device,
              },
            )
            as Json;
    return _session(data);
  }

  Future<void> forgotPassword(String email) =>
      _request('POST', '/auth/forgot-password', body: {'email': email.trim()});

  Future<UserProfile> updateProfile(Map<String, String> fields) async =>
      UserProfile.fromJson(
        await _request('PATCH', '/auth/me', body: fields) as Json,
      );

  Future<void> changePassword(String current, String next) => _request(
    'POST',
    '/auth/change-password',
    body: {'currentPassword': current, 'newPassword': next},
  );

  // ─── Pacientes e convites ──────────────────────────────────────────────────
  Future<List<Patient>> patients() async =>
      _list(await _request('GET', '/patients'), Patient.fromJson);

  Future<Patient> patient(String id) async =>
      Patient.fromJson(await _request('GET', '/patients/$id') as Json);

  Future<Patient> createPatient(Map<String, String> fields) async =>
      Patient.fromJson(
        await _request('POST', '/patients', body: fields) as Json,
      );

  Future<Patient> updatePatient(String id, Map<String, String> fields) async =>
      Patient.fromJson(
        await _request('PATCH', '/patients/$id', body: fields) as Json,
      );

  Future<void> validateInvite(String code) =>
      _request('POST', '/patients/invite/validate', body: {'code': code});

  Future<Patient> joinPatient(String code) async => Patient.fromJson(
    await _request('POST', '/patients/join', body: {'code': code}) as Json,
  );

  Future<Patient> rotateInviteCode(String patientId) async => Patient.fromJson(
    await _request('POST', '/patients/$patientId/invite-code') as Json,
  );

  Future<List<TeamMember>> members(String patientId) async => _list(
    await _request('GET', '/patients/$patientId/members'),
    TeamMember.fromJson,
  );

  Future<TeamMember> updateMember(
    String patientId,
    String memberId,
    Map<String, bool> fields,
  ) async => TeamMember.fromJson(
    await _request(
          'PATCH',
          '/patients/$patientId/members/$memberId',
          body: fields,
        )
        as Json,
  );

  Future<void> removeMember(String patientId, String memberId) =>
      _request('DELETE', '/patients/$patientId/members/$memberId');

  // ─── Medicamentos ──────────────────────────────────────────────────────────
  Future<({List<Medication> medications, List<Administration> records})>
  medications(String patientId) async {
    final data =
        await _request('GET', '/patients/$patientId/medications') as Json;
    return (
      medications: _list(data['medications'], Medication.fromJson),
      records: _list(data['administrations'], Administration.fromJson),
    );
  }

  Future<void> createMedication(
    String patientId, {
    required String name,
    required String dosage,
    required String route,
    required List<String> schedule,
    String? frequency,
    String? startDate,
    String? endDate,
    String? instructions,
  }) => _request(
    'POST',
    '/patients/$patientId/medications',
    body: {
      'name': name.trim(),
      'dosage': dosage.trim(),
      'route': route.trim(),
      'schedule': schedule,
      if (frequency?.isNotEmpty == true) 'frequency': frequency,
      if (startDate?.isNotEmpty == true) 'startDate': startDate,
      if (endDate?.isNotEmpty == true) 'endDate': endDate,
      if (instructions?.trim().isNotEmpty == true)
        'instructions': instructions!.trim(),
    },
  );

  Future<void> recordMedication(
    String medicationId, {
    required DateTime scheduledAt,
    String status = 'administered',
    String? notes,
  }) => _request(
    'POST',
    '/medications/$medicationId/administrations',
    body: {
      'scheduledAt': scheduledAt.toUtc().toIso8601String(),
      if (status == 'administered')
        'administeredAt': DateTime.now().toUtc().toIso8601String(),
      'status': status,
      if (notes?.trim().isNotEmpty == true) 'notes': notes!.trim(),
    },
  );

  // ─── Observações ───────────────────────────────────────────────────────────
  Future<List<Observation>> observations(String patientId) async => _list(
    await _request('GET', '/patients/$patientId/observations'),
    Observation.fromJson,
  );

  Future<void> addObservation(
    String patientId, {
    required String category,
    required String level,
    required String text,
    bool notifyResponsible = false,
  }) => _request(
    'POST',
    '/patients/$patientId/observations',
    body: {
      'category': category,
      'level': level,
      'text': text.trim(),
      'notifyResponsible': notifyResponsible,
    },
  );

  // ─── Plano de cuidados ─────────────────────────────────────────────────────
  Future<({List<CareActivity> activities, List<ActivityRecord> records})>
  careActivities(String patientId) async {
    final data =
        await _request('GET', '/patients/$patientId/care-activities') as Json;
    return (
      activities: _list(data['activities'], CareActivity.fromJson),
      records: _list(data['records'], ActivityRecord.fromJson),
    );
  }

  Future<void> createCareActivity(
    String patientId, {
    required String title,
    required String type,
    required String objective,
    required String instructions,
    required String schedule,
    String? time,
    String? duration,
    String? series,
    bool needsAssistance = false,
  }) => _request(
    'POST',
    '/patients/$patientId/care-activities',
    body: {
      'title': title.trim(),
      'type': type.trim(),
      'objective': objective.trim(),
      'instructions': instructions.trim(),
      'schedule': schedule.trim(),
      if (time?.isNotEmpty == true) 'time': time,
      if (duration?.trim().isNotEmpty == true) 'duration': duration!.trim(),
      if (series?.trim().isNotEmpty == true) 'series': series!.trim(),
      'needsAssistance': needsAssistance,
    },
  );

  Future<void> recordActivity(
    String activityId, {
    required String status,
    int? painBefore,
    int? painAfter,
    String? notes,
  }) => _request(
    'POST',
    '/care-activities/$activityId/records',
    body: {
      'status': status,
      'performedAt': DateTime.now().toUtc().toIso8601String(),
      'painBefore': ?painBefore,
      'painAfter': ?painAfter,
      if (notes?.trim().isNotEmpty == true) 'notes': notes!.trim(),
    },
  );

  // ─── Histórico, acionamentos e notificações ───────────────────────────────
  Future<List<AuditEvent>> audit(String patientId) async => _list(
    await _request('GET', '/patients/$patientId/audit'),
    AuditEvent.fromJson,
  );

  Future<List<EmergencyAlert>> emergencyAlerts(String patientId) async => _list(
    await _request('GET', '/patients/$patientId/emergency-alerts'),
    EmergencyAlert.fromJson,
  );

  Future<void> acknowledgeEmergency(String alertId) =>
      _request('PATCH', '/emergency-alerts/$alertId/acknowledge');

  Future<EmergencyAlert> triggerEmergency(
    String patientId, {
    required String reason,
    required String priority,
    String? message,
  }) async => EmergencyAlert.fromJson(
    await _request(
          'POST',
          '/patients/$patientId/emergency-alerts',
          body: {
            'reason': reason,
            'priority': priority,
            if (message?.trim().isNotEmpty == true) 'message': message!.trim(),
          },
        )
        as Json,
  );

  Future<List<AppNotification>> notifications() async =>
      _list(await _request('GET', '/notifications'), AppNotification.fromJson);

  Future<void> markNotificationRead(String id) =>
      _request('POST', '/notifications/$id/read');

  Future<void> markAllNotificationsRead() =>
      _request('POST', '/notifications/read-all');
}

// ─── Login em duas etapas ────────────────────────────────────────────────────
sealed class LoginStep {
  const LoginStep();
}

class Authenticated extends LoginStep {
  const Authenticated(this.user);
  final UserProfile user;
}

/// Aparelho reconhecido: basta assinar o desafio com a chave local.
class DeviceChallenge extends LoginStep {
  const DeviceChallenge({required this.loginToken, required this.challenge});
  final String loginToken;
  final String challenge;
}

/// Aparelho desconhecido: código de 6 dígitos enviado por e-mail.
class CodeChallenge extends LoginStep {
  const CodeChallenge({required this.loginToken, required this.emailHint});
  final String loginToken;
  final String emailHint;
}
