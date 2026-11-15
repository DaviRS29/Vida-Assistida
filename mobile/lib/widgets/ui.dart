import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_theme.dart';
import '../core/care_data.dart';
import '../core/session.dart';

// ─── Utilitários ─────────────────────────────────────────────────────────────
Future<T?> go<T>(BuildContext context, Widget screen) =>
    Navigator.of(context).push<T>(MaterialPageRoute(builder: (_) => screen));

const _patientPalette = [
  Color(0xFF1565C0),
  Color(0xFF00695C),
  Color(0xFF6A1B9A),
  Color(0xFFE65100),
  Color(0xFF2E7D32),
  Color(0xFFAD1457),
];

Color colorFor(String seed) =>
    _patientPalette[seed.codeUnits.fold(0, (a, b) => a + b) %
        _patientPalette.length];

bool isProfessional(BuildContext context) {
  final session = context.dependOnInheritedWidgetOfExactType<Session>();
  return session?.professional ?? false;
}

LinearGradient headerGradient(BuildContext context) =>
    isProfessional(context) ? professionalHeaderGradient : appHeaderGradient;

double headerTop(BuildContext context) =>
    math.max(48, MediaQuery.paddingOf(context).top + 16);

void showToast(BuildContext context, String message, {bool error = false}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        duration: const Duration(milliseconds: 2400),
        elevation: 12,
        backgroundColor: AppColors.slate800,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 96),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Row(
          children: [
            Icon(
              error ? Icons.error_outline : Icons.check,
              size: 18,
              color: error ? AppColors.red400 : AppColors.green400,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: body(
                  size: 14,
                  weight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
}

Future<void> copyText(BuildContext context, String text, String message) async {
  await Clipboard.setData(ClipboardData(text: text));
  if (context.mounted) showToast(context, message);
}

Future<T?> showAppSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
}) => showModalBottomSheet<T>(
  context: context,
  isScrollControlled: true,
  backgroundColor: Colors.white,
  barrierColor: Colors.black.withValues(alpha: .4),
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
  ),
  builder: (context) => ConstrainedBox(
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * .88,
    ),
    child: SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        24,
        12,
        24,
        24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: AppColors.slate200,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          builder(context),
        ],
      ),
    ),
  ),
);

Future<bool> confirmDialog(
  BuildContext context, {
  required IconData icon,
  required String title,
  required String message,
  required String confirmLabel,
  Color color = AppColors.red600,
  Color iconBg = AppColors.red100,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: .4),
    builder: (dialogContext) => Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: IconTile(icon: icon, color: color, bg: iconBg, size: 56),
            ),
            const SizedBox(height: 16),
            Text(title, textAlign: TextAlign.center, style: display(size: 20)),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: body(size: 14, color: AppColors.slate500),
            ),
            const SizedBox(height: 20),
            PrimaryButton(
              label: confirmLabel,
              color: color,
              height: 48,
              onPressed: () => Navigator.pop(dialogContext, true),
            ),
            const SizedBox(height: 4),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(
                'Cancelar',
                style: body(
                  size: 14,
                  weight: FontWeight.w600,
                  color: AppColors.slate500,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  return result ?? false;
}

// ─── Cabeçalho ───────────────────────────────────────────────────────────────
class GradientHeader extends StatelessWidget {
  const GradientHeader({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(20, 0, 20, 20),
    this.gradient,
    this.onBack,
  });

  final Widget child;
  final EdgeInsets padding;
  final Gradient? gradient;

  /// Exibe a seta de voltar acima do conteúdo.
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(gradient: gradient ?? headerGradient(context)),
      padding: padding.copyWith(top: headerTop(context)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (onBack != null) ...[
            HeaderBack(onTap: onBack!),
            const SizedBox(height: 12),
          ],
          child,
        ],
      ),
    );
  }
}

class HeaderBack extends StatelessWidget {
  const HeaderBack({super.key, required this.onTap, this.color});
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Voltar',
    child: InkResponse(
      onTap: onTap,
      radius: 22,
      child: Icon(
        Icons.arrow_back,
        size: 22,
        color: color ?? AppColors.teal100,
      ),
    ),
  );
}

/// Título e subtítulo padrão dos cabeçalhos.
class HeaderTitle extends StatelessWidget {
  const HeaderTitle(
    this.title, {
    super.key,
    this.subtitle,
    this.overline,
    this.trailing,
    this.size = 24,
  });

  final String title;
  final String? subtitle;
  final String? overline;
  final Widget? trailing;
  final double size;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (overline != null)
              Text(
                overline!.toUpperCase(),
                style: body(
                  size: 12,
                  weight: FontWeight.w600,
                  color: AppColors.teal100,
                  letterSpacing: 1.4,
                ),
              ),
            Text(
              title,
              style: display(size: size, color: Colors.white, height: 1.2),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(subtitle!, style: body(size: 14, color: AppColors.teal100)),
            ],
          ],
        ),
      ),
      if (trailing != null) ...[const SizedBox(width: 12), trailing!],
    ],
  );
}

