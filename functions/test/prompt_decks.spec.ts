import { expect } from "chai";
import { PromptDecks, validateDeckStems, DeckDefinition } from "../src/prompt_decks";

describe("Prompt Decks & Stems Tests (TS)", () => {
  it("should look up stems for an existing prompt", () => {
    const knownPrompt = "The first thing I'm stealing if looting becomes completely legal for one night.";
    const stems = PromptDecks.getStemsForPrompt(knownPrompt);
    expect(stems).to.be.an("array");
    expect(stems!.length).to.be.greaterThan(0);
    expect(stems![0]).to.be.a("string");
  });

  it("should return undefined for custom or nonexistent prompt", () => {
    const customPrompt = "A custom prompt that does not exist in any catalogue deck.";
    const stems = PromptDecks.getStemsForPrompt(customPrompt);
    expect(stems).to.be.undefined;
  });

  it("should validate all production decks successfully", () => {
    const decks = PromptDecks.getAllDecks();
    expect(() => validateDeckStems(decks)).to.not.throw();
  });

  it("should throw at module load if a stem key does not match any prompt in its deck", () => {
    const bogusDecks: DeckDefinition[] = [
      {
        id: "test_deck",
        displayName: "Test Deck",
        rating: "PG",
        prompts: ["Valid prompt 1", "Valid prompt 2"],
        stems: {
          "Valid prompt 1": ["Stem 1"],
          "Bogus prompt that does not exist": ["Bogus stem"],
        },
      },
    ];

    expect(() => validateDeckStems(bogusDecks)).to.throw(
      /Stem prompt key "Bogus prompt that does not exist" does not match any prompt in deck "test_deck"/
    );
  });
});
