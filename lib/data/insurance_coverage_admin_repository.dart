import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/insurance_coverage_admin.dart';
import '../supabase_config.dart';

abstract class InsuranceCoverageAdminRepository {
  Stream<List<InsuranceCoverageAdminRequest>> watchCoverages();

  Future<String> createCardUrl(String storagePath);

  Future<void> reviewCoverage({
    required String coverageId,
    required bool approve,
    required String reason,
    DateTime? validUntil,
  });
}

class SupabaseInsuranceCoverageAdminRepository
    implements InsuranceCoverageAdminRepository {
  final SupabaseClient client;

  SupabaseInsuranceCoverageAdminRepository({SupabaseClient? client})
    : client = client ?? SupabaseConfig.client;

  @override
  Stream<List<InsuranceCoverageAdminRequest>> watchCoverages() => client
      .schema('ientier')
      .from('medical_insurance_coverages')
      .stream(primaryKey: ['coverage_id'])
      .order('submitted_at', ascending: false)
      .map(
        (rows) => rows
            .map(InsuranceCoverageAdminRequest.fromRow)
            .toList(growable: false),
      );

  @override
  Future<String> createCardUrl(String storagePath) =>
      client.storage.from('insurance-cards').createSignedUrl(storagePath, 600);

  @override
  Future<void> reviewCoverage({
    required String coverageId,
    required bool approve,
    required String reason,
    DateTime? validUntil,
  }) => client
      .schema('ientier')
      .rpc(
        'review_medical_insurance_coverage',
        params: {
          'p_coverage_id': coverageId,
          'p_approve': approve,
          'p_reason': reason,
          'p_valid_until': validUntil == null
              ? null
              : '${validUntil.year.toString().padLeft(4, '0')}-${validUntil.month.toString().padLeft(2, '0')}-${validUntil.day.toString().padLeft(2, '0')}',
        },
      );
}
