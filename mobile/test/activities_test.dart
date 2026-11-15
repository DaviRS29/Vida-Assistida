// Testes de unidade do plano de atividades (RF03) e do histórico (RF06).
import 'package:flutter_test/flutter_test.dart';
import 'package:vida_assistida/core/care_data.dart';
import 'package:vida_assistida/models.dart';

const _patient = Patient(
  id: 'p1',
  name: 'Maria Souza',
  birthDate: '1940-01-01',
  status: 'active',
  joinCode: '',
);

CareActivity _activity({String schedule = 'Todos os dias', String? time}) =>
    CareActivity(
      id: 'a1',
      patientId: 'p1',
      title: 'Caminhada assistida',
      type: 'fisioterapia',
      objective: 'Mobilidade',
      instructions: '10 minutos',
      schedule: schedule,
      createdAt: DateTime(2026, 1, 1),
      time: time,
    );

void main() {
  final yesterday = dayOf(DateTime.now()).subtract(const Duration(days: 1));

  test('A01 rotina "Seg, qua e sex" só aparece nesses dias', () {
    final activity = _activity(schedule: 'Seg, qua e sex');
    expect(activityRunsOn(activity, DateTime(2026, 11, 2)), isTrue); // segunda
    expect(activityRunsOn(activity, DateTime(2026, 11, 3)), isFalse); // terça
    expect(activityRunsOn(activity, DateTime(2026, 11, 6)), isTrue); // sexta
  });

  test('A02 atividade com horário vencido e sem registro fica atrasada', () {
    final bundle = PatientBundle(
      patient: _patient,
      activities: [_activity(time: '10:30')],
    );
    expect(activitiesFor(bundle, yesterday).single.status, ActivityStatus.atrasada);
  });

  test('A03 registro concluído ou parcial muda o status da atividade', () {
    ActivityStatus statusWith(String recordStatus) => activitiesFor(
      PatientBundle(
        patient: _patient,
        activities: [_activity(time: '10:30')],
        activityRecords: [
          ActivityRecord(
            id: 'r1',
            activityId: 'a1',
            status: recordStatus,
            performedAt: atTime(yesterday, '10:40'),
          ),
        ],
      ),
      yesterday,
    ).single.status;
    expect(statusWith('completed'), ActivityStatus.concluida);
    expect(statusWith('partial'), ActivityStatus.parcial);
    expect(statusWith('not_done'), ActivityStatus.naoRealizada);
  });

  test('A04 eventos do histórico são classificados pelo tipo de ação', () {
    expect(eventKind('medication.administration_recorded'), EventKind.medicamento);
    expect(eventKind('care_activity.recorded'), EventKind.atividade);
    expect(eventKind('observation.created'), EventKind.observacao);
    expect(eventKind('emergency.triggered'), EventKind.acionamento);
    expect(eventKind('patient.member_suspended'), EventKind.profissional);
  });

  test('A05 iniciais usam o primeiro e o último nome relevantes', () {
    expect(initials('Maria das Graças Oliveira'), 'MO');
    expect(initials('Carlos'), 'C');
    expect(initials(''), '?');
  });
}
