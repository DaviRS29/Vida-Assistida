import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../../core/device_identity.dart';
import '../../models.dart';
import '../../widgets/ui.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key, required this.api, this.inviteCode});

  final ApiClient api;

  /// Quando vem de um convite, o perfil profissional é pré-selecionado.
  final String? inviteCode;

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  int _step = 1;
  String? _role;
  final _name = TextEditingController();
  final _cpf = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _profession = TextEditingController();
  final _council = TextEditingController();
  final _password = TextEditingController();
  final _password2 = TextEditingController();
  bool _show = false;
  bool _terms = false;
  bool _loading = false;
  String _error = '';

  @override
  void initState() {
    super.initState();
    if (widget.inviteCode != null) _role = 'professional';
    for (final controller in [_password, _password2, _name, _email, _cpf]) {
      controller.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    for (final controller in [
      _name,
      _cpf,
      _email,
      _phone,
      _profession,
      _council,
      _password,
      _password2,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  bool get _passwordOk => _password.text.length >= 8;
  bool get _passwordMatch => _password.text == _password2.text;
  bool get _cpfOk {
    final digits = _cpf.text.replaceAll(RegExp(r'\D'), '');
    return digits.isEmpty || digits.length == 11;
  }

  String? _validateStep2() {
    if (_name.text.trim().length < 2) return 'Informe seu nome completo.';
    if (!_cpfOk) return 'O CPF deve ter 11 dígitos.';
    if (!_email.text.contains('@')) return 'Informe um e-mail válido.';
    return null;
  }

  Future<void> _finish() async {
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      final device = await DeviceIdentity().ensure();
      final user = await widget.api.register(
        name: _name.text,
        email: _email.text,
        password: _password.text,
        role: _role!,
        cpf: _cpf.text,
        phone: _phone.text,
        profession: _role == 'professional' ? _profession.text : null,
        professionalCouncil: _role == 'professional' ? _council.text : null,
        device: device.toJson(),
      );
      if (widget.inviteCode != null && user.isProfessional) {
        await widget.api.joinPatient(widget.inviteCode!);
      }
      if (mounted) Navigator.pop<UserProfile>(context, user);
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
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          onBack: () => Navigator.pop(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              StepBars(step: _step),
              const SizedBox(height: 16),
              HeaderTitle(
                'Criar conta',
                subtitle: _step == 1
                    ? 'Escolha seu perfil'
                    : _step == 2
                    ? 'Seus dados pessoais'
                    : 'Segurança e termos',
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
            children: [
              if (_error.isNotEmpty) ...[
                ErrorBox(_error),
                const SizedBox(height: 20),
              ],
              ...switch (_step) {
                1 => _stepProfile(),
                2 => _stepData(),
                _ => _stepSecurity(),
              },
            ],
          ),
        ),
      ],
    ),
  );

  List<Widget> _stepProfile() => [
    Text(
      'Como você usará o Vida Assistida?',
      style: body(size: 14, color: AppColors.slate600),
    ),
    const SizedBox(height: 20),
    _ProfileCard(
      icon: Icons.phone_outlined,
      title: 'Sou responsável por um paciente',
      text: 'Gerencio o cuidado de um familiar ou pessoa próxima',
      selected: _role == 'responsible',
      onTap: widget.inviteCode == null
          ? () => setState(() => _role = 'responsible')
          : null,
    ),
    const SizedBox(height: 20),
    _ProfileCard(
      icon: Icons.assignment_outlined,
      title: 'Sou profissional de atenção domiciliar',
      text: 'Presto serviços de saúde em ambiente domiciliar',
      selected: _role == 'professional',
      onTap: () => setState(() => _role = 'professional'),
    ),
    const SizedBox(height: 28),
    PrimaryButton(
      label: 'Continuar',
      onPressed: _role == null ? null : () => setState(() => _step = 2),
    ),
  ];

  List<Widget> _stepData() => [
    AppInput(
      label: 'Nome completo',
      controller: _name,
      hint: 'Seu nome completo',
    ),
    const SizedBox(height: 20),
    AppInput(
      label: 'CPF',
      controller: _cpf,
      hint: '000.000.000-00',
      keyboardType: TextInputType.number,
      error: _cpfOk ? null : 'O CPF deve ter 11 dígitos.',
    ),
    const SizedBox(height: 20),
    AppInput(
      label: 'E-mail',
      controller: _email,
      hint: 'seu@email.com',
      keyboardType: TextInputType.emailAddress,
    ),
    const SizedBox(height: 20),
    AppInput(
      label: 'Telefone',
      controller: _phone,
      hint: '(79) 99000-0000',
      keyboardType: TextInputType.phone,
    ),
    if (_role == 'professional') ...[
      const SizedBox(height: 20),
      AppInput(
        label: 'Profissão',
        controller: _profession,
        hint: 'Ex: Enfermeiro, Fisioterapeuta',
      ),
      const SizedBox(height: 20),
      AppInput(
        label: 'Conselho profissional',
        controller: _council,
        hint: 'Ex: COREN-SE 45.678',
        helper: 'Deixe em branco se não aplicável',
      ),
    ],
    const SizedBox(height: 28),
    Row(
      children: [
        SecondaryButton(
          label: 'Voltar',
          onPressed: () => setState(() => _step = 1),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: PrimaryButton(
            label: 'Continuar',
            onPressed: () {
              final problem = _validateStep2();
              setState(() {
                _error = problem ?? '';
                if (problem == null) _step = 3;
              });
            },
          ),
        ),
      ],
    ),
  ];

  List<Widget> _stepSecurity() {
    final score = (_password.text.length / 3).floor().clamp(0, 4);
    final strengthColor = score <= 1
        ? AppColors.red400
        : score <= 2
        ? AppColors.orange400
        : score <= 3
        ? const Color(0xFFFACC15)
        : const Color(0xFF22C55E);
    return [
      AppInput(
        label: 'Senha',
        controller: _password,
        hint: 'Mínimo 8 caracteres',
        obscure: !_show,
        error: _password.text.isNotEmpty && !_passwordOk
            ? 'Use pelo menos 8 caracteres.'
            : null,
        suffix: IconButton(
          onPressed: () => setState(() => _show = !_show),
          icon: Icon(
            _show ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            size: 18,
            color: AppColors.slate400,
          ),
        ),
      ),
      const SizedBox(height: 20),
      AppInput(
        label: 'Confirmar senha',
        controller: _password2,
        hint: 'Repita sua senha',
        obscure: !_show,
        error: _password2.text.isNotEmpty && !_passwordMatch
            ? 'As senhas não coincidem.'
            : null,
      ),
      if (_password.text.isNotEmpty) ...[
        const SizedBox(height: 20),
        Row(
          children: [
            for (var i = 1; i <= 4; i++) ...[
              if (i > 1) const SizedBox(width: 4),
              Expanded(
                child: Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: i <= score ? strengthColor : AppColors.slate200,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
      const SizedBox(height: 20),
      const InfoBanner(
        bordered: false,
        text:
            'Ao criar sua conta, você concorda com nossos Termos de Uso e com o tratamento dos seus dados conforme nossa Política de Privacidade e a LGPD (Lei 13.709/2018).',
      ),
      const SizedBox(height: 20),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: AppCheckbox(
              value: _terms,
              onChanged: (value) => setState(() => _terms = value),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _terms = !_terms),
              child: Text.rich(
                TextSpan(
                  text: 'Li e aceito os ',
                  children: [
                    TextSpan(
                      text: 'Termos de Uso',
                      style: body(
                        size: 14,
                        weight: FontWeight.w600,
                        color: AppColors.teal700,
                      ),
                    ),
                    const TextSpan(text: ' e a '),
                    TextSpan(
                      text: 'Política de Privacidade',
                      style: body(
                        size: 14,
                        weight: FontWeight.w600,
                        color: AppColors.teal700,
                      ),
                    ),
                  ],
                ),
                style: body(size: 14, color: AppColors.slate600),
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 20),
      Row(
        children: [
          SecondaryButton(
            label: 'Voltar',
            onPressed: () => setState(() => _step = 2),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: PrimaryButton(
              label: 'Criar conta',
              loading: _loading,
              onPressed: _terms && _passwordOk && _passwordMatch
                  ? _finish
                  : null,
            ),
          ),
        ],
      ),
    ];
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.icon,
    required this.title,
    required this.text,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String text;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: onTap == null && !selected ? .5 : 1,
    child: Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: selected ? AppColors.teal700 : AppColors.slate100,
          width: 2,
        ),
      ),
      elevation: selected ? 3 : 0,
      shadowColor: Colors.black26,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconTile(
                icon: icon,
                color: selected ? AppColors.teal700 : AppColors.slate500,
                bg: selected ? AppColors.teal100 : AppColors.slate100,
                size: 48,
                radius: 16,
                iconSize: 24,
              ),
              const SizedBox(height: 12),
              Text(title, style: display(size: 16)),
              const SizedBox(height: 4),
              Text(text, style: body(size: 14, color: AppColors.slate500)),
            ],
          ),
        ),
      ),
    ),
  );
}
