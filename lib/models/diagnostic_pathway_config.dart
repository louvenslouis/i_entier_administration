enum DiagnosticVersionStatus { draft, published, archived }

class DiagnosticPathwayVersion {
  final String id;
  final String pathwayId;
  final int versionNumber;
  final DiagnosticVersionStatus status;
  final DiagnosticPathwayDefinition definition;
  final String changeNote;
  final DateTime? updatedAt;
  final DateTime? publishedAt;

  const DiagnosticPathwayVersion({
    required this.id,
    required this.pathwayId,
    required this.versionNumber,
    required this.status,
    required this.definition,
    this.changeNote = '',
    this.updatedAt,
    this.publishedAt,
  });

  factory DiagnosticPathwayVersion.fromRow(Map<String, dynamic> row) {
    final raw = row['definition'];
    return DiagnosticPathwayVersion(
      id: row['version_id']?.toString() ?? '',
      pathwayId: row['pathway_id']?.toString() ?? '',
      versionNumber: (row['version_number'] as num?)?.round() ?? 1,
      status: DiagnosticVersionStatus.values.firstWhere(
        (value) => value.name == row['status']?.toString(),
        orElse: () => DiagnosticVersionStatus.draft,
      ),
      definition: DiagnosticPathwayDefinition.fromMap(
        raw is Map ? Map<String, dynamic>.from(raw) : const {},
      ),
      changeNote: row['change_note']?.toString() ?? '',
      updatedAt: _dateFrom(row['updated_at']),
      publishedAt: _dateFrom(row['published_at']),
    );
  }
}

class DiagnosticPathwayBundle {
  final String pathwayId;
  final DiagnosticPathwayVersion? draft;
  final DiagnosticPathwayVersion? published;
  final List<DiagnosticPathwayVersion> archives;

  const DiagnosticPathwayBundle({
    required this.pathwayId,
    required this.draft,
    required this.published,
    required this.archives,
  });

  DiagnosticPathwayDefinition get visibleDefinition =>
      draft?.definition ??
      published?.definition ??
      DiagnosticPathwayDefinition.empty(pathwayId);

  int get nextVersionNumber {
    final versions = [
      if (draft != null) draft!.versionNumber,
      if (published != null) published!.versionNumber,
      ...archives.map((item) => item.versionNumber),
    ];
    return versions.isEmpty
        ? 1
        : versions.reduce((first, second) => first > second ? first : second) +
              1;
  }
}

class DiagnosticPathwayDefinition {
  final String id;
  final String title;
  final String subtitle;
  final String iconKey;
  final String colorHex;
  final List<DiagnosticQuestionDefinition> questions;
  final List<DiagnosticPossibilityDefinition> possibilities;
  final List<String> selfCare;
  final List<String> pharmacyAdvice;

  const DiagnosticPathwayDefinition({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.iconKey,
    required this.colorHex,
    required this.questions,
    required this.possibilities,
    required this.selfCare,
    required this.pharmacyAdvice,
  });

  factory DiagnosticPathwayDefinition.empty(String id) =>
      DiagnosticPathwayDefinition(
        id: id,
        title: 'Nouveau malaise',
        subtitle: '',
        iconKey: 'info',
        colorHex: '#2457D6',
        questions: const [],
        possibilities: const [],
        selfCare: const [],
        pharmacyAdvice: const [],
      );

  factory DiagnosticPathwayDefinition.fromMap(Map<String, dynamic> map) {
    List<Map<String, dynamic>> maps(String key) =>
        (map[key] as List? ?? const [])
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList(growable: false);
    List<String> strings(Object? value) => (value as List? ?? const [])
        .map((item) => item.toString())
        .toList(growable: false);
    return DiagnosticPathwayDefinition(
      id: map['id']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      subtitle: map['subtitle']?.toString() ?? '',
      iconKey: map['iconKey']?.toString() ?? 'info',
      colorHex: map['colorHex']?.toString() ?? '#2457D6',
      questions: maps(
        'questions',
      ).map(DiagnosticQuestionDefinition.fromMap).toList(growable: false),
      possibilities: maps(
        'possibilities',
      ).map(DiagnosticPossibilityDefinition.fromMap).toList(growable: false),
      selfCare: strings(map['selfCare']),
      pharmacyAdvice: strings(map['pharmacyAdvice']),
    );
  }

