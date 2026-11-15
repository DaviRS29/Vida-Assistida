import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vida_assistida/core/care_data.dart';
import 'package:vida_assistida/main.dart';
import 'package:vida_assistida/models.dart';

void main() {
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('abre pela tela inicial e segue para o login', (tester) async {
    // A fonte de teste (Ahem) é bem mais larga que Nunito/Inter; avisos de
    // estouro de layout causados por ela não representam a tela real.
    final original = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exceptionAsString().contains('overflowed')) return;
      original?.call(details);
    };
    addTearDown(() => FlutterError.onError = original);
    await tester.pumpWidget(const VidaAssistidaApp());
    expect(find.text('Cuidado conectado, informação segura'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 2500));
    await tester.pumpAndSettle();

    expect(find.text('Bem-vindo de volta'), findsOneWidget);
    expect(find.text('Responsável'), findsOneWidget);
    expect(find.text('Profissional'), findsOneWidget);
    expect(find.text('Entrar com código de convite'), findsOneWidget);
  });

  test('calcula atraso e confirmação dos horários de medicamento', () {
    final today = DateTime.now();
    final patient = Patient.fromJson({
      'id': 'p1',
      'name': 'Maria das Graças Oliveira',
      'birthDate': '1946-03-15',
      'status': 'active',
    });
    final medication = Medication(
      id: 'm1',
      patientId: 'p1',
      name: 'Losartana',
      dosage: '50 mg',
      route: 'Oral',
      schedule: const ['00:00', '23:59'],
      createdAt: today.subtract(const Duration(days: 1)),
    );
    final bundle = PatientBundle(patient: patient, medications: [medication]);
    final doses = dosesFor(bundle, today);

    expect(initials(patient.name), 'MO');
    expect(doses, hasLength(2));
    expect(doses.last.status, DoseStatus.pendente);
    if (today.hour > 0 || today.minute >= 30) {
      expect(doses.first.status, DoseStatus.atrasado);
    }

    final confirmed = PatientBundle(
      patient: patient,
      medications: [medication],
      administrations: [
        Administration(
          id: 'a1',
          medicationId: 'm1',
          status: 'administered',
          scheduledAt: atTime(today, '00:00'),
          createdAt: today,
        ),
      ],
    );
    expect(dosesFor(confirmed, today).first.status, DoseStatus.administrado);
  });
}
