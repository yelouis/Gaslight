// lib/models/card_model.dart

class CardModel {
  final String targetPlayerId;
  final String promptText;
  final String truthAnswer;
  final Map<String, String> sabotageAnswers;
  final Map<String, String> votes; // VoterId -> VotedForId
  final Map<String, String> unmaskGuesses; // GuesserId -> GuessedAuthorId

  CardModel({
    required this.targetPlayerId,
    required this.promptText,
    this.truthAnswer = '',
    this.sabotageAnswers = const {},
    this.votes = const {},
    this.unmaskGuesses = const {},
  });

  CardModel copyWith({
    String? targetPlayerId,
    String? promptText,
    String? truthAnswer,
    Map<String, String>? sabotageAnswers,
    Map<String, String>? votes,
    Map<String, String>? unmaskGuesses,
  }) {
    return CardModel(
      targetPlayerId: targetPlayerId ?? this.targetPlayerId,
      promptText: promptText ?? this.promptText,
      truthAnswer: truthAnswer ?? this.truthAnswer,
      sabotageAnswers: sabotageAnswers ?? this.sabotageAnswers,
      votes: votes ?? this.votes,
      unmaskGuesses: unmaskGuesses ?? this.unmaskGuesses,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'targetPlayerId': targetPlayerId,
      'promptText': promptText,
      'truthAnswer': truthAnswer,
      'sabotageAnswers': sabotageAnswers,
      'votes': votes,
      'unmaskGuesses': unmaskGuesses,
    };
  }

  factory CardModel.fromMap(Map<String, dynamic> map) {
    return CardModel(
      targetPlayerId: map['targetPlayerId'] ?? '',
      promptText: map['promptText'] ?? '',
      truthAnswer: map['truthAnswer'] ?? '',
      sabotageAnswers: Map<String, String>.from(map['sabotageAnswers'] ?? {}),
      votes: Map<String, String>.from(map['votes'] ?? {}),
      unmaskGuesses: Map<String, String>.from(map['unmaskGuesses'] ?? {}),
    );
  }
}
