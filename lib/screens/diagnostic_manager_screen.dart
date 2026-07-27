import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/diagnostic_config_repository.dart';
import '../models/diagnostic_pathway_config.dart';
import '../theme/admin_theme.dart';

class DiagnosticManagerScreen extends StatefulWidget {
  final User user;
  final DiagnosticConfigRepository repository;

  const DiagnosticManagerScreen({
    super.key,
    required this.user,
    required this.repository,
  });

  @override
  State<DiagnosticManagerScreen> createState() =>
      _DiagnosticManagerScreenState();
}

class _DiagnosticManagerScreenState extends State<DiagnosticManagerScreen> {
  late Stream<List<DiagnosticPathwayBundle>> _pathways;
  String? _selectedId;

  @override
  void initState() {
    super.initState();
    _pathways = widget.repository.watchPathways();
  }

  @override
  void didUpdateWidget(covariant DiagnosticManagerScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.repository != widget.repository) {
      _pathways = widget.repository.watchPathways();
    }
  }

  Future<void> _createPathway() async {
    final definition = await showDialog<DiagnosticPathwayDefinition>(
      context: context,
      builder: (_) => const _PathwayDialog(),
    );
    if (definition == null) return;
    try {
      await widget.repository.createPathway(
        definition: definition,
        adminUid: widget.user.id,
      );
      if (!mounted) return;
      setState(() => _selectedId = definition.id);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nouveau malaise ajouté en brouillon.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Ce malaise existe déjà ou n’a pas pu être enregistré.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(
    BuildContext context,
  ) => StreamBuilder<List<DiagnosticPathwayBundle>>(
    stream: _pathways,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting &&
          !snapshot.hasData) {
        return const Center(
          child: CircularProgressIndicator(color: AdminColors.primary),
        );
      }
      if (snapshot.hasError) {
        return const _ManagerFeedback(
          icon: Icons.cloud_off_outlined,
          title: 'Gestionnaire indisponible',
          message:
              'Vérifiez la migration du catalogue et les droits administrateur.',
        );
      }
      final bundles = snapshot.data ?? const <DiagnosticPathwayBundle>[];
      final selectedId =
          _selectedId ?? (bundles.isEmpty ? null : bundles.first.pathwayId);
      DiagnosticPathwayBundle? selected;
      for (final bundle in bundles) {
        if (bundle.pathwayId == selectedId) selected = bundle;
      }
      return LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 980;
          final catalog = _PathwayCatalog(
            bundles: bundles,
            selectedId: selectedId,
            onSelected: (id) => setState(() => _selectedId = id),
            onAdd: _createPathway,
          );
          final editor = selected == null
              ? _ManagerFeedback(
                  icon: Icons.account_tree_outlined,
                  title: 'Créez le premier parcours',
                  message:
                      'Ajoutez un type de malaise, puis construisez ses questions et ses embranchements.',
                  action: FilledButton.icon(
                    onPressed: _createPathway,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Ajouter un malaise'),
                  ),
                )
              : DiagnosticPathwayEditor(
                  key: ValueKey(
                    '${selected.pathwayId}-${selected.draft?.id ?? selected.published?.id}',
                  ),
                  bundle: selected,
                  user: widget.user,
                  repository: widget.repository,
                );
          return Padding(
            padding: EdgeInsets.fromLTRB(
              wide ? 24 : 16,
              24,
              wide ? 24 : 16,
              30,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ManagerHeader(onAdd: _createPathway),
                const SizedBox(height: 20),
                Expanded(
                  child: wide
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SizedBox(width: 280, child: catalog),
                            const SizedBox(width: 16),
                            Expanded(child: editor),
                          ],
                        )
                      : ListView(
                          children: [
                            SizedBox(height: 220, child: catalog),
                            const SizedBox(height: 14),
                            SizedBox(
                              height: constraints.maxHeight < 760
                                  ? 540
                                  : constraints.maxHeight - 220,
                              child: editor,
                            ),
                          ],
                        ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

class _ManagerHeader extends StatelessWidget {
  final VoidCallback onAdd;
  const _ManagerHeader({required this.onAdd});

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Gestionnaire du diagnostic assisté',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 5),
            const Text(
              'Construisez, testez et publiez les parcours visibles par les patients.',
              style: TextStyle(color: AdminColors.muted, fontSize: 15),
            ),
          ],
        ),
      ),
      FilledButton.icon(
        key: const ValueKey('add-pathway'),
        onPressed: onAdd,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nouveau malaise'),
      ),
    ],
  );
}

class _PathwayCatalog extends StatelessWidget {
  final List<DiagnosticPathwayBundle> bundles;
  final String? selectedId;
  final ValueChanged<String> onSelected;
  final VoidCallback onAdd;

