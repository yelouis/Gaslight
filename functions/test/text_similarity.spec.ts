import { expect } from "chai";
import { isTooSimilar, normalize, stem } from "../src/text_similarity";

describe("Text Similarity Heuristic Tests (TS)", () => {
  describe("Normalization & Stemming", () => {
    it("should normalize string correctly", () => {
      expect(normalize("Sleeping!")).to.equal("sleeping");
      expect(normalize("hello   world!!")).to.equal("hello world");
    });

    it("should stem tokens correctly", () => {
      expect(stem("sleeping")).to.equal("sleep");
      expect(stem("played")).to.equal("play");
      expect(stem("places")).to.equal("plac");
      expect(stem("dogs")).to.equal("dog");
      expect(stem("class")).to.equal("class"); // ends in ss
      expect(stem("quickly")).to.equal("quick");
    });
  });

  describe("Worked cases matrix", () => {
    const testCases = [
      { candidate: "Sleeping!", existing: "sleeping", expected: true },
      { candidate: "sleeping in my bed all day", existing: "sleep all day in bed", expected: true },
      { candidate: "the dog ate the homework", existing: "my dog ate my homework", expected: true },
      { candidate: "pizza", existing: "pizza with pineapple", expected: false },
      { candidate: "a quick nap", existing: "sleeping", expected: false },
      { candidate: "went to the club", existing: "clubbing downtown", expected: false },
      { candidate: "hello world", existing: "", expected: false }
    ];

    testCases.forEach(({ candidate, existing, expected }) => {
      it(`should return ${expected} for candidate "${candidate}" and existing "${existing}"`, () => {
        expect(isTooSimilar(candidate, [existing])).to.equal(expected);
      });
    });
  });

  describe("Edge cases", () => {
    it("should handle empty arrays", () => {
      expect(isTooSimilar("hello", [])).to.equal(false);
    });

    it("should handle identical normalizations as reject", () => {
      expect(isTooSimilar("abc", ["abc"])).to.equal(true);
    });
  });
});
