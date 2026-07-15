export const STOPWORDS = new Set([
  "a", "an", "the", "my", "your", "our", "his", "her", "their", "this", "that",
  "in", "on", "of", "to", "and", "or", "for", "with", "at", "is", "am", "are",
  "was", "were", "be", "been", "it", "i", "me", "we", "you", "all"
]);

export const JACCARD_THRESHOLD = 0.6;
export const LEV_RATIO_THRESHOLD = 0.85;
export const CONTAINMENT_MIN_TOKENS = 2;

export function normalize(s: string): string {
  return s.toLowerCase().replace(/[^a-z0-9]/g, " ").replace(/\s+/g, " ").trim();
}

export function stem(tok: string): string {
  if (tok.length > 5 && tok.endsWith("ing")) {
    return tok.slice(0, -3);
  } else if (tok.length > 4 && tok.endsWith("ed")) {
    return tok.slice(0, -2);
  } else if (tok.length > 4 && tok.endsWith("es")) {
    return tok.slice(0, -2);
  } else if (tok.length > 3 && tok.endsWith("s") && !tok.endsWith("ss")) {
    return tok.slice(0, -1);
  } else if (tok.length > 4 && tok.endsWith("ly")) {
    return tok.slice(0, -2);
  }
  return tok;
}

export function contentTokensSet(s: string): Set<string> {
  const norm = normalize(s);
  if (norm === "") return new Set();
  const tokens = norm.split(" ");
  const result = new Set<string>();
  for (const t of tokens) {
    if (t !== "" && !STOPWORDS.has(t)) {
      result.add(stem(t));
    }
  }
  return result;
}

export function contentPhrase(s: string): string {
  const norm = normalize(s);
  if (norm === "") return "";
  const tokens = norm.split(" ");
  const stemmed: string[] = [];
  for (const t of tokens) {
    if (t !== "" && !STOPWORDS.has(t)) {
      stemmed.push(stem(t));
    }
  }
  return stemmed.join(" ");
}

export function levenshtein(s1: string, s2: string): number {
  const m = s1.length;
  const n = s2.length;
  const d: number[][] = Array.from({ length: m + 1 }, () => Array(n + 1).fill(0));

  for (let i = 0; i <= m; i++) d[i][0] = i;
  for (let j = 0; j <= n; j++) d[0][j] = j;

  for (let i = 1; i <= m; i++) {
    for (let j = 1; j <= n; j++) {
      const cost = s1[i - 1] === s2[j - 1] ? 0 : 1;
      d[i][j] = Math.min(
        d[i - 1][j] + 1,
        d[i][j - 1] + 1,
        d[i - 1][j - 1] + cost
      );
    }
  }
  return d[m][n];
}

export function isTooSimilar(candidate: string, existing: string[]): boolean {
  const normC = normalize(candidate);
  const pc = contentPhrase(candidate);
  const tc = contentTokensSet(candidate);

  for (const e of existing) {
    const normE = normalize(e);
    // 1. Exact match after normalize
    if (normC === normE) {
      return true;
    }

    // 2. Containment
    const pe = contentPhrase(e);
    if (pc !== "" && pe !== "") {
      const shorter = pc.length < pe.length ? pc : pe;
      const longer = pc.length < pe.length ? pe : pc;
      if (longer.includes(shorter)) {
        const tokenCount = shorter.split(" ").filter((t) => t !== "").length;
        if (tokenCount >= CONTAINMENT_MIN_TOKENS) {
          return true;
        }
      }
    }

    // 3. Jaccard
    const te = contentTokensSet(e);
    if (tc.size > 0 && te.size > 0) {
      let intersectCount = 0;
      for (const t of tc) {
        if (te.has(t)) {
          intersectCount++;
        }
      }
      const unionCount = tc.size + te.size - intersectCount;
      const jaccard = intersectCount / unionCount;
      if (jaccard >= JACCARD_THRESHOLD) {
        return true;
      }
    }

    // 4. Levenshtein ratio
    const maxLen = Math.max(normC.length, normE.length);
    if (maxLen === 0) {
      return true; // both empty
    } else {
      const dist = levenshtein(normC, normE);
      const ratio = 1.0 - dist / maxLen;
      if (ratio >= LEV_RATIO_THRESHOLD) {
        return true;
      }
    }
  }

  return false;
}
