// Verifica o modo demonstração usado no teste de usabilidade: as cinco
// tarefas do roteiro funcionam sobre o servidor em memória.
import 'package:flutter_test/flutter_test.dart';
import 'package:vida_assistida/core/api_client.dart';
import 'package:vida_assistida/core/demo_backend.dart';

const maria = '33333333-3333-4333-8333-333333333333';

Future<void> loginAs(String email) async {
  final demo = DemoBackend.instance;
  final step = await demo.handle('POST', '/auth/login', {
    'email': email,
    'password': 'Demo@123',
  });
  await demo.handle('POST', '/auth/login/verify-code', {
    'loginToken': step['loginToken'],
    'code': DemoBackend.code,
    'deviceId': 'navegador-de-teste-0001',
    'deviceName': 'Teste',
  });
}

void main() {
  final demo = DemoBackend.instance;

  test('D01 recusa código incorreto do segundo fator', () async {
    final step = await demo.handle('POST', '/auth/login', {
      'email': 'profissional@vidaassistida.app',
      'password': 'Demo@123',
    });
    expect(step['status'], 'code');
    expect(
      () => demo.handle('POST', '/auth/login/verify-code', {
        'loginToken': step['loginToken'],
        'code': '000000',
      }),
      throwsA(isA<ApiException>()),
    );
  });

  test('D02 tarefas do profissional: medicamento, observação e acionamento', () async {
    await loginAs('profissional@vidaassistida.app');
    await demo.handle('POST', '/medications/demo-med-losartana/administrations', {
      'scheduledAt': DateTime.now().toUtc().toIso8601String(),
      'status': 'administered',
    });
    await demo.handle('POST', '/patients/$maria/observations', {
      'category': 'Alteração no estado do paciente',
      'level': 'attention',
      'text': 'Pressão elevada',
    });
    final alert = await demo.handle('POST', '/patients/$maria/emergency-alerts', {
      'reason': 'Situação urgente',
      'priority': 'alta',
    });
    expect(alert['notifiedName'], 'Ana Souza');

    final history = await demo.handle('GET', '/patients/$maria/audit', null) as List;
    expect(history.first['action'], 'emergency.triggered');
    expect(history[2]['action'], 'medication.administration_recorded');
    expect(history[2]['actor']['name'], 'Carlos Lima');
  });

  test('D03 responsável recebe a notificação e o profissional não vê o convite', () async {
    await loginAs('responsavel@vidaassistida.app');
    final notes = await demo.handle('GET', '/notifications', null) as List;
    expect(notes.first['type'], 'acionamento');

    await loginAs('profissional@vidaassistida.app');
    final patient = await demo.handle('GET', '/patients/$maria', null);
    expect(patient['joinCode'], '');
  });

  test('D04 cadastro de profissional com código de convite e novo login', () async {
    await demo.handle('POST', '/patients/invite/validate', {'code': 'VIDA2026'});
    await demo.handle('POST', '/auth/register', {
      'name': 'Paula Teste',
      'email': 'paula@teste.com',
      'password': 'Senha@123',
      'role': 'professional',
    });
    await demo.handle('POST', '/patients/join', {'code': 'VIDA2026'});
    final patients = await demo.handle('GET', '/patients', null) as List;
    expect(patients.single['name'], 'Maria Oliveira');

    final step = await demo.handle('POST', '/auth/login', {
      'email': 'paula@teste.com',
      'password': 'Senha@123',
    });
    expect(step['status'], 'code');
  });
}
