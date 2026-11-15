import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../core/care_data.dart';
import '../core/session.dart';
import '../widgets/patient_widgets.dart';
import '../widgets/ui.dart';
import 'auth/invite_code_screen.dart';
import 'patient_detail_screen.dart';
import 'patient_form_screen.dart';

class PatientsScreen extends StatefulWidget {
  const PatientsScreen({super.key});

  @override
  State<PatientsScreen> createState() => _PatientsScreenState();
}

class _PatientsScreenState extends State<PatientsScreen> {
  final _search = TextEditingController();
  String _filter = 'todos';

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = Session.of(context);
    final responsible = !session.professional;
    final store = session.store;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final query = _search.text.trim().toLowerCase();
        final filtered = store.bundles
            .where(
              (b) =>
                  b.patient.name.toLowerCase().contains(query) &&
                  (_filter == 'todos' || b.displayStatus == _filter),
            )
            .toList();
        return AppScreen(
          onRefresh: store.load,
          header: GradientHeader(
            child: Column(
              children: [
                HeaderTitle(
                  responsible ? 'Pacientes sob cuidado' : 'Meus pacientes',
                  subtitle: responsible
                      ? 'Você administra cadastro, equipe e acesso'
                      : 'Somente pacientes vinculados ao seu perfil',
                  trailing: responsible
                      ? HeaderIconButton(
                          icon: Icons.add,
                          tooltip: 'Adicionar paciente',
                          onTap: () => go(context, const PatientFormScreen()),
                        )
                      : null,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _search,
                  style: body(size: 14, color: AppColors.slate800),
                  decoration: InputDecoration(
                    isDense: true,
                    filled: true,
                    fillColor: Colors.white,
                    hintText: 'Buscar paciente...',
                    hintStyle: body(size: 14, color: AppColors.slate400),
                    prefixIcon: const Icon(
                      Icons.search,
                      size: 18,
                      color: AppColors.slate400,
                    ),
                    suffixIcon: _search.text.isEmpty
                        ? null
                        : IconButton(
                            onPressed: _search.clear,
                            icon: const Icon(
                              Icons.close,
                              size: 16,
                              color: AppColors.slate400,
                            ),
                          ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 11),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ],
            ),
          ),
          belowHeader: [
            FilterBar(
              options: const [
                ('todos', 'Todos'),
                ('ativo', 'Ativos'),
                ('atencao', 'Atenção'),
                ('inativo', 'Inativos'),
              ],
              selected: _filter,
              onChanged: (value) => setState(() => _filter = value),
            ),
          ],
          children: [
            const RoleContext(),
            if (!store.loaded && store.loading)
              const LoadingView()
            else if (!store.loaded && store.error != null)
              ErrorView(error: store.error, onRetry: store.load)
            else if (filtered.isEmpty)
              EmptyState(
                icon: Icons.group_outlined,
                title: 'Nenhum paciente encontrado',
                subtitle: responsible
                    ? 'Tente outro filtro ou adicione um novo paciente'
                    : 'Você ainda não está vinculado a nenhum paciente. Use um código de convite.',
                action: responsible ? 'Novo paciente' : null,
                onAction: responsible
                    ? () => go(context, const PatientFormScreen())
                    : null,
              )
            else
              for (final bundle in filtered)
                _PatientCard(bundle: bundle, userId: session.user.id),
            if (responsible)
              DashedButton(
                icon: Icons.add,
                label: 'Cadastrar novo paciente',
                onTap: () => go(context, const PatientFormScreen()),
              )
            else
              DashedButton(
                icon: Icons.link,
                label: 'Vincular paciente com código',
                tone: Tone.blue,
                onTap: () => _join(context),
              ),
          ],
        );
      },
    );
  }

  Future<void> _join(BuildContext context) async {
    final code = await go<String>(context, const JoinPatientScreen());
    if (code != null && context.mounted) {
      showToast(context, 'Paciente vinculado com sucesso.');
    }
  }
}

