# Phase 3: AI-Assisted Semantic Integrity

## Overview
To prevent multiple players from submitting synonymous answers (e.g., "spiders", "arachnids"), which ruins the deduction puzzle, we employ a semantic similarity check. In this version, we will embed the `.env` local proxy approach to allow ultra-fast prototyping rather than spinning up a Firebase Cloud Function.

## Key Processing Logic
1. **Trigger**: When a Saboteur clicks "Submit", the system temporarily holds the payload.
2. **Fetch Existing**: Retrieve all previously submitted answers for that specific `Card` from `GameState`.
3. **Direct Client Embeddings API**: Convert answers to vectors by pinging the direct OpenAI / custom LLM endpoint directly from Dart utilizing `flutter_dotenv`.
4. **Cosine Similarity**: Compare. If score $>0.85$, reject the request. We will also ensure time constraints: if the auto-advance timer completes during this hold, the API request cancels and drops the user out to a penalty/safe-placeholder.

## Pseudo Code

```dart
// Client-side Http Service directly using Dart http package
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class SemanticFilter {
  static const double threshold = 0.85;

  static Future<bool> isAnswerUnique(String newAnswer, List<String> existingAnswers) async {
    if (existingAnswers.isEmpty) return true;

    // 1. Get embedding via Client HTTP (fast local prototyping model)
    List<double> newVector = await _getEmbedding(newAnswer);
    
    // 2. Fetch existing embeddings (Should cache if possible during rotation)
    List<List<double>> existingVectors = await Future.wait(
      existingAnswers.map((ans) => _getEmbedding(ans))
    );
    
    // 3. Cosine Calculation
    for (var ev in existingVectors) {
      double sim = cosineSimilarity(newVector, ev);
      if (sim > threshold) {
        return false;
      }
    }
    
    return true; 
  }
  
  static double cosineSimilarity(List<double> a, List<double> b) {
      // Standard Dot Product Math
      ...
  }
  
  static Future<List<double>> _getEmbedding(String text) async {
      final apiKey = dotenv.env['OPENAI_API_KEY']; 
      final response = await http.post(
         Uri.parse('https://api.openai.com/v1/embeddings'),
         headers: {
            'Authorization': 'Bearer \$apiKey',
            'Content-Type': 'application/json'
         },
         body: jsonEncode({
            'model': 'text-embedding-3-small', // text-embedding-004 equiv
            'input': text
         })
      );
      
      final data = jsonDecode(response.body);
      return List<double>.from(data['data'][0]['embedding']);
  }
}
```
