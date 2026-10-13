import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/rescue_admin_repository.dart';
import '../models/rescue_models.dart';
import '../supabase_config.dart';
import '../theme/admin_theme.dart';

const _rescueRed = Color(0xFFD92D20);
const _rescueRedDark = Color(0xFF9D2018);
const _rescueRedSoft = Color(0xFFFFEAE8);
const _rescueOrange = Color(0xFFF79009);

class RescueManagerScreen extends StatefulWidget {
  final User user;
  final RescueAdminRepository repository;
  final int initialTab;

  const RescueManagerScreen({
    super.key,
    required this.user,
    required this.repository,
    this.initialTab = 0,
  });

  @override
  State<RescueManagerScreen> createState() => _RescueManagerScreenState();
}

class _RescueManagerScreenState extends State<RescueManagerScreen> {
  late Stream<List<AdminRescueVolunteer>> _volunteers;
  late Stream<List<AdminRescueEvent>> _events;
  late Stream<List<AdminRescueNeed>> _needs;
  late Stream<List<AdminRescueAssignment>> _assignments;
  late Stream<double> _resources;
  late _ReplayBroadcast<List<AdminRescueVolunteer>> _volunteerRelay;
  late _ReplayBroadcast<List<AdminRescueEvent>> _eventRelay;
  late _ReplayBroadcast<List<AdminRescueNeed>> _needRelay;
  late _ReplayBroadcast<List<AdminRescueAssignment>> _assignmentRelay;
  late _ReplayBroadcast<double> _resourceRelay;
  final _search = TextEditingController();
  String _query = '';
  RescueReviewStatus? _volunteerFilter = RescueReviewStatus.pending;
  final Set<String> _reviewing = {};

  @override
  void initState() {
    super.initState();
    _bindStreams();
  }

  void _bindStreams() {
    _volunteerRelay = _ReplayBroadcast(widget.repository.watchVolunteers());
    _eventRelay = _ReplayBroadcast(widget.repository.watchEvents());
    _needRelay = _ReplayBroadcast(widget.repository.watchNeeds());
    _assignmentRelay = _ReplayBroadcast(widget.repository.watchAssignments());
    _resourceRelay = _ReplayBroadcast(
      widget.repository.watchAvailableResourceUnits(),
    );
    _volunteers = _volunteerRelay.stream;
    _events = _eventRelay.stream;
    _needs = _needRelay.stream;
    _assignments = _assignmentRelay.stream;
    _resources = _resourceRelay.stream;
  }

