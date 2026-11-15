import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'care_data.dart';

/// Lembretes locais dos horários de medicamento.
///
/// Os avisos são agendados no próprio aparelho (Android e iOS), funcionam
/// com o aplicativo fechado e não exibem nome de medicamento nem dados
/// clínicos na tela bloqueada, conforme a LGPD.
class MedicationReminders {
  MedicationReminders._();
  static final instance = MedicationReminders._();

  static const _channelId = 'lembretes_medicamentos';
  static const _maxScheduled = 60; // o iOS aceita até 64 pendentes
  static const _horizon = Duration(hours: 48);

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;
  bool _permissionAsked = false;

  /// Lembretes locais só existem em Android e iOS.
  bool get supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  Future<void> init() async {
    if (!supported || _ready) return;
    try {
      tzdata.initializeTimeZones();
      try {
        final zone = await FlutterTimezone.getLocalTimezone();
        tz.setLocalLocation(tz.getLocation(zone.identifier));
      } catch (_) {
        tz.setLocalLocation(tz.getLocation('America/Sao_Paulo'));
      }
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
      );
      _ready = true;
    } catch (error) {
      debugPrint('Lembretes indisponíveis: $error');
    }
  }

  Future<void> _askPermission() async {
    if (_permissionAsked) return;
    _permissionAsked = true;
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
    await _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, sound: true);
  }

  /// Reagenda os próximos horários pendentes de todos os pacientes.
  Future<void> sync(
    List<PatientBundle> bundles, {
    required bool enabled,
  }) async {
    if (!supported) return;
    await init();
    if (!_ready) return;
    await _plugin.cancelAll();
    if (!enabled) return;
    await _askPermission();

    final now = DateTime.now();
    final slots =
        <DoseSlot>[
          for (final bundle in bundles)
            if (!bundle.medicationsDenied) ...[
              ...dosesFor(bundle, now),
              ...dosesFor(bundle, now.add(const Duration(days: 1))),
            ],
        ]..removeWhere(
          (slot) =>
              slot.status != DoseStatus.pendente ||
              !slot.scheduledAt.isAfter(now) ||
              slot.scheduledAt.isAfter(now.add(_horizon)),
        );
    slots.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));

    var id = 0;
    for (final slot in slots.take(_maxScheduled)) {
      await _plugin.zonedSchedule(
        id: id++,
        scheduledDate: tz.TZDateTime.from(slot.scheduledAt, tz.local),
        title: 'Lembrete de medicamento',
        body:
            'Há um medicamento programado para ${slot.time} — ${slot.patient.firstName}. Abra o app para confirmar.',
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            'Lembretes de medicamentos',
            channelDescription: 'Avisos nos horários programados',
            importance: Importance.high,
            priority: Priority.high,
            visibility: NotificationVisibility.private,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: slot.patient.id,
      );
    }
  }

  Future<void> clear() async {
    if (!supported || !_ready) return;
    await _plugin.cancelAll();
  }
}
