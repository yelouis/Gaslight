import 'dart:convert';
import 'dart:math';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class SemanticFilter {
  static const double threshold = 0.85;
  static final Map<String, List<double>> _vectorCache = {};
  
  /// Clears the static embedding cache. Should be called at the start of every game.
  static void clearCache() {
    _vectorCache.clear();
  }

  /// Compares the newly submitted answer against all previously existing answers.
  /// Returns `true` if it is unique (below threshold similarity to all others).
  /// Falls back to `true` silently if network/API failure occurs to prevent breaking the game.
  static Future<bool> isAnswerUnique(String newAnswer, List<String> existingAnswers) async {
    if (existingAnswers.isEmpty) return true;

    try {
      List<double> newVector = await _getEmbedding(newAnswer);
      
      // Concurrently get embeddings for all existing answers 
      List<List<double>> existingVectors = await Future.wait(
        existingAnswers.map((ans) => _getEmbedding(ans))
      );
      
      for (var ev in existingVectors) {
        double sim = cosineSimilarity(newVector, ev);
        if (sim > threshold) {
          return false;
        }
      }
      return true;
    } catch (e) {
      // Print error in debug but fail open to allow gameplay to continue
      print('Semantic API Error (failing open): \$e');
      return true;
    }
  }

  /// Evaluates dot-product based cosine similarity of two numerical vector embeddings.
  static double cosineSimilarity(List<double> a, List<double> b) {
    if (a.length != b.length || a.isEmpty) return 0.0;
    
    double dotProduct = 0.0;
    double normA = 0.0;
    double normB = 0.0;
    
    for (int i = 0; i < a.length; i++) {
        dotProduct += a[i] * b[i];
        normA += a[i] * a[i];
        normB += b[i] * b[i];
    }
    
    if (normA == 0 || normB == 0) return 0.0;
    return dotProduct / (sqrt(normA) * sqrt(normB));
  }

  /// Pings Gemini directly using Dart HTTP without requiring thick Firebase Functions
  static Future<List<double>> _getEmbedding(String text) async {
    final apiKey = dotenv.env['GEMINI_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('Missing GEMINI_API_KEY');
    }

    if (_vectorCache.containsKey(text)) {
      return _vectorCache[text]!;
    }

    final url = 'https://generativelanguage.googleapis.com/v1beta/models/text-embedding-004:embedContent?key=$apiKey';
    
    final response = await http.post(
      Uri.parse(url),
      headers: {
        'Content-Type': 'application/json'
      },
      body: jsonEncode({
        'model': 'models/text-embedding-004', 
        'content': {
          'parts': [{'text': text}]
        }
      })
    ).timeout(const Duration(seconds: 5));
    
    if (response.statusCode != 200) {
      throw Exception('Gemini API returned \${response.statusCode}: \${response.body}');
    }

    final data = jsonDecode(response.body);
    final vector = List<double>.from(data['embedding']['values']);
    _vectorCache[text] = vector;
    return vector;
  }
}
