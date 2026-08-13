double adminCreditAmount(Object? value) => value is num
    ? value.toDouble()
    : double.tryParse(value?.toString() ?? '') ?? 0;

DateTime? adminCreditDate(Object? value) =>
    DateTime.tryParse(value?.toString() ?? '')?.toLocal();

class AdminHealthCreditReference {
  final String id;
  final String name;
  final String phone;
  final String relationship;
  final String type;
  final String status;
  final String note;

  const AdminHealthCreditReference({
    required this.id,
    required this.name,
    required this.phone,
    required this.relationship,
    required this.type,
    required this.status,
    required this.note,
  });

  factory AdminHealthCreditReference.fromRow(Map<String, dynamic> row) =>
      AdminHealthCreditReference(
        id: row['reference_id']?.toString() ?? '',
        name: row['full_name']?.toString() ?? '',
        phone: row['phone']?.toString() ?? '',
        relationship: row['relationship']?.toString() ?? '',
        type: row['reference_type']?.toString() ?? '',
        status: row['validation_status']?.toString() ?? '',
        note: row['validation_note']?.toString() ?? '',
      );
}

class AdminHealthCreditDocument {
  final String id;
  final String fileName;
  final String storagePath;
  final String status;

  const AdminHealthCreditDocument({
    required this.id,
    required this.fileName,
    required this.storagePath,
    required this.status,
  });

  factory AdminHealthCreditDocument.fromRow(Map<String, dynamic> row) =>
      AdminHealthCreditDocument(
        id: row['document_id']?.toString() ?? '',
        fileName: row['file_name']?.toString() ?? '',
        storagePath: row['storage_path']?.toString() ?? '',
        status: row['verification_status']?.toString() ?? '',
      );
}

class AdminHealthCreditApplication {
  final String id;
  final String patientId;
  final String patientName;
  final double requestedAmount;
  final String medicalReason;
  final double income;
  final double expenses;
  final double disposable;
  final String employer;
  final int installments;
  final double estimatedInstallment;
  final int preliminaryScore;
  final int validatedReferences;
  final String status;
  final String decisionReason;
  final DateTime createdAt;
  final List<AdminHealthCreditReference> references;
  final List<AdminHealthCreditDocument> documents;

  const AdminHealthCreditApplication({
    required this.id,
    required this.patientId,
    required this.patientName,
    required this.requestedAmount,
    required this.medicalReason,
    required this.income,
    required this.expenses,
    required this.disposable,
    required this.employer,
    required this.installments,
    required this.estimatedInstallment,
    required this.preliminaryScore,
    required this.validatedReferences,
    required this.status,
    required this.decisionReason,
    required this.createdAt,
    this.references = const [],
    this.documents = const [],
  });

  factory AdminHealthCreditApplication.fromRow(
    Map<String, dynamic> row, {
    List<AdminHealthCreditReference> references = const [],
    List<AdminHealthCreditDocument> documents = const [],
  }) => AdminHealthCreditApplication(
    id: row['application_id']?.toString() ?? '',
    patientId: row['patient_id']?.toString() ?? '',
    patientName: row['patient_name_snapshot']?.toString() ?? '',
    requestedAmount: adminCreditAmount(row['requested_amount']),
    medicalReason: row['medical_reason']?.toString() ?? '',
    income: adminCreditAmount(row['monthly_income']),
    expenses: adminCreditAmount(row['monthly_expenses']),
    disposable: adminCreditAmount(row['disposable_income']),
    employer: row['employer']?.toString() ?? '',
    installments: (row['recommended_installments'] as num?)?.toInt() ?? 0,
    estimatedInstallment: adminCreditAmount(row['estimated_installment']),
    preliminaryScore: (row['preliminary_score'] as num?)?.toInt() ?? 0,
    validatedReferences:
        (row['validated_reference_count'] as num?)?.toInt() ?? 0,
    status: row['status']?.toString() ?? '',
    decisionReason: row['decision_reason']?.toString() ?? '',
    createdAt: adminCreditDate(row['created_at']) ?? DateTime.now(),
    references: references,
    documents: documents,
  );
}

class AdminHealthCredit {
  final String id;
  final String patientId;
  final double principal;
  final double balance;
  final int score;
  final String status;

  const AdminHealthCredit({
    required this.id,
    required this.patientId,
    required this.principal,
    required this.balance,
    required this.score,
    required this.status,
  });

  factory AdminHealthCredit.fromRow(Map<String, dynamic> row) =>
      AdminHealthCredit(
        id: row['credit_id']?.toString() ?? '',
        patientId: row['patient_id']?.toString() ?? '',
        principal: adminCreditAmount(row['principal_amount']),
        balance: adminCreditAmount(row['outstanding_balance']),
        score: (row['financial_health_score'] as num?)?.toInt() ?? 100,
        status: row['status']?.toString() ?? '',
      );
}

class AdminHealthInstallment {
  final String id;
  final String creditId;
  final DateTime dueDate;
  final double due;
  final double paid;
  final String status;

  const AdminHealthInstallment({
    required this.id,
    required this.creditId,
    required this.dueDate,
    required this.due,
    required this.paid,
    required this.status,
  });

  factory AdminHealthInstallment.fromRow(Map<String, dynamic> row) =>
      AdminHealthInstallment(
        id: row['installment_id']?.toString() ?? '',
        creditId: row['credit_id']?.toString() ?? '',
        dueDate: adminCreditDate(row['due_date']) ?? DateTime.now(),
        due: adminCreditAmount(row['amount_due']),
        paid: adminCreditAmount(row['amount_paid']),
        status: row['status']?.toString() ?? '',
      );
}

