import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/admin_repository.dart';
import '../data/crowdfunding_admin_repository.dart';
import '../data/diagnostic_config_repository.dart';
import '../models/provider_application.dart';
import '../supabase_config.dart';
import '../theme/admin_theme.dart';
import 'crowdfunding_manager_screen.dart';
import 'diagnostic_manager_screen.dart';

enum _StatusFilter { all, pending, approved, rejected }

enum _AdminSection { applications, crowdfunding, diagnostics }

class AdminDashboardScreen extends StatefulWidget {
  final User user;
  final AdminRepository repository;
  final DiagnosticConfigRepository? diagnosticRepository;
  final CrowdfundingAdminRepository? crowdfundingRepository;

  const AdminDashboardScreen({
    super.key,
    required this.user,
    required this.repository,
    this.diagnosticRepository,
    this.crowdfundingRepository,
  });

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final _searchController = TextEditingController();
  late Stream<List<ProviderApplication>> _applications;
  _StatusFilter _statusFilter = _StatusFilter.pending;
  ApplicationType? _typeFilter;
  String _query = '';
  final Set<String> _reviewing = {};
  _AdminSection _selectedSection = _AdminSection.applications;
  DiagnosticConfigRepository? _defaultDiagnosticRepository;
  CrowdfundingAdminRepository? _defaultCrowdfundingRepository;

  DiagnosticConfigRepository get _diagnosticRepository =>
      widget.diagnosticRepository ??
      (_defaultDiagnosticRepository ??= SupabaseDiagnosticConfigRepository());

  CrowdfundingAdminRepository get _crowdfundingRepository =>
      widget.crowdfundingRepository ??
      (_defaultCrowdfundingRepository ??=
          SupabaseCrowdfundingAdminRepository());

  @override
  void initState() {
    super.initState();
    _applications = widget.repository.watchApplications();
  }

