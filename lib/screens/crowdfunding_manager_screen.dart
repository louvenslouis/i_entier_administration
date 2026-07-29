import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/crowdfunding_admin_repository.dart';
import '../models/crowdfunding_campaign.dart';
import '../theme/admin_theme.dart';

const _fundingGreen = Color(0xFF087A5B);
const _fundingSoft = Color(0xFFE9F8F3);

class CrowdfundingManagerScreen extends StatefulWidget {
  final User user;
  final CrowdfundingAdminRepository repository;

  const CrowdfundingManagerScreen({
    super.key,
    required this.user,
    required this.repository,
  });

  @override
  State<CrowdfundingManagerScreen> createState() =>
      _CrowdfundingManagerScreenState();
}

class _CrowdfundingManagerScreenState extends State<CrowdfundingManagerScreen> {
  late Stream<List<AdminCrowdfundingCampaign>> _campaigns;
  late Stream<List<AdminCrowdfundingContribution>> _contributions;
  CrowdfundingReviewStatus? _filter = CrowdfundingReviewStatus.pending;
  final _searchController = TextEditingController();
  String _query = '';
  final Set<String> _working = {};

  @override
  void initState() {
    super.initState();
    _loadStreams();
  }

  void _loadStreams() {
    _campaigns = widget.repository.watchCampaigns();
    _contributions = widget.repository.watchPendingContributions();
  }

