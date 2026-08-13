import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/insurance_coverage_admin.dart';
import '../supabase_config.dart';

abstract class InsuranceCoverageAdminRepository {
  Stream<List<InsuranceCoverageAdminRequest>> watchCoverages();

  Future<String> createCardUrl(String storagePath);
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
}