  @override
  void didUpdateWidget(covariant RescueManagerScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.repository != widget.repository) {
      _disposeRelays();
      _bindStreams();
    }
  }

  void _disposeRelays() {
    _volunteerRelay.dispose();
    _eventRelay.dispose();
    _needRelay.dispose();
    _assignmentRelay.dispose();
    _resourceRelay.dispose();
  }

  @override
  void dispose() {
    _search.dispose();
    _disposeRelays();
    super.dispose();
  }

  Future<void> _review(
    AdminRescueVolunteer volunteer,
    RescueReviewStatus status,
  ) async {
    String notes = '';
    if (status == RescueReviewStatus.suspended) {
      final result = await showDialog<String>(
        context: context,
        builder: (_) => _SuspensionDialog(volunteer: volunteer),
      );
      if (result == null) return;
      notes = result;
    } else {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          icon: const Icon(
            Icons.verified_user_outlined,
            color: AdminColors.success,
            size: 38,
          ),
          title: const Text('Vérifier ce volontaire ?'),
          content: Text(
            '${volunteer.fullName} pourra se déclarer disponible et recevoir des missions Rescue.',
            textAlign: TextAlign.center,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              key: const Key('confirm-rescue-verification'),
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(
                backgroundColor: AdminColors.success,
              ),
              child: const Text('Vérifier'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    setState(() => _reviewing.add(volunteer.id));
    try {
      await widget.repository.reviewVolunteer(
        volunteer: volunteer,
        adminUid: widget.user.uid,
        status: status,
        notes: notes,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              status == RescueReviewStatus.verified
                  ? 'Volontaire vérifié avec succès.'
                  : 'Volontaire suspendu.',
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('La décision n’a pas pu être enregistrée.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _reviewing.remove(volunteer.id));
    }
  }

  Future<void> _openVolunteer(AdminRescueVolunteer volunteer) =>
      showDialog<void>(
        context: context,
        builder: (_) => _VolunteerDetailDialog(
          volunteer: volunteer,
          repository: widget.repository,
          reviewing: _reviewing.contains(volunteer.id),
          onVerify: () {
            Navigator.pop(context);
            _review(volunteer, RescueReviewStatus.verified);
          },
          onSuspend: () {
            Navigator.pop(context);
            _review(volunteer, RescueReviewStatus.suspended);
          },
        ),
      );

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 3,
    initialIndex: widget.initialTab.clamp(0, 2),
    child: Column(
      children: [
        const _RescueAdminHeader(),
        const Material(
          color: Colors.white,
          child: TabBar(
            labelColor: _rescueRed,
            unselectedLabelColor: AdminColors.muted,
            indicatorColor: _rescueRed,
            tabs: [
              Tab(
                key: Key('rescue-dashboard-tab'),
                icon: Icon(Icons.monitor_heart_outlined),
                text: 'Vue d’ensemble',
              ),
              Tab(
                key: Key('rescue-volunteers-tab'),
                icon: Icon(Icons.groups_2_outlined),
                text: 'Volontaires',
              ),
              Tab(
                key: Key('rescue-operations-tab'),
                icon: Icon(Icons.crisis_alert_outlined),
                text: 'Opérations',
              ),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            children: [
              _RescueDashboard(
                volunteers: _volunteers,
                events: _events,
                needs: _needs,
                assignments: _assignments,
                resources: _resources,
              ),
              _volunteerView(),
              _OperationsView(
                events: _events,
                needs: _needs,
                repository: widget.repository,
                adminUid: widget.user.uid,
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _volunteerView() => StreamBuilder<List<AdminRescueVolunteer>>(
    stream: _volunteers,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Center(
          child: CircularProgressIndicator(color: _rescueRed),
        );
      }
      if (snapshot.hasError) {
        return const _RescueEmpty(
          icon: Icons.cloud_off_outlined,
          title: 'Volontaires indisponibles',
          message: 'Vérifiez la connexion à Supabase.',
        );
      }
      final query = _query.trim().toLowerCase();
      final all = snapshot.data ?? const [];
      final visible = all
          .where((volunteer) {
            final filterMatches =
                _volunteerFilter == null ||
                volunteer.verificationStatus == _volunteerFilter;
            final queryMatches =
                query.isEmpty ||
                '${volunteer.fullName} ${volunteer.professionLabel} ${volunteer.specialty} ${volunteer.organization}'
                    .toLowerCase()
                    .contains(query);
            return filterMatches && queryMatches;
          })
          .toList(growable: false);
      return CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 14),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final search = TextField(
                    key: const Key('rescue-volunteer-search'),
                    controller: _search,
                    onChanged: (value) => setState(() => _query = value),
                    decoration: const InputDecoration(
                      hintText: 'Nom, profession, spécialité, organisation...',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                  );
                  final filter = DropdownButtonFormField<RescueReviewStatus?>(
                    initialValue: _volunteerFilter,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Statut'),
                    items: const [
                      DropdownMenuItem(value: null, child: Text('Tous')),
                      DropdownMenuItem(
                        value: RescueReviewStatus.pending,
                        child: Text('En attente'),
                      ),
                      DropdownMenuItem(
                        value: RescueReviewStatus.verified,
                        child: Text('Vérifiés'),
                      ),
                      DropdownMenuItem(
                        value: RescueReviewStatus.suspended,
                        child: Text('Suspendus'),
                      ),
                    ],
                    onChanged: (value) =>
                        setState(() => _volunteerFilter = value),
                  );
                  if (constraints.maxWidth < 680) {
                    return Column(
                      children: [search, const SizedBox(height: 10), filter],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(child: search),
                      const SizedBox(width: 12),
                      SizedBox(width: 210, child: filter),
                    ],
                  );
                },
              ),
            ),
          ),
          if (visible.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: _RescueEmpty(
                icon: Icons.person_search_outlined,
                title: 'Aucun volontaire trouvé',
                message: 'Ajustez la recherche ou le statut.',
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
              sliver: SliverList.separated(
                itemCount: visible.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (_, index) => _VolunteerRow(
                  volunteer: visible[index],
                  reviewing: _reviewing.contains(visible[index].id),
                  onOpen: () => _openVolunteer(visible[index]),
                  onVerify: () =>
                      _review(visible[index], RescueReviewStatus.verified),
                  onSuspend: () =>
                      _review(visible[index], RescueReviewStatus.suspended),
                ),
              ),
            ),
        ],
      );
    },
  );
}

class _RescueAdminHeader extends StatelessWidget {
  const _RescueAdminHeader();

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(24, 20, 24, 18),
    decoration: const BoxDecoration(
      gradient: LinearGradient(colors: [_rescueRedDark, _rescueRed]),
    ),
    child: Row(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(2),
            child: Image.asset(
              'assets/services/i_entier_rescue_3d.png',
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
              semanticLabel: 'I-Entier Rescue',
            ),
          ),
        ),
        const SizedBox(width: 14),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'I-Entier Rescue',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 3),
              Text(
                'Centre national de coordination des volontaires',
                style: TextStyle(color: Color(0xFFFFDEDB)),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .15),
            borderRadius: BorderRadius.circular(99),
          ),
          child: const Row(
            children: [
              Icon(Icons.circle, size: 8, color: Colors.white),
              SizedBox(width: 7),
              Text(
                'OPÉRATIONNEL',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _RescueDashboard extends StatelessWidget {
  final Stream<List<AdminRescueVolunteer>> volunteers;
  final Stream<List<AdminRescueEvent>> events;
  final Stream<List<AdminRescueNeed>> needs;
  final Stream<List<AdminRescueAssignment>> assignments;
  final Stream<double> resources;

  const _RescueDashboard({
    required this.volunteers,
    required this.events,
    required this.needs,
    required this.assignments,
    required this.resources,
  });

  @override
  Widget build(BuildContext context) => ListView(
    key: const Key('rescue-admin-dashboard'),
    padding: const EdgeInsets.all(24),
    children: [
      Text(
        'Situation nationale',
        style: Theme.of(context).textTheme.headlineMedium,
      ),
      const SizedBox(height: 6),
      const Text(
        'Indicateurs de mobilisation et de réponse en temps réel.',
        style: TextStyle(color: AdminColors.muted),
      ),
      const SizedBox(height: 20),
      LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 1050
              ? 3
              : constraints.maxWidth >= 620
              ? 2
              : 1;
          return GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: columns,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: columns == 1 ? 3.3 : 2.25,
            children: [
              _VolunteerMetric(
                stream: volunteers,
                label: 'Volontaires inscrits',
                icon: Icons.groups_2_outlined,
                value: (items) => items.length.toString(),
              ),
              _VolunteerMetric(
                stream: volunteers,
                label: 'Volontaires actifs',
                icon: Icons.person_pin_circle_outlined,
                color: AdminColors.success,
                value: (items) => items
                    .where((item) => item.availability == 'available')
                    .length
                    .toString(),
              ),
              _AssignmentMetric(
                stream: assignments,
                label: 'Missions en cours',
                icon: Icons.route_outlined,
                value: (items) => items
                    .where(
                      (item) => const {
                        'accepted',
                        'en_route',
                        'on_site',
                      }.contains(item.status),
                    )
                    .length
                    .toString(),
              ),
              _EventMetric(
                stream: events,
                label: 'Catastrophes actives',
                icon: Icons.crisis_alert_outlined,
                color: _rescueRed,
                value: (items) => items
                    .where((item) => item.status == 'active')
                    .length
                    .toString(),
              ),
              _AssignmentMetric(
                stream: assignments,
                label: 'Temps moyen de réponse',
                icon: Icons.timer_outlined,
                color: _rescueOrange,
                value: _averageResponse,
              ),
              _ResourceMetric(stream: resources),
            ],
          );
        },
      ),
      const SizedBox(height: 22),
      LayoutBuilder(
        builder: (context, constraints) {
          final activeEvents = _ActiveEventsPanel(events: events);
          final urgentNeeds = _UrgentNeedsPanel(needs: needs);
          if (constraints.maxWidth < 850) {
            return Column(
              children: [activeEvents, const SizedBox(height: 14), urgentNeeds],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: activeEvents),
              const SizedBox(width: 14),
              Expanded(child: urgentNeeds),
            ],
          );
        },
      ),
    ],
  );

  String _averageResponse(List<AdminRescueAssignment> items) {
    final responded = items.where((item) => item.acceptedAt != null).toList();
    if (responded.isEmpty) return '—';
    final minutes =
        responded
            .map(
              (item) => item.acceptedAt!.difference(item.createdAt).inSeconds,
            )
            .fold<int>(0, (sum, value) => sum + value) /
        responded.length /
        60;
    return '${minutes.round()} min';
  }
}

class _LiveMetric<T> extends StatelessWidget {
  final Stream<List<T>> stream;
  final String label;
  final IconData icon;
  final Color color;
  final String Function(List<T>) value;

  const _LiveMetric({
    required this.stream,
    required this.label,
    required this.icon,
    required this.value,
    this.color = AdminColors.primary,
  });

  @override
  Widget build(BuildContext context) => StreamBuilder<List<T>>(
    stream: stream,
    builder: (_, snapshot) => _MetricCard(
      label: label,
      icon: icon,
      color: color,
      value: snapshot.hasData ? value(snapshot.data!) : '—',
    ),
  );
}

class _VolunteerMetric extends _LiveMetric<AdminRescueVolunteer> {
  const _VolunteerMetric({
    required super.stream,
    required super.label,
    required super.icon,
    required super.value,
    super.color,
  });
}

class _EventMetric extends _LiveMetric<AdminRescueEvent> {
  const _EventMetric({
    required super.stream,
    required super.label,
    required super.icon,
    required super.value,
    super.color,
  });
}

class _AssignmentMetric extends _LiveMetric<AdminRescueAssignment> {
  const _AssignmentMetric({
    required super.stream,
    required super.label,
    required super.icon,
    required super.value,
    super.color,
  });
}

class _ResourceMetric extends StatelessWidget {
  final Stream<double> stream;

  const _ResourceMetric({required this.stream});

  @override
  Widget build(BuildContext context) => StreamBuilder<double>(
    stream: stream,
    builder: (_, snapshot) => _MetricCard(
      label: 'Ressources disponibles',
      icon: Icons.inventory_2_outlined,
      color: const Color(0xFF7656D8),
      value: snapshot.hasData ? snapshot.data!.round().toString() : '—',
    ),
  );
}

class _MetricCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final String value;

  const _MetricCard({
    required this.label,
    required this.icon,
    required this.color,
    required this.value,
  });

  @override
  Widget build(BuildContext context) => AdminPanel(
    padding: const EdgeInsets.all(18),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            color: color.withValues(alpha: .1),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: color),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: const TextStyle(
                  color: AdminColors.ink,
                  fontSize: 25,
                  fontWeight: FontWeight.w700,
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

class _ActiveEventsPanel extends StatelessWidget {
  final Stream<List<AdminRescueEvent>> events;

  const _ActiveEventsPanel({required this.events});

  @override
  Widget build(BuildContext context) => AdminPanel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Événements actifs',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 14),
        StreamBuilder<List<AdminRescueEvent>>(
          stream: events,
          builder: (_, snapshot) {
            final items = (snapshot.data ?? const [])
                .where((item) => item.status == 'active')
                .take(4)
                .toList();
            if (items.isEmpty) return const Text('Aucun événement actif.');
            return Column(
              children: [
                for (final item in items)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const CircleAvatar(
                      backgroundColor: _rescueRedSoft,
                      child: Icon(Icons.warning_rounded, color: _rescueRed),
                    ),
                    title: Text(
                      item.title,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text('${item.typeLabel} • ${item.zoneName}'),
                    trailing: _AdminPill(
                      label: _priorityLabel(item.severity),
                      color: _priorityColor(item.severity),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    ),
  );
}

class _UrgentNeedsPanel extends StatelessWidget {
  final Stream<List<AdminRescueNeed>> needs;

  const _UrgentNeedsPanel({required this.needs});

  @override
  Widget build(BuildContext context) => AdminPanel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Besoins prioritaires',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 14),
        StreamBuilder<List<AdminRescueNeed>>(
          stream: needs,
          builder: (_, snapshot) {
            final items = (snapshot.data ?? const [])
                .where((item) => item.status != 'resolved')
                .take(4)
                .toList();
            if (items.isEmpty) return const Text('Aucun besoin ouvert.');
            return Column(
              children: [
                for (final item in items)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(
                      Icons.inventory_2_outlined,
                      color: _rescueOrange,
                    ),
                    title: Text(
                      item.typeLabel,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      item.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: _AdminPill(
                      label: _priorityLabel(item.priority),
                      color: _priorityColor(item.priority),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    ),
  );
}

class _VolunteerRow extends StatelessWidget {
  final AdminRescueVolunteer volunteer;
  final bool reviewing;
  final VoidCallback onOpen;
  final VoidCallback onVerify;
  final VoidCallback onSuspend;

  const _VolunteerRow({
    required this.volunteer,
    required this.reviewing,
    required this.onOpen,
    required this.onVerify,
    required this.onSuspend,
  });

  @override
  Widget build(BuildContext context) => AdminPanel(
    padding: const EdgeInsets.all(16),
    child: Row(
      children: [
        CircleAvatar(
          backgroundColor: _rescueRedSoft,
          child: const Icon(
            Icons.health_and_safety_outlined,
            color: _rescueRed,
          ),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: InkWell(
            onTap: onOpen,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  volunteer.fullName,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 3),
                Text(
                  '${volunteer.professionLabel}${volunteer.specialty.isEmpty ? '' : ' • ${volunteer.specialty}'}',
                  style: const TextStyle(color: AdminColors.muted),
                ),
              ],
            ),
          ),
        ),
        _AdminPill(
          label: volunteer.verificationStatus.label,
          color: _reviewColor(volunteer.verificationStatus),
        ),
        const SizedBox(width: 10),
        if (reviewing)
          const SizedBox.square(
            dimension: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        else if (volunteer.verificationStatus == RescueReviewStatus.pending)
          FilledButton.icon(
            onPressed: onVerify,
            style: FilledButton.styleFrom(backgroundColor: AdminColors.success),
            icon: const Icon(Icons.verified_outlined, size: 18),
            label: const Text('Vérifier'),
          )
        else
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'open') onOpen();
              if (value == 'suspend') onSuspend();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'open', child: Text('Voir le dossier')),
              PopupMenuItem(value: 'suspend', child: Text('Suspendre')),
            ],
          ),
      ],
    ),
  );
}

class _VolunteerDetailDialog extends StatelessWidget {
  final AdminRescueVolunteer volunteer;
  final RescueAdminRepository repository;
  final bool reviewing;
  final VoidCallback onVerify;
  final VoidCallback onSuspend;

  const _VolunteerDetailDialog({
    required this.volunteer,
    required this.repository,
    required this.reviewing,
    required this.onVerify,
    required this.onSuspend,
  });

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Row(
      children: [
        const Icon(Icons.badge_outlined, color: _rescueRed),
        const SizedBox(width: 10),
        Expanded(child: Text(volunteer.fullName)),
      ],
    ),
    content: SizedBox(
      width: 620,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DialogInfo(label: 'Profession', value: volunteer.professionLabel),
            _DialogInfo(
              label: 'Spécialité',
              value: volunteer.specialty.isEmpty
                  ? 'Non précisée'
                  : volunteer.specialty,
            ),
            _DialogInfo(label: 'Téléphone', value: volunteer.phone),
            _DialogInfo(
              label: 'Organisation',
              value: volunteer.organization.isEmpty
                  ? 'Indépendant'
                  : volunteer.organization,
            ),
            _DialogInfo(
              label: 'Compétences',
              value: volunteer.skills.isEmpty
                  ? 'Non précisées'
                  : volunteer.skills.join(', '),
            ),
            _DialogInfo(
              label: 'Rayon d’intervention',
              value: '${volunteer.interventionRadiusKm} km',
            ),
            const SizedBox(height: 14),
            const Text(
              'Justificatifs privés',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            FutureBuilder<List<AdminRescueDocument>>(
              future: repository.loadDocuments(volunteer.id),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const LinearProgressIndicator();
                }
                final documents = snapshot.data ?? const [];
                if (documents.isEmpty) {
                  return const Text('Aucun document déposé.');
                }
                return Column(
                  children: [
                    for (final document in documents)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(
                          Icons.description_outlined,
                          color: _rescueRed,
                        ),
                        title: Text(document.typeLabel),
                        subtitle: Text(document.fileName),
                        trailing: IconButton(
                          tooltip: 'Ouvrir pendant 5 minutes',
                          onPressed: () async {
                            final url = await repository.createDocumentUrl(
                              document.storagePath,
                            );
                            await launchUrl(
                              Uri.parse(url),
                              mode: LaunchMode.externalApplication,
                            );
                          },
                          icon: const Icon(Icons.open_in_new_rounded),
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
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Fermer'),
      ),
      if (volunteer.verificationStatus == RescueReviewStatus.verified)
        OutlinedButton(
          onPressed: reviewing ? null : onSuspend,
          child: const Text('Suspendre'),
        ),
      if (volunteer.verificationStatus != RescueReviewStatus.verified)
        FilledButton(
          onPressed: reviewing ? null : onVerify,
          style: FilledButton.styleFrom(backgroundColor: AdminColors.success),
          child: const Text('Vérifier'),
        ),
    ],
  );
}

class _OperationsView extends StatelessWidget {
  final Stream<List<AdminRescueEvent>> events;
  final Stream<List<AdminRescueNeed>> needs;
  final RescueAdminRepository repository;
  final String adminUid;

  const _OperationsView({
    required this.events,
    required this.needs,
    required this.repository,
    required this.adminUid,
  });

  @override
  Widget build(BuildContext context) => StreamBuilder<List<AdminRescueEvent>>(
    stream: events,
    builder: (context, eventSnapshot) {
      final eventItems = eventSnapshot.data ?? const [];
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 12,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Centre des opérations',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const Text(
                    'Catastrophes, alertes multicanales et besoins urgents.',
                  ),
                ],
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    key: const Key('rescue-create-need'),
                    onPressed: eventItems.isEmpty
                        ? null
                        : () => _createNeed(context, eventItems),
                    icon: const Icon(Icons.inventory_2_outlined),
                    label: const Text('Nouveau besoin'),
                  ),
                  FilledButton.icon(
                    key: const Key('rescue-send-alert'),
                    onPressed: eventItems.isEmpty
                        ? null
                        : () => _sendAlert(context, eventItems),
                    style: FilledButton.styleFrom(backgroundColor: _rescueRed),
                    icon: const Icon(Icons.campaign_outlined),
                    label: const Text('Créer une alerte'),
                  ),
                  FilledButton.icon(
                    key: const Key('rescue-create-event'),
                    onPressed: () => _createEvent(context),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Nouvel événement'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text('Événements', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          if (eventSnapshot.connectionState == ConnectionState.waiting)
            const LinearProgressIndicator()
          else if (eventItems.isEmpty)
            const AdminPanel(
              child: Text('Créez un événement pour démarrer une opération.'),
            )
          else
            ...eventItems.map(
              (event) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _EventRow(event: event),
              ),
            ),
          const SizedBox(height: 16),
          Text(
            'Besoins urgents',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 10),
          StreamBuilder<List<AdminRescueNeed>>(
            stream: needs,
            builder: (context, snapshot) {
              final items = snapshot.data ?? const [];
              if (items.isEmpty) {
                return const AdminPanel(
                  child: Text('Aucun besoin enregistré.'),
                );
              }
              return Column(
                children: [
                  for (final need in items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 9),
                      child: _NeedRow(
                        need: need,
                        onStatus: (status) =>
                            repository.updateNeedStatus(need.id, status),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      );
    },
  );

  Future<void> _createEvent(BuildContext context) async {
    final draft = await showDialog<RescueEventDraft>(
      context: context,
      builder: (_) => const _EventDialog(),
    );
    if (draft == null) return;
    try {
      await repository.createEvent(draft, adminUid);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Événement Rescue créé.')));
      }
    } catch (_) {
      if (context.mounted) _showFailure(context);
    }
  }

  Future<void> _createNeed(
    BuildContext context,
    List<AdminRescueEvent> events,
  ) async {
    final draft = await showDialog<RescueNeedDraft>(
      context: context,
      builder: (_) => _NeedDialog(events: events),
    );
    if (draft == null) return;
    try {
      await repository.createNeed(draft, adminUid);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Besoin urgent enregistré.')),
        );
      }
    } catch (_) {
      if (context.mounted) _showFailure(context);
    }
  }

  Future<void> _sendAlert(
    BuildContext context,
    List<AdminRescueEvent> events,
  ) async {
    final draft = await showDialog<RescueAlertDraft>(
      context: context,
      builder: (_) => _AlertDialog(events: events),
    );
    if (draft == null) return;
    try {
      final count = await repository.sendAlert(draft, adminUid);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Alerte envoyée à $count volontaire${count > 1 ? 's' : ''} par Push, SMS et e-mail.',
            ),
          ),
        );
      }
    } catch (_) {
      if (context.mounted) _showFailure(context);
    }
  }

  void _showFailure(BuildContext context) =>
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('L’opération n’a pas pu être enregistrée.'),
        ),
      );
}

