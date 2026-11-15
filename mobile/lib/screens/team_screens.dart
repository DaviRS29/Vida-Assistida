import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/app_theme.dart';
import '../core/care_data.dart';
import '../core/session.dart';
import '../models.dart';
import '../widgets/ui.dart';

const _permissionLabels = {
  'canViewMedications': (
    'Consultar medicamentos',
    'Ver lista de medicamentos e horários',
    'Consultar med.',
  ),
  'canRecordMedications': (
    'Confirmar administração',
    'Marcar medicamentos como administrados',
    'Confirmar med.',
  ),
  'canManageCarePlan': (
    'Criar atividades clínicas',
    'Adicionar orientações ao plano de cuidados',
    'Criar atividades',
  ),
  'canRecordActivities': (
    'Registrar atividades realizadas',
    'Informar conclusão, dor e dificuldades',
    'Registrar cuidados',
  ),
  'canRecordObservations': (
    'Criar observações',
    'Registrar observações e intercorrências',
    'Observações',
  ),
  'canViewHistory': (
    'Visualizar histórico',
    'Acessar o histórico completo',
    'Histórico',
  ),
  'canEditPatient': (
    'Editar dados do paciente',
    'Alterar dados cadastrais do paciente',
    'Editar dados',
  ),
};

String inviteLink(String code) => 'vidaassistida.app/c/${code.toLowerCase()}';

String inviteMessage(Patient patient) =>
    'Você foi convidado(a) para a equipe de cuidado de ${patient.firstName} no Vida Assistida. '
    'Use o código ${patient.joinCode} (válido até ${patient.inviteExpiresAt == null ? '—' : ddmmyyyy(patient.inviteExpiresAt!)}) '
    'ou acesse ${inviteLink(patient.joinCode)}.';

/// Cartão do código de convite com copiar/compartilhar.
class InviteCodeCard extends StatelessWidget {
  const InviteCodeCard({
    super.key,
    required this.patient,
    this.large = false,
    this.showRotate = false,
  });

  final Patient patient;
  final bool large;
  final bool showRotate;

