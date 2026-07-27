import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/diagnostic_pathway_config.dart';

abstract class DiagnosticConfigRepository {
  Stream<List<DiagnosticPathwayBundle>> watchPathways();

  Future<void> createPathway({
    required DiagnosticPathwayDefinition definition,
    required String adminUid,
  });

  Future<void> createDraftFromPublished({
    required DiagnosticPathwayBundle bundle,
    required String adminUid,
  });

  Future<void> saveDraft({
    required DiagnosticPathwayVersion draft,
    required DiagnosticPathwayDefinition definition,
    required String adminUid,
  });

  Future<void> publishDraft({
    required DiagnosticPathwayVersion draft,
    required String adminUid,
    required String changeNote,
  });

  Future<void> deleteDraft(DiagnosticPathwayVersion draft);
}

class SupabaseDiagnosticConfigRepository implements DiagnosticConfigRepository {
  final SupabaseClient client;

  SupabaseDiagnosticConfigRepository({SupabaseClient? client})
    : client = client ?? Supabase.instance.client;

  @override
  Stream<List<DiagnosticPathwayBundle>> watchPathways() => client
      .schema('ientier')
      .from('diagnostic_pathway_versions')
      .stream(primaryKey: ['version_id'])
      .order('pathway_id')
      .map((rows) => diagnosticBundlesFromRows(rows));

  @override
  Future<void> createPathway({
    required DiagnosticPathwayDefinition definition,
    required String adminUid,
  }) async {
    await client.schema('ientier').from('diagnostic_pathway_versions').insert({
      'pathway_id': definition.id,
      'version_number': 1,
      'status': 'draft',
      'definition': definition.toMap(),
      'created_by': adminUid,
      'updated_by': adminUid,
    });
  }

  @override
  Future<void> createDraftFromPublished({
    required DiagnosticPathwayBundle bundle,
    required String adminUid,
  }) async {
    final published = bundle.published;
    if (published == null || bundle.draft != null) {
      throw StateError('Aucune version publiée à dupliquer.');
    }
    await client.schema('ientier').from('diagnostic_pathway_versions').insert({
      'pathway_id': bundle.pathwayId,
      'version_number': bundle.nextVersionNumber,
      'status': 'draft',
      'definition': published.definition.toMap(),
      'created_by': adminUid,
      'updated_by': adminUid,
    });
  }

  @override
  Future<void> saveDraft({
    required DiagnosticPathwayVersion draft,
    required DiagnosticPathwayDefinition definition,
    required String adminUid,
  }) async {
    if (draft.status != DiagnosticVersionStatus.draft) {
      throw StateError('Seul un brouillon peut être modifié.');
    }
    await client
        .schema('ientier')
        .from('diagnostic_pathway_versions')
        .update({'definition': definition.toMap(), 'updated_by': adminUid})
        .eq('version_id', draft.id)
        .eq('status', 'draft');
  }

  @override
  Future<void> publishDraft({
    required DiagnosticPathwayVersion draft,
    required String adminUid,
    required String changeNote,
  }) async {
    await client
        .schema('ientier')
        .rpc(
          'publish_diagnostic_pathway',
          params: {
            'p_version_id': draft.id,
            'p_admin_id': adminUid,
            'p_change_note': changeNote.trim(),
          },
        );
  }

  @override
  Future<void> deleteDraft(DiagnosticPathwayVersion draft) async {
    if (draft.status != DiagnosticVersionStatus.draft) return;
    await client
        .schema('ientier')
        .from('diagnostic_pathway_versions')
        .delete()
        .eq('version_id', draft.id)
        .eq('status', 'draft');
  }
}

List<DiagnosticPathwayBundle> diagnosticBundlesFromRows(
  List<Map<String, dynamic>> rows,
) {
  final grouped = <String, List<DiagnosticPathwayVersion>>{};
  for (final row in rows) {
    final version = DiagnosticPathwayVersion.fromRow(row);
    grouped.putIfAbsent(version.pathwayId, () => []).add(version);
  }
  final bundles = grouped.entries.map((entry) {
    DiagnosticPathwayVersion? draft;
    DiagnosticPathwayVersion? published;
    final archives = <DiagnosticPathwayVersion>[];
    for (final version in entry.value) {
      switch (version.status) {
        case DiagnosticVersionStatus.draft:
          draft = version;
        case DiagnosticVersionStatus.published:
          published = version;
        case DiagnosticVersionStatus.archived:
          archives.add(version);
      }
    }
    archives.sort((a, b) => b.versionNumber.compareTo(a.versionNumber));
    return DiagnosticPathwayBundle(
      pathwayId: entry.key,
      draft: draft,
      published: published,
      archives: archives,
    );
  }).toList();
  bundles.sort(
    (a, b) => a.visibleDefinition.title.toLowerCase().compareTo(
      b.visibleDefinition.title.toLowerCase(),
    ),
  );
  return bundles;
}
