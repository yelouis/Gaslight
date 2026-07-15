# Duplicate-Answer Filtering

This document details the local lexical similarity heuristic used to prevent players from writing synonymous, identical, or near-identical answers for a card.

## 1. Overview & Architecture

To maintain the challenge of the deduction puzzle, submissions must not be too similar to existing answers on the same card (e.g. submitting "sleep all day in bed" when "sleeping in my bed all day" is already on the card).

The check is implemented as a **dependency-free, deterministic lexical heuristic** running in two mirrored places:
1. **Server-Authoritative:** Runs inside the `submitAnswer` Cloud Function (`functions/src/index.ts` via `./text_similarity`). All submissions are verified on the server before database writes.
2. **Client-Side Pre-check:** Runs locally on the client inside `phase2_craft.dart` (via `lib/utils/text_similarity.dart`). This provides instant "Too similar, try again" feedback to the player without incurring a network round-trip.

### Synonym Trade-off
Because this is a lexical heuristic rather than a deep learning model, it targets structural and word-level overlaps (normalized spelling, stemming, Jaccard token overlap, substring containment, and Levenshtein distance). It does **not** block pure synonyms with no shared words (e.g., "a quick nap" vs "sleeping"). This is a design-approved trade-off to eliminate Gemini API dependencies, costs, latency, and API keys.

---

## 2. The Shared Heuristic Algorithm

The TS and Dart implementations are byte-identical and behave deterministically. The algorithm evaluates a `candidate` string against a list of `existing` answers on the card using four cascading rules:

### A. Pre-processing & Normalization
*   **Stopwords**: Stopwords are filtered out during tokenization.
    `STOPWORDS = {a, an, the, my, your, our, his, her, their, this, that, in, on, of, to, and, or, for, with, at, is, am, are, was, were, be, been, it, i, me, we, you, all}`
*   **Normalization (`normalize`)**: Converts the string to lowercase, replaces all non-alphanumeric characters `[^a-z0-9]` with spaces, collapses multiple spaces, and trims.
*   **Stemming (`stem`)**: Reduces tokens to their base form. Applies the first matching rule:
    1.  Length > 5 & ends with `"ing"` $\rightarrow$ drop last 3.
    2.  Length > 4 & ends with `"ed"` $\rightarrow$ drop last 2.
    3.  Length > 4 & ends with `"es"` $\rightarrow$ drop last 2.
    4.  Length > 3 & ends with `"s"` & not ends with `"ss"` $\rightarrow$ drop last 1.
    5.  Length > 4 & ends with `"ly"` $\rightarrow$ drop last 2.

### B. Cascading Reject Rules
A candidate `C` is rejected against an existing entry `E` if any of these conditions are met:

1.  **Exact Match**:
    $$\text{normalize}(C) == \text{normalize}(E)$$
2.  **Containment**:
    Extracts the stemmed, stopword-filtered phrase strings `pc` and `pe`. If the shorter phrase is a substring of the longer phrase, and the shorter phrase contains at least `CONTAINMENT_MIN_TOKENS` (2) tokens, the candidate is rejected.
3.  **Jaccard Similarity**:
    Extracts the sets of content tokens `tc` and `te`. If both are non-empty:
    $$\text{Jaccard}(C, E) = \frac{|tc \cap te|}{|tc \cup te|} \ge \text{JACCARD\_THRESHOLD}\ (0.6)$$
4.  **Levenshtein Distance**:
    Computes Levenshtein distance on the normalized strings:
    $$\text{Ratio}(C, E) = 1.0 - \frac{\text{lev}(C, E)}{\max(|C|, |E|)} \ge \text{LEV\_RATIO\_THRESHOLD}\ (0.85)$$
    *(If both are empty, Ratio is 1.0)*

---

## 3. Thresholds & Configuration Constants

The threshold constants are exposed at the top of the similarity files for easy adjustment:

| Constant | Value | Purpose |
|---|---|---|
| `JACCARD_THRESHOLD` | `0.6` | Triggers reject on high word overlap (e.g. "dog ate homework" vs "dog ate my homework"). |
| `LEV_RATIO_THRESHOLD` | `0.85` | Triggers reject on near-exact typos or minor spelling differences. |
| `CONTAINMENT_MIN_TOKENS` | `2` | Minimum token count required for containment matching (prevents single common words from blocking phrases). |
