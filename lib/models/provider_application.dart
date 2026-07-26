enum ApplicationType { professional, institution }

extension ApplicationTypeText on ApplicationType {
  String get label => switch (this) {
    ApplicationType.professional => 'Personnel de santé',
    ApplicationType.institution => 'Institution de santé',
  };

  static ApplicationType fromStorage(String? value) => value == 'institution'
      ? ApplicationType.institution
      : ApplicationType.professional;
}

enum ApplicationStatus { pending, approved, rejected }

extension ApplicationStatusText on ApplicationStatus {
  String get storageValue => switch (this) {
    ApplicationStatus.pending => 'pending',
    ApplicationStatus.approved => 'approved',
    ApplicationStatus.rejected => 'rejected',
  };

  String get label => switch (this) {
    ApplicationStatus.pending => 'En attente',
    ApplicationStatus.approved => 'Approuvé',
    ApplicationStatus.rejected => 'Refusé',
  };

  static ApplicationStatus fromStorage(String? value) => switch (value) {
    'approved' => ApplicationStatus.approved,
    'rejected' => ApplicationStatus.rejected,
    _ => ApplicationStatus.pending,
  };
}

class ProviderApplication {
  final String id;
  final ApplicationType type;
  final String displayName;
  final String category;
  final String registrationNumber;
  final String contactPerson;
  final String workplace;
  final String phone;
  final String email;
  final String address;
  final String description;
  final String experience;
  final String qualifications;
  final String services;
  final String schedule;
  final String atProviderSchedule;
  final String homeVisitSchedule;
  final String videoSchedule;
  final String defaultPrice;
  final bool atProviderEnabled;
  final bool homeVisitEnabled;
  final bool videoEnabled;
  final bool institutionPricesPublished;
  final String servicePrices;
  final String roomPrices;
  final bool available;
  final bool isVisible;
  final ApplicationStatus status;
  final String rejectionReason;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const ProviderApplication({
    required this.id,
    required this.type,
    required this.displayName,
    required this.category,
    required this.registrationNumber,
    required this.contactPerson,
    required this.workplace,
    required this.phone,
    required this.email,
    required this.address,
    required this.description,
    required this.experience,
    required this.qualifications,
    required this.services,
    required this.schedule,
    this.atProviderSchedule = '',
    this.homeVisitSchedule = '',
    this.videoSchedule = '',
    this.defaultPrice = '',
    this.atProviderEnabled = false,
    this.homeVisitEnabled = false,
    this.videoEnabled = false,
    this.institutionPricesPublished = false,
    this.servicePrices = '',
    this.roomPrices = '',
    required this.available,
    required this.isVisible,
    required this.status,
    required this.rejectionReason,
    this.createdAt,
    this.updatedAt,
  });

  factory ProviderApplication.fromRow(Map<String, dynamic> data) {
    String text(String key) => data[key]?.toString().trim() ?? '';
    DateTime? date(String key) {
      final value = data[key];
      if (value is DateTime) return value;
      return value is String ? DateTime.tryParse(value)?.toLocal() : null;
    }

    final legacy = data['legacy_availability_config'] is Map
        ? Map<String, dynamic>.from(data['legacy_availability_config'] as Map)
        : const <String, dynamic>{};

    return ProviderApplication(
      id: text('provider_id'),
      type: ApplicationTypeText.fromStorage(text('account_type')),
      displayName: text('display_name'),
      category: text('category'),
      registrationNumber: text('registration_number'),
      contactPerson: text('contact_person'),
      workplace: text('workplace'),
      phone: text('phone'),
      email: text('email'),
      address: text('address'),
      description: text('description'),
      experience: text('experience'),
      qualifications: text('qualifications'),
      services: text('services_summary'),
      schedule: text('schedule_summary'),
      atProviderSchedule: legacy['atProviderSchedule']?.toString() ?? '',
      homeVisitSchedule: legacy['homeVisitSchedule']?.toString() ?? '',
      videoSchedule: legacy['videoSchedule']?.toString() ?? '',
      defaultPrice: legacy['defaultPrice']?.toString() ?? '',
      atProviderEnabled: legacy['atProviderEnabled'] == true,
      homeVisitEnabled: legacy['homeVisitEnabled'] == true,
      videoEnabled: legacy['videoEnabled'] == true,
      institutionPricesPublished: data['institution_prices_published'] == true,
      servicePrices: text('service_prices_summary'),
      roomPrices: text('room_prices_summary'),
      available: data['available'] != false,
      isVisible: data['is_visible'] == true,
      status: ApplicationStatusText.fromStorage(text('verification_status')),
      rejectionReason: text('rejection_reason'),
      createdAt: date('created_at'),
      updatedAt: date('updated_at'),
    );
  }

  String get appointmentModesSummary => [
    if (atProviderEnabled && atProviderSchedule.isNotEmpty)
      'Sur place : $atProviderSchedule',
    if (homeVisitEnabled && homeVisitSchedule.isNotEmpty)
      'À domicile : $homeVisitSchedule',
    if (videoEnabled && videoSchedule.isNotEmpty)
      'Visioconférence : $videoSchedule',
  ].join('\n');
}
