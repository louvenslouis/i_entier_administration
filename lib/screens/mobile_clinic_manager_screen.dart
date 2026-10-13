import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/mobile_clinic_admin_repository.dart';
import '../models/mobile_clinic_admin.dart';
import '../supabase_config.dart';
import '../theme/admin_theme.dart';

enum _ClinicAdminFilter { all, pending, approved, rejected }

class MobileClinicManagerScreen extends StatefulWidget {
  final User user;
  final MobileClinicAdminRepository repository;

  const MobileClinicManagerScreen({
    super.key,
    required this.user,
    required this.repository,
  });

  @override
  State<MobileClinicManagerScreen> createState() =>
      _MobileClinicManagerScreenState();
}

class _MobileClinicManagerScreenState extends State<MobileClinicManagerScreen> {
  final _searchController = TextEditingController();
  _ClinicAdminFilter _filter = _ClinicAdminFilter.pending;
  String _query = '';
  final Set<String> _reviewing = {};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _approve(MobileClinicAdminRecord clinic) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(
          Icons.verified_outlined,
          color: AdminColors.success,
          size: 38,
        ),
        title: const Text('Certifier cette clinique mobile ?'),
        content: Text(
          '${clinic.name} recevra automatiquement le badge « Clinique Mobile Certifiée I-Entier » et pourra être publiée.',
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AdminColors.success),
            child: const Text('Certifier'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _review(clinic, MobileClinicAdminStatus.approved);
    }
  }

  Future<void> _reject(MobileClinicAdminRecord clinic) async {
    final controller = TextEditingController(text: clinic.rejectionReason);
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Demander des corrections'),
        content: SizedBox(
          width: 500,
          child: TextField(
            controller: controller,
            autofocus: true,
            minLines: 3,
            maxLines: 6,
            maxLength: 700,
            decoration: const InputDecoration(
              labelText: 'Motif du refus',
              hintText: 'Indiquez le document manquant ou non conforme.',
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
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                Navigator.pop(context, controller.text.trim());
              }
            },
            style: FilledButton.styleFrom(backgroundColor: AdminColors.danger),
            child: const Text('Refuser'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (reason != null) {
      await _review(clinic, MobileClinicAdminStatus.rejected, reason: reason);
    }
  }

  Future<void> _review(
    MobileClinicAdminRecord clinic,
    MobileClinicAdminStatus status, {
    String reason = '',
  }) async {
    setState(() => _reviewing.add(clinic.id));
    try {
      await widget.repository.review(
        clinicId: clinic.id,
        adminId: widget.user.uid,
        status: status,
        reason: reason,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              status == MobileClinicAdminStatus.approved
                  ? 'Clinique certifiée et badge attribué.'
                  : 'Corrections demandées au responsable.',
            ),
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
      if (mounted) setState(() => _reviewing.remove(clinic.id));
    }
  }

  void _open(MobileClinicAdminRecord clinic) {
    showDialog<void>(
      context: context,
      builder: (context) => _ClinicReviewDialog(
        clinic: clinic,
        reviewing: _reviewing.contains(clinic.id),
        onApprove: () {
          Navigator.pop(context);
          _approve(clinic);
        },
        onReject: () {
          Navigator.pop(context);
          _reject(clinic);
        },
      ),
    );
  }

  List<MobileClinicAdminRecord> _filtered(
    List<MobileClinicAdminRecord> clinics,
  ) {
    final query = _query.trim().toLowerCase();
    return clinics
        .where((clinic) {
          final statusMatch = switch (_filter) {
            _ClinicAdminFilter.all => true,
            _ClinicAdminFilter.pending =>
              clinic.status == MobileClinicAdminStatus.pending,
            _ClinicAdminFilter.approved =>
              clinic.status == MobileClinicAdminStatus.approved,
            _ClinicAdminFilter.rejected =>
              clinic.status == MobileClinicAdminStatus.rejected,
          };
          final queryMatch =
              query.isEmpty ||
              '${clinic.name} ${clinic.responsibleName} ${clinic.department} ${clinic.commune} ${clinic.creatorLabel}'
                  .toLowerCase()
                  .contains(query);
          return statusMatch && queryMatch;
        })
        .toList(growable: false);
  }

  @override
  Widget build(
    BuildContext context,
  ) => StreamBuilder<List<MobileClinicAdminRecord>>(
    stream: widget.repository.watchClinics(),
    builder: (context, clinicSnapshot) =>
        StreamBuilder<List<MobileClinicAdminTour>>(
          stream: widget.repository.watchTours(),
          builder: (context, tourSnapshot) {
            if (clinicSnapshot.hasError || tourSnapshot.hasError) {
              return const Center(
                child: Text('Données momentanément indisponibles.'),
              );
            }
            if (!clinicSnapshot.hasData || !tourSnapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(color: AdminColors.primary),
              );
            }
            final clinics = clinicSnapshot.data!;
            final tours = tourSnapshot.data!;
            final certified = clinics
                .where(
                  (clinic) => clinic.status == MobileClinicAdminStatus.approved,
                )
                .toList();
            final approvedIds = certified.map((clinic) => clinic.id).toSet();
            final zones = <String>{
              for (final clinic in certified) clinic.area,
              for (final tour in tours)
                if (approvedIds.contains(tour.clinicId) &&
                    tour.status != 'cancelled')
                  tour.area,
            }..removeWhere((zone) => zone.replaceAll(',', '').trim().isEmpty);
            final visible = _filtered(clinics);
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(28, 28, 28, 52),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1200),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Réseau Clinique Mobile',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Validez les demandes et suivez la couverture nationale du réseau.',
                      ),
                      const SizedBox(height: 22),
                      _ClinicMetrics(
                        certifiedCount: certified.length,
                        pendingCount: clinics
                            .where(
                              (clinic) =>
                                  clinic.status ==
                                  MobileClinicAdminStatus.pending,
                            )
                            .length,
                        deployedCount: certified
                            .where((clinic) => clinic.isDeployed)
                            .length,
                        zones: zones.toList()..sort(),
                      ),
                      const SizedBox(height: 22),
                      AdminPanel(
                        child: Column(
                          children: [
                            TextField(
                              controller: _searchController,
                              onChanged: (value) =>
                                  setState(() => _query = value),
                              decoration: const InputDecoration(
                                hintText:
                                    'Rechercher une clinique ou une zone…',
                                prefixIcon: Icon(Icons.search_rounded),
                              ),
                            ),
                            const SizedBox(height: 13),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: SegmentedButton<_ClinicAdminFilter>(
                                segments: const [
                                  ButtonSegment(
                                    value: _ClinicAdminFilter.pending,
                                    label: Text('À vérifier'),
                                  ),
                                  ButtonSegment(
                                    value: _ClinicAdminFilter.approved,
                                    label: Text('Certifiées'),
                                  ),
                                  ButtonSegment(
                                    value: _ClinicAdminFilter.rejected,
                                    label: Text('Refusées'),
                                  ),
                                  ButtonSegment(
                                    value: _ClinicAdminFilter.all,
                                    label: Text('Toutes'),
                                  ),
                                ],
                                selected: {_filter},
                                onSelectionChanged: (value) =>
                                    setState(() => _filter = value.first),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      if (visible.isEmpty)
                        const AdminPanel(
                          child: Padding(
                            padding: EdgeInsets.all(18),
                            child: Center(
                              child: Text('Aucune clinique pour ce filtre.'),
                            ),
                          ),
                        )
                      else
                        for (final clinic in visible) ...[
                          _ClinicAdminCard(
                            clinic: clinic,
                            reviewing: _reviewing.contains(clinic.id),
                            onOpen: () => _open(clinic),
                            onApprove: () => _approve(clinic),
                            onReject: () => _reject(clinic),
                          ),
                          const SizedBox(height: 11),
                        ],
                    ],
                  ),
                ),
              ),
            );
          },
        ),
  );
}

