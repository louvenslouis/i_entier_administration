import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/traditional_medicine_admin.dart';
import '../supabase_config.dart';

abstract class TraditionalMedicineAdminRepository {
  Stream<List<TraditionalAdminApplication>> watchApplications();
  Stream<List<TraditionalAdminDocument>> watchDocuments(String providerId);
  Stream<List<TraditionalSafetyReport>> watchReports();

  Future<String> createDocumentReviewUrl(String storagePath);
  Future<void> reviewDocument({
    required String documentId,
    required String adminId,
    required bool verified,
    String note,
  });
  Future<void> reviewApplication({
    required String providerId,
    required String adminId,
    required bool approved,
    String reason,
  });
  Future<void> reviewReport({
    required String reportId,
    required String adminId,
    required bool credible,
    required String note,
  });
}

class SupabaseTraditionalMedicineAdminRepository
    implements TraditionalMedicineAdminRepository {
  final SupabaseClient client;

  SupabaseTraditionalMedicineAdminRepository({SupabaseClient? client})
    : client = client ?? SupabaseConfig.client;

  @override
  Stream<List<TraditionalAdminApplication>> watchApplications() => client
      .schema('ientier')
      .from('traditional_practitioner_profiles')
      .stream(primaryKey: ['provider_id'])
      .order('created_at', ascending: false)
      .asyncMap((rows) async {
        final result = <TraditionalAdminApplication>[];
        for (final row in rows) {
          final provider = await client
              .schema('ientier')
              .from('provider_profiles')
              .select('display_name,email,phone')
              .eq('provider_id', row['provider_id'] as Object)
              .maybeSingle();
          if (provider != null) {
            result.add(TraditionalAdminApplication.fromRows(row, provider));
          }
        }
        return result;
      });

  @override
  Stream<List<TraditionalAdminDocument>> watchDocuments(String providerId) =>
      client
          .schema('ientier')
          .from('traditional_practitioner_documents')
          .stream(primaryKey: ['document_id'])
          .eq('provider_id', providerId)
          .order('created_at')
          .map(
            (rows) => rows
                .map(TraditionalAdminDocument.fromRow)
                .toList(growable: false),
          );

  @override
  Stream<List<TraditionalSafetyReport>> watchReports() => client
      .schema('ientier')
      .from('traditional_safety_reports')
      .stream(primaryKey: ['report_id'])
      .order('created_at', ascending: false)
      .asyncMap((rows) async {
        final names = <String, String>{};
        final result = <TraditionalSafetyReport>[];
        for (final row in rows) {
          final providerId = row['practitioner_id']?.toString() ?? '';
          if (!names.containsKey(providerId)) {
            final provider = await client
                .schema('ientier')
                .from('provider_profiles')
                .select('display_name')
                .eq('provider_id', providerId)
                .maybeSingle();
            names[providerId] = provider?['display_name']?.toString() ?? '';
          }
          result.add(
            TraditionalSafetyReport.fromRows(row, names[providerId] ?? ''),
          );
        }
        return result;
      });

  @override
  Future<String> createDocumentReviewUrl(String storagePath) => client.storage
      .from('traditional-practitioner-documents')
      .createSignedUrl(storagePath, 300);

  @override
  Future<void> reviewDocument({
    required String documentId,
    required String adminId,
    required bool verified,
    String note = '',
  }) => client
      .schema('ientier')
      .from('traditional_practitioner_documents')
      .update({
        'review_status': verified ? 'verified' : 'rejected',
        'review_note': note.trim(),
        'reviewed_by': adminId,
        'reviewed_at': DateTime.now().toUtc().toIso8601String(),
      })
      .eq('document_id', documentId);

  @override
  Future<void> reviewApplication({
    required String providerId,
    required String adminId,
    required bool approved,
    String reason = '',
  }) async {
    if (!approved && reason.trim().isEmpty) {
      throw ArgumentError('Un motif est requis.');
    }
    final documents = await client
        .schema('ientier')
        .from('traditional_practitioner_documents')
        .select('document_type,review_status')
        .eq('provider_id', providerId);
    final rows = List<Map<String, dynamic>>.from(documents);
    final identityVerified = rows.any(
      (row) =>
          row['document_type'] == 'identity' &&
          row['review_status'] == 'verified',
    );
    final attestationVerified = rows.any(
      (row) =>
          (row['document_type'] == 'attestation' ||
              row['document_type'] == 'training') &&
          row['review_status'] == 'verified',
    );
    if (approved && (!identityVerified || !attestationVerified)) {
      throw StateError(
        'Une identité et une attestation vérifiées sont requises.',
      );
    }
    await client
        .schema('ientier')
        .from('traditional_practitioner_profiles')
        .update({
          'identity_status': identityVerified ? 'verified' : 'rejected',
          'attestation_status': attestationVerified ? 'verified' : 'rejected',
          'validation_status': approved ? 'approved' : 'rejected',
          'review_reason': approved ? '' : reason.trim(),
          'profile_verification_score': approved ? 20 : 0,
          'validated_by': adminId,
          'validated_at': DateTime.now().toUtc().toIso8601String(),
          'suspended_at': null,
        })
        .eq('provider_id', providerId);
  }

  @override
  Future<void> reviewReport({
    required String reportId,
    required String adminId,
    required bool credible,
    required String note,
  }) => client
      .schema('ientier')
      .from('traditional_safety_reports')
      .update({
        'credibility_status': credible ? 'credible' : 'not_credible',
        'resolution_status': credible ? 'investigating' : 'dismissed',
        'admin_note': note.trim(),
        'reviewed_by': adminId,
        'reviewed_at': DateTime.now().toUtc().toIso8601String(),
      })
      .eq('report_id', reportId);
}