class HeaderIconButton extends StatelessWidget {
  const HeaderIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.badge = 0,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;
  final int badge;
  final String? tooltip;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip ?? '',
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        Material(
          color: Colors.white.withValues(alpha: .2),
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            child: SizedBox(
              width: 40,
              height: 40,
              child: Icon(icon, size: 20, color: Colors.white),
            ),
          ),
        ),
        if (badge > 0)
          Positioned(
            top: -4,
            right: -4,
            child: CountBadge(count: badge, color: AppColors.red500, size: 16),
          ),
      ],
    ),
  );
}

class CountBadge extends StatelessWidget {
  const CountBadge({
    super.key,
    required this.count,
    this.color = AppColors.red600,
    this.size = 20,
    this.border = false,
  });

  final int count;
  final Color color;
  final double size;
  final bool border;

  @override
  Widget build(BuildContext context) => Container(
    constraints: BoxConstraints(minWidth: size, minHeight: size),
    padding: const EdgeInsets.symmetric(horizontal: 3),
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(99),
      border: border ? Border.all(color: Colors.white, width: 2) : null,
    ),
    child: Text(
      count > 99 ? '99+' : '$count',
      style: body(size: 9, weight: FontWeight.w700, color: Colors.white),
    ),
  );
}

/// Métrica translúcida no cabeçalho do início.
class HeaderMetric extends StatelessWidget {
  const HeaderMetric({
    super.key,
    required this.value,
    required this.label,
    this.alert = false,
  });

  final int value;
  final String label;
  final bool alert;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .15),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            '$value',
            style: display(
              size: 24,
              weight: FontWeight.w900,
              color: alert ? const Color(0xFFFFCDD2) : Colors.white,
            ),
          ),
          Text(
            label,
            textAlign: TextAlign.center,
            style: body(size: 10, color: AppColors.teal100, height: 1.2),
          ),
        ],
      ),
    ),
  );
}

// ─── Estrutura de tela ───────────────────────────────────────────────────────
class AppScreen extends StatelessWidget {
  const AppScreen({
    super.key,
    required this.header,
    required this.children,
    this.belowHeader = const [],
    this.onRefresh,
    this.padding = const EdgeInsets.fromLTRB(16, 16, 16, 24),
    this.spacing = 12,
    this.background = AppColors.canvas,
  });

  final Widget header;
  final List<Widget> belowHeader;
  final List<Widget> children;
  final Future<void> Function()? onRefresh;
  final EdgeInsets padding;
  final double spacing;
  final Color background;

  @override
  Widget build(BuildContext context) {
    Widget list = ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: padding,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) SizedBox(height: spacing),
          children[i],
        ],
      ],
    );
    if (onRefresh != null) {
      list = RefreshIndicator(
        color: AppColors.teal700,
        onRefresh: onRefresh!,
        child: list,
      );
    }
    return Scaffold(
      backgroundColor: background,
      body: Column(
        children: [
          header,
          ...belowHeader,
          Expanded(child: list),
        ],
      ),
    );
  }
}

/// Barra branca com resumo numérico (Total, Adm., Pendentes…).
class SummaryBar extends StatelessWidget {
  const SummaryBar({super.key, required this.items, this.valueSize = 18});
  final List<(String, int, Color)> items;
  final double valueSize;

  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(bottom: BorderSide(color: AppColors.slate100)),
    ),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    child: Row(
      children: [
        for (final (label, value, color) in items)
          Expanded(
            child: Column(
              children: [
                Text(
                  '$value',
                  style: display(
                    size: valueSize,
                    weight: FontWeight.w900,
                    color: color,
                  ),
                ),
                Text(label, style: body(size: 10, color: AppColors.slate400)),
              ],
            ),
          ),
      ],
    ),
  );
}

/// Linha de chips de filtro (fundo branco com borda inferior).
class FilterBar extends StatelessWidget {
  const FilterBar({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
    this.secondary = false,
  });

  final List<(String, String)> options;
  final String selected;
  final ValueChanged<String> onChanged;

  /// Variante discreta (fundo slate-50, ativo slate-700).
  final bool secondary;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    decoration: BoxDecoration(
      color: secondary ? AppColors.slate50 : Colors.white,
      border: const Border(bottom: BorderSide(color: AppColors.slate100)),
    ),
    padding: EdgeInsets.symmetric(horizontal: 16, vertical: secondary ? 8 : 12),
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final (value, label) in options)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: AppChip(
                label: label,
                selected: value == selected,
                onTap: () => onChanged(value),
                activeColor: secondary ? AppColors.slate700 : AppColors.teal700,
                inactiveBg: secondary ? Colors.transparent : AppColors.slate100,
                inactiveFg: secondary ? AppColors.slate500 : AppColors.slate600,
                compact: secondary,
              ),
            ),
        ],
      ),
    ),
  );
}

