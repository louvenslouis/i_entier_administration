enum CrowdfundingReviewStatus { pending, approved, rejected }

extension CrowdfundingReviewStatusDetails on CrowdfundingReviewStatus {
  String get storageValue => switch (this) {
    CrowdfundingReviewStatus.pending => 'pending',
    CrowdfundingReviewStatus.approved => 'approved',
    CrowdfundingReviewStatus.rejected => 'rejected',
  };

  String get label => switch (this) {
    CrowdfundingReviewStatus.pending => 'En attente',
    CrowdfundingReviewStatus.approved => 'Approuvée',
    CrowdfundingReviewStatus.rejected => 'Refusée',
  };

  static CrowdfundingReviewStatus fromStorage(Object? value) =>
      switch (value?.toString()) {
        'approved' => CrowdfundingReviewStatus.approved,
        'rejected' => CrowdfundingReviewStatus.rejected,
        _ => CrowdfundingReviewStatus.pending,
      };
}

class AdminCrowdfundingCampaign {
  final String id;
  final String creatorId;
  final String beneficiaryName;
  final String relationshipToPatient;
  final String title;
  final String story;
  final String category;
  final String medicalFacility;
  final String location;
  final String contactPhone;
  final double targetAmount;
  final double raisedAmount;
  final int contributorCount;
  final String currency;
  final DateTime deadline;
  final String status;
  final CrowdfundingReviewStatus verificationStatus;
  final String rejectionReason;
  final bool consentToPublish;
  final bool featured;
  final DateTime? createdAt;
  final DateTime? reviewedAt;

  const AdminCrowdfundingCampaign({
    required this.id,
    required this.creatorId,
    required this.beneficiaryName,
    required this.relationshipToPatient,
    required this.title,
    required this.story,
    required this.category,
    required this.medicalFacility,
    required this.location,
    required this.contactPhone,
    required this.targetAmount,
    required this.raisedAmount,
    required this.contributorCount,
    required this.currency,
    required this.deadline,
    required this.status,
    required this.verificationStatus,
    required this.rejectionReason,
    required this.consentToPublish,
    required this.featured,
    this.createdAt,
    this.reviewedAt,
  });

  factory AdminCrowdfundingCampaign.fromRow(Map<String, dynamic> row) {
    String text(String key) => row[key]?.toString().trim() ?? '';
    double number(String key) => row[key] is num
        ? (row[key] as num).toDouble()
        : double.tryParse(text(key)) ?? 0;
    DateTime? date(String key) {
      final value = text(key);
      return value.isEmpty ? null : DateTime.tryParse(value)?.toLocal();
    }

    return AdminCrowdfundingCampaign(
      id: text('campaign_id'),
      creatorId: text('creator_id'),
      beneficiaryName: text('beneficiary_name'),
      relationshipToPatient: text('relationship_to_patient'),
      title: text('title'),
      story: text('story'),
      category: text('category'),
      medicalFacility: text('medical_facility'),
      location: text('location'),
      contactPhone: text('contact_phone'),
      targetAmount: number('target_amount'),
      raisedAmount: number('raised_amount'),
      contributorCount: row['contributor_count'] is num
          ? (row['contributor_count'] as num).toInt()
          : int.tryParse(text('contributor_count')) ?? 0,
      currency: text('currency').isEmpty ? 'HTG' : text('currency'),
      deadline: date('deadline') ?? DateTime.now(),
      status: text('status'),
      verificationStatus: CrowdfundingReviewStatusDetails.fromStorage(
        row['verification_status'],
      ),
      rejectionReason: text('rejection_reason'),
      consentToPublish: row['consent_to_publish'] == true,
      featured: row['featured'] == true,
      createdAt: date('created_at'),
      reviewedAt: date('reviewed_at'),
    );
  }
}

class AdminCrowdfundingContribution {
  final String id;
  final String campaignId;
  final String contributorId;
  final double amount;
  final String currency;
  final String paymentMethod;
  final String paymentStatus;
  final String publicName;
  final bool anonymous;
  final String supporterMessage;
  final String processorReference;
  final DateTime? createdAt;

  const AdminCrowdfundingContribution({
    required this.id,
    required this.campaignId,
    required this.contributorId,
    required this.amount,
    required this.currency,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.publicName,
    required this.anonymous,
    required this.supporterMessage,
    required this.processorReference,
    this.createdAt,
  });

  factory AdminCrowdfundingContribution.fromRow(Map<String, dynamic> row) {
    String text(String key) => row[key]?.toString().trim() ?? '';
    return AdminCrowdfundingContribution(
      id: text('contribution_id'),
      campaignId: text('campaign_id'),
      contributorId: text('contributor_id'),
      amount: row['amount'] is num
          ? (row['amount'] as num).toDouble()
          : double.tryParse(text('amount')) ?? 0,
      currency: text('currency'),
      paymentMethod: text('payment_method'),
      paymentStatus: text('payment_status'),
      publicName: text('public_name'),
      anonymous: row['anonymous'] == true,
      supporterMessage: text('supporter_message'),
      processorReference: text('processor_reference'),
      createdAt: DateTime.tryParse(text('created_at'))?.toLocal(),
    );
  }
}
