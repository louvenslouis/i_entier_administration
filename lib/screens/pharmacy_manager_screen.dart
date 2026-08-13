import 'package:flutter/material.dart';

import '../data/pharmacy_admin_repository.dart';
import '../models/pharmacy_admin.dart';
import '../theme/admin_theme.dart';

class PharmacyManagerScreen extends StatefulWidget {
  final String adminId;
  final PharmacyAdminRepository repository;

  const PharmacyManagerScreen({
    super.key,
    required this.adminId,
    required this.repository,
  });

  @override
  State<PharmacyManagerScreen> createState() => _PharmacyManagerScreenState();
}

class _PharmacyManagerScreenState extends State<PharmacyManagerScreen> {
  final _search = TextEditingController();
  PharmacyAdminStatus? _status = PharmacyAdminStatus.pending;
  String _query = '';
  final Set<String> _busy = {};

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _review(
    PharmacyAdminRecord pharmacy,
    PharmacyAdminStatus status,
  ) async {
    String reason = '';
    if (status == PharmacyAdminStatus.suspended ||
        status == PharmacyAdminStatus.rejected) {
      final value = await showDialog<String>(
        context: context,
        builder: (context) =>
            _RegulationReasonDialog(pharmacy: pharmacy, status: status),
      );
      if (value == null) return;
      reason = value;
    } else {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          icon: const Icon(
            Icons.verified_outlined,
            color: AdminColors.success,
            size: 36,
          ),
          title: Text(
            pharmacy.status == PharmacyAdminStatus.suspended
                ? 'Réactiver cette pharmacie ?'
                : 'Activer cette pharmacie ?',
          ),
          content: Text(
            '${pharmacy.name} sera publiée dans le service Pharmacie de l’app Patient.',
            textAlign: TextAlign.center,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Confirmer'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    setState(() => _busy.add(pharmacy.id));
    try {
      await widget.repository.review(
        pharmacyId: pharmacy.id,
        adminId: widget.adminId,
        status: status,
        reason: reason,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Statut ${status.label.toLowerCase()} appliqué.'),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('La décision n’a pas été enregistrée.')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy.remove(pharmacy.id));
    }
  }

  @override
  Widget build(
    BuildContext context,
  ) => StreamBuilder<List<PharmacyAdminRecord>>(
    stream: widget.repository.watchPharmacies(),
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Center(
          child: CircularProgressIndicator(color: AdminColors.primary),
        );
      }
      if (snapshot.hasError) {
        return const _PharmacyFeedback(
          icon: Icons.cloud_off_outlined,
          title: 'Régulation indisponible',
          message:
              'Vérifiez la migration et les politiques Supabase pharmacie.',
        );
      }
      final pharmacies = (snapshot.data ?? const <PharmacyAdminRecord>[])
          .where((pharmacy) {
            final matchesStatus = _status == null || pharmacy.status == _status;
            final haystack = [
              pharmacy.name,
              pharmacy.legalName,
              pharmacy.licenseNumber,
              pharmacy.responsiblePharmacist,
              pharmacy.address,
            ].join(' ').toLowerCase();
            return matchesStatus && haystack.contains(_query.toLowerCase());
          })
          .toList(growable: false);
      return SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1180),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Régulation des pharmacies',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: AdminColors.ink,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Licences, activation, suspension et indicateurs opérationnels',
                  style: TextStyle(color: AdminColors.muted),
                ),
                const SizedBox(height: 20),
                TextField(
                  key: const ValueKey('admin-pharmacy-search'),
                  controller: _search,
                  onChanged: (value) => setState(() => _query = value),
                  decoration: const InputDecoration(
                    hintText: 'Nom, licence, pharmacien responsable ou adresse',
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _FilterChip(
                        label: 'Toutes',
                        selected: _status == null,
                        onSelected: () => setState(() => _status = null),
                      ),
                      for (final status in PharmacyAdminStatus.values)
                        _FilterChip(
                          label: status.label,
                          selected: _status == status,
                          onSelected: () => setState(() => _status = status),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                if (pharmacies.isEmpty)
                  const _PharmacyFeedback(
                    icon: Icons.local_pharmacy_outlined,
                    title: 'Aucune pharmacie',
                    message: 'Aucun dossier ne correspond aux filtres.',
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: pharmacies.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final pharmacy = pharmacies[index];
                      return _PharmacyRegulationCard(
                        pharmacy: pharmacy,
                        busy: _busy.contains(pharmacy.id),
                        onActivate: () =>
                            _review(pharmacy, PharmacyAdminStatus.active),
                        onSuspend: () =>
                            _review(pharmacy, PharmacyAdminStatus.suspended),
                        onReject: () =>
                            _review(pharmacy, PharmacyAdminStatus.rejected),
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onSelected;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
    ),
  );
}

class _PharmacyRegulationCard extends StatelessWidget {
  final PharmacyAdminRecord pharmacy;
  final bool busy;
  final VoidCallback onActivate;
  final VoidCallback onSuspend;
  final VoidCallback onReject;

  const _PharmacyRegulationCard({
    required this.pharmacy,
    required this.busy,
    required this.onActivate,
    required this.onSuspend,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (pharmacy.status) {
      PharmacyAdminStatus.active => AdminColors.success,
      PharmacyAdminStatus.pending => const Color(0xFFC26B00),
      PharmacyAdminStatus.suspended ||
      PharmacyAdminStatus.rejected => AdminColors.danger,
    };
    return AdminPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F7F3),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(
                  Icons.local_pharmacy_rounded,
                  color: AdminColors.success,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pharmacy.name,
                      style: const TextStyle(
                        color: AdminColors.ink,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      '${pharmacy.legalName} · Licence ${pharmacy.licenseNumber}',
                      style: const TextStyle(color: AdminColors.muted),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${pharmacy.responsiblePharmacist} · ${pharmacy.address}',
                      style: const TextStyle(
                        color: AdminColors.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: .10),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Text(
                  pharmacy.status.label,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 9,
            runSpacing: 9,
            children: [
              _Indicator(
                icon: pharmacy.licenseExpired
                    ? Icons.warning_amber_rounded
                    : Icons.badge_outlined,
                text: pharmacy.licenseExpired
                    ? 'Licence expirée'
                    : 'Licence valide',
                danger: pharmacy.licenseExpired,
              ),
              _Indicator(
                icon: Icons.medication_outlined,
                text: '${pharmacy.productCount} produit(s)',
              ),
              _Indicator(
                icon: Icons.inventory_2_outlined,
                text: '${pharmacy.lowStockCount} alerte(s) stock',
                danger: pharmacy.lowStockCount > 0,
              ),
              _Indicator(
                icon: Icons.shopping_bag_outlined,
                text: '${pharmacy.openOrderCount} commande(s) ouverte(s)',
              ),
              _Indicator(
                icon: Icons.payments_outlined,
                text:
                    '${pharmacy.monthSalesTotal.toStringAsFixed(0)} HTG ce mois',
              ),
            ],
          ),
          if (pharmacy.regulationNote.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              pharmacy.regulationNote,
              style: const TextStyle(color: AdminColors.danger, fontSize: 12),
            ),
          ],
          const SizedBox(height: 14),
          if (busy)
            const Align(
              alignment: Alignment.centerRight,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.end,
              children: [
                if (pharmacy.status != PharmacyAdminStatus.active)
                  FilledButton.icon(
                    onPressed: pharmacy.licenseExpired ? null : onActivate,
                    icon: const Icon(Icons.verified_outlined, size: 18),
                    label: Text(
                      pharmacy.status == PharmacyAdminStatus.suspended
                          ? 'Réactiver'
                          : 'Activer',
                    ),
                  ),
                if (pharmacy.status == PharmacyAdminStatus.active)
                  OutlinedButton.icon(
                    onPressed: onSuspend,
                    icon: const Icon(Icons.pause_circle_outline, size: 18),
                    label: const Text('Suspendre'),
                  ),
                if (pharmacy.status != PharmacyAdminStatus.rejected)
                  TextButton.icon(
                    onPressed: onReject,
                    icon: const Icon(Icons.block_outlined, size: 18),
                    label: const Text('Refuser'),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _Indicator extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool danger;

  const _Indicator({
    required this.icon,
    required this.text,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: danger ? const Color(0xFFFFEFEE) : const Color(0xFFF5F7FA),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 16,
          color: danger ? AdminColors.danger : AdminColors.muted,
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(
            color: danger ? AdminColors.danger : AdminColors.muted,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

class _RegulationReasonDialog extends StatefulWidget {
  final PharmacyAdminRecord pharmacy;
  final PharmacyAdminStatus status;

  const _RegulationReasonDialog({required this.pharmacy, required this.status});

  @override
  State<_RegulationReasonDialog> createState() =>
      _RegulationReasonDialogState();
}

class _RegulationReasonDialogState extends State<_RegulationReasonDialog> {
  final _formKey = GlobalKey<FormState>();
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.status == PharmacyAdminStatus.suspended
          ? 'Suspendre ${widget.pharmacy.name}'
          : 'Refuser ${widget.pharmacy.name}',
    ),
    content: Form(
      key: _formKey,
      child: SizedBox(
        width: 480,
        child: TextFormField(
          key: const ValueKey('pharmacy-regulation-reason'),
          controller: _reason,
          maxLines: 4,
          maxLength: 600,
          decoration: const InputDecoration(
            labelText: 'Motif communiqué à la pharmacie',
            alignLabelWithHint: true,
          ),
          validator: (value) => value == null || value.trim().length < 3
              ? 'Un motif précis est requis.'
              : null,
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Annuler'),
      ),
      FilledButton(
        onPressed: () {
          if (_formKey.currentState?.validate() == true) {
            Navigator.pop(context, _reason.text.trim());
          }
        },
        style: FilledButton.styleFrom(backgroundColor: AdminColors.danger),
        child: const Text('Confirmer'),
      ),
    ],
  );
}

class _PharmacyFeedback extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _PharmacyFeedback({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 44, color: AdminColors.primary),
          const SizedBox(height: 12),
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(message, style: const TextStyle(color: AdminColors.muted)),
        ],
      ),
    ),
  );
}