  @override
  void didUpdateWidget(covariant AdminDashboardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.repository != widget.repository) {
      _applications = widget.repository.watchApplications();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _approve(ProviderApplication application) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(
          Icons.verified_outlined,
          color: AdminColors.success,
          size: 34,
        ),
        title: const Text('Approuver cette demande ?'),
        content: Text(
          '${application.displayName} pourra ensuite publier sa fiche dans l’annuaire i-ENTIER.',
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
            child: const Text('Approuver'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _submitReview(
        application: application,
        status: ApplicationStatus.approved,
      );
    }
  }

  Future<void> _reject(ProviderApplication application) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => _RejectionDialog(application: application),
    );
    if (reason != null && reason.isNotEmpty) {
      await _submitReview(
        application: application,
        status: ApplicationStatus.rejected,
        reason: reason,
      );
    }
  }

  Future<void> _submitReview({
    required ProviderApplication application,
    required ApplicationStatus status,
    String reason = '',
  }) async {
    setState(() => _reviewing.add(application.id));
    try {
      await widget.repository.reviewApplication(
        application: application,
        adminUid: widget.user.uid,
        status: status,
        reason: reason,
      );
      if (!mounted) return;
      final action = status == ApplicationStatus.approved
          ? 'approuvée'
          : 'refusée';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Demande $action avec succès.')));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('La décision n’a pas été enregistrée. Réessayez.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _reviewing.remove(application.id));
    }
  }

  void _openApplication(ProviderApplication application) {
    showDialog<void>(
      context: context,
      builder: (context) => _ApplicationDetailDialog(
        application: application,
        reviewing: _reviewing.contains(application.id),
        onApprove: () {
          Navigator.pop(context);
          _approve(application);
        },
        onReject: () {
          Navigator.pop(context);
          _reject(application);
        },
      ),
    );
  }

  Widget _applicationsView() => StreamBuilder<List<ProviderApplication>>(
    stream: _applications,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Center(
          child: CircularProgressIndicator(color: AdminColors.primary),
        );
      }
      if (snapshot.hasError) return const _ApplicationsError();
      final applications = snapshot.data ?? const [];
      return _DashboardContent(
        applications: applications,
        searchController: _searchController,
        query: _query,
        statusFilter: _statusFilter,
        typeFilter: _typeFilter,
        reviewing: _reviewing,
        onQueryChanged: (value) => setState(() => _query = value),
        onStatusChanged: (value) => setState(() => _statusFilter = value),
        onTypeChanged: (value) => setState(() => _typeFilter = value),
        onOpen: _openApplication,
        onApprove: _approve,
        onReject: _reject,
      );
    },
  );

  Widget _selectedView() => switch (_selectedSection) {
    _AdminSection.applications => _applicationsView(),
    _AdminSection.crowdfunding => CrowdfundingManagerScreen(
      user: widget.user,
      repository: _crowdfundingRepository,
    ),
    _AdminSection.diagnostics => DiagnosticManagerScreen(
      user: widget.user,
      repository: _diagnosticRepository,
    ),
  };

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final desktop = constraints.maxWidth >= 980;
      return Scaffold(
        appBar: desktop
            ? null
            : AppBar(
                title: Text(switch (_selectedSection) {
                  _AdminSection.applications => 'Demandes',
                  _AdminSection.crowdfunding => 'Financement solidaire',
                  _AdminSection.diagnostics => 'Diagnostic assisté',
                }, style: const TextStyle(fontWeight: FontWeight.w900)),
                actions: [
                  PopupMenuButton<_AdminSection>(
                    tooltip: 'Changer de section',
                    initialValue: _selectedSection,
                    onSelected: (value) =>
                        setState(() => _selectedSection = value),
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: _AdminSection.applications,
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.fact_check_outlined),
                          title: Text('Demandes'),
                        ),
                      ),
                      PopupMenuItem(
                        value: _AdminSection.crowdfunding,
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.volunteer_activism_outlined),
                          title: Text('Financement solidaire'),
                        ),
                      ),
                      PopupMenuItem(
                        value: _AdminSection.diagnostics,
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.account_tree_outlined),
                          title: Text('Diagnostic assisté'),
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    tooltip: 'Déconnexion',
                    onPressed: () => SupabaseConfig.client.auth.signOut(),
                    icon: const Icon(Icons.logout_rounded),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
        body: SafeArea(
          child: Row(
            children: [
              if (desktop)
                _AdminSidebar(
                  user: widget.user,
                  selectedSection: _selectedSection,
                  onSectionSelected: (value) =>
                      setState(() => _selectedSection = value),
                  onSignOut: () => SupabaseConfig.client.auth.signOut(),
                ),
              Expanded(child: _selectedView()),
            ],
          ),
        ),
      );
    },
  );
}

class _RejectionDialog extends StatefulWidget {
  final ProviderApplication application;

  const _RejectionDialog({required this.application});

  @override
  State<_RejectionDialog> createState() => _RejectionDialogState();
}