class _EventRow extends StatelessWidget {
  final AdminRescueEvent event;

  const _EventRow({required this.event});

  @override
  Widget build(BuildContext context) => AdminPanel(
    padding: const EdgeInsets.all(16),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _priorityColor(event.severity).withValues(alpha: .1),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(
            Icons.crisis_alert_rounded,
            color: _priorityColor(event.severity),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                event.title,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              Text(
                '${event.typeLabel} • ${event.zoneName} • ${event.estimatedVictims} victime(s) estimée(s)',
              ),
            ],
          ),
        ),
        _AdminPill(
          label: _priorityLabel(event.severity),
          color: _priorityColor(event.severity),
        ),
      ],
    ),
  );
}

class _NeedRow extends StatelessWidget {
  final AdminRescueNeed need;
  final ValueChanged<String> onStatus;

  const _NeedRow({required this.need, required this.onStatus});

  @override
  Widget build(BuildContext context) => AdminPanel(
    padding: const EdgeInsets.all(16),
    child: Row(
      children: [
        const Icon(Icons.inventory_2_outlined, color: _rescueOrange),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                need.typeLabel,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              Text(need.description),
            ],
          ),
        ),
        _AdminPill(
          label: _priorityLabel(need.priority),
          color: _priorityColor(need.priority),
        ),
        const SizedBox(width: 8),
        DropdownButton<String>(
          value: need.status,
          underline: const SizedBox.shrink(),
          items: const [
            DropdownMenuItem(value: 'open', child: Text('Ouverte')),
            DropdownMenuItem(value: 'in_progress', child: Text('En cours')),
            DropdownMenuItem(value: 'resolved', child: Text('Résolue')),
          ],
          onChanged: (value) {
            if (value != null) onStatus(value);
          },
        ),
      ],
    ),
  );
}

