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

class CardModel {
  final String targetPlayerId;
  final String promptText;
  final String truthAnswer;
  final Map<String, String> sabotageAnswers;
  final List<CardAnswerOption> options;
  final Map<String, String> votes; // VoterId -> VotedForAuthorId
  final Map<String, String> unmaskGuesses; // GuesserId -> GuessedAuthorId
  final Map<String, int> scoreDeltas; // PlayerId -> Delta points on this card

  CardModel({
    required this.targetPlayerId,
    required this.promptText,
    this.truthAnswer = '',
    this.sabotageAnswers = const {},
    this.options = const [],
    this.votes = const {},
    this.unmaskGuesses = const {},
    this.scoreDeltas = const {},
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
    );
  }
}
