import { expect } from "chai";
import { PromptDecks, validateDeckSamples, DeckDefinition } from "../src/prompt_decks";

describe("Prompt Decks & Samples Tests (TS)", () => {
  it("should look up samples for an existing prompt", () => {
    const knownPrompt = "The first thing I'm stealing if looting becomes completely legal for one night.";
    const samples = PromptDecks.getSamplesForPrompt(knownPrompt);
    expect(samples).to.be.an("array");
    expect(samples!.length).to.be.greaterThan(0);
    expect(samples![0]).to.be.a("string");
    expect(samples![0].length).to.be.greaterThan(0);
    expect(samples![0].length).to.be.at.most(100);
  });

  it("should return undefined for custom or nonexistent prompt", () => {
    const customPrompt = "A custom prompt that does not exist in any catalogue deck.";
    const samples = PromptDecks.getSamplesForPrompt(customPrompt);
    expect(samples).to.be.undefined;
  });

  it("should validate all production decks successfully", () => {
    const decks = PromptDecks.getAllDecks();
    expect(() => validateDeckSamples(decks)).to.not.throw();
  });

  it("should cover all 150 prompts with sample answers (no prompt left uncovered)", () => {
    const decks = PromptDecks.getAllDecks();
    let totalPrompts = 0;
    let coveredPrompts = 0;

    for (const deck of decks) {
      for (const prompt of deck.prompts) {
        totalPrompts++;
        const samples = PromptDecks.getSamplesForPrompt(prompt);
        if (samples && samples.length > 0 && samples[0].trim().length > 0) {
          coveredPrompts++;
        }
      }
    }

    expect(totalPrompts).to.equal(150);
    expect(coveredPrompts).to.equal(150);
  });

  it("should throw at module load if a sample key does not match any prompt in its deck", () => {
    const bogusDecks: DeckDefinition[] = [
      {
        id: "test_deck",
        displayName: "Test Deck",
        rating: "PG",
        prompts: ["Valid prompt 1", "Valid prompt 2"],
        samples: {
          "Valid prompt 1": ["Sample 1"],
          "Bogus prompt that does not exist": ["Bogus sample"],
        },
      },
    ];

    expect(() => validateDeckSamples(bogusDecks)).to.throw(
      /Sample prompt key "Bogus prompt that does not exist" does not match any prompt in deck "test_deck"/
    );
  });
});