  @override
  void didUpdateWidget(covariant CrowdfundingManagerScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.repository != widget.repository) _loadStreams();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _approve(AdminCrowdfundingCampaign campaign) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(
          Icons.verified_outlined,
          color: _fundingGreen,
          size: 36,
        ),
        title: const Text('Publier cette campagne ?'),
        content: Text(
          'La campagne « ${campaign.title} » deviendra visible et pourra recevoir des contributions.',
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            key: const Key('confirm-campaign-approval'),
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: _fundingGreen),
            child: const Text('Approuver et publier'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _review(campaign, CrowdfundingReviewStatus.approved);
    }
  }

  Future<void> _reject(AdminCrowdfundingCampaign campaign) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => _CampaignRejectionDialog(campaign: campaign),
    );
    if (reason != null) {
      await _review(
        campaign,
        CrowdfundingReviewStatus.rejected,
        reason: reason,
      );
    }
  }

  Future<void> _review(
    AdminCrowdfundingCampaign campaign,
    CrowdfundingReviewStatus status, {
    String reason = '',
  }) async {
    setState(() => _working.add(campaign.id));
    try {
      await widget.repository.reviewCampaign(
        campaign: campaign,
        adminUid: widget.user.id,
        status: status,
        reason: reason,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            status == CrowdfundingReviewStatus.approved
                ? 'Campagne approuvée et publiée.'
                : 'Campagne refusée avec motif.',
          ),
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('La décision n’a pas été enregistrée.')),
        );
      }
    } finally {
      if (mounted) setState(() => _working.remove(campaign.id));
    }
  }

  Future<void> _confirmContribution(
    AdminCrowdfundingContribution contribution,
  ) async {
    final reference = await showDialog<String>(
      context: context,
      builder: (context) =>
          _PaymentConfirmationDialog(contribution: contribution),
    );
    if (reference == null) return;
    setState(() => _working.add(contribution.id));
    try {
      await widget.repository.confirmContribution(
        contribution: contribution,
        adminUid: widget.user.id,
        processorReference: reference,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Paiement confirmé et total de la campagne mis à jour.',
          ),
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('La confirmation du paiement a échoué.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _working.remove(contribution.id));
    }
  }

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 2,
    child: Column(
      children: [
        const _CrowdfundingAdminHeader(),
        Material(
          color: Colors.white,
          child: TabBar(
            tabs: const [
              Tab(
                key: Key('crowdfunding-admin-campaigns-tab'),
                icon: Icon(Icons.campaign_outlined),
                text: 'Campagnes',
              ),
              Tab(
                key: Key('crowdfunding-admin-contributions-tab'),
                icon: Icon(Icons.payments_outlined),
                text: 'Paiements à confirmer',
              ),
            ],
            labelColor: _fundingGreen,
            unselectedLabelColor: AdminColors.muted,
            indicatorColor: _fundingGreen,
          ),
        ),
        Expanded(
          child: TabBarView(children: [_campaignsView(), _contributionsView()]),
        ),
      ],
    ),
  );

  Widget _campaignsView() => StreamBuilder<List<AdminCrowdfundingCampaign>>(
    stream: _campaigns,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Center(
          child: CircularProgressIndicator(color: _fundingGreen),
        );
      }
      if (snapshot.hasError) {
        return const _AdminFundingError(
          message: 'Impossible de charger les campagnes.',
        );
      }
      final all = snapshot.data ?? const [];
      final query = _query.trim().toLowerCase();
      final visible = all
          .where((campaign) {
            final statusMatches =
                _filter == null || campaign.verificationStatus == _filter;
            final queryMatches =
                query.isEmpty ||
                '${campaign.title} ${campaign.beneficiaryName} '
                        '${campaign.location} ${campaign.medicalFacility}'
                    .toLowerCase()
                    .contains(query);
            return statusMatches && queryMatches;
          })
          .toList(growable: false);

      return CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
              child: Column(
                children: [
                  _CampaignMetrics(campaigns: all),
                  const SizedBox(height: 18),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final search = TextField(
                        controller: _searchController,
                        onChanged: (value) => setState(() => _query = value),
                        decoration: const InputDecoration(
                          hintText: 'Campagne, bénéficiaire, lieu...',
                          prefixIcon: Icon(Icons.search_rounded),
                        ),
                      );
                      final filter =
                          DropdownButtonFormField<CrowdfundingReviewStatus?>(
                            initialValue: _filter,
                            decoration: const InputDecoration(
                              labelText: 'Statut',
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: null,
                                child: Text('Toutes'),
                              ),
                              DropdownMenuItem(
                                value: CrowdfundingReviewStatus.pending,
                                child: Text('En attente'),
                              ),
                              DropdownMenuItem(
                                value: CrowdfundingReviewStatus.approved,
                                child: Text('Approuvées'),
                              ),
                              DropdownMenuItem(
                                value: CrowdfundingReviewStatus.rejected,
                                child: Text('Refusées'),
                              ),
                            ],
                            onChanged: (value) =>
                                setState(() => _filter = value),
                          );
                      if (constraints.maxWidth < 650) {
                        return Column(
                          children: [
                            search,
                            const SizedBox(height: 10),
                            filter,
                          ],
                        );
                      }
                      return Row(
                        children: [
                          Expanded(flex: 2, child: search),
                          const SizedBox(width: 12),
                          Expanded(child: filter),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Dossiers de campagne',
                          style: TextStyle(
                            color: AdminColors.navy,
                            fontSize: 19,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      Text(
                        '${visible.length} dossier${visible.length > 1 ? 's' : ''}',
                        style: const TextStyle(
                          color: AdminColors.muted,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (visible.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: _AdminFundingEmpty(
                icon: Icons.campaign_outlined,
                title: 'Aucune campagne dans cette vue',
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
              sliver: SliverList.separated(
                itemCount: visible.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final campaign = visible[index];
                  return _AdminCampaignCard(
                    campaign: campaign,
                    working: _working.contains(campaign.id),
                    onApprove: () => _approve(campaign),
                    onReject: () => _reject(campaign),
                  );
                },
              ),
            ),
        ],
      );
    },
  );

  Widget
  _contributionsView() => StreamBuilder<List<AdminCrowdfundingContribution>>(
    stream: _contributions,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Center(
          child: CircularProgressIndicator(color: _fundingGreen),
        );
      }
      if (snapshot.hasError) {
        return const _AdminFundingError(
          message: 'Impossible de charger les paiements.',
        );
      }
      final contributions = snapshot.data ?? const [];
      if (contributions.isEmpty) {
        return const _AdminFundingEmpty(
          icon: Icons.task_alt_rounded,
          title: 'Aucun paiement en attente',
          message:
              'Les intentions apparaîtront ici avant d’être rapprochées avec le prestataire de paiement.',
        );
      }
      return ListView.separated(
        padding: const EdgeInsets.all(24),
        itemCount: contributions.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final contribution = contributions[index];
          return _ContributionCard(
            contribution: contribution,
            working: _working.contains(contribution.id),
            onConfirm: () => _confirmContribution(contribution),
          );
        },
      );
    },
  );
}

