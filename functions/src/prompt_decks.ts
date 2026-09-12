import { HttpsError } from "firebase-functions/v2/https";

/**
 * THE SOURCE OF TRUTH FOR DECKS.
 *
 * Everything the app knows about a deck lives here: its id, the name players
 * see, its content rating, and its prompts. No other file may branch on a deck
 * id. To add a deck, append a DeckDefinition below and regenerate the Dart
 * mirror (see below) - nothing else needs editing.
 *
 * The Flutter client reads a GENERATED copy at lib/utils/prompt_decks.dart.
 * Regenerate it with:  ./scripts/generate_prompt_decks_dart.sh
 * ./scripts/check_decks_in_sync.sh fails the battery if it is stale.
 */

/** Content rating. The seal COLOUR is a UI concern and lives in app_colors.dart. */
export type DeckRating = "PG" | "R" | "X";

export interface DeckDefinition {
  id: string;
  /** Shown to players. Not derived from the id - "rated_r_nsfw" would render as "Rated R Nsfw". */
  displayName: string;
  rating: DeckRating;
  /**
   * The deck used when no chosen deck applies: the default for a new room,
   * the top-up pool for custom decks, and the source for re-rolls in a custom
   * game. EXACTLY ONE deck must set this - getFallbackDeckId() throws otherwise.
   * Prefer the largest deck, since custom top-up draws from it.
   */
  isFallback?: boolean;
  prompts: string[];
  /** Optional sample answers, keyed by the EXACT prompt text they belong to. */
  samples?: Record<string, string[]>;
}

