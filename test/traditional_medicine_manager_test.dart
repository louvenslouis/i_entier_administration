import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i_entier_administration/data/traditional_medicine_admin_repository.dart';
import 'package:i_entier_administration/models/traditional_medicine_admin.dart';
import 'package:i_entier_administration/screens/traditional_medicine_manager_screen.dart';
import 'package:i_entier_administration/theme/admin_theme.dart';

class _FakeRepository implements TraditionalMedicineAdminRepository {
  String? reviewedProvider;
  bool? applicationApproved;
  String? reviewedReport;
  bool? reportCredible;

  @override
  Stream<List<TraditionalAdminApplication>> watchApplications() =>
      Stream.value([
        TraditionalAdminApplication(
          providerId: 'traditional-1',
          displayName: 'Man Rose Pierre',
          email: 'rose@example.ht',
          phone: '+509 2222-0000',
          experienceYears: 18,
          practiceDomains: const ['Prévention', 'Bien-être'],
          languages: const ['Créole haïtien'],
          interventionZones: const ['Delmas'],
          identityStatus: 'pending',
          attestationStatus: 'pending',
          validationStatus: 'pending',
          reviewReason: '',
          trustScore: 20,
          createdAt: DateTime(2026, 8, 7),
        ),
      ]);

  @override
  Stream<List<TraditionalAdminDocument>> watchDocuments(String providerId) =>
      Stream.value(const [
        TraditionalAdminDocument(
          id: 'identity-1',
          providerId: 'traditional-1',
          type: 'identity',
          fileName: 'identite.jpg',
          storagePath: 'traditional-1/identite.jpg',
          reviewStatus: 'verified',
          reviewNote: '',
        ),
        TraditionalAdminDocument(
          id: 'attestation-1',
          providerId: 'traditional-1',
          type: 'attestation',
          fileName: 'attestation.jpg',
          storagePath: 'traditional-1/attestation.jpg',
          reviewStatus: 'verified',
          reviewNote: '',
        ),
      ]);

  @override
  Stream<List<TraditionalSafetyReport>> watchReports() => Stream.value([
    TraditionalSafetyReport(
      id: 'report-1',
      reporterId: 'patient-1',
      practitionerId: 'traditional-1',
      practitionerName: 'Man Rose Pierre',
      category: 'dangerous_advice',
      details: 'Le conseil transmis présentait un risque sérieux.',
      credibilityStatus: 'pending_review',
      resolutionStatus: 'open',
      createdAt: DateTime(2026, 8, 7),
    ),
  ]);

  @override
  Future<String> createDocumentReviewUrl(String storagePath) async =>
      'https://example.com/document';

  @override
  Future<void> reviewDocument({
    required String documentId,
    required String adminId,
    required bool verified,
    String note = '',
  }) async {}

  @override
  Future<void> reviewApplication({
    required String providerId,
    required String adminId,
    required bool approved,
    String reason = '',
  }) async {
    reviewedProvider = providerId;
    applicationApproved = approved;
  }

  @override
  Future<void> reviewReport({
    required String reportId,
    required String adminId,
    required bool credible,
    required String note,
  }) async {
    reviewedReport = reportId;
    reportCredible = credible;
  }
}

void main() {
  testWidgets('approuve un dossier après examen des justificatifs', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1100, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _FakeRepository();

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAdminTheme(),
        home: Scaffold(
          body: TraditionalMedicineManagerScreen(
            adminId: 'admin-1',
            repository: repository,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Man Rose Pierre'), findsOneWidget);
    await tester.tap(
      find.byKey(const Key('traditional-admin-open-traditional-1')),
    );
    await tester.pumpAndSettle();
    expect(find.text('identite.jpg'), findsOneWidget);
    expect(find.text('attestation.jpg'), findsOneWidget);
    await tester.tap(find.byKey(const Key('traditional-admin-approve')));
    await tester.pumpAndSettle();

    expect(repository.reviewedProvider, 'traditional-1');
    expect(repository.applicationApproved, isTrue);
  });

  testWidgets('un signalement crédible déclenche la suspension préventive', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1100, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _FakeRepository();

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAdminTheme(),
        home: Scaffold(
          body: TraditionalMedicineManagerScreen(
            adminId: 'admin-1',
            repository: repository,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Signalements'));
    await tester.pumpAndSettle();
    expect(find.text('dangerous_advice'), findsOneWidget);
    await tester.tap(find.byKey(const Key('credible-report-report-1')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('traditional-admin-note')),
      'Éléments concordants, enquête de sécurité ouverte.',
    );
    await tester.tap(find.byKey(const Key('traditional-admin-confirm-note')));
    await tester.pumpAndSettle();

    expect(repository.reviewedReport, 'report-1');
    expect(repository.reportCredible, isTrue);
  });
}
