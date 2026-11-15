import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../../core/demo_backend.dart';
import '../../core/device_identity.dart';
import '../../models.dart';
import '../../widgets/ui.dart';

/// Conclui o login após a senha: assina com o aparelho reconhecido ou pede
/// o código enviado por e-mail quando o aparelho é novo.
Future<UserProfile?> completeLogin(
  BuildContext context, {
  required ApiClient api,
  required DeviceIdentity identity,
  required LoginStep step,
}) async {
  switch (step) {
    case Authenticated(:final user):
      return user;
    case DeviceChallenge(:final loginToken, :final challenge):
      try {
        final signature = await identity.sign(challenge);
        return await api.verifyDevice(loginToken, signature);
      } catch (_) {
        // Chave perdida ou aparelho revogado: segue pelo código por e-mail.
        final fallback = await api.sendCode(loginToken);
        if (!context.mounted) return null;
        return completeLogin(
          context,
          api: api,
          identity: identity,
          step: fallback,
        );
      }
    case CodeChallenge():
      return Navigator.of(context).push<UserProfile>(
        MaterialPageRoute(
          builder: (_) =>
              TwoFactorScreen(api: api, identity: identity, challenge: step),
        ),
      );
  }
}

class TwoFactorScreen extends StatefulWidget {
  const TwoFactorScreen({
    super.key,
    required this.api,
    required this.identity,
    required this.challenge,
  });

  final ApiClient api;
  final DeviceIdentity identity;
  final CodeChallenge challenge;

  @override
  State<TwoFactorScreen> createState() => _TwoFactorScreenState();
}

class _TwoFactorScreenState extends State<TwoFactorScreen> {
  final _code = TextEditingController();
  late CodeChallenge _challenge = widget.challenge;
  bool _loading = false;
  bool _resending = false;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _code.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    if (_code.text.length != 6) return;
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      final device = await widget.identity.ensure();
      final user = await widget.api.verifyCode(
        _challenge.loginToken,
        _code.text,
        device.toJson(),
      );
      if (mounted) Navigator.pop(context, user);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
      if (error.message.contains('expirada') ||
          error.message.contains('máximo')) {
        await Future<void>.delayed(const Duration(seconds: 2));
        if (mounted) Navigator.pop(context);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resend() async {
    setState(() {
      _resending = true;
      _error = '';
    });
    try {
      final next = await widget.api.sendCode(_challenge.loginToken);
      if (!mounted) return;
      setState(() {
        _challenge = next;
        _code.clear();
      });
      showToast(context, 'Enviamos um novo código.');
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.slate50,
    body: Column(
      children: [
        GradientHeader(
          gradient: appHeaderGradient,
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
          onBack: () => Navigator.pop(context),
          child: const HeaderTitle(
            'Verificação em duas etapas',
            subtitle: 'Confirme que é você neste aparelho',
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
            children: [
              const Center(
                child: IconTile(
                  icon: Icons.shield_outlined,
                  color: AppColors.teal700,
                  bg: AppColors.teal100,
                  size: 64,
                  radius: 20,
                  iconSize: 30,
                ),
              ),
              const SizedBox(height: 16),
              Text.rich(
                TextSpan(
                  text: 'Enviamos um código de 6 dígitos para ',
                  children: [
                    TextSpan(
                      text: _challenge.emailHint,
                      style: body(
                        size: 14,
                        weight: FontWeight.w600,
                        color: AppColors.slate700,
                      ),
                    ),
                    const TextSpan(text: '. Ele vale por 10 minutos.'),
                  ],
                ),
                textAlign: TextAlign.center,
                style: body(size: 14, color: AppColors.slate500),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _code,
                autofocus: true,
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                autofillHints: const [AutofillHints.oneTimeCode],
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                onSubmitted: (_) => _confirm(),
                style: display(
                  size: 28,
                  weight: FontWeight.w900,
                  color: AppColors.teal700,
                  letterSpacing: 12,
                ),
                decoration: appInputDecoration(hint: '000000').copyWith(
                  hintStyle: display(
                    size: 28,
                    weight: FontWeight.w900,
                    color: AppColors.slate300,
                    letterSpacing: 12,
                  ),
                ),
              ),
              if (_error.isNotEmpty) ...[
                const SizedBox(height: 12),
                ErrorBox(_error),
              ],
              const SizedBox(height: 20),
              if (DemoBackend.enabled) ...[
                const InfoBanner(
                  icon: Icons.science_outlined,
                  title: 'Modo demonstração',
                  text:
                      'Nesta versão de teste o e-mail não é enviado. Use o código ${DemoBackend.code}.',
                ),
                const SizedBox(height: 12),
              ],
              const InfoBanner(
                icon: Icons.phone_android_outlined,
                text:
                    'Depois da confirmação, este aparelho passa a ser reconhecido e os próximos acessos não pedirão o código. Você pode revogar aparelhos em Perfil › Segurança.',
              ),
              const SizedBox(height: 20),
              PrimaryButton(
                label: 'Confirmar',
                loading: _loading,
                onPressed: _code.text.length == 6 ? _confirm : null,
              ),
              const SizedBox(height: 8),
              TextLinkButton(
                label: _resending ? 'Enviando...' : 'Reenviar código',
                color: AppColors.teal700,
                onPressed: _resending ? () {} : _resend,
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