class _PatientCard extends StatelessWidget {
  const _PatientCard({required this.bundle, required this.userId});
  final PatientBundle bundle;
  final String userId;

  @override
  Widget build(BuildContext context) {
    final patient = bundle.patient;
    return AppCard(
      onTap: () => go(context, PatientDetailScreen(patientId: patient.id)),
      child: Row(
        children: [
          PatientAvatar(
            patient: patient,
            size: 52,
            badge: bundle.recentObservationsFrom(userId),
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(patient.name, style: display(size: 16)),
                          Text(
                            '${patient.age} anos',
                            style: body(size: 12, color: AppColors.slate400),
                          ),
                        ],
                      ),
                    ),
                    StatusBadge(status: bundle.displayStatus),
                  ],
                ),
                const SizedBox(height: 4),
                NextDoseLine(bundle: bundle),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      Icons.groups_outlined,
                      size: 12,
                      color: AppColors.slate400,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${patient.professionalsCount} profissiona${patient.professionalsCount == 1 ? 'l' : 'is'}',
                      style: body(size: 12, color: AppColors.slate400),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right, size: 18, color: AppColors.slate300),
        ],
      ),
    );
  }
}

/// Vínculo de um novo paciente por profissional já autenticado.
class JoinPatientScreen extends StatefulWidget {
  const JoinPatientScreen({super.key});

  @override
  State<JoinPatientScreen> createState() => _JoinPatientScreenState();
}

class _JoinPatientScreenState extends State<JoinPatientScreen> {
  final _code = TextEditingController();
  bool _loading = false;
  String _error = '';
  String? _invalid;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final code = normalizeInviteCode(_code.text);
    if (code.length != 8) {
      setState(() => _error = 'O código possui 8 caracteres, como VID-7A2F.');
      return;
    }
    final session = Session.of(context);
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      final patient = await session.api.joinPatient(code);
      await session.store.load();
      if (mounted) {
        final navigator = Navigator.of(context);
        navigator.pop(code);
        navigator.push(
          MaterialPageRoute<void>(
            builder: (_) => PatientDetailScreen(patientId: patient.id),
          ),
        );
      }
    } catch (error) {
      final message = error.toString();
      if (mounted) {
        setState(() {
          if (message.contains('inválido') || message.contains('expirou')) {
            _invalid = message;
          } else {
            _error = message;
          }
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => AppScreen(
    background: AppColors.slate50,
    header: GradientHeader(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
      onBack: () => Navigator.pop(context),
      child: const HeaderTitle(
        'Vincular paciente',
        subtitle: 'Digite o código recebido do responsável pelo paciente',
      ),
    ),
    padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
    spacing: 20,
    children: _invalid != null
        ? [
            EmptyState(
              icon: Icons.close,
              title: 'Convite inválido',
              subtitle: _invalid,
              action: 'Tentar novamente',
              onAction: () => setState(() {
                _invalid = null;
                _code.clear();
              }),
            ),
          ]
        : [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const FieldLabel('Código de convite'),
                const SizedBox(height: 6),
                TextField(
                  controller: _code,
                  textAlign: TextAlign.center,
                  inputFormatters: [InviteCodeFormatter()],
                  onSubmitted: (_) => _submit(),
                  style: display(
                    size: 20,
                    weight: FontWeight.w900,
                    color: AppColors.teal700,
                    letterSpacing: 6,
                  ),
                  decoration: appInputDecoration(hint: 'VID-0000'),
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
              ],
            ),
            const InfoBanner(
              bordered: false,
              text:
                  'O código de convite foi gerado pelo responsável do paciente. Ele tem prazo de validade e pode ser revogado a qualquer momento.',
            ),
            PrimaryButton(
              label: 'Vincular paciente',
              loading: _loading,
              onPressed: _submit,
            ),
          ],
  );
}