class AppChip extends StatelessWidget {
  const AppChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.activeColor = AppColors.teal700,
    this.inactiveBg = AppColors.slate100,
    this.inactiveFg = AppColors.slate600,
    this.outlined = false,
    this.compact = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color activeColor;
  final Color inactiveBg;
  final Color inactiveFg;
  final bool outlined;
  final bool compact;

  @override
  Widget build(BuildContext context) => Material(
    color: selected ? activeColor : inactiveBg,
    shape: StadiumBorder(
      side: outlined && !selected
          ? const BorderSide(color: AppColors.slate200)
          : BorderSide.none,
    ),
    child: InkWell(
      customBorder: const StadiumBorder(),
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 12 : (outlined ? 12 : 16),
          vertical: compact ? 4 : 6,
        ),
        child: Text(
          label,
          style: body(
            size: 12,
            weight: FontWeight.w600,
            color: selected ? Colors.white : inactiveFg,
          ),
        ),
      ),
    ),
  );
}

// ─── Cartões e blocos ────────────────────────────────────────────────────────
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(16),
    this.accent,
    this.color = Colors.white,
    this.borderColor = AppColors.slate100,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;

  /// Borda esquerda destacada (ex.: item atrasado).
  final Color? accent;
  final Color color;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    final content = Padding(padding: padding, child: child);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 2,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: accent == null
                ? content
                : DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border(
                        left: BorderSide(color: accent!, width: 4),
                      ),
                    ),
                    child: content,
                  ),
          ),
        ),
      ),
    );
  }
}

class Avatar extends StatelessWidget {
  const Avatar({
    super.key,
    required this.initials,
    this.color = AppColors.teal600,
    this.size = 44,
  });

  final String initials;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(size / 3),
    ),
    child: Text(
      initials,
      style: display(
        size: size * .38,
        weight: FontWeight.w700,
        color: Colors.white,
      ),
    ),
  );
}

class IconTile extends StatelessWidget {
  const IconTile({
    super.key,
    required this.icon,
    required this.color,
    required this.bg,
    this.size = 40,
    this.radius,
    this.iconSize,
  });

  final IconData icon;
  final Color color;
  final Color bg;
  final double size;
  final double? radius;
  final double? iconSize;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(radius ?? size * .3),
    ),
    child: Icon(icon, color: color, size: iconSize ?? size * .5),
  );
}

class Pill extends StatelessWidget {
  const Pill(
    this.label, {
    super.key,
    required this.bg,
    required this.fg,
    this.size = 12,
    this.bold = false,
  });

  final String label;
  final Color bg;
  final Color fg;
  final double size;
  final bool bold;

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.symmetric(
      horizontal: bold ? 10 : 8,
      vertical: bold ? 4 : 2,
    ),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(99),
    ),
    child: Text(
      label,
      style: body(
        size: size,
        weight: bold ? FontWeight.w700 : FontWeight.w600,
        color: fg,
      ),
    ),
  );
}

class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.status});

  /// ativo | atencao | inativo | suspenso
  final String status;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, label) = switch (status) {
      'ativo' => (AppColors.statusGreenBg, AppColors.statusGreen, 'Ativo'),
      'atencao' => (
        AppColors.statusOrangeBg,
        AppColors.statusOrange,
        'Atenção',
      ),
      'suspenso' => (AppColors.statusRedBg, AppColors.statusRed, 'Suspenso'),
      _ => (AppColors.statusGreyBg, AppColors.statusGrey, 'Inativo'),
    };
    return Pill(label, bg: bg, fg: fg);
  }
}

class LevelBadge extends StatelessWidget {
  const LevelBadge({super.key, required this.level});

  /// information | attention | urgent (ou informativo/atencao/urgente)
  final String level;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, label) = switch (level) {
      'attention' || 'atencao' => (
        AppColors.statusOrangeBg,
        AppColors.statusOrange,
        'Atenção',
      ),
      'urgent' ||
      'urgente' => (AppColors.statusRedBg, AppColors.statusRed, 'Urgente'),
      _ => (AppColors.teal50, AppColors.teal600, 'Informativo'),
    };
    return Pill(label, bg: bg, fg: fg);
  }
}