class _EventDialog extends StatefulWidget {
  const _EventDialog();

  @override
  State<_EventDialog> createState() => _EventDialogState();
}

class _EventDialogState extends State<_EventDialog> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _zone = TextEditingController();
  final _victims = TextEditingController(text: '0');
  final _priorities = TextEditingController();
  final _description = TextEditingController();
  String _type = 'earthquake';
  String _severity = 'high';

  @override
  void dispose() {
    _title.dispose();
    _zone.dispose();
    _victims.dispose();
    _priorities.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Nouvel événement'),
    content: SizedBox(
      width: 560,
      child: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            children: [
              TextFormField(
                key: const Key('rescue-event-title'),
                controller: _title,
                decoration: const InputDecoration(labelText: 'Titre *'),
                validator: _required,
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: _type,
                decoration: const InputDecoration(labelText: 'Type'),
                items: const [
                  DropdownMenuItem(value: 'earthquake', child: Text('Séisme')),
                  DropdownMenuItem(value: 'flood', child: Text('Inondation')),
                  DropdownMenuItem(value: 'cyclone', child: Text('Cyclone')),
                  DropdownMenuItem(value: 'fire', child: Text('Incendie')),
                  DropdownMenuItem(value: 'epidemic', child: Text('Épidémie')),
                  DropdownMenuItem(
                    value: 'landslide',
                    child: Text('Glissement de terrain'),
                  ),
                  DropdownMenuItem(
                    value: 'humanitarian_crisis',
                    child: Text('Crise humanitaire'),
                  ),
                  DropdownMenuItem(value: 'other', child: Text('Autre')),
                ],
                onChanged: (value) => _type = value ?? _type,
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: _severity,
                decoration: const InputDecoration(labelText: 'Gravité'),
                items: _priorityItems,
                onChanged: (value) => _severity = value ?? _severity,
              ),
              const SizedBox(height: 10),
              TextFormField(
                key: const Key('rescue-event-zone'),
                controller: _zone,
                decoration: const InputDecoration(
                  labelText: 'Zone concernée *',
                ),
                validator: _required,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _victims,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Victimes estimées',
                ),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _priorities,
                decoration: const InputDecoration(
                  labelText: 'Priorités, séparées par des virgules',
                ),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _description,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Description'),
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
        key: const Key('confirm-rescue-event'),
        onPressed: () {
          if (_form.currentState?.validate() != true) return;
          Navigator.pop(
            context,
            RescueEventDraft(
              title: _title.text,
              eventType: _type,
              severity: _severity,
              zoneName: _zone.text,
              estimatedVictims: int.tryParse(_victims.text) ?? 0,
              priorities: _split(_priorities.text),
              description: _description.text,
            ),
          );
        },
        child: const Text('Créer'),
      ),
    ],
  );
}

