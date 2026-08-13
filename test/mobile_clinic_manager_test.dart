import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i_entier_administration/data/mobile_clinic_admin_repository.dart';
import 'package:i_entier_administration/models/mobile_clinic_admin.dart';
import 'package:i_entier_administration/screens/mobile_clinic_manager_screen.dart';
import 'package:i_entier_administration/theme/admin_theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  testWidgets('affiche les cliniques certifiées et les zones couvertes', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1300, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _FakeMobileClinicAdminRepository(
      clinics: [_pendingClinic, _certifiedClinic],
      tours: [_tour],
    );

    await tester.pumpWidget(_manager(repository));
    await tester.pumpAndSettle();

    expect(find.text('Réseau Clinique Mobile'), findsOneWidget);
    expect(find.text('Cliniques certifiées'), findsOneWidget);
    expect(find.text('Demandes à vérifier'), findsOneWidget);
    expect(find.text('Déployées maintenant'), findsOneWidget);
    expect(find.text('Zones couvertes'), findsWidgets);
    expect(find.textContaining('Jacmel, Sud-Est'), findsWidgets);
    expect(find.text('Clinique Mobile Espoir'), findsOneWidget);
  });

  testWidgets('certifie une clinique et demande le badge automatique', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1300, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _FakeMobileClinicAdminRepository(
      clinics: [_pendingClinic],
      tours: const [],
    );
    await tester.pumpWidget(_manager(repository));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Certifier').first);
    await tester.pumpAndSettle();
    expect(find.text('Certifier cette clinique mobile ?'), findsOneWidget);
    expect(
      find.textContaining('Clinique Mobile Certifiée I-Entier'),
      findsOneWidget,
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Certifier').last);
    await tester.pumpAndSettle();

    expect(repository.reviews, hasLength(1));
    expect(repository.reviews.single.$1, 'clinic-pending');
    expect(repository.reviews.single.$2, MobileClinicAdminStatus.approved);
  });
}

Widget _manager(MobileClinicAdminRepository repository) => MaterialApp(
  theme: buildAdminTheme(),
  home: Scaffold(
    body: MobileClinicManagerScreen(
      user: User(
        id: 'admin-1',
        appMetadata: const {},
        userMetadata: const {'full_name': 'Admin i-ENTIER'},
        aud: 'authenticated',
        email: 'admin@ientier.ht',
        createdAt: DateTime(2026, 8, 3).toIso8601String(),
      ),
      repository: repository,
    ),
  ),
);

final _pendingClinic = MobileClinicAdminRecord.fromRow({
  'mobile_clinic_id': 'clinic-pending',
  'owner_provider_id': 'provider-1',
  'owner_account_type': 'professional',
  'creator_type': 'doctor',
  'name': 'Clinique Mobile Espoir',
  'responsible_name': 'Dr Marie Jean',
  'phone': '+509 3700 0000',
  'email': 'marie@ientier.ht',
  'description': 'Soins de proximité',
  'base_address': 'Jacmel',
  'department': 'Sud-Est',
  'commune': 'Jacmel',
  'identity_document_url': 'https://docs.test/identity.pdf',
  'professional_license_url': 'https://docs.test/license.pdf',
  'operating_authorization_url': 'https://docs.test/auth.pdf',
  'verification_status': 'pending',
  'created_at': '2026-08-03T12:00:00Z',
});

final _certifiedClinic = MobileClinicAdminRecord.fromRow({
  'mobile_clinic_id': 'clinic-certified',
  'owner_provider_id': 'provider-2',
  'owner_account_type': 'institution',
  'creator_type': 'ngo',
  'name': 'Unité Mobile Solidarité',
  'responsible_name': 'ONG Santé Pour Tous',
  'department': 'Ouest',
  'commune': 'Léogâne',
  'identity_document_url': 'https://docs.test/identity.pdf',
  'operating_authorization_url': 'https://docs.test/auth.pdf',
  'verification_status': 'approved',
  'certification_badge': 'Clinique Mobile Certifiée I-Entier',
  'certified_at': '2026-08-03T14:00:00Z',
  'is_published': true,
  'is_deployed': true,
  'created_at': '2026-08-02T12:00:00Z',
});

final _tour = MobileClinicAdminTour.fromRow({
  'mobile_clinic_tour_id': 'tour-1',
  'mobile_clinic_id': 'clinic-certified',
  'zone_name': 'Jacmel Centre',
  'department': 'Sud-Est',
  'commune': 'Jacmel',
  'starts_at': '2026-08-05T12:00:00Z',
  'ends_at': '2026-08-07T20:00:00Z',
  'status': 'planned',
});

class _FakeMobileClinicAdminRepository implements MobileClinicAdminRepository {
  final List<MobileClinicAdminRecord> clinics;
  final List<MobileClinicAdminTour> tours;
  final List<(String, MobileClinicAdminStatus, String)> reviews = [];

  _FakeMobileClinicAdminRepository({
    required this.clinics,
    required this.tours,
  });

  @override
  Stream<List<MobileClinicAdminRecord>> watchClinics() => Stream.value(clinics);

  @override
  Stream<List<MobileClinicAdminTour>> watchTours() => Stream.value(tours);

  @override
  Future<void> review({
    required String clinicId,
    required String adminId,
    required MobileClinicAdminStatus status,
    String reason = '',
  }) async {
    reviews.add((clinicId, status, reason));
  }
}
