import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i_entier_administration/data/crowdfunding_admin_repository.dart';
import 'package:i_entier_administration/models/crowdfunding_campaign.dart';
import 'package:i_entier_administration/screens/crowdfunding_manager_screen.dart';
import 'package:i_entier_administration/theme/admin_theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  final campaign = AdminCrowdfundingCampaign(
    id: 'campaign-1',
    creatorId: 'patient-1',
    beneficiaryName: 'Nadia Pierre',
    relationshipToPatient: 'Sœur',
    title: 'Aidez Nadia à financer son opération',
    story:
        'Nadia doit subir une intervention chirurgicale indispensable. '
        'La famille sollicite un soutien pour les frais hospitaliers.',
    category: 'surgery',
    medicalFacility: 'Hôpital Saint-Louis',
    location: 'Port-au-Prince',
    contactPhone: '+509 3700 0000',
    targetAmount: 250000,
    raisedAmount: 0,
    contributorCount: 0,
    currency: 'HTG',
    deadline: DateTime(2026, 9, 1),
    status: 'pending',
    verificationStatus: CrowdfundingReviewStatus.pending,
    rejectionReason: '',
    consentToPublish: true,
    featured: false,
    createdAt: DateTime(2026, 7, 29),
  );

  final contribution = AdminCrowdfundingContribution(
    id: 'contribution-1',
    campaignId: 'campaign-1',
    contributorId: 'supporter-1',
    amount: 5000,
    currency: 'HTG',
    paymentMethod: 'moncash',
    paymentStatus: 'pending_payment',
    publicName: 'Jean Test',
    anonymous: false,
    supporterMessage: 'Bon courage',
    processorReference: '',
    createdAt: DateTime(2026, 7, 29),
  );

  testWidgets('approuve et publie une campagne vérifiée', (tester) async {
    final repository = _FakeCrowdfundingAdminRepository(campaigns: [campaign]);
    await _setDesktopSize(tester);

    await tester.pumpWidget(_manager(repository));
    await tester.pumpAndSettle();

    expect(
      find.text('Contrôle des campagnes et des paiements'),
      findsOneWidget,
    );
    expect(
      find.image(const AssetImage('assets/services/crowdfunding_3d.png')),
      findsOneWidget,
    );
    expect(find.text(campaign.title), findsOneWidget);
    expect(find.text('1 dossier'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Approuver'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-campaign-approval')));
    await tester.pumpAndSettle();

    expect(repository.reviews, hasLength(1));
    expect(repository.reviews.single.status, CrowdfundingReviewStatus.approved);
    expect(repository.reviews.single.adminUid, 'admin-1');
  });

  testWidgets('exige un motif pour refuser une campagne', (tester) async {
    final repository = _FakeCrowdfundingAdminRepository(campaigns: [campaign]);
    await _setDesktopSize(tester);

    await tester.pumpWidget(_manager(repository));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, 'Refuser'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-campaign-rejection')));
    await tester.pump();

    expect(find.text('Un motif est requis.'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('campaign-rejection-reason')),
      'Le justificatif médical est incomplet.',
    );
    await tester.tap(find.byKey(const Key('confirm-campaign-rejection')));
    await tester.pumpAndSettle();

    expect(repository.reviews, hasLength(1));
    expect(repository.reviews.single.status, CrowdfundingReviewStatus.rejected);
    expect(
      repository.reviews.single.reason,
      'Le justificatif médical est incomplet.',
    );
  });

  testWidgets('confirme un paiement uniquement avec sa référence', (
    tester,
  ) async {
    final repository = _FakeCrowdfundingAdminRepository(
      campaigns: [campaign],
      contributions: [contribution],
    );
    await _setDesktopSize(tester);

    await tester.pumpWidget(_manager(repository));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Paiements à confirmer'));
    await tester.pumpAndSettle();

    expect(find.text('5 000 HTG'), findsOneWidget);
    await tester.tap(
      find.byKey(const Key('confirm-contribution-contribution-1')),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('payment-processor-reference')),
      'MC-2026-001928',
    );
    await tester.tap(find.byKey(const Key('confirm-payment-reference')));
    await tester.pumpAndSettle();

    expect(repository.confirmations, hasLength(1));
    expect(repository.confirmations.single.reference, 'MC-2026-001928');
    expect(repository.confirmations.single.adminUid, 'admin-1');
  });
}

Future<void> _setDesktopSize(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(1200, 1000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

Widget _manager(_FakeCrowdfundingAdminRepository repository) => MaterialApp(
  theme: buildAdminTheme(),
  home: Scaffold(
    body: CrowdfundingManagerScreen(
      user: User(
        id: 'admin-1',
        appMetadata: const {},
        userMetadata: const {'full_name': 'Admin Test'},
        aud: 'authenticated',
        email: 'admin@ientier.ht',
        createdAt: DateTime(2026, 7, 20).toIso8601String(),
      ),
      repository: repository,
    ),
  ),
);

class _FakeCrowdfundingAdminRepository implements CrowdfundingAdminRepository {
  final List<AdminCrowdfundingCampaign> campaigns;
  final List<AdminCrowdfundingContribution> contributions;
  final List<_ReviewCall> reviews = [];
  final List<_ConfirmationCall> confirmations = [];

  _FakeCrowdfundingAdminRepository({
    this.campaigns = const [],
    this.contributions = const [],
  });

  @override
  Stream<List<AdminCrowdfundingCampaign>> watchCampaigns() =>
      Stream.value(campaigns);

  @override
  Stream<List<AdminCrowdfundingContribution>> watchPendingContributions() =>
      Stream.value(contributions);

  @override
  Future<void> reviewCampaign({
    required AdminCrowdfundingCampaign campaign,
    required String adminUid,
    required CrowdfundingReviewStatus status,
    String reason = '',
  }) async {
    reviews.add(
      _ReviewCall(adminUid: adminUid, status: status, reason: reason),
    );
  }

  @override
  Future<void> confirmContribution({
    required AdminCrowdfundingContribution contribution,
    required String adminUid,
    required String processorReference,
  }) async {
    confirmations.add(
      _ConfirmationCall(adminUid: adminUid, reference: processorReference),
    );
  }
}

class _ReviewCall {
  final String adminUid;
  final CrowdfundingReviewStatus status;
  final String reason;

  const _ReviewCall({
    required this.adminUid,
    required this.status,
    required this.reason,
  });
}

class _ConfirmationCall {
  final String adminUid;
  final String reference;

  const _ConfirmationCall({required this.adminUid, required this.reference});
}
