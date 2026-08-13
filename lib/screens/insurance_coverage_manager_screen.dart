import 'package:flutter/material.dart';

import '../data/insurance_coverage_admin_repository.dart';
import '../models/insurance_coverage_admin.dart';
import '../theme/admin_theme.dart';

enum _CoverageFilter { pending, all, verified, rejected }

class InsuranceCoverageManagerScreen extends StatefulWidget {
  final InsuranceCoverageAdminRepository repository;

  const InsuranceCoverageManagerScreen({super.key, required this.repository});

  @override
  State<InsuranceCoverageManagerScreen> createState() =>
      _InsuranceCoverageManagerScreenState();
}

class _InsuranceCoverageManagerScreenState
    extends State<InsuranceCoverageManagerScreen> {
  late Stream<List<InsuranceCoverageAdminRequest>> _coverages;
  final _searchController = TextEditingController();
  _CoverageFilter _filter = _CoverageFilter.pending;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _coverages = widget.repository.watchCoverages();
  }

  @override
  void didUpdateWidget(covariant InsuranceCoverageManagerScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.repository != widget.repository) {
      _coverages = widget.repository.watchCoverages();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      StreamBuilder<List<InsuranceCoverageAdminRequest>>(
        stream: _coverages,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: AdminColors.primary),
            );
          }
          if (snapshot.hasError) {
            return const _CoverageError();
          }

          final all = snapshot.data ?? const [];
          final pendingCount = all.where((item) => item.pending).length;
          final query = _query.trim().toLowerCase();
          final visible = all
              .where((item) {
                final statusMatches = switch (_filter) {
                  _CoverageFilter.pending => item.pending,
                  _CoverageFilter.verified => item.verified,
                  _CoverageFilter.rejected => item.rejected,
                  _CoverageFilter.all => true,
                };
                if (!statusMatches) return false;
                if (query.isEmpty) return true;
                return item.patientName.toLowerCase().contains(query) ||
                    item.memberNumber.toLowerCase().contains(query) ||
                    item.patientId.toLowerCase().contains(query);
              })
              .toList(growable: false);

          return Column(
            children: [
              _CoverageHeader(
                pendingCount: pendingCount,
                filter: _filter,
                searchController: _searchController,
                onFilterChanged: (value) => setState(() => _filter = value),
                onSearchChanged: (value) => setState(() => _query = value),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(22, 22, 22, 38),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1180),
                      child: visible.isEmpty
                          ? _EmptyCoverageList(filter: _filter)
                          : Column(
                              children: [
                                for (final coverage in visible) ...[
                                  _CoverageTile(
                                    coverage: coverage,
                                    repository: widget.repository,
                                  ),
                                  const SizedBox(height: 12),
                                ],
                              ],
                            ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      );
}

class _CoverageHeader extends StatelessWidget {
  final int pendingCount;
  final _CoverageFilter filter;
  final TextEditingController searchController;
  final ValueChanged<_CoverageFilter> onFilterChanged;
  final ValueChanged<String> onSearchChanged;

  const _CoverageHeader({
    required this.pendingCount,
    required this.filter,
    required this.searchController,
    required this.onFilterChanged,
    required this.onSearchChanged,
  });

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(bottom: BorderSide(color: AdminColors.border)),
    ),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1180),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 14,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Couvertures OFATMA',
                      style: TextStyle(
                        color: AdminColors.ink,
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Supervision des cartes soumises par les patients.',
                      style: TextStyle(color: AdminColors.muted),
                    ),
                  ],
                ),
                _PendingBadge(count: pendingCount),
              ],
            ),
            const SizedBox(height: 18),
            LayoutBuilder(
              builder: (context, constraints) {
                final search = SizedBox(
                  width: constraints.maxWidth < 720
                      ? constraints.maxWidth
                      : 340,
                  child: TextField(
                    controller: searchController,
                    onChanged: onSearchChanged,
                    decoration: const InputDecoration(
                      hintText: 'Patient ou numéro d’adhérent',
                      prefixIcon: Icon(Icons.search_rounded),
                      isDense: true,
                    ),
                  ),
                );
                final filters = Wrap(
                  spacing: 7,
                  children: [
                    _FilterChip(
                      label: 'En attente',
                      selected: filter == _CoverageFilter.pending,
                      onTap: () => onFilterChanged(_CoverageFilter.pending),
                    ),
                    _FilterChip(
                      label: 'Toutes',
                      selected: filter == _CoverageFilter.all,
                      onTap: () => onFilterChanged(_CoverageFilter.all),
                    ),
                    _FilterChip(
                      label: 'Validées',
                      selected: filter == _CoverageFilter.verified,
                      onTap: () => onFilterChanged(_CoverageFilter.verified),
                    ),
                    _FilterChip(
                      label: 'Refusées',
                      selected: filter == _CoverageFilter.rejected,
                      onTap: () => onFilterChanged(_CoverageFilter.rejected),
                    ),
                  ],
                );
                if (constraints.maxWidth < 720) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [search, const SizedBox(height: 12), filters],
                  );
                }
                return Row(
                  children: [
                    search,
                    const SizedBox(width: 16),
                    Expanded(child: filters),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    ),
  );
}

