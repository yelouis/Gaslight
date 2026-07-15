import 'dart:math' as math;

class TextSimilarity {
  static const Set<String> stopwords = {
    "a", "an", "the", "my", "your", "our", "his", "her", "their", "this", "that",
    "in", "on", "of", "to", "and", "or", "for", "with", "at", "is", "am", "are",
    "was", "were", "be", "been", "it", "i", "me", "we", "you", "all"
  };

  static const double jaccardThreshold = 0.6;
  static const double levRatioThreshold = 0.85;
  static const int containmentMinTokens = 2;

  static String normalize(String s) {
    return s
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static String stem(String tok) {
    if (tok.length > 5 && tok.endsWith("ing")) {
      return tok.substring(0, tok.length - 3);
    } else if (tok.length > 4 && tok.endsWith("ed")) {
      return tok.substring(0, tok.length - 2);
    } else if (tok.length > 4 && tok.endsWith("es")) {
      return tok.substring(0, tok.length - 2);
    } else if (tok.length > 3 && tok.endsWith("s") && !tok.endsWith("ss")) {
      return tok.substring(0, tok.length - 1);
    } else if (tok.length > 4 && tok.endsWith("ly")) {
      return tok.substring(0, tok.length - 2);
    }
    return tok;
  }

  static Set<String> contentTokensSet(String s) {
    final norm = normalize(s);
    if (norm.isEmpty) return <String>{};
    final tokens = norm.split(' ');
    final result = <String>{};
    for (final t in tokens) {
      if (t.isNotEmpty && !stopwords.contains(t)) {
        result.add(stem(t));
      }
    }
    return result;
  }

  static String contentPhrase(String s) {
    final norm = normalize(s);
    if (norm.isEmpty) return '';
    final tokens = norm.split(' ');
    final stemmed = <String>[];
    for (final t in tokens) {
      if (t.isNotEmpty && !stopwords.contains(t)) {
        stemmed.add(stem(t));
      }
    }
    return stemmed.join(' ');
  }

  static int levenshtein(String s1, String s2) {
    final m = s1.length;
    final n = s2.length;
    final d = List.generate(m + 1, (_) => List.filled(n + 1, 0));

    for (var i = 0; i <= m; i++) {
      d[i][0] = i;
    }
    for (var j = 0; j <= n; j++) {
      d[0][j] = j;
    }

    for (var i = 1; i <= m; i++) {
      for (var j = 1; j <= n; j++) {
        final cost = s1[i - 1] == s2[j - 1] ? 0 : 1;
        d[i][j] = [
          d[i - 1][j] + 1,
          d[i][j - 1] + 1,
          d[i - 1][j - 1] + cost,
        ].reduce((a, b) => a < b ? a : b);
      }
    }
    return d[m][n];
  }

  static bool isTooSimilar(String candidate, List<String> existing) {
    final normC = normalize(candidate);
    final pc = contentPhrase(candidate);
    final tc = contentTokensSet(candidate);

    for (final e in existing) {
      final normE = normalize(e);
      // 1. Exact match after normalize
      if (normC == normE) {
        return true;
      }

      // 2. Containment
      final pe = contentPhrase(e);
      if (pc.isNotEmpty && pe.isNotEmpty) {
        final shorter = pc.length < pe.length ? pc : pe;
        final longer = pc.length < pe.length ? pe : pc;
        if (longer.contains(shorter)) {
          final tokenCount = shorter.split(' ').where((t) => t.isNotEmpty).length;
          if (tokenCount >= containmentMinTokens) {
            return true;
          }
        }
      }

      // 3. Jaccard
      final te = contentTokensSet(e);
      if (tc.isNotEmpty && te.isNotEmpty) {
        final intersect = tc.intersection(te);
        final union = tc.union(te);
        final jaccard = intersect.length / union.length;
        if (jaccard >= jaccardThreshold) {
          return true;
        }
      }

      // 4. Levenshtein ratio
      final maxLen = math.max(normC.length, normE.length);
      if (maxLen == 0) {
        return true; // both empty
      } else {
        final dist = levenshtein(normC, normE);
        final ratio = 1.0 - (dist / maxLen);
        if (ratio >= levRatioThreshold) {
          return true;
        }
      }
    }

    return false;
  }
}
