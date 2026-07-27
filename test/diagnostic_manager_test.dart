import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i_entier_administration/data/diagnostic_config_repository.dart';
import 'package:i_entier_administration/models/diagnostic_pathway_config.dart';
import 'package:i_entier_administration/screens/diagnostic_manager_screen.dart';
import 'package:i_entier_administration/theme/admin_theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestWidgetsFlutterBinding.instance.platformDispatcher.views.first
      ..physicalSize = const Size(1440, 1000)
      ..devicePixelRatio = 1;
  });

  tearDown(() {
    TestWidgetsFlutterBinding.instance.platformDispatcher.views.first
      ..resetPhysicalSize()
      ..resetDevicePixelRatio();
  });

  testWidgets('ajoute une question dans l’arbre et enregistre le brouillon', (
    tester,
  ) async {
    final repository = _FakeDiagnosticRepository(_draftBundle());

    await tester.pumpWidget(_manager(repository));
    await tester.pumpAndSettle();

    expect(find.text('Gestionnaire du diagnostic assisté'), findsOneWidget);
    expect(find.text('Questions et embranchements (0)'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Ajouter').first);
    await tester.pumpAndSettle();

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(1), 'Localisation');
    await tester.enterText(
      find.byKey(const ValueKey('question-prompt-field')),
      'Où ressentez-vous la douleur ?',
    );
    await tester.tap(find.byKey(const ValueKey('confirm-question')));
    await tester.pumpAndSettle();

    expect(find.text('Localisation'), findsOneWidget);
    expect(find.text('Où ressentez-vous la douleur ?'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('save-draft')));
    await tester.pumpAndSettle();

    expect(repository.saved, isNotNull);
    expect(repository.saved!.questions, hasLength(1));
    expect(repository.saved!.questions.single.options, hasLength(2));
  });

  testWidgets('bloque la publication d’un parcours incomplet', (tester) async {
    final repository = _FakeDiagnosticRepository(_draftBundle());

    await tester.pumpWidget(_manager(repository));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('publish-draft')));
    await tester.pumpAndSettle();

    expect(find.text('Parcours à corriger'), findsOneWidget);
    expect(find.text('Ajoutez au moins une question.'), findsOneWidget);
    expect(repository.published, isFalse);
  });

  testWidgets('reste utilisable sur un écran mobile', (tester) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    final repository = _FakeDiagnosticRepository(_draftBundle());

    await tester.pumpWidget(_manager(repository));
    await tester.pumpAndSettle();

    expect(find.text('Gestionnaire du diagnostic assisté'), findsOneWidget);
    expect(find.text('Douleur de test'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  test('regroupe le brouillon, la publication et l’historique', () {
    final definition = DiagnosticPathwayDefinition.empty('douleur_test');
    final bundles = diagnosticBundlesFromRows([
      _row('archive-1', 1, 'archived', definition),
      _row('published-2', 2, 'published', definition),
      _row('draft-3', 3, 'draft', definition),
    ]);

    expect(bundles, hasLength(1));
    expect(bundles.single.draft?.versionNumber, 3);
    expect(bundles.single.published?.versionNumber, 2);
    expect(bundles.single.archives.single.versionNumber, 1);
    expect(bundles.single.nextVersionNumber, 4);
  });
}

Widget _manager(_FakeDiagnosticRepository repository) => MaterialApp(
  theme: buildAdminTheme(),
  home: Scaffold(
    body: DiagnosticManagerScreen(
      user: User(
        id: 'admin-1',
        appMetadata: const {},
        userMetadata: const {'full_name': 'Administration i-ENTIER'},
        aud: 'authenticated',
        email: 'admin@ientier.ht',
        createdAt: DateTime(2026, 7, 20).toIso8601String(),
      ),
      repository: repository,
    ),
  ),
);

DiagnosticPathwayBundle _draftBundle() {
  final definition = DiagnosticPathwayDefinition.empty(
    'douleur_test',
  ).copyWith(title: 'Douleur de test', subtitle: 'Parcours de vérification');
  return DiagnosticPathwayBundle(
    pathwayId: definition.id,
    draft: DiagnosticPathwayVersion(
      id: 'draft-1',
      pathwayId: definition.id,
      versionNumber: 1,
      status: DiagnosticVersionStatus.draft,
      definition: definition,
    ),
    published: null,
    archives: const [],
  );
}

Map<String, dynamic> _row(
  String id,
  int version,
  String status,
  DiagnosticPathwayDefinition definition,
) => {
  'version_id': id,
  'pathway_id': definition.id,
  'version_number': version,
  'status': status,
  'definition': definition.toMap(),
};

class _FakeDiagnosticRepository implements DiagnosticConfigRepository {
  DiagnosticPathwayBundle bundle;
  DiagnosticPathwayDefinition? saved;
  bool published = false;

  _FakeDiagnosticRepository(this.bundle);

  @override
  Stream<List<DiagnosticPathwayBundle>> watchPathways() =>
      Stream.value([bundle]);

  @override
  Future<void> createPathway({
    required DiagnosticPathwayDefinition definition,
    required String adminUid,
  }) async {}

  @override
  Future<void> createDraftFromPublished({
    required DiagnosticPathwayBundle bundle,
    required String adminUid,
  }) async {}

  @override
  Future<void> deleteDraft(DiagnosticPathwayVersion draft) async {}

  @override
  Future<void> publishDraft({
    required DiagnosticPathwayVersion draft,
    required String adminUid,
    required String changeNote,
  }) async {
    published = true;
  }

  @override
  Future<void> saveDraft({
    required DiagnosticPathwayVersion draft,
    required DiagnosticPathwayDefinition definition,
    required String adminUid,
  }) async {
    saved = definition;
  }
}