class _PendingBadge extends StatelessWidget {
  final int count;
  const _PendingBadge({required this.count});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
    decoration: BoxDecoration(
      color: AdminColors.primarySoft,
      borderRadius: BorderRadius.circular(18),
    ),
    child: Text(
      '$count en attente',
      style: const TextStyle(
        color: AdminColors.primaryDark,
        fontWeight: FontWeight.w900,
      ),
    ),
  );
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => ChoiceChip(
    label: Text(label),
    selected: selected,
    onSelected: (_) => onTap(),
  );
}

class _CoverageTile extends StatelessWidget {
  final InsuranceCoverageAdminRequest coverage;
  final InsuranceCoverageAdminRepository repository;

  const _CoverageTile({required this.coverage, required this.repository});

  @override
  Widget build(BuildContext context) {
    final status = _statusAppearance(coverage);
    return AdminPanel(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final information = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: status.color.withValues(alpha: .10),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(status.icon, color: status.color),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          coverage.patientName,
                          style: const TextStyle(
                            color: AdminColors.ink,
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${coverage.insurerCode}${coverage.memberNumber.isEmpty ? '' : ' • ${coverage.memberNumber}'}',
                          style: const TextStyle(color: AdminColors.muted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 13),
              Wrap(
                spacing: 14,
                runSpacing: 6,
                children: [
                  _Meta(
                    icon: Icons.schedule_rounded,
                    text: 'Soumise le ${_date(coverage.submittedAt)}',
                  ),
                  _StatusBadge(label: status.label, color: status.color),
                ],
              ),
            ],
          );
          final action = OutlinedButton.icon(
            key: ValueKey('open-coverage-${coverage.id}'),
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => _CoverageDetailDialog(
                coverage: coverage,
                repository: repository,
              ),
            ),
            icon: const Icon(Icons.visibility_outlined),
            label: const Text('Voir le dossier'),
          );
          if (constraints.maxWidth < 660) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [information, const SizedBox(height: 16), action],
            );
          }
          return Row(
            children: [
              Expanded(child: information),
              const SizedBox(width: 24),
              action,
            ],
          );
        },
      ),
    );
  }
}

class _CoverageDetailDialog extends StatefulWidget {
  final InsuranceCoverageAdminRequest coverage;
  final InsuranceCoverageAdminRepository repository;

  const _CoverageDetailDialog({
    required this.coverage,
    required this.repository,
  });

  @override
  State<_CoverageDetailDialog> createState() => _CoverageDetailDialogState();
}

class _CoverageDetailDialogState extends State<_CoverageDetailDialog> {
  late final Future<List<String>> _cardUrls;
  bool _saving = false;

  InsuranceCoverageAdminRequest get coverage => widget.coverage;

  @override
  void initState() {
    super.initState();
    _cardUrls = Future.wait([
      widget.repository.createCardUrl(coverage.frontPath),
      widget.repository.createCardUrl(coverage.backPath),
    ]);
  }

  Future<void> _approve() async {
    final decision = await showDialog<_CoverageApprovalDecision>(
      context: context,
      builder: (_) => const _CoverageApprovalDialog(),
    );
    if (decision == null) return;
    await _review(
      approve: true,
      reason: decision.note,
      validUntil: decision.validUntil,
    );
  }

