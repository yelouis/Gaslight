// GENERATED FILE — DO NOT EDIT.
//
// Source of truth: functions/src/prompt_decks.ts
// Regenerate:      ./scripts/generate_prompt_decks_dart.sh
// Verified by:     ./scripts/check_decks_in_sync.sh (part of the battery)
//
// Hand-editing this file is how the decks silently diverged twice before:
// once the Dart copy was edited alone, once the TypeScript copy was. Add or
// change a deck in the .ts file and regenerate.

import 'dart:math';

/// Content rating for a deck. The seal COLOUR is a UI concern and lives in
/// `app_colors.dart` — this is only the token.
enum DeckRating { pg, r, x }

/// Everything the app knows about one deck. Mirrors `DeckDefinition` in the
/// TypeScript source.
class DeckDefinition {
  final String id;
  final String displayName;
  final DeckRating rating;
  final bool isFallback;
  final List<String> prompts;

  const DeckDefinition({
    required this.id,
    required this.displayName,
    required this.rating,
    required this.isFallback,
    required this.prompts,
  });
}

class PromptDecks {
  /// Declaration order matches the TypeScript source, so the lobby carousel
  /// shows decks in the order they are written there.
  static const List<DeckDefinition> allDecks = [
    DeckDefinition(
      id: 'hypotheticals',
      displayName: 'Hypotheticals',
      rating: DeckRating.pg,
      isFallback: true,
      prompts: [
        'The first thing I\'m stealing if looting becomes completely legal for one night.',
        'The dumbest reason I would end up getting kicked out of a cult.',
        'The weirdly specific side hustle I would start if I went completely broke tomorrow.',
        'The exact crime I\'d probably be convicted of in a dystopian future.',
        'The fake backstory and name I would use if I went into witness protection.',
        'The stupid minor issue I would make the centerpiece of my presidential campaign.',
        'The everyday annoying behavior I would make punishable by immediate jail time.',
        'The animal I honestly think I could take in a fistfight if my life depended on it.',
        'The petty reason I would refuse to save someone in a zombie apocalypse.',
        'The first thing I would buy with lottery money that would make people question my sanity.',
        'The bizarre rumor I would spread about myself if I became famous overnight.',
        'The weird hill I would die on during a high-stakes job interview.',
        'What I would actually do if I got accidentally locked inside a Target overnight.',
        'The completely useless superpower I would actually get the most mileage out of.',
        'The minor scam I could easily pull off if I had zero morals.',
        'The dumb thing I would spend a million dollars on before ever buying a house.',
        'The weird luxury I would insist on putting in my personal doomsday bunker.',
        'The reason my friends will probably have to stage an intervention for me in ten years.',
        'The ridiculous contest I would challenge the devil to for my own soul.',
        'The embarrassing passion project I would fund if I had unlimited billionaire money.',
        'The odd job I would be shockingly good at if I quit my career today.',
        'The petty lie I would tell on a reality dating show to cause maximum drama.',
        'The weird object in my house I would grab as a weapon during a break-in.',
        'The bizarre conspiracy theory I could probably be convinced is one hundred percent real.',
        'The useless, niche topic I could give an hour-long presentation on with zero prep.',
        'The ridiculous vanity project I would force a movie studio to let me star in.',
        'The mundane everyday chore I would hire a full-time assistant to handle for me.',
        'The stupidest bet I would actually agree to take for ten thousand dollars.',
        'The petty reason I\'d get fired on my very first day working retail or fast food.',
        'What I would bury in my backyard just to mess with future archaeologists.',
        'The oddly specific red flag that would make me climb out a restaurant bathroom window.',
        'The ridiculous backstage demand I would put in my contract rider as a touring artist.',
        'The exact scenario where I would completely sell out my moral principles for cash.',
        'The weird habit of mine that would immediately expose me as an alien impostor.',
        'The dumbest thing I would do if I had total invisibility for two hours.',
        'The terrible business idea I genuinely believe could make millions if someone funded it.',
        'The fake hobby I would invent just to sound cultured at a fancy party.',
        'The petty reason I would cut a family member completely out of my will.',
        'The role I would inevitably end up playing in a post-apocalyptic survivor settlement.',
        'The harmless lie about myself I plan on taking all the way to my grave.',
        'The weird item I would definitely try to smuggle through airport security.',
        'The minor annoyance I would ban nationwide on my first day in power.',
        'The completely irrational phobia that would get me killed first in a horror movie.',
        'The stupid internet argument that would actually tempt me to show up at someone\'s house.',
        'The chaotic text I would send to my group chats if an asteroid hit tomorrow.',
        'The trashy reality TV competition I would secretly dominate.',
        'The oddly specific task I would gladly pay someone two hundred dollars an hour to do.',
        'The dumb thing I would do with a time machine before fixing any historical events.',
        'The fake profession I would tell a stranger next to me on a long flight.',
        'The stupid mistake that would get me caught during an otherwise flawless bank heist.',
      ],
    ),
    DeckDefinition(
      id: 'real_life',
      displayName: 'Real Life',
      rating: DeckRating.pg,
      isFallback: false,
      prompts: [
        'The weirdest belief I had as a kid.',
        'The dumbest way I\'ve ever injured myself.',
        'A food combination I actually enjoy that grosses people out.',
        'The most embarrassing phase I went through growing up.',
        'My most irrational pet peeve.',
        'The pettiest reason I stopped talking to someone.',
        'The worst gift I\'ve ever received and pretended to like.',
        'The dumbest lie I ever told my parents.',
        'A weird habit I have when I\'m home alone.',
        'The most trouble I ever got into at school.',
        'A time I completely blanked on someone\'s name.',
        'The worst first impression I ever made on someone.',
        'Something I accidentally broke and never confessed to.',
        'The artist or guilty pleasure song I secretly listen to.',
        'The most useless item I spent my own money on.',
        'A trend I participated in that aged terribly.',
        'Something I pretend to understand just to fit in.',
        'The most awkward interaction I\'ve had with a stranger.',
        'The weirdest thing currently in my room or car.',
        'A bizarre hidden talent or useless skill I have.',
        'The longest I have ever gone without leaving my house.',
        'A popular movie or show that I secretly cannot stand.',
        'The worst haircut or style choice I\'ve ever had.',
        'A time I got completely lost in a place I knew well.',
        'My biggest irrational fear that makes no sense.',
      ],
    ),
    DeckDefinition(
      id: 'unhinged_quirks',
      displayName: 'Unhinged Quirks',
      rating: DeckRating.pg,
      isFallback: false,
      prompts: [
        'A weird habit I have when I think nobody is watching.',
        'The dumbest routine I do every single day.',
        'A normal food I eat in a completely wrong way.',
        'The imaginary argument I rehearse the most in the shower.',
        'Something stupid I do when I\'m bored alone in my room.',
        'A sound or texture that makes me unreasonably angry.',
        'The weirdest thing I do while pacing on the phone.',
        'A ridiculous personal rule I follow that makes zero sense.',
        'The random thing I hoard and stubbornly refuse to throw away.',
        'A habit of mine that would drive a roommate crazy.',
        'The strange way I organize something or do a basic chore.',
        'Something I have to do before bed or I can\'t sleep.',
        'A totally normal phrase or noise that instantly annoys me.',
        'The random hobby I obsessed over for two weeks and then dropped forever.',
        'The trick I use to avoid making small talk with people in public.',
        'The weirdest thing I\'ve caught myself doing on autopilot.',
        'A superstition I claim not to believe in but still follow anyway.',
        'Something petty that immediately makes me judge a person.',
        'The song or short video I\'ve listened to on loop an embarrassing amount.',
        'A basic everyday task I do in a backwards way.',
        'The irrational thing I do whenever I get slightly stressed out.',
        'A weird food order or modification I insist on every time.',
        'The random topic I could rant about for an hour with zero prep.',
        'The weirdest note or search tab currently open on my phone.',
        'The absurdly over-the-top way I react to a minor inconvenience.',
      ],
    ),
    DeckDefinition(
      id: 'love_life',
      displayName: 'Love Life',
      rating: DeckRating.pg,
      isFallback: false,
      prompts: [
        'The most awkward first date I\'ve ever been on.',
        'The pettiest romantic ick that immediately turned me off.',
        'The most cringe thing I did to impress a crush.',
        'The worst gift I\'ve ever given or received in a relationship.',
        'A time a date went so badly I actively looked for an escape.',
        'The dumbest reason I ever broke up with someone.',
        'The weirdest thing I\'ve found while snooping on a crush\'s profile.',
        'The most embarrassing romantic rejection I\'ve ever experienced.',
        'A cliché romantic gesture I secretly love.',
        'The worst outfit I wore on a date thinking I looked great.',
        'The strangest place I\'ve ever gone on a date.',
        'A time I accidentally completely ruined a romantic moment.',
        'The obvious red flag I ignored for way too long.',
        'The most dramatic argument I\'ve had over something tiny with a partner.',
        'The weirdest habit I learned about someone after staying at their place.',
        'The most embarrassing pet name I\'ve ever been called or used.',
        'The worst excuse I used to turn down a second date.',
        'A weird celebrity crush I had that makes no sense.',
        'A time I caught feelings for someone at the worst possible time.',
        'The most awkward interaction I\'ve had with a partner\'s parents.',
        'The most desperate thing I did right after a breakup.',
        'A bizarre dealbreaker I secretly have when dating.',
        'The worst dating advice a friend gave me that I actually followed.',
        'A lie I told on a date just to seem more interesting.',
        'The quickest I have ever lost interest in someone.',
      ],
    ),
    DeckDefinition(
      id: 'rated_r_nsfw',
      displayName: 'Rated R NSFW',
      rating: DeckRating.r,
      isFallback: false,
      prompts: [
        'The most desperate public bathroom emergency I barely survived.',
        'The weirdest thing in my private browsing history that I\'d die if someone saw.',
        'The most humiliating accidental nudity moment I\'ve ever experienced.',
        'The absolute grossest personal hygiene shortcut I take when nobody is around.',
        'The political figure or president I\'d reluctantly sleep with to save humanity.',
        'The most NSFW thing I\'ve ever done in a semi-public place.',
        'The most embarrassing item a bag checker or TSA agent has pulled out of my luggage.',
        'The lowest amount of money I\'d accept to publicly stream my entire camera roll.',
        'The weirdest object I\'ve used as makeshift toilet paper in an emergency.',
        'A time someone walked in on me at the absolute worst possible moment.',
        'The most humiliating bodily malfunction I\'ve had during a quiet, crowded event.',
        'The longest I have ever gone without showering or changing my clothes.',
        'The most NSFW thing I accidentally broadcasted onto a shared screen or speaker.',
        'The grossest thing I\'ve eaten off the floor or out of desperation.',
        'The sketchiest place I\'ve peed or thrown up in public.',
        'The absolute worst or most forbidden person I\'ve had a fleeting dirty thought about.',
        'The most degenerate thing I\'ve done while drunk or blacked out.',
        'The grossest injury, rash, or infection I stubbornly ignored for way too long.',
        'The most unhinged thing currently sitting in my phone\'s hidden album.',
        'The absolute lowest, dirtiest state my bedroom or bathroom has ever reached.',
        'The pettiest reason I immediately lost attraction right before hooking up.',
        'The weirdest thing I would let someone pay me five thousand dollars to do.',
        'The most awkward walk of shame or late-night escape I\'ve ever made.',
        'The degenerate vice or bad habit I spend way too much money hiding.',
        'A time an intimate or serious moment was completely ruined by an unsexy bodily noise.',
      ],
    ),
  ];

