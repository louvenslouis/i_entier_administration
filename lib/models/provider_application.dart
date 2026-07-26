import 'package:cloud_firestore/cloud_firestore.dart';

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

  factory ProviderApplication.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? const <String, dynamic>{};
    String text(String key) => data[key]?.toString().trim() ?? '';
    DateTime? date(String key) => switch (data[key]) {
      Timestamp timestamp => timestamp.toDate(),
      _ => null,
    };
    return ProviderApplication(
      id: document.id,
      type: ApplicationTypeText.fromStorage(text('accountType')),
      displayName: text('displayName'),
      category: text('category'),
      registrationNumber: text('registrationNumber'),
      contactPerson: text('contactPerson'),
      workplace: text('workplace'),
      phone: text('phone'),
      email: text('email'),
      address: text('address'),
      description: text('description'),
      experience: text('experience'),
      qualifications: text('qualifications'),
      services: text('services'),
      schedule: text('schedule'),
      atProviderSchedule: text('atProviderSchedule'),
      homeVisitSchedule: text('homeVisitSchedule'),
      videoSchedule: text('videoSchedule'),
      defaultPrice: text('defaultPrice'),
      atProviderEnabled: data['atProviderEnabled'] == true,
      homeVisitEnabled: data['homeVisitEnabled'] == true,
      videoEnabled: data['videoEnabled'] == true,
      institutionPricesPublished: data['institutionPricesPublished'] == true,
      servicePrices: text('servicePrices'),
      roomPrices: text('roomPrices'),
      available: data['available'] != false,
      isVisible: data['isVisible'] == true,
      status: ApplicationStatusText.fromStorage(text('verificationStatus')),
      rejectionReason: text('rejectionReason'),
      createdAt: date('createdAt'),
      updatedAt: date('updatedAt'),
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
