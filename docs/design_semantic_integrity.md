# Semantic Integrity & AI Filtering

This document details the AI-assisted semantic similarity filtering used to prevent players from writing synonymous or identical answers.

> **Server-side enforcement (July 2026):** with the server-authoritative migration (see `design_database_and_security.md`), the authoritative similarity check now runs **inside the `submitAnswer` Cloud Function** (`functions/src/index.ts`). The `GEMINI_API_KEY` lives only in the Functions environment — it is no longer shipped in the client `.env` (closing the README's key-exposure risk). Embedding vectors are cached per room in Firestore at `/rooms/{roomCode}/embeddings/{md5(normalizedText)}` (server-only; clients cannot read them). The check **fails open** on API errors so gameplay never blocks, but a confirmed >0.85 similarity rejects the submission with a player-facing "too similar" error. The legacy client-side `lib/utils/semantic_filter.dart` pre-check is now vestigial (no client key → always passes) and is slated for removal under open Issue 14.

## 1. Embedding Engine

To maintain the challenge of the deduction puzzle, submissions must not be semantically redundant (e.g., submitting "a quick nap" when "sleeping" is already on the card).
* Authoritative: `functions/src/index.ts` (`getEmbedding`, `cosineSimilarity`, invoked by `submitAnswer`)
* Legacy client mirror (vestigial): `lib/utils/semantic_filter.dart`

### API Integration
* **Service**: Gemini API (`models/text-embedding-004`).
* **Security Header**: The `GEMINI_API_KEY` is read from the Cloud Functions environment (`process.env.GEMINI_API_KEY` / Secret Manager) and passed via the HTTP header `x-goog-api-key`. It is **never** exposed in the request URL query parameters, and never present in client binaries.
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
