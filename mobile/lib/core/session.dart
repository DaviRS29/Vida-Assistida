import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models.dart';
import 'api_client.dart';
import 'care_data.dart';
import 'reminders.dart';

/// Preferências locais do aparelho (lembrar login, acessibilidade, alertas).
class AppSettings extends ChangeNotifier {
  SharedPreferences? _prefs;

  String rememberedLogin = '';
  double textScale = 1;
  bool highContrast = false;
  bool notifyMedications = true;
  bool notifyObservations = true;
  bool notifyAlerts = true;

  Future<void> load() async {
    try {
      _prefs = await SharedPreferences.getInstance();
    } catch (_) {
      return;
    }
    final p = _prefs!;
    rememberedLogin = p.getString('rememberedLogin') ?? '';
    textScale = p.getDouble('textScale') ?? 1;
    highContrast = p.getBool('highContrast') ?? false;
    notifyMedications = p.getBool('notifyMedications') ?? true;
    notifyObservations = p.getBool('notifyObservations') ?? true;
    notifyAlerts = p.getBool('notifyAlerts') ?? true;
    notifyListeners();
  }

  Future<void> setRememberedLogin(String value) async {
    rememberedLogin = value;
    await _prefs?.setString('rememberedLogin', value);
    notifyListeners();
  }

  Future<void> setTextScale(double value) async {
    textScale = value;
    await _prefs?.setDouble('textScale', value);
    notifyListeners();
  }

  Future<void> setHighContrast(bool value) async {
    highContrast = value;
    await _prefs?.setBool('highContrast', value);
    notifyListeners();
  }

  Future<void> setNotify(String key, bool value) async {
    switch (key) {
      case 'notifyMedications':
        notifyMedications = value;
      case 'notifyObservations':
        notifyObservations = value;
      case 'notifyAlerts':
        notifyAlerts = value;
    }
    await _prefs?.setBool(key, value);
    notifyListeners();
  }
}

/// Central de notificações: eventos da API + alertas calculados no app.
class NotificationCenter extends ChangeNotifier {
  NotificationCenter(this.api, this.settings);

  final ApiClient api;
  final AppSettings settings;
  List<AppNotification> _server = [];
  List<AppNotification> _local = [];
  final Set<String> _localRead = {};

  List<AppNotification> get items {
    final all = [
      ..._local.map(
        (item) => item.copyWith(read: _localRead.contains(item.id)),
      ),
      ..._server,
    ].where(_enabled).toList();
    all.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return all;
  }

  bool _enabled(AppNotification item) {
    if (item.type.startsWith('med')) return settings.notifyMedications;
    if (item.type.startsWith('obs')) return settings.notifyObservations;
    if (item.type.startsWith('acionamento')) return settings.notifyAlerts;
    return true;
  }

  int get unread => items.where((item) => !item.read).length;

  Future<void> refresh({List<PatientBundle>? bundles}) async {
    try {
      _server = await api.notifications();
    } catch (_) {
      // Mantém a última lista conhecida quando estiver sem conexão.
    }
    if (bundles != null) {
      _local = _computeLocal(bundles);
      MedicationReminders.instance
          .sync(bundles, enabled: settings.notifyMedications)
          .catchError((Object error) => debugPrint('Lembretes: $error'));
    }
    notifyListeners();
  }

