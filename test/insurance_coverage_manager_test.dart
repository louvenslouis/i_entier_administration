import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i_entier_administration/data/insurance_coverage_admin_repository.dart';
import 'package:i_entier_administration/models/insurance_coverage_admin.dart';
import 'package:i_entier_administration/screens/insurance_coverage_manager_screen.dart';
import 'package:i_entier_administration/theme/admin_theme.dart';

void main() {
  testWidgets('affiche la demande OFATMA en attente dans administration', (
    tester,
  ) async {
    final repository = _FakeInsuranceCoverageAdminRepository([
      InsuranceCoverageAdminRequest(
        id: 'coverage-1',
        patientId: 'patient-1',
        patientName: 'Marie Joseph',
        insurerCode: 'OFATMA',
        memberNumber: 'OFA-509-001',
        frontPath: 'patient-1/front.jpg',
        backPath: 'patient-1/back.jpg',
        status: 'pending',
        reviewNote: '',
        reviewedBy: null,
        reviewedAt: null,
        validFrom: null,
        validUntil: null,
        submittedAt: DateTime(2026, 8, 13),
      ),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAdminTheme(),
        home: Scaffold(
          body: InsuranceCoverageManagerScreen(repository: repository),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Couvertures OFATMA'), findsOneWidget);
    expect(find.text('1 en attente'), findsOneWidget);
    expect(find.text('Marie Joseph'), findsOneWidget);
    expect(find.text('OFATMA • OFA-509-001'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('open-coverage-coverage-1')));
    await tester.pumpAndSettle();

    expect(find.text('Dossier OFATMA — Marie Joseph'), findsOneWidget);
    expect(
      find.textContaining('validation ou le refus reste réservé'),
      findsOneWidget,
    );
  });
}

class _FakeInsuranceCoverageAdminRepository
    implements InsuranceCoverageAdminRepository {
  final List<InsuranceCoverageAdminRequest> coverages;

  const _FakeInsuranceCoverageAdminRepository(this.coverages);

  @override
  Stream<List<InsuranceCoverageAdminRequest>> watchCoverages() =>
      Stream.value(coverages);

  @override
  Future<String> createCardUrl(String storagePath) async =>
      'https://example.test/$storagePath';
}
