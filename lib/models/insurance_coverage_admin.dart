class InsuranceCoverageAdminRequest {
  final String id;
  final String patientId;
  final String patientName;
  final String insurerCode;
  final String memberNumber;
  final String frontPath;
  final String backPath;
  final String status;
  final String reviewNote;
  final String? reviewedBy;
  final DateTime? reviewedAt;
  final DateTime? validFrom;
  final DateTime? validUntil;
  final DateTime submittedAt;

  const InsuranceCoverageAdminRequest({
    required this.id,
    required this.patientId,
    required this.patientName,
    required this.insurerCode,
    required this.memberNumber,
    required this.frontPath,
    required this.backPath,
    required this.status,
    required this.reviewNote,
    required this.reviewedBy,
    required this.reviewedAt,
    required this.validFrom,
    required this.validUntil,
    required this.submittedAt,
  });

  factory InsuranceCoverageAdminRequest.fromRow(Map<String, dynamic> row) =>
      InsuranceCoverageAdminRequest(
        id: row['coverage_id']?.toString() ?? '',
        patientId: row['patient_id']?.toString() ?? '',
        patientName: row['patient_name_snapshot']?.toString() ?? '',
        insurerCode: row['insurer_code']?.toString() ?? 'OFATMA',
        memberNumber: row['member_number']?.toString() ?? '',
        frontPath: row['card_front_path']?.toString() ?? '',
        backPath: row['card_back_path']?.toString() ?? '',
        status: row['status']?.toString() ?? 'pending',
        reviewNote: row['review_note']?.toString() ?? '',
        reviewedBy: row['reviewed_by']?.toString(),
        reviewedAt: _date(row['reviewed_at']),
        validFrom: _date(row['valid_from']),
        validUntil: _date(row['valid_until']),
        submittedAt: _date(row['submitted_at']) ?? DateTime.now(),
      );

  bool get pending => status == 'pending';
  bool get verified => status == 'verified';
  bool get rejected => status == 'rejected';
}

DateTime? _date(Object? value) =>
    DateTime.tryParse(value?.toString() ?? '')?.toLocal();