  static final Map<String, DeckDefinition> _byId = {
    for (final d in allDecks) d.id: d,
  };

  /// The deck used when no chosen deck applies: the default for a new room,
  /// the top-up pool for custom decks, and the source for re-rolls in a custom
  /// game. Declared in the TypeScript source via `isFallback`.
  static const String fallbackDeckId = 'hypotheticals';

  static int getDeckSize(String deckId) => _byId[deckId]?.prompts.length ?? 0;

  /// Deck IDs in declaration order.
  static List<String> get availableDecks =>
      allDecks.map((d) => d.id).toList();

  /// The name players see. Declared per-deck, NOT derived from the id —
  /// splitting `rated_r_nsfw` on underscores renders it as 'Rated R Nsfw'.
  static String getDeckName(String deckId) =>
      _byId[deckId]?.displayName ?? deckId;

  static DeckRating? getDeckRating(String deckId) => _byId[deckId]?.rating;

  static DeckDefinition? getDeck(String deckId) => _byId[deckId];

  /// Pulls [count] randomly selected unique prompts from [deckId].
  static List<String> drawPrompts(String deckId, int count) {
    final deck = _byId[deckId];
    if (deck == null) {
      throw Exception('Failed to load deck: \$deckId. Ensure it is defined in PromptDecks.');
    }

    final deckCopy = List<String>.from(deck.prompts)..shuffle(Random());
    if (count > deckCopy.length) {
      throw Exception('Not enough prompts in the deck for \$count players. Max is \${deckCopy.length}.');
    }
    return deckCopy.sublist(0, count);
  }

  /// Draws one prompt, preferring anything outside [excludedPrompts].
  ///
  /// Re-rolls are unlimited: once every prompt has been seen this repeats one
  /// rather than refusing. [mustAvoid] survives that fallback so a re-roll
  /// always visibly changes something. Only a missing deck throws.
  static String drawOneExcluding(
    String deckId,
    Set<String> excludedPrompts, [
    Set<String> mustAvoid = const {},
  ]) {
    final entry = _byId[deckId];
    if (entry == null) {
      throw Exception('Failed to load deck: \$deckId. Ensure it is defined in PromptDecks.');
    }

    final deck = entry.prompts;
    String pick(List<String> xs) => (xs.toList()..shuffle(Random())).first;

    final preferred = deck.where((p) => !excludedPrompts.contains(p)).toList();
    if (preferred.isNotEmpty) return pick(preferred);

    final relaxed = deck.where((p) => !mustAvoid.contains(p)).toList();
    if (relaxed.isNotEmpty) return pick(relaxed);

    return pick(deck);
  }
}
