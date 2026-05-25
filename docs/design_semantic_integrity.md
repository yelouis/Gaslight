# Semantic Integrity & AI Filtering

This document details the AI-assisted semantic similarity filtering used to prevent players from writing synonymous or identical answers.

## 1. Embedding Engine (`SemanticFilter`)

To maintain the challenge of the deduction puzzle, submissions must not be semantically redundant (e.g., submitting "a quick nap" when "sleeping" is already on the card).
* File: `lib/utils/semantic_filter.dart`

### API Integration
* **Service**: Gemini API (`models/text-embedding-004`).
* **Security Header**: The `GEMINI_API_KEY` is loaded from local environment configurations and passed via the HTTP header `x-goog-api-key`. It is **never** exposed in the request URL query parameters.
* **Payload**:
  ```json
  {
    "model": "models/text-embedding-004",
    "content": {
      "parts": [{ "text": "<answer>" }]
    }
  }
  ```

---

## 2. Cosine Similarity & Math

Vectors returned from the embeddings endpoint are compared mathematically:

### Formulas
* **Dot Product**: $\mathbf{A} \cdot \mathbf{B} = \sum_{i=1}^n A_i B_i$
* **Magnitude**: $\|\mathbf{A}\| = \sqrt{\sum_{i=1}^n A_i^2}$
* **Cosine Similarity**: $\text{similarity} = \frac{\mathbf{A} \cdot \mathbf{B}}{\|\mathbf{A}\| \|\mathbf{B}\|}$

### Threshold
* **Limit**: `0.85`.
* **Behavior**: If the cosine similarity score between the new answer and *any* existing answer on the target card (truth or other sabotages) exceeds `0.85`, the submission is rejected, and the client receives a warning SnackBar.

---

## 3. Performance & Memory Optimization

To keep response times low and avoid repeating network calls, a vector cache is maintained:
* **Cache**: `Map<String, List<double>> _vectorCache` maps text strings to their computed double vectors.
* **Lifecycle**: To prevent unbounded memory expansion, `SemanticFilter.clearCache()` is invoked when a new game session starts.
* **Concurrency Security**: All card edits (inserting sabotage or truth answers) run inside Firestore transactions to prevent parallel writes on a card from bypassing similarity checks.
