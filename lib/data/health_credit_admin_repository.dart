import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/health_credit_admin_models.dart';

abstract class HealthCreditAdminRepository {
  Stream<HealthCreditAdminDashboardData> watchDashboard();
  Future<void> refreshOverdues(String adminId);
  Future<void> validateReference({
    required String referenceId,
    required String adminId,
    required bool valid,
    String note = '',
  });
  Future<void> reviewApplication({
    required String applicationId,
    required String adminId,
    required bool approve,
    String reason = '',
  });
  Future<void> reviewPayment({
    required String paymentId,
    required String adminId,
    required bool confirm,
    String reason = '',
  });
  Future<void> flagDefault({
    required String creditId,
    required String adminId,
    required bool hasJustification,
    String justification = '',
  });
  Future<void> manageSolidarity({
    required String requestId,
    required String adminId,
    required String status,
    required double approvedAmount,
    required double fundedAmount,
    String? centerId,
    required String socialWorker,
    required String medicalCoordinator,
    required String followUpNote,
  });
  Future<String> createDocumentUrl(String storagePath);
}

class SupabaseHealthCreditAdminRepository
    implements HealthCreditAdminRepository {
  final SupabaseClient client;
  SupabaseHealthCreditAdminRepository({SupabaseClient? client})
    : client = client ?? Supabase.instance.client;

  @override
  Stream<HealthCreditAdminDashboardData> watchDashboard() async* {
    while (true) {
      yield await _loadDashboard();
      await Future<void>.delayed(const Duration(seconds: 20));
    }
  }

  Future<HealthCreditAdminDashboardData> _loadDashboard() async {
    final results = await Future.wait<dynamic>([
      client
          .schema('ientier')
          .from('health_credit_applications')
          .select()
          .order('created_at', ascending: false),
      client.schema('ientier').from('health_credit_references').select(),
      client.schema('ientier').from('health_credit_documents').select(),
      client
          .schema('ientier')
          .from('health_credits')
          .select()
          .order('activated_at', ascending: false),
      client
          .schema('ientier')
          .from('health_credit_installments')
          .select()
          .order('due_date'),
      client
          .schema('ientier')
          .from('health_credit_payments')
          .select()
          .order('created_at', ascending: false),
      client
          .schema('ientier')
          .from('health_social_assessments')
          .select()
          .order('assessed_at', ascending: false),
      client
          .schema('ientier')
          .from('health_solidarity_requests')
          .select()
          .order('created_at', ascending: false),
      client
          .schema('ientier')
          .from('health_partner_centers')
          .select()
          .eq('active', true)
          .order('name'),
    ]);
    List<Map<String, dynamic>> rows(int index) =>
        List<Map<String, dynamic>>.from(results[index] as List);
    final references = rows(1).map(AdminHealthCreditReference.fromRow).toList();
    final documents = rows(2).map(AdminHealthCreditDocument.fromRow).toList();
    return HealthCreditAdminDashboardData(
      applications: rows(0).map((row) {
        final id = row['application_id']?.toString();
        return AdminHealthCreditApplication.fromRow(
          row,
          references: references
              .where(
                (item) =>
                    rows(1)
                        .firstWhere(
                          (raw) => raw['reference_id']?.toString() == item.id,
                        )['application_id']
                        ?.toString() ==
                    id,
              )
              .toList(),
          documents: documents
              .where(
                (item) =>
                    rows(2)
                        .firstWhere(
                          (raw) => raw['document_id']?.toString() == item.id,
                        )['application_id']
                        ?.toString() ==
                    id,
              )
              .toList(),
        );
      }).toList(),
      credits: rows(3).map(AdminHealthCredit.fromRow).toList(),
      installments: rows(4).map(AdminHealthInstallment.fromRow).toList(),
      payments: rows(5).map(AdminHealthPayment.fromRow).toList(),
      assessments: rows(6).map(AdminSocialAssessment.fromRow).toList(),
      solidarityRequests: rows(7).map(AdminSolidarityRequest.fromRow).toList(),
      partnerCenters: rows(8).map(AdminPartnerCenter.fromRow).toList(),
    );
  }

  @override
  Future<void> refreshOverdues(String adminId) => client
      .schema('ientier')
      .rpc('refresh_health_credit_overdues', params: {'p_admin_id': adminId});

  @override
  Future<void> validateReference({
    required String referenceId,
    required String adminId,
    required bool valid,
    String note = '',
  }) => client
      .schema('ientier')
      .rpc(
        'validate_health_credit_reference',
        params: {
          'p_reference_id': referenceId,
          'p_admin_id': adminId,
          'p_valid': valid,
          'p_note': note,
        },
      );

  @override
  Future<void> reviewApplication({
    required String applicationId,
    required String adminId,
    required bool approve,
    String reason = '',
  }) => client
      .schema('ientier')
      .rpc(
        'review_health_credit_application',
        params: {
          'p_application_id': applicationId,
          'p_admin_id': adminId,
          'p_approve': approve,
          'p_reason': reason,
        },
      );

  @override
  Future<void> reviewPayment({
    required String paymentId,
    required String adminId,
    required bool confirm,
    String reason = '',
  }) => client
      .schema('ientier')
      .rpc(
        'review_health_credit_payment',
        params: {
          'p_payment_id': paymentId,
          'p_admin_id': adminId,
          'p_confirm': confirm,
          'p_reason': reason,
        },
      );

  @override
  Future<void> flagDefault({
    required String creditId,
    required String adminId,
    required bool hasJustification,
    String justification = '',
  }) => client
      .schema('ientier')
      .rpc(
        'flag_health_credit_default',
        params: {
          'p_credit_id': creditId,
          'p_admin_id': adminId,
          'p_has_justification': hasJustification,
          'p_justification': justification,
        },
      );

  @override
  Future<void> manageSolidarity({
    required String requestId,
    required String adminId,
    required String status,
    required double approvedAmount,
    required double fundedAmount,
    String? centerId,
    required String socialWorker,
    required String medicalCoordinator,
    required String followUpNote,
  }) => client
      .schema('ientier')
      .rpc(
        'manage_health_solidarity_request',
        params: {
          'p_request_id': requestId,
          'p_admin_id': adminId,
          'p_status': status,
          'p_approved_amount': approvedAmount,
          'p_funded_amount': fundedAmount,
          'p_partner_center_id': centerId,
          'p_social_worker': socialWorker,
          'p_medical_coordinator': medicalCoordinator,
          'p_follow_up_note': followUpNote,
        },
      );

  @override
  Future<String> createDocumentUrl(String storagePath) => client.storage
      .from('health-credit-documents')
      .createSignedUrl(storagePath, 900);
}
