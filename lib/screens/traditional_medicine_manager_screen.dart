import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/traditional_medicine_admin_repository.dart';
import '../models/traditional_medicine_admin.dart';
import '../theme/admin_theme.dart';

class TraditionalMedicineManagerScreen extends StatefulWidget {
  final String adminId;
  final TraditionalMedicineAdminRepository repository;

  const TraditionalMedicineManagerScreen({
    super.key,
    required this.adminId,
    required this.repository,
  });

  @override
  State<TraditionalMedicineManagerScreen> createState() =>
      _TraditionalMedicineManagerScreenState();
}

class _TraditionalMedicineManagerScreenState
    extends State<TraditionalMedicineManagerScreen> {
  int _section = 0;
  final Set<String> _busy = {};

  Future<void> _run(
    String id,
    Future<void> Function() action,
    String success,
  ) async {
    if (_busy.contains(id)) return;
    setState(() => _busy.add(id));
    try {
      await action();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(success)));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Action impossible : $error')));
      }
    } finally {
      if (mounted) setState(() => _busy.remove(id));
    }
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(28, 28, 28, 48),
    children: [
      _Header(
        section: _section,
        onChanged: (value) => setState(() => _section = value),
      ),
      const SizedBox(height: 20),
      if (_section == 0) _applications() else _reports(),
    ],
  );

  Widget _applications() => StreamBuilder<List<TraditionalAdminApplication>>(
    stream: widget.repository.watchApplications(),
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Center(child: CircularProgressIndicator());
      }
      if (snapshot.hasError) {
        return const _AdminFeedback(
          icon: Icons.cloud_off_outlined,
          title: 'Registre indisponible',
          message: 'Impossible de charger les dossiers.',
        );
      }
      final applications = snapshot.data ?? const [];
      if (applications.isEmpty) {
        return const _AdminFeedback(
          icon: Icons.fact_check_outlined,
          title: 'Aucun dossier',
          message: 'Les nouvelles candidatures apparaîtront ici.',
        );
      }
      return Column(
        children: applications
            .map(
              (application) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _ApplicationCard(
                  application: application,
                  busy: _busy.contains(application.providerId),
                  onOpen: () => _openApplication(application),
                ),
              ),
            )
            .toList(growable: false),
      );
    },
  );

  Widget _reports() => StreamBuilder<List<TraditionalSafetyReport>>(
    stream: widget.repository.watchReports(),
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Center(child: CircularProgressIndicator());
      }
      final reports = snapshot.data ?? const [];
      if (snapshot.hasError || reports.isEmpty) {
        return const _AdminFeedback(
          icon: Icons.verified_user_outlined,
          title: 'Aucun signalement à examiner',
          message: 'La file de sécurité est à jour.',
        );
      }
      return Column(
        children: reports
            .map(
              (report) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _ReportCard(
                  report: report,
                  busy: _busy.contains(report.id),
                  onCredible: () => _reviewReport(report, true),
                  onNotCredible: () => _reviewReport(report, false),
                ),
              ),
            )
            .toList(growable: false),
      );
    },
  );

  Future<void> _openApplication(TraditionalAdminApplication application) async {
    await showDialog<void>(
      context: context,
      builder: (context) => _ApplicationDialog(
        application: application,
        adminId: widget.adminId,
        repository: widget.repository,
        onApprove: () {
          Navigator.pop(context);
          _reviewApplication(application, true);
        },
        onReject: () async {
          Navigator.pop(context);
          await _reviewApplication(application, false);
        },
      ),
    );
  }

  Future<void> _reviewApplication(
    TraditionalAdminApplication application,
    bool approved,
  ) async {
    var reason = '';
    if (!approved) {
      reason =
          await _askNote(
            'Motif du refus',
            'Expliquez ce que le praticien doit corriger.',
          ) ??
          '';
      if (reason.isEmpty) return;
    }
    await _run(
      application.providerId,
      () => widget.repository.reviewApplication(
        providerId: application.providerId,
        adminId: widget.adminId,
        approved: approved,
        reason: reason,
      ),
      approved ? 'Praticien vérifié et publiable.' : 'Dossier refusé.',
    );
  }

  Future<void> _reviewReport(
    TraditionalSafetyReport report,
    bool credible,
  ) async {
    final note = await _askNote(
      credible ? 'Signalement crédible' : 'Signalement non crédible',
      credible
          ? 'Justifiez la suspension préventive et l’ouverture de l’enquête.'
          : 'Consignez la raison du classement.',
    );
    if (note == null || note.trim().isEmpty) return;
    await _run(
      report.id,
      () => widget.repository.reviewReport(
        reportId: report.id,
        adminId: widget.adminId,
        credible: credible,
        note: note,
      ),
      credible
          ? 'Signalement crédible : profil suspendu préventivement.'
          : 'Signalement classé comme non crédible.',
    );
  }

  Future<String?> _askNote(String title, String hint) async {
    return showDialog<String>(
      context: context,
      builder: (context) =>
          _TraditionalAdminNoteDialog(title: title, hint: hint),
    );
  }
}