class MedStatusBadge extends StatelessWidget {
  const MedStatusBadge({super.key, required this.status});
  final DoseStatus status;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, label) = switch (status) {
      DoseStatus.administrado => (
        AppColors.statusGreenBg,
        AppColors.statusGreen,
        'Administrado',
      ),
      DoseStatus.atrasado => (
        AppColors.statusRedBg,
        AppColors.statusRed,
        'Atrasado',
      ),
      DoseStatus.naoAdministrado => (
        AppColors.statusGreyBg,
        AppColors.statusGrey,
        'Não adm.',
      ),
      DoseStatus.pendente => (AppColors.teal50, AppColors.teal600, 'Pendente'),
    };
    return Pill(label, bg: bg, fg: fg);
  }
}

class ActivityStatusBadge extends StatelessWidget {
  const ActivityStatusBadge({super.key, required this.status});
  final ActivityStatus status;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, label) = switch (status) {
      ActivityStatus.concluida => (
        AppColors.green100,
        const Color(0xFF166534),
        'Concluída',
      ),
      ActivityStatus.pendente => (
        AppColors.blue100,
        AppColors.blue700,
        'Pendente',
      ),
      ActivityStatus.atrasada => (
        AppColors.red100,
        AppColors.red700,
        'Atrasada',
      ),
      ActivityStatus.parcial => (
        const Color(0xFFFEF3C7),
        AppColors.amber700,
        'Parcial',
      ),
      ActivityStatus.naoRealizada => (
        AppColors.slate100,
        AppColors.slate600,
        'Não realizada',
      ),
    };
    return Pill(label, bg: bg, fg: fg, size: 10, bold: true);
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.action,
    this.onAction,
  });

  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      children: [
        Expanded(child: Text(title, style: display(size: 16))),
        if (action != null)
          InkWell(
            onTap: onAction,
            child: Text(
              action!,
              style: body(
                size: 12,
                weight: FontWeight.w600,
                color: AppColors.teal700,
              ),
            ),
          ),
      ],
    ),
  );
}

/// Faixa de contexto: área do responsável (gestão) ou do profissional.
class RoleContext extends StatelessWidget {
  const RoleContext({super.key, this.compact = false});
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final professional = isProfessional(context);
    final accent = professional ? AppColors.blue700 : AppColors.teal700;
    final soft = professional ? AppColors.blue100 : AppColors.teal100;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: professional ? AppColors.blue200 : const Color(0xFFBFE9E4),
        ),
        gradient: LinearGradient(
          colors: [
            professional ? const Color(0xFAEFF6FF) : const Color(0xFAF0FDFA),
            const Color(0xFAFFFFFF),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color:
                (professional
                        ? const Color(0xFF1565C0)
                        : const Color(0xFF0F766E))
                    .withValues(alpha: .07),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          IconTile(
            icon: professional
                ? Icons.assignment_outlined
                : Icons.shield_outlined,
            color: accent,
            bg: soft,
            size: 36,
            radius: 12,
            iconSize: 16,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  professional ? 'Área do profissional' : 'Área do responsável',
                  style: display(
                    size: 13,
                    weight: FontWeight.w800,
                    color: professional
                        ? AppColors.blue900
                        : const Color(0xFF134E4A),
                  ),
                ),
                if (!compact) ...[
                  const SizedBox(height: 2),
                  Text(
                    professional
                        ? 'Execute cuidados, registre evoluções e acione o responsável.'
                        : 'Organize pacientes, equipe, rotinas e permissões de acesso.',
                    style: body(
                      size: 10,
                      color: const Color(0xFF5F7479),
                      height: 1.45,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: soft,
              borderRadius: BorderRadius.circular(99),
            ),
            child: Text(
              professional ? 'ASSISTÊNCIA' : 'GESTÃO',
              style: body(
                size: 9,
                weight: FontWeight.w800,
                color: accent,
                letterSpacing: .5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum Tone { teal, amber, red, blue, orange, slate, green }

(Color bg, Color border, Color fg) toneColors(Tone tone) => switch (tone) {
  Tone.teal => (AppColors.teal50, AppColors.teal200, AppColors.teal700),
  Tone.amber => (AppColors.amber50, AppColors.amber200, AppColors.amber700),
  Tone.red => (AppColors.red50, AppColors.red200, AppColors.red700),
  Tone.blue => (AppColors.blue50, AppColors.blue200, AppColors.blue700),
  Tone.orange => (AppColors.orange50, AppColors.orange200, AppColors.orange700),
  Tone.green => (AppColors.green50, AppColors.green100, AppColors.green700),
  Tone.slate => (AppColors.slate100, AppColors.slate100, AppColors.slate500),
};

class InfoBanner extends StatelessWidget {
  const InfoBanner({
    super.key,
    required this.text,
    this.title,
    this.icon = Icons.info_outline,
    this.tone = Tone.teal,
    this.bordered = true,
    this.onClose,
    this.onTap,
    this.trailing,
  });

  final String text;
  final String? title;
  final IconData icon;
  final Tone tone;
  final bool bordered;
  final VoidCallback? onClose;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final (bg, border, fg) = toneColors(tone);
    return Material(
      color: bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: bordered ? BorderSide(color: border) : BorderSide.none,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Icon(icon, size: 18, color: fg),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (title != null) ...[
                      Text(
                        title!,
                        style: body(
                          size: 14,
                          weight: FontWeight.w700,
                          color: tone == Tone.blue ? AppColors.blue900 : fg,
                        ),
                      ),
                      const SizedBox(height: 2),
                    ],
                    Text(text, style: body(size: 12, color: fg, height: 1.5)),
                  ],
                ),
              ),
              ?trailing,
              if (onClose != null)
                InkResponse(
                  onTap: onClose,
                  child: Icon(Icons.close, size: 16, color: fg),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Alerta clicável no topo do início (atrasado, acionamento, pendência).
class AlertRow extends StatelessWidget {
  const AlertRow({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.tone = Tone.red,
    this.onTap,
    this.onClose,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Tone tone;
  final VoidCallback? onTap;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final (bg, border, fg) = toneColors(tone);
    final soft = switch (tone) {
      Tone.red => AppColors.red100,
      Tone.orange => AppColors.orange100,
      Tone.blue => AppColors.blue100,
      _ => AppColors.teal100,
    };
    final iconColor = switch (tone) {
      Tone.red => AppColors.red600,
      Tone.orange => AppColors.orange600,
      Tone.blue => AppColors.blue700,
      _ => AppColors.teal700,
    };
    return Material(
      color: bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              IconTile(
                icon: icon,
                color: iconColor,
                bg: soft,
                size: 40,
                radius: 12,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: body(size: 14, weight: FontWeight.w600, color: fg),
                    ),
                    const SizedBox(height: 2),
                    Text(subtitle, style: body(size: 12, color: iconColor)),
                  ],
                ),
              ),
              if (onClose != null)
                InkResponse(
                  onTap: onClose,
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      Icons.close,
                      size: 16,
                      color: iconColor.withValues(alpha: .6),
                    ),
                  ),
                )
              else if (onTap != null)
                Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: iconColor.withValues(alpha: .6),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 56, horizontal: 24),
    child: Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: const BoxDecoration(
            color: AppColors.slate100,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 32, color: AppColors.slate300),
        ),
        const SizedBox(height: 12),
        Text(
          title,
          textAlign: TextAlign.center,
          style: body(
            size: 16,
            weight: FontWeight.w600,
            color: AppColors.slate600,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 6),
          Text(
            subtitle!,
            textAlign: TextAlign.center,
            style: body(size: 14, color: AppColors.slate400),
          ),
        ],
        if (action != null) ...[
          const SizedBox(height: 16),
          PrimaryButton(
            label: action!,
            onPressed: onAction,
            expand: false,
            height: 42,
            fontSize: 14,
            radius: 12,
          ),
        ],
      ],
    ),
  );
}