class _NeedDialog extends StatefulWidget {
  final List<AdminRescueEvent> events;

  const _NeedDialog({required this.events});

  @override
  State<_NeedDialog> createState() => _NeedDialogState();
}

class _NeedDialogState extends State<_NeedDialog> {
  final _form = GlobalKey<FormState>();
  final _description = TextEditingController();
  final _quantity = TextEditingController();
  final _unit = TextEditingController();
  late String _event = widget.events.first.id;
  String _type = 'blood';
  String _priority = 'critical';

  @override
  void dispose() {
    _description.dispose();
    _quantity.dispose();
    _unit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Nouveau besoin urgent'),
    content: SizedBox(
      width: 540,
      child: Form(
        key: _form,
        child: SingleChildScrollView(
          child: Column(
            children: [
              DropdownButtonFormField<String>(
                initialValue: _event,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Événement'),
                items: [
                  for (final event in widget.events)
                    DropdownMenuItem(value: event.id, child: Text(event.title)),
                ],
                onChanged: (value) => _event = value ?? _event,
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: _type,
                decoration: const InputDecoration(labelText: 'Type'),
                items: const [
                  DropdownMenuItem(value: 'blood', child: Text('Sang')),
                  DropdownMenuItem(
                    value: 'medication',
                    child: Text('Médicaments'),
                  ),
                  DropdownMenuItem(
                    value: 'medical_equipment',
                    child: Text('Matériel médical'),
                  ),
                  DropdownMenuItem(
                    value: 'ambulance',
                    child: Text('Ambulances'),
                  ),
                  DropdownMenuItem(
                    value: 'medical_staff',
                    child: Text('Personnel médical'),
                  ),
                  DropdownMenuItem(
                    value: 'drinking_water',
                    child: Text('Eau potable'),
                  ),
                  DropdownMenuItem(value: 'food', child: Text('Nourriture')),
                ],
                onChanged: (value) => _type = value ?? _type,
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: _priority,
                decoration: const InputDecoration(labelText: 'Priorité'),
                items: _priorityItems,
                onChanged: (value) => _priority = value ?? _priority,
              ),
              const SizedBox(height: 10),
              TextFormField(
                key: const Key('rescue-need-description'),
                controller: _description,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Description *'),
                validator: _required,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _quantity,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Quantité'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _unit,
                      decoration: const InputDecoration(labelText: 'Unité'),
                    ),
                  ),
                ],
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
        key: const Key('confirm-rescue-need'),
        onPressed: () {
          if (_form.currentState?.validate() != true) return;
          Navigator.pop(
            context,
            RescueNeedDraft(
              eventId: _event,
              type: _type,
              description: _description.text,
              priority: _priority,
              quantity: double.tryParse(_quantity.text.replaceAll(',', '.')),
              unit: _unit.text,
            ),
          );
        },
        child: const Text('Créer'),
      ),
    ],
  );
}

class _AlertDialog extends StatefulWidget {
  final List<AdminRescueEvent> events;

