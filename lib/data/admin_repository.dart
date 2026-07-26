import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/provider_application.dart';

abstract class AdminRepository {
  Stream<bool> watchAccess(String uid);

  Stream<List<ProviderApplication>> watchApplications();

  Future<void> reviewApplication({
    required ProviderApplication application,
    required String adminUid,
    required ApplicationStatus status,
    String reason = '',
  });
}

class SupabaseAdminRepository implements AdminRepository {
  final SupabaseClient client;

  SupabaseAdminRepository({SupabaseClient? client})
    : client = client ?? Supabase.instance.client;

  @override
  Stream<bool> watchAccess(String uid) => client
      .schema('ientier')
      .from('administrators')
      .stream(primaryKey: ['user_id'])
      .eq('user_id', uid)
      .map((rows) => rows.isNotEmpty && rows.first['active'] == true);

  @override
  Stream<List<ProviderApplication>> watchApplications() => client
      .schema('ientier')
      .from('provider_profiles')
      .stream(primaryKey: ['provider_id'])
      .order('updated_at', ascending: false)
      .limit(250)
      .map(
        (rows) => rows.map(ProviderApplication.fromRow).toList(growable: false),
      );

  @override
  Future<void> reviewApplication({
    required ProviderApplication application,
    required String adminUid,
    required ApplicationStatus status,
    String reason = '',
  }) async {
    if (status == ApplicationStatus.pending) {
      throw ArgumentError('Une décision finale est requise.');
    }
    final normalizedReason = status == ApplicationStatus.rejected
        ? reason.trim()
        : '';
    if (status == ApplicationStatus.rejected && normalizedReason.isEmpty) {
      throw ArgumentError('Un motif de refus est requis.');
    }

    await client
        .schema('ientier')
        .rpc(
          'review_provider',
          params: {
            'p_provider_id': application.id,
            'p_admin_id': adminUid,
            'p_new_status': status.storageValue,
            'p_reason': normalizedReason,
          },
        );
  }
}
