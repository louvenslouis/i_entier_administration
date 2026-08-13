import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/pharmacy_admin.dart';

abstract class PharmacyAdminRepository {
  Stream<List<PharmacyAdminRecord>> watchPharmacies();

  Future<void> review({
    required String pharmacyId,
    required String adminId,
    required PharmacyAdminStatus status,
    String reason = '',
  });
}

class SupabasePharmacyAdminRepository implements PharmacyAdminRepository {
  final SupabaseClient client;

  SupabasePharmacyAdminRepository({SupabaseClient? client})
    : client = client ?? Supabase.instance.client;

  @override
  Stream<List<PharmacyAdminRecord>> watchPharmacies() async* {
    final refreshes = StreamController<void>();
    void refresh([Object? _]) {
      if (!refreshes.isClosed) refreshes.add(null);
    }

    void fail(Object error, StackTrace stackTrace) {
      if (!refreshes.isClosed) refreshes.addError(error, stackTrace);
    }

    final subscriptions = <StreamSubscription<dynamic>>[
      client
          .schema('ientier')
          .from('pharmacies')
          .stream(primaryKey: ['pharmacy_id'])
          .listen(refresh, onError: fail),
      client
          .schema('ientier')
          .from('pharmacy_products')
          .stream(primaryKey: ['product_id'])
          .listen(refresh, onError: fail),
      client
          .schema('ientier')
          .from('pharmacy_orders')
          .stream(primaryKey: ['order_id'])
          .listen(refresh, onError: fail),
      client
          .schema('ientier')
          .from('pharmacy_sales')
          .stream(primaryKey: ['sale_id'])
          .listen(refresh, onError: fail),
    ];
    try {
      await for (final _ in refreshes.stream) {
        final rows = await client
            .schema('ientier')
            .from('v_pharmacy_admin_overview')
            .select()
            .order('created_at', ascending: false);
        yield rows.map(PharmacyAdminRecord.fromRow).toList(growable: false);
      }
    } finally {
      await Future.wait(
        subscriptions.map((subscription) => subscription.cancel()),
      );
      await refreshes.close();
    }
  }

  @override
  Future<void> review({
    required String pharmacyId,
    required String adminId,
    required PharmacyAdminStatus status,
    String reason = '',
  }) async {
    if (status == PharmacyAdminStatus.pending) {
      throw ArgumentError('Une décision est requise.');
    }
    await client
        .schema('ientier')
        .rpc(
          'review_pharmacy',
          params: {
            'p_pharmacy_id': pharmacyId,
            'p_admin_id': adminId,
            'p_new_status': status.storageValue,
            'p_reason': reason.trim(),
          },
        );
  }
}
