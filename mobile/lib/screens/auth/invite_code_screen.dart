import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../../widgets/ui.dart';

class InviteResult {
  const InviteResult(this.code, {this.createAccount = false});
  final String code;
  final bool createAccount;
}

/// Mantém o código em maiúsculas, com letras, números e hífen (máx. 8).
/// O hífen é opcional ao digitar: "VID7A2F" vira "VID-7A2F" ao enviar.
class InviteCodeFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var text = newValue.text.toUpperCase().replaceAll(
      RegExp(r'[^A-Z0-9-]'),
      '',
    );
    if (text.length > 8) text = text.substring(0, 8);
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

/// Converte o texto digitado no formato aceito pela API (8 caracteres).
String normalizeInviteCode(String value) {
  final clean = value.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
  if (clean.length == 7) {
    return '${clean.substring(0, 3)}-${clean.substring(3)}';
  }
  return value.toUpperCase().trim();
}

class InviteCodeScreen extends StatefulWidget {
  const InviteCodeScreen({super.key, required this.api});
  final ApiClient api;

  @override
  State<InviteCodeScreen> createState() => _InviteCodeScreenState();
}

class _InviteCodeScreenState extends State<InviteCodeScreen> {
  final _code = TextEditingController();
  String _error = '';
  bool _loading = false;
  String? _invalidReason;
  String? _validCode;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final code = normalizeInviteCode(_code.text);
    if (code.isEmpty) {
      setState(() => _error = 'Digite o código de convite.');
      return;
    }
    if (code.length != 8) {
      setState(() => _error = 'O código possui 8 caracteres, como VID-7A2F.');
      return;
    }
    setState(() {
      _error = '';
      _loading = true;
    });
    try {
      await widget.api.validateInvite(code);
      if (mounted) setState(() => _validCode = code);
    } on ApiException catch (error) {
      if (!mounted) return;
      if (error.isNotFound || error.isExpired) {
        setState(
          () => _invalidReason = error.isExpired
              ? 'Este convite expirou. Solicite um novo código ao responsável.'
              : 'O código pode ter expirado ou estar incorreto.',
        );
      } else {
        setState(() => _error = error.message);
      }
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
            'Entrar com convite',
            subtitle: 'Digite o código recebido do responsável pelo paciente',
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
            children: [
              if (_invalidReason != null)
                _Invalid(
                  reason: _invalidReason!,
                  onRetry: () => setState(() {
                    _invalidReason = null;
                    _code.clear();
                  }),
                )
              else if (_validCode != null)
                _Valid(code: _validCode!)
              else ...[
                const FieldLabel('Código de convite'),
                const SizedBox(height: 6),
                TextField(
                  controller: _code,
                  textAlign: TextAlign.center,
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: [InviteCodeFormatter()],
                  onSubmitted: (_) => _submit(),
                  style: display(
                    size: 20,
                    weight: FontWeight.w900,
                    color: AppColors.teal700,
                    letterSpacing: 6,
                  ),
                  decoration: appInputDecoration(hint: 'VID-0000').copyWith(
                    hintStyle: display(
                      size: 20,
                      weight: FontWeight.w900,
                      color: AppColors.slate300,
                      letterSpacing: 6,
                    ),
                  ),
                ),
                if (_error.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    _error,
                    style: body(
                      size: 12,
                      weight: FontWeight.w500,
                      color: AppColors.red600,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                const InfoBanner(
                  bordered: false,
                  text:
                      'O código de convite foi gerado pelo responsável do paciente. Ele tem prazo de validade e pode ser revogado a qualquer momento.',
                ),
                const SizedBox(height: 20),
                PrimaryButton(
                  label: 'Acessar com convite',
                  loading: _loading,
                  onPressed: _submit,
                ),
                const SizedBox(height: 20),
                Center(
                  child: InkWell(
                    onTap: () => Navigator.pop(context),
                    child: Text.rich(
                      TextSpan(
                        text: 'Já tem conta? ',
                        children: [
                          TextSpan(
                            text: 'Fazer login',
                            style: body(
                              size: 14,
                              weight: FontWeight.w700,
                              color: AppColors.teal700,
                            ),
                          ),
                        ],
                      ),
                      style: body(size: 14, color: AppColors.slate500),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    ),
  );
}

class _Invalid extends StatelessWidget {
  const _Invalid({required this.reason, required this.onRetry});
  final String reason;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 32),
    child: Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: const BoxDecoration(
            color: AppColors.red100,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.close, size: 28, color: AppColors.red600),
        ),
        const SizedBox(height: 16),
        Text('Convite inválido', style: display(size: 18)),
        const SizedBox(height: 4),
        Text(
          reason,
          textAlign: TextAlign.center,
          style: body(size: 14, color: AppColors.slate500),
        ),
        const SizedBox(height: 16),
        PrimaryButton(
          label: 'Tentar novamente',
          expand: false,
          height: 48,
          onPressed: onRetry,
        ),
      ],
    ),
  );
}

class _Valid extends StatelessWidget {
  const _Valid({required this.code});
  final String code;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      const SizedBox(height: 16),
      Container(
        width: 64,
        height: 64,
        decoration: const BoxDecoration(
          color: AppColors.green100,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.check, size: 30, color: AppColors.green600),
      ),
      const SizedBox(height: 16),
      Text('Convite válido', style: display(size: 18)),
      const SizedBox(height: 4),
      Text(
        'Para garantir a rastreabilidade dos registros, entre ou crie sua conta profissional. O paciente será vinculado automaticamente.',
        textAlign: TextAlign.center,
        style: body(size: 14, color: AppColors.slate500),
      ),
      const SizedBox(height: 24),
      PrimaryButton(
        label: 'Entrar com minha conta',
        onPressed: () => Navigator.pop(context, InviteResult(code)),
      ),
      const SizedBox(height: 12),
      OutlineAppButton(
        label: 'Criar conta profissional',
        icon: Icons.person_add_alt_1_outlined,
        onPressed: () =>
            Navigator.pop(context, InviteResult(code, createAccount: true)),
      ),
    ],
  );
}
