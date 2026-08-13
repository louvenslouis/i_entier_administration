import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/rescue_models.dart';
import '../supabase_config.dart';

abstract class RescueAdminRepository {
  Stream<List<AdminRescueVolunteer>> watchVolunteers();

  Stream<List<AdminRescueEvent>> watchEvents();

  Stream<List<AdminRescueNeed>> watchNeeds();

  Stream<List<AdminRescueAssignment>> watchAssignments();

  Stream<double> watchAvailableResourceUnits();

  Future<List<AdminRescueDocument>> loadDocuments(String volunteerId);

  Future<String> createDocumentUrl(String storagePath);

  Future<void> reviewVolunteer({
    required AdminRescueVolunteer volunteer,
    required String adminUid,
    required RescueReviewStatus status,
    String notes = '',
  });

  Future<String> createEvent(RescueEventDraft draft, String adminUid);

  Future<String> createNeed(RescueNeedDraft draft, String adminUid);

  Future<int> sendAlert(RescueAlertDraft draft, String adminUid);

  Future<void> updateNeedStatus(String needId, String status);
}

class SupabaseRescueAdminRepository implements RescueAdminRepository {
  final SupabaseClient client;

  SupabaseRescueAdminRepository({SupabaseClient? client})
    : client = client ?? SupabaseConfig.client;

  @override
  Stream<List<AdminRescueVolunteer>> watchVolunteers() => client
      .schema('ientier')
      .from('rescue_volunteers')
      .stream(primaryKey: ['volunteer_id'])
      .order('created_at', ascending: false)
      .map(
        (rows) =>
            rows.map(AdminRescueVolunteer.fromRow).toList(growable: false),
      );

  @override
  Stream<List<AdminRescueEvent>> watchEvents() => client
      .schema('ientier')
      .from('rescue_events')
      .stream(primaryKey: ['event_id'])
      .order('starts_at', ascending: false)
      .map(
        (rows) => rows.map(AdminRescueEvent.fromRow).toList(growable: false),
      );

  @override
  Stream<List<AdminRescueNeed>> watchNeeds() => client
      .schema('ientier')
      .from('rescue_urgent_needs')
      .stream(primaryKey: ['need_id'])
      .order('created_at', ascending: false)
      .map((rows) => rows.map(AdminRescueNeed.fromRow).toList(growable: false));

  @override
  Stream<List<AdminRescueAssignment>> watchAssignments() => client
      .schema('ientier')
      .from('rescue_assignments')
      .stream(primaryKey: ['assignment_id'])
      .order('created_at', ascending: false)
      .map(
        (rows) =>
            rows.map(AdminRescueAssignment.fromRow).toList(growable: false),
      );

  @override
  Stream<double> watchAvailableResourceUnits() => client
      .schema('ientier')
      .from('rescue_resources')
      .stream(primaryKey: ['resource_id'])
      .map(
        (rows) => rows
            .where(
              (row) => row['status'] == 'available' || row['status'] == 'low',
            )
            .fold<double>(
              0,
              (total, row) =>
                  total +
                  ((row['available_quantity'] as num?)?.toDouble() ?? 0) -
                  ((row['reserved_quantity'] as num?)?.toDouble() ?? 0),
            ),
      );

  @override
  Future<List<AdminRescueDocument>> loadDocuments(String volunteerId) async {
    final rows = await client
        .schema('ientier')
        .from('rescue_volunteer_documents')
        .select()
        .eq('volunteer_id', volunteerId)
        .order('created_at');
    return List<Map<String, dynamic>>.from(
      rows,
    ).map(AdminRescueDocument.fromRow).toList(growable: false);
  }

  @override
  Future<String> createDocumentUrl(String storagePath) =>
      client.storage.from('rescue-documents').createSignedUrl(storagePath, 300);

  @override
  Future<void> reviewVolunteer({
    required AdminRescueVolunteer volunteer,
    required String adminUid,
    required RescueReviewStatus status,
    String notes = '',
  }) async {
    if (status == RescueReviewStatus.pending) {
      throw ArgumentError('Une décision finale est requise.');
    }
    if (status == RescueReviewStatus.suspended && notes.trim().isEmpty) {
      throw ArgumentError('Un motif de suspension est requis.');
    }
    await client
        .schema('ientier')
        .rpc(
          'rescue_review_volunteer',
          params: {
            'p_volunteer_id': volunteer.id,
            'p_admin_id': adminUid,
            'p_new_status': status.storageValue,
            'p_notes': notes.trim(),
          },
        );
  }

  @override
  Future<String> createEvent(RescueEventDraft draft, String adminUid) async {
    final row = await client
        .schema('ientier')
        .from('rescue_events')
        .insert({
          'title': draft.title.trim(),
          'event_type': draft.eventType,
          'severity': draft.severity,
          'status': 'active',
          'zone_name': draft.zoneName.trim(),
          'estimated_victims': draft.estimatedVictims,
          'intervention_priorities': draft.priorities,
          'description': draft.description.trim(),
          'created_by': adminUid,
        })
        .select('event_id')
        .single();
    return row['event_id'].toString();
  }

  @override
  Future<String> createNeed(RescueNeedDraft draft, String adminUid) async {
    final row = await client
        .schema('ientier')
        .from('rescue_urgent_needs')
        .insert({
          'event_id': draft.eventId,
          'need_type': draft.type,
          'description': draft.description.trim(),
          'priority': draft.priority,
          'quantity': draft.quantity,
          'unit': draft.unit.trim(),
          'status': 'open',
          'created_by': adminUid,
        })
        .select('need_id')
        .single();
    return row['need_id'].toString();
  }

  @override
  Future<int> sendAlert(RescueAlertDraft draft, String adminUid) async {
    final row = await client
        .schema('ientier')
        .from('rescue_alerts')
        .insert({
          'event_id': draft.eventId,
          'title': draft.title.trim(),
          'message': draft.message.trim(),
          'instructions': draft.instructions.trim(),
          'priority': draft.priority,
          'target_professions': draft.targetProfessions,
          'push_enabled': true,
          'sms_enabled': true,
          'email_enabled': true,
          'status': 'draft',
          'created_by': adminUid,
        })
        .select('alert_id')
        .single();
    final result = await client
        .schema('ientier')
        .rpc(
          'rescue_auto_assign_alert',
          params: {
            'p_alert_id': row['alert_id'].toString(),
            'p_limit': draft.volunteerLimit,
          },
        );
    return (result as num?)?.toInt() ?? 0;
  }

  @override
  Future<void> updateNeedStatus(String needId, String status) => client
      .schema('ientier')
      .from('rescue_urgent_needs')
      .update({
        'status': status,
        if (status == 'resolved')
          'resolved_at': DateTime.now().toUtc().toIso8601String(),
      })
      .eq('need_id', needId);
}