  Future<void> _reject() async {
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => const _CoverageRejectionDialog(),
    );
    if (reason == null) return;
    await _review(approve: false, reason: reason);
  }

  Future<void> _review({
    required bool approve,
    required String reason,
    DateTime? validUntil,
  }) async {
    setState(() => _saving = true);
    try {
      await widget.repository.reviewCoverage(
        coverageId: coverage.id,
        approve: approve,
        reason: reason,
        validUntil: validUntil,
      );
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            approve
                ? 'La couverture OFATMA est maintenant valide.'
                : 'Le refus a été transmis au patient.',
          ),
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'La décision n’a pas pu être enregistrée. Vérifiez vos droits administrateur.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Dialog(
    insetPadding: const EdgeInsets.all(18),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 920, maxHeight: 820),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 18, 10, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Dossier OFATMA — ${coverage.patientName}',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        coverage.memberNumber.isEmpty
                            ? 'Numéro d’adhérent non renseigné'
                            : 'Adhérent ${coverage.memberNumber}',
                        style: const TextStyle(color: AdminColors.muted),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Fermer',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AdminColors.border),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FutureBuilder<List<String>>(
                    future: _cardUrls,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const SizedBox(
                          height: 260,
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      if (snapshot.hasError || !snapshot.hasData) {
                        return const AdminPanel(
                          child: Text(
                            'Impossible d’ouvrir les images privées de cette carte.',
                          ),
                        );
                      }
                      return LayoutBuilder(
                        builder: (context, constraints) {
                          final cards = [
                            _CardPreview(
                              label: 'Recto',
                              url: snapshot.data![0],
                            ),
                            _CardPreview(
                              label: 'Verso',
                              url: snapshot.data![1],
                            ),
                          ];
                          if (constraints.maxWidth < 700) {
                            return Column(
                              children: [
                                cards[0],
                                const SizedBox(height: 14),
                                cards[1],
                              ],
                            );
                          }
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: cards[0]),
                              const SizedBox(width: 14),
                              Expanded(child: cards[1]),
                            ],
                          );
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AdminColors.primarySoft,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.info_outline_rounded,
                          color: AdminColors.primary,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            coverage.pending
                                ? 'En tant qu’administrateur actif, vous pouvez valider ou refuser cette couverture après contrôle des deux faces.'
                                : 'Ce dossier a déjà été traité et ne peut plus recevoir une nouvelle décision.',
                            style: const TextStyle(
                              color: AdminColors.primaryDark,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (coverage.reviewNote.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Text(
                      'Note de traitement : ${coverage.reviewNote}',
                      style: const TextStyle(color: AdminColors.muted),
                    ),
                  ],
                  if (coverage.pending) ...[
                    const SizedBox(height: 18),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final reject = OutlinedButton.icon(
                          key: ValueKey('admin-reject-coverage-${coverage.id}'),
                          onPressed: _saving ? null : _reject,
                          icon: const Icon(Icons.close_rounded),
                          label: const Text('Refuser'),
                        );
                        final approve = FilledButton.icon(
                          key: ValueKey(
                            'admin-approve-coverage-${coverage.id}',
                          ),
                          onPressed: _saving ? null : _approve,
                          icon: _saving
                              ? const SizedBox.square(
                                  dimension: 17,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.verified_rounded),
                          label: const Text('Valider'),
                        );
                        if (constraints.maxWidth < 520) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              reject,
                              const SizedBox(height: 10),
                              approve,
                            ],
                          );
                        }
                        return Row(
                          children: [
                            Expanded(child: reject),
                            const SizedBox(width: 12),
                            Expanded(child: approve),
                          ],
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _CoverageApprovalDecision {
  final DateTime validUntil;
  final String note;

  const _CoverageApprovalDecision({
    required this.validUntil,
    required this.note,
  });
}

class _CoverageApprovalDialog extends StatefulWidget {
  const _CoverageApprovalDialog();

  @override
  State<_CoverageApprovalDialog> createState() =>
      _CoverageApprovalDialogState();
}

class _CoverageApprovalDialogState extends State<_CoverageApprovalDialog> {
  final _note = TextEditingController();
  late DateTime _validUntil;

  @override
  void initState() {
    super.initState();
    final now = DateUtils.dateOnly(DateTime.now());
    _validUntil = DateTime(now.year + 1, now.month, now.day);
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateUtils.dateOnly(DateTime.now());
    final value = await showDatePicker(
      context: context,
      initialDate: _validUntil,
      firstDate: now,
      lastDate: DateTime(now.year + 10, now.month, now.day),
      helpText: 'Fin de validité OFATMA',
    );
    if (value != null) setState(() => _validUntil = value);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Valider la couverture OFATMA'),
    content: SizedBox(
      width: 440,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            key: const ValueKey('admin-insurance-valid-until'),
            contentPadding: EdgeInsets.zero,
            onTap: _pickDate,
            leading: const Icon(Icons.event_available_outlined),
            title: const Text('Date de fin de validité'),
            subtitle: Text(_date(_validUntil)),
            trailing: const Icon(Icons.edit_calendar_outlined),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _note,
            maxLength: 1000,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Note de contrôle (facultative)',
            ),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Annuler'),
      ),
      FilledButton(
        key: const ValueKey('confirm-admin-insurance-approval'),
        onPressed: () => Navigator.pop(
          context,
          _CoverageApprovalDecision(
            validUntil: _validUntil,
            note: _note.text.trim(),
          ),
        ),
        child: const Text('Confirmer la validité'),
      ),
    ],
  );
}