  const _AlertDialog({required this.events});

  @override
  State<_AlertDialog> createState() => _AlertDialogState();
}

class _AlertDialogState extends State<_AlertDialog> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _message = TextEditingController();
  final _instructions = TextEditingController();
  final Set<String> _professions = {};
  late String _event = widget.events.first.id;
  String _priority = 'critical';
  double _limit = 20;

  @override
  void dispose() {
    _title.dispose();
    _message.dispose();
    _instructions.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Créer et diffuser une alerte'),
    content: SizedBox(
      width: 620,
      child: Form(
        key: _form,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<String>(
                initialValue: _event,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Événement'),
                items: [
                  for (final event in widget.events)
                    DropdownMenuItem(value: event.id, child: Text(event.title)),
                ],
                onChanged: (value) => _event = value ?? _event,
              ),
              const SizedBox(height: 10),
              TextFormField(
                key: const Key('rescue-alert-title'),
                controller: _title,
                decoration: const InputDecoration(labelText: 'Titre *'),
                validator: _required,
              ),
              const SizedBox(height: 10),
              TextFormField(
                key: const Key('rescue-alert-message'),
                controller: _message,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Message *'),
                validator: _required,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _instructions,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Instructions de mission',
                ),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: _priority,
                decoration: const InputDecoration(labelText: 'Priorité'),
                items: _priorityItems,
                onChanged: (value) => _priority = value ?? _priority,
              ),
              const SizedBox(height: 15),
              const Text(
                'Professions ciblées',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const Text(
                'Aucune sélection = toutes les professions.',
                style: TextStyle(color: AdminColors.muted, fontSize: 12),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: [
                  for (final item in _professionItems)
                    FilterChip(
                      label: Text(item.$2),
                      selected: _professions.contains(item.$1),
                      onSelected: (selected) => setState(
                        () => selected
                            ? _professions.add(item.$1)
                            : _professions.remove(item.$1),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Nombre maximal de volontaires : ${_limit.round()}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              Slider(
                value: _limit,
                min: 1,
                max: 100,
                divisions: 99,
                activeColor: _rescueRed,
                onChanged: (value) => setState(() => _limit = value),
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _rescueRedSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.notifications_active_outlined,
                      color: _rescueRed,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Diffusion simultanée par notification Push, SMS et e-mail. Affectation selon proximité, compétences et disponibilité.',
                      ),
                    ),
                  ],
                ),
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
      FilledButton.icon(
        key: const Key('confirm-rescue-alert'),
        onPressed: () {
          if (_form.currentState?.validate() != true) return;
          Navigator.pop(
            context,
            RescueAlertDraft(
              eventId: _event,
              title: _title.text,
              message: _message.text,
              instructions: _instructions.text,
              priority: _priority,
              targetProfessions: _professions.toList(),
              volunteerLimit: _limit.round(),
            ),
          );
        },
        style: FilledButton.styleFrom(backgroundColor: _rescueRed),
        icon: const Icon(Icons.send_rounded),
        label: const Text('Diffuser l’alerte'),
      ),
    ],
  );
}

class _SuspensionDialog extends StatefulWidget {
  final AdminRescueVolunteer volunteer;

  const _SuspensionDialog({required this.volunteer});

  @override
  State<_SuspensionDialog> createState() => _SuspensionDialogState();
}

class _SuspensionDialogState extends State<_SuspensionDialog> {
  final _form = GlobalKey<FormState>();
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    icon: const Icon(Icons.block_outlined, color: AdminColors.danger, size: 36),
    title: const Text('Suspendre le volontaire'),
    content: SizedBox(
      width: 480,
      child: Form(
        key: _form,
        child: TextFormField(
          key: const Key('rescue-suspension-reason'),
          controller: _reason,
          maxLines: 4,
          decoration: InputDecoration(
            labelText: 'Motif obligatoire',
            hintText:
                'Expliquez la suspension de ${widget.volunteer.fullName}.',
          ),
          validator: _required,
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Annuler'),
      ),
      FilledButton(
        key: const Key('confirm-rescue-suspension'),
        onPressed: () {
          if (_form.currentState?.validate() == true) {
            Navigator.pop(context, _reason.text.trim());
          }
        },
        style: FilledButton.styleFrom(backgroundColor: AdminColors.danger),
        child: const Text('Suspendre'),
      ),
    ],
  );
}

class _DialogInfo extends StatelessWidget {
  final String label;
  final String value;

  const _DialogInfo({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 145,
          child: Text(label, style: const TextStyle(color: AdminColors.muted)),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );
}

class _AdminPill extends StatelessWidget {
  final String label;
  final Color color;

  const _AdminPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .1),
      borderRadius: BorderRadius.circular(99),
    ),
    child: Text(
      label,
      style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700),
    ),
  );
}

