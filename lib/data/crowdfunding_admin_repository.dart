import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/crowdfunding_campaign.dart';

abstract class CrowdfundingAdminRepository {
  Stream<List<AdminCrowdfundingCampaign>> watchCampaigns();

  Stream<List<AdminCrowdfundingContribution>> watchPendingContributions();

  Future<void> reviewCampaign({
    required AdminCrowdfundingCampaign campaign,
    required String adminUid,
    required CrowdfundingReviewStatus status,
    String reason = '',
  });

  Future<void> confirmContribution({
    required AdminCrowdfundingContribution contribution,
    required String adminUid,
    required String processorReference,
  });
}

class SupabaseCrowdfundingAdminRepository
    implements CrowdfundingAdminRepository {
  final SupabaseClient client;

  SupabaseCrowdfundingAdminRepository({SupabaseClient? client})
    : client = client ?? Supabase.instance.client;

  @override
  Stream<List<AdminCrowdfundingCampaign>> watchCampaigns() => client
      .schema('ientier')
      .from('crowdfunding_campaigns')
      .stream(primaryKey: ['campaign_id'])
      .order('created_at', ascending: false)
      .limit(500)
      .asyncMap((rows) async {
        final privateRows = List<Map<String, dynamic>>.from(
          await client
              .schema('ientier')
              .from('crowdfunding_campaign_contacts')
              .select('campaign_id,creator_id,contact_phone'),
        );
        final privateByCampaign = {
          for (final row in privateRows)
            row['campaign_id']?.toString() ?? '': row,
        };
        return rows
            .map((row) {
              final privateData =
                  privateByCampaign[row['campaign_id']?.toString()] ??
                  const <String, dynamic>{};
              return AdminCrowdfundingCampaign.fromRow({
                ...row,
                'creator_id': privateData['creator_id'],
                'contact_phone': privateData['contact_phone'],
              });
            })
            .toList(growable: false);
      });

  @override
  Stream<List<AdminCrowdfundingContribution>> watchPendingContributions() =>
      client
          .schema('ientier')
          .from('crowdfunding_contributions')
          .stream(primaryKey: ['contribution_id'])
          .eq('payment_status', 'pending_payment')
          .order('created_at', ascending: false)
          .limit(500)
          .map(
            (rows) => rows
                .map(AdminCrowdfundingContribution.fromRow)
                .toList(growable: false),
          );

  @override
  Future<void> reviewCampaign({
    required AdminCrowdfundingCampaign campaign,
    required String adminUid,
    required CrowdfundingReviewStatus status,
    String reason = '',
  }) async {
    if (status == CrowdfundingReviewStatus.pending) {
      throw ArgumentError('Une décision finale est requise.');
    }
    final normalizedReason = status == CrowdfundingReviewStatus.rejected
        ? reason.trim()
        : '';
    if (status == CrowdfundingReviewStatus.rejected &&
        normalizedReason.isEmpty) {
      throw ArgumentError('Un motif de refus est requis.');
    }
    await client
        .schema('ientier')
        .rpc(
          'review_crowdfunding_campaign',
          params: {
            'p_campaign_id': campaign.id,
            'p_admin_id': adminUid,
            'p_new_status': status.storageValue,
            'p_reason': normalizedReason,
          },
        );
  }

  @override
  Future<void> confirmContribution({
    required AdminCrowdfundingContribution contribution,
    required String adminUid,
    required String processorReference,
  }) async {
    final normalizedReference = processorReference.trim();
    if (normalizedReference.length < 4) {
      throw ArgumentError('Une référence de paiement valide est requise.');
    }
    await client
        .schema('ientier')
        .rpc(
          'confirm_crowdfunding_contribution',
          params: {
            'p_contribution_id': contribution.id,
            'p_admin_id': adminUid,
            'p_processor_reference': normalizedReference,
          },
        );
  }
}
