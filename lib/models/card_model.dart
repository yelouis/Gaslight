// lib/models/card_model.dart

class CardModel {
  final String targetPlayerId;
  final String promptId;
  final String truthAnswer;
  final Map<String, String> sabotageAnswers;
  final Map<String, String> votes; // VoterId -> VotedForId

  CardModel({
    required this.targetPlayerId,
    required this.promptId,
    this.truthAnswer = '',
    this.sabotageAnswers = const {},
    this.votes = const {},
  });

  CardModel copyWith({
    String? targetPlayerId,
    String? promptId,
    String? truthAnswer,
    Map<String, String>? sabotageAnswers,
    Map<String, String>? votes,
  }) {
    return CardModel(
      targetPlayerId: targetPlayerId ?? this.targetPlayerId,
      promptId: promptId ?? this.promptId,
      truthAnswer: truthAnswer ?? this.truthAnswer,
      sabotageAnswers: sabotageAnswers ?? this.sabotageAnswers,
      votes: votes ?? this.votes,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'targetPlayerId': targetPlayerId,
      'promptId': promptId,
      'truthAnswer': truthAnswer,
      'sabotageAnswers': sabotageAnswers,
      'votes': votes,
    };
  }

  factory CardModel.fromMap(Map<String, dynamic> map) {
    return CardModel(
      targetPlayerId: map['targetPlayerId'] ?? '',
      promptId: map['promptId'] ?? '',
      truthAnswer: map['truthAnswer'] ?? '',
      sabotageAnswers: Map<String, String>.from(map['sabotageAnswers'] ?? {}),
      votes: Map<String, String>.from(map['votes'] ?? {}),
    );
  }
}
