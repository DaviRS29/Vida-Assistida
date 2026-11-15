import 'dart:async';

import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/app_theme.dart';
import '../core/care_data.dart';
import '../core/session.dart';
import '../models.dart';
import '../widgets/ui.dart';

/// Acionamento do responsável com confirmação por pressão contínua (2 s).
class SosScreen extends StatefulWidget {
  const SosScreen({super.key, required this.patientId});
  final String patientId;

  @override
  State<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends State<SosScreen>
    with SingleTickerProviderStateMixin {
  static const _reasons = [
    'Dúvida',
    'Medicamento',
    'Mudança no estado do paciente',
    'Necessidade de contato',
    'Situação urgente',
  ];

  String _reason = '';
  String _priority = 'normal';
  final _message = TextEditingController();
  late final AnimationController _hold = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  )..addStatusListener(_onHoldStatus);
  bool _sending = false;
  EmergencyAlert? _sent;
  bool _checking = false;

  @override
  void dispose() {
    _hold.dispose();
    _message.dispose();
    super.dispose();
  }

  bool get _critical => _priority == 'critica';

  void _onHoldStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) _send();
  }

  void _startHold() {
    if (_reason.isEmpty || _sending) return;
    _hold.forward(from: 0);
  }

  void _endHold() {
    if (_hold.status == AnimationStatus.completed) return;
    final releasedEarly = _hold.value < 1;
    _hold.reset();
    if (releasedEarly && mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'Segure o botão por 2 segundos para enviar o acionamento.',
            ),
            duration: Duration(seconds: 3),
          ),
        );
    }
  }

  Future<void> _send() async {
    final session = Session.of(context);
    setState(() => _sending = true);
    try {
      final alert = await session.api.triggerEmergency(
        widget.patientId,
        reason: _reason,
        priority: _priority,
        message: _message.text,
      );
      unawaited(session.store.refreshPatient(widget.patientId));
      if (mounted) setState(() => _sent = alert);
    } on ApiException catch (error) {
      _hold.reset();
      if (mounted) showToast(context, error.message, error: true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _checkStatus() async {
    final session = Session.of(context);
    setState(() => _checking = true);
    try {
      final alerts = await session.api.emergencyAlerts(widget.patientId);
      final current = alerts.where((a) => a.id == _sent!.id).firstOrNull;
      if (current != null && mounted) {
        setState(
          () => _sent = EmergencyAlert(
            id: current.id,
            patientId: current.patientId,
            status: current.status,
            priority: current.priority,
            createdAt: current.createdAt,
            reason: current.reason,
            message: current.message,
            acknowledgedAt: current.acknowledgedAt,
            acknowledgedBy: current.acknowledgedBy,
            triggeredBy: current.triggeredBy,
            notifiedName: _sent!.notifiedName,
          ),
        );
      }
    } on ApiException catch (error) {
      if (mounted) showToast(context, error.message, error: true);
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final patient = Session.of(
      context,
    ).store.bundleFor(widget.patientId)?.patient;
    if (_sent != null) return _sentView(patient);
    return AppScreen(
      header: GradientHeader(
        gradient: _critical
            ? criticalHeaderGradient
            : professionalHeaderGradient,
        onBack: () => Navigator.pop(context),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.sos_outlined,
                size: 26,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Contato com responsável',
                    style: display(size: 22, color: Colors.white, height: 1.15),
                  ),
                  Text(
                    'Canal interno · ${patient?.name ?? ''}',
                    style: body(
                      size: 14,
                      color: Colors.white.withValues(alpha: .7),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      spacing: 16,
      children: [
        const InfoBanner(
          tone: Tone.blue,
          icon: Icons.phone_outlined,
          title: 'Mensagem interna ao responsável',
          text:
              'Use para dúvidas, avisos e mudanças percebidas durante o cuidado.',
        ),
        const InfoBanner(
          tone: Tone.red,
          icon: Icons.warning_amber_rounded,
          text:
              'Este recurso não substitui serviços de emergência. Em uma situação crítica, ligue imediatamente para o SAMU (192) ou Bombeiros (193).',
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const FieldLabel('Motivo do acionamento', required: true),
            const SizedBox(height: 8),
            for (final item in _reasons) ...[
              OptionTile(
                label: item,
                radio: true,
                selected: _reason == item,
                color: AppColors.red600,
                bg: AppColors.red50,
                onTap: () => setState(() {
                  _reason = item;
                  if (item == 'Situação urgente' && _priority == 'normal') {
                    _priority = 'alta';
                  }
                }),
              ),
              const SizedBox(height: 8),
            ],
          ],
        ),
        AppInput(
          label: 'Mensagem (opcional)',
          controller: _message,
          hint: 'Descreva brevemente a situação...',
          maxLines: 3,
          maxLength: 500,
          focusColor: AppColors.red400,
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const FieldLabel('Prioridade'),
            const SizedBox(height: 8),
            SegmentChoice(
              options: const [
                ('normal', 'Normal', AppColors.teal600, AppColors.teal50),
                (
                  'alta',
                  'Alta',
                  AppColors.statusOrange,
                  AppColors.statusOrangeBg,
                ),
                (
                  'critica',
                  'Crítica',
                  AppColors.statusRed,
                  AppColors.statusRedBg,
                ),
              ],
              selected: _priority,
              onChanged: (value) => setState(() => _priority = value),
            ),
          ],
        ),
        Column(
          children: [
            const SizedBox(height: 8),
            Text(
              _reason.isEmpty
                  ? 'Selecione o motivo para habilitar o acionamento'
                  : 'Mantenha pressionado por 2 segundos para enviar',
              textAlign: TextAlign.center,
              style: body(size: 12, color: AppColors.slate400),
            ),
            const SizedBox(height: 12),
            _HoldButton(
              animation: _hold,
              enabled: _reason.isNotEmpty && !_sending,
              critical: _critical,
              sending: _sending,
              onStart: _startHold,
              onEnd: _endHold,
            ),
          ],
        ),
      ],
    );
  }

  Widget _sentView(Patient? patient) {
    final alert = _sent!;
    final seen = !alert.isActive;
    final name =
        alert.notifiedName ?? patient?.responsibleName ?? 'O responsável';
    return Scaffold(
      backgroundColor: AppColors.slate50,
      body: ListView(
        padding: EdgeInsets.fromLTRB(32, headerTop(context) + 24, 32, 32),
        children: [
          Center(
            child: Container(
              width: 96,
              height: 96,
              decoration: const BoxDecoration(
                color: AppColors.green100,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check,
                size: 44,
                color: AppColors.green600,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Responsável acionado',
            textAlign: TextAlign.center,
            style: display(size: 24),
          ),
          const SizedBox(height: 8),
          Text(
            '$name foi notificado(a) às ${hhmm(alert.createdAt)}',
            textAlign: TextAlign.center,
            style: body(size: 14, color: AppColors.slate500),
          ),
          const SizedBox(height: 24),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _InfoLine('Motivo', alert.reason ?? _reason),
                if (alert.message?.isNotEmpty == true) ...[
                  const SizedBox(height: 12),
                  _InfoLine('Mensagem', alert.message!),
                ],
                const SizedBox(height: 12),
                _InfoLine(
                  'Registrado em',
                  '${ddmmyyyy(alert.createdAt)} às ${hhmm(alert.createdAt)}',
                ),
                const SizedBox(height: 12),
                Text(
                  'Status',
                  style: body(size: 12, color: AppColors.slate400),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    _Pulse(
                      color: seen ? AppColors.green600 : AppColors.orange400,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        seen
                            ? 'Visualizado${alert.acknowledgedAt == null ? '' : ' às ${hhmm(alert.acknowledgedAt!)}'}'
                            : 'Aguardando visualização',
                        style: body(
                          size: 14,
                          weight: FontWeight.w600,
                          color: seen
                              ? AppColors.green700
                              : AppColors.orange600,
                        ),
                      ),
                    ),
                    if (!seen)
                      TextButton(
                        onPressed: _checking ? null : _checkStatus,
                        child: Text(
                          _checking ? 'Verificando...' : 'Atualizar',
                          style: body(
                            size: 12,
                            weight: FontWeight.w600,
                            color: AppColors.teal700,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const InfoBanner(
            tone: Tone.red,
            icon: Icons.warning_amber_rounded,
            text:
                'Este recurso não substitui serviços de emergência. Em uma emergência real, ligue para o SAMU (192) ou Bombeiros (193).',
          ),
          const SizedBox(height: 24),
          PrimaryButton(
            label: 'Concluído',
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: body(size: 12, color: AppColors.slate400)),
      const SizedBox(height: 2),
      Text(
        value,
        style: body(
          size: 14,
          weight: FontWeight.w600,
          color: AppColors.slate700,
        ),
      ),
    ],
  );
}

class _Pulse extends StatefulWidget {
  const _Pulse({required this.color});
  final Color color;

  @override
  State<_Pulse> createState() => _PulseState();
}

class _PulseState extends State<_Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: 14,
    child: AnimatedBuilder(
      animation: _c,
      builder: (context, _) => Stack(
        alignment: Alignment.center,
        children: [
          Transform.scale(
            scale: 1 + _c.value * .4,
            child: Opacity(
              opacity: 1 - _c.value,
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: widget.color,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: widget.color,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    ),
  );
}

class _HoldButton extends StatelessWidget {
  const _HoldButton({
    required this.animation,
    required this.enabled,
    required this.critical,
    required this.sending,
    required this.onStart,
    required this.onEnd,
  });

  final Animation<double> animation;
  final bool enabled;
  final bool critical;
  final bool sending;
  final VoidCallback onStart;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) {
    final strong = critical ? AppColors.red600 : AppColors.blue600;
    final darker = critical ? AppColors.red700 : AppColors.blue700;
    final text = critical ? AppColors.red700 : AppColors.blue800;
    final sub = critical ? AppColors.red500 : AppColors.blue600;
    return Semantics(
      button: true,
      enabled: enabled,
      label: 'Manter pressionado para acionar o responsável',
      child: Opacity(
        opacity: enabled || sending ? 1 : .4,
        child: Listener(
          onPointerDown: enabled ? (_) => onStart() : null,
          onPointerUp: enabled ? (_) => onEnd() : null,
          onPointerCancel: enabled ? (_) => onEnd() : null,
          child: AnimatedBuilder(
            animation: animation,
            builder: (context, _) {
              final holding = animation.value > 0 && !sending;
              return ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  color: critical ? AppColors.red100 : AppColors.blue50,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: animation.value,
                          child: Container(
                            color:
                                (critical
                                        ? AppColors.red500
                                        : const Color(0xFF3B82F6))
                                    .withValues(alpha: .3),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            AnimatedScale(
                              scale: holding ? 1.1 : 1,
                              duration: const Duration(milliseconds: 150),
                              child: Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  color: holding ? darker : strong,
                                  shape: BoxShape.circle,
                                  boxShadow: holding
                                      ? const [
                                          BoxShadow(
                                            color: Color(0x33000000),
                                            blurRadius: 12,
                                            offset: Offset(0, 4),
                                          ),
                                        ]
                                      : null,
                                ),
                                child: sending
                                    ? const Padding(
                                        padding: EdgeInsets.all(16),
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.sos_outlined,
                                        size: 26,
                                        color: Colors.white,
                                      ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  sending
                                      ? 'Enviando...'
                                      : holding
                                      ? 'Acionando... ${(animation.value * 100).round()}%'
                                      : 'Acionar responsável',
                                  style: display(
                                    size: 16,
                                    weight: FontWeight.w900,
                                    color: text,
                                    height: 1,
                                  ),
                                ),
                                if (!holding && !sending && enabled) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    'Segure para confirmar',
                                    style: body(size: 12, color: sub),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
