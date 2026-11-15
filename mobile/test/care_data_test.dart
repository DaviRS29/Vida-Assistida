// Testes de unidade das regras da agenda de medicamentos (RF02).
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

Medication _medication({
  List<String> schedule = const ['08:00', '20:00'],
  String? frequency,
  DateTime? start,
  DateTime? end,
}) =>
    Medication(
      id: 'm1',
      patientId: 'p1',
      name: 'Losartana',
      dosage: '50 mg',
      route: 'oral',
      schedule: schedule,
      createdAt: DateTime(2026, 1, 1),
      frequency: frequency,
      startDate: start,
      endDate: end,
    );

void main() {
  final yesterday = dayOf(DateTime.now()).subtract(const Duration(days: 1));

  test('F01 dose passada sem registro fica atrasada', () {
    final bundle = PatientBundle(patient: _patient, medications: [_medication()]);
    final doses = dosesFor(bundle, yesterday);
    expect(doses, hasLength(2));
    expect(doses.every((d) => d.status == DoseStatus.atrasado), isTrue);
  });

  test('F02 dose registrada aparece como administrada ou não administrada', () {
    final bundle = PatientBundle(
      patient: _patient,
      medications: [_medication()],
      administrations: [
        Administration(
          id: 'a1',
          medicationId: 'm1',
          status: 'administered',
          scheduledAt: atTime(yesterday, '08:00'),
          createdAt: yesterday,
        ),
        Administration(
          id: 'a2',
          medicationId: 'm1',
          status: 'not_administered',
          scheduledAt: atTime(yesterday, '20:00'),
          createdAt: yesterday,
        ),
      ],
    );
    final doses = dosesFor(bundle, yesterday);
    expect(doses.first.status, DoseStatus.administrado);
    expect(doses.last.status, DoseStatus.naoAdministrado);
  });

  test('F03 dose futura permanece pendente', () {
    final tomorrow = dayOf(DateTime.now()).add(const Duration(days: 1));
    final bundle = PatientBundle(patient: _patient, medications: [_medication()]);
    expect(
      dosesFor(bundle, tomorrow).every((d) => d.status == DoseStatus.pendente),
      isTrue,
    );
  });

  test('F04 respeita início, fim e dias alternados', () {
    final start = DateTime(2026, 3, 1);
    final alternate = _medication(
      frequency: 'Em dias alternados',
      start: start,
      end: DateTime(2026, 3, 10),
    );
    final bundle = PatientBundle(patient: _patient, medications: [alternate]);
    expect(dosesFor(bundle, DateTime(2026, 2, 28)), isEmpty);
    expect(dosesFor(bundle, DateTime(2026, 3, 1)), hasLength(2));
    expect(dosesFor(bundle, DateTime(2026, 3, 2)), isEmpty);
    expect(dosesFor(bundle, DateTime(2026, 3, 11)), isEmpty);
  });
}
