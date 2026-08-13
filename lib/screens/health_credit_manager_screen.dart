import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/health_credit_admin_repository.dart';
import '../models/health_credit_admin_models.dart';
import '../supabase_config.dart';
import '../theme/admin_theme.dart';

enum _CreditAdminView { overview, applications, payments, solidarity }

class HealthCreditManagerScreen extends StatefulWidget {
  final User user;
  final HealthCreditAdminRepository repository;

  const HealthCreditManagerScreen({
    super.key,
    required this.user,
    required this.repository,
  });

  @override
  State<HealthCreditManagerScreen> createState() =>
      _HealthCreditManagerScreenState();
}

class _HealthCreditManagerScreenState extends State<HealthCreditManagerScreen> {
  late Stream<HealthCreditAdminDashboardData> _dashboard;
  _CreditAdminView _view = _CreditAdminView.overview;
  final Set<String> _busy = {};

  @override
  void initState() {
    super.initState();
    _reload();
    widget.repository.refreshOverdues(widget.user.uid).catchError((_) {});
  }

  void _reload() => _dashboard = widget.repository.watchDashboard();

  void _refresh() => setState(_reload);

  Future<void> _run(
    String id,
    Future<void> Function() action,
    String success,
  ) async {
    setState(() => _busy.add(id));
    try {
      await action();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(success)));
      _refresh();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'L’action n’a pas pu être enregistrée. Vérifiez les critères et réessayez.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy.remove(id));
    }
  }

  Future<void> _validateReference(
    AdminHealthCreditReference reference,
    bool valid,
  ) async {
    String note = '';
    if (!valid) {
      final value = await _askReason(
        'Refuser cette référence',
        'Indiquez pourquoi cette personne ne peut pas valider le dossier.',
      );
      if (value == null) return;
      note = value;
    }
    await _run(
      reference.id,
      () => widget.repository.validateReference(
        referenceId: reference.id,
        adminId: widget.user.uid,
        valid: valid,
        note: note,
      ),
      valid ? 'Référence validée.' : 'Référence refusée.',
    );
  }

  Future<void> _reviewApplication(
    AdminHealthCreditApplication application,
    bool approve,
  ) async {
    String reason = '';
    if (!approve) {
      final value = await _askReason(
        'Refuser la demande de crédit',
        'Le motif sera visible par le patient.',
      );
      if (value == null) return;
      reason = value;
    } else {
      final confirmed = await _confirm(
        title: 'Approuver ${_money(application.requestedAmount)} ?',
        message:
            'Un crédit de ${application.installments} échéances sera activé avec un Score Santé Financier initial de 100.',
        action: 'Approuver',
      );
      if (!confirmed) return;
    }
    await _run(
      application.id,
      () => widget.repository.reviewApplication(
        applicationId: application.id,
        adminId: widget.user.uid,
        approve: approve,
        reason: reason,
      ),
      approve ? 'Crédit approuvé et échéancier créé.' : 'Demande refusée.',
    );
  }

  Future<void> _reviewPayment(AdminHealthPayment payment, bool confirm) async {
    String reason = '';
    if (!confirm) {
      final value = await _askReason(
        'Rejeter le paiement',
        'Indiquez pourquoi la preuve ou la transaction est invalide.',
      );
      if (value == null) return;
      reason = value;
    } else {
      final accepted = await _confirm(
        title: 'Confirmer ${_money(payment.amount)} ?',
        message:
            'Le montant sera imputé aux premières échéances ouvertes et le score du patient sera recalculé.',
        action: 'Confirmer',
      );
      if (!accepted) return;
    }
    await _run(
      payment.id,
      () => widget.repository.reviewPayment(
        paymentId: payment.id,
        adminId: widget.user.uid,
        confirm: confirm,
        reason: reason,
      ),
      confirm ? 'Paiement confirmé et score mis à jour.' : 'Paiement rejeté.',
    );
  }

  Future<void> _flagDefault(String creditId) async {
    final decision = await showDialog<_DefaultDecision>(
      context: context,
      builder: (_) => const _DefaultReviewDialog(),
    );
    if (decision == null) return;
    await _run(
      'default-$creditId',
      () => widget.repository.flagDefault(
        creditId: creditId,
        adminId: widget.user.uid,
        hasJustification: decision.hasJustification,
        justification: decision.justification,
      ),
      decision.hasJustification
          ? 'La justification a été consignée sans pénalité.'
          : 'Défaut enregistré et accès temporairement suspendu.',
    );
  }

  Future<String?> _askReason(String title, String helper) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 460,
          child: TextField(
            controller: controller,
            maxLines: 4,
            maxLength: 500,
            decoration: InputDecoration(
              labelText: 'Motif obligatoire',
              helperText: helper,
              helperMaxLines: 2,
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
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String action,
  }) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          icon: const Icon(
            Icons.verified_outlined,
            color: AdminColors.success,
            size: 34,
          ),
          title: Text(title),
          content: Text(message, textAlign: TextAlign.center),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(
                backgroundColor: AdminColors.success,
              ),
              child: Text(action),
            ),
          ],
        ),
      ) ??
      false;

  Future<void> _openDocument(AdminHealthCreditDocument document) async {
    try {
      final url = await widget.repository.createDocumentUrl(
        document.storagePath,
      );
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossible d’ouvrir ce justificatif.')),
        );
      }
    }
  }

  Future<void> _manageSolidarity(
    AdminSolidarityRequest request,
    List<AdminPartnerCenter> centers,
  ) async {
    final decision = await showDialog<_SolidarityDecision>(
      context: context,
      builder: (_) =>
          _SolidarityManagementDialog(request: request, centers: centers),
    );
    if (decision == null) return;
    await _run(
      request.id,
      () => widget.repository.manageSolidarity(
        requestId: request.id,
        adminId: widget.user.uid,
        status: decision.status,
        approvedAmount: decision.approvedAmount,
        fundedAmount: decision.fundedAmount,
        centerId: decision.centerId,
        socialWorker: decision.socialWorker,
        medicalCoordinator: decision.medicalCoordinator,
        followUpNote: decision.followUpNote,
      ),
      'Dossier solidaire mis à jour.',
    );
  }

  @override
  Widget build(BuildContext context) =>
      StreamBuilder<HealthCreditAdminDashboardData>(
        stream: _dashboard,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: AdminColors.primary),
            );
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return _CreditAdminError(onRetry: _refresh);
          }
          final data = snapshot.data!;
          return Column(
            children: [
              _CreditAdminHeader(
                view: _view,
                onChanged: (value) => setState(() => _view = value),
                onRefresh: _refresh,
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(22, 22, 22, 38),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1240),
                      child: switch (_view) {
                        _CreditAdminView.overview => _OverviewDashboard(
                          data: data,
                          onFlagDefault: _flagDefault,
                        ),
                        _CreditAdminView.applications => _ApplicationsDashboard(
                          data: data,
                          busy: _busy,
                          onReference: _validateReference,
                          onReview: _reviewApplication,
                          onDocument: _openDocument,
                        ),
                        _CreditAdminView.payments => _PaymentsDashboard(
                          data: data,
                          busy: _busy,
                          onReview: _reviewPayment,
                        ),
                        _CreditAdminView.solidarity => _SolidarityDashboard(
                          data: data,
                          busy: _busy,
                          onManage: _manageSolidarity,
                        ),
                      },
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      );
}

