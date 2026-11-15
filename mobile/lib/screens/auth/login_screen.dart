import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../../core/demo_backend.dart';
import '../../core/device_identity.dart';
import '../../core/session.dart';
import '../../models.dart';
import '../../widgets/ui.dart';
import 'forgot_password_screen.dart';
import 'invite_code_screen.dart';
import 'register_screen.dart';
import 'two_factor_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    required this.api,
    required this.settings,
    required this.onAuthenticated,
  });

  final ApiClient api;
  final AppSettings settings;
  final ValueChanged<UserProfile> onAuthenticated;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _login = TextEditingController();
  final _password = TextEditingController();
  bool _show = false;
  bool _remember = false;
  String _role = 'responsible';
  bool _loading = false;
  String _error = '';
  String? _pendingInvite;

  @override
  void initState() {
    super.initState();
    final remembered = widget.settings.rememberedLogin;
    if (remembered.isNotEmpty) {
      _login.text = remembered;
      _remember = true;
    } else if (kDebugMode || DemoBackend.enabled) {
      _fillDemo();
    }
  }

  /// Em modo de desenvolvimento, preenche as contas fictícias de demonstração.
  void _fillDemo() {
    if (!kDebugMode && !DemoBackend.enabled) return;
    _login.text = _role == 'responsible'
        ? 'responsavel@vidaassistida.app'
        : 'profissional@vidaassistida.app';
    _password.text = 'Demo@123';
  }

  @override
  void dispose() {
    _login.dispose();
    _password.dispose();
    super.dispose();
  }

  void _selectRole(String role) {
    setState(() => _role = role);
    if (widget.settings.rememberedLogin.isEmpty) _fillDemo();
  }

  Future<void> _submit() async {
    if (_login.text.trim().isEmpty || _password.text.isEmpty) {
      setState(() => _error = 'Preencha CPF/e-mail e senha.');
      return;
    }
    setState(() {
      _error = '';
      _loading = true;
    });
    try {
      final identity = DeviceIdentity();
      final step = await widget.api.login(
        _login.text,
        _password.text,
        deviceId: await identity.existingId(),
      );
      if (!mounted) return;
      final user = await completeLogin(
        context,
        api: widget.api,
        identity: identity,
        step: step,
      );
      if (user == null) {
        widget.api.clearSession();
        return;
      }
      if (user.role != _role) {
        widget.api.clearSession();
        throw ApiException(
          user.isResponsible
              ? 'Esta conta é de responsável. Selecione "Responsável" para continuar.'
              : 'Esta conta é de profissional. Selecione "Profissional" para continuar.',
        );
      }
      if (_pendingInvite != null) await widget.api.joinPatient(_pendingInvite!);
      await widget.settings.setRememberedLogin(
        _remember ? _login.text.trim() : '',
      );
      widget.onAuthenticated(user);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (error, stack) {
      debugPrint('Falha no login: $error\n$stack');
      if (mounted) {
        setState(
          () => _error = DemoBackend.enabled
              ? 'Erro no modo demonstração: $error'
              : 'API indisponível. Verifique se o servidor está ativo.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openInvite() async {
    final result = await Navigator.of(context).push<InviteResult>(
      MaterialPageRoute(builder: (_) => InviteCodeScreen(api: widget.api)),
    );
    if (result == null || !mounted) return;
    if (result.createAccount) {
      await _openRegister(inviteCode: result.code);
      return;
    }
    setState(() {
      _pendingInvite = result.code;
      _role = 'professional';
      _error = '';
    });
    if (widget.settings.rememberedLogin.isEmpty) _fillDemo();
  }

  Future<void> _openRegister({String? inviteCode}) async {
    final user = await Navigator.of(context).push<UserProfile>(
      MaterialPageRoute(
        builder: (_) => RegisterScreen(api: widget.api, inviteCode: inviteCode),
      ),
    );
    if (user != null) widget.onAuthenticated(user);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.slate50,
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          GradientHeader(
            gradient: appHeaderGradient,
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.asset(
                        'assets/brand/icon_small.png',
                        width: 48,
                        height: 48,
                        semanticLabel: 'Logo Vida Assistida',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Vida Assistida',
                          style: display(
                            size: 20,
                            weight: FontWeight.w900,
                            color: Colors.white,
                            height: 1,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Home Care',
                          style: body(
                            size: 12,
                            weight: FontWeight.w500,
                            color: AppColors.teal100,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  'Bem-vindo de volta',
                  style: display(size: 24, color: Colors.white),
                ),
                const SizedBox(height: 4),
                Text(
                  'Acesse sua conta para continuar',
                  style: body(size: 14, color: AppColors.teal100),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'COMO VOCÊ VAI ACESSAR?',
                  style: body(
                    size: 12,
                    weight: FontWeight.w700,
                    color: AppColors.slate400,
                    letterSpacing: 1.7,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _RoleChoice(
                        icon: Icons.shield_outlined,
                        title: 'Responsável',
                        subtitle: 'Gestão do cuidado',
                        selected: _role == 'responsible',
                        onTap: () => _selectRole('responsible'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _RoleChoice(
                        icon: Icons.assignment_outlined,
                        title: 'Profissional',
                        subtitle: 'Rotina assistencial',
                        selected: _role == 'professional',
                        onTap: () => _selectRole('professional'),
                      ),
                    ),
                  ],
                ),
                if (_pendingInvite != null) ...[
                  const SizedBox(height: 20),
                  InfoBanner(
                    icon: Icons.link,
                    tone: Tone.blue,
                    title: 'Convite $_pendingInvite validado',
                    text:
                        'Entre com sua conta profissional para acessar o espaço do paciente.',
                    onClose: () => setState(() => _pendingInvite = null),
                  ),
                ],
                if (_error.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  ErrorBox(_error),
                ],
                const SizedBox(height: 20),
                AppInput(
                  label: 'CPF ou E-mail',
                  controller: _login,
                  hint: '000.000.000-00',
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.username],
                ),
                const SizedBox(height: 20),
                AppInput(
                  label: 'Senha',
                  controller: _password,
                  hint: '••••••••',
                  obscure: !_show,
                  autofillHints: const [AutofillHints.password],
                  onSubmitted: (_) => _submit(),
                  suffix: IconButton(
                    tooltip: _show ? 'Ocultar senha' : 'Mostrar senha',
                    onPressed: () => setState(() => _show = !_show),
                    icon: Icon(
                      _show
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      size: 18,
                      color: AppColors.slate400,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    AppCheckbox(
                      value: _remember,
                      onChanged: (value) => setState(() => _remember = value),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _remember = !_remember),
                        child: Text(
                          'Lembrar-me',
                          overflow: TextOverflow.ellipsis,
                          style: body(size: 14, color: AppColors.slate600),
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => ForgotPasswordScreen(api: widget.api),
                        ),
                      ),
                      child: Text(
                        'Esqueci a senha',
                        style: body(
                          size: 14,
                          weight: FontWeight.w600,
                          color: AppColors.teal700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                PrimaryButton(
                  label: 'Entrar',
                  loading: _loading,
                  onPressed: _submit,
                ),
                const SizedBox(height: 20),
                const OrDivider('ou'),
                const SizedBox(height: 20),
                OutlineAppButton(
                  label: 'Entrar com código de convite',
                  icon: Icons.link,
                  onPressed: _openInvite,
                ),
                const SizedBox(height: 20),
                Center(
                  child: InkWell(
                    onTap: () => _openRegister(),
                    child: Text.rich(
                      TextSpan(
                        text: 'Não tem conta? ',
                        children: [
                          TextSpan(
                            text: 'Criar minha conta',
                            style: body(
                              size: 14,
                              weight: FontWeight.w700,
                              color: AppColors.teal700,
                            ),
                          ),
                        ],
                      ),
                      style: body(size: 14, color: AppColors.slate600),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.shield_outlined,
                      size: 14,
                      color: AppColors.slate400,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'Seus dados são protegidos conforme a LGPD.',
                        style: body(size: 12, color: AppColors.slate400),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RoleChoice extends StatelessWidget {
  const _RoleChoice({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.teal700 : AppColors.slate500;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      constraints: const BoxConstraints(minHeight: 74),
      decoration: BoxDecoration(
        gradient: selected
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.teal50, Colors.white],
              )
            : null,
        color: selected ? null : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: selected ? AppColors.teal300 : AppColors.slate200,
        ),
        boxShadow: selected
            ? const [
                BoxShadow(
                  color: Color(0x1F0D9488),
                  blurRadius: 22,
                  offset: Offset(0, 8),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(icon, size: 19, color: color),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: body(
                          size: 14,
                          weight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: body(
                          size: 10,
                          color: color.withValues(alpha: .7),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