class _TraditionalAdminNoteDialog extends StatefulWidget {
  final String title;
  final String hint;

  const _TraditionalAdminNoteDialog({required this.title, required this.hint});

  @override
  State<_TraditionalAdminNoteDialog> createState() =>
      _TraditionalAdminNoteDialogState();
}

class _TraditionalAdminNoteDialogState
    extends State<_TraditionalAdminNoteDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: TextField(
      key: const ValueKey('traditional-admin-note'),
      controller: _controller,
      minLines: 3,
      maxLines: 6,
      maxLength: 1000,
      decoration: InputDecoration(
        hintText: widget.hint,
        alignLabelWithHint: true,
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Annuler'),
      ),
      FilledButton(
        key: const ValueKey('traditional-admin-confirm-note'),
        onPressed: () => Navigator.pop(context, _controller.text.trim()),
        child: const Text('Confirmer'),
      ),
    ],
  );
}

class _Header extends StatelessWidget {
  final int section;
  final ValueChanged<int> onChanged;
  const _Header({required this.section, required this.onChanged});

  @override
  Widget build(BuildContext context) => AdminPanel(
    child: Wrap(
      alignment: WrapAlignment.spaceBetween,
      runAlignment: WrapAlignment.center,
      spacing: 18,
      runSpacing: 14,
      children: [
        const SizedBox(
          width: 520,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Médecine Traditionnelle',
                style: TextStyle(
                  color: AdminColors.ink,
                  fontSize: 25,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 5),
              Text(
                'Validation des praticiens, justificatifs, score de confiance et sécurité.',
                style: TextStyle(color: AdminColors.muted),
              ),
            ],
          ),
        ),
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(
              value: 0,
              icon: Icon(Icons.fact_check_outlined),
              label: Text('Dossiers'),
            ),
            ButtonSegment(
              value: 1,
              icon: Icon(Icons.report_outlined),
              label: Text('Signalements'),
            ),
          ],
          selected: {section},
          onSelectionChanged: (value) => onChanged(value.first),
        ),
      ],
    ),
  );
}

class _ApplicationCard extends StatelessWidget {
  final TraditionalAdminApplication application;
  final bool busy;
  final VoidCallback onOpen;
  const _ApplicationCard({
    required this.application,
    required this.busy,
    required this.onOpen,
  });
  @override
  Widget build(BuildContext context) => AdminPanel(
    child: Row(
      children: [
        CircleAvatar(
          backgroundColor: AdminColors.primarySoft,
          foregroundColor: AdminColors.primary,
          child: Text(
            application.displayName.isEmpty ? '?' : application.displayName[0],
          ),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                application.displayName,
                style: const TextStyle(
                  color: AdminColors.ink,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${application.experienceYears} ans • ${application.practiceDomains.join(', ')}',
                style: const TextStyle(color: AdminColors.muted),
              ),
            ],
          ),
        ),
        _StatusChip(status: application.validationStatus),
        const SizedBox(width: 10),
        IconButton(
          key: ValueKey('traditional-admin-open-${application.providerId}'),
          onPressed: busy ? null : onOpen,
          icon: busy
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.chevron_right_rounded),
        ),
      ],
    ),
  );
}