class LoadingView extends StatelessWidget {
  const LoadingView({super.key});

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (var i = 0; i < 3; i++)
        Container(
          height: 84,
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Colors.white,
            border: Border.all(color: AppColors.slate100),
          ),
          child: const _Shimmer(),
        ),
    ],
  );
}

class _Shimmer extends StatefulWidget {
  const _Shimmer();
  @override
  State<_Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<_Shimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, _) => ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment(-1 + _controller.value * 3, 0),
            end: Alignment(_controller.value * 3, 0),
            colors: const [
              Color(0xFFF0F0F0),
              Color(0xFFE6E6E6),
              Color(0xFFF0F0F0),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Estados de erro, sem conexão e permissão negada.
class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.error, this.onRetry});

  final Object? error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final message = error?.toString() ?? '';
    final offline = message.contains('Sem conexão');
    final denied =
        message.contains('permissão') || message.contains('acesso a este');
    return EmptyState(
      icon: denied
          ? Icons.lock_outline
          : offline
          ? Icons.wifi_off
          : Icons.error_outline,
      title: denied
          ? 'Permissão negada'
          : offline
          ? 'Sem conexão'
          : 'Não foi possível carregar',
      subtitle: denied
          ? '$message Solicite acesso ao responsável pelo paciente.'
          : offline
          ? 'Verifique sua internet ou se o servidor está ativo.'
          : message,
      action: denied || onRetry == null ? null : 'Tentar novamente',
      onAction: onRetry,
    );
  }
}