class _RejectionDialogState extends State<_RejectionDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.application.status == ApplicationStatus.rejected
          ? widget.application.rejectionReason
          : '',
    );
  }

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
      size: 34,
    ),
    title: const Text('Refuser cette demande'),
    content: SingleChildScrollView(
      child: SizedBox(
        width: 480,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Expliquez clairement à ${widget.application.displayName} ce qui doit être corrigé.',
                style: const TextStyle(color: AdminColors.muted),
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: const ValueKey('rejection-reason-field'),
                controller: _controller,
                maxLines: 4,
                maxLength: 600,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Motif du refus',
                  hintText:
                      'Ex. Le numéro de licence ne correspond pas au document fourni.',
                  alignLabelWithHint: true,
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Un motif est requis.'
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
        key: const ValueKey('confirm-rejection'),
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

class _AdminSidebar extends StatelessWidget {
  final User user;
  final VoidCallback onSignOut;
  final _AdminSection selectedSection;
  final ValueChanged<_AdminSection> onSectionSelected;

  const _AdminSidebar({
    required this.user,
    required this.onSignOut,
    required this.selectedSection,
    required this.onSectionSelected,
  });

  @override
  Widget build(BuildContext context) => Container(
    width: 270,
    padding: const EdgeInsets.fromLTRB(20, 25, 20, 20),
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(right: BorderSide(color: AdminColors.border)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AdminBrand(),
        const SizedBox(height: 42),
        _SidebarItem(
          icon: Icons.fact_check_outlined,
          label: 'Demandes',
          selected: selectedSection == _AdminSection.applications,
          onTap: () => onSectionSelected(_AdminSection.applications),
        ),
        const SizedBox(height: 7),
        _SidebarItem(
          icon: Icons.volunteer_activism_outlined,
          label: 'Financement solidaire',
          selected: selectedSection == _AdminSection.crowdfunding,
          onTap: () => onSectionSelected(_AdminSection.crowdfunding),
        ),
        const SizedBox(height: 7),
        _SidebarItem(
          icon: Icons.account_tree_outlined,
          label: 'Diagnostic assisté',
          selected: selectedSection == _AdminSection.diagnostics,
          onTap: () => onSectionSelected(_AdminSection.diagnostics),
        ),
        const SizedBox(height: 22),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF7F9FC),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.shield_outlined, color: AdminColors.success, size: 19),
              SizedBox(width: 9),
              Expanded(
                child: Text(
                  'Toutes les décisions sont journalisées.',
                  style: TextStyle(
                    color: AdminColors.muted,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
        const Divider(color: AdminColors.border),
        const SizedBox(height: 10),
        Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AdminColors.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _initials(user.displayName ?? user.email ?? 'Admin'),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.displayName ?? 'Administrateur',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AdminColors.ink,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    user.email ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AdminColors.muted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Déconnexion',
              onPressed: onSignOut,
              icon: const Icon(Icons.logout_rounded, size: 20),
            ),
          ],
        ),
      ],
    ),
  );
}