class _CrowdfundingAdminHeader extends StatelessWidget {
  const _CrowdfundingAdminHeader();

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(26, 24, 26, 22),
    decoration: const BoxDecoration(
      gradient: LinearGradient(colors: [Color(0xFF075D47), Color(0xFF0A8F77)]),
    ),
    child: Row(
      children: [
        Image.asset(
          'assets/services/crowdfunding_3d.png',
          width: 82,
          height: 82,
          fit: BoxFit.contain,
          semanticLabel: 'Icône 3D de financement solidaire pour la santé',
        ),
        const SizedBox(width: 18),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'FINANCEMENT SOLIDAIRE',
                style: TextStyle(
                  color: Color(0xFFA9F0D8),
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
              SizedBox(height: 7),
              Text(
                'Contrôle des campagnes et des paiements',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 25,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -.5,
                ),
              ),
              SizedBox(height: 5),
              Text(
                'Vérifiez les dossiers avant publication et rapprochez chaque paiement avec sa référence.',
                style: TextStyle(color: Color(0xFFD7F4EA), height: 1.4),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _CampaignMetrics extends StatelessWidget {
  final List<AdminCrowdfundingCampaign> campaigns;

  const _CampaignMetrics({required this.campaigns});

  @override
  Widget build(BuildContext context) {
    final pending = campaigns
        .where(
          (campaign) =>
              campaign.verificationStatus == CrowdfundingReviewStatus.pending,
        )
        .length;
    final active = campaigns
        .where((campaign) => campaign.status == 'active')
        .length;
    final raised = campaigns.fold<double>(
      0,
      (total, campaign) => total + campaign.raisedAmount,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final cards = [
          _AdminMetricCard(
            label: 'À vérifier',
            value: '$pending',
            icon: Icons.fact_check_outlined,
            color: AdminColors.warning,
          ),
          _AdminMetricCard(
            label: 'Actives',
            value: '$active',
            icon: Icons.campaign_outlined,
            color: _fundingGreen,
          ),
          _AdminMetricCard(
            label: 'Collecté',
            value: _money(raised, 'HTG'),
            icon: Icons.savings_outlined,
            color: AdminColors.primary,
          ),
        ];
        if (constraints.maxWidth < 760) {
          return Column(
            children: [
              for (final card in cards) ...[
                SizedBox(width: double.infinity, child: card),
                const SizedBox(height: 8),
              ],
            ],
          );
        }
        return Row(
          children: [
            for (var index = 0; index < cards.length; index++) ...[
              Expanded(child: cards[index]),
              if (index != cards.length - 1) const SizedBox(width: 10),
            ],
          ],
        );
      },
    );
  }
}

class _AdminMetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _AdminMetricCard({
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
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AdminColors.navy,
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                label,
                style: const TextStyle(color: AdminColors.muted, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _AdminCampaignCard extends StatelessWidget {
  final AdminCrowdfundingCampaign campaign;
  final bool working;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _AdminCampaignCard({
    required this.campaign,
    required this.working,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) => AdminPanel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _StatusBadge(status: campaign.verificationStatus),
            _InfoBadge(
              icon: Icons.category_outlined,
              label: _categoryLabel(campaign.category),
            ),
            if (!campaign.consentToPublish)
              const _InfoBadge(
                icon: Icons.warning_amber_rounded,
                label: 'Consentement absent',
                danger: true,
              ),
          ],
        ),
        const SizedBox(height: 13),
        Text(
          campaign.title,
          style: const TextStyle(
            color: AdminColors.navy,
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          '${campaign.beneficiaryName} • ${campaign.location}',
          style: const TextStyle(color: AdminColors.muted),
        ),
        const SizedBox(height: 14),
        Text(
          campaign.story,
          maxLines: 4,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: AdminColors.ink, height: 1.5),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 22,
          runSpacing: 10,
          children: [
            _DataPoint(
              label: 'Objectif',
              value: _money(campaign.targetAmount, campaign.currency),
            ),
            _DataPoint(
              label: 'Déjà collecté',
              value: _money(campaign.raisedAmount, campaign.currency),
            ),
            _DataPoint(label: 'Téléphone privé', value: campaign.contactPhone),
            _DataPoint(label: 'Échéance', value: _date(campaign.deadline)),
            if (campaign.medicalFacility.isNotEmpty)
              _DataPoint(
                label: 'Établissement',
                value: campaign.medicalFacility,
              ),
          ],
        ),
        if (campaign.rejectionReason.isNotEmpty) ...[
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF0ED),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Motif : ${campaign.rejectionReason}',
              style: const TextStyle(color: AdminColors.danger),
            ),
          ),
        ],
        if (campaign.verificationStatus ==
            CrowdfundingReviewStatus.pending) ...[
          const SizedBox(height: 18),
          if (working)
            const LinearProgressIndicator(color: _fundingGreen)
          else
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton.icon(
                  onPressed: campaign.consentToPublish ? onApprove : null,
                  style: FilledButton.styleFrom(backgroundColor: _fundingGreen),
                  icon: const Icon(Icons.verified_outlined),
                  label: const Text('Approuver'),
                ),
                OutlinedButton.icon(
                  onPressed: onReject,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AdminColors.danger,
                  ),
                  icon: const Icon(Icons.close_rounded),
                  label: const Text('Refuser'),
                ),
              ],
            ),
        ],
      ],
    ),
  );
}