class _CreditAdminHeader extends StatelessWidget {
  final _CreditAdminView view;
  final ValueChanged<_CreditAdminView> onChanged;
  final VoidCallback onRefresh;
  const _CreditAdminHeader({
    required this.view,
    required this.onChanged,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) => Container(
    color: Colors.white,
    padding: const EdgeInsets.fromLTRB(22, 18, 14, 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 52,
              height: 52,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AdminColors.primarySoft,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Image.asset(
                'assets/services/health_credit_3d.png',
                fit: BoxFit.contain,
                semanticLabel: 'Crédit Santé',
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Crédit Santé',
                    style: TextStyle(
                      color: AdminColors.ink,
                      fontSize: 21,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    'Financement, risque et accompagnement social',
                    style: TextStyle(color: AdminColors.muted, fontSize: 12),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: onRefresh,
              tooltip: 'Actualiser',
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        const SizedBox(height: 14),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SegmentedButton<_CreditAdminView>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(
                value: _CreditAdminView.overview,
                icon: Icon(Icons.dashboard_outlined),
                label: Text('Vue d’ensemble'),
              ),
              ButtonSegment(
                value: _CreditAdminView.applications,
                icon: Icon(Icons.fact_check_outlined),
                label: Text('Demandes'),
              ),
              ButtonSegment(
                value: _CreditAdminView.payments,
                icon: Icon(Icons.payments_outlined),
                label: Text('Paiements'),
              ),
              ButtonSegment(
                value: _CreditAdminView.solidarity,
                icon: Icon(Icons.volunteer_activism_outlined),
                label: Text('Vulnérabilité & solidarité'),
              ),
            ],
            selected: {view},
            onSelectionChanged: (values) => onChanged(values.first),
          ),
        ),
      ],
    ),
  );
}