  DiagnosticPathwayDefinition copyWith({
    String? title,
    String? subtitle,
    String? iconKey,
    String? colorHex,
    List<DiagnosticQuestionDefinition>? questions,
    List<DiagnosticPossibilityDefinition>? possibilities,
    List<String>? selfCare,
    List<String>? pharmacyAdvice,
  }) => DiagnosticPathwayDefinition(
    id: id,
    title: title ?? this.title,
    subtitle: subtitle ?? this.subtitle,
    iconKey: iconKey ?? this.iconKey,
    colorHex: colorHex ?? this.colorHex,
    questions: questions ?? this.questions,
    possibilities: possibilities ?? this.possibilities,
    selfCare: selfCare ?? this.selfCare,
    pharmacyAdvice: pharmacyAdvice ?? this.pharmacyAdvice,
  );

  Map<String, dynamic> toMap() => {
    'schemaVersion': 1,
    'id': id,
    'title': title,
    'subtitle': subtitle,
    'iconKey': iconKey,
    'colorHex': colorHex,
    'questions': questions.map((item) => item.toMap()).toList(),
    'possibilities': possibilities.map((item) => item.toMap()).toList(),
    'selfCare': selfCare,
    'pharmacyAdvice': pharmacyAdvice,
  };

  List<String> validate() {
    final issues = <String>[];
    if (!RegExp(r'^[a-z0-9][a-z0-9_-]{1,79}$').hasMatch(id)) {
      issues.add('L’identifiant du malaise est invalide.');
    }
    if (title.trim().isEmpty) issues.add('Le malaise doit avoir un titre.');
    if (questions.isEmpty) {
      issues.add('Ajoutez au moins une question.');
      return issues;
    }
    final questionIds = <String>{};
    for (final question in questions) {
      if (question.id.trim().isEmpty || question.prompt.trim().isEmpty) {
        issues.add('Chaque question doit avoir un identifiant et un texte.');
      }
      if (!questionIds.add(question.id)) {
        issues.add('L’identifiant ${question.id} est utilisé plusieurs fois.');
      }
      if (question.options.length < 2) {
        issues.add('« ${question.title} » doit proposer au moins deux choix.');
      }
      final optionIds = <String>{};
      for (final option in question.options) {
        if (option.id.trim().isEmpty || option.label.trim().isEmpty) {
          issues.add('Chaque choix de « ${question.title} » doit être nommé.');
        }
        if (!optionIds.add(option.id)) {
          issues.add(
            'Le choix ${option.id} est dupliqué dans « ${question.title} ».',
          );
        }
      }
    }
    for (final question in questions) {
      for (final option in question.options) {
        final next = option.nextQuestionId;
        if (next != null && next.isNotEmpty && !questionIds.contains(next)) {
          issues.add(
            '« ${option.label} » pointe vers une question inexistante.',
          );
        }
        if (next == question.id) {
          issues.add(
            '« ${question.title} » ne peut pas pointer vers elle-même.',
          );
        }
      }
    }
    if (possibilities.isEmpty) {
      issues.add('Ajoutez au moins une possibilité de résultat.');
    }
    return issues;
  }
}

class DiagnosticQuestionDefinition {
  final String id;
  final String title;
  final String prompt;
  final String iconKey;
  final List<String> requiredTags;
  final List<String> excludedTags;
  final List<DiagnosticOptionDefinition> options;

  const DiagnosticQuestionDefinition({
    required this.id,
    required this.title,
    required this.prompt,
    required this.iconKey,
    required this.requiredTags,
    required this.excludedTags,
    required this.options,
  });