class _ContributionCard extends StatelessWidget {
  final AdminCrowdfundingContribution contribution;
  final bool working;
  final VoidCallback onConfirm;

  const _ContributionCard({
    required this.contribution,
    required this.working,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) => AdminPanel(
    child: LayoutBuilder(
      builder: (context, constraints) {
        final content = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _InfoBadge(
              icon: Icons.schedule_rounded,
              label: 'Paiement en attente',
            ),
            const SizedBox(height: 12),
            Text(
              _money(contribution.amount, contribution.currency),
              style: const TextStyle(
                color: AdminColors.navy,
                fontSize: 23,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              '${_paymentLabel(contribution.paymentMethod)} • '
              '${contribution.anonymous ? 'Anonyme' : (contribution.publicName.isEmpty ? 'Nom non publié' : contribution.publicName)}',
              style: const TextStyle(color: AdminColors.muted),
            ),
            const SizedBox(height: 7),
            Text(
              'Campagne : ${_shortReference(contribution.campaignId)}',
              style: const TextStyle(
                color: AdminColors.ink,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        );
        final button = FilledButton.icon(
          key: Key('confirm-contribution-${contribution.id}'),
          onPressed: working ? null : onConfirm,
          style: FilledButton.styleFrom(backgroundColor: _fundingGreen),
          icon: working
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.task_alt_rounded),
          label: const Text('Confirmer avec référence'),
        );
        if (constraints.maxWidth < 650) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [content, const SizedBox(height: 16), button],
          );
        }
        return Row(
          children: [
            Expanded(child: content),
            const SizedBox(width: 20),
            button,
          ],
        );
      },
    ),
  );
}

class _CampaignRejectionDialog extends StatefulWidget {
  final AdminCrowdfundingCampaign campaign;

  const _CampaignRejectionDialog({required this.campaign});

  @override
  State<_CampaignRejectionDialog> createState() =>
      _CampaignRejectionDialogState();
}

class _CampaignRejectionDialogState extends State<_CampaignRejectionDialog> {
  final _formKey = GlobalKey<FormState>();
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    icon: const Icon(
      Icons.report_gmailerrorred_outlined,
      color: AdminColors.danger,
      size: 36,
    ),
    title: const Text('Refuser la campagne'),
    content: SizedBox(
      width: 480,
      child: Form(
        key: _formKey,
        child: TextFormField(
          key: const Key('campaign-rejection-reason'),
          controller: _controller,
          autofocus: true,
          maxLength: 600,
          maxLines: 4,
          decoration: InputDecoration(
            labelText: 'Motif communiqué au créateur',
            helperText: widget.campaign.title,
            alignLabelWithHint: true,
          ),
          validator: (value) => value == null || value.trim().isEmpty
              ? 'Un motif est requis.'
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
        key: const Key('confirm-campaign-rejection'),
        onPressed: () {
          if (_formKey.currentState?.validate() == true) {
            Navigator.pop(context, _controller.text.trim());
          }
        },
        style: FilledButton.styleFrom(backgroundColor: AdminColors.danger),
        child: const Text('Confirmer le refus'),
      ),
    ],
  );
}

class _PaymentConfirmationDialog extends StatefulWidget {
  final AdminCrowdfundingContribution contribution;

  const _PaymentConfirmationDialog({required this.contribution});

