import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/app_theme.dart';
import '../core/care_data.dart';
import '../core/device_identity.dart';
import '../models.dart';
import '../core/session.dart';
import '../widgets/ui.dart';
import 'history_screens.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = Session.of(context);
    final user = session.user;
    final responsible = user.isResponsible;
    final store = session.store;

    final sections =
        <(String, List<(IconData, String, Color, Widget Function())>)>[
          (
            'Conta',
            [
              (
                Icons.person_outline,
                'Dados pessoais',
                AppColors.teal600,
                () => const ProfileEditScreen(),
              ),
              (
                Icons.shield_outlined,
                'Segurança',
                AppColors.teal600,
                () => const SecurityScreen(),
              ),
              if (!responsible)
                (
                  Icons.history,
                  'Meu histórico',
                  AppColors.teal600,
                  () => const MyHistoryScreen(),
                ),
            ],
          ),
          (
            'Preferências',
            [
              (
                Icons.notifications_none,
                'Notificações',
                const Color(0xFF059669),
                () => const NotificationPrefsScreen(),
              ),
              (
                Icons.settings_outlined,
                'Acessibilidade',
                const Color(0xFF059669),
                () => const AccessibilityScreen(),
              ),
            ],
          ),
          (
            'Privacidade e Legal',
            [
              (
                Icons.shield_outlined,
                'Termos de uso',
                AppColors.purple,
                () => const LegalScreen(kind: LegalKind.terms),
              ),
              (
                Icons.info_outline,
                'Política de privacidade',
                AppColors.purple,
                () => const LegalScreen(kind: LegalKind.privacy),
              ),
              (
                Icons.info_outline,
                'Tratamento de dados (LGPD)',
                AppColors.purple,
                () => const LegalScreen(kind: LegalKind.lgpd),
              ),
            ],
          ),
        ];

    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final bundles = store.bundles;
        final professionals = bundles.fold<int>(
          0,
          (s, b) => s + b.patient.professionalsCount,
        );
        final myObservations = bundles.fold<int>(
          0,
          (s, b) =>
              s + b.observations.where((o) => o.authorId == user.id).length,
        );
        final myConfirmations = bundles.fold<int>(
          0,
          (s, b) =>
              s +
              b.administrations
                  .where(
                    (a) =>
                        a.recordedById == user.id && a.status == 'administered',
                  )
                  .length,
        );
        final stats = [
          ('Pacientes', bundles.length),
          if (responsible)
            ('Profissionais', professionals)
          else
            ('Confirmações', myConfirmations),
          ('Obs. registradas', myObservations),
        ];
        return Scaffold(
          backgroundColor: AppColors.slate50,
          body: ListView(
            padding: EdgeInsets.zero,
            children: [
              GradientHeader(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                child: Center(
                  child: Column(
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Avatar(
                            initials: initials(user.name),
                            color: Colors.white.withValues(alpha: .25),
                            size: 76,
                          ),
                          Positioned(
                            right: -4,
                            bottom: -4,
                            child: InkWell(
                              onTap: () =>
                                  go(context, const ProfileEditScreen()),
                              child: Container(
                                width: 28,
                                height: 28,
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Color(0x22000000),
                                      blurRadius: 6,
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.edit_outlined,
                                  size: 13,
                                  color: AppColors.teal700,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        user.name,
                        style: display(size: 20, color: Colors.white),
                      ),
                      Text(
                        user.email,
                        style: body(size: 14, color: AppColors.teal100),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: .2),
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(
                          responsible
                              ? 'Responsável'
                              : 'Profissional${user.profession == null ? '' : ' · ${user.profession}'}',
                          style: body(
                            size: 12,
                            weight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        for (var i = 0; i < stats.length; i++) ...[
                          if (i > 0) const SizedBox(width: 12),
                          Expanded(
                            child: AppCard(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                children: [
                                  Text(
                                    '${stats[i].$2}',
                                    style: display(
                                      size: 20,
                                      weight: FontWeight.w900,
                                      color: AppColors.teal700,
                                    ),
                                  ),
                                  Text(
                                    stats[i].$1,
                                    textAlign: TextAlign.center,
                                    style: body(
                                      size: 10,
                                      color: AppColors.slate400,
                                      height: 1.2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    for (final (title, items) in sections) ...[
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.only(left: 4, bottom: 8),
                        child: Text(
                          title.toUpperCase(),
                          style: body(
                            size: 12,
                            weight: FontWeight.w700,
                            color: AppColors.slate400,
                            letterSpacing: .8,
                          ),
                        ),
                      ),
                      AppCard(
                        padding: EdgeInsets.zero,
                        child: Column(
                          children: [
                            for (var i = 0; i < items.length; i++) ...[
                              if (i > 0)
                                const Divider(
                                  height: 1,
                                  color: AppColors.slate100,
                                ),
                              _MenuRow(
                                icon: items[i].$1,
                                label: items[i].$2,
                                color: items[i].$3,
                                onTap: () => go(context, items[i].$4()),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    Material(
                      color: AppColors.red50,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: const BorderSide(color: AppColors.red200),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () async {
                          final ok = await confirmDialog(
                            context,
                            icon: Icons.logout,
                            title: 'Sair da conta?',
                            message:
                                'Você precisará entrar novamente para acessar os pacientes.',
                            confirmLabel: 'Sair',
                          );
                          if (ok) session.onLogout();
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.logout,
                                size: 20,
                                color: AppColors.red600,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Sair da conta',
                                style: display(
                                  size: 16,
                                  color: AppColors.red600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Vida Assistida Home Care · v1.0.0 · Dados protegidos conforme a LGPD',
                      textAlign: TextAlign.center,
                      style: body(size: 12, color: AppColors.slate300),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          IconTile(
            icon: icon,
            color: color,
            bg: color.withValues(alpha: .08),
            size: 36,
            radius: 12,
            iconSize: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: body(
                size: 14,
                weight: FontWeight.w500,
                color: AppColors.slate700,
              ),
            ),
          ),
          const Icon(Icons.chevron_right, size: 18, color: AppColors.slate300),
        ],
      ),
    ),
  );
}

// ─── Editar perfil ───────────────────────────────────────────────────────────
class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  late final TextEditingController _name;
  late final TextEditingController _email;
  late final TextEditingController _phone;
  late final TextEditingController _cpf;
  late final TextEditingController _profession;
  late final TextEditingController _council;
  bool _saving = false;
  String _error = '';
  bool _ready = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_ready) return;
    final user = Session.of(context).user;
    final cpf = user.cpf ?? '';
    _name = TextEditingController(text: user.name);
    _email = TextEditingController(text: user.email);
    _phone = TextEditingController(text: user.phone ?? '');
    _cpf = TextEditingController(
      text: cpf.length == 11
          ? '${cpf.substring(0, 3)}.${cpf.substring(3, 6)}.${cpf.substring(6, 9)}-${cpf.substring(9)}'
          : 'Não informado',
    );
    _profession = TextEditingController(text: user.profession ?? '');
    _council = TextEditingController(text: user.professionalCouncil ?? '');
    _ready = true;
  }

  @override
  void dispose() {
    for (final c in [_name, _email, _phone, _cpf, _profession, _council]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final session = Session.of(context);
    setState(() {
      _saving = true;
      _error = '';
    });
    try {
      final updated = await session.api.updateProfile({
        'name': _name.text.trim(),
        'email': _email.text.trim(),
        'phone': _phone.text.trim(),
        if (session.professional) ...{
          'profession': _profession.text.trim(),
          'professionalCouncil': _council.text.trim(),
        },
      });
      session.onUserUpdated(updated);
      if (!mounted) return;
      showToast(context, 'Dados atualizados com sucesso!');
      await Future<void>.delayed(const Duration(milliseconds: 900));
      if (mounted) Navigator.pop(context);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = Session.of(context);
    return AppScreen(
      header: GradientHeader(
        onBack: () => Navigator.pop(context),
        child: const HeaderTitle('Editar perfil'),
      ),
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      spacing: 16,
      children: [
        Column(
          children: [
            Avatar(initials: initials(session.user.name), size: 72),
            const SizedBox(height: 8),
            Text(
              'Foto de perfil',
              style: body(size: 12, color: AppColors.slate400),
            ),
          ],
        ),
        if (_error.isNotEmpty) ErrorBox(_error),
        AppInput(label: 'Nome completo', controller: _name),
        AppInput(
          label: 'E-mail',
          controller: _email,
          keyboardType: TextInputType.emailAddress,
        ),
        AppInput(
          label: 'Telefone',
          controller: _phone,
          keyboardType: TextInputType.phone,
        ),
        AppInput(
          label: 'CPF',
          controller: _cpf,
          readOnly: true,
          helper: 'O CPF não pode ser alterado.',
        ),
        if (session.professional) ...[
          AppInput(label: 'Profissão', controller: _profession),
          AppInput(label: 'Conselho profissional', controller: _council),
        ],
        const SizedBox(height: 4),
        PrimaryButton(
          label: 'Salvar alterações',
          loading: _saving,
          onPressed: _save,
        ),
        TextLinkButton(
          label: 'Cancelar',
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }
}

// ─── Segurança ───────────────────────────────────────────────────────────────
class SecurityScreen extends StatefulWidget {
  const SecurityScreen({super.key});

  @override
  State<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends State<SecurityScreen> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _show = false;
  bool _saving = false;
  String _error = '';
  Future<List<TrustedDevice>>? _devices;
  String? _thisDevice;

  @override
  void initState() {
    super.initState();
    for (final c in [_current, _next, _confirm]) {
      c.addListener(() => setState(() {}));
    }
    DeviceIdentity().existingId().then((id) {
      if (mounted) setState(() => _thisDevice = id);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _devices ??= Session.of(context).api.devices();
  }

  Future<void> _revoke(TrustedDevice device) async {
    final current = device.deviceId == _thisDevice;
    final ok = await confirmDialog(
      context,
      icon: Icons.phonelink_erase_outlined,
      title: 'Revogar aparelho?',
      message: current
          ? 'Este é o aparelho que você está usando. No próximo acesso será pedido um código enviado por e-mail.'
          : '${device.name} deixará de ser reconhecido e precisará do código no próximo acesso.',
      confirmLabel: 'Revogar',
    );
    if (!ok || !mounted) return;
    final api = Session.of(context).api;
    try {
      await api.revokeDevice(device.id);
      if (!mounted) return;
      setState(() => _devices = api.devices());
      showToast(context, 'Aparelho revogado.');
    } on ApiException catch (error) {
      if (mounted) showToast(context, error.message, error: true);
    }
  }

  @override
  void dispose() {
    for (final c in [_current, _next, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final api = Session.of(context).api;
    setState(() {
      _saving = true;
      _error = '';
    });
    try {
      await api.changePassword(_current.text, _next.text);
      if (!mounted) return;
      showToast(context, 'Senha alterada com sucesso.');
      Navigator.pop(context);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final valid =
        _current.text.length >= 8 &&
        _next.text.length >= 8 &&
        _next.text == _confirm.text;
    return AppScreen(
      header: GradientHeader(
        onBack: () => Navigator.pop(context),
        child: const HeaderTitle(
          'Segurança',
          subtitle: 'Senha e aparelhos reconhecidos',
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      spacing: 16,
      children: [
        const InfoBanner(
          icon: Icons.shield_outlined,
          text:
              'Use uma senha com pelo menos 8 caracteres e não a compartilhe. Todas as ações no aplicativo ficam associadas à sua conta.',
        ),
        if (_error.isNotEmpty) ErrorBox(_error),
        AppInput(
          label: 'Senha atual',
          controller: _current,
          obscure: !_show,
          suffix: IconButton(
            onPressed: () => setState(() => _show = !_show),
            icon: Icon(
              _show ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              size: 18,
              color: AppColors.slate400,
            ),
          ),
        ),
        AppInput(
          label: 'Nova senha',
          controller: _next,
          obscure: !_show,
          hint: 'Mínimo 8 caracteres',
          error: _next.text.isNotEmpty && _next.text.length < 8
              ? 'Use pelo menos 8 caracteres.'
              : null,
        ),
        AppInput(
          label: 'Confirmar nova senha',
          controller: _confirm,
          obscure: !_show,
          error: _confirm.text.isNotEmpty && _confirm.text != _next.text
              ? 'As senhas não coincidem.'
              : null,
        ),
        PrimaryButton(
          label: 'Alterar senha',
          loading: _saving,
          onPressed: valid ? _save : null,
        ),
        const SizedBox(height: 8),
        const SectionHeader(title: 'Aparelhos reconhecidos'),
        const InfoBanner(
          tone: Tone.slate,
          bordered: false,
          icon: Icons.phone_android_outlined,
          text:
              'Verificação em duas etapas ativa: em aparelhos que não estão nesta lista, o acesso exige um código enviado ao seu e-mail.',
        ),
        FutureBuilder<List<TrustedDevice>>(
          future: _devices,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const LoadingView();
            }
            if (snapshot.hasError) {
              return ErrorView(error: snapshot.error);
            }
            final devices = snapshot.data ?? const <TrustedDevice>[];
            if (devices.isEmpty) {
              return Text(
                'Nenhum aparelho reconhecido.',
                style: body(size: 13, color: AppColors.slate400),
              );
            }
            return Column(
              children: [
                for (final device in devices) ...[
                  AppCard(
                    child: Row(
                      children: [
                        IconTile(
                          icon:
                              device.name.contains('Computador') ||
                                  device.name == 'Navegador'
                              ? Icons.computer_outlined
                              : Icons.phone_android_outlined,
                          color: AppColors.teal700,
                          bg: AppColors.teal50,
                          size: 40,
                          radius: 12,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      device.name,
                                      style: body(
                                        size: 14,
                                        weight: FontWeight.w600,
                                        color: AppColors.slate800,
                                      ),
                                    ),
                                  ),
                                  if (device.deviceId == _thisDevice) ...[
                                    const SizedBox(width: 8),
                                    const Pill(
                                      'Este aparelho',
                                      bg: AppColors.teal50,
                                      fg: AppColors.teal700,
                                      size: 10,
                                    ),
                                  ],
                                ],
                              ),
                              Text(
                                device.lastUsedAt == null
                                    ? 'Reconhecido em ${ddmmyyyy(device.createdAt)}'
                                    : 'Último acesso: ${relativeDateTime(device.lastUsedAt!)}',
                                style: body(
                                  size: 12,
                                  color: AppColors.slate400,
                                ),
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: () => _revoke(device),
                          child: Text(
                            'Revogar',
                            style: body(
                              size: 12,
                              weight: FontWeight.w600,
                              color: AppColors.red600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

// ─── Preferências de notificação ─────────────────────────────────────────────
class NotificationPrefsScreen extends StatelessWidget {
  const NotificationPrefsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = Session.of(context).settings;
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) => AppScreen(
        header: GradientHeader(
          onBack: () => Navigator.pop(context),
          child: const HeaderTitle(
            'Notificações',
            subtitle: 'Escolha o que deseja receber',
          ),
        ),
        children: [
          AppCard(
            child: Column(
              children: [
                for (final (key, title, text, value) in [
                  (
                    'notifyMedications',
                    'Medicamentos',
                    'Horários próximos, atrasos e não administrações',
                    settings.notifyMedications,
                  ),
                  (
                    'notifyObservations',
                    'Observações e intercorrências',
                    'Novos registros da equipe de cuidado',
                    settings.notifyObservations,
                  ),
                  (
                    'notifyAlerts',
                    'Acionamentos',
                    'Solicitações de ajuda e confirmações de leitura',
                    settings.notifyAlerts,
                  ),
                ]) ...[
                  _ToggleRow(
                    title: title,
                    text: text,
                    value: value,
                    onChanged: (v) => settings.setNotify(key, v),
                  ),
                  const SizedBox(height: 16),
                ],
              ],
            ),
          ),
          const InfoBanner(
            tone: Tone.slate,
            bordered: false,
            icon: Icons.lock_outline,
            text:
                'Por privacidade, as notificações não exibem informações médicas detalhadas na tela bloqueada.',
          ),
        ],
      ),
    );
  }
}

// ─── Acessibilidade ──────────────────────────────────────────────────────────
class AccessibilityScreen extends StatelessWidget {
  const AccessibilityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = Session.of(context).settings;
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) => AppScreen(
        header: GradientHeader(
          onBack: () => Navigator.pop(context),
          child: const HeaderTitle(
            'Acessibilidade',
            subtitle: 'Ajuste a leitura do aplicativo',
          ),
        ),
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Tamanho do texto', style: display(size: 14)),
                const SizedBox(height: 12),
                SegmentChoice(
                  options: const [
                    ('1.0', 'Padrão', AppColors.teal700, AppColors.teal50),
                    ('1.15', 'Grande', AppColors.teal700, AppColors.teal50),
                    (
                      '1.3',
                      'Muito grande',
                      AppColors.teal700,
                      AppColors.teal50,
                    ),
                  ],
                  selected: settings.textScale.toString(),
                  onChanged: (value) =>
                      settings.setTextScale(double.parse(value)),
                ),
                const SizedBox(height: 12),
                Text(
                  'Exemplo: Losartana 50 mg · 08:00',
                  style: body(size: 14, color: AppColors.slate600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.title,
    required this.text,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String text;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: body(
                size: 14,
                weight: FontWeight.w600,
                color: AppColors.slate700,
              ),
            ),
            Text(text, style: body(size: 12, color: AppColors.slate400)),
          ],
        ),
      ),
      const SizedBox(width: 12),
      AppSwitch(value: value, onChanged: onChanged),
    ],
  );
}

// ─── Termos, privacidade e LGPD ──────────────────────────────────────────────
enum LegalKind { terms, privacy, lgpd }

class LegalScreen extends StatelessWidget {
  const LegalScreen({super.key, required this.kind});
  final LegalKind kind;

  @override
  Widget build(BuildContext context) {
    final (title, sections) = switch (kind) {
      LegalKind.terms => (
        'Termos de uso',
        const [
          (
            'Finalidade',
            'O Vida Assistida é uma ferramenta de apoio à organização e à comunicação do cuidado domiciliar. Ele não realiza diagnóstico, não substitui orientação médica e não é um serviço de emergência.',
          ),
          (
            'Responsabilidades',
            'O responsável cadastra o paciente, convida profissionais e define permissões. Cada profissional responde pelos registros feitos com sua conta.',
          ),
          (
            'Uso adequado',
            'Cadastre somente informações orientadas por profissional habilitado. Em situações graves, procure imediatamente o SAMU (192) ou os Bombeiros (193).',
          ),
        ],
      ),
      LegalKind.privacy => (
        'Política de privacidade',
        const [
          (
            'Dados coletados',
            'Dados de cadastro (nome, e-mail, CPF e telefone) e informações de cuidado registradas pela equipe: medicamentos, atividades, observações e acionamentos.',
          ),
          (
            'Acesso',
            'Cada pessoa vê apenas os pacientes aos quais está vinculada e somente as informações permitidas pelo responsável. Códigos de convite expiram e podem ser revogados.',
          ),
          (
            'Rastreabilidade',
            'Ações importantes ficam registradas no histórico do paciente com data, hora e autor.',
          ),
        ],
      ),
      LegalKind.lgpd => (
        'Tratamento de dados (LGPD)',
        const [
          (
            'Base legal',
            'Os dados de saúde são tratados para a tutela da saúde do paciente, com consentimento do responsável, conforme a Lei nº 13.709/2018 (LGPD).',
          ),
          (
            'Seus direitos',
            'Você pode solicitar acesso, correção ou exclusão dos seus dados e revogar o consentimento a qualquer momento.',
          ),
          (
            'Segurança',
            'Senhas são armazenadas com hash, o acesso exige autenticação e as permissões são verificadas pelo servidor em cada operação.',
          ),
        ],
      ),
    };
    return AppScreen(
      header: GradientHeader(
        onBack: () => Navigator.pop(context),
        child: HeaderTitle(title),
      ),
      children: [
        for (final (heading, text) in sections)
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(heading, style: display(size: 14)),
                const SizedBox(height: 6),
                Text(
                  text,
                  style: body(size: 14, color: AppColors.slate600, height: 1.5),
                ),
              ],
            ),
          ),
        Text(
          'Conteúdo de demonstração acadêmica.',
          textAlign: TextAlign.center,
          style: body(size: 12, color: AppColors.slate400),
        ),
      ],
    );
  }
}