  factory DiagnosticQuestionDefinition.fromMap(Map<String, dynamic> map) =>
      DiagnosticQuestionDefinition(
        id: map['id']?.toString() ?? '',
        title: map['title']?.toString() ?? '',
        prompt: map['prompt']?.toString() ?? '',
        iconKey: map['iconKey']?.toString() ?? 'info',
        requiredTags: _strings(map['requiredTags']),
        excludedTags: _strings(map['excludedTags']),
        options: (map['options'] as List? ?? const [])
            .whereType<Map>()
            .map(
              (item) => DiagnosticOptionDefinition.fromMap(
                Map<String, dynamic>.from(item),
              ),
            )
            .toList(growable: false),
      );

  DiagnosticQuestionDefinition copyWith({
    String? title,
    String? prompt,
    String? iconKey,
    List<String>? requiredTags,
    List<String>? excludedTags,
    List<DiagnosticOptionDefinition>? options,
  }) => DiagnosticQuestionDefinition(
    id: id,
    title: title ?? this.title,
    prompt: prompt ?? this.prompt,
    iconKey: iconKey ?? this.iconKey,
    requiredTags: requiredTags ?? this.requiredTags,
    excludedTags: excludedTags ?? this.excludedTags,
    options: options ?? this.options,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'prompt': prompt,
    'iconKey': iconKey,
    'requiredTags': requiredTags,
    'excludedTags': excludedTags,
    'options': options.map((item) => item.toMap()).toList(),
  };
}

class DiagnosticOptionDefinition {
  final String id;
  final String label;
  final String iconKey;
  final List<String> tags;
  final String urgency;
  final String? nextQuestionId;

  const DiagnosticOptionDefinition({
    required this.id,
    required this.label,
    required this.iconKey,
    required this.tags,
    required this.urgency,
    required this.nextQuestionId,
  });

  factory DiagnosticOptionDefinition.fromMap(Map<String, dynamic> map) =>
      DiagnosticOptionDefinition(
        id: map['id']?.toString() ?? '',
        label: map['label']?.toString() ?? '',
        iconKey: map['iconKey']?.toString() ?? 'choice',
        tags: _strings(map['tags']),
        urgency: map['urgency']?.toString() ?? 'selfCare',
        nextQuestionId: map['nextQuestionId']?.toString(),
      );

  DiagnosticOptionDefinition copyWith({
    String? label,
    String? iconKey,
    List<String>? tags,
    String? urgency,
    String? nextQuestionId,
    bool clearNextQuestion = false,
  }) => DiagnosticOptionDefinition(
    id: id,
    label: label ?? this.label,
    iconKey: iconKey ?? this.iconKey,
    tags: tags ?? this.tags,
    urgency: urgency ?? this.urgency,
    nextQuestionId: clearNextQuestion
        ? null
        : nextQuestionId ?? this.nextQuestionId,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'label': label,
    'iconKey': iconKey,
    'tags': tags,
    'urgency': urgency,
    'nextQuestionId': nextQuestionId,
  };
}

class DiagnosticPossibilityDefinition {
  final String title;
  final String explanation;
  final Map<String, int> tagWeights;
  final int baseScore;

  const DiagnosticPossibilityDefinition({
    required this.title,
    required this.explanation,
    required this.tagWeights,
    required this.baseScore,
  });

  factory DiagnosticPossibilityDefinition.fromMap(Map<String, dynamic> map) {
    final weights = <String, int>{};
    final raw = map['tagWeights'];
    if (raw is Map) {
      for (final entry in raw.entries) {
        final value = entry.value is num
            ? (entry.value as num).round()
            : int.tryParse(entry.value.toString());
        if (value != null) weights[entry.key.toString()] = value;
      }
    }
    return DiagnosticPossibilityDefinition(
      title: map['title']?.toString() ?? '',
      explanation: map['explanation']?.toString() ?? '',
      tagWeights: weights,
      baseScore: (map['baseScore'] as num?)?.round() ?? 8,
    );
  }

  Map<String, dynamic> toMap() => {
    'title': title,
    'explanation': explanation,
    'tagWeights': tagWeights,
    'baseScore': baseScore,
  };
}

List<String> _strings(Object? value) => (value as List? ?? const [])
    .map((item) => item.toString())
    .toList(growable: false);

DateTime? _dateFrom(Object? value) =>
    value is DateTime ? value : DateTime.tryParse(value?.toString() ?? '');