  @override
  Widget build(BuildContext context) {
    final expires = patient.inviteExpiresAt;
    final expired = expires != null && expires.isBefore(DateTime.now());
    final copy = IconTile(
      icon: Icons.copy_outlined,
      color: AppColors.teal700,
      bg: AppColors.teal100,
      size: 36,
      radius: 12,
      iconSize: 16,
    );
    final share = IconTile(
      icon: Icons.share_outlined,
      color: AppColors.teal700,
      bg: AppColors.teal100,
      size: 36,
      radius: 12,
      iconSize: 16,
    );
    final actions = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => copyText(context, patient.joinCode, 'Código copiado!'),
          child: copy,
        ),
        const SizedBox(width: 8),
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => copyText(
            context,
            inviteMessage(patient),
            'Mensagem de convite copiada para compartilhar.',
          ),
          child: share,
        ),
      ],
    );
    final validity = Text(
      expires == null
          ? 'Prazo não informado'
          : expired
          ? 'Expirou em ${ddmmyyyy(expires)}'
          : 'Válido até ${ddmmyyyy(expires)}',
      style: body(
        size: 12,
        color: expired ? AppColors.red600 : AppColors.slate400,
      ),
    );

    if (large) {
      return AppCard(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Código de convite gerado',
              style: body(
                size: 12,
                weight: FontWeight.w500,
                color: AppColors.slate500,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: FittedBox(
                    alignment: Alignment.centerLeft,
                    fit: BoxFit.scaleDown,
                    child: Text(
                      patient.joinCode,
                      style: display(
                        size: 34,
                        weight: FontWeight.w900,
                        color: AppColors.teal700,
                        letterSpacing: 5,
                      ),
                    ),
                  ),
                ),
                actions,
              ],
            ),
            const SizedBox(height: 8),
            validity,
          ],
        ),
      );
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Código de convite', style: display(size: 14)),
              ),
              expired
                  ? const Pill(
                      'Expirado',
                      bg: AppColors.red100,
                      fg: AppColors.red700,
                    )
                  : const Pill(
                      'Ativo',
                      bg: AppColors.green100,
                      fg: AppColors.green700,
                    ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.slate50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        patient.joinCode,
                        style: display(
                          size: 24,
                          weight: FontWeight.w900,
                          color: AppColors.teal700,
                          letterSpacing: 3.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      validity,
                    ],
                  ),
                ),
                actions,
              ],
            ),
          ),
          if (showRotate) ...[
            const SizedBox(height: 8),
            InkWell(
              onTap: () => rotateInvite(context, patient),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  'Cancelar e gerar novo código',
                  textAlign: TextAlign.center,
                  style: body(
                    size: 12,
                    weight: FontWeight.w500,
                    color: AppColors.red500,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

Future<void> rotateInvite(BuildContext context, Patient patient) async {
  final ok = await confirmDialog(
    context,
    icon: Icons.refresh,
    title: 'Gerar novo código?',
    message:
        'O código atual (${patient.joinCode}) deixará de funcionar imediatamente. Profissionais já vinculados não perdem o acesso.',
    confirmLabel: 'Cancelar e gerar novo',
  );
  if (!ok || !context.mounted) return;
  final session = Session.of(context);
  try {
    await session.api.rotateInviteCode(patient.id);
    await session.store.refreshPatient(patient.id);
    if (context.mounted) {
      showToast(context, 'Novo código gerado. O anterior foi cancelado.');
    }
  } on ApiException catch (error) {
    if (context.mounted) showToast(context, error.message, error: true);
  }
}

// ─── Convidar profissional ───────────────────────────────────────────────────
class InviteScreen extends StatefulWidget {
  const InviteScreen({super.key, required this.patientId});
  final String patientId;

  @override
  State<InviteScreen> createState() => _InviteScreenState();
}

class _InviteScreenState extends State<InviteScreen> {
  bool _copied = false;

  @override
  Widget build(BuildContext context) {
    final store = Session.of(context).store;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final patient = store.bundleFor(widget.patientId)?.patient;
        if (patient == null) {
          return AppScreen(
            header: GradientHeader(
              onBack: () => Navigator.pop(context),
              child: const HeaderTitle('Convidar profissional'),
            ),
            children: const [LoadingView()],
          );
        }
        final expires = patient.inviteExpiresAt;
        return AppScreen(
          header: GradientHeader(
            onBack: () => Navigator.pop(context),
            child: HeaderTitle('Convidar profissional', subtitle: patient.name),
          ),
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
          spacing: 20,
          children: [
            Column(
              children: [
                const IconTile(
                  icon: Icons.person_add_alt_1_outlined,
                  color: AppColors.teal700,
                  bg: AppColors.teal100,
                  size: 64,
                  radius: 16,
                  iconSize: 32,
                ),
                const SizedBox(height: 8),
                Text(
                  'Compartilhe o código ou link com o profissional de saúde',
                  textAlign: TextAlign.center,
                  style: body(
                    size: 16,
                    weight: FontWeight.w600,
                    color: AppColors.slate700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Ao aceitar o convite, o profissional terá acesso somente às informações que você definir.',
                  textAlign: TextAlign.center,
                  style: body(size: 12, color: AppColors.slate400),
                ),
              ],
            ),
            AppCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Código de convite',
                    style: body(
                      size: 12,
                      weight: FontWeight.w500,
                      color: AppColors.slate400,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        patient.joinCode,
                        style: display(
                          size: 44,
                          weight: FontWeight.w900,
                          color: AppColors.teal700,
                          letterSpacing: 8,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      expires == null ? '' : 'Válido até ${ddmmyyyy(expires)}',
                      style: body(size: 12, color: AppColors.slate400),
                    ),
                  ),
                ],
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: PrimaryButton(
                    label: _copied ? 'Copiado!' : 'Copiar código',
                    icon: _copied ? Icons.check : Icons.copy_outlined,
                    color: _copied ? AppColors.green600 : AppColors.teal700,
                    fontSize: 14,
                    shadow: false,
                    onPressed: () async {
                      await copyText(
                        context,
                        patient.joinCode,
                        'Código copiado para a área de transferência!',
                      );
                      if (!mounted) return;
                      setState(() => _copied = true);
                      Future.delayed(const Duration(seconds: 2), () {
                        if (mounted) setState(() => _copied = false);
                      });
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlineAppButton(
                    label: 'Compartilhar',
                    icon: Icons.share_outlined,
                    height: 52,
                    onPressed: () => copyText(
                      context,
                      inviteMessage(patient),
                      'Mensagem de convite copiada para compartilhar.',
                    ),
                  ),
                ),
              ],
            ),
            const OrDivider('ou via link'),
            AppCard(
              onTap: () => copyText(
                context,
                inviteLink(patient.joinCode),
                'Link copiado!',
              ),
              child: SizedBox(
                width: double.infinity,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Link de convite',
                      style: body(size: 12, color: AppColors.slate400),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      inviteLink(patient.joinCode),
                      style: body(
                        size: 14,
                        color: AppColors.slate700,
                      ).copyWith(fontFamily: 'monospace'),
                    ),
                  ],
                ),
              ),
            ),
            InfoBanner(
              tone: Tone.slate,
              bordered: false,
              icon: Icons.schedule,
              title: 'Prazo de validade',
              text:
                  'Este convite expira em ${expires == null ? '—' : ddmmyyyy(expires)}. Você pode cancelar e gerar um novo código a qualquer momento.',
            ),
            TextLinkButton(
              label: 'Cancelar convite e gerar novo código',
              color: AppColors.red500,
              onPressed: () => rotateInvite(context, patient),
            ),
          ],
        );
      },
    );
  }
}