class _OverviewDashboard extends StatelessWidget {
  final HealthCreditAdminDashboardData data;
  final ValueChanged<String> onFlagDefault;
  const _OverviewDashboard({required this.data, required this.onFlagDefault});
  @override
  Widget build(BuildContext context) {
    final metrics = [
      (
        'Demandes de crédit',
        '${data.applications.length}',
        Icons.request_quote_outlined,
        AdminColors.primary,
      ),
      (
        'Crédits actifs',
        '${data.activeCredits}',
        Icons.credit_score_outlined,
        AdminColors.success,
      ),
      (
        'Taux de remboursement',
        '${(data.repaymentRate * 100).toStringAsFixed(1)} %',
        Icons.donut_large_outlined,
        AdminColors.primary,
      ),
      (
        'Score moyen',
        data.averageScore.toStringAsFixed(1),
        Icons.speed_outlined,
        const Color(0xFF7A5AF8),
      ),
      (
        'Patients vulnérables',
        '${data.vulnerablePatients}',
        Icons.people_outline_rounded,
        AdminColors.warning,
      ),
      (
        'Dossiers solidaires financés',
        '${data.fundedCases}',
        Icons.volunteer_activism_outlined,
        AdminColors.success,
      ),
      (
        'Alertes de retard',
        '${data.lateInstallments}',
        Icons.warning_amber_rounded,
        AdminColors.danger,
      ),
    ];
    final late = data.installments
        .where((item) => item.status == 'late')
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _AdminCreditTitle(
          title: 'Tableau de bord',
          subtitle:
              'Vue consolidée des crédits, remboursements et prises en charge solidaires.',
        ),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 1040
                ? 4
                : constraints.maxWidth >= 650
                ? 2
                : 1;
            const gap = 14.0;
            final width =
                (constraints.maxWidth - gap * (columns - 1)) / columns;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (final metric in metrics)
                  SizedBox(
                    width: width,
                    child: _AdminCreditMetric(
                      label: metric.$1,
                      value: metric.$2,
                      icon: metric.$3,
                      color: metric.$4,
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 22),
        AdminPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Alertes sur les retards de paiement',
                style: TextStyle(
                  color: AdminColors.ink,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              if (late.isEmpty)
                const _AdminEmptyLine(
                  icon: Icons.verified_outlined,
                  text: 'Aucune échéance en retard.',
                )
              else
                for (final item in late.take(12))
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFFFECE9),
                      child: Icon(
                        Icons.warning_amber_rounded,
                        color: AdminColors.danger,
                      ),
                    ),
                    title: Text(
                      'Crédit ${_shortId(item.creditId)}',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: Text('Échéance du ${_date(item.dueDate)}'),
                    trailing: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          _money(item.due - item.paid),
                          style: const TextStyle(
                            color: AdminColors.danger,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Qualifier le défaut',
                          onPressed: () => onFlagDefault(item.creditId),
                          icon: const Icon(Icons.gavel_outlined, size: 20),
                        ),
                      ],
                    ),
                  ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        AdminPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Score et niveau de risque des patients',
                style: TextStyle(
                  color: AdminColors.ink,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              if (data.credits.isEmpty)
                const _AdminEmptyLine(
                  icon: Icons.speed_outlined,
                  text: 'Aucun score disponible.',
                )
              else
                for (final credit in data.credits.take(12))
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: _riskColor(
                        credit.score,
                      ).withValues(alpha: .1),
                      child: Text(
                        '${credit.score}',
                        style: TextStyle(
                          color: _riskColor(credit.score),
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    title: Text(
                      'Patient ${_shortId(credit.patientId)}',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: Text('Solde ${_money(credit.balance)}'),
                    trailing: _AdminStatus(
                      text: _riskLabel(credit.score),
                      color: _riskColor(credit.score),
                    ),
                  ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ApplicationsDashboard extends StatelessWidget {
  final HealthCreditAdminDashboardData data;
  final Set<String> busy;
  final Future<void> Function(AdminHealthCreditReference, bool) onReference;
  final Future<void> Function(AdminHealthCreditApplication, bool) onReview;
  final Future<void> Function(AdminHealthCreditDocument) onDocument;
  const _ApplicationsDashboard({
    required this.data,
    required this.busy,
    required this.onReference,
    required this.onReview,
    required this.onDocument,
  });
  @override
  Widget build(BuildContext context) {
    final applications = [...data.applications]
      ..sort((a, b) {
        final aPending = const {
          'pending_references',
          'under_review',
        }.contains(a.status);
        final bPending = const {
          'pending_references',
          'under_review',
        }.contains(b.status);
        if (aPending != bPending) return aPending ? -1 : 1;
        return b.createdAt.compareTo(a.createdAt);
      });
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _AdminCreditTitle(
          title: 'Demandes de crédit',
          subtitle:
              '${applications.where((item) => const {'pending_references', 'under_review'}.contains(item.status)).length} dossier(s) nécessitent une décision.',
        ),
        const SizedBox(height: 18),
        if (applications.isEmpty)
          const _AdminEmptyLine(
            icon: Icons.inbox_outlined,
            text: 'Aucune demande de crédit.',
          )
        else
          for (final application in applications)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _ApplicationAdminCard(
                application: application,
                busy: busy,
                onReference: onReference,
                onReview: onReview,
                onDocument: onDocument,
              ),
            ),
      ],
    );
  }
}

class _ApplicationAdminCard extends StatelessWidget {
  final AdminHealthCreditApplication application;
  final Set<String> busy;
  final Future<void> Function(AdminHealthCreditReference, bool) onReference;
  final Future<void> Function(AdminHealthCreditApplication, bool) onReview;
  final Future<void> Function(AdminHealthCreditDocument) onDocument;
  const _ApplicationAdminCard({
    required this.application,
    required this.busy,
    required this.onReference,
    required this.onReview,
    required this.onDocument,
  });
  @override
  Widget build(BuildContext context) {
    final pending = const {
      'pending_references',
      'under_review',
    }.contains(application.status);
    final approvable =
        application.validatedReferences >= 3 &&
        application.preliminaryScore >= 60;
    return AdminPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 50,
                height: 50,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AdminColors.primarySoft,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(
                  Icons.health_and_safety_outlined,
                  color: AdminColors.primary,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      application.patientName,
                      style: const TextStyle(
                        color: AdminColors.ink,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      '${_money(application.requestedAmount)} • ${application.installments} échéances de ${_money(application.estimatedInstallment)}',
                      style: const TextStyle(color: AdminColors.muted),
                    ),
                  ],
                ),
              ),
              _AdminStatus(
                text: _applicationStatus(application.status),
                color: pending
                    ? AdminColors.warning
                    : application.status == 'approved'
                    ? AdminColors.success
                    : AdminColors.danger,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _DataPill(label: 'Revenus', value: _money(application.income)),
              _DataPill(label: 'Dépenses', value: _money(application.expenses)),
              _DataPill(
                label: 'Reste à vivre',
                value: _money(application.disposable),
              ),
              _DataPill(
                label: 'Score préliminaire',
                value: '${application.preliminaryScore}/100',
              ),
              _DataPill(
                label: 'Références validées',
                value:
                    '${application.validatedReferences}/${application.references.length}',
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            application.medicalReason,
            style: const TextStyle(color: AdminColors.ink, height: 1.45),
          ),
          if (application.employer.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 7),
              child: Text(
                'Employeur : ${application.employer}',
                style: const TextStyle(color: AdminColors.muted),
              ),
            ),
          if (application.documents.isNotEmpty) ...[
            const Divider(height: 28),
            const Text(
              'Justificatifs de revenus',
              style: TextStyle(
                color: AdminColors.ink,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final document in application.documents)
                  OutlinedButton.icon(
                    onPressed: () => onDocument(document),
                    icon: const Icon(Icons.description_outlined, size: 18),
                    label: Text(document.fileName),
                  ),
              ],
            ),
          ],
          const Divider(height: 28),
          const Text(
            'Validation des références',
            style: TextStyle(
              color: AdminColors.ink,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          for (final reference in application.references)
            _ReferenceAdminTile(
              reference: reference,
              busy: busy.contains(reference.id),
              onReview: (valid) => onReference(reference, valid),
            ),
          if (pending) ...[
            const Divider(height: 26),
            if (busy.contains(application.id))
              const LinearProgressIndicator()
            else
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => onReview(application, false),
                      icon: const Icon(Icons.close_rounded),
                      label: const Text('Refuser'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: approvable
                          ? () => onReview(application, true)
                          : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: AdminColors.success,
                      ),
                      icon: const Icon(Icons.check_rounded),
                      label: const Text('Approuver'),
                    ),
                  ),
                ],
              ),
            if (!approvable)
              const Padding(
                padding: EdgeInsets.only(top: 9),
                child: Text(
                  'L’approbation requiert au moins 3 références validées et un score préliminaire de 60.',
                  style: TextStyle(color: AdminColors.warning, fontSize: 12),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _ReferenceAdminTile extends StatelessWidget {
  final AdminHealthCreditReference reference;
  final bool busy;
  final ValueChanged<bool> onReview;
  const _ReferenceAdminTile({
    required this.reference,
    required this.busy,
    required this.onReview,
  });
  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: CircleAvatar(
      backgroundColor: AdminColors.primarySoft,
      child: Icon(
        reference.type == 'guarantor'
            ? Icons.handshake_outlined
            : Icons.groups_outlined,
        color: AdminColors.primary,
      ),
    ),
    title: Text(
      reference.name,
      style: const TextStyle(fontWeight: FontWeight.w800),
    ),
    subtitle: Text(
      '${reference.phone} • ${reference.relationship}${reference.note.isEmpty ? '' : '\n${reference.note}'}',
    ),
    trailing: busy
        ? const SizedBox.square(
            dimension: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : reference.status == 'pending'
        ? Wrap(
            spacing: 4,
            children: [
              IconButton(
                onPressed: () => onReview(false),
                tooltip: 'Refuser',
                icon: const Icon(
                  Icons.close_rounded,
                  color: AdminColors.danger,
                ),
              ),
              IconButton(
                onPressed: () => onReview(true),
                tooltip: 'Valider',
                icon: const Icon(
                  Icons.check_rounded,
                  color: AdminColors.success,
                ),
              ),
            ],
          )
        : _AdminStatus(
            text: reference.status == 'validated' ? 'Validée' : 'Refusée',
            color: reference.status == 'validated'
                ? AdminColors.success
                : AdminColors.danger,
          ),
  );
}

class _PaymentsDashboard extends StatelessWidget {
  final HealthCreditAdminDashboardData data;
  final Set<String> busy;
  final Future<void> Function(AdminHealthPayment, bool) onReview;
  const _PaymentsDashboard({
    required this.data,
    required this.busy,
    required this.onReview,
  });
  @override
  Widget build(BuildContext context) {
    final payments = [...data.payments]
      ..sort((a, b) {
        if ((a.status == 'pending') != (b.status == 'pending')) {
          return a.status == 'pending' ? -1 : 1;
        }
        return b.createdAt.compareTo(a.createdAt);
      });
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _AdminCreditTitle(
          title: 'Paiements',
          subtitle:
              '${payments.where((item) => item.status == 'pending').length} transaction(s) à confirmer.',
        ),
        const SizedBox(height: 18),
        AdminPanel(
          child: payments.isEmpty
              ? const _AdminEmptyLine(
                  icon: Icons.receipt_long_outlined,
                  text: 'Aucun paiement déclaré.',
                )
              : Column(
                  children: [
                    for (final payment in payments)
                      _PaymentAdminTile(
                        payment: payment,
                        busy: busy.contains(payment.id),
                        onReview: onReview,
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _PaymentAdminTile extends StatelessWidget {
  final AdminHealthPayment payment;
  final bool busy;
  final Future<void> Function(AdminHealthPayment, bool) onReview;
  const _PaymentAdminTile({
    required this.payment,
    required this.busy,
    required this.onReview,
  });
  @override
  Widget build(BuildContext context) => Column(
    children: [
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const CircleAvatar(
          backgroundColor: AdminColors.primarySoft,
          child: Icon(Icons.payments_outlined, color: AdminColors.primary),
        ),
        title: Text(
          _money(payment.amount),
          style: const TextStyle(
            color: AdminColors.ink,
            fontWeight: FontWeight.w900,
          ),
        ),
        subtitle: Text(
          'Patient ${_shortId(payment.patientId)} • ${_method(payment.method)} • ${_date(payment.createdAt)}${payment.reference.isEmpty ? '' : '\nRéf. ${payment.reference}'}',
        ),
        trailing: busy
            ? const CircularProgressIndicator()
            : payment.status == 'pending'
            ? Wrap(
                spacing: 5,
                children: [
                  OutlinedButton(
                    onPressed: () => onReview(payment, false),
                    child: const Text('Rejeter'),
                  ),
                  FilledButton(
                    onPressed: () => onReview(payment, true),
                    style: FilledButton.styleFrom(
                      backgroundColor: AdminColors.success,
                    ),
                    child: const Text('Confirmer'),
                  ),
                ],
              )
            : _AdminStatus(
                text: payment.status == 'confirmed' ? 'Confirmé' : 'Rejeté',
                color: payment.status == 'confirmed'
                    ? AdminColors.success
                    : AdminColors.danger,
              ),
      ),
      const Divider(height: 1),
    ],
  );
}

class _SolidarityDashboard extends StatelessWidget {
  final HealthCreditAdminDashboardData data;
  final Set<String> busy;
  final Future<void> Function(AdminSolidarityRequest, List<AdminPartnerCenter>)
  onManage;
  const _SolidarityDashboard({
    required this.data,
    required this.busy,
    required this.onManage,
  });
  @override
  Widget build(BuildContext context) {
    final vulnerable = data.assessments
        .where((item) => item.vulnerable)
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _AdminCreditTitle(
          title: 'Vulnérabilité et Financement Solidaire',
          subtitle:
              '${data.vulnerablePatients} patient(s) vulnérable(s) • ${data.solidarityRequests.length} dossier(s) de financement.',
        ),
        const SizedBox(height: 18),
        AdminPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Patients identifiés comme vulnérables',
                style: TextStyle(
                  color: AdminColors.ink,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              if (vulnerable.isEmpty)
                const _AdminEmptyLine(
                  icon: Icons.people_outline,
                  text: 'Aucun patient identifié.',
                )
              else
                for (final item in vulnerable.take(20))
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: const Color(0xFFFFF2DD),
                      child: Text(
                        '${item.score}',
                        style: const TextStyle(
                          color: AdminColors.warning,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    title: Text(
                      'Patient ${_shortId(item.patientId)}',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: Text('Évaluation du ${_date(item.assessedAt)}'),
                    trailing: _AdminStatus(
                      text: item.level == 'critical'
                          ? 'Critique'
                          : 'Vulnérable',
                      color: item.level == 'critical'
                          ? AdminColors.danger
                          : AdminColors.warning,
                    ),
                  ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        if (data.solidarityRequests.isEmpty)
          const _AdminEmptyLine(
            icon: Icons.volunteer_activism_outlined,
            text: 'Aucun dossier de Financement Solidaire.',
          )
        else
          for (final request in data.solidarityRequests)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: AdminPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Patient ${_shortId(request.patientId)}',
                            style: const TextStyle(
                              color: AdminColors.ink,
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        _AdminStatus(
                          text: _solidarityStatus(request.status),
                          color: _solidarityColor(request.status),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      request.medicalNeed,
                      style: const TextStyle(
                        color: AdminColors.ink,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 14,
                      children: [
                        Text('Demandé ${_money(request.requestedAmount)}'),
                        Text('Approuvé ${_money(request.approvedAmount)}'),
                        Text('Financé ${_money(request.fundedAmount)}'),
                      ],
                    ),
                    if (request.socialWorker.isNotEmpty ||
                        request.medicalCoordinator.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Text(
                          'Équipe : ${[request.socialWorker, request.medicalCoordinator].where((v) => v.isNotEmpty).join(' • ')}',
                          style: const TextStyle(color: AdminColors.muted),
                        ),
                      ),
                    if (request.followUpNote.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 7),
                        child: Text(
                          request.followUpNote,
                          style: const TextStyle(color: AdminColors.muted),
                        ),
                      ),
                    const SizedBox(height: 14),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton.icon(
                        onPressed: busy.contains(request.id)
                            ? null
                            : () => onManage(request, data.partnerCenters),
                        icon: const Icon(Icons.edit_note_rounded),
                        label: const Text('Mettre à jour le suivi'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
      ],
    );
  }
}

class _SolidarityManagementDialog extends StatefulWidget {
  final AdminSolidarityRequest request;
  final List<AdminPartnerCenter> centers;
  const _SolidarityManagementDialog({
    required this.request,
    required this.centers,
  });
  @override
  State<_SolidarityManagementDialog> createState() =>
      _SolidarityManagementDialogState();
}

class _DefaultReviewDialog extends StatefulWidget {
  const _DefaultReviewDialog();

  @override
  State<_DefaultReviewDialog> createState() => _DefaultReviewDialogState();
}

class _DefaultReviewDialogState extends State<_DefaultReviewDialog> {
  final _justification = TextEditingController();
  bool _hasJustification = false;

  @override
  void dispose() {
    _justification.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Qualifier le défaut de paiement'),
    content: SizedBox(
      width: 500,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _hasJustification,
            onChanged: (value) => setState(() => _hasJustification = value),
            title: const Text('Le patient a fourni une justification'),
          ),
          if (_hasJustification)
            TextField(
              controller: _justification,
              maxLines: 3,
              maxLength: 1000,
              decoration: const InputDecoration(
                labelText: 'Justification du patient',
                alignLabelWithHint: true,
              ),
            )
          else
            const _AdminEmptyLine(
              icon: Icons.lock_clock_outlined,
              text:
                  'Sans justification, le score perdra 30 points et l’accès sera suspendu pendant 180 jours.',
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
        onPressed: () {
          if (_hasJustification && _justification.text.trim().isEmpty) return;
          Navigator.pop(
            context,
            _DefaultDecision(
              hasJustification: _hasJustification,
              justification: _justification.text.trim(),
            ),
          );
        },
        style: FilledButton.styleFrom(
          backgroundColor: _hasJustification
              ? AdminColors.primary
              : AdminColors.danger,
        ),
        child: Text(_hasJustification ? 'Consigner' : 'Suspendre'),
      ),
    ],
  );
}

class _DefaultDecision {
  final bool hasJustification;
  final String justification;

  const _DefaultDecision({
    required this.hasJustification,
    required this.justification,
  });
}

class _SolidarityManagementDialogState
    extends State<_SolidarityManagementDialog> {
  final _key = GlobalKey<FormState>();
  late final TextEditingController _approved;
  late final TextEditingController _funded;
  late final TextEditingController _social;
  late final TextEditingController _medical;
  late final TextEditingController _note;
  late String _status;
  String? _center;
  @override
  void initState() {
    super.initState();
    final r = widget.request;
    _approved = TextEditingController(
      text: r.approvedAmount.toStringAsFixed(0),
    );
    _funded = TextEditingController(text: r.fundedAmount.toStringAsFixed(0));
    _social = TextEditingController(text: r.socialWorker);
    _medical = TextEditingController(text: r.medicalCoordinator);
    _note = TextEditingController(text: r.followUpNote);
    _status = r.status;
    _center = r.centerId;
  }

  @override
  void dispose() {
    _approved.dispose();
    _funded.dispose();
    _social.dispose();
    _medical.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Suivi du dossier solidaire'),
    content: SizedBox(
      width: 540,
      child: Form(
        key: _key,
        child: SingleChildScrollView(
          child: Column(
            children: [
              DropdownButtonFormField<String>(
                initialValue: _status,
                decoration: const InputDecoration(labelText: 'Statut'),
                items: const [
                  DropdownMenuItem(value: 'pending', child: Text('En étude')),
                  DropdownMenuItem(value: 'approved', child: Text('Approuvé')),
                  DropdownMenuItem(
                    value: 'partially_funded',
                    child: Text('Partiellement financé'),
                  ),
                  DropdownMenuItem(value: 'funded', child: Text('Financé')),
                  DropdownMenuItem(
                    value: 'in_care',
                    child: Text('Soins en cours'),
                  ),
                  DropdownMenuItem(
                    value: 'completed',
                    child: Text('Prise en charge terminée'),
                  ),
                  DropdownMenuItem(
                    value: 'rejected',
                    child: Text('Non retenu'),
                  ),
                ],
                onChanged: (v) => setState(() => _status = v!),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _approved,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Montant approuvé (HTG)',
                ),
                validator: _amountValidator,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _funded,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Montant déjà financé (HTG)',
                ),
                validator: _amountValidator,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String?>(
                initialValue: _center,
                decoration: const InputDecoration(
                  labelText: 'Centre partenaire',
                ),
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text('À affecter'),
                  ),
                  for (final center in widget.centers)
                    DropdownMenuItem(
                      value: center.id,
                      child: Text(center.name),
                    ),
                ],
                onChanged: (v) => setState(() => _center = v),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _social,
                decoration: const InputDecoration(
                  labelText: 'Accompagnateur social',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _medical,
                decoration: const InputDecoration(
                  labelText: 'Accompagnateur médical',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _note,
                maxLines: 4,
                maxLength: 2000,
                decoration: const InputDecoration(
                  labelText: 'Note de suivi',
                  alignLabelWithHint: true,
                ),
                validator: (v) =>
                    _status == 'rejected' && (v?.trim().isEmpty ?? true)
                    ? 'Une explication est obligatoire.'
                    : null,
              ),
            ],
          ),
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
          if (_key.currentState?.validate() != true) return;
          Navigator.pop(
            context,
            _SolidarityDecision(
              status: _status,
              approvedAmount: _amount(_approved.text),
              fundedAmount: _amount(_funded.text),
              centerId: _center,
              socialWorker: _social.text.trim(),
              medicalCoordinator: _medical.text.trim(),
              followUpNote: _note.text.trim(),
            ),
          );
        },
        child: const Text('Enregistrer'),
      ),
    ],
  );
}

class _SolidarityDecision {
  final String status;
  final double approvedAmount;
  final double fundedAmount;
  final String? centerId;
  final String socialWorker;
  final String medicalCoordinator;
  final String followUpNote;
  const _SolidarityDecision({
    required this.status,
    required this.approvedAmount,
    required this.fundedAmount,
    required this.centerId,
    required this.socialWorker,
    required this.medicalCoordinator,
    required this.followUpNote,
  });
}

class _AdminCreditTitle extends StatelessWidget {
  final String title;
  final String subtitle;
  const _AdminCreditTitle({required this.title, required this.subtitle});
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: Theme.of(context).textTheme.headlineMedium),
      const SizedBox(height: 5),
      Text(subtitle, style: const TextStyle(color: AdminColors.muted)),
    ],
  );
}

class _AdminCreditMetric extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _AdminCreditMetric({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
  @override
  Widget build(BuildContext context) => AdminPanel(
    padding: const EdgeInsets.all(16),
    child: Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color.withValues(alpha: .1),
            borderRadius: BorderRadius.circular(13),
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
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                label,
                maxLines: 2,
                style: const TextStyle(
                  color: AdminColors.muted,
                  fontSize: 11.5,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _AdminStatus extends StatelessWidget {
  final String text;
  final Color color;
  const _AdminStatus({required this.text, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .1),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      text,
      style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w900),
    ),
  );
}

class _DataPill extends StatelessWidget {
  final String label;
  final String value;
  const _DataPill({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
    decoration: BoxDecoration(
      color: const Color(0xFFF7F9FC),
      borderRadius: BorderRadius.circular(11),
    ),
    child: Text(
      '$label  $value',
      style: const TextStyle(
        color: AdminColors.muted,
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _AdminEmptyLine extends StatelessWidget {
  final IconData icon;
  final String text;
  const _AdminEmptyLine({required this.icon, required this.text});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(24),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: AdminColors.muted),
        const SizedBox(width: 10),
        Flexible(
          child: Text(text, style: const TextStyle(color: AdminColors.muted)),
        ),
      ],
    ),
  );
}

class _CreditAdminError extends StatelessWidget {
  final VoidCallback onRetry;
  const _CreditAdminError({required this.onRetry});
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.cloud_off_outlined,
          size: 42,
          color: AdminColors.primary,
        ),
        const SizedBox(height: 12),
        const Text('Impossible de charger Crédit Santé.'),
        const SizedBox(height: 12),
        FilledButton(onPressed: onRetry, child: const Text('Réessayer')),
      ],
    ),
  );
}

double _amount(String value) =>
    double.tryParse(value.replaceAll(' ', '').replaceAll(',', '.')) ?? 0;
String? _amountValidator(String? value) =>
    _amount(value ?? '') < 0 ? 'Entrez un montant valide.' : null;
String _money(double value) {
  final fixed = value.toStringAsFixed(value == value.roundToDouble() ? 0 : 2);
  final parts = fixed.split('.');
  final grouped = parts.first.replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => ' ',
  );
  return '${parts.length == 1 ? grouped : '$grouped.${parts.last}'} HTG';
}

String _date(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
String _shortId(String value) =>
    value.length <= 8 ? value : '${value.substring(0, 8)}…';
String _method(String value) => switch (value) {
  'moncash' => 'MonCash',
  'card' => 'Carte',
  'bank_transfer' => 'Virement',
  'cash_partner' => 'Espèces partenaire',
  _ => value,
};
String _applicationStatus(String value) => switch (value) {
  'pending_references' => 'Références à valider',
  'under_review' => 'À décider',
  'approved' => 'Approuvée',
  'rejected' => 'Refusée',
  'cancelled' => 'Annulée',
  _ => value,
};
String _riskLabel(int score) => score >= 100
    ? 'Excellent'
    : score >= 85
    ? 'Bon'
    : score >= 70
    ? 'Moyen'
    : 'Élevé';
Color _riskColor(int score) => score >= 100
    ? AdminColors.success
    : score >= 85
    ? AdminColors.primary
    : score >= 70
    ? AdminColors.warning
    : AdminColors.danger;
String _solidarityStatus(String value) => switch (value) {
  'pending' => 'En étude',
  'approved' => 'Approuvé',
  'partially_funded' => 'Partiellement financé',
  'funded' => 'Financé',
  'in_care' => 'Soins en cours',
  'completed' => 'Terminé',
  'rejected' => 'Non retenu',
  _ => value,
};
Color _solidarityColor(String value) => switch (value) {
  'funded' || 'completed' => AdminColors.success,
  'rejected' => AdminColors.danger,
  'pending' => AdminColors.warning,
  _ => AdminColors.primary,
};
