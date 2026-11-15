import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../core/care_data.dart';
import '../core/session.dart';
import '../models.dart';
import 'ui.dart';

class PatientAvatar extends StatelessWidget {
  const PatientAvatar({
    super.key,
    required this.patient,
    this.size = 48,
    this.badge = 0,
  });

  final Patient patient;
  final double size;
  final int badge;

  @override
  Widget build(BuildContext context) => Stack(
    clipBehavior: Clip.none,
    children: [
      Avatar(
        initials: initials(patient.name),
        color: colorFor(patient.id),
        size: size,
      ),
      if (badge > 0)
        Positioned(
          top: -4,
          right: -4,
          child: CountBadge(count: badge, border: true),
        ),
    ],
  );
}

/// Linha "Próximo medicamento · horário" com destaque para atraso.
class NextDoseLine extends StatelessWidget {
  const NextDoseLine({
    super.key,
    required this.bundle,
    this.icon = Icons.medication_outlined,
    this.prefix = '',
  });

  final PatientBundle bundle;
  final IconData icon;
  final String prefix;

  @override
  Widget build(BuildContext context) {
    final next = bundle.nextDose;
    final late = next?.status == DoseStatus.atrasado;
    final text = bundle.medicationsDenied
        ? 'Medicamentos restritos'
        : next == null
        ? 'Sem medicamentos pendentes hoje'
        : '$prefix${next.medication.label} · ${next.time}${late ? ' — ATRASADO' : ''}';
    return Row(
      children: [
        Icon(
          icon,
          size: 12,
          color: late ? AppColors.red500 : AppColors.teal600,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: body(
              size: 12,
              weight: FontWeight.w500,
              color: late ? AppColors.red600 : AppColors.slate500,
            ),
          ),
        ),
      ],
    );
  }
}

/// Seleciona o paciente para uma ação; com um único paciente, segue direto.
Future<Patient?> pickPatient(
  BuildContext context, {
  required String title,
  String subtitle = 'Selecione o paciente',
  IconData trailingIcon = Icons.chevron_right,
  Color trailingColor = AppColors.slate300,
  Color trailingBg = Colors.transparent,
}) async {
  final store = Session.of(context).store;
  final patients = store.bundles.map((b) => b.patient).toList();
  if (patients.isEmpty) {
    showToast(context, 'Nenhum paciente vinculado.', error: true);
    return null;
  }
  if (patients.length == 1) return patients.first;
  return Navigator.of(context).push<Patient>(
    MaterialPageRoute(
      builder: (_) => PatientPickerScreen(
        title: title,
        subtitle: subtitle,
        trailingIcon: trailingIcon,
        trailingColor: trailingColor,
        trailingBg: trailingBg,
      ),
    ),
  );
}

class PatientPickerScreen extends StatelessWidget {
  const PatientPickerScreen({
    super.key,
    required this.title,
    required this.subtitle,
    required this.trailingIcon,
    required this.trailingColor,
    required this.trailingBg,
  });

  final String title;
  final String subtitle;
  final IconData trailingIcon;
  final Color trailingColor;
  final Color trailingBg;

  @override
  Widget build(BuildContext context) {
    final store = Session.of(context).store;
    return AppScreen(
      header: GradientHeader(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Row(
          children: [
            Material(
              color: Colors.white.withValues(alpha: .2),
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => Navigator.pop(context),
                child: const SizedBox(
                  width: 36,
                  height: 36,
                  child: Icon(Icons.arrow_back, size: 20, color: Colors.white),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: display(size: 20, color: Colors.white)),
                  Text(
                    subtitle,
                    style: body(size: 12, color: AppColors.teal100),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
      children: [
        for (final bundle in store.bundles)
          AppCard(
            onTap: () => Navigator.pop(context, bundle.patient),
            child: Row(
              children: [
                PatientAvatar(patient: bundle.patient),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(bundle.patient.name, style: display(size: 16)),
                      const SizedBox(height: 2),
                      Text(
                        '${bundle.patient.age} anos · ${firstCondition(bundle.patient)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: body(size: 12, color: AppColors.slate400),
                      ),
                    ],
                  ),
                ),
                IconTile(
                  icon: trailingIcon,
                  color: trailingColor,
                  bg: trailingBg,
                  size: 36,
                  radius: 12,
                  iconSize: 18,
                ),
              ],
            ),
          ),
      ],
    );
  }
}

String firstCondition(Patient patient) {
  final value = patient.conditions?.trim();
  if (value == null || value.isEmpty) return 'Plano ativo';
  return value.split(RegExp(r'[,.;]| e ')).first.trim();
}
