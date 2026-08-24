import { HttpsError } from "firebase-functions/v2/https";

const DECKS: Record<string, string[]> = {
  the_daily_grind: [
    "The most embarrassing thing I've ever done on a Zoom call.",
    "The worst excuse I've used to call out of work.",
    "A time I lied about my skills to get a job or project.",
    "The most ridiculous thing I've expensed on a company card.",
    "The biggest mistake I made at work and successfully hid.",
    "A time I actually fell asleep during a meeting.",
    "The most unprofessional thing I've done at a holiday party.",
    "A situation where I completely faked my way through a presentation.",
    "The pettiest reason I've disliked a coworker.",
    "A time I gossiped about a boss and got caught.",
    "The dumbest rule I enforced just because I had the power.",
    "A time I pretended to understand a concept for months.",
    "The most inappropriate place I've taken a business call.",
    "A time I stole someone else's lunch from the fridge.",
    "The longest I've gone working without actually doing any work.",
    "A time I accidentally hit 'reply-all' and regretted it.",
    "The worst lie I told to get out of an after-work event.",
    "A time I cried at work over something completely insignificant.",
    "The weirdest coworker interaction I've ever had.",
    "A time I took credit for someone else's idea."
  ],
  deep_fears_and_phobias: [
    "An irrational fear I have about ordinary household objects.",
    "The weirdest scenario I regularly play out in my head before sleeping.",
    "A common animal that completely terrifies me.",
    "The most embarrassing thing I'm afraid of in the dark.",
    "A fear I have that makes absolutely no logical sense.",
    "The weirdest superstition I secretly believe in.",
    "A time my irrational fear caused a public scene.",
    "The most ridiculous thing I check before leaving the house.",
    "A specific noise that instantly sends me into a panic.",
    "The weirdest intrusive thought I've had while driving.",
    "A fear I've lied about not having so I wouldn't look stupid.",
    "The most uncomfortable situation I've avoided out of pure phobia.",
    "An irrational reason I refused to go into a body of water.",
    "The most bizarre reason I've been afraid of a piece of technology.",
    "A childhood fear I still secretly have.",
    "The weirdest way I prepare for the 'worst-case scenario'.",
    "A time I let a phobia ruin a fun event.",
    "The most irrational thought I've had on an airplane.",
    "A fear I have about going to the doctor.",
    "The weirdest fear I have about the afterlife."
  ],
  unhinged_quirks: [
    "The weirdest food combination I genuinely enjoy.",
    "A hyper-fixation I had at 2 AM that lasted for exactly one night.",
    "The strangest habit I have when I am completely alone.",
    "A bizarre routine I must do before going to sleep.",
    "The most unhinged thing I do when I think nobody is watching.",
    "A weird physical quirk I have that people find disturbing.",
    "The most ridiculous thing I've searched for on the internet.",
    "A weird sound I make when I am focused.",
    "The strangest thing I collect or hoard.",
    "A bizarre way I eat a very common food.",
    "The most unhinged criteria I have for dating someone.",
    "A weird place I prefer to sit or lay down in my house.",
    "The strangest thing I do in front of the mirror.",
    "A completely nonsensical preference I have for clothing.",
    "The most ridiculous thing I enthusiastically talk to my pets about.",
    "A bizarre superstition I have regarding numbers or counting.",
    "The weirdest thing that instantly makes me angry.",
    "A bizarre way I show affection to my friends.",
    "The most unhinged lie I told just to avoid explaining a quirk.",
    "A weird thing I do when I am nervous or lying."
  ],
  romantic_disasters: [
    "The absolutely worst first date I've ever been on.",
    "The most cringe-inducing text message I've sent a crush.",
    "A time I tried to impress someone and failed miserably.",
    "The pettiest reason I decided to break up with someone.",
    "The most embarrassing thing that happened to me during a hookup.",
    "A time I realized mid-date that the person was completely unhinged.",
    "The worst lie I've told to reject someone's advances.",
    "A situation where I was definitely the toxic one in the relationship.",
    "The most awkward encounter I've had with an ex.",
    "A time I accidentally insulted my date without realizing it.",
    "The most desperate thing I've done to get someone's attention.",
    "A weird dealbreaker I have that no one understands.",
    "The worst place I've ever taken someone for a date.",
    "A time I got caught stalking a crush on social media.",
    "The most inappropriate time I've ever developed feelings for someone.",
    "A bizarre assumption I made about a partner that was totally wrong.",
    "The worst gift I have ever given or received in a relationship.",
    "A time I cried for a stupid reason in front of a date.",
    "The most awkward 'meet the parents' story I possess.",
    "A time I accidentally set up a date with the wrong person."
  ],
  rated_r_nsfw: [
    "What's your most embarassing moment?",
    "If you had to sleep with a president, who would it be?",
    "What would be the name of your biography?",
    "What would you take to a dessert island? (can't be a way off)",
    "What will you name your first kid?",
    "Which celebrity do you think you're most like?",
    "What was the last dream you remember?",
    "When was the last time you shit your pants?",
    "Where was your most dangerous near-death experience?",
    "What's the strangest food you've eaten?",
    "Who are you most likely to assassinate?",
    "What did you want to be growing up?",
    "What's your favorite holiday destination?",
    "Who was your first celebrity crush?",
    "What's the most NSFW thing you've done in public?",
    "Which cartoon character would you want to date?",
    "What's the best thing you can cook?",
    "What would your dream house include?",
    "What's your most embarassing item of clothing?",
    "The worst way I've lost money is…",
    "The most embarassing thing I've spent money on",
    "What's the last thing you've broken?",
    "What's the closest to a serious crime you've ever been?",
    "What's been your greatest success in the last year?"
  ],
  cah_dark_humor: [
    "The absolute worst thing to say at a funeral.",
    "A highly inappropriate theme for a children's birthday party.",
    "The real reason the dinosaurs went extinct.",
    "A terrible advertising slogan for a brand of baby food.",
    "The most offensive gift you could bring to a housewarming party.",
    "What is secretly hiding under the host's floorboards.",
    "The worst candidate for a modern saint.",
    "A dark secret that would immediately cancel a politician.",
    "The real reason I am going to hell.",
    "A terrible topic to bring up on a first date.",
    "What my future biographer will write to summarize my life choices.",
    "The weirdest item to put in a time capsule for future generations."
  ],
};