const DECK_LIST: DeckDefinition[] = [
  {
    id: "hypotheticals",
    displayName: "Hypotheticals",
    rating: "PG",
    isFallback: true,
    prompts: [
      "The first thing I'm stealing if looting becomes completely legal for one night.",
      "The dumbest reason I would end up getting kicked out of a cult.",
      "The weirdly specific side hustle I would start if I went completely broke tomorrow.",
      "The exact crime I'd probably be convicted of in a dystopian future.",
      "The fake backstory and name I would use if I went into witness protection.",
      "The stupid minor issue I would make the centerpiece of my presidential campaign.",
      "The everyday annoying behavior I would make punishable by immediate jail time.",
      "The animal I honestly think I could take in a fistfight if my life depended on it.",
      "The petty reason I would refuse to save someone in a zombie apocalypse.",
      "The first thing I would buy with lottery money that would make people question my sanity.",
      "The bizarre rumor I would spread about myself if I became famous overnight.",
      "The weird hill I would die on during a high-stakes job interview.",
      "What I would actually do if I got accidentally locked inside a Target overnight.",
      "The completely useless superpower I would actually get the most mileage out of.",
      "The minor scam I could easily pull off if I had zero morals.",
      "The dumb thing I would spend a million dollars on before ever buying a house.",
      "The weird luxury I would insist on putting in my personal doomsday bunker.",
      "The reason my friends will probably have to stage an intervention for me in ten years.",
      "The ridiculous contest I would challenge the devil to for my own soul.",
      "The embarrassing passion project I would fund if I had unlimited billionaire money.",
      "The odd job I would be shockingly good at if I quit my career today.",
      "The petty lie I would tell on a reality dating show to cause maximum drama.",
      "The weird object in my house I would grab as a weapon during a break-in.",
      "The bizarre conspiracy theory I could probably be convinced is one hundred percent real.",
      "The useless, niche topic I could give an hour-long presentation on with zero prep.",
      "The ridiculous vanity project I would force a movie studio to let me star in.",
      "The mundane everyday chore I would hire a full-time assistant to handle for me.",
      "The stupidest bet I would actually agree to take for ten thousand dollars.",
      "The petty reason I'd get fired on my very first day working retail or fast food.",
      "What I would bury in my backyard just to mess with future archaeologists.",
      "The oddly specific red flag that would make me climb out a restaurant bathroom window.",
      "The ridiculous backstage demand I would put in my contract rider as a touring artist.",
      "The exact scenario where I would completely sell out my moral principles for cash.",
      "The weird habit of mine that would immediately expose me as an alien impostor.",
      "The dumbest thing I would do if I had total invisibility for two hours.",
      "The terrible business idea I genuinely believe could make millions if someone funded it.",
      "The fake hobby I would invent just to sound cultured at a fancy party.",
      "The petty reason I would cut a family member completely out of my will.",
      "The role I would inevitably end up playing in a post-apocalyptic survivor settlement.",
      "The harmless lie about myself I plan on taking all the way to my grave.",
      "The weird item I would definitely try to smuggle through airport security.",
      "The minor annoyance I would ban nationwide on my first day in power.",
      "The completely irrational phobia that would get me killed first in a horror movie.",
      "The stupid internet argument that would actually tempt me to show up at someone's house.",
      "The chaotic text I would send to my group chats if an asteroid hit tomorrow.",
      "The trashy reality TV competition I would secretly dominate.",
      "The oddly specific task I would gladly pay someone two hundred dollars an hour to do.",
      "The dumb thing I would do with a time machine before fixing any historical events.",
      "The fake profession I would tell a stranger next to me on a long flight.",
      "The stupid mistake that would get me caught during an otherwise flawless bank heist."
    ],
    samples: {
      "The first thing I'm stealing if looting becomes completely legal for one night.": [
        "A commercial wheel of aged parmesan and two espresso machines",
      ],
      "The dumbest reason I would end up getting kicked out of a cult.": [
        "Demanding a spreadsheet audit of where our commune dues were going",
      ],
      "The weirdly specific side hustle I would start if I went completely broke tomorrow.": [
        "Ghostwriting strongly worded HOA complaint letters for petty neighbors",
      ],
      "The exact crime I'd probably be convicted of in a dystopian future.": [
        "Hoarding unapproved heirloom tomato seeds in an underground cellar",
      ],
      "The fake backstory and name I would use if I went into witness protection.": [
        "Barnaby Thorne, a melancholic antique clock restorer from Vermont",
      ],
      "The stupid minor issue I would make the centerpiece of my presidential campaign.": [
        "Mandatory roundabouts at every four-way stop in the contiguous states",
      ],
      "The everyday annoying behavior I would make punishable by immediate jail time.": [
        "FaceTiming on speakerphone while standing in a checkout line",
      ],
      "The animal I honestly think I could take in a fistfight if my life depended on it.": [
        "A moderately fatigued Canadian goose with poor depth perception",
      ],
      "The petty reason I would refuse to save someone in a zombie apocalypse.": [
        "They microwave raw tilapia in the communal office breakroom",
      ],
      "The first thing I would buy with lottery money that would make people question my sanity.": [
        "A full-scale decommissioned lighthouse on a landlocked cattle ranch",
      ],
      "The bizarre rumor I would spread about myself if I became famous overnight.": [
        "I lost my real index finger in a duel over a vintage fountain pen",
      ],
      "The weird hill I would die on during a high-stakes job interview.": [
        "Refusing to acknowledge the open-plan office as a valid human environment",
      ],
      "What I would actually do if I got accidentally locked inside a Target overnight.": [
        "Build a multi-room blanket fortress in home goods and sleep until dawn",
      ],
      "The completely useless superpower I would actually get the most mileage out of.": [
        "Knowing the exact temperature of any lukewarm beverage from across the room",
      ],
      "The minor scam I could easily pull off if I had zero morals.": [
        "Selling authentic cursed Victorian buttons to wealthy occult tourists",
      ],
      "The dumb thing I would spend a million dollars on before ever buying a house.": [
        "A subterranean wine cellar stocked exclusively with vintage cream soda",
      ],
      "The weird luxury I would insist on putting in my personal doomsday bunker.": [
        "A custom heated bidet and a soundproof room for screaming into pillows",
      ],
      "The reason my friends will probably have to stage an intervention for me in ten years.": [
        "My attic contains four hundred unlabeled vintage mechanical typewriters",
      ],
      "The ridiculous contest I would challenge the devil to for my own soul.": [
        "A no-holds-barred competitive game of four-player Mario Kart on Rainbow Road",
      ],
      "The embarrassing passion project I would fund if I had unlimited billionaire money.": [
        "A prestige HBO miniseries about the scandalous patent disputes over the paperclip",
      ],
      "The odd job I would be shockingly good at if I quit my career today.": [
        "Professional estate sale appraiser who specializes in haunted silverware",
      ],
      "The petty lie I would tell on a reality dating show to cause maximum drama.": [
        "Whispering that I saw the frontrunner drinking milk straight from the carton",
      ],
      "The weird object in my house I would grab as a weapon during a break-in.": [
        "A ten-pound frozen block of sourdough starter from the deep freezer",
      ],
      "The bizarre conspiracy theory I could probably be convinced is one hundred percent real.": [
        "Mattress stores are financial fronts operating on an intergalactic barter system",
      ],
      "The useless, niche topic I could give an hour-long presentation on with zero prep.": [
        "The catastrophic industrial design failures of turn-of-the-century tea infusers",
      ],
      "The ridiculous vanity project I would force a movie studio to let me star in.": [
        "A brooding period drama where I play a reclusive lighthouse keeper who speaks Latin",
      ],
      "The mundane everyday chore I would hire a full-time assistant to handle for me.": [
        "Breaking down corrugated delivery boxes and peeling off shipping labels",
      ],
      "The stupidest bet I would actually agree to take for ten thousand dollars.": [
        "Eating a single ghost pepper while delivering a twenty-minute funeral eulogy",
      ],
      "The petty reason I'd get fired on my very first day working retail or fast food.": [
        "Refusing to say the required promotional greeting because it felt degrading",
      ],
      "What I would bury in my backyard just to mess with future archaeologists.": [
        "A bronze bust of myself wearing novelty sunglasses inside a locked lead chest",
      ],
      "The oddly specific red flag that would make me climb out a restaurant bathroom window.": [
        "They casually announce they manage an astrology-based cryptocurrency portfolio",
      ],
      "The ridiculous backstage demand I would put in my contract rider as a touring artist.": [
        "A bowl of M&Ms sorted strictly by wavelength and six room-temperature lemons",
      ],
      "The exact scenario where I would completely sell out my moral principles for cash.": [
        "Someone offering eight figures to endorse a luxury yacht wax on television",
      ],
      "The weird habit of mine that would immediately expose me as an alien impostor.": [
        "Eating the entire kiwi fruit whole, skin, fuzz, stem, and all",
      ],
      "The dumbest thing I would do if I had total invisibility for two hours.": [
        "Rearranging every book in a stranger's living room by shade of green",
      ],
      "The terrible business idea I genuinely believe could make millions if someone funded it.": [
        "A subscription service that sends you a random antique key once a month",
      ],
      "The fake hobby I would invent just to sound cultured at a fancy party.": [
        "Bespoke artisanal bookbinding using only reclaimed library leather",
      ],
      "The petty reason I would cut a family member completely out of my will.": [
        "They dog-eared the pages of my signed first-edition hardcovers",
      ],
      "The role I would inevitably end up playing in a post-apocalyptic survivor settlement.": [
        "The eccentric librarian who refuses to ration candles because reading is survival",
      ],
      "The harmless lie about myself I plan on taking all the way to my grave.": [
        "I told everyone I speak fluent conversational French after six Duolingo lessons",
      ],
      "The weird item I would definitely try to smuggle through airport security.": [
        "Three jars of unpasteurized artisanal plum preserves wrapped in wool socks",
      ],
      "The minor annoyance I would ban nationwide on my first day in power.": [
        "Supermarket carts with one stubborn wheel that spins violently sideways",
      ],
      "The completely irrational phobia that would get me killed first in a horror movie.": [
        "Refusing to sprint across gravel barefoot because the texture gives me goosebumps",
      ],
      "The stupid internet argument that would actually tempt me to show up at someone's house.": [
        "A stranger asserting that deep-dish pizza qualifies as a savory open-faced pie",
      ],
      "The chaotic text I would send to my group chats if an asteroid hit tomorrow.": [
        "I knew about this three weeks ago and invested heavily in canned beans. Farewell.",
      ],
      "The trashy reality TV competition I would secretly dominate.": [
        "A high-stakes blindfolded cake decorating show judged by angry pastry chefs",
      ],
      "The oddly specific task I would gladly pay someone two hundred dollars an hour to do.": [
        "Untangling three years of coiled holiday string lights and audio cables",
      ],
      "The dumb thing I would do with a time machine before fixing any historical events.": [
        "Go back to 1998 just to taste the original recipe McDonald's Szechuan sauce",
      ],
      "The fake profession I would tell a stranger next to me on a long flight.": [
        "Independent quality inspector for commercial carousel horse upholstery",
      ],
      "The stupid mistake that would get me caught during an otherwise flawless bank heist.": [
        "Stopping to adjust a crooked framed landscape painting in the manager's office",
      ],
    },

  },
  {
    id: "real_life",
    displayName: "Real Life",
    rating: "PG",
    prompts: [
      "The weirdest belief I had as a kid.",
      "The dumbest way I've ever injured myself.",
      "A food combination I actually enjoy that grosses people out.",
      "The most embarrassing phase I went through growing up.",
      "My most irrational pet peeve.",
      "The pettiest reason I stopped talking to someone.",
      "The worst gift I've ever received and pretended to like.",
      "The dumbest lie I ever told my parents.",
      "A weird habit I have when I'm home alone.",
      "The most trouble I ever got into at school.",
      "A time I completely blanked on someone's name.",
      "The worst first impression I ever made on someone.",
      "Something I accidentally broke and never confessed to.",
      "The artist or guilty pleasure song I secretly listen to.",
      "The most useless item I spent my own money on.",
      "A trend I participated in that aged terribly.",
      "Something I pretend to understand just to fit in.",
      "The most awkward interaction I've had with a stranger.",
      "The weirdest thing currently in my room or car.",
      "A bizarre hidden talent or useless skill I have.",
      "The longest I have ever gone without leaving my house.",
      "A popular movie or show that I secretly cannot stand.",
      "The worst haircut or style choice I've ever had.",
      "A time I got completely lost in a place I knew well.",
      "My biggest irrational fear that makes no sense."
    ],
    samples: {
      "The weirdest belief I had as a kid.": [
        "That quicksand was an unavoidable daily peril facing modern commuters",
      ],
      "The dumbest way I've ever injured myself.": [
        "Dislocating my shoulder while aggressively celebrating a miniature golf putt",
      ],
      "A food combination I actually enjoy that grosses people out.": [
        "Dipping cold cheddar cheese slices directly into crunchy peanut butter",
      ],
      "The most embarrassing phase I went through growing up.": [
        "Wearing a three-piece tweed vest and carrying an empty pocket watch to middle school",
      ],
      "My most irrational pet peeve.": [
        "When someone leaves exactly four seconds remaining on the microwave timer",
      ],
      "The pettiest reason I stopped talking to someone.": [
        "They sent a three-minute voice note that could have been four words of text",
      ],
      "The worst gift I've ever received and pretended to like.": [
        "A battery-operated singing bass mounted on a faux mahogany plaque",
      ],
      "The dumbest lie I ever told my parents.": [
        "Claiming the neighbor's outdoor cat came inside and drank all the chocolate milk",
      ],
      "A weird habit I have when I'm home alone.": [
        "Narrating all of my kitchen cooking steps like a furious Michelin-starred chef",
      ],
      "The most trouble I ever got into at school.": [
        "Setting up an illicit black market trade network for contraband sour candy",
      ],
      "A time I completely blanked on someone's name.": [
        "Calling my own cousin 'pal' for an entire four-hour family Thanksgiving dinner",
      ],
      "The worst first impression I ever made on someone.": [
        "Sneezing directly into my palms right before extending a formal handshake",
      ],
      "Something I accidentally broke and never confessed to.": [
        "Cracking the bottom of an heirloom crystal vase and rotating it toward the wall",
      ],
      "The artist or guilty pleasure song I secretly listen to.": [
        "Carly Rae Jepsen's entire discography on maximum volume with headphones",
      ],
      "The most useless item I spent my own money on.": [
        "An antique brass monocular that can only focus on objects eighteen inches away",
      ],
      "A trend I participated in that aged terribly.": [
        "Planking across random public railings in 2011 for Facebook photo albums",
      ],
      "Something I pretend to understand just to fit in.": [
        "The intricate geopolitical dynamics of European soccer transfer windows",
      ],
      "The most awkward interaction I've had with a stranger.": [
        "Saying 'You too!' after a movie theater usher handed me my ticket and said 'Enjoy!'",
      ],
      "The weirdest thing currently in my room or car.": [
        "A bag of ceramic doll heads I bought for an art project five years ago",
      ],
      "A bizarre hidden talent or useless skill I have.": [
        "Identifying any 90s animated movie soundtrack from the first two drum beats",
      ],
      "The longest I have ever gone without leaving my house.": [
        "Six consecutive days existing solely on instant ramen and detective documentaries",
      ],
      "A popular movie or show that I secretly cannot stand.": [
        "The Office, because the ambient secondhand embarrassment makes my skin crawl",
      ],
      "The worst haircut or style choice I've ever had.": [
        "A DIY asymmetrical bowl cut inspired by a poorly lit Pinterest photograph",
      ],
      "A time I got completely lost in a place I knew well.": [
        "Taking three wrong turns in the subterranean parking garage of my own apartment",
      ],
      "My biggest irrational fear that makes no sense.": [
        "Stepping on an escalator and being sucked into the grinding gears beneath",
      ],
    },

  },
  {
    id: "unhinged_quirks",
    displayName: "Unhinged Quirks",
    rating: "PG",
    prompts: [
      "A weird habit I have when I think nobody is watching.",
      "The dumbest routine I do every single day.",
      "A normal food I eat in a completely wrong way.",
      "The imaginary argument I rehearse the most in the shower.",
      "Something stupid I do when I'm bored alone in my room.",
      "A sound or texture that makes me unreasonably angry.",
      "The weirdest thing I do while pacing on the phone.",
      "A ridiculous personal rule I follow that makes zero sense.",
      "The random thing I hoard and stubbornly refuse to throw away.",
      "A habit of mine that would drive a roommate crazy.",
      "The strange way I organize something or do a basic chore.",
      "Something I have to do before bed or I can't sleep.",
      "A totally normal phrase or noise that instantly annoys me.",
      "The random hobby I obsessed over for two weeks and then dropped forever.",
      "The trick I use to avoid making small talk with people in public.",
      "The weirdest thing I've caught myself doing on autopilot.",
      "A superstition I claim not to believe in but still follow anyway.",
      "Something petty that immediately makes me judge a person.",
      "The song or short video I've listened to on loop an embarrassing amount.",
      "A basic everyday task I do in a backwards way.",
      "The irrational thing I do whenever I get slightly stressed out.",
      "A weird food order or modification I insist on every time.",
      "The random topic I could rant about for an hour with zero prep.",
      "The weirdest note or search tab currently open on my phone.",
      "The absurdly over-the-top way I react to a minor inconvenience."
    ],
    samples: {
      "A weird habit I have when I think nobody is watching.": [
        "Testing whether I can open sliding automatic doors using only the Force",
      ],
      "The dumbest routine I do every single day.": [
        "Checking that my front door is deadbolted three times before walking down the hall",
      ],
      "A normal food I eat in a completely wrong way.": [
        "Peeling all the breading off chicken nuggets and eating it like crispy paper",
      ],
      "The imaginary argument I rehearse the most in the shower.": [
        "Debating a hypothetical rude barista about the proper extraction time of cold brew",
      ],
      "Something stupid I do when I'm bored alone in my room.": [
        "Balancing random desk objects on the back of my hand until they collapse",
      ],
      "A sound or texture that makes me unreasonably angry.": [
        "Dry microfiber cloths snagging against the microscopic rough skin of my thumbs",
      ],
      "The weirdest thing I do while pacing on the phone.": [
        "Circling my dining room table forty times while picking lint off the rug",
      ],
      "A ridiculous personal rule I follow that makes zero sense.": [
        "Never putting the volume knob on an odd number unless it is a multiple of five",
      ],
      "The random thing I hoard and stubbornly refuse to throw away.": [
        "Sturdy corrugated cardboard boxes that might be the exact right size someday",
      ],
      "A habit of mine that would drive a roommate crazy.": [
        "Leaving two sips of water in twelve identical mugs scattered across every counter",
      ],
      "The strange way I organize something or do a basic chore.": [
        "Sorting dirty laundry strictly by fabric weight rather than color or wash cycle",
      ],
      "Something I have to do before bed or I can't sleep.": [
        "Tucking the comforter so tightly beneath my feet that I cannot wiggle my toes",
      ],
      "A totally normal phrase or noise that instantly annoys me.": [
        "Anyone beginning an email with the cheerful phrase 'Happy Monday!'",
      ],
      "The random hobby I obsessed over for two weeks and then dropped forever.": [
        "Hand-carving artisanal wooden spoons from fallen backyard birch branches",
      ],
      "The trick I use to avoid making small talk with people in public.": [
        "Wearing bulky noise-canceling headphones that are completely switched off",
      ],
      "The weirdest thing I've caught myself doing on autopilot.": [
        "Putting the carton of milk into the pantry and the cereal box into the fridge",
      ],
      "A superstition I claim not to believe in but still follow anyway.": [
        "Saluting solitary magpies and holding my breath while driving past cemeteries",
      ],
      "Something petty that immediately makes me judge a person.": [
        "Dog-earing paperback corners instead of using a receipt as a bookmark",
      ],
      "The song or short video I've listened to on loop an embarrassing amount.": [
        "A twenty-second audio clip of a medieval lute cover of a pop song",
      ],
      "A basic everyday task I do in a backwards way.": [
        "Putting on my socks before putting on my pants so my ankles stay warm",
      ],
      "The irrational thing I do whenever I get slightly stressed out.": [
        "Deep-cleaning the grout behind my bathroom toilet with an old toothbrush",
      ],
      "A weird food order or modification I insist on every time.": [
        "Asking for fries cooked until they are borderline burnt and intensely crispy",
      ],
      "The random topic I could rant about for an hour with zero prep.": [
        "Why modern refrigerator interior shelving layouts are an architectural crime",
      ],
      "The weirdest note or search tab currently open on my phone.": [
        "Can owls recognize human faces over prolonged multi-year grudges",
      ],
      "The absurdly over-the-top way I react to a minor inconvenience.": [
        "Lying face down on my living room rug for twenty minutes after dropping a fork",
      ],
    },

  },
  {
    id: "love_life",
    displayName: "Love Life",
    rating: "PG",
    prompts: [
      "The most awkward first date I've ever been on.",
      "The pettiest romantic ick that immediately turned me off.",
      "The most cringe thing I did to impress a crush.",
      "The worst gift I've ever given or received in a relationship.",
      "A time a date went so badly I actively looked for an escape.",
      "The dumbest reason I ever broke up with someone.",
      "The weirdest thing I've found while snooping on a crush's profile.",
      "The most embarrassing romantic rejection I've ever experienced.",
      "A cliché romantic gesture I secretly love.",
      "The worst outfit I wore on a date thinking I looked great.",
      "The strangest place I've ever gone on a date.",
      "A time I accidentally completely ruined a romantic moment.",
      "The obvious red flag I ignored for way too long.",
      "The most dramatic argument I've had over something tiny with a partner.",
      "The weirdest habit I learned about someone after staying at their place.",
      "The most embarrassing pet name I've ever been called or used.",
      "The worst excuse I used to turn down a second date.",
      "A weird celebrity crush I had that makes no sense.",
      "A time I caught feelings for someone at the worst possible time.",
      "The most awkward interaction I've had with a partner's parents.",
      "The most desperate thing I did right after a breakup.",
      "A bizarre dealbreaker I secretly have when dating.",
      "The worst dating advice a friend gave me that I actually followed.",
      "A lie I told on a date just to seem more interesting.",
      "The quickest I have ever lost interest in someone."
    ],
    samples: {
      "The most awkward first date I've ever been on.": [
        "They brought their mother along to grade my posture and evaluate my manners",
      ],
      "The pettiest romantic ick that immediately turned me off.": [
        "Watching them chase an escaped napkin across a breezy restaurant patio",
      ],
      "The most cringe thing I did to impress a crush.": [
        "Pretending to have read War and Peace and carrying the giant volume everywhere",
      ],
      "The worst gift I've ever given or received in a relationship.": [
        "A coupon book offering ten redeemable back rubs that expired in thirty days",
      ],
      "A time a date went so badly I actively looked for an escape.": [
        "Climbing through the ground floor bathroom window during a dinner about crypto",
      ],
      "The dumbest reason I ever broke up with someone.": [
        "They insisted on clapping enthusiastically whenever an airplane landed",
      ],
      "The weirdest thing I've found while snooping on a crush's profile.": [
        "A Pinterest board dedicated to vintage taxidermy chipmunks playing poker",
      ],
      "The most embarrassing romantic rejection I've ever experienced.": [
        "Leaning in for a passionate first kiss and getting a firm two-handed high five",
      ],
      "A cliché romantic gesture I secretly love.": [
        "Sharing one enormous wool umbrella while walking through heavy rain",
      ],
      "The worst outfit I wore on a date thinking I looked great.": [
        "A bright purple velvet blazer that shed iridescent lint onto their white sofa",
      ],
      "The strangest place I've ever gone on a date.": [
        "An abandoned botanical greenhouse that smelled intensely of wet compost",
      ],
      "A time I accidentally completely ruined a romantic moment.": [
        "Sneezing violently onto their forehead while leaning in for a quiet embrace",
      ],
      "The obvious red flag I ignored for way too long.": [
        "They had zero long-term friends and claimed all their exes were insane",
      ],
      "The most dramatic argument I've had over something tiny with a partner.": [
        "A two-day standoff over which direction the toilet paper roll should unwind",
      ],
      "The weirdest habit I learned about someone after staying at their place.": [
        "They slept with four hot water bottles tucked under an electric blanket in July",
      ],
      "The most embarrassing pet name I've ever been called or used.": [
        "Calling a serious adult partner 'snuggle-muffin' in front of their coworkers",
      ],
      "The worst excuse I used to turn down a second date.": [
        "Claiming my cat was having an existential crisis and required my presence",
      ],
      "A weird celebrity crush I had that makes no sense.": [
        "Willem Dafoe in full villain makeup from The Boondock Saints",
      ],
      "A time I caught feelings for someone at the worst possible time.": [
        "Falling in love with my roommate's ex during a shared fourteen-hour road trip",
      ],
      "The most awkward interaction I've had with a partner's parents.": [
        "Accidentally breaking their decorative glass turtle during Sunday dinner",
      ],
      "The most desperate thing I did right after a breakup.": [
        "Listening to sad acoustic covers while refreshing their Spotify activity feed",
      ],
      "A bizarre dealbreaker I secretly have when dating.": [
        "Anyone who chews their fingernails and leaves the clippings on bedside tables",
      ],
      "The worst dating advice a friend gave me that I actually followed.": [
        "Wait four days to reply to a text message to manufacture an aura of mystery",
      ],
      "A lie I told on a date just to seem more interesting.": [
        "Claiming I was an apprentice glassblower working on custom chandeliers",
      ],
      "The quickest I have ever lost interest in someone.": [
        "The moment they were visibly rude to our exhausted diner waitress",
      ],
    },

  },
  {
    id: "rated_r_nsfw",
    displayName: "Rated R NSFW",
    rating: "R",
    prompts: [
      "The most desperate public bathroom emergency I barely survived.",
      "The weirdest thing in my private browsing history that I'd die if someone saw.",
      "The most humiliating accidental nudity moment I've ever experienced.",
      "The absolute grossest personal hygiene shortcut I take when nobody is around.",
      "The political figure or president I'd reluctantly sleep with to save humanity.",
      "The most NSFW thing I've ever done in a semi-public place.",
      "The most embarrassing item a bag checker or TSA agent has pulled out of my luggage.",
      "The lowest amount of money I'd accept to publicly stream my entire camera roll.",
      "The weirdest object I've used as makeshift toilet paper in an emergency.",
      "A time someone walked in on me at the absolute worst possible moment.",
      "The most humiliating bodily malfunction I've had during a quiet, crowded event.",
      "The longest I have ever gone without showering or changing my clothes.",
      "The most NSFW thing I accidentally broadcasted onto a shared screen or speaker.",
      "The grossest thing I've eaten off the floor or out of desperation.",
      "The sketchiest place I've peed or thrown up in public.",
      "The absolute worst or most forbidden person I've had a fleeting dirty thought about.",
      "The most degenerate thing I've done while drunk or blacked out.",
      "The grossest injury, rash, or infection I stubbornly ignored for way too long.",
      "The most unhinged thing currently sitting in my phone's hidden album.",
      "The absolute lowest, dirtiest state my bedroom or bathroom has ever reached.",
      "The pettiest reason I immediately lost attraction right before hooking up.",
      "The weirdest thing I would let someone pay me five thousand dollars to do.",
      "The most awkward walk of shame or late-night escape I've ever made.",
      "The degenerate vice or bad habit I spend way too much money hiding.",
      "A time an intimate or serious moment was completely ruined by an unsexy bodily noise."
    ],
    samples: {
      "The most desperate public bathroom emergency I barely survived.": [
        "Sprinting half a mile through downtown traffic clenching with every ounce of will",
      ],
      "The weirdest thing in my private browsing history that I'd die if someone saw.": [
        "Extensive research into medieval execution methods and royal gout treatments",
      ],
      "The most humiliating accidental nudity moment I've ever experienced.": [
        "Towel falling off in the dorm hallway as the fire alarm forced everyone outside",
      ],
      "The absolute grossest personal hygiene shortcut I take when nobody is around.": [
        "Using dry shampoo four days in a row instead of actually taking a proper shower",
      ],
      "The political figure or president I'd reluctantly sleep with to save humanity.": [
        "Young Abraham Lincoln, purely out of historical curiosity and respect",
      ],
      "The most NSFW thing I've ever done in a semi-public place.": [
        "Making out aggressively in the back row of an empty late-night indie cinema",
      ],
      "The most embarrassing item a bag checker or TSA agent has pulled out of my luggage.": [
        "An enormous novelty shaped beeswax candle that looked thoroughly suspicious on X-ray",
      ],
      "The lowest amount of money I'd accept to publicly stream my entire camera roll.": [
        "Five hundred thousand dollars in unmarked non-sequential twenty-dollar bills",
      ],
      "The weirdest object I've used as makeshift toilet paper in an emergency.": [
        "A crumpled gas station receipt and the cardboard tube from the empty roll",
      ],
      "A time someone walked in on me at the absolute worst possible moment.": [
        "My roommate walking into the living room while I danced naked to 80s synth pop",
      ],
      "The most humiliating bodily malfunction I've had during a quiet, crowded event.": [
        "A loud, echoing stomach gurgle during a silent moment of prayer at a wedding",
      ],
      "The longest I have ever gone without showering or changing my clothes.": [
        "Five full days during a chaotic college finals week fueled entirely by energy drinks",
      ],
      "The most NSFW thing I accidentally broadcasted onto a shared screen or speaker.": [
        "AirPlaying an explicit comedy podcast to my parents' living room television",
      ],
      "The grossest thing I've eaten off the floor or out of desperation.": [
        "A dusty glazed donut half that had been sitting under a couch for thirty-six hours",
      ],
      "The sketchiest place I've peed or thrown up in public.": [
        "Behind a rusted industrial dumpster outside an underground techno warehouse",
      ],
      "The absolute worst or most forbidden person I've had a fleeting dirty thought about.": [
        "My best friend's eccentric, leather-jacket-wearing uncle at a holiday barbecue",
      ],
      "The most degenerate thing I've done while drunk or blacked out.": [
        "Ordering seventy dollars of McDonald's and eating four double cheeseburgers in bed",
      ],
      "The grossest injury, rash, or infection I stubbornly ignored for way too long.": [
        "A raging infected blister covered with three dirty bandages for two weeks",
      ],
      "The most unhinged thing currently sitting in my phone's hidden album.": [
        "Screenshots of petty group chat receipts cataloged for future leverage",
      ],
      "The absolute lowest, dirtiest state my bedroom or bathroom has ever reached.": [
        "A floor covered in takeout boxes, laundry piles, and twelve empty seltzer cans",
      ],
      "The pettiest reason I immediately lost attraction right before hooking up.": [
        "They had no fitted sheet on their mattress, just a bare stained foam pad",
      ],
      "The weirdest thing I would let someone pay me five thousand dollars to do.": [
        "Wear a full Victorian ghost costume and silently pace their hallway at midnight",
      ],
      "The most awkward walk of shame or late-night escape I've ever made.": [
        "Sneaking out at 6 AM wearing oversized gray sweatpants and bright yellow Crocs",
      ],
      "The degenerate vice or bad habit I spend way too much money hiding.": [
        "Buying premium single-origin coffee beans while claiming I drink instant Nescafe",
      ],
      "A time an intimate or serious moment was completely ruined by an unsexy bodily noise.": [
        "A massive uninvited hiccup right in the middle of a delicate emotional confession",
      ],
    },

  },
];
/** id -> prompts, derived. Draw functions use this; nothing else should. */
const DECKS: Record<string, string[]> = Object.fromEntries(
  DECK_LIST.map((d) => [d.id, d.prompts])
);

