// lib/models/card_model.dart

class CardModel {
  final String targetPlayerId;
  final String promptId;
  final String truthAnswer;
  final Map<String, String> sabotageAnswers;

  CardModel({
    required this.targetPlayerId,
    required this.promptId,
    this.truthAnswer = '',
    this.sabotageAnswers = const {},
  });

  CardModel copyWith({
    String? targetPlayerId,
    String? promptId,
    String? truthAnswer,
    Map<String, String>? sabotageAnswers,
  }) {
    return CardModel(
      targetPlayerId: targetPlayerId ?? this.targetPlayerId,
      promptId: promptId ?? this.promptId,
      truthAnswer: truthAnswer ?? this.truthAnswer,
      sabotageAnswers: sabotageAnswers ?? this.sabotageAnswers,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'targetPlayerId': targetPlayerId,
      'promptId': promptId,
      'truthAnswer': truthAnswer,
      'sabotageAnswers': sabotageAnswers,
    };
  }

  factory CardModel.fromMap(Map<String, dynamic> map) {
    return CardModel(
      targetPlayerId: map['targetPlayerId'] ?? '',
      promptId: map['promptId'] ?? '',
      truthAnswer: map['truthAnswer'] ?? '',
      sabotageAnswers: Map<String, String>.from(map['sabotageAnswers'] ?? {}),
    );
  }
}
