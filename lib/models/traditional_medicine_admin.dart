class TraditionalAdminApplication {
  final String providerId;
  final String displayName;
  final String email;
  final String phone;
  final int experienceYears;
  final List<String> practiceDomains;
  final List<String> languages;
  final List<String> interventionZones;
  final String identityStatus;
  final String attestationStatus;
  final String validationStatus;
  final String reviewReason;
  final int trustScore;
  final DateTime createdAt;

  const TraditionalAdminApplication({
    required this.providerId,
    required this.displayName,
    required this.email,
    required this.phone,
    required this.experienceYears,
    required this.practiceDomains,
    required this.languages,
    required this.interventionZones,
    required this.identityStatus,
    required this.attestationStatus,
    required this.validationStatus,
    required this.reviewReason,
    required this.trustScore,
    required this.createdAt,
  });

  factory TraditionalAdminApplication.fromRows(
    Map<String, dynamic> traditional,
    Map<String, dynamic> provider,
  ) {
    List<String> list(String key) => (traditional[key] as List? ?? const [])
        .map((value) => value.toString())
        .toList(growable: false);
    return TraditionalAdminApplication(
      providerId: traditional['provider_id']?.toString() ?? '',
      displayName: provider['display_name']?.toString() ?? '',
      email: provider['email']?.toString() ?? '',
      phone: provider['phone']?.toString() ?? '',
      experienceYears: (traditional['experience_years'] as num?)?.toInt() ?? 0,
      practiceDomains: list('practice_domains'),
      languages: list('languages'),
      interventionZones: list('intervention_zones'),
      identityStatus: traditional['identity_status']?.toString() ?? 'pending',
      attestationStatus:
          traditional['attestation_status']?.toString() ?? 'pending',
      validationStatus:
          traditional['validation_status']?.toString() ?? 'pending',
      reviewReason: traditional['review_reason']?.toString() ?? '',
      trustScore: (traditional['trust_score'] as num?)?.toInt() ?? 0,
      createdAt:
          DateTime.tryParse(
            traditional['created_at']?.toString() ?? '',
          )?.toLocal() ??
          DateTime.now(),
    );
  }
}

class TraditionalAdminDocument {
  final String id;
  final String providerId;
  final String type;
  final String fileName;
  final String storagePath;
  final String reviewStatus;
  final String reviewNote;

  const TraditionalAdminDocument({
    required this.id,
    required this.providerId,
    required this.type,
    required this.fileName,
    required this.storagePath,
    required this.reviewStatus,
    required this.reviewNote,
  });

  factory TraditionalAdminDocument.fromRow(Map<String, dynamic> row) =>
      TraditionalAdminDocument(
        id: row['document_id']?.toString() ?? '',
        providerId: row['provider_id']?.toString() ?? '',
        type: row['document_type']?.toString() ?? 'other',
        fileName: row['original_file_name']?.toString() ?? '',
        storagePath: row['storage_path']?.toString() ?? '',
        reviewStatus: row['review_status']?.toString() ?? 'pending',
        reviewNote: row['review_note']?.toString() ?? '',
      );
}

class TraditionalSafetyReport {
  final String id;
  final String reporterId;
  final String practitionerId;
  final String practitionerName;
  final String category;
  final String details;
  final String credibilityStatus;
  final String resolutionStatus;
  final DateTime createdAt;

  const TraditionalSafetyReport({
    required this.id,
    required this.reporterId,
    required this.practitionerId,
    required this.practitionerName,
    required this.category,
    required this.details,
    required this.credibilityStatus,
    required this.resolutionStatus,
    required this.createdAt,
  });

  factory TraditionalSafetyReport.fromRows(
    Map<String, dynamic> report,
    String practitionerName,
  ) => TraditionalSafetyReport(
    id: report['report_id']?.toString() ?? '',
    reporterId: report['reporter_id']?.toString() ?? '',
    practitionerId: report['practitioner_id']?.toString() ?? '',
    practitionerName: practitionerName,
    category: report['category']?.toString() ?? '',
    details: report['details']?.toString() ?? '',
    credibilityStatus:
        report['credibility_status']?.toString() ?? 'pending_review',
    resolutionStatus: report['resolution_status']?.toString() ?? 'open',
    createdAt:
        DateTime.tryParse(report['created_at']?.toString() ?? '')?.toLocal() ??
        DateTime.now(),
  );
}
