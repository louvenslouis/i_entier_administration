enum MobileClinicAdminStatus { pending, approved, rejected }

extension MobileClinicAdminStatusText on MobileClinicAdminStatus {
  String get storageValue => switch (this) {
    MobileClinicAdminStatus.pending => 'pending',
    MobileClinicAdminStatus.approved => 'approved',
    MobileClinicAdminStatus.rejected => 'rejected',
  };

  String get label => switch (this) {
    MobileClinicAdminStatus.pending => 'En attente',
    MobileClinicAdminStatus.approved => 'Certifiée',
    MobileClinicAdminStatus.rejected => 'Refusée',
  };

  static MobileClinicAdminStatus fromStorage(String? value) => switch (value) {
    'approved' => MobileClinicAdminStatus.approved,
    'rejected' => MobileClinicAdminStatus.rejected,
    _ => MobileClinicAdminStatus.pending,
  };
}

class MobileClinicAdminRecord {
  final String id;
  final String ownerId;
  final String ownerAccountType;
  final String creatorType;
  final String name;
  final String responsibleName;
  final String phone;
  final String email;
  final String description;
  final String baseAddress;
  final String department;
  final String commune;
  final String identityDocumentUrl;
  final String professionalLicenseUrl;
  final String operatingAuthorizationUrl;
  final List<String> partnerDocumentUrls;
  final MobileClinicAdminStatus status;
  final String rejectionReason;
  final String badge;
  final bool isPublished;
  final bool isDeployed;
  final DateTime createdAt;
  final DateTime? certifiedAt;

  const MobileClinicAdminRecord({
    required this.id,
    required this.ownerId,
    required this.ownerAccountType,
    required this.creatorType,
    required this.name,
    required this.responsibleName,
    required this.phone,
    required this.email,
    required this.description,
    required this.baseAddress,
    required this.department,
    required this.commune,
    required this.identityDocumentUrl,
    required this.professionalLicenseUrl,
    required this.operatingAuthorizationUrl,
    required this.partnerDocumentUrls,
    required this.status,
    required this.rejectionReason,
    required this.badge,
    required this.isPublished,
    required this.isDeployed,
    required this.createdAt,
    this.certifiedAt,
  });

  String get area => '$commune, $department';

  String get creatorLabel => switch (creatorType) {
    'doctor' => 'Médecin',
    'nurse' => 'Infirmier(ère)',
    'midwife' => 'Sage-femme',
    'dentist' => 'Dentiste',
    'other_certified_professional' => 'Autre professionnel certifié',
    'hospital' => 'Hôpital',
    'private_clinic' => 'Clinique privée',
    'health_center' => 'Centre de santé',
    'ngo' => 'ONG / organisation humanitaire',
    'public_health_institution' => 'Institution publique de santé',
    'company' => 'Entreprise',
    _ => creatorType,
  };

  factory MobileClinicAdminRecord.fromRow(Map<String, dynamic> row) =>
      MobileClinicAdminRecord(
        id: _text(row, 'mobile_clinic_id'),
        ownerId: _text(row, 'owner_provider_id'),
        ownerAccountType: _text(row, 'owner_account_type'),
        creatorType: _text(row, 'creator_type'),
        name: _text(row, 'name'),
        responsibleName: _text(row, 'responsible_name'),
        phone: _text(row, 'phone'),
        email: _text(row, 'email'),
        description: _text(row, 'description'),
        baseAddress: _text(row, 'base_address'),
        department: _text(row, 'department'),
        commune: _text(row, 'commune'),
        identityDocumentUrl: _text(row, 'identity_document_url'),
        professionalLicenseUrl: _text(row, 'professional_license_url'),
        operatingAuthorizationUrl: _text(row, 'operating_authorization_url'),
        partnerDocumentUrls: row['partner_document_urls'] is List
            ? List<String>.from(row['partner_document_urls'] as List)
            : const [],
        status: MobileClinicAdminStatusText.fromStorage(
          _text(row, 'verification_status'),
        ),
        rejectionReason: _text(row, 'rejection_reason'),
        badge: _text(row, 'certification_badge'),
        isPublished: row['is_published'] == true,
        isDeployed: row['is_deployed'] == true,
        createdAt: _date(row['created_at']),
        certifiedAt: _nullableDate(row['certified_at']),
      );
}

class MobileClinicAdminTour {
  final String id;
  final String clinicId;
  final String zoneName;
  final String department;
  final String commune;
  final DateTime startsAt;
  final DateTime endsAt;
  final String status;

  const MobileClinicAdminTour({
    required this.id,
    required this.clinicId,
    required this.zoneName,
    required this.department,
    required this.commune,
    required this.startsAt,
    required this.endsAt,
    required this.status,
  });

  String get area => '$commune, $department';

  factory MobileClinicAdminTour.fromRow(Map<String, dynamic> row) =>
      MobileClinicAdminTour(
        id: _text(row, 'mobile_clinic_tour_id'),
        clinicId: _text(row, 'mobile_clinic_id'),
        zoneName: _text(row, 'zone_name'),
        department: _text(row, 'department'),
        commune: _text(row, 'commune'),
        startsAt: _date(row['starts_at']),
        endsAt: _date(row['ends_at']),
        status: _text(row, 'status'),
      );
}

String _text(Map<String, dynamic> row, String key) =>
    row[key]?.toString().trim() ?? '';

DateTime _date(Object? value) =>
    _nullableDate(value) ?? DateTime.fromMillisecondsSinceEpoch(0);

DateTime? _nullableDate(Object? value) {
  if (value is DateTime) return value.toLocal();
  return DateTime.tryParse(value?.toString() ?? '')?.toLocal();
}
