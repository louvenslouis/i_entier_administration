import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i_entier_administration/data/health_credit_admin_repository.dart';
import 'package:i_entier_administration/models/health_credit_admin_models.dart';
import 'package:i_entier_administration/screens/health_credit_manager_screen.dart';
import 'package:i_entier_administration/theme/admin_theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  testWidgets('affiche les sept indicateurs Crédit Santé', (tester) async {
    await _desktop(tester);
    final repository = _FakeHealthCreditAdminRepository(_dashboard);

    await tester.pumpWidget(_manager(repository));
    await tester.pumpAndSettle();

    expect(find.text('Demandes de crédit'), findsOneWidget);
    expect(find.text('Crédits actifs'), findsOneWidget);
    expect(find.text('Taux de remboursement'), findsOneWidget);
    expect(find.text('Score moyen'), findsOneWidget);
    expect(find.text('Patients vulnérables'), findsOneWidget);
    expect(find.text('Dossiers solidaires financés'), findsOneWidget);
    expect(find.text('Alertes de retard'), findsOneWidget);
    expect(find.text('40.0 %'), findsOneWidget);
    expect(find.text('88.0'), findsOneWidget);
  });

  testWidgets('valide une référence puis transmet une approbation', (
    tester,
  ) async {
    await _desktop(tester);
    final repository = _FakeHealthCreditAdminRepository(_dashboard);

    await tester.pumpWidget(_manager(repository));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Demandes'));
    await tester.pumpAndSettle();

    expect(find.text('Marie Jean'), findsOneWidget);
    expect(find.text('Référence Communautaire'), findsOneWidget);
    await tester.tap(find.byTooltip('Valider'));
    await tester.pumpAndSettle();
    expect(repository.referenceReviews, [('reference-1', true)]);

    await tester.tap(find.widgetWithText(FilledButton, 'Approuver'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Approuver').last);
    await tester.pumpAndSettle();
    expect(repository.applicationReviews, [('application-1', true)]);
  });

  testWidgets('suspend temporairement un défaut sans justification', (
    tester,
  ) async {
    await _desktop(tester);
    final repository = _FakeHealthCreditAdminRepository(_dashboard);

    await tester.pumpWidget(_manager(repository));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Qualifier le défaut'));
    await tester.pumpAndSettle();

    expect(find.text('Qualifier le défaut de paiement'), findsOneWidget);
    expect(find.textContaining('180 jours'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Suspendre'));
    await tester.pumpAndSettle();

    expect(repository.defaults, [('credit-1', false)]);
  });
}

Future<void> _desktop(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(1280, 1200));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

Widget _manager(_FakeHealthCreditAdminRepository repository) => MaterialApp(
  theme: buildAdminTheme(),
  home: Scaffold(
    body: HealthCreditManagerScreen(
      user: User(
        id: 'admin-1',
        appMetadata: const {},
        userMetadata: const {'full_name': 'Admin Crédit'},
        aud: 'authenticated',
        email: 'admin@ientier.ht',
        createdAt: DateTime(2026, 8, 3).toIso8601String(),
      ),
      repository: repository,
    ),
  ),
);

final _dashboard = HealthCreditAdminDashboardData(
  applications: [
    AdminHealthCreditApplication(
      id: 'application-1',
      patientId: 'patient-1',
      patientName: 'Marie Jean',
      requestedAmount: 100000,
      medicalReason: 'Intervention chirurgicale prescrite et urgente.',
      income: 50000,
      expenses: 25000,
      disposable: 25000,
      employer: 'Clinique Espoir',
      installments: 5,
      estimatedInstallment: 20000,
      preliminaryScore: 85,
      validatedReferences: 3,
      status: 'under_review',
      decisionReason: '',
      createdAt: DateTime(2026, 8, 3),
      references: const [
        AdminHealthCreditReference(
          id: 'reference-1',
          name: 'Référence Communautaire',
          phone: '+509 3700 0000',
          relationship: 'Pasteur',
          type: 'community',
          status: 'pending',
          note: '',
        ),
      ],
    ),
  ],
  credits: const [
    AdminHealthCredit(
      id: 'credit-1',
      patientId: 'patient-1',
      principal: 100000,
      balance: 60000,
      score: 88,
      status: 'active',
    ),
  ],
  installments: [
    AdminHealthInstallment(
      id: 'installment-1',
      creditId: 'credit-1',
      dueDate: DateTime(2026, 7, 3),
      due: 20000,
      paid: 0,
      status: 'late',
    ),
  ],
  payments: const [],
  assessments: [
    AdminSocialAssessment(
      id: 'assessment-1',
      patientId: 'patient-1',
      score: 75,
      level: 'critical',
      vulnerable: true,
      assessedAt: DateTime(2026, 8, 3),
    ),
  ],
  solidarityRequests: const [],
  partnerCenters: const [],
);

class _FakeHealthCreditAdminRepository implements HealthCreditAdminRepository {
  final HealthCreditAdminDashboardData data;
  final List<(String, bool)> referenceReviews = [];
  final List<(String, bool)> applicationReviews = [];
  final List<(String, bool)> defaults = [];

  _FakeHealthCreditAdminRepository(this.data);

  @override
  Stream<HealthCreditAdminDashboardData> watchDashboard() => Stream.value(data);

  @override
  Future<void> refreshOverdues(String adminId) async {}

  @override
  Future<void> validateReference({
    required String referenceId,
    required String adminId,
    required bool valid,
    String note = '',
  }) async => referenceReviews.add((referenceId, valid));

  @override
  Future<void> reviewApplication({
    required String applicationId,
    required String adminId,
    required bool approve,
    String reason = '',
  }) async => applicationReviews.add((applicationId, approve));

  @override
  Future<void> reviewPayment({
    required String paymentId,
    required String adminId,
    required bool confirm,
    String reason = '',
  }) async {}

  @override
  Future<void> flagDefault({
    required String creditId,
    required String adminId,
    required bool hasJustification,
    String justification = '',
  }) async => defaults.add((creditId, hasJustification));

  @override
  Future<void> manageSolidarity({
    required String requestId,
    required String adminId,
    required String status,
    required double approvedAmount,
    required double fundedAmount,
    String? centerId,
    required String socialWorker,
    required String medicalCoordinator,
    required String followUpNote,
  }) async {}

  @override
  Future<String> createDocumentUrl(String storagePath) async => '';
}