  List<AppNotification> _computeLocal(List<PatientBundle> bundles) {
    final now = DateTime.now();
    final result = <AppNotification>[];
    for (final bundle in bundles) {
      for (final slot in bundle.todayDoses) {
        final id = 'local-${slot.medication.id}-${slot.time}-${isoDate(now)}';
        if (slot.status == DoseStatus.atrasado) {
          result.add(
            AppNotification(
              id: id,
              type: 'med_atrasado',
              title: 'Medicamento atrasado',
              body:
                  '${slot.medication.label} — ${bundle.patient.firstName} · ${slot.time}',
              createdAt: slot.scheduledAt,
              read: false,
              patientId: bundle.patient.id,
              local: true,
            ),
          );
        } else if (slot.status == DoseStatus.pendente &&
            slot.scheduledAt.difference(now).inMinutes.abs() <= 60) {
          result.add(
            AppNotification(
              id: id,
              type: 'med_proximo',
              title: 'Medicamento próximo do horário',
              body:
                  '${slot.medication.label} — ${bundle.patient.firstName} · ${slot.time}',
              createdAt: slot.scheduledAt.subtract(const Duration(hours: 1)),
              read: false,
              patientId: bundle.patient.id,
              local: true,
            ),
          );
        }
      }
    }
    return result;
  }

  Future<void> markRead(AppNotification item) async {
    if (item.read) return;
    if (item.local) {
      _localRead.add(item.id);
    } else {
      _server = [
        for (final n in _server) n.id == item.id ? n.copyWith(read: true) : n,
      ];
      notifyListeners();
      try {
        await api.markNotificationRead(item.id);
      } catch (_) {}
    }
    notifyListeners();
  }

  Future<void> markAll() async {
    _localRead.addAll(_local.map((item) => item.id));
    _server = [for (final n in _server) n.copyWith(read: true)];
    notifyListeners();
    try {
      await api.markAllNotificationsRead();
    } catch (_) {}
  }
}

/// Pacientes visíveis ao usuário com medicamentos, rotina, observações e
/// alertas. Todas as telas leem daqui e pedem recarga após cada registro.
class CareStore extends ChangeNotifier {
  CareStore(this.api, this.notifications);

  final ApiClient api;
  final NotificationCenter notifications;
  List<PatientBundle> bundles = [];
  bool loading = false;
  bool loaded = false;
  Object? error;

  Future<void> load() async {
    loading = true;
    notifyListeners();
    try {
      bundles = await loadAllBundles(api);
      error = null;
      loaded = true;
    } catch (e) {
      error = e;
    } finally {
      loading = false;
      notifyListeners();
    }
    await notifications.refresh(bundles: bundles);
  }

  PatientBundle? bundleFor(String patientId) {
    for (final bundle in bundles) {
      if (bundle.patient.id == patientId) return bundle;
    }
    return null;
  }

  Future<PatientBundle> refreshPatient(String patientId) async {
    final patient = await api.patient(patientId);
    final bundle = await loadBundle(api, patient);
    final index = bundles.indexWhere((item) => item.patient.id == patientId);
    if (index >= 0) {
      bundles = [...bundles]..[index] = bundle;
    } else {
      bundles = [bundle, ...bundles];
    }
    notifyListeners();
    notifications.refresh(bundles: bundles);
    return bundle;
  }

  List<DoseSlot> dosesOn(DateTime day) =>
      [for (final bundle in bundles) ...dosesFor(bundle, day)]
        ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));

  List<ActivitySlot> activitiesOn(DateTime day) => [
    for (final bundle in bundles) ...activitiesFor(bundle, day),
  ];
}

/// Dados de sessão disponíveis para todas as telas autenticadas.
class Session extends InheritedWidget {
  const Session({
    super.key,
    required this.api,
    required this.user,
    required this.settings,
    required this.notifications,
    required this.store,
    required this.onLogout,
    required this.onUserUpdated,
    required super.child,
  });

  final ApiClient api;
  final UserProfile user;
  final AppSettings settings;
  final NotificationCenter notifications;
  final CareStore store;
  final VoidCallback onLogout;
  final ValueChanged<UserProfile> onUserUpdated;

  bool get professional => user.isProfessional;

  static Session of(BuildContext context) {
    final session = context.dependOnInheritedWidgetOfExactType<Session>();
    assert(session != null, 'Session não encontrada no contexto.');
    return session!;
  }

  @override
  bool updateShouldNotify(Session oldWidget) =>
      user != oldWidget.user || api != oldWidget.api;
}
