enum RescueReviewStatus { pending, verified, suspended }

extension RescueReviewStatusDetails on RescueReviewStatus {
  String get storageValue => switch (this) {
    RescueReviewStatus.pending => 'pending',
    RescueReviewStatus.verified => 'verified',
    RescueReviewStatus.suspended => 'suspended',
  };

  String get label => switch (this) {
    RescueReviewStatus.pending => 'En attente',
    RescueReviewStatus.verified => 'Vérifié',
    RescueReviewStatus.suspended => 'Suspendu',
  };

  static RescueReviewStatus fromStorage(String value) => switch (value) {
    'verified' => RescueReviewStatus.verified,
    'suspended' => RescueReviewStatus.suspended,
    _ => RescueReviewStatus.pending,
  };
}

class AdminRescueVolunteer {
  final String id;
  final String userId;
  final String fullName;
  final String phone;
  final String profession;
  final String specialty;
  final String organization;
  final List<String> skills;
  final RescueReviewStatus verificationStatus;
  final String availability;
  final int interventionRadiusKm;
  final bool locationConsent;
  final double? latitude;
  final double? longitude;
  final String reviewNotes;
  final DateTime createdAt;

  const AdminRescueVolunteer({
    required this.id,
    required this.userId,
    required this.fullName,
    required this.phone,
    required this.profession,
    required this.specialty,
    required this.organization,
    required this.skills,
    required this.verificationStatus,
    required this.availability,
    required this.interventionRadiusKm,
    required this.locationConsent,
    required this.latitude,
    required this.longitude,
    required this.reviewNotes,
    required this.createdAt,
  });

  factory AdminRescueVolunteer.fromRow(Map<String, dynamic> row) =>
      AdminRescueVolunteer(
        id: row['volunteer_id'].toString(),
        userId: row['user_id']?.toString() ?? '',
        fullName: row['full_name']?.toString() ?? '',
        phone: row['phone']?.toString() ?? '',
        profession: row['profession']?.toString() ?? 'other',
        specialty: row['specialty']?.toString() ?? '',
        organization: row['organization']?.toString() ?? '',
        skills: List<String>.from(row['skills'] as List? ?? const []),
        verificationStatus: RescueReviewStatusDetails.fromStorage(
          row['verification_status']?.toString() ?? '',
        ),
        availability: row['availability']?.toString() ?? 'offline',
        interventionRadiusKm:
            (row['intervention_radius_km'] as num?)?.toInt() ?? 25,
        locationConsent: row['location_consent'] == true,
        latitude: (row['latitude'] as num?)?.toDouble(),
        longitude: (row['longitude'] as num?)?.toDouble(),
        reviewNotes: row['review_notes']?.toString() ?? '',
        createdAt:
            DateTime.tryParse(row['created_at']?.toString() ?? '') ??
            DateTime.now(),
      );

  String get professionLabel => switch (profession) {
    'general_practitioner' => 'Médecin généraliste',
    'specialist_doctor' => 'Médecin spécialiste',
    'nurse' => 'Infirmière',
    'midwife' => 'Sage-femme',
    'paramedic' => 'Ambulancier',
    'first_responder' => 'Secouriste',
    'pharmacist' => 'Pharmacien',
    'psychologist' => 'Psychologue',
    'health_student' => 'Étudiant en santé',
    _ => 'Autre professionnel volontaire',
  };

  String get availabilityLabel => switch (availability) {
    'available' => 'Disponible',
    'busy' => 'Occupé',
    _ => 'Hors ligne',
  };
}

class AdminRescueEvent {
  final String id;
  final String title;
  final String eventType;
  final String severity;
  final String status;
  final String zoneName;
  final int estimatedVictims;
  final List<String> priorities;
  final DateTime startsAt;

  const AdminRescueEvent({
    required this.id,
    required this.title,
    required this.eventType,
    required this.severity,
    required this.status,
    required this.zoneName,
    required this.estimatedVictims,
    required this.priorities,
    required this.startsAt,
  });

  factory AdminRescueEvent.fromRow(Map<String, dynamic> row) =>
      AdminRescueEvent(
        id: row['event_id'].toString(),
        title: row['title']?.toString() ?? '',
        eventType: row['event_type']?.toString() ?? 'other',
        severity: row['severity']?.toString() ?? 'medium',
        status: row['status']?.toString() ?? 'active',
        zoneName: row['zone_name']?.toString() ?? '',
        estimatedVictims: (row['estimated_victims'] as num?)?.toInt() ?? 0,
        priorities: List<String>.from(
          row['intervention_priorities'] as List? ?? const [],
        ),
        startsAt:
            DateTime.tryParse(row['starts_at']?.toString() ?? '') ??
            DateTime.now(),
      );

