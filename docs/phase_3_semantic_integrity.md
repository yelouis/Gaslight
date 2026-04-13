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
      final apiKey = dotenv.env['GEMINI_API_KEY']; 
      final url = 'https://generativelanguage.googleapis.com/v1beta/models/text-embedding-004:embedContent?key=\$apiKey';
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
      );
      
      final data = jsonDecode(response.body);
      return List<double>.from(data['embedding']['values']);
  }
}
```

## Verification Plan

### Network Integration & Cosine Math Test
A standalone script (`scratch/test_semantic.dart`) will be generated to test:
1. Connecting to the live Gemini embed endpoint using a mock `GEMINI_API_KEY` (or throwing a safe exception if unauthorized). 
2. Passing two identical strings through the standard dot product Cosine Similarity function to ensure it outputs exactly `1.0`.
3. Passing two disjoint strings to see the variance.

To satisfy the pre-commit review, only the Math function (2 and 3) needs to pass cleanly without `http` errors if the API key isn't provided locally.

- **Transactional Integrity**: All card submissions now occur within Firestore transactions. This guarantees that multiple concurrent saboteur submissions on the same card are handled sequentially, resolving any potential data race conditions.
- **UI Integration & UX**: Added loading indicators during submission to account for the async `http` similarity check. If an answer is too similar to existing one, a SnackBar informs the user, preventing frustration from "hanging" UI.

### Places where there could be errors:
- **API Key Exposure on Client:** The `GEMINI_API_KEY` is loaded via `flutter_dotenv` and sent directly from the Dart HTTP client. This remains an active risk for prototyping; for production, this should be proxied through a secure backend (e.g. Firebase Cloud Functions).
- **Anti-Dupe Check Against Truth Is Structurally Impossible (Design Gap):** The PRD specifies rejecting sabotage answers that are >85% similar to the Target's Truth. However, the game flow runs **all sabotage rounds BEFORE the truth phase**. During sabotage submission (`phase2_craft.dart:41-44`), `targetCard.truthAnswer` is always an empty string (filtered out by `.where((a) => a.isNotEmpty)`). The semantic check between sabotages and truth can only fire in one direction: when the Target writes their truth, it IS checked against existing sabotages. But the reverse (sabotage vs. truth) can never happen because truth doesn't exist yet. This means two players could independently submit near-identical sabotage and truth answers with no warning. The fix is that we aren't checking if the sabotage is similar to the truth, but rather if the sabotage is similar to any other answer before it. Likewise, the truth is checked against all previous sabotages. 
- **`_vectorCache` Static Memory Leak (Active):** `SemanticFilter._vectorCache` is a `static final Map` that caches every embedding ever computed. It is never cleared between games or on room leave. Over multiple game sessions, this map grows unboundedly, consuming device memory. Fix: clear the cache on game start or room creation.
- **No Auto-Advance Timer Cancellation (Missing Implementation):** The Phase 3 doc specifies: "if the auto-advance timer completes during this hold, the API request cancels." However, no timer or `CancellationToken`-style mechanism exists anywhere in the codebase. The HTTP call has a 5-second timeout (`semantic_filter.dart:80`), but there is no external timer that can interrupt the submission flow. If a player's submission hangs during the semantic check, other players must wait indefinitely.
