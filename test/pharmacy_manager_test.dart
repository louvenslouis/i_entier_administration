import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i_entier_administration/data/pharmacy_admin_repository.dart';
import 'package:i_entier_administration/models/pharmacy_admin.dart';
import 'package:i_entier_administration/screens/pharmacy_manager_screen.dart';

class _FakeRepository implements PharmacyAdminRepository {
  PharmacyAdminStatus? reviewedStatus;
  String? reviewedPharmacyId;

  @override
  Stream<List<PharmacyAdminRecord>> watchPharmacies() =>
      Stream.value(const [_pendingPharmacy]);

  @override
  Future<void> review({
    required String pharmacyId,
    required String adminId,
    required PharmacyAdminStatus status,
    String reason = '',
  }) async {
    reviewedPharmacyId = pharmacyId;
    reviewedStatus = status;
  }
}

const _pendingPharmacy = PharmacyAdminRecord(
  id: 'pharmacy-1',
  name: 'Pharmacie Centrale',
  legalName: 'Pharmacie Centrale SA',
  licenseNumber: 'LIC-001',
  licenseExpiresOn: null,
  responsiblePharmacist: 'Marie Pierre',
  phone: '+509 0000-0000',
  email: 'pharmacie@example.com',
  address: 'Delmas',
  status: PharmacyAdminStatus.pending,
  publicEnabled: false,
  regulationNote: '',
  licenseExpired: false,
  productCount: 12,
  lowStockCount: 2,
  openOrderCount: 3,
  monthSalesTotal: 4750,
  createdAt: null,
);

void main() {
  testWidgets('active une pharmacie en attente', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1100, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _FakeRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PharmacyManagerScreen(
            adminId: 'admin-1',
            repository: repository,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Régulation des pharmacies'), findsOneWidget);
    expect(find.text('Pharmacie Centrale'), findsOneWidget);
    expect(find.text('2 alerte(s) stock'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Activer'));
    await tester.pumpAndSettle();
    expect(find.text('Activer cette pharmacie ?'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Confirmer'));
    await tester.pumpAndSettle();

    expect(repository.reviewedPharmacyId, 'pharmacy-1');
    expect(repository.reviewedStatus, PharmacyAdminStatus.active);
  });
}