  String get typeLabel => switch (eventType) {
    'earthquake' => 'Séisme',
    'flood' => 'Inondation',
    'cyclone' => 'Cyclone',
    'fire' => 'Incendie',
    'epidemic' => 'Épidémie',
    'landslide' => 'Glissement de terrain',
    'humanitarian_crisis' => 'Crise humanitaire',
    _ => 'Autre événement',
  };
}

class AdminRescueNeed {
  final String id;
  final String eventId;
  final String type;
  final String description;
  final String priority;
  final String status;
  final double? quantity;
  final String unit;

  const AdminRescueNeed({
    required this.id,
    required this.eventId,
    required this.type,
    required this.description,
    required this.priority,
    required this.status,
    required this.quantity,
    required this.unit,
  });

  factory AdminRescueNeed.fromRow(Map<String, dynamic> row) => AdminRescueNeed(
    id: row['need_id'].toString(),
    eventId: row['event_id']?.toString() ?? '',
    type: row['need_type']?.toString() ?? '',
    description: row['description']?.toString() ?? '',
    priority: row['priority']?.toString() ?? 'medium',
    status: row['status']?.toString() ?? 'open',
    quantity: (row['quantity'] as num?)?.toDouble(),
    unit: row['unit']?.toString() ?? '',
  );

  String get typeLabel => switch (type) {
    'blood' => 'Sang',
    'medication' => 'Médicaments',
    'medical_equipment' => 'Matériel médical',
    'ambulance' => 'Ambulances',
    'medical_staff' => 'Personnel médical',
    'drinking_water' => 'Eau potable',
    'food' => 'Nourriture',
    _ => type,
  };
}

class AdminRescueAssignment {
  final String id;
  final String status;
  final DateTime createdAt;
  final DateTime? acceptedAt;

  const AdminRescueAssignment({
    required this.id,
    required this.status,
    required this.createdAt,
    required this.acceptedAt,
  });

  factory AdminRescueAssignment.fromRow(Map<String, dynamic> row) =>
      AdminRescueAssignment(
        id: row['assignment_id'].toString(),
        status: row['status']?.toString() ?? 'sent',
        createdAt:
            DateTime.tryParse(row['created_at']?.toString() ?? '') ??
            DateTime.now(),
        acceptedAt: DateTime.tryParse(row['accepted_at']?.toString() ?? ''),
      );
}

class AdminRescueDocument {
  final String id;
  final String type;
  final String storagePath;
  final String fileName;
  final String status;

  const AdminRescueDocument({
    required this.id,
    required this.type,
    required this.storagePath,
    required this.fileName,
    required this.status,
  });

  factory AdminRescueDocument.fromRow(Map<String, dynamic> row) =>
      AdminRescueDocument(
        id: row['document_id'].toString(),
        type: row['document_type']?.toString() ?? 'other',
        storagePath: row['storage_path']?.toString() ?? '',
        fileName: row['file_name']?.toString() ?? '',
        status: row['verification_status']?.toString() ?? 'pending',
      );

  String get typeLabel => switch (type) {
    'identity' => 'Pièce d’identité',
    'professional_license' => 'Licence professionnelle',
    'certificate' => 'Certificat',
    _ => 'Autre justificatif',
  };
}

class RescueEventDraft {
  final String title;
  final String eventType;
  final String severity;
  final String zoneName;
  final int estimatedVictims;
  final List<String> priorities;
  final String description;

  const RescueEventDraft({
    required this.title,
    required this.eventType,
    required this.severity,
    required this.zoneName,
    required this.estimatedVictims,
    required this.priorities,
    required this.description,
  });
}

class RescueNeedDraft {
  final String eventId;
  final String type;
  final String description;
  final String priority;
  final double? quantity;
  final String unit;

  const RescueNeedDraft({
    required this.eventId,
    required this.type,
    required this.description,
    required this.priority,
    required this.quantity,
    required this.unit,
  });
}

class RescueAlertDraft {
  final String eventId;
  final String title;
  final String message;
  final String instructions;
  final String priority;
  final List<String> targetProfessions;
  final int volunteerLimit;

  const RescueAlertDraft({
    required this.eventId,
    required this.title,
    required this.message,
    required this.instructions,
    required this.priority,
    required this.targetProfessions,
    required this.volunteerLimit,
  });
}
