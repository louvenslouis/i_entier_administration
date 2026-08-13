import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/mobile_clinic_admin.dart';

abstract class MobileClinicAdminRepository {
  Stream<List<MobileClinicAdminRecord>> watchClinics();

  Stream<List<MobileClinicAdminTour>> watchTours();

  Future<void> review({
    required String clinicId,
    required String adminId,
    required MobileClinicAdminStatus status,
    String reason,
  });
}

class SupabaseMobileClinicAdminRepository
    implements MobileClinicAdminRepository {
  final SupabaseClient client;

  SupabaseMobileClinicAdminRepository({SupabaseClient? client})
    : client = client ?? Supabase.instance.client;

  @override
  Stream<List<MobileClinicAdminRecord>> watchClinics() => client
      .schema('ientier')
      .from('mobile_clinics')
      .stream(primaryKey: ['mobile_clinic_id'])
      .order('created_at', ascending: false)
      .map(
        (rows) =>
            rows.map(MobileClinicAdminRecord.fromRow).toList(growable: false),
      );

  @override
  Stream<List<MobileClinicAdminTour>> watchTours() => client
      .schema('ientier')
      .from('mobile_clinic_tours')
      .stream(primaryKey: ['mobile_clinic_tour_id'])
      .order('starts_at', ascending: false)
      .map(
        (rows) =>
            rows.map(MobileClinicAdminTour.fromRow).toList(growable: false),
      );

  @override
  Future<void> review({
    required String clinicId,
    required String adminId,
    required MobileClinicAdminStatus status,
    String reason = '',
  }) async {
    if (status == MobileClinicAdminStatus.pending) {
      throw ArgumentError('Une décision finale est requise.');
    }
    await client
        .schema('ientier')
        .rpc(
          'review_mobile_clinic',
          params: {
            'p_mobile_clinic_id': clinicId,
            'p_admin_id': adminId,
            'p_new_status': status.storageValue,
            'p_reason': reason.trim(),
          },
        );
  }
}
