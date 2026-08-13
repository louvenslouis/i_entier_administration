import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i_entier_administration/data/rescue_admin_repository.dart';
import 'package:i_entier_administration/models/rescue_models.dart';
import 'package:i_entier_administration/screens/rescue_manager_screen.dart';
import 'package:i_entier_administration/theme/admin_theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  final pendingVolunteer = AdminRescueVolunteer(
    id: 'volunteer-1',
    userId: 'user-1',
    fullName: 'Marie Jean',
    phone: '+509 3700 0000',
    profession: 'nurse',
    specialty: 'Urgences',
    organization: 'Hôpital communautaire',
    skills: const ['Triage', 'Premiers soins'],
    verificationStatus: RescueReviewStatus.pending,
    availability: 'offline',
    interventionRadiusKm: 30,
    locationConsent: false,
    latitude: null,
    longitude: null,
    reviewNotes: '',
    createdAt: DateTime(2026, 8, 3),
  );

  final event = AdminRescueEvent(
    id: 'event-1',
    title: 'Séisme dans l’Ouest',
    eventType: 'earthquake',
    severity: 'critical',
    status: 'active',
    zoneName: 'Delmas',
    estimatedVictims: 120,
    priorities: const ['Triage', 'Évacuation'],
    startsAt: DateTime(2026, 8, 3),
  );

  testWidgets('affiche les six indicateurs du tableau Rescue', (tester) async {
    await _desktop(tester);
    final repository = _FakeRescueAdminRepository(
      volunteers: [pendingVolunteer, _verifiedVolunteer],
      events: [event],
      needs: const [],
      assignments: [
        AdminRescueAssignment(
          id: 'assignment-1',
          status: 'accepted',
          createdAt: DateTime(2026, 8, 3, 10),
          acceptedAt: DateTime(2026, 8, 3, 10, 5),
        ),
      ],
      resourceUnits: 245,
    );

    await tester.pumpWidget(_manager(repository));
    await tester.pumpAndSettle();

    expect(find.text('Situation nationale'), findsOneWidget);
    expect(
      find.image(const AssetImage('assets/services/i_entier_rescue_3d.png')),
      findsOneWidget,
    );
    expect(find.text('Volontaires inscrits'), findsOneWidget);
    expect(find.text('Volontaires actifs'), findsOneWidget);
    expect(find.text('Missions en cours'), findsOneWidget);
    expect(find.text('Catastrophes actives'), findsOneWidget);
    expect(find.text('Temps moyen de réponse'), findsOneWidget);
    expect(find.text('Ressources disponibles'), findsOneWidget);
    expect(find.text('5 min'), findsOneWidget);
    expect(find.text('245'), findsOneWidget);
  });

  testWidgets('vérifie un dossier volontaire après confirmation', (
    tester,
  ) async {
    await _desktop(tester);
    final repository = _FakeRescueAdminRepository(
      volunteers: [pendingVolunteer],
    );

    await tester.pumpWidget(_manager(repository, initialTab: 1));
    await tester.pumpAndSettle();
    expect(find.text('Marie Jean'), findsOneWidget);
    expect(find.text('Infirmière • Urgences'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Vérifier'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-rescue-verification')));
    await tester.pumpAndSettle();

    expect(repository.reviews, hasLength(1));
    expect(repository.reviews.single.$1, 'volunteer-1');
    expect(repository.reviews.single.$2, RescueReviewStatus.verified);
  });

  testWidgets('diffuse une alerte multicanale avec affectation automatique', (
    tester,
  ) async {
    await _desktop(tester);
    final repository = _FakeRescueAdminRepository(events: [event]);

    await tester.pumpWidget(_manager(repository, initialTab: 2));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('rescue-send-alert')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('rescue-alert-title')),
      'Renfort médical immédiat',
    );
    await tester.enterText(
      find.byKey(const Key('rescue-alert-message')),
      'Besoin urgent de volontaires vérifiés.',
    );
    await tester.tap(find.byKey(const Key('confirm-rescue-alert')));
    await tester.pumpAndSettle();

    expect(repository.alerts, hasLength(1));
    expect(repository.alerts.single.title, 'Renfort médical immédiat');
    expect(
      find.textContaining('Alerte envoyée à 3 volontaires'),
      findsOneWidget,
    );
  });
}

final _verifiedVolunteer = AdminRescueVolunteer(
  id: 'volunteer-2',
  userId: 'user-2',
  fullName: 'Jean Pierre',
  phone: '+509 3800 0000',
  profession: 'first_responder',
  specialty: '',
  organization: '',
  skills: const ['Premiers soins'],
  verificationStatus: RescueReviewStatus.verified,
  availability: 'available',
  interventionRadiusKm: 25,
  locationConsent: true,
  latitude: 18.55,
  longitude: -72.3,
  reviewNotes: '',
  createdAt: DateTime(2026, 8, 2),
);

Future<void> _desktop(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(1280, 1000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

Widget _manager(_FakeRescueAdminRepository repository, {int initialTab = 0}) =>
    MaterialApp(
      theme: buildAdminTheme(),
      home: Scaffold(
        body: RescueManagerScreen(
          user: User(
            id: 'admin-1',
            appMetadata: const {},
            userMetadata: const {'full_name': 'Admin Rescue'},
            aud: 'authenticated',
            email: 'admin@ientier.ht',
            createdAt: DateTime(2026, 8, 1).toIso8601String(),
          ),
          repository: repository,
          initialTab: initialTab,
        ),
      ),
    );

class _FakeRescueAdminRepository implements RescueAdminRepository {
  final List<AdminRescueVolunteer> volunteers;
  final List<AdminRescueEvent> events;
  final List<AdminRescueNeed> needs;
  final List<AdminRescueAssignment> assignments;
  final double resourceUnits;
  final List<(String, RescueReviewStatus, String)> reviews = [];
  final List<RescueAlertDraft> alerts = [];

  _FakeRescueAdminRepository({
    this.volunteers = const [],
    this.events = const [],
    this.needs = const [],
    this.assignments = const [],
    this.resourceUnits = 0,
  });

  @override
  Stream<List<AdminRescueVolunteer>> watchVolunteers() =>
      Stream.value(volunteers);

  @override
  Stream<List<AdminRescueEvent>> watchEvents() => Stream.value(events);

  @override
  Stream<List<AdminRescueNeed>> watchNeeds() => Stream.value(needs);

  @override
  Stream<List<AdminRescueAssignment>> watchAssignments() =>
      Stream.value(assignments);

  @override
  Stream<double> watchAvailableResourceUnits() => Stream.value(resourceUnits);

  @override
  Future<List<AdminRescueDocument>> loadDocuments(String volunteerId) async =>
      const [];

  @override
  Future<String> createDocumentUrl(String storagePath) async => '';

  @override
  Future<void> reviewVolunteer({
    required AdminRescueVolunteer volunteer,
    required String adminUid,
    required RescueReviewStatus status,
    String notes = '',
  }) async {
    reviews.add((volunteer.id, status, notes));
  }

  @override
  Future<String> createEvent(RescueEventDraft draft, String adminUid) async =>
      'event-new';

  @override
  Future<String> createNeed(RescueNeedDraft draft, String adminUid) async =>
      'need-new';

  @override
  Future<int> sendAlert(RescueAlertDraft draft, String adminUid) async {
    alerts.add(draft);
    return 3;
  }

  @override
  Future<void> updateNeedStatus(String needId, String status) async {}
}