// ─── Equipe e permissões ─────────────────────────────────────────────────────
class TeamScreen extends StatefulWidget {
  const TeamScreen({super.key, required this.patientId});
  final String patientId;

  @override
  State<TeamScreen> createState() => _TeamScreenState();
}

class _TeamScreenState extends State<TeamScreen> {
  late Future<List<TeamMember>> _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future = Session.of(context).api.members(widget.patientId);
  }

  Future<void> _reload() async {
    setState(() => _future = Session.of(context).api.members(widget.patientId));
    await _future;
    if (mounted) {
      await Session.of(context).store.refreshPatient(widget.patientId);
    }
  }

  Future<void> _update(
    TeamMember member,
    Map<String, bool> fields,
    String message,
  ) async {
    final api = Session.of(context).api;
    try {
      await api.updateMember(widget.patientId, member.id, fields);
      await _reload();
      if (mounted) showToast(context, message);
    } on ApiException catch (error) {
      if (mounted) showToast(context, error.message, error: true);
    }
  }

  Future<void> _remove(TeamMember member) async {
    final ok = await confirmDialog(
      context,
      icon: Icons.delete_outline,
      title: 'Remover profissional?',
      message:
          'O acesso ao espaço deste paciente será removido imediatamente. Esta ação é registrada no histórico.',
      confirmLabel: 'Confirmar remoção',
    );
    if (!ok || !mounted) return;
    final api = Session.of(context).api;
    try {
      await api.removeMember(widget.patientId, member.id);
      await _reload();
      if (mounted) showToast(context, 'Profissional removido.');
    } on ApiException catch (error) {
      if (mounted) showToast(context, error.message, error: true);
    }
  }

  Future<void> _suspend(TeamMember member) async {
    if (member.active) {
      final ok = await confirmDialog(
        context,
        icon: Icons.pause_circle_outline,
        title: 'Suspender acesso?',
        message:
            '${member.name} deixará de ver o paciente até que você reative o acesso.',
        confirmLabel: 'Suspender acesso',
        color: AppColors.orange600,
        iconBg: AppColors.orange100,
      );
      if (!ok) return;
    }
    await _update(member, {
      'active': !member.active,
    }, member.active ? 'Acesso suspenso.' : 'Acesso reativado.');
  }

  Future<void> _permissions(TeamMember member) async {
    final values = Map<String, bool>.of(member.permissions.toJson());
    final save = await showAppSheet<bool>(
      context,
      builder: (sheet) => StatefulBuilder(
        builder: (sheet, setSheet) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Avatar(initials: initials(member.name), size: 44),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(member.name, style: display(size: 16)),
                      Text(
                        member.profession ?? 'Profissional',
                        style: body(size: 14, color: AppColors.slate400),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              'PERMISSÕES DE ACESSO',
              style: body(
                size: 12,
                weight: FontWeight.w700,
                color: AppColors.slate400,
                letterSpacing: .8,
              ),
            ),
            const SizedBox(height: 12),
            for (final key in PatientPermissions.keys) ...[
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _permissionLabels[key]!.$1,
                          style: body(
                            size: 14,
                            weight: FontWeight.w600,
                            color: AppColors.slate700,
                          ),
                        ),
                        Text(
                          _permissionLabels[key]!.$2,
                          style: body(size: 12, color: AppColors.slate400),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  AppSwitch(
                    value: values[key] ?? false,
                    onChanged: (value) => setSheet(() => values[key] = value),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
            const SizedBox(height: 8),
            PrimaryButton(
              label: 'Salvar permissões',
              shadow: false,
              onPressed: () => Navigator.pop(sheet, true),
            ),
          ],
        ),
      ),
    );
    if (save == true) await _update(member, values, 'Permissões atualizadas.');
  }

  @override
  Widget build(BuildContext context) {
    final patient = Session.of(
      context,
    ).store.bundleFor(widget.patientId)?.patient;
    return FutureBuilder<List<TeamMember>>(
      future: _future,
      builder: (context, snapshot) {
        final members = snapshot.data ?? const <TeamMember>[];
        final active = members.where((m) => m.active).length;
        return AppScreen(
          onRefresh: _reload,
          header: GradientHeader(
            onBack: () => Navigator.pop(context),
            child: HeaderTitle(
              'Equipe',
              subtitle:
                  '${patient?.name ?? ''} · $active profissiona${active == 1 ? 'l' : 'is'}',
              trailing: HeaderIconButton(
                icon: Icons.person_add_alt_1_outlined,
                tooltip: 'Convidar profissional',
                onTap: () =>
                    go(context, InviteScreen(patientId: widget.patientId)),
              ),
            ),
          ),
          children: [
            if (snapshot.connectionState == ConnectionState.waiting)
              const LoadingView()
            else if (snapshot.hasError)
              ErrorView(error: snapshot.error, onRetry: _reload)
            else if (members.isEmpty)
              const EmptyState(
                icon: Icons.groups_outlined,
                title: 'Nenhum profissional vinculado',
                subtitle:
                    'Compartilhe o código de convite para montar a equipe.',
              )
            else
              for (final member in members)
                _MemberCard(
                  member: member,
                  onPermissions: () => _permissions(member),
                  onSuspend: () => _suspend(member),
                  onRemove: () => _remove(member),
                ),
            DashedButton(
              icon: Icons.person_add_alt_1_outlined,
              label: 'Convidar profissional',
              tone: Tone.slate,
              onTap: () =>
                  go(context, InviteScreen(patientId: widget.patientId)),
            ),
          ],
        );
      },
    );
  }
}