class _ClinicMetrics extends StatelessWidget {
  final int certifiedCount;
  final int pendingCount;
  final int deployedCount;
  final List<String> zones;

  const _ClinicMetrics({
    required this.certifiedCount,
    required this.pendingCount,
    required this.deployedCount,
    required this.zones,
  });

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          _MetricCard(
            icon: Icons.verified_rounded,
            value: '$certifiedCount',
            label: 'Cliniques certifiées',
            color: AdminColors.success,
          ),
          _MetricCard(
            icon: Icons.fact_check_outlined,
            value: '$pendingCount',
            label: 'Demandes à vérifier',
            color: AdminColors.warning,
          ),
          _MetricCard(
            icon: Icons.sensors_rounded,
            value: '$deployedCount',
            label: 'Déployées maintenant',
            color: AdminColors.primary,
          ),
          _MetricCard(
            icon: Icons.map_outlined,
            value: '${zones.length}',
            label: 'Zones couvertes',
            color: const Color(0xFF7A5AF8),
          ),
        ],
      ),
      const SizedBox(height: 12),
      AdminPanel(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.public_rounded, color: AdminColors.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Zones couvertes',
                    style: TextStyle(
                      color: AdminColors.ink,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    zones.isEmpty
                        ? 'Aucune zone couverte pour le moment.'
                        : zones.join('  •  '),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class _MetricCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _MetricCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 245,
    child: AdminPanel(
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    color: AdminColors.ink,
                    fontSize: 23,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(label, style: const TextStyle(fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _ClinicAdminCard extends StatelessWidget {
  final MobileClinicAdminRecord clinic;
  final bool reviewing;
  final VoidCallback onOpen;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _ClinicAdminCard({
    required this.clinic,
    required this.reviewing,
    required this.onOpen,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) => AdminPanel(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            color: AdminColors.primarySoft,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(
            Icons.local_shipping_rounded,
            color: AdminColors.primary,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  Text(
                    clinic.name,
                    style: const TextStyle(
                      color: AdminColors.ink,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  _StatusBadge(status: clinic.status),
                ],
              ),
              const SizedBox(height: 5),
              Text('${clinic.creatorLabel} · ${clinic.responsibleName}'),
              const SizedBox(height: 4),
              Text(
                clinic.area,
                style: const TextStyle(
                  color: AdminColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        if (clinic.status == MobileClinicAdminStatus.pending)
          Wrap(
            spacing: 7,
            children: [
              OutlinedButton(
                onPressed: reviewing ? null : onReject,
                child: const Text('Refuser'),
              ),
              FilledButton(
                onPressed: reviewing ? null : onApprove,
                style: FilledButton.styleFrom(
                  backgroundColor: AdminColors.success,
                ),
                child: const Text('Certifier'),
              ),
            ],
          ),
        IconButton(
          tooltip: 'Ouvrir le dossier',
          onPressed: onOpen,
          icon: const Icon(Icons.chevron_right_rounded),
        ),
      ],
    ),
  );
}

class _ClinicReviewDialog extends StatelessWidget {
  final MobileClinicAdminRecord clinic;
  final bool reviewing;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _ClinicReviewDialog({
    required this.clinic,
    required this.reviewing,
    required this.onApprove,
    required this.onReject,
  });

  Future<void> _openDocument(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Row(
      children: [
        const Icon(Icons.local_shipping_rounded, color: AdminColors.primary),
        const SizedBox(width: 10),
        Expanded(child: Text(clinic.name)),
      ],
    ),
    content: SizedBox(
      width: 760,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _StatusBadge(status: clinic.status),
                if (clinic.badge.isNotEmpty)
                  const _InfoPill(
                    icon: Icons.verified_rounded,
                    label: 'Badge i-ENTIER attribué',
                  ),
                if (clinic.isDeployed)
                  const _InfoPill(
                    icon: Icons.sensors_rounded,
                    label: 'Déployée',
                  ),
              ],
            ),
            const SizedBox(height: 18),
            const _DialogHeading('Responsable et structure'),
            _DetailRow(label: 'Type', value: clinic.creatorLabel),
            _DetailRow(label: 'Responsable', value: clinic.responsibleName),
            _DetailRow(label: 'Téléphone', value: clinic.phone),
            _DetailRow(label: 'Courriel', value: clinic.email),
            _DetailRow(label: 'Adresse', value: clinic.baseAddress),
            _DetailRow(label: 'Zone', value: clinic.area),
            _DetailRow(label: 'Description', value: clinic.description),
            const SizedBox(height: 16),
            const _DialogHeading('Vérification documentaire'),
            _DocumentTile(
              label: 'Identité du responsable',
              url: clinic.identityDocumentUrl,
              onOpen: _openDocument,
            ),
            _DocumentTile(
              label: 'Diplôme ou licence professionnelle',
              url: clinic.professionalLicenseUrl,
              optional: true,
              onOpen: _openDocument,
            ),
            _DocumentTile(
              label: 'Autorisation de fonctionnement',
              url: clinic.operatingAuthorizationUrl,
              onOpen: _openDocument,
            ),
            for (
              var index = 0;
              index < clinic.partnerDocumentUrls.length;
              index++
            )
              _DocumentTile(
                label: 'Document partenaire ${index + 1}',
                url: clinic.partnerDocumentUrls[index],
                optional: true,
                onOpen: _openDocument,
              ),
            if (clinic.status == MobileClinicAdminStatus.rejected &&
                clinic.rejectionReason.isNotEmpty) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF0ED),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Text(
                  clinic.rejectionReason,
                  style: const TextStyle(
                    color: AdminColors.danger,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Fermer'),
      ),
      if (clinic.status != MobileClinicAdminStatus.approved)
        OutlinedButton(
          onPressed: reviewing ? null : onReject,
          child: const Text('Refuser'),
        ),
      if (clinic.status != MobileClinicAdminStatus.approved)
        FilledButton.icon(
          onPressed: reviewing ? null : onApprove,
          icon: const Icon(Icons.verified_rounded),
          label: const Text('Certifier'),
          style: FilledButton.styleFrom(backgroundColor: AdminColors.success),
        ),
    ],
  );
}

class _DocumentTile extends StatelessWidget {
  final String label;
  final String url;
  final bool optional;
  final Future<void> Function(String url) onOpen;

  const _DocumentTile({
    required this.label,
    required this.url,
    required this.onOpen,
    this.optional = false,
  });

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Icon(
      url.isEmpty ? Icons.warning_amber_rounded : Icons.description_outlined,
      color: url.isEmpty ? AdminColors.warning : AdminColors.primary,
    ),
    title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
    subtitle: Text(
      url.isEmpty
          ? (optional
                ? 'Non requis pour ce type de créateur'
                : 'Document manquant')
          : url,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    ),
    trailing: url.isEmpty
        ? null
        : IconButton(
            tooltip: 'Ouvrir le document',
            onPressed: () => onOpen(url),
            icon: const Icon(Icons.open_in_new_rounded),
          ),
  );
}

class _StatusBadge extends StatelessWidget {
  final MobileClinicAdminStatus status;
  const _StatusBadge({required this.status});
  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      MobileClinicAdminStatus.pending => AdminColors.warning,
      MobileClinicAdminStatus.approved => AdminColors.success,
      MobileClinicAdminStatus.rejected => AdminColors.danger,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoPill({required this.icon, required this.label});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: AdminColors.primarySoft,
      borderRadius: BorderRadius.circular(99),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AdminColors.primary),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
            color: AdminColors.primaryDark,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}

class _DialogHeading extends StatelessWidget {
  final String text;
  const _DialogHeading(this.text);
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      color: AdminColors.primaryDark,
      fontWeight: FontWeight.w700,
    ),
  );
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 140,
          child: Text(
            label,
            style: const TextStyle(
              color: AdminColors.muted,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(child: Text(value.isEmpty ? '—' : value)),
      ],
    ),
  );
}