class AdminHealthPayment {
  final String id;
  final String creditId;
  final String patientId;
  final double amount;
  final String method;
  final String reference;
  final String status;
  final DateTime createdAt;

  const AdminHealthPayment({
    required this.id,
    required this.creditId,
    required this.patientId,
    required this.amount,
    required this.method,
    required this.reference,
    required this.status,
    required this.createdAt,
  });

  factory AdminHealthPayment.fromRow(Map<String, dynamic> row) =>
      AdminHealthPayment(
        id: row['payment_id']?.toString() ?? '',
        creditId: row['credit_id']?.toString() ?? '',
        patientId: row['patient_id']?.toString() ?? '',
        amount: adminCreditAmount(row['amount']),
        method: row['payment_method']?.toString() ?? '',
        reference: row['patient_reference']?.toString() ?? '',
        status: row['payment_status']?.toString() ?? '',
        createdAt: adminCreditDate(row['created_at']) ?? DateTime.now(),
      );
}

class AdminSocialAssessment {
  final String id;
  final String patientId;
  final int score;
  final String level;
  final bool vulnerable;
  final DateTime assessedAt;

  const AdminSocialAssessment({
    required this.id,
    required this.patientId,
    required this.score,
    required this.level,
    required this.vulnerable,
    required this.assessedAt,
  });

  factory AdminSocialAssessment.fromRow(Map<String, dynamic> row) =>
      AdminSocialAssessment(
        id: row['assessment_id']?.toString() ?? '',
        patientId: row['patient_id']?.toString() ?? '',
        score: (row['vulnerability_score'] as num?)?.toInt() ?? 0,
        level: row['vulnerability_level']?.toString() ?? '',
        vulnerable: row['recognized_vulnerable'] == true,
        assessedAt: adminCreditDate(row['assessed_at']) ?? DateTime.now(),
      );
}

class AdminPartnerCenter {
  final String id;
  final String name;
  const AdminPartnerCenter({required this.id, required this.name});
  factory AdminPartnerCenter.fromRow(Map<String, dynamic> row) =>
      AdminPartnerCenter(
        id: row['center_id']?.toString() ?? '',
        name: row['name']?.toString() ?? '',
      );
}

class AdminSolidarityRequest {
  final String id;
  final String patientId;
  final double requestedAmount;
  final double approvedAmount;
  final double fundedAmount;
  final String medicalNeed;
  final String status;
  final String? centerId;
  final String socialWorker;
  final String medicalCoordinator;
  final String followUpNote;
  final DateTime createdAt;

  const AdminSolidarityRequest({
    required this.id,
    required this.patientId,
    required this.requestedAmount,
    required this.approvedAmount,
    required this.fundedAmount,
    required this.medicalNeed,
    required this.status,
    required this.centerId,
    required this.socialWorker,
    required this.medicalCoordinator,
    required this.followUpNote,
    required this.createdAt,
  });

  factory AdminSolidarityRequest.fromRow(Map<String, dynamic> row) =>
      AdminSolidarityRequest(
        id: row['solidarity_request_id']?.toString() ?? '',
        patientId: row['patient_id']?.toString() ?? '',
        requestedAmount: adminCreditAmount(row['requested_amount']),
        approvedAmount: adminCreditAmount(row['approved_amount']),
        fundedAmount: adminCreditAmount(row['funded_amount']),
        medicalNeed: row['medical_need']?.toString() ?? '',
        status: row['status']?.toString() ?? '',
        centerId: row['partner_center_id']?.toString(),
        socialWorker: row['social_worker']?.toString() ?? '',
        medicalCoordinator: row['medical_coordinator']?.toString() ?? '',
        followUpNote: row['follow_up_note']?.toString() ?? '',
        createdAt: adminCreditDate(row['created_at']) ?? DateTime.now(),
      );
}

class HealthCreditAdminDashboardData {
  final List<AdminHealthCreditApplication> applications;
  final List<AdminHealthCredit> credits;
  final List<AdminHealthInstallment> installments;
  final List<AdminHealthPayment> payments;
  final List<AdminSocialAssessment> assessments;
  final List<AdminSolidarityRequest> solidarityRequests;
  final List<AdminPartnerCenter> partnerCenters;

  const HealthCreditAdminDashboardData({
    required this.applications,
    required this.credits,
    required this.installments,
    required this.payments,
    required this.assessments,
    required this.solidarityRequests,
    required this.partnerCenters,
  });

  int get activeCredits => credits
      .where((item) => item.status == 'active' || item.status == 'suspended')
      .length;
  int get vulnerablePatients => assessments
      .where((item) => item.vulnerable)
      .map((item) => item.patientId)
      .toSet()
      .length;
  int get fundedCases => solidarityRequests
      .where(
        (item) => const {
          'partially_funded',
          'funded',
          'in_care',
          'completed',
        }.contains(item.status),
      )
      .length;
  int get lateInstallments =>
      installments.where((item) => item.status == 'late').length;
  double get averageScore => credits.isEmpty
      ? 0
      : credits.fold<double>(0, (sum, item) => sum + item.score) /
            credits.length;
  double get repaymentRate {
    final principal = credits.fold<double>(
      0,
      (sum, item) => sum + item.principal,
    );
    final balance = credits.fold<double>(0, (sum, item) => sum + item.balance);
    return principal <= 0
        ? 0
        : ((principal - balance) / principal).clamp(0, 1).toDouble();
  }
}
