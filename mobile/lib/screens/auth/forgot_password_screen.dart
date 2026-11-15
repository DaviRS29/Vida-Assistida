import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../../widgets/ui.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key, required this.api});
  final ApiClient api;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _email = TextEditingController();
  bool _loading = false;
  bool _sent = false;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _email.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!_email.text.contains('@')) {
      setState(() => _error = 'Informe um e-mail válido.');
      return;
    }
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      await widget.api.forgotPassword(_email.text);
      if (mounted) setState(() => _sent = true);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
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
            'Recuperar acesso',
            subtitle: 'Enviaremos um link de redefinição para seu e-mail',
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
            children: _sent ? _sentView() : _form(),
          ),
        ),
      ],
    ),
  );

  List<Widget> _form() => [
    const InfoBanner(
      text:
          'Digite o e-mail cadastrado na sua conta. Você receberá um link para criar uma nova senha.',
    ),
    const SizedBox(height: 20),
    AppInput(
      label: 'E-mail cadastrado',
      controller: _email,
      hint: 'seu@email.com',
      keyboardType: TextInputType.emailAddress,
      error: _error.isEmpty ? null : _error,
      onSubmitted: (_) => _send(),
    ),
    const SizedBox(height: 20),
    PrimaryButton(
      label: 'Enviar link de recuperação',
      loading: _loading,
      onPressed: _email.text.trim().isEmpty ? null : _send,
    ),
    const SizedBox(height: 8),
    TextLinkButton(
      label: 'Voltar ao login',
      onPressed: () => Navigator.pop(context),
    ),
  ];

  List<Widget> _sentView() => [
    const SizedBox(height: 16),
    Center(
      child: Container(
        width: 80,
        height: 80,
        decoration: const BoxDecoration(
          color: AppColors.teal50,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.check, size: 36, color: AppColors.teal700),
      ),
    ),
    const SizedBox(height: 20),
    Text(
      'E-mail enviado!',
      textAlign: TextAlign.center,
      style: display(size: 20),
    ),
    const SizedBox(height: 8),
    Text.rich(
      TextSpan(
        text: 'Se houver uma conta para ',
        children: [
          TextSpan(
            text: _email.text.trim(),
            style: body(
              size: 14,
              weight: FontWeight.w600,
              color: AppColors.slate500,
            ),
          ),
          const TextSpan(
            text: ', você receberá as instruções para redefinir sua senha.',
          ),
        ],
      ),
      textAlign: TextAlign.center,
      style: body(size: 14, color: AppColors.slate500),
    ),
    const SizedBox(height: 20),
    Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.teal50,
        border: Border.all(color: AppColors.teal200),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        'O link expira em 30 minutos. Verifique também a pasta de spam.',
        textAlign: TextAlign.center,
        style: body(size: 12, color: AppColors.teal700),
      ),
    ),
    const SizedBox(height: 20),
    PrimaryButton(
      label: 'Voltar ao login',
      onPressed: () => Navigator.pop(context),
    ),
  ];
}