class _RescueEmpty extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _RescueEmpty({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: _rescueRed),
          const SizedBox(height: 12),
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(message, textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}

String? _required(String? value) =>
    value == null || value.trim().isEmpty ? 'Ce champ est requis.' : null;

List<String> _split(String value) => value
    .split(',')
    .map((item) => item.trim())
    .where((item) => item.isNotEmpty)
    .toList();

String _priorityLabel(String value) => switch (value) {
  'critical' => 'Critique',
  'high' => 'Élevée',
  'medium' => 'Moyenne',
  _ => 'Faible',
};

Color _priorityColor(String value) => switch (value) {
  'critical' => _rescueRed,
  'high' => _rescueOrange,
  'medium' => AdminColors.primary,
  _ => AdminColors.success,
};

Color _reviewColor(RescueReviewStatus status) => switch (status) {
  RescueReviewStatus.pending => _rescueOrange,
  RescueReviewStatus.verified => AdminColors.success,
  RescueReviewStatus.suspended => _rescueRed,
};

const _priorityItems = [
  DropdownMenuItem(value: 'critical', child: Text('Critique')),
  DropdownMenuItem(value: 'high', child: Text('Élevée')),
  DropdownMenuItem(value: 'medium', child: Text('Moyenne')),
  DropdownMenuItem(value: 'low', child: Text('Faible')),
];

const _professionItems = [
  ('general_practitioner', 'Médecin généraliste'),
  ('specialist_doctor', 'Médecin spécialiste'),
  ('nurse', 'Infirmière'),
  ('midwife', 'Sage-femme'),
  ('paramedic', 'Ambulancier'),
  ('first_responder', 'Secouriste'),
  ('pharmacist', 'Pharmacien'),
  ('psychologist', 'Psychologue'),
  ('health_student', 'Étudiant en santé'),
  ('other', 'Autre'),
];

/// Partage une seule souscription temps réel et rejoue la dernière valeur aux
/// vues créées plus tard par [TabBarView].
class _ReplayBroadcast<T> {
  late final StreamController<T> _controller;
  late final StreamSubscription<T> _subscription;
  T? _latest;
  bool _hasLatest = false;

  _ReplayBroadcast(Stream<T> source) {
    _controller = StreamController<T>.broadcast();
    _subscription = source.listen(
      (value) {
        _latest = value;
        _hasLatest = true;
        if (!_controller.isClosed) _controller.add(value);
      },
      onError: (Object error, StackTrace stackTrace) {
        if (!_controller.isClosed) _controller.addError(error, stackTrace);
      },
    );
  }

  Stream<T> get stream => Stream<T>.multi((emitter) {
    if (_hasLatest) emitter.add(_latest as T);
    final subscription = _controller.stream.listen(
      emitter.add,
      onError: emitter.addError,
      onDone: emitter.close,
    );
    emitter.onCancel = subscription.cancel;
  });

  void dispose() {
    unawaited(_subscription.cancel());
    unawaited(_controller.close());
  }
}