  const _PathwayCatalog({
    required this.bundles,
    required this.selectedId,
    required this.onSelected,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) => AdminPanel(
    padding: const EdgeInsets.all(12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(6, 4, 6, 10),
          child: Row(
            children: [
              Icon(
                Icons.medical_information_outlined,
                color: AdminColors.primary,
                size: 20,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Types de malaise',
                  style: TextStyle(
                    color: AdminColors.ink,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: bundles.isEmpty
              ? Center(
                  child: TextButton.icon(
                    onPressed: onAdd,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Créer le catalogue'),
                  ),
                )
              : ListView.separated(
                  itemCount: bundles.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 7),
                  itemBuilder: (context, index) {
                    final bundle = bundles[index];
                    final definition = bundle.visibleDefinition;
                    final selected = selectedId == bundle.pathwayId;
                    return Material(
                      color: selected
                          ? AdminColors.primarySoft
                          : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(13),
                      child: InkWell(
                        key: ValueKey('pathway-row-${bundle.pathwayId}'),
                        onTap: () => onSelected(bundle.pathwayId),
                        borderRadius: BorderRadius.circular(13),
                        child: Padding(
                          padding: const EdgeInsets.all(11),
                          child: Row(
                            children: [
                              _ConfigIcon(
                                iconKey: definition.iconKey,
                                colorHex: definition.colorHex,
                                size: 39,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      definition.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: selected
                                            ? AdminColors.primaryDark
                                            : AdminColors.ink,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      bundle.draft != null
                                          ? 'Brouillon v${bundle.draft!.versionNumber}'
                                          : 'Publié v${bundle.published?.versionNumber ?? 0}',
                                      style: TextStyle(
                                        color: bundle.draft != null
                                            ? AdminColors.warning
                                            : AdminColors.success,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (selected)
                                const Icon(
                                  Icons.chevron_right_rounded,
                                  color: AdminColors.primary,
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    ),
  );
}

class DiagnosticPathwayEditor extends StatefulWidget {
  final DiagnosticPathwayBundle bundle;
  final User user;
  final DiagnosticConfigRepository repository;

  const DiagnosticPathwayEditor({
    super.key,
    required this.bundle,
    required this.user,
    required this.repository,
  });

  @override
  State<DiagnosticPathwayEditor> createState() =>
      _DiagnosticPathwayEditorState();
}

class _DiagnosticPathwayEditorState extends State<DiagnosticPathwayEditor> {
  late DiagnosticPathwayDefinition _definition =
      widget.bundle.visibleDefinition;
  bool _dirty = false;
  bool _busy = false;

  bool get _editable => widget.bundle.draft != null;

  void _replace(DiagnosticPathwayDefinition definition) {
    if (!_editable) return;
    setState(() {
      _definition = definition;
      _dirty = true;
    });
  }

  Future<void> _createDraft() async {
    setState(() => _busy = true);
    try {
      await widget.repository.createDraftFromPublished(
        bundle: widget.bundle,
        adminUid: widget.user.id,
      );
    } catch (_) {
      if (mounted) _showError('Le brouillon n’a pas pu être créé.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _save({bool notify = true}) async {
    final draft = widget.bundle.draft;
    if (draft == null) return false;
    setState(() => _busy = true);
    try {
      await widget.repository.saveDraft(
        draft: draft,
        definition: _definition,
        adminUid: widget.user.id,
      );
      if (!mounted) return true;
      setState(() => _dirty = false);
      if (notify) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Brouillon enregistré.')));
      }
      return true;
    } catch (_) {
      if (mounted) _showError('Le brouillon n’a pas pu être enregistré.');
      return false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _publish() async {
    final issues = _definition.validate();
    if (issues.isNotEmpty) {
      await showDialog<void>(
        context: context,
        builder: (_) => _ValidationDialog(issues: issues),
      );
      return;
    }
    if (_dirty && !await _save(notify: false)) return;
    if (!mounted) return;
    final note = await showDialog<String>(
      context: context,
      builder: (_) => const _PublishDialog(),
    );
    if (note == null) return;
    final draft = widget.bundle.draft;
    if (draft == null) return;
    setState(() => _busy = true);
    try {
      await widget.repository.publishDraft(
        draft: draft,
        adminUid: widget.user.id,
        changeNote: note,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Parcours publié. Il est maintenant disponible pour les patients.',
          ),
        ),
      );
    } catch (_) {
      if (mounted) _showError('La publication a échoué.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteDraft() async {
    final draft = widget.bundle.draft;
    if (draft == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.delete_outline, color: AdminColors.danger),
        title: const Text('Supprimer ce brouillon ?'),
        content: const Text(
          'La version publiée restera active. Cette action ne peut pas être annulée.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AdminColors.danger),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _busy = true);
    try {
      await widget.repository.deleteDraft(draft);
    } catch (_) {
      if (mounted) _showError('Le brouillon n’a pas pu être supprimé.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _editPathway() async {
    final updated = await showDialog<DiagnosticPathwayDefinition>(
      context: context,
      builder: (_) => _PathwayDialog(initial: _definition),
    );
    if (updated != null) _replace(updated);
  }

  Future<void> _editQuestion(int? index) async {
    final initial = index == null ? null : _definition.questions[index];
    final updated = await showDialog<DiagnosticQuestionDefinition>(
      context: context,
      builder: (_) => _QuestionDialog(
        initial: initial,
        suggestedId: nextAvailableId(
          '${_definition.id}_question',
          _definition.questions.map((item) => item.id),
        ),
      ),
    );
    if (updated == null) return;
    final questions = List<DiagnosticQuestionDefinition>.of(
      _definition.questions,
    );
    if (index == null) {
      questions.add(updated);
    } else {
      questions[index] = updated;
    }
    _replace(_definition.copyWith(questions: questions));
  }

  Future<void> _editOption(int questionIndex, int? optionIndex) async {
    final question = _definition.questions[questionIndex];
    final initial = optionIndex == null ? null : question.options[optionIndex];
    final updated = await showDialog<DiagnosticOptionDefinition>(
      context: context,
      builder: (_) => _OptionDialog(
        initial: initial,
        suggestedId: nextAvailableId(
          'choice',
          question.options.map((item) => item.id),
        ),
        questions: _definition.questions,
        currentQuestionId: question.id,
      ),
    );
    if (updated == null) return;
    final options = List<DiagnosticOptionDefinition>.of(question.options);
    if (optionIndex == null) {
      options.add(updated);
    } else {
      options[optionIndex] = updated;
    }
    final questions = List<DiagnosticQuestionDefinition>.of(
      _definition.questions,
    )..[questionIndex] = question.copyWith(options: options);
    _replace(_definition.copyWith(questions: questions));
  }

  Future<void> _editPossibility(int? index) async {
    final initial = index == null ? null : _definition.possibilities[index];
    final updated = await showDialog<DiagnosticPossibilityDefinition>(
      context: context,
      builder: (_) => _PossibilityDialog(initial: initial),
    );
    if (updated == null) return;
    final items = List<DiagnosticPossibilityDefinition>.of(
      _definition.possibilities,
    );
    if (index == null) {
      items.add(updated);
    } else {
      items[index] = updated;
    }
    _replace(_definition.copyWith(possibilities: items));
  }

  Future<void> _editAdvice({required bool pharmacy, int? index}) async {
    final source = pharmacy ? _definition.pharmacyAdvice : _definition.selfCare;
    final updated = await showDialog<String>(
      context: context,
      builder: (_) => _TextItemDialog(
        title: pharmacy ? 'Conseil pharmacie' : 'Conseil d’attente',
        initial: index == null ? '' : source[index],
      ),
    );
    if (updated == null) return;
    final items = List<String>.of(source);
    if (index == null) {
      items.add(updated);
    } else {
      items[index] = updated;
    }
    _replace(
      pharmacy
          ? _definition.copyWith(pharmacyAdvice: items)
          : _definition.copyWith(selfCare: items),
    );
  }

  void _removeQuestion(int index) {
    final questions = List<DiagnosticQuestionDefinition>.of(
      _definition.questions,
    );
    final removedId = questions.removeAt(index).id;
    final cleaned = questions
        .map(
          (question) => question.copyWith(
            options: question.options
                .map(
                  (option) => option.nextQuestionId == removedId
                      ? option.copyWith(clearNextQuestion: true)
                      : option,
                )
                .toList(),
          ),
        )
        .toList();
    _replace(_definition.copyWith(questions: cleaned));
  }

  void _removeOption(int questionIndex, int optionIndex) {
    final question = _definition.questions[questionIndex];
    final options = List<DiagnosticOptionDefinition>.of(question.options)
      ..removeAt(optionIndex);
    final questions = List<DiagnosticQuestionDefinition>.of(
      _definition.questions,
    )..[questionIndex] = question.copyWith(options: options);
    _replace(_definition.copyWith(questions: questions));
  }

  void _removePossibility(int index) {
    final items = List<DiagnosticPossibilityDefinition>.of(
      _definition.possibilities,
    )..removeAt(index);
    _replace(_definition.copyWith(possibilities: items));
  }

  void _removeAdvice({required bool pharmacy, required int index}) {
    final items = List<String>.of(
      pharmacy ? _definition.pharmacyAdvice : _definition.selfCare,
    )..removeAt(index);
    _replace(
      pharmacy
          ? _definition.copyWith(pharmacyAdvice: items)
          : _definition.copyWith(selfCare: items),
    );
  }

  void _moveQuestion(int index, int delta) {
    final target = index + delta;
    if (target < 0 || target >= _definition.questions.length) return;
    final questions = List<DiagnosticQuestionDefinition>.of(
      _definition.questions,
    );
    final item = questions.removeAt(index);
    questions.insert(target, item);
    _replace(_definition.copyWith(questions: questions));
  }

  void _moveOption(int questionIndex, int optionIndex, int delta) {
    final question = _definition.questions[questionIndex];
    final target = optionIndex + delta;
    if (target < 0 || target >= question.options.length) return;
    final options = List<DiagnosticOptionDefinition>.of(question.options);
    final item = options.removeAt(optionIndex);
    options.insert(target, item);
    final questions = List<DiagnosticQuestionDefinition>.of(
      _definition.questions,
    )..[questionIndex] = question.copyWith(options: options);
    _replace(_definition.copyWith(questions: questions));
  }

  @override
  Widget build(BuildContext context) => AdminPanel(
    padding: EdgeInsets.zero,
    child: Column(
      children: [
        _EditorToolbar(
          definition: _definition,
          bundle: widget.bundle,
          dirty: _dirty,
          busy: _busy,
          onCreateDraft: _createDraft,
          onSave: _save,
          onPublish: _publish,
          onDeleteDraft: _deleteDraft,
        ),
        const Divider(height: 1, color: AdminColors.border),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(18),
            children: [
              _TreeNode(
                depth: 0,
                icon: configIcon(_definition.iconKey),
                iconColor: colorFromHex(_definition.colorHex),
                title: _definition.title,
                subtitle:
                    '${_definition.id} · ${_definition.questions.length} questions',
                editable: _editable,
                onEdit: _editPathway,
              ),
              _TreeSectionHeader(
                title: 'Questions et embranchements',
                count: _definition.questions.length,
                icon: Icons.account_tree_outlined,
                editable: _editable,
                onAdd: () => _editQuestion(null),
              ),
              for (
                var questionIndex = 0;
                questionIndex < _definition.questions.length;
                questionIndex++
              ) ...[
                Builder(
                  builder: (context) {
                    final question = _definition.questions[questionIndex];
                    return _TreeNode(
                      key: ValueKey('question-node-${question.id}'),
                      depth: 1,
                      icon: configIcon(question.iconKey),
                      title: question.title,
                      subtitle: question.prompt,
                      editable: _editable,
                      onEdit: () => _editQuestion(questionIndex),
                      onDelete: () => _removeQuestion(questionIndex),
                      onMoveUp: questionIndex == 0
                          ? null
                          : () => _moveQuestion(questionIndex, -1),
                      onMoveDown:
                          questionIndex == _definition.questions.length - 1
                          ? null
                          : () => _moveQuestion(questionIndex, 1),
                      trailing: TextButton.icon(
                        onPressed: _editable
                            ? () => _editOption(questionIndex, null)
                            : null,
                        icon: const Icon(Icons.add_rounded, size: 17),
                        label: const Text('Choix'),
                      ),
                    );
                  },
                ),
                for (
                  var optionIndex = 0;
                  optionIndex <
                      _definition.questions[questionIndex].options.length;
                  optionIndex++
                )
                  Builder(
                    builder: (context) {
                      final option = _definition
                          .questions[questionIndex]
                          .options[optionIndex];
                      return _TreeNode(
                        key: ValueKey(
                          'option-node-${_definition.questions[questionIndex].id}-${option.id}',
                        ),
                        depth: 2,
                        icon: option.urgency == 'emergency'
                            ? Icons.emergency_outlined
                            : configIcon(option.iconKey),
                        iconColor: urgencyColor(option.urgency),
                        title: option.label,
                        subtitle: [
                          urgencyLabel(option.urgency),
                          if (option.tags.isNotEmpty)
                            'Tags : ${option.tags.join(', ')}',
                          if (option.nextQuestionId != null &&
                              option.nextQuestionId!.isNotEmpty)
                            '→ ${option.nextQuestionId}',
                        ].join(' · '),
                        editable: _editable,
                        onEdit: () => _editOption(questionIndex, optionIndex),
                        onDelete: () =>
                            _removeOption(questionIndex, optionIndex),
                        onMoveUp: optionIndex == 0
                            ? null
                            : () => _moveOption(questionIndex, optionIndex, -1),
                        onMoveDown:
                            optionIndex ==
                                _definition
                                        .questions[questionIndex]
                                        .options
                                        .length -
                                    1
                            ? null
                            : () => _moveOption(questionIndex, optionIndex, 1),
                      );
                    },
                  ),
              ],
              _TreeSectionHeader(
                title: 'Résultats possibles',
                count: _definition.possibilities.length,
                icon: Icons.analytics_outlined,
                editable: _editable,
                onAdd: () => _editPossibility(null),
              ),
              for (
                var index = 0;
                index < _definition.possibilities.length;
                index++
              )
                _TreeNode(
                  depth: 1,
                  icon: Icons.insights_outlined,
                  title: _definition.possibilities[index].title,
                  subtitle:
                      '${_definition.possibilities[index].tagWeights.length} critères pondérés · base ${_definition.possibilities[index].baseScore}',
                  editable: _editable,
                  onEdit: () => _editPossibility(index),
                  onDelete: () => _removePossibility(index),
                ),
              _TreeSectionHeader(
                title: 'Conseils en attendant',
                count: _definition.selfCare.length,
                icon: Icons.self_improvement_outlined,
                editable: _editable,
                onAdd: () => _editAdvice(pharmacy: false),
              ),
              for (var index = 0; index < _definition.selfCare.length; index++)
                _TreeNode(
                  depth: 1,
                  icon: Icons.tips_and_updates_outlined,
                  title: _definition.selfCare[index],
                  editable: _editable,
                  onEdit: () => _editAdvice(pharmacy: false, index: index),
                  onDelete: () => _removeAdvice(pharmacy: false, index: index),
                ),
              _TreeSectionHeader(
                title: 'Conseils de pharmacie',
                count: _definition.pharmacyAdvice.length,
                icon: Icons.local_pharmacy_outlined,
                editable: _editable,
                onAdd: () => _editAdvice(pharmacy: true),
              ),
              for (
                var index = 0;
                index < _definition.pharmacyAdvice.length;
                index++
              )
                _TreeNode(
                  depth: 1,
                  icon: Icons.medication_outlined,
                  title: _definition.pharmacyAdvice[index],
                  editable: _editable,
                  onEdit: () => _editAdvice(pharmacy: true, index: index),
                  onDelete: () => _removeAdvice(pharmacy: true, index: index),
                ),
              if (widget.bundle.archives.isNotEmpty) ...[
                _TreeSectionHeader(
                  title: 'Historique',
                  count: widget.bundle.archives.length,
                  icon: Icons.history_outlined,
                  editable: false,
                ),
                for (final version in widget.bundle.archives)
                  _TreeNode(
                    depth: 1,
                    icon: Icons.archive_outlined,
                    title: 'Version ${version.versionNumber}',
                    subtitle: version.changeNote.isEmpty
                        ? 'Version archivée'
                        : version.changeNote,
                    editable: false,
                  ),
              ],
            ],
          ),
        ),
      ],
    ),
  );
}

class _EditorToolbar extends StatelessWidget {
  final DiagnosticPathwayDefinition definition;
  final DiagnosticPathwayBundle bundle;
  final bool dirty;
  final bool busy;
  final VoidCallback onCreateDraft;
  final Future<bool> Function({bool notify}) onSave;
  final VoidCallback onPublish;
  final VoidCallback onDeleteDraft;

  const _EditorToolbar({
    required this.definition,
    required this.bundle,
    required this.dirty,
    required this.busy,
    required this.onCreateDraft,
    required this.onSave,
    required this.onPublish,
    required this.onDeleteDraft,
  });

  Widget _identity() => Row(
    children: [
      _ConfigIcon(
        iconKey: definition.iconKey,
        colorHex: definition.colorHex,
        size: 45,
      ),
      const SizedBox(width: 11),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              definition.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AdminColors.ink,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 3),
            Wrap(
              spacing: 7,
              runSpacing: 5,
              children: [
                _StatusBadge(
                  label: bundle.draft != null
                      ? 'Brouillon v${bundle.draft!.versionNumber}'
                      : 'Publié v${bundle.published?.versionNumber ?? 0}',
                  color: bundle.draft != null
                      ? AdminColors.warning
                      : AdminColors.success,
                ),
                if (dirty)
                  const _StatusBadge(
                    label: 'Modifications non enregistrées',
                    color: AdminColors.danger,
                  ),
              ],
            ),
          ],
        ),
      ),
    ],
  );

  List<Widget> _actions() {
    if (busy) {
      return const [
        Padding(
          padding: EdgeInsets.all(13),
          child: SizedBox.square(
            dimension: 22,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
        ),
      ];
    }
    if (bundle.draft == null) {
      return [
        FilledButton.icon(
          key: const ValueKey('create-draft'),
          onPressed: bundle.published == null ? null : onCreateDraft,
          icon: const Icon(Icons.edit_note_rounded),
          label: const Text('Créer un brouillon'),
        ),
      ];
    }
    return [
      IconButton(
        tooltip: 'Supprimer le brouillon',
        onPressed: onDeleteDraft,
        icon: const Icon(Icons.delete_outline, color: AdminColors.danger),
      ),
      OutlinedButton.icon(
        key: const ValueKey('save-draft'),
        onPressed: dirty ? () => onSave() : null,
        icon: const Icon(Icons.save_outlined),
        label: const Text('Enregistrer'),
      ),
      FilledButton.icon(
        key: const ValueKey('publish-draft'),
        onPressed: onPublish,
        style: FilledButton.styleFrom(backgroundColor: AdminColors.success),
        icon: const Icon(Icons.publish_rounded),
        label: const Text('Publier'),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final compact = constraints.maxWidth < 680;
      final actions = Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.end,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: _actions(),
      );
      return Padding(
        padding: const EdgeInsets.fromLTRB(18, 15, 14, 15),
        child: compact
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [_identity(), const SizedBox(height: 11), actions],
              )
            : Row(
                children: [
                  Expanded(child: _identity()),
                  const SizedBox(width: 14),
                  actions,
                ],
              ),
      );
    },
  );
}

class _TreeSectionHeader extends StatelessWidget {
  final String title;
  final int count;
  final IconData icon;
  final bool editable;
  final VoidCallback? onAdd;

  const _TreeSectionHeader({
    required this.title,
    required this.count,
    required this.icon,
    required this.editable,
    this.onAdd,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(18, 20, 0, 8),
    child: Row(
      children: [
        Container(width: 2, height: 24, color: AdminColors.border),
        const SizedBox(width: 12),
        Icon(icon, size: 20, color: AdminColors.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '$title ($count)',
            style: const TextStyle(
              color: AdminColors.ink,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        if (onAdd != null)
          TextButton.icon(
            onPressed: editable ? onAdd : null,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Ajouter'),
          ),
      ],
    ),
  );
}

class _TreeNode extends StatelessWidget {
  final int depth;
  final IconData icon;
  final Color? iconColor;
  final String title;
  final String? subtitle;
  final bool editable;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;
  final Widget? trailing;

  const _TreeNode({
    super.key,
    required this.depth,
    required this.icon,
    required this.title,
    required this.editable,
    this.iconColor,
    this.subtitle,
    this.onEdit,
    this.onDelete,
    this.onMoveUp,
    this.onMoveDown,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(left: depth * 25.0, bottom: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (depth > 0)
          Container(
            width: 15,
            margin: const EdgeInsets.only(right: 8),
            decoration: const BoxDecoration(
              border: Border(
                left: BorderSide(color: AdminColors.border, width: 2),
                bottom: BorderSide(color: AdminColors.border, width: 2),
              ),
            ),
          ),
        Expanded(
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 7, 10),
            decoration: BoxDecoration(
              color: depth == 0
                  ? AdminColors.primarySoft
                  : const Color(0xFFF8FAFC),
              border: Border.all(color: AdminColors.border),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Row(
              children: [
                Icon(icon, size: 21, color: iconColor ?? AdminColors.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: AdminColors.ink,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (subtitle != null && subtitle!.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          subtitle!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AdminColors.muted,
                            fontSize: 11.5,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                ?trailing,
                if (editable && onMoveUp != null)
                  IconButton(
                    tooltip: 'Monter',
                    onPressed: onMoveUp,
                    icon: const Icon(Icons.arrow_upward_rounded, size: 18),
                  ),
                if (editable && onMoveDown != null)
                  IconButton(
                    tooltip: 'Descendre',
                    onPressed: onMoveDown,
                    icon: const Icon(Icons.arrow_downward_rounded, size: 18),
                  ),
                if (editable && onEdit != null)
                  IconButton(
                    tooltip: 'Modifier',
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined, size: 18),
                  ),
                if (editable && onDelete != null)
                  IconButton(
                    tooltip: 'Supprimer',
                    onPressed: onDelete,
                    icon: const Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: AdminColors.danger,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .1),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      label,
      style: TextStyle(
        color: color,
        fontSize: 10.5,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}

class _PathwayDialog extends StatefulWidget {
  final DiagnosticPathwayDefinition? initial;
  const _PathwayDialog({this.initial});

  @override
  State<_PathwayDialog> createState() => _PathwayDialogState();
}

class _PathwayDialogState extends State<_PathwayDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _id = TextEditingController(
    text: widget.initial?.id ?? '',
  );
  late final TextEditingController _title = TextEditingController(
    text: widget.initial?.title ?? '',
  );
  late final TextEditingController _subtitle = TextEditingController(
    text: widget.initial?.subtitle ?? '',
  );
  late String _icon = widget.initial?.iconKey ?? 'info';
  late String _color = widget.initial?.colorHex ?? '#2457D6';

  @override
  void dispose() {
    _id.dispose();
    _title.dispose();
    _subtitle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.initial == null ? 'Nouveau malaise' : 'Présentation'),
    content: SizedBox(
      width: 560,
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                key: const ValueKey('pathway-id-field'),
                controller: _id,
                enabled: widget.initial == null,
                decoration: const InputDecoration(
                  labelText: 'Identifiant technique',
                  hintText: 'ex. douleur_dos',
                ),
                validator: (value) =>
                    !RegExp(
                      r'^[a-z0-9][a-z0-9_-]{1,79}$',
                    ).hasMatch(value?.trim() ?? '')
                    ? 'Utilisez des minuscules, chiffres, tirets ou _.'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _title,
                decoration: const InputDecoration(labelText: 'Titre affiché'),
                validator: _required,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _subtitle,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Description courte',
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _icon,
                decoration: const InputDecoration(labelText: 'Icône'),
                items: [
                  for (final entry in configIcons.entries)
                    DropdownMenuItem(
                      value: entry.key,
                      child: Row(
                        children: [
                          Icon(entry.value, size: 20),
                          const SizedBox(width: 9),
                          Text(iconLabel(entry.key)),
                        ],
                      ),
                    ),
                ],
                onChanged: (value) => setState(() => _icon = value ?? 'info'),
              ),
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: 9,
                  children: [
                    for (final color in configColors)
                      InkWell(
                        onTap: () => setState(() => _color = color),
                        borderRadius: BorderRadius.circular(30),
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: colorFromHex(color),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _color == color
                                  ? AdminColors.ink
                                  : Colors.white,
                              width: 3,
                            ),
                          ),
                          child: _color == color
                              ? const Icon(
                                  Icons.check_rounded,
                                  color: Colors.white,
                                  size: 19,
                                )
                              : null,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Annuler'),
      ),
      FilledButton(
        key: const ValueKey('confirm-pathway'),
        onPressed: () {
          if (_formKey.currentState?.validate() != true) return;
          final base =
              widget.initial ??
              DiagnosticPathwayDefinition.empty(_id.text.trim());
          Navigator.pop(
            context,
            base.copyWith(
              title: _title.text.trim(),
              subtitle: _subtitle.text.trim(),
              iconKey: _icon,
              colorHex: _color,
            ),
          );
        },
        child: Text(widget.initial == null ? 'Créer' : 'Appliquer'),
      ),
    ],
  );
}

class _QuestionDialog extends StatefulWidget {
  final DiagnosticQuestionDefinition? initial;
  final String suggestedId;
  const _QuestionDialog({required this.initial, required this.suggestedId});

  @override
  State<_QuestionDialog> createState() => _QuestionDialogState();
}

class _QuestionDialogState extends State<_QuestionDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _id = TextEditingController(
    text: widget.initial?.id ?? widget.suggestedId,
  );
  late final TextEditingController _title = TextEditingController(
    text: widget.initial?.title ?? '',
  );
  late final TextEditingController _prompt = TextEditingController(
    text: widget.initial?.prompt ?? '',
  );
  late final TextEditingController _requiredTags = TextEditingController(
    text: widget.initial?.requiredTags.join(', ') ?? '',
  );
  late final TextEditingController _excludedTags = TextEditingController(
    text: widget.initial?.excludedTags.join(', ') ?? '',
  );
  late String _icon = widget.initial?.iconKey ?? 'info';

  @override
  void dispose() {
    _id.dispose();
    _title.dispose();
    _prompt.dispose();
    _requiredTags.dispose();
    _excludedTags.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.initial == null ? 'Ajouter une question' : 'Question'),
    content: SizedBox(
      width: 600,
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            children: [
              TextFormField(
                controller: _id,
                enabled: widget.initial == null,
                decoration: const InputDecoration(
                  labelText: 'Identifiant technique',
                ),
                validator: _required,
              ),
              const SizedBox(height: 11),
              TextFormField(
                controller: _title,
                decoration: const InputDecoration(labelText: 'Titre court'),
                validator: _required,
              ),
              const SizedBox(height: 11),
              TextFormField(
                key: const ValueKey('question-prompt-field'),
                controller: _prompt,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Question lue au patient',
                ),
                validator: _required,
              ),
              const SizedBox(height: 11),
              DropdownButtonFormField<String>(
                initialValue: _icon,
                decoration: const InputDecoration(labelText: 'Icône'),
                items: [
                  for (final entry in configIcons.entries)
                    DropdownMenuItem(
                      value: entry.key,
                      child: Text(iconLabel(entry.key)),
                    ),
                ],
                onChanged: (value) => _icon = value ?? 'info',
              ),
              const SizedBox(height: 11),
              TextFormField(
                controller: _requiredTags,
                decoration: const InputDecoration(
                  labelText: 'Afficher si ces tags existent',
                  hintText: 'ex. grossesse, fièvre',
                ),
              ),
              const SizedBox(height: 11),
              TextFormField(
                controller: _excludedTags,
                decoration: const InputDecoration(
                  labelText: 'Masquer si ces tags existent',
                ),
              ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Annuler'),
      ),
      FilledButton(
        key: const ValueKey('confirm-question'),
        onPressed: () {
          if (_formKey.currentState?.validate() != true) return;
          Navigator.pop(
            context,
            DiagnosticQuestionDefinition(
              id: _id.text.trim(),
              title: _title.text.trim(),
              prompt: _prompt.text.trim(),
              iconKey: _icon,
              requiredTags: commaList(_requiredTags.text),
              excludedTags: commaList(_excludedTags.text),
              options:
                  widget.initial?.options ??
                  const [
                    DiagnosticOptionDefinition(
                      id: 'yes',
                      label: 'Oui',
                      iconKey: 'check',
                      tags: [],
                      urgency: 'selfCare',
                      nextQuestionId: null,
                    ),
                    DiagnosticOptionDefinition(
                      id: 'no',
                      label: 'Non',
                      iconKey: 'choice',
                      tags: [],
                      urgency: 'selfCare',
                      nextQuestionId: null,
                    ),
                  ],
            ),
          );
        },
        child: const Text('Appliquer'),
      ),
    ],
  );
}

class _OptionDialog extends StatefulWidget {
  final DiagnosticOptionDefinition? initial;
  final String suggestedId;
  final List<DiagnosticQuestionDefinition> questions;
  final String currentQuestionId;

  const _OptionDialog({
    required this.initial,
    required this.suggestedId,
    required this.questions,
    required this.currentQuestionId,
  });

  @override
  State<_OptionDialog> createState() => _OptionDialogState();
}

class _OptionDialogState extends State<_OptionDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _id = TextEditingController(
    text: widget.initial?.id ?? widget.suggestedId,
  );
  late final TextEditingController _label = TextEditingController(
    text: widget.initial?.label ?? '',
  );
  late final TextEditingController _tags = TextEditingController(
    text: widget.initial?.tags.join(', ') ?? '',
  );
  late String _icon = widget.initial?.iconKey ?? 'choice';
  late String _urgency = widget.initial?.urgency ?? 'selfCare';
  late String? _next = widget.initial?.nextQuestionId;

  @override
  void dispose() {
    _id.dispose();
    _label.dispose();
    _tags.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.initial == null ? 'Ajouter un choix' : 'Modifier le choix',
    ),
    content: SizedBox(
      width: 600,
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            children: [
              TextFormField(
                controller: _id,
                enabled: widget.initial == null,
                decoration: const InputDecoration(
                  labelText: 'Identifiant technique',
                ),
                validator: _required,
              ),
              const SizedBox(height: 11),
              TextFormField(
                key: const ValueKey('option-label-field'),
                controller: _label,
                decoration: const InputDecoration(
                  labelText: 'Choix affiché et lu',
                ),
                validator: _required,
              ),
              const SizedBox(height: 11),
              TextFormField(
                controller: _tags,
                decoration: const InputDecoration(
                  labelText: 'Tags produits',
                  hintText: 'ex. fièvre, douleur_forte',
                ),
              ),
              const SizedBox(height: 11),
              DropdownButtonFormField<String>(
                initialValue: _urgency,
                decoration: const InputDecoration(
                  labelText: 'Niveau d’orientation',
                ),
                items: [
                  for (final urgency in urgencyLabels.entries)
                    DropdownMenuItem(
                      value: urgency.key,
                      child: Text(urgency.value),
                    ),
                ],
                onChanged: (value) =>
                    setState(() => _urgency = value ?? 'selfCare'),
              ),
              const SizedBox(height: 11),
              DropdownButtonFormField<String>(
                initialValue: _next ?? '',
                decoration: const InputDecoration(
                  labelText: 'Question suivante',
                  helperText:
                      'Automatique suit l’ordre de l’arbre. Urgence termine le parcours.',
                ),
                items: [
                  const DropdownMenuItem(value: '', child: Text('Automatique')),
                  for (final question in widget.questions)
                    if (question.id != widget.currentQuestionId)
                      DropdownMenuItem(
                        value: question.id,
                        child: Text(question.title),
                      ),
                ],
                onChanged: (value) => setState(
                  () => _next = value?.isEmpty == true ? null : value,
                ),
              ),
              const SizedBox(height: 11),
              DropdownButtonFormField<String>(
                initialValue: _icon,
                decoration: const InputDecoration(labelText: 'Icône'),
                items: [
                  for (final entry in configIcons.entries)
                    DropdownMenuItem(
                      value: entry.key,
                      child: Text(iconLabel(entry.key)),
                    ),
                ],
                onChanged: (value) => _icon = value ?? 'choice',
              ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Annuler'),
      ),
      FilledButton(
        key: const ValueKey('confirm-option'),
        onPressed: () {
          if (_formKey.currentState?.validate() != true) return;
          Navigator.pop(
            context,
            DiagnosticOptionDefinition(
              id: _id.text.trim(),
              label: _label.text.trim(),
              iconKey: _icon,
              tags: commaList(_tags.text),
              urgency: _urgency,
              nextQuestionId: _next,
            ),
          );
        },
        child: const Text('Appliquer'),
      ),
    ],
  );
}

class _PossibilityDialog extends StatefulWidget {
  final DiagnosticPossibilityDefinition? initial;
  const _PossibilityDialog({required this.initial});

  @override
  State<_PossibilityDialog> createState() => _PossibilityDialogState();
}

class _PossibilityDialogState extends State<_PossibilityDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title = TextEditingController(
    text: widget.initial?.title ?? '',
  );
  late final TextEditingController _explanation = TextEditingController(
    text: widget.initial?.explanation ?? '',
  );
  late final TextEditingController _weights = TextEditingController(
    text:
        widget.initial?.tagWeights.entries
            .map((entry) => '${entry.key}=${entry.value}')
            .join('\n') ??
        '',
  );
  late final TextEditingController _base = TextEditingController(
    text: '${widget.initial?.baseScore ?? 8}',
  );

  @override
  void dispose() {
    _title.dispose();
    _explanation.dispose();
    _weights.dispose();
    _base.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Résultat possible'),
    content: SizedBox(
      width: 620,
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            children: [
              TextFormField(
                key: const ValueKey('possibility-title-field'),
                controller: _title,
                decoration: const InputDecoration(
                  labelText: 'Maladie ou cause possible',
                ),
                validator: _required,
              ),
              const SizedBox(height: 11),
              TextFormField(
                controller: _explanation,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Explication prudente',
                ),
                validator: _required,
              ),
              const SizedBox(height: 11),
              TextFormField(
                controller: _weights,
                minLines: 4,
                maxLines: 8,
                decoration: const InputDecoration(
                  labelText: 'Critères et poids',
                  hintText: 'fièvre=25\ndouleur_forte=40',
                  helperText:
                      'Chaque tag sélectionné ajoute son poids à l’indice de compatibilité.',
                ),
              ),
              const SizedBox(height: 11),
              TextFormField(
                controller: _base,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Indice de base'),
                validator: (value) => int.tryParse(value ?? '') == null
                    ? 'Entrez un nombre.'
                    : null,
              ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Annuler'),
      ),
      FilledButton(
        key: const ValueKey('confirm-possibility'),
        onPressed: () {
          if (_formKey.currentState?.validate() != true) return;
          Navigator.pop(
            context,
            DiagnosticPossibilityDefinition(
              title: _title.text.trim(),
              explanation: _explanation.text.trim(),
              tagWeights: parseWeights(_weights.text),
              baseScore: int.parse(_base.text),
            ),
          );
        },
        child: const Text('Appliquer'),
      ),
    ],
  );
}

class _TextItemDialog extends StatefulWidget {
  final String title;
  final String initial;
  const _TextItemDialog({required this.title, required this.initial});

  @override
  State<_TextItemDialog> createState() => _TextItemDialogState();
}

class _TextItemDialogState extends State<_TextItemDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initial,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: SizedBox(
      width: 560,
      child: TextField(
        controller: _controller,
        maxLines: 4,
        autofocus: true,
        decoration: const InputDecoration(
          labelText: 'Texte affiché au patient',
          alignLabelWithHint: true,
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Annuler'),
      ),
      FilledButton(
        onPressed: () {
          final value = _controller.text.trim();
          if (value.isNotEmpty) Navigator.pop(context, value);
        },
        child: const Text('Appliquer'),
      ),
    ],
  );
}

class _PublishDialog extends StatefulWidget {
  const _PublishDialog();

  @override
  State<_PublishDialog> createState() => _PublishDialogState();
}

class _PublishDialogState extends State<_PublishDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    icon: const Icon(
      Icons.publish_rounded,
      color: AdminColors.success,
      size: 34,
    ),
    title: const Text('Publier ce parcours ?'),
    content: SizedBox(
      width: 520,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Cette version remplacera immédiatement la version actuellement visible par les patients.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 15),
          TextField(
            key: const ValueKey('publish-note-field'),
            controller: _controller,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Résumé des changements',
              hintText: 'Ex. Ajout des signes respiratoires urgents.',
            ),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Annuler'),
      ),
      FilledButton.icon(
        key: const ValueKey('confirm-publish'),
        onPressed: () => Navigator.pop(context, _controller.text.trim()),
        style: FilledButton.styleFrom(backgroundColor: AdminColors.success),
        icon: const Icon(Icons.check_rounded),
        label: const Text('Publier maintenant'),
      ),
    ],
  );
}

class _ValidationDialog extends StatelessWidget {
  final List<String> issues;
  const _ValidationDialog({required this.issues});

  @override
  Widget build(BuildContext context) => AlertDialog(
    icon: const Icon(
      Icons.rule_folder_outlined,
      color: AdminColors.warning,
      size: 34,
    ),
    title: const Text('Parcours à corriger'),
    content: SizedBox(
      width: 540,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'La publication est bloquée pour éviter un parcours incomplet ou cassé.',
          ),
          const SizedBox(height: 12),
          for (final issue in issues)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 19,
                    color: AdminColors.warning,
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(issue)),
                ],
              ),
            ),
        ],
      ),
    ),
    actions: [
      FilledButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Continuer la modification'),
      ),
    ],
  );
}

class _ManagerFeedback extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  const _ManagerFeedback({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: AdminPanel(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AdminColors.primary, size: 42),
            const SizedBox(height: 13),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(message, textAlign: TextAlign.center),
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    ),
  );
}

class _ConfigIcon extends StatelessWidget {
  final String iconKey;
  final String colorHex;
  final double size;
  const _ConfigIcon({
    required this.iconKey,
    required this.colorHex,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final color = colorFromHex(colorHex);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(size * .3),
      ),
      child: Icon(configIcon(iconKey), color: color, size: size * .53),
    );
  }
}

const configIcons = <String, IconData>{
  'info': Icons.info_outline,
  'stomach': Icons.sick_outlined,
  'head': Icons.psychology_alt_outlined,
  'blood': Icons.water_drop_outlined,
  'air': Icons.air_outlined,
  'skin': Icons.texture_outlined,
  'pregnancy': Icons.pregnant_woman_outlined,
  'heart': Icons.favorite_border_outlined,
  'temperature': Icons.thermostat_outlined,
  'water': Icons.local_drink_outlined,
  'medicine': Icons.medication_outlined,
  'emergency': Icons.emergency_outlined,
  'face': Icons.face_outlined,
  'alert': Icons.warning_amber_rounded,
  'check': Icons.check_circle_outline,
  'clock': Icons.schedule_outlined,
  'calendar': Icons.calendar_month_outlined,
  'person': Icons.accessibility_new_outlined,
  'choice': Icons.radio_button_checked_outlined,
};

const configColors = [
  '#2457D6',
  '#149D9A',
  '#7759D8',
  '#E65F91',
  '#F29D49',
  '#B56B45',
  '#16845B',
  '#B42318',
];

const urgencyLabels = {
  'selfCare': 'Surveillance et soins prudents',
  'consultationSoon': 'Consultation recommandée',
  'consultationToday': 'Avis médical aujourd’hui',
  'emergency': 'Urgence médicale immédiate',
};

IconData configIcon(String key) =>
    configIcons[key] ?? Icons.radio_button_checked_outlined;

String iconLabel(String key) => switch (key) {
  'stomach' => 'Ventre',
  'head' => 'Tête',
  'blood' => 'Sang / règles',
  'air' => 'Respiration',
  'skin' => 'Peau',
  'pregnancy' => 'Grossesse',
  'heart' => 'Cœur / santé',
  'temperature' => 'Température',
  'water' => 'Hydratation',
  'medicine' => 'Médicament',
  'emergency' => 'Urgence',
  'face' => 'Visage',
  'alert' => 'Alerte',
  'check' => 'Confirmation',
  'clock' => 'Temps',
  'calendar' => 'Calendrier',
  'person' => 'Personne',
  'choice' => 'Choix',
  _ => 'Information',
};

String urgencyLabel(String key) =>
    urgencyLabels[key] ?? urgencyLabels.values.first;

Color urgencyColor(String key) => switch (key) {
  'emergency' => AdminColors.danger,
  'consultationToday' => AdminColors.warning,
  'consultationSoon' => AdminColors.primary,
  _ => AdminColors.success,
};

Color colorFromHex(String value) {
  final normalized = value.replaceFirst('#', '');
  final parsed = int.tryParse(
    normalized.length == 6 ? 'FF$normalized' : normalized,
    radix: 16,
  );
  return parsed == null ? AdminColors.primary : Color(parsed);
}

List<String> commaList(String value) => value
    .split(RegExp(r'[,\n]'))
    .map((item) => item.trim())
    .where((item) => item.isNotEmpty)
    .toSet()
    .toList(growable: false);

Map<String, int> parseWeights(String value) {
  final result = <String, int>{};
  for (final line in value.split(RegExp(r'[\n,]'))) {
    final parts = line.split('=');
    if (parts.length != 2) continue;
    final tag = parts.first.trim();
    final weight = int.tryParse(parts.last.trim());
    if (tag.isNotEmpty && weight != null) {
      result[tag] = weight.clamp(0, 100).toInt();
    }
  }
  return result;
}

String nextAvailableId(String prefix, Iterable<String> existing) {
  final used = existing.toSet();
  var number = used.length + 1;
  while (used.contains('${prefix}_$number')) {
    number++;
  }
  return '${prefix}_$number';
}

String? _required(String? value) =>
    value == null || value.trim().isEmpty ? 'Ce champ est requis.' : null;