class _MemberCard extends StatelessWidget {
  const _MemberCard({
    required this.member,
    required this.onPermissions,
    required this.onSuspend,
    required this.onRemove,
  });

  final TeamMember member;
  final VoidCallback onPermissions;
  final VoidCallback onSuspend;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final enabled = PatientPermissions.keys
        .where((key) => member.permissions[key])
        .take(3)
        .toList();
    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Avatar(
            initials: initials(member.name),
            color: member.active ? AppColors.teal600 : const Color(0xFF9E9E9E),
            size: 48,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(member.name, style: display(size: 16)),
                    ),
                    const SizedBox(width: 8),
                    StatusBadge(status: member.active ? 'ativo' : 'suspenso'),
                  ],
                ),
                Text(
                  member.profession ?? 'Profissional',
                  style: body(size: 12, color: AppColors.slate500),
                ),
                if (member.professionalCouncil?.isNotEmpty == true)
                  Text(
                    member.professionalCouncil!,
                    style: body(size: 12, color: AppColors.slate400),
                  ),
                const SizedBox(height: 4),
                Text(
                  member.lastAccessAt == null
                      ? 'Vinculado em ${ddmmyyyy(member.createdAt)} · sem acesso registrado'
                      : 'Último acesso: ${relativeDateTime(member.lastAccessAt!)}',
                  style: body(size: 12, color: AppColors.slate300),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    for (final key in enabled)
                      Pill(
                        _permissionLabels[key]!.$3,
                        bg: AppColors.teal50,
                        fg: AppColors.teal700,
                        size: 10,
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _SmallAction(
                      icon: Icons.settings_outlined,
                      label: 'Permissões',
                      bg: AppColors.teal50,
                      fg: AppColors.teal700,
                      onTap: onPermissions,
                    ),
                    member.active
                        ? _SmallAction(
                            label: 'Suspender',
                            bg: AppColors.orange50,
                            fg: AppColors.orange700,
                            onTap: onSuspend,
                          )
                        : _SmallAction(
                            label: 'Reativar',
                            bg: AppColors.green50,
                            fg: AppColors.green700,
                            onTap: onSuspend,
                          ),
                    _SmallAction(
                      icon: Icons.delete_outline,
                      label: 'Remover',
                      bg: AppColors.red50,
                      fg: AppColors.red700,
                      onTap: onRemove,
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

class _SmallAction extends StatelessWidget {
  const _SmallAction({
    required this.label,
    required this.bg,
    required this.fg,
    required this.onTap,
    this.icon,
  });

  final String label;
  final Color bg;
  final Color fg;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Material(
    color: bg,
    borderRadius: BorderRadius.circular(8),
    child: InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 13, color: fg),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: body(size: 12, weight: FontWeight.w600, color: fg),
            ),
          ],
        ),
      ),
    ),
  );
}
