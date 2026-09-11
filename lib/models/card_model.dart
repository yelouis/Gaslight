// lib/models/card_model.dart

class CardAnswerOption {
  final String id;
  final String text;

  CardAnswerOption({
    required this.id,
    required this.text,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'text': text,
    };
  }

  factory CardAnswerOption.fromMap(Map<String, dynamic> map) {
    return CardAnswerOption(
      id: map['id'] ?? '',
      text: map['text'] ?? '',
    );
  }
}

class ScoreBreakdownItem {
  final String rule;
  final int points;

  const ScoreBreakdownItem({
    required this.rule,
    required this.points,
  });

  Map<String, dynamic> toMap() {
    return {
      'rule': rule,
      'points': points,
    };
  }

  factory ScoreBreakdownItem.fromMap(Map<String, dynamic> map) {
    return ScoreBreakdownItem(
      rule: map['rule']?.toString() ?? '',
      points: (map['points'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ScoreBreakdownItem &&
          runtimeType == other.runtimeType &&
          rule == other.rule &&
          points == other.points;

  @override
  int get hashCode => rule.hashCode ^ points.hashCode;
}

class CardModel {
  final String targetPlayerId;
  final String promptText;
  final String truthAnswer;
  final Map<String, String> sabotageAnswers;
  final List<CardAnswerOption> options;
  final Map<String, String> votes; // VoterId -> VotedForAuthorId
  final Map<String, String> unmaskGuesses; // GuesserId -> GuessedAuthorId
  final Map<String, int> scoreDeltas; // PlayerId -> Delta points on this card
  final Map<String, List<ScoreBreakdownItem>> scoreBreakdown; // PlayerId -> rule breakdown items

  CardModel({
    required this.targetPlayerId,
    required this.promptText,
    this.truthAnswer = '',
    this.sabotageAnswers = const {},
    this.options = const [],
    this.votes = const {},
    this.unmaskGuesses = const {},
    this.scoreDeltas = const {},
    this.scoreBreakdown = const {},
  });

  CardModel copyWith({
    String? targetPlayerId,
    String? promptText,
    String? truthAnswer,
    Map<String, String>? sabotageAnswers,
    List<CardAnswerOption>? options,
    Map<String, String>? votes,
    Map<String, String>? unmaskGuesses,
    Map<String, int>? scoreDeltas,
    Map<String, List<ScoreBreakdownItem>>? scoreBreakdown,
  }) {
    return CardModel(
      targetPlayerId: targetPlayerId ?? this.targetPlayerId,
      promptText: promptText ?? this.promptText,
      truthAnswer: truthAnswer ?? this.truthAnswer,
      sabotageAnswers: sabotageAnswers ?? this.sabotageAnswers,
      options: options ?? this.options,
      votes: votes ?? this.votes,
      unmaskGuesses: unmaskGuesses ?? this.unmaskGuesses,
      scoreDeltas: scoreDeltas ?? this.scoreDeltas,
      scoreBreakdown: scoreBreakdown ?? this.scoreBreakdown,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'targetPlayerId': targetPlayerId,
      'promptText': promptText,
      'truthAnswer': truthAnswer,
      'sabotageAnswers': sabotageAnswers,
      'options': options.map((o) => o.toMap()).toList(),
      'votes': votes,
      'unmaskGuesses': unmaskGuesses,
      'scoreDeltas': scoreDeltas,
      'scoreBreakdown': scoreBreakdown.map((k, v) => MapEntry(k, v.map((item) => item.toMap()).toList())),
    };
  }

  factory CardModel.fromMap(Map<String, dynamic> map) {
    final rawOptions = map['options'];
    List<CardAnswerOption> parsedOptions = [];
    if (rawOptions is List) {
      parsedOptions = rawOptions
          .map((item) => CardAnswerOption.fromMap(Map<String, dynamic>.from(item)))
          .toList();
    }

    final rawBreakdown = map['scoreBreakdown'];
    Map<String, List<ScoreBreakdownItem>> parsedBreakdown = {};
    if (rawBreakdown is Map) {
      rawBreakdown.forEach((k, v) {
        if (v is List) {
          parsedBreakdown[k.toString()] = v
              .map((item) => ScoreBreakdownItem.fromMap(Map<String, dynamic>.from(item as Map)))
              .toList();
        }
      });
    }

    return CardModel(
      targetPlayerId: map['targetPlayerId'] ?? '',
      promptText: map['promptText'] ?? '',
      truthAnswer: map['truthAnswer'] ?? '',
      sabotageAnswers: Map<String, String>.from(map['sabotageAnswers'] ?? {}),
      options: parsedOptions,
      votes: Map<String, String>.from(map['votes'] ?? {}),
      unmaskGuesses: Map<String, String>.from(map['unmaskGuesses'] ?? {}),
      scoreDeltas: Map<String, int>.from(
        (map['scoreDeltas'] as Map?)?.map((k, v) => MapEntry(k.toString(), (v as num).toInt())) ?? {},
      ),
      scoreBreakdown: parsedBreakdown,
    );
  }
}