class _ApplicationDialog extends StatelessWidget {
  final TraditionalAdminApplication application;
  final String adminId;
  final TraditionalMedicineAdminRepository repository;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  const _ApplicationDialog({
    required this.application,
    required this.adminId,
    required this.repository,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(application.displayName),
    content: SizedBox(
      width: 680,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _InfoLine(
              label: 'Expérience',
              value: '${application.experienceYears} ans',
            ),
            _InfoLine(
              label: 'Domaines',
              value: application.practiceDomains.join(', '),
            ),
            _InfoLine(
              label: 'Langues',
              value: application.languages.join(', '),
            ),
            _InfoLine(
              label: 'Zones',
              value: application.interventionZones.join(', '),
            ),
            const Divider(height: 26),
            const Text(
              'Justificatifs',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            StreamBuilder<List<TraditionalAdminDocument>>(
              stream: repository.watchDocuments(application.providerId),
              builder: (context, snapshot) {
                final documents = snapshot.data ?? const [];
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const LinearProgressIndicator();
                }
                if (documents.isEmpty) {
                  return const Text(
                    'Aucun justificatif déposé.',
                    style: TextStyle(color: AdminColors.danger),
                  );
                }
                return Column(
                  children: documents
                      .map(
                        (document) => _DocumentRow(
                          document: document,
                          adminId: adminId,
                          repository: repository,
                        ),
                      )
                      .toList(growable: false),
                );
              },
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Fermer'),
      ),
      OutlinedButton.icon(
        onPressed: onReject,
        icon: const Icon(Icons.close_rounded),
        label: const Text('Refuser'),
      ),
      FilledButton.icon(
        key: const ValueKey('traditional-admin-approve'),
        onPressed: onApprove,
        icon: const Icon(Icons.verified_rounded),
        label: const Text('Approuver'),
      ),
    ],
  );
}

class _DocumentRow extends StatefulWidget {
  final TraditionalAdminDocument document;
  final String adminId;
  final TraditionalMedicineAdminRepository repository;
  const _DocumentRow({
    required this.document,
    required this.adminId,
    required this.repository,
  });
  @override
  State<_DocumentRow> createState() => _DocumentRowState();
}

class _DocumentRowState extends State<_DocumentRow> {
  bool _busy = false;
  Future<void> _open() async {
    setState(() => _busy = true);
    try {
      final url = await widget.repository.createDocumentReviewUrl(
        widget.document.storagePath,
      );
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _review(bool verified) async {
    setState(() => _busy = true);
    try {
      await widget.repository.reviewDocument(
        documentId: widget.document.id,
        adminId: widget.adminId,
        verified: verified,
        note: verified ? '' : 'Document illisible ou non conforme.',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: const Icon(Icons.description_outlined),
    title: Text(widget.document.fileName),
    subtitle: Text('${widget.document.type} • ${widget.document.reviewStatus}'),
    onTap: _busy ? null : _open,
    trailing: widget.document.reviewStatus == 'pending'
        ? Wrap(
            children: [
              IconButton(
                key: ValueKey('reject-document-${widget.document.id}'),
                onPressed: _busy ? null : () => _review(false),
                icon: const Icon(
                  Icons.close_rounded,
                  color: AdminColors.danger,
                ),
              ),
              IconButton(
                key: ValueKey('approve-document-${widget.document.id}'),
                onPressed: _busy ? null : () => _review(true),
                icon: const Icon(
                  Icons.check_rounded,
                  color: AdminColors.success,
                ),
              ),
            ],
          )
        : Icon(
            widget.document.reviewStatus == 'verified'
                ? Icons.verified_rounded
                : Icons.error_outline,
            color: widget.document.reviewStatus == 'verified'
                ? AdminColors.success
                : AdminColors.danger,
          ),
  );
}

class _ReportCard extends StatelessWidget {
  final TraditionalSafetyReport report;
  final bool busy;
  final VoidCallback onCredible;
  final VoidCallback onNotCredible;
  const _ReportCard({
    required this.report,
    required this.busy,
    required this.onCredible,
    required this.onNotCredible,
  });
  @override
  Widget build(BuildContext context) => AdminPanel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.report_gmailerrorred_outlined,
              color: AdminColors.danger,
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                report.practitionerName,
                style: const TextStyle(
                  color: AdminColors.ink,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            _StatusChip(status: report.credibilityStatus),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          report.category,
          style: const TextStyle(
            color: AdminColors.danger,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          report.details,
          style: const TextStyle(color: AdminColors.muted, height: 1.4),
        ),
        if (report.credibilityStatus == 'pending_review') ...[
          const SizedBox(height: 13),
          Wrap(
            spacing: 9,
            children: [
              OutlinedButton(
                onPressed: busy ? null : onNotCredible,
                child: const Text('Non crédible'),
              ),
              FilledButton.icon(
                key: ValueKey('credible-report-${report.id}'),
                onPressed: busy ? null : onCredible,
                style: FilledButton.styleFrom(
                  backgroundColor: AdminColors.danger,
                ),
                icon: const Icon(Icons.gpp_maybe_outlined),
                label: const Text('Crédible : suspendre'),
              ),
            ],
          ),
        ],
      ],
    ),
  );
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});
  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'approved' || 'credible' || 'verified' => AdminColors.success,
      'rejected' || 'suspended' || 'not_credible' => AdminColors.danger,
      _ => AdminColors.warning,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        status.replaceAll('_', ' '),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  final String label;
  final String value;
  const _InfoLine({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(label, style: const TextStyle(color: AdminColors.muted)),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: AdminColors.ink,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );
}

class _AdminFeedback extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  const _AdminFeedback({
    required this.icon,
    required this.title,
    required this.message,
  });
  @override
  Widget build(BuildContext context) => AdminPanel(
    child: Column(
      children: [
        Icon(icon, size: 42, color: AdminColors.primary),
        const SizedBox(height: 10),
        Text(
          title,
          style: const TextStyle(
            color: AdminColors.ink,
            fontWeight: FontWeight.w700,
            fontSize: 17,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AdminColors.muted),
        ),
      ],
    ),
  );
}