const DECK_META: Record<string, DeckDefinition> = Object.fromEntries(
  DECK_LIST.map((d) => [d.id, d])
);

export function validateDeckSamples(decks: DeckDefinition[]): void {
  for (const deck of decks) {
    if (deck.samples) {
      const promptSet = new Set(deck.prompts);
      for (const promptKey of Object.keys(deck.samples)) {
        if (!promptSet.has(promptKey)) {
          throw new Error(
            `Sample prompt key "${promptKey}" does not match any prompt in deck "${deck.id}".`
          );
        }
      }
    }
  }
}
validateDeckSamples(DECK_LIST);

export class PromptDecks {
  static getDeckSize(deckId: string): number {
    return DECKS[deckId]?.length || 0;
  }

  static getAvailableDecks(): string[] {
    return DECK_LIST.map((d) => d.id);
  }

  /** Everything the UI needs, prompts included. Callers should loop over this. */
  static getAllDecks(): DeckDefinition[] {
    return DECK_LIST;
  }

  static getDeck(deckId: string): DeckDefinition | undefined {
    return DECK_META[deckId];
  }

  static getDeckDisplayName(deckId: string): string {
    return DECK_META[deckId]?.displayName ?? deckId;
  }

  static getDeckRating(deckId: string): DeckRating | undefined {
    return DECK_META[deckId]?.rating;
  }

  static getSamplesForPrompt(promptText: string): string[] | undefined {
    for (const d of DECK_LIST) {
      if (d.samples && d.samples[promptText]) {
        return d.samples[promptText];
      }
    }
    return undefined;
  }

  /**
   * The deck to fall back to when no chosen deck applies. Replaces the
   * hardcoded "the_daily_grind" that used to appear at eight call sites and
   * broke the moment that deck was renamed.
   */
  static getFallbackDeckId(): string {
    const marked = DECK_LIST.filter((d) => d.isFallback);
    if (marked.length !== 1) {
      throw new Error(
        `Exactly one deck must set isFallback; found ${marked.length}` +
        (marked.length ? ` (${marked.map((d) => d.id).join(", ")})` : "")
      );
    }
    return marked[0].id;
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
