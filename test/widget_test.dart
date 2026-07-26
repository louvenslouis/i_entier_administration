import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i_entier_administration/data/admin_repository.dart';
import 'package:i_entier_administration/models/provider_application.dart';
import 'package:i_entier_administration/screens/admin_dashboard_screen.dart';
import 'package:i_entier_administration/screens/admin_sign_in_screen.dart';
import 'package:i_entier_administration/theme/admin_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestWidgetsFlutterBinding.instance.platformDispatcher.views.first
      ..physicalSize = const Size(1440, 1000)
      ..devicePixelRatio = 1;
  });

  tearDown(() {
    TestWidgetsFlutterBinding.instance.platformDispatcher.views.first
      ..resetPhysicalSize()
      ..resetDevicePixelRatio();
  });

  testWidgets('affiche l’accès sécurisé à l’administration', (tester) async {
    await tester.pumpWidget(
      MaterialApp(theme: buildAdminTheme(), home: const AdminSignInScreen()),
    );

    expect(find.text('i-ENTIER'), findsOneWidget);
    expect(find.text('ADMINISTRATION'), findsOneWidget);
    expect(find.text('Accès à l’administration'), findsOneWidget);
    expect(find.text('Continuer avec Google'), findsOneWidget);
  });

  testWidgets('affiche et filtre les demandes en attente', (tester) async {
    final repository = _FakeAdminRepository([
      _application(
        id: 'professional-1',
        name: 'Dr Marie Louis',
        category: 'Cardiologue',
      ),
      _application(
        id: 'institution-1',
        name: 'Clinique Espoir',
        category: 'Clinique',
        type: ApplicationType.institution,
      ),
    ]);

    await tester.pumpWidget(_dashboard(repository));
    await tester.pumpAndSettle();

    expect(find.text('Validation des professionnels'), findsOneWidget);
    expect(find.text('Dr Marie Louis'), findsOneWidget);
    expect(find.text('Clinique Espoir'), findsOneWidget);
    expect(find.text('2 demandes'), findsOneWidget);

    await tester.tap(find.text('Institutions'));
    await tester.pump();

    expect(find.text('Dr Marie Louis'), findsNothing);
    expect(find.text('Clinique Espoir'), findsOneWidget);
    expect(find.text('1 demande'), findsOneWidget);
  });

  testWidgets('confirme et enregistre une approbation', (tester) async {
    final repository = _FakeAdminRepository([
      _application(
        id: 'professional-1',
        name: 'Dr Marie Louis',
        category: 'Cardiologue',
      ),
    ]);

    await tester.pumpWidget(_dashboard(repository));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Approuver').first);
    await tester.pumpAndSettle();

    expect(find.text('Approuver cette demande ?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Approuver').last);
    await tester.pumpAndSettle();

    expect(repository.reviews, hasLength(1));
    expect(repository.reviews.single.status, ApplicationStatus.approved);
    expect(repository.reviews.single.adminUid, 'admin-1');
  });

  testWidgets('exige et enregistre un motif de refus', (tester) async {
    final repository = _FakeAdminRepository([
      _application(
        id: 'professional-1',
        name: 'Dr Marie Louis',
        category: 'Cardiologue',
      ),
    ]);

    await tester.pumpWidget(_dashboard(repository));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, 'Refuser').first);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('confirm-rejection')));
    await tester.pump();
    expect(find.text('Un motif est requis.'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('rejection-reason-field')),
      'Licence professionnelle illisible.',
    );
    await tester.tap(find.byKey(const ValueKey('confirm-rejection')));
    await tester.pumpAndSettle();

    expect(repository.reviews, hasLength(1));
    expect(repository.reviews.single.status, ApplicationStatus.rejected);
    expect(
      repository.reviews.single.reason,
      'Licence professionnelle illisible.',
    );
  });

  testWidgets('affiche les tarifs publiés d’une institution à vérifier', (
    tester,
  ) async {
    final repository = _FakeAdminRepository([
      _application(
        id: 'institution-1',
        name: 'Clinique Espoir',
        category: 'Clinique',
        type: ApplicationType.institution,
        institutionPricesPublished: true,
        servicePrices: 'Consultation : 2 500',
        roomPrices: 'Chambre standard : 6 000 / nuit',
      ),
    ]);

    await tester.pumpWidget(_dashboard(repository));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Voir le dossier'));
    await tester.pumpAndSettle();

    expect(find.text('Tarifs de l’institution'), findsOneWidget);
    expect(find.text('Autorisée par l’institution'), findsOneWidget);
    expect(find.text('Consultation : 2 500'), findsOneWidget);
    expect(find.text('Chambre standard : 6 000 / nuit'), findsOneWidget);
  });
}

Widget _dashboard(_FakeAdminRepository repository) => MaterialApp(
  theme: buildAdminTheme(),
  home: AdminDashboardScreen(
    user: _FakeUser(
      uid: 'admin-1',
      email: 'admin@ientier.ht',
      displayName: 'Administration i-ENTIER',
    ),
    repository: repository,
  ),
);

ProviderApplication _application({
  required String id,
  required String name,
  required String category,
  ApplicationType type = ApplicationType.professional,
  bool institutionPricesPublished = false,
  String servicePrices = '',
  String roomPrices = '',
}) => ProviderApplication(
  id: id,
  type: type,
  displayName: name,
  category: category,
  registrationNumber: 'LIC-2026-001',
  contactPerson: type == ApplicationType.institution ? 'Jean Pierre' : '',
  workplace: type == ApplicationType.professional ? 'Hôpital Central' : '',
  phone: '+509 3700-0000',
  email: 'contact@ientier.ht',
  address: 'Pétion-Ville, Haïti',
  description: 'Dossier professionnel de test.',
  experience: '10 ans',
  qualifications: 'Diplôme et licence',
  services: 'Consultations',
  schedule: 'Lundi au vendredi',
  institutionPricesPublished: institutionPricesPublished,
  servicePrices: servicePrices,
  roomPrices: roomPrices,
  available: true,
  isVisible: false,
  status: ApplicationStatus.pending,
  rejectionReason: '',
  createdAt: DateTime(2026, 7, 20),
  updatedAt: DateTime(2026, 7, 22),
);

class _FakeUser implements User {
  @override
  final String uid;

  @override
  final String? email;

  @override
  final String? displayName;

  _FakeUser({
    required this.uid,
    required this.email,
    required this.displayName,
  });

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeAdminRepository implements AdminRepository {
  final List<ProviderApplication> applications;
  final List<_ReviewCall> reviews = [];

  _FakeAdminRepository(this.applications);

  @override
  Stream<bool> watchAccess(String uid) => Stream.value(true);

  @override
  Stream<List<ProviderApplication>> watchApplications() =>
      Stream.value(applications);

  @override
  Future<void> reviewApplication({
    required ProviderApplication application,
    required String adminUid,
    required ApplicationStatus status,
    String reason = '',
  }) async {
    reviews.add(
      _ReviewCall(adminUid: adminUid, status: status, reason: reason),
    );
  }
}

class _ReviewCall {
  final String adminUid;
  final ApplicationStatus status;
  final String reason;

  const _ReviewCall({
    required this.adminUid,
    required this.status,
    required this.reason,
  });
}