class _SidebarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Material(
    color: selected ? AdminColors.primarySoft : Colors.transparent,
    borderRadius: BorderRadius.circular(13),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(13),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
        child: Row(
          children: [
            Icon(
              icon,
              color: selected ? AdminColors.primary : AdminColors.muted,
              size: 21,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: selected ? AdminColors.primaryDark : AdminColors.muted,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _DashboardContent extends StatelessWidget {
  final List<ProviderApplication> applications;
  final TextEditingController searchController;
  final String query;
  final _StatusFilter statusFilter;
  final ApplicationType? typeFilter;
  final Set<String> reviewing;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<_StatusFilter> onStatusChanged;
  final ValueChanged<ApplicationType?> onTypeChanged;
  final ValueChanged<ProviderApplication> onOpen;
  final ValueChanged<ProviderApplication> onApprove;
  final ValueChanged<ProviderApplication> onReject;

  const _DashboardContent({
    required this.applications,
    required this.searchController,
    required this.query,
    required this.statusFilter,
    required this.typeFilter,
    required this.reviewing,
    required this.onQueryChanged,
    required this.onStatusChanged,
    required this.onTypeChanged,
    required this.onOpen,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final normalizedQuery = query.trim().toLowerCase();
    final filtered = applications
        .where((application) {
          final matchesStatus = switch (statusFilter) {
            _StatusFilter.all => true,
            _StatusFilter.pending =>
              application.status == ApplicationStatus.pending,
            _StatusFilter.approved =>
              application.status == ApplicationStatus.approved,
            _StatusFilter.rejected =>
              application.status == ApplicationStatus.rejected,
          };
          final matchesType =
              typeFilter == null || application.type == typeFilter;
          final searchable =
              '${application.displayName} ${application.category} '
                      '${application.registrationNumber} ${application.email}'
                  .toLowerCase();
          return matchesStatus &&
              matchesType &&
              (normalizedQuery.isEmpty || searchable.contains(normalizedQuery));
        })
        .toList(growable: false);

    int count(ApplicationStatus status) =>
        applications.where((item) => item.status == status).length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(26, 30, 26, 50),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1180),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Validation des professionnels',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 7),
                const Text(
                  'Examinez les informations avant d’autoriser une présence dans l’annuaire.',
                  style: TextStyle(color: AdminColors.muted, fontSize: 16),
                ),
                const SizedBox(height: 24),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = constraints.maxWidth >= 760 ? 4 : 2;
                    const spacing = 12.0;
                    final width =
                        (constraints.maxWidth - ((columns - 1) * spacing)) /
                        columns;
                    return Wrap(
                      spacing: spacing,
                      runSpacing: spacing,
                      children: [
                        SizedBox(
                          width: width,
                          child: _MetricCard(
                            label: 'Total',
                            value: applications.length,
                            icon: Icons.groups_outlined,
                            color: AdminColors.primary,
                          ),
                        ),
                        SizedBox(
                          width: width,
                          child: _MetricCard(
                            label: 'En attente',
                            value: count(ApplicationStatus.pending),
                            icon: Icons.hourglass_top_rounded,
                            color: AdminColors.warning,
                          ),
                        ),
                        SizedBox(
                          width: width,
                          child: _MetricCard(
                            label: 'Approuvés',
                            value: count(ApplicationStatus.approved),
                            icon: Icons.verified_outlined,
                            color: AdminColors.success,
                          ),
                        ),
                        SizedBox(
                          width: width,
                          child: _MetricCard(
                            label: 'Refusés',
                            value: count(ApplicationStatus.rejected),
                            icon: Icons.block_outlined,
                            color: AdminColors.danger,
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 20),
                AdminPanel(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      TextField(
                        controller: searchController,
                        onChanged: onQueryChanged,
                        decoration: InputDecoration(
                          hintText:
                              'Rechercher un nom, une spécialité, un numéro…',
                          prefixIcon: const Icon(Icons.search_rounded),
                          suffixIcon: query.isEmpty
                              ? null
                              : IconButton(
                                  tooltip: 'Effacer',
                                  onPressed: () {
                                    searchController.clear();
                                    onQueryChanged('');
                                  },
                                  icon: const Icon(Icons.close_rounded),
                                ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _FilterChip(
                              label: 'En attente',
                              selected: statusFilter == _StatusFilter.pending,
                              onTap: () =>
                                  onStatusChanged(_StatusFilter.pending),
                            ),
                            _FilterChip(
                              label: 'Tous les statuts',
                              selected: statusFilter == _StatusFilter.all,
                              onTap: () => onStatusChanged(_StatusFilter.all),
                            ),
                            _FilterChip(
                              label: 'Approuvés',
                              selected: statusFilter == _StatusFilter.approved,
                              onTap: () =>
                                  onStatusChanged(_StatusFilter.approved),
                            ),
                            _FilterChip(
                              label: 'Refusés',
                              selected: statusFilter == _StatusFilter.rejected,
                              onTap: () =>
                                  onStatusChanged(_StatusFilter.rejected),
                            ),
                            const SizedBox(width: 6),
                            _FilterChip(
                              label: 'Tous les types',
                              selected: typeFilter == null,
                              onTap: () => onTypeChanged(null),
                            ),
                            _FilterChip(
                              label: 'Personnels',
                              selected:
                                  typeFilter == ApplicationType.professional,
                              onTap: () =>
                                  onTypeChanged(ApplicationType.professional),
                            ),
                            _FilterChip(
                              label: 'Institutions',
                              selected:
                                  typeFilter == ApplicationType.institution,
                              onTap: () =>
                                  onTypeChanged(ApplicationType.institution),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${filtered.length} demande${filtered.length > 1 ? 's' : ''}',
                        style: const TextStyle(
                          color: AdminColors.ink,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    if (applications.isNotEmpty)
                      const Row(
                        children: [
                          Icon(
                            Icons.sync_rounded,
                            size: 16,
                            color: AdminColors.success,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Synchronisé',
                            style: TextStyle(
                              color: AdminColors.success,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                if (filtered.isEmpty)
                  const _EmptyApplications()
                else
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final columns = constraints.maxWidth >= 840 ? 2 : 1;
                      const spacing = 14.0;
                      final width =
                          (constraints.maxWidth - ((columns - 1) * spacing)) /
                          columns;
                      return Wrap(
                        spacing: spacing,
                        runSpacing: spacing,
                        children: [
                          for (final application in filtered)
                            SizedBox(
                              width: width,
                              child: _ApplicationCard(
                                application: application,
                                reviewing: reviewing.contains(application.id),
                                onOpen: () => onOpen(application),
                                onApprove: () => onApprove(application),
                                onReject: () => onReject(application),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;
  final Color color;

  const _MetricCard({
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
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: color.withValues(alpha: .1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 21),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$value',
                style: const TextStyle(
                  color: AdminColors.ink,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
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
    selectedColor: AdminColors.primarySoft,
    side: BorderSide(
      color: selected ? AdminColors.primary : AdminColors.border,
    ),
    labelStyle: TextStyle(
      color: selected ? AdminColors.primaryDark : AdminColors.muted,
      fontWeight: FontWeight.w700,
      fontSize: 12,
    ),
    showCheckmark: false,
  );
}

class _ApplicationCard extends StatelessWidget {
  final ProviderApplication application;
  final bool reviewing;
  final VoidCallback onOpen;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _ApplicationCard({
    required this.application,
    required this.reviewing,
    required this.onOpen,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) => AdminPanel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 50,
              height: 50,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: application.type == ApplicationType.professional
                    ? AdminColors.primarySoft
                    : const Color(0xFFE8F7F0),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(
                application.type == ApplicationType.professional
                    ? Icons.medical_services_outlined
                    : Icons.local_hospital_outlined,
                color: application.type == ApplicationType.professional
                    ? AdminColors.primary
                    : AdminColors.success,
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    application.displayName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AdminColors.ink,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    application.category,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AdminColors.muted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _StatusBadge(status: application.status),
          ],
        ),
        const SizedBox(height: 17),
        _CardLine(
          icon: Icons.badge_outlined,
          text: application.registrationNumber,
        ),
        const SizedBox(height: 9),
        _CardLine(icon: Icons.location_on_outlined, text: application.address),
        const SizedBox(height: 9),
        _CardLine(icon: Icons.email_outlined, text: application.email),
        const SizedBox(height: 15),
        Row(
          children: [
            Expanded(
              child: Text(
                'Mise à jour ${_dateLabel(application.updatedAt)}',
                style: const TextStyle(
                  color: AdminColors.muted,
                  fontSize: 11.5,
                ),
              ),
            ),
            TextButton(onPressed: onOpen, child: const Text('Voir le dossier')),
          ],
        ),
        if (application.status == ApplicationStatus.pending) ...[
          const Divider(height: 20, color: AdminColors.border),
          if (reviewing)
            const LinearProgressIndicator(color: AdminColors.primary)
          else
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onReject,
                    icon: const Icon(Icons.close_rounded, size: 18),
                    label: const Text('Refuser'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onApprove,
                    style: FilledButton.styleFrom(
                      backgroundColor: AdminColors.success,
                    ),
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: const Text('Approuver'),
                  ),
                ),
              ],
            ),
        ],
      ],
    ),
  );
}

class _CardLine extends StatelessWidget {
  final IconData icon;
  final String text;

  const _CardLine({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, color: AdminColors.primary, size: 17),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          text.isEmpty ? 'Non renseigné' : text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: AdminColors.muted, fontSize: 13),
        ),
      ),
    ],
  );
}

class _StatusBadge extends StatelessWidget {
  final ApplicationStatus status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (foreground, background) = switch (status) {
      ApplicationStatus.pending => (
        AdminColors.warning,
        const Color(0xFFFFF2DD),
      ),
      ApplicationStatus.approved => (
        AdminColors.success,
        const Color(0xFFE6F5EE),
      ),
      ApplicationStatus.rejected => (
        AdminColors.danger,
        const Color(0xFFFFECE9),
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          color: foreground,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _ApplicationDetailDialog extends StatelessWidget {
  final ProviderApplication application;
  final bool reviewing;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _ApplicationDetailDialog({
    required this.application,
    required this.reviewing,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) => Dialog(
    insetPadding: const EdgeInsets.all(18),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 800, maxHeight: 760),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 16, 18),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Dossier de vérification',
                        style: TextStyle(
                          color: AdminColors.muted,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        application.displayName,
                        style: const TextStyle(
                          color: AdminColors.ink,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                _StatusBadge(status: application.status),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Fermer',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AdminColors.border),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _DetailSection(
                    title: 'Identité et autorisation',
                    children: [
                      _DetailItem(
                        label: 'Type de compte',
                        value: application.type.label,
                      ),
                      _DetailItem(
                        label: application.type == ApplicationType.professional
                            ? 'Profession / spécialité'
                            : 'Type d’institution',
                        value: application.category,
                      ),
                      _DetailItem(
                        label: application.type == ApplicationType.professional
                            ? 'Numéro de licence / ordre'
                            : 'Numéro d’enregistrement',
                        value: application.registrationNumber,
                      ),
                      if (application.contactPerson.isNotEmpty)
                        _DetailItem(
                          label: 'Responsable du compte',
                          value: application.contactPerson,
                        ),
                      if (application.workplace.isNotEmpty)
                        _DetailItem(
                          label: 'Établissement principal',
                          value: application.workplace,
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _DetailSection(
                    title: 'Coordonnées',
                    children: [
                      _DetailItem(label: 'Téléphone', value: application.phone),
                      _DetailItem(label: 'E-mail', value: application.email),
                      _DetailItem(label: 'Adresse', value: application.address),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _DetailSection(
                    title: 'Activité professionnelle',
                    children: [
                      _DetailItem(
                        label: 'Présentation',
                        value: application.description,
                        fullWidth: true,
                      ),
                      if (application.experience.isNotEmpty)
                        _DetailItem(
                          label: 'Expérience',
                          value: application.experience,
                        ),
                      if (application.qualifications.isNotEmpty)
                        _DetailItem(
                          label: 'Qualifications',
                          value: application.qualifications,
                        ),
                      _DetailItem(
                        label: 'Services',
                        value: application.services,
                      ),
                      _DetailItem(
                        label: 'Horaires',
                        value: application.schedule,
                      ),
                      if (application.type == ApplicationType.professional &&
                          application.appointmentModesSummary.isNotEmpty)
                        _DetailItem(
                          label: 'Disponibilités par mode',
                          value: application.appointmentModesSummary,
                          fullWidth: true,
                        ),
                      if (application.type == ApplicationType.professional &&
                          application.defaultPrice.isNotEmpty)
                        _DetailItem(
                          label: 'Prix indicatif',
                          value: '${application.defaultPrice} HTG',
                        ),
                    ],
                  ),
                  if (application.type == ApplicationType.institution) ...[
                    const SizedBox(height: 16),
                    _DetailSection(
                      title: 'Tarifs de l’institution',
                      children: [
                        _DetailItem(
                          label: 'Publication dans l’annuaire',
                          value: application.institutionPricesPublished
                              ? 'Autorisée par l’institution'
                              : 'Non autorisée par l’institution',
                        ),
                        if (application.servicePrices.isNotEmpty)
                          _DetailItem(
                            label: 'Tarifs des services',
                            value: application.servicePrices,
                            fullWidth: true,
                          ),
                        if (application.roomPrices.isNotEmpty)
                          _DetailItem(
                            label: 'Tarifs des chambres',
                            value: application.roomPrices,
                            fullWidth: true,
                          ),
                      ],
                    ),
                  ],
                  if (application.rejectionReason.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFEFEC),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Motif du dernier refus',
                            style: TextStyle(
                              color: AdminColors.danger,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            application.rejectionReason,
                            style: const TextStyle(
                              color: AdminColors.danger,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (application.status == ApplicationStatus.pending) ...[
            const Divider(height: 1, color: AdminColors.border),
            Padding(
              padding: const EdgeInsets.all(18),
              child: reviewing
                  ? const LinearProgressIndicator(color: AdminColors.primary)
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton.icon(
                          onPressed: onReject,
                          icon: const Icon(Icons.close_rounded, size: 18),
                          label: const Text('Refuser'),
                        ),
                        const SizedBox(width: 10),
                        FilledButton.icon(
                          onPressed: onApprove,
                          style: FilledButton.styleFrom(
                            backgroundColor: AdminColors.success,
                          ),
                          icon: const Icon(Icons.check_rounded, size: 18),
                          label: const Text('Approuver'),
                        ),
                      ],
                    ),
            ),
          ],
        ],
      ),
    ),
  );
}

class _DetailSection extends StatelessWidget {
  final String title;
  final List<_DetailItem> children;

  const _DetailSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(17),
    decoration: BoxDecoration(
      color: const Color(0xFFF7F9FC),
      borderRadius: BorderRadius.circular(15),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AdminColors.ink,
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            const spacing = 14.0;
            final twoColumns = constraints.maxWidth >= 600;
            final width = twoColumns
                ? (constraints.maxWidth - spacing) / 2
                : constraints.maxWidth;
            return Wrap(
              spacing: spacing,
              runSpacing: 12,
              children: [
                for (final item in children)
                  SizedBox(
                    width: item.fullWidth || !twoColumns
                        ? constraints.maxWidth
                        : width,
                    child: item,
                  ),
              ],
            );
          },
        ),
      ],
    ),
  );
}

class _DetailItem extends StatelessWidget {
  final String label;
  final String value;
  final bool fullWidth;

  const _DetailItem({
    required this.label,
    required this.value,
    this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(
          color: AdminColors.muted,
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: 3),
      SelectableText(
        value.isEmpty ? 'Non renseigné' : value,
        style: const TextStyle(
          color: AdminColors.ink,
          fontWeight: FontWeight.w600,
          height: 1.4,
        ),
      ),
    ],
  );
}

class _EmptyApplications extends StatelessWidget {
  const _EmptyApplications();

  @override
  Widget build(BuildContext context) => AdminPanel(
    child: const Padding(
      padding: EdgeInsets.symmetric(vertical: 28),
      child: Column(
        children: [
          Icon(Icons.inbox_outlined, color: AdminColors.primary, size: 40),
          SizedBox(height: 12),
          Text(
            'Aucune demande dans cette sélection',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AdminColors.ink,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 5),
          Text(
            'Modifiez les filtres ou la recherche.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AdminColors.muted),
          ),
        ],
      ),
    ),
  );
}

class _ApplicationsError extends StatelessWidget {
  const _ApplicationsError();

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: AdminPanel(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_off_outlined,
                color: AdminColors.primary,
                size: 42,
              ),
              const SizedBox(height: 14),
              Text(
                'Demandes indisponibles',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 7),
              const Text(
                'Vérifiez les politiques Supabase et le rôle administrateur.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

String _dateLabel(DateTime? date) {
  if (date == null) return 'récemment';
  final local = date.toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  return 'le ${two(local.day)}/${two(local.month)}/${local.year}';
}

String _initials(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.isEmpty) return 'AD';
  if (parts.length == 1) {
    return parts.first
        .substring(0, parts.first.length.clamp(1, 2))
        .toUpperCase();
  }
  return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
}
