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

class _CoverageDetailDialog extends StatelessWidget {
  final InsuranceCoverageAdminRequest coverage;
  final InsuranceCoverageAdminRepository repository;

  const _CoverageDetailDialog({
    required this.coverage,
    required this.repository,
  });

  Future<List<String>> _urls() => Future.wait([
    repository.createCardUrl(coverage.frontPath),
    repository.createCardUrl(coverage.backPath),
  ]);

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
                    future: _urls(),
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
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          color: AdminColors.primary,
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'La validation ou le refus reste réservé à un professionnel vérifié dans I-ENTIER Professionnel.',
                            style: TextStyle(
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
                ],
              ),
            ),
          ),
        ],
      ),
    ),
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