class _CoverageRejectionDialog extends StatefulWidget {
  const _CoverageRejectionDialog();

  @override
  State<_CoverageRejectionDialog> createState() =>
      _CoverageRejectionDialogState();
}

class _CoverageRejectionDialogState extends State<_CoverageRejectionDialog> {
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Refuser la carte OFATMA'),
    content: SizedBox(
      width: 440,
      child: TextField(
        key: const ValueKey('admin-insurance-rejection-reason'),
        controller: _reason,
        autofocus: true,
        maxLength: 1000,
        minLines: 3,
        maxLines: 5,
        onChanged: (_) => setState(() {}),
        decoration: const InputDecoration(
          labelText: 'Motif transmis au patient',
          hintText: 'Ex. verso illisible ou carte expirée',
          alignLabelWithHint: true,
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Annuler'),
      ),
      FilledButton(
        key: const ValueKey('confirm-admin-insurance-rejection'),
        onPressed: _reason.text.trim().length < 5
            ? null
            : () => Navigator.pop(context, _reason.text.trim()),
        child: const Text('Confirmer le refus'),
      ),
    ],
  );
}

class _CardPreview extends StatelessWidget {
  final String label;
  final String url;
  const _CardPreview({required this.label, required this.url});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Carte OFATMA — $label',
        style: const TextStyle(
          color: AdminColors.ink,
          fontWeight: FontWeight.w900,
        ),
      ),
      const SizedBox(height: 8),
      Container(
        height: 280,
        width: double.infinity,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: const Color(0xFFF7F9FC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AdminColors.border),
        ),
        child: InteractiveViewer(
          minScale: .8,
          maxScale: 5,
          child: Image.network(
            url,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) =>
                const Center(child: Text('Image indisponible')),
          ),
        ),
      ),
    ],
  );
}

class _Meta extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Meta({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 16, color: AdminColors.muted),
      const SizedBox(width: 5),
      Text(text, style: const TextStyle(color: AdminColors.muted)),
    ],
  );
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .10),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(
      label,
      style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 12),
    ),
  );
}

class _StatusAppearance {
  final String label;
  final Color color;
  final IconData icon;
  const _StatusAppearance(this.label, this.color, this.icon);
}

_StatusAppearance _statusAppearance(InsuranceCoverageAdminRequest coverage) {
  if (coverage.verified) {
    return const _StatusAppearance(
      'Validée',
      AdminColors.success,
      Icons.verified_user_outlined,
    );
  }
  if (coverage.rejected) {
    return const _StatusAppearance(
      'Refusée',
      AdminColors.danger,
      Icons.cancel_outlined,
    );
  }
  return const _StatusAppearance(
    'En attente',
    AdminColors.warning,
    Icons.pending_actions_outlined,
  );
}

class _EmptyCoverageList extends StatelessWidget {
  final _CoverageFilter filter;
  const _EmptyCoverageList({required this.filter});

  @override
  Widget build(BuildContext context) => AdminPanel(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Column(
        children: [
          const Icon(
            Icons.health_and_safety_outlined,
            color: AdminColors.success,
            size: 42,
          ),
          const SizedBox(height: 12),
          Text(
            filter == _CoverageFilter.pending
                ? 'Aucune demande OFATMA en attente.'
                : 'Aucune couverture dans cette vue.',
            style: const TextStyle(
              color: AdminColors.ink,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    ),
  );
}

class _CoverageError extends StatelessWidget {
  const _CoverageError();

  @override
  Widget build(BuildContext context) => const Center(
    child: Padding(
      padding: EdgeInsets.all(24),
      child: AdminPanel(
        child: Text(
          'Impossible de charger les demandes OFATMA. Vérifiez la connexion et les droits administrateur.',
          textAlign: TextAlign.center,
        ),
      ),
    ),
  );
}

String _date(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