// ─── Botões ──────────────────────────────────────────────────────────────────
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.color = AppColors.teal700,
    this.icon,
    this.height = 52,
    this.expand = true,
    this.fontSize = 16,
    this.radius = 16,
    this.gradient,
    this.shadow = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final Color color;
  final IconData? icon;
  final double height;
  final bool expand;
  final double fontSize;
  final double radius;
  final Gradient? gradient;
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    final button = Opacity(
      opacity: onPressed == null ? .4 : (loading ? .7 : 1),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: gradient == null ? color : null,
          gradient: gradient,
          borderRadius: BorderRadius.circular(radius),
          boxShadow: shadow && onPressed != null
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: .25),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(radius),
            onTap: enabled ? onPressed : null,
            child: SizedBox(
              height: height,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: loading
                      ? const [
                          SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          ),
                        ]
                      : [
                          if (icon != null) ...[
                            Icon(icon, size: 18, color: Colors.white),
                            const SizedBox(width: 8),
                          ],
                          Flexible(
                            child: Text(
                              label,
                              textAlign: TextAlign.center,
                              style: display(
                                size: fontSize,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}

class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.slate200,
    borderRadius: BorderRadius.circular(16),
    child: InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onPressed,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Text(
          label,
          style: body(
            size: 14,
            weight: FontWeight.w600,
            color: AppColors.slate700,
          ),
        ),
      ),
    ),
  );
}

class OutlineAppButton extends StatelessWidget {
  const OutlineAppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.iconColor = AppColors.teal600,
    this.height = 50,
  });

  final String label;
  final VoidCallback onPressed;
  final IconData? icon;
  final Color iconColor;
  final double height;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: const BorderSide(color: AppColors.slate200, width: 2),
    ),
    child: InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onPressed,
      child: SizedBox(
        height: height,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18, color: iconColor),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: body(
                  size: 14,
                  weight: FontWeight.w600,
                  color: AppColors.slate700,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class TextLinkButton extends StatelessWidget {
  const TextLinkButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.color = AppColors.slate500,
  });

  final String label;
  final VoidCallback onPressed;
  final Color color;

  @override
  Widget build(BuildContext context) => TextButton(
    style: TextButton.styleFrom(
      minimumSize: const Size.fromHeight(40),
      foregroundColor: color,
    ),
    onPressed: onPressed,
    child: Text(
      label,
      style: body(size: 14, weight: FontWeight.w600, color: color),
    ),
  );
}

/// Botão tracejado ("Cadastrar novo paciente", "Adicionar foto").
class DashedButton extends StatelessWidget {
  const DashedButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.tone = Tone.teal,
    this.leadingTile = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Tone tone;
  final bool leadingTile;