  @override
  State<_PaymentConfirmationDialog> createState() =>
      _PaymentConfirmationDialogState();
}

class _PaymentConfirmationDialogState
    extends State<_PaymentConfirmationDialog> {
  final _formKey = GlobalKey<FormState>();
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    icon: const Icon(Icons.payments_outlined, color: _fundingGreen, size: 36),
    title: const Text('Confirmer le paiement'),
    content: SizedBox(
      width: 470,
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Vérifiez le paiement de ${_money(widget.contribution.amount, widget.contribution.currency)} '
              'chez le prestataire avant de continuer.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            TextFormField(
              key: const Key('payment-processor-reference'),
              controller: _controller,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Référence du prestataire',
                hintText: 'Ex. MC-2026-001928',
              ),
              validator: (value) => value == null || value.trim().length < 4
                  ? 'Une référence valide est requise.'
                  : null,
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Annuler'),
      ),
      FilledButton(
        key: const Key('confirm-payment-reference'),
        onPressed: () {
          if (_formKey.currentState?.validate() == true) {
            Navigator.pop(context, _controller.text.trim());
          }
        },
        style: FilledButton.styleFrom(backgroundColor: _fundingGreen),
        child: const Text('Confirmer le paiement'),
      ),
    ],
  );
}

class _StatusBadge extends StatelessWidget {
  final CrowdfundingReviewStatus status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      CrowdfundingReviewStatus.pending => AdminColors.warning,
      CrowdfundingReviewStatus.approved => _fundingGreen,
      CrowdfundingReviewStatus.rejected => AdminColors.danger,
    };
    return _InfoBadge(
      icon: switch (status) {
        CrowdfundingReviewStatus.pending => Icons.schedule_rounded,
        CrowdfundingReviewStatus.approved => Icons.verified_outlined,
        CrowdfundingReviewStatus.rejected => Icons.cancel_outlined,
      },
      label: status.label,
      color: color,
    );
  }
}

class _InfoBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool danger;
  final Color? color;

  const _InfoBadge({
    required this.icon,
    required this.label,
    this.danger = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor =
        color ?? (danger ? AdminColors.danger : AdminColors.primary);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: effectiveColor.withValues(alpha: .09),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: effectiveColor),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: effectiveColor,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _DataPoint extends StatelessWidget {
  final String label;
  final String value;

  const _DataPoint({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(minWidth: 130, maxWidth: 250),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            color: AdminColors.muted,
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: .6,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: const TextStyle(
            color: AdminColors.ink,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

class _AdminFundingEmpty extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _AdminFundingEmpty({
    required this.icon,
    required this.title,
    this.message =
        'Modifiez le filtre ou revenez après une nouvelle soumission.',
  });

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 66,
            height: 66,
            decoration: const BoxDecoration(
              color: _fundingSoft,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: _fundingGreen, size: 32),
          ),
          const SizedBox(height: 15),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AdminColors.navy,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AdminColors.muted, height: 1.45),
          ),
        ],
      ),
    ),
  );
}

class _AdminFundingError extends StatelessWidget {
  final String message;

  const _AdminFundingError({required this.message});

  @override
  Widget build(BuildContext context) => Center(
    child: Text(
      message,
      style: const TextStyle(
        color: AdminColors.danger,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

String _categoryLabel(String category) => switch (category) {
  'emergency' => 'Urgence',
  'surgery' => 'Chirurgie',
  'treatment' => 'Traitement',
  'medication' => 'Médicaments',
  'maternity' => 'Maternité',
  'rehabilitation' => 'Réadaptation',
  _ => 'Autre',
};

String _paymentLabel(String method) => switch (method) {
  'moncash' => 'MonCash',
  'card' => 'Carte',
  'bank_transfer' => 'Virement',
  _ => method,
};

String _money(double amount, String currency) {
  final raw = amount.round().toString();
  final buffer = StringBuffer();
  for (var index = 0; index < raw.length; index++) {
    if (index > 0 && (raw.length - index) % 3 == 0) buffer.write(' ');
    buffer.write(raw[index]);
  }
  return '${buffer.toString()} $currency';
}

String _date(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/'
    '${date.month.toString().padLeft(2, '0')}/${date.year}';

String _shortReference(String id) {
  final normalized = id.replaceAll('-', '').toUpperCase();
  return normalized.length <= 10 ? normalized : normalized.substring(0, 10);
}
