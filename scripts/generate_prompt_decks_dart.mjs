#!/usr/bin/env node
/**
 * Generates lib/utils/prompt_decks.dart from functions/src/prompt_decks.ts.
 *
 * functions/src/prompt_decks.ts is the SOURCE OF TRUTH for decks. The Dart file
 * is a build artefact and must never be hand-edited — scripts/check_decks_in_sync.sh
 * fails the battery when it is stale.
 *
 * It reads the COMPILED functions/lib/prompt_decks.js rather than parsing
 * TypeScript, so the data it emits is exactly what the server will draw from.
 * Run `npm --prefix functions run build` first; this script does it for you.
 *
 * Usage: ./scripts/generate_prompt_decks_dart.sh
 */
import { execSync } from "node:child_process";
import { writeFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import path from "node:path";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");

execSync("npm --prefix functions run build", { cwd: root, stdio: "pipe" });
const { PromptDecks } = await import(
  path.join(root, "functions/lib/prompt_decks.js")
);

const decks = PromptDecks.getAllDecks();
if (!decks.length) {
  console.error("ERROR: no decks found — refusing to write an empty Dart file.");
  process.exit(2);
}
// Surfaces a malformed source before it reaches the client.
const fallbackId = PromptDecks.getFallbackDeckId();

/** Dart single-quoted string literal. */
const lit = (s) => "'" + s.replace(/\\/g, "\\\\").replace(/'/g, "\\'").replace(/\$/g, "\\$") + "'";

const out = [];
const w = (s = "") => out.push(s);

w("// GENERATED FILE — DO NOT EDIT.");
w("//");
w("// Source of truth: functions/src/prompt_decks.ts");
w("// Regenerate:      ./scripts/generate_prompt_decks_dart.sh");
w("// Verified by:     ./scripts/check_decks_in_sync.sh (part of the battery)");
w("//");
w("// Hand-editing this file is how the decks silently diverged twice before:");
w("// once the Dart copy was edited alone, once the TypeScript copy was. Add or");
w("// change a deck in the .ts file and regenerate.");
w("");
w("import 'dart:math';");
w("");
w("/// Content rating for a deck. The seal COLOUR is a UI concern and lives in");
w("/// `app_colors.dart` — this is only the token.");
w("enum DeckRating { pg, r, x }");
w("");
w("/// Everything the app knows about one deck. Mirrors `DeckDefinition` in the");
w("/// TypeScript source.");
w("class DeckDefinition {");
w("  final String id;");
w("  final String displayName;");
w("  final DeckRating rating;");
w("  final bool isFallback;");
w("  final List<String> prompts;");
w("");
w("  const DeckDefinition({");
w("    required this.id,");
w("    required this.displayName,");
w("    required this.rating,");
w("    required this.isFallback,");
w("    required this.prompts,");
w("  });");
w("}");
w("");
w("class PromptDecks {");
w("  /// Declaration order matches the TypeScript source, so the lobby carousel");
w("  /// shows decks in the order they are written there.");
w("  static const List<DeckDefinition> allDecks = [");
for (const d of decks) {
  w("    DeckDefinition(");
  w(`      id: ${lit(d.id)},`);
  w(`      displayName: ${lit(d.displayName)},`);
  w(`      rating: DeckRating.${d.rating.toLowerCase()},`);
  w(`      isFallback: ${d.isFallback === true},`);
  w("      prompts: [");
  for (const p of d.prompts) w(`        ${lit(p)},`);
  w("      ],");
  w("    ),");
}
w("  ];");
w("");
w("  static final Map<String, DeckDefinition> _byId = {");
w("    for (final d in allDecks) d.id: d,");
w("  };");
w("");
w("  /// The deck used when no chosen deck applies: the default for a new room,");
w("  /// the top-up pool for custom decks, and the source for re-rolls in a custom");
w("  /// game. Declared in the TypeScript source via `isFallback`.");
w(`  static const String fallbackDeckId = ${lit(fallbackId)};`);
w("");
w("  static int getDeckSize(String deckId) => _byId[deckId]?.prompts.length ?? 0;");
w("");
w("  /// Deck IDs in declaration order.");
w("  static List<String> get availableDecks =>");
w("      allDecks.map((d) => d.id).toList();");
w("");
w("  /// The name players see. Declared per-deck, NOT derived from the id —");
w("  /// splitting `rated_r_nsfw` on underscores renders it as 'Rated R Nsfw'.");
w("  static String getDeckName(String deckId) =>");
w("      _byId[deckId]?.displayName ?? deckId;");
w("");
w("  static DeckRating? getDeckRating(String deckId) => _byId[deckId]?.rating;");
w("");
w("  static DeckDefinition? getDeck(String deckId) => _byId[deckId];");
w("");
w("  /// Pulls [count] randomly selected unique prompts from [deckId].");
w("  static List<String> drawPrompts(String deckId, int count) {");
w("    final deck = _byId[deckId];");
w("    if (deck == null) {");
w("      throw Exception('Failed to load deck: \\$deckId. Ensure it is defined in PromptDecks.');");
w("    }");
w("");
w("    final deckCopy = List<String>.from(deck.prompts)..shuffle(Random());");
w("    if (count > deckCopy.length) {");
w("      throw Exception('Not enough prompts in the deck for \\$count players. Max is \\${deckCopy.length}.');");
w("    }");
w("    return deckCopy.sublist(0, count);");
w("  }");
w("");
w("  /// Draws one prompt, preferring anything outside [excludedPrompts].");
w("  ///");
w("  /// Re-rolls are unlimited: once every prompt has been seen this repeats one");
w("  /// rather than refusing. [mustAvoid] survives that fallback so a re-roll");
w("  /// always visibly changes something. Only a missing deck throws.");
w("  static String drawOneExcluding(");
w("    String deckId,");
w("    Set<String> excludedPrompts, [");
w("    Set<String> mustAvoid = const {},");
w("  ]) {");
w("    final entry = _byId[deckId];");
w("    if (entry == null) {");
w("      throw Exception('Failed to load deck: \\$deckId. Ensure it is defined in PromptDecks.');");
w("    }");
w("");
w("    final deck = entry.prompts;");
w("    String pick(List<String> xs) => (xs.toList()..shuffle(Random())).first;");
w("");
w("    final preferred = deck.where((p) => !excludedPrompts.contains(p)).toList();");
w("    if (preferred.isNotEmpty) return pick(preferred);");
w("");
w("    final relaxed = deck.where((p) => !mustAvoid.contains(p)).toList();");
w("    if (relaxed.isNotEmpty) return pick(relaxed);");
w("");
w("    return pick(deck);");
w("  }");
w("}");
w("");

writeFileSync(path.join(root, "lib/utils/prompt_decks.dart"), out.join("\n"));
console.log(
  `Generated lib/utils/prompt_decks.dart — ${decks.length} decks, ` +
  `${decks.reduce((n, d) => n + d.prompts.length, 0)} prompts, fallback '${fallbackId}'.`
);