  @override
  Widget build(BuildContext context) {
    final (borderColor, bg, fg) = switch (tone) {
      Tone.teal => (
        AppColors.teal200,
        const Color(0x80F0FDFA),
        AppColors.teal700,
      ),
      Tone.blue => (
        AppColors.blue200,
        const Color(0x99EFF6FF),
        AppColors.blue700,
      ),
      _ => (AppColors.slate300, Colors.white, AppColors.slate400),
    };
    return CustomPaint(
      painter: _DashedBorderPainter(color: borderColor),
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: leadingTile
                  ? MainAxisAlignment.start
                  : MainAxisAlignment.center,
              children: [
                if (leadingTile)
                  IconTile(
                    icon: icon,
                    color: fg,
                    bg: AppColors.slate100,
                    size: 40,
                    radius: 12,
                  )
                else
                  Icon(icon, size: 20, color: fg),
                SizedBox(width: leadingTile ? 12 : 8),
                Flexible(
                  child: Text(
                    label,
                    style: body(
                      size: 14,
                      weight: leadingTile ? FontWeight.w500 : FontWeight.w600,
                      color: fg,
                    ),
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

class _DashedBorderPainter extends CustomPainter {
  _DashedBorderPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          const Radius.circular(16),
        ).deflate(1),
      );
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(metric.extractPath(distance, distance + 6), paint);
        distance += 10;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// Botão grande colorido dos atalhos do início.
class ActionTileButton extends StatelessWidget {
  const ActionTileButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = AppColors.teal700,
    this.gradient,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: gradient == null ? color : null,
      gradient: gradient,
      borderRadius: BorderRadius.circular(16),
      boxShadow: gradient != null
          ? const [
              BoxShadow(
                color: Color(0x3D1D4ED8),
                blurRadius: 20,
                offset: Offset(0, 4),
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
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 22, color: Colors.white),
              const SizedBox(height: 8),
              Text(label, style: display(size: 14, color: Colors.white)),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Grupo de 3 opções lado a lado (nível de atenção, prioridade, resultado).
class SegmentChoice extends StatelessWidget {
  const SegmentChoice({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  /// (valor, rótulo, cor, fundo)
  final List<(String, String, Color, Color)> options;
  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (var i = 0; i < options.length; i++) ...[
        if (i > 0) const SizedBox(width: 8),
        Expanded(
          child: Builder(
            builder: (context) {
              final (value, label, color, bg) = options[i];
              final active = selected == value;
              return Material(
                color: active ? bg : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: active ? color : AppColors.slate200,
                    width: 2,
                  ),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => onChanged(value),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: body(
                        size: 12,
                        weight: FontWeight.w700,
                        color: active ? color : AppColors.slate400,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    ],
  );
}

/// Lista de opções selecionáveis (motivos, perfis).
class OptionTile extends StatelessWidget {
  const OptionTile({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.color = AppColors.teal700,
    this.bg = AppColors.teal50,
    this.radio = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color color;
  final Color bg;
  final bool radio;

  @override
  Widget build(BuildContext context) => Material(
    color: selected ? bg : Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: BorderSide(color: selected ? color : AppColors.slate200, width: 2),
    ),
    child: InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            if (radio) ...[
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? color : null,
                  border: Border.all(
                    color: selected ? color : AppColors.slate300,
                    width: 2,
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Text(
                label,
                style: body(
                  size: 14,
                  weight: FontWeight.w500,
                  color: selected ? color : AppColors.slate700,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

// ─── Formulário ──────────────────────────────────────────────────────────────
class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key, this.required = false});
  final String text;
  final bool required;

  @override
  Widget build(BuildContext context) => Text.rich(
    TextSpan(
      text: text,
      children: [
        if (required)
          TextSpan(
            text: ' *',
            style: body(size: 14, color: AppColors.red500),
          ),
      ],
    ),
    style: body(size: 14, weight: FontWeight.w600, color: AppColors.slate700),
  );
}

InputDecoration appInputDecoration({
  String? hint,
  Widget? suffix,
  Widget? prefix,
  bool readOnly = false,
  Color focus = AppColors.teal600,
  bool dense = false,
}) {
  OutlineInputBorder border(Color color, [double width = 1]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: color, width: width),
      );
  return InputDecoration(
    isDense: true,
    hintText: hint,
    hintStyle: body(size: 14, color: AppColors.slate400),
    filled: true,
    fillColor: readOnly ? AppColors.slate50 : Colors.white,
    contentPadding: EdgeInsets.symmetric(
      horizontal: 16,
      vertical: dense ? 11 : 14,
    ),
    suffixIcon: suffix,
    prefixIcon: prefix,
    border: border(AppColors.slate200),
    enabledBorder: border(AppColors.slate200),
    focusedBorder: border(focus, 1.6),
    errorBorder: border(AppColors.red400),
    focusedErrorBorder: border(AppColors.red600, 1.6),
    counterText: '',
  );
}

class AppInput extends StatelessWidget {
  const AppInput({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.helper,
    this.error,
    this.suffix,
    this.obscure = false,
    this.keyboardType,
    this.readOnly = false,
    this.maxLines = 1,
    this.onTap,
    this.onChanged,
    this.onSubmitted,
    this.required = false,
    this.inputFormatters,
    this.textCapitalization = TextCapitalization.none,
    this.focusColor = AppColors.teal600,
    this.maxLength,
    this.autofillHints,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final String? helper;
  final String? error;
  final Widget? suffix;
  final bool obscure;
  final TextInputType? keyboardType;
  final bool readOnly;
  final int maxLines;
  final VoidCallback? onTap;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool required;
  final List<TextInputFormatter>? inputFormatters;
  final TextCapitalization textCapitalization;
  final Color focusColor;
  final int? maxLength;
  final Iterable<String>? autofillHints;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      FieldLabel(label, required: required),
      const SizedBox(height: 6),
      TextField(
        controller: controller,
        obscureText: obscure,
        keyboardType: maxLines > 1 ? TextInputType.multiline : keyboardType,
        readOnly: readOnly || onTap != null,
        onTap: onTap,
        maxLines: maxLines,
        maxLength: maxLength,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        inputFormatters: inputFormatters,
        textCapitalization: textCapitalization,
        autofillHints: autofillHints,
        style: body(
          size: 14,
          color: readOnly ? AppColors.slate500 : AppColors.slate800,
        ),
        decoration: appInputDecoration(
          hint: hint,
          suffix: suffix,
          readOnly: readOnly,
          focus: focusColor,
        ),
      ),
      if (error != null) ...[
        const SizedBox(height: 4),
        Text(
          error!,
          style: body(
            size: 12,
            weight: FontWeight.w500,
            color: AppColors.red600,
          ),
        ),
      ] else if (helper != null) ...[
        const SizedBox(height: 4),
        Text(helper!, style: body(size: 12, color: AppColors.slate400)),
      ],
    ],
  );
}

class AppSelect<T> extends StatelessWidget {
  const AppSelect({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.labelOf,
  });

  final String label;
  final T value;
  final List<T> items;
  final ValueChanged<T> onChanged;
  final String Function(T)? labelOf;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      FieldLabel(label),
      const SizedBox(height: 6),
      DropdownButtonFormField<T>(
        initialValue: value,
        isExpanded: true,
        borderRadius: BorderRadius.circular(12),
        dropdownColor: Colors.white,
        icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.slate400),
        style: body(size: 14, color: AppColors.slate700),
        decoration: appInputDecoration(dense: true),
        items: [
          for (final item in items)
            DropdownMenuItem<T>(
              value: item,
              child: Text(labelOf?.call(item) ?? item.toString()),
            ),
        ],
        onChanged: (selected) {
          if (selected != null) onChanged(selected);
        },
      ),
    ],
  );
}

class AppCheckbox extends StatelessWidget {
  const AppCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
    this.size = 20,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final double size;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () => onChanged(!value),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: value ? AppColors.teal700 : Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: value ? AppColors.teal700 : AppColors.slate300,
          width: 2,
        ),
      ),
      child: value
          ? Icon(Icons.check, size: size * .62, color: Colors.white)
          : null,
    ),
  );
}

class AppSwitch extends StatelessWidget {
  const AppSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.width = 48,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final double width;

  @override
  Widget build(BuildContext context) => Semantics(
    toggled: value,
    child: GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: width,
        height: 24,
        padding: const EdgeInsets.symmetric(horizontal: 2),
        alignment: value ? Alignment.centerRight : Alignment.centerLeft,
        decoration: BoxDecoration(
          color: value ? AppColors.teal700 : AppColors.slate200,
          borderRadius: BorderRadius.circular(99),
        ),
        child: Container(
          width: 20,
          height: 20,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: Color(0x22000000), blurRadius: 2)],
          ),
        ),
      ),
    ),
  );
}

class ErrorBox extends StatelessWidget {
  const ErrorBox(this.message, {super.key});
  final String message;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: BoxDecoration(
      color: AppColors.red50,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.red200),
    ),
    child: Row(
      children: [
        const Icon(
          Icons.warning_amber_rounded,
          size: 16,
          color: AppColors.red600,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(message, style: body(size: 14, color: AppColors.red700)),
        ),
      ],
    ),
  );
}

/// Indicador de etapas do cabeçalho (cadastro, novo paciente).
class StepBars extends StatelessWidget {
  const StepBars({super.key, required this.step, this.total = 3});
  final int step;
  final int total;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (var i = 1; i <= total; i++) ...[
        if (i > 1) const SizedBox(width: 6),
        Expanded(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: 6,
            decoration: BoxDecoration(
              color: step >= i
                  ? Colors.white
                  : Colors.white.withValues(alpha: .3),
              borderRadius: BorderRadius.circular(99),
            ),
          ),
        ),
      ],
    ],
  );
}