export class PromptDecks {
  static getDeckSize(deckId: string): number {
    return DECKS[deckId]?.length || 0;
  }

  static getAvailableDecks(): string[] {
    return Object.keys(DECKS);
  }

  static drawPrompts(deckId: string, count: number): string[] {
    if (!DECKS[deckId]) {
      throw new Error(`Failed to load deck: ${deckId}. Ensure it is defined in PromptDecks.`);
    }

    const deckCopy = [...DECKS[deckId]];
    // Shuffle using Fisher-Yates
    for (let i = deckCopy.length - 1; i > 0; i--) {
      const j = Math.floor(Math.random() * (i + 1));
      [deckCopy[i], deckCopy[j]] = [deckCopy[j], deckCopy[i]];
    }

    if (count > deckCopy.length) {
      throw new Error(`Not enough prompts in the deck for ${count} players. Max is ${deckCopy.length}.`);
    }

    return deckCopy.slice(0, count);
  }

  /// Draws one prompt, preferring anything not in [excludedPrompts].
  ///
  /// Re-rolls are unlimited: once a player has seen everything the deck holds,
  /// this repeats a prompt rather than refusing. [mustAvoid] is the harder
  /// bound that survives that fallback - pass the prompts that are live on
  /// other cards right now plus the one already on this card, so a re-roll
  /// always visibly changes something and two players never share a prompt.
  ///
  /// Only a missing deck throws. This used to throw `resource-exhausted` when
  /// the deck ran dry, which surfaced to the player as a dead end mid-game.
  static drawOneExcluding(
    deckId: string,
    excludedPrompts: Set<string>,
    mustAvoid: Set<string> = new Set()
  ): string {
    if (!DECKS[deckId]) {
      throw new HttpsError("not-found", `Failed to load deck: ${deckId}. Ensure it is defined in PromptDecks.`);
    }

    const deck = DECKS[deckId];
    const pick = (xs: string[]) => xs[Math.floor(Math.random() * xs.length)];

    const preferred = deck.filter((p) => !excludedPrompts.has(p));
    if (preferred.length > 0) return pick(preferred);

    const relaxed = deck.filter((p) => !mustAvoid.has(p));
    if (relaxed.length > 0) return pick(relaxed);

    // Deck smaller than the table: nothing left to vary by.
    return pick(deck);
  }
}
