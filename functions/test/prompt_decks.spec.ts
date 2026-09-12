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

  describe("Fallback Deck & Top-up on Exhaustion (AC5 / Issue 174)", () => {
    it("AC5.5: getFallbackDeckId()'s deck is rated PG", () => {
      const fallbackId = PromptDecks.getFallbackDeckId();
      const fallbackDeck = PromptDecks.getDeck(fallbackId);
      expect(fallbackDeck).to.exist;
      expect(fallbackDeck!.rating).to.equal("PG");
      expect(PromptDecks.getDeckRating(fallbackId)).to.equal("PG");
      expect(fallbackDeck!.isFallback).to.be.true;
    });

    it("AC5.4: while the room deck still has unseen prompts, the fallback is never consulted", () => {
      const roomDeckId = "real_life"; // 25 prompts
      const roomDeck = PromptDecks.getDeck(roomDeckId)!;

      // Exclude 10 prompts out of 25 from roomDeck
      const excluded = new Set(roomDeck.prompts.slice(0, 10));

      for (let i = 0; i < 20; i++) {
        const drawn = PromptDecks.drawWithFallbackExcluding(roomDeckId, excluded);
        expect(roomDeck.prompts).to.include(drawn);
        expect(excluded.has(drawn)).to.be.false;
      }
    });

    it("AC5.3: history covering both decks still returns a prompt and does not throw (terminal case)", () => {
      const roomDeckId = "real_life";
      const roomDeck = PromptDecks.getDeck(roomDeckId)!;
      const fallbackDeckId = PromptDecks.getFallbackDeckId();
      const fallbackDeck = PromptDecks.getDeck(fallbackDeckId)!;

      // Exclude all prompts in BOTH decks
      const allPrompts = new Set([...roomDeck.prompts, ...fallbackDeck.prompts]);
      const inPlay = new Set(roomDeck.prompts.slice(0, 3)); // 3 in play

      let drawn: string | undefined;
      expect(() => {
        drawn = PromptDecks.drawWithFallbackExcluding(roomDeckId, allPrompts, inPlay);
      }).to.not.throw();

      expect(drawn).to.be.a("string");
      expect(drawn!.length).to.be.greaterThan(0);
      // It relaxed, but must avoid prompts in play
      expect(inPlay.has(drawn!)).to.be.false;
    });

    it("AC5: draws from fallback deck when room deck unseen pool is completely exhausted", () => {
      const roomDeckId = "real_life";
      const roomDeck = PromptDecks.getDeck(roomDeckId)!;
      const fallbackDeckId = PromptDecks.getFallbackDeckId();
      const fallbackDeck = PromptDecks.getDeck(fallbackDeckId)!;

      // Exclude all prompts in room deck, none in fallback deck
      const excluded = new Set(roomDeck.prompts);
      const drawn = PromptDecks.drawWithFallbackExcluding(roomDeckId, excluded);

      expect(fallbackDeck.prompts).to.include(drawn);
      expect(roomDeck.prompts).to.not.include(drawn);
    });
  });
});