/// Tela de sucesso centralizada ("Medicamento salvo!").
class SuccessView extends StatelessWidget {
  const SuccessView({
    super.key,
    required this.title,
    this.message,
    this.action,
    this.onAction,
  });

  final String title;
  final String? message;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.slate50,
    body: Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 300),
          builder: (context, value, child) => Opacity(
            opacity: value,
            child: Transform.translate(
              offset: Offset(0, 8 * (1 - value)),
              child: child,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: const BoxDecoration(
                  color: AppColors.green100,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check,
                  size: 36,
                  color: AppColors.green600,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: display(size: 20),
              ),
              if (message != null) ...[
                const SizedBox(height: 8),
                Text(
                  message!,
                  textAlign: TextAlign.center,
                  style: body(size: 14, color: AppColors.slate500),
                ),
              ],
              if (action != null) ...[
                const SizedBox(height: 28),
                PrimaryButton(label: action!, onPressed: onAction),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}

/// Linha de divisão com texto central ("ou", "ou via link").
class OrDivider extends StatelessWidget {
  const OrDivider(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      const Expanded(child: Divider(color: AppColors.slate200, height: 1)),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Text(text, style: body(size: 12, color: AppColors.slate400)),
      ),
      const Expanded(child: Divider(color: AppColors.slate200, height: 1)),
    ],
  );
}

/// Linha do tempo: trilho vertical à esquerda e conteúdo.
class TimelineItem extends StatelessWidget {
  const TimelineItem({
    super.key,
    required this.marker,
    required this.child,
    required this.isLast,
    this.indent = 40,
    this.lineLeft = 20,
    this.markerLeft = 14,
    this.markerTop = 12,
  });

  final Widget marker;
  final Widget child;
  final bool isLast;
  final double indent;
  final double lineLeft;
  final double markerLeft;
  final double markerTop;

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      if (!isLast)
        Positioned(
          left: lineLeft,
          top: 40,
          bottom: 0,
          child: Container(width: 2, color: AppColors.slate200),
        ),
      Padding(
        padding: EdgeInsets.only(left: indent, bottom: 16),
        child: child,
      ),
      Positioned(left: markerLeft, top: markerTop, child: marker),
    ],
  );
}
