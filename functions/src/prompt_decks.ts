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
  /** Optional writing aids, keyed by the EXACT prompt text they belong to. */
  stems?: Record<string, string[]>;
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
    stems: {
          "The first thing I'm stealing if looting becomes completely legal for one night.": [
                "I'm heading straight for",
                "Without question, I am looting"
          ],
          "The dumbest reason I would end up getting kicked out of a cult.": [
                "I'd be banished for constantly",
                "It would all fall apart when I insisted on"
          ],
          "The weirdly specific side hustle I would start if I went completely broke tomorrow.": [
                "I would make rent by",
                "I'd start charging strangers to"
          ],
          "The exact crime I'd probably be convicted of in a dystopian future.": [
                "I would be sentenced to hard labor for",
                "My treasonous charge would definitely be"
          ],
          "The fake backstory and name I would use if I went into witness protection.": [
                "Call me",
                "My cover story is a disgraced"
          ],
          "The stupid minor issue I would make the centerpiece of my presidential campaign.": [
                "My entire platform hinges on",
                "My first executive order would immediately"
          ],
          "The everyday annoying behavior I would make punishable by immediate jail time.": [
                "Straight to federal prison for anyone who",
                "A mandatory five-year sentence for"
          ],
          "The animal I honestly think I could take in a fistfight if my life depended on it.": [
                "I am reasonably confident I could drop a",
                "Give me five minutes in the ring with a"
          ],
          "The petty reason I would refuse to save someone in a zombie apocalypse.": [
                "I'd lock the barricade because they once",
                "You're zombie food if you ever"
          ],
          "The first thing I would buy with lottery money that would make people question my sanity.": [
                "I would instantly wire fifty grand for",
                "My financial advisor would weep when I bought"
          ],
          "The bizarre rumor I would spread about myself if I became famous overnight.": [
                "I'd leak to the press that I",
                "Everyone would believe I secretly"
          ],
          "The weird hill I would die on during a high-stakes job interview.": [
                "I would tank the interview just to prove that",
                "I will not accept the offer unless we agree that"
          ],
          "What I would actually do if I got accidentally locked inside a Target overnight.": [
                "The first three hours would be spent",
                "Security cameras would catch me"
          ],
          "The completely useless superpower I would actually get the most mileage out of.": [
                "The power to instantly",
                "Being able to telepathically"
          ],
          "The minor scam I could easily pull off if I had zero morals.": [
                "I could easily convince tourists to buy",
                "I'd make a fortune pretending to be"
          ],
          "The dumb thing I would spend a million dollars on before ever buying a house.": [
                "Before touching real estate, I'm buying",
                "Forget a mortgage, I need a lifetime supply of"
          ],
          "The weird luxury I would insist on putting in my personal doomsday bunker.": [
                "The bunker is non-negotiable without a custom",
                "While civilization burns, I'll be enjoying my"
          ],
          "The reason my friends will probably have to stage an intervention for me in ten years.": [
                "They'll sit me down because of my obsession with",
                "The intervention will be entirely about my"
          ],
          "The ridiculous contest I would challenge the devil to for my own soul.": [
                "Satan isn't beating me in a high-stakes",
                "My soul is safe because I challenged him to"
          ],
          "The embarrassing passion project I would fund if I had unlimited billionaire money.": [
                "I would sink millions into producing",
                "I'd build a private research institute dedicated solely to"
          ],
          "The odd job I would be shockingly good at if I quit my career today.": [
                "I was born to be a professional",
                "My true calling is definitely"
          ],
          "The petty lie I would tell on a reality dating show to cause maximum drama.": [
                "During confessionals I'd whisper that I",
                "At the rose ceremony I would reveal that"
          ],
          "The weird object in my house I would grab as a weapon during a break-in.": [
                "An intruder is getting clobbered with my",
                "I'm defending the hallway armed only with"
          ],
          "The bizarre conspiracy theory I could probably be convinced is one hundred percent real.": [
                "You could easily convince me that",
                "Deep down, I suspect the government is hiding that"
          ],
          "The useless, niche topic I could give an hour-long presentation on with zero prep.": [
                "Sit down and listen to me explain the lore of",
                "I have an unprompted 60-minute lecture ready on"
          ],
          "The ridiculous vanity project I would force a movie studio to let me star in.": [
                "A gritty, three-hour biopic where I play",
                "An action blockbuster where I'm a rogue"
          ],
          "The mundane everyday chore I would hire a full-time assistant to handle for me.": [
                "I'd pay someone forty bucks an hour just to",
                "Their only job description would be"
          ],
          "The stupidest bet I would actually agree to take for ten thousand dollars.": [
                "For ten grand in cash, I would publicly",
                "Count me in, as long as all I have to do is"
          ],
          "The petty reason I'd get fired on my very first day working retail or fast food.": [
                "I'd get canned an hour in for refusing to",
                "The manager would escort me out after I told a customer"
          ],
          "What I would bury in my backyard just to mess with future archaeologists.": [
                "In three hundred years they're going to dig up",
                "Future historians will be deeply confused by my buried"
          ],
          "The oddly specific red flag that would make me climb out a restaurant bathroom window.": [
                "I'm hitting the fire exit the second they admit they",
                "The date is over immediately if they mention their"
          ],
          "The ridiculous backstage demand I would put in my contract rider as a touring artist.": [
                "Dressing room must contain exactly twenty-four",
                "My tour manager must ensure there is always a"
          ],
          "The exact scenario where I would completely sell out my moral principles for cash.": [
                "All my ethics evaporate the second someone offers",
                "I will gladly sell out if it means getting a"
          ],
          "The weird habit of mine that would immediately expose me as an alien impostor.": [
                "My human disguise falls apart whenever I",
                "The men in black will catch me because I constantly"
          ],
          "The dumbest thing I would do if I had total invisibility for two hours.": [
                "I wouldn't steal anything, I'd just spend two hours",
                "The most childish thing imaginable: sneaking in to"
          ],
          "The terrible business idea I genuinely believe could make millions if someone funded it.": [
                "It's like Uber, but exclusively for",
                "A subscription service that sends you"
          ],
          "The fake hobby I would invent just to sound cultured at a fancy party.": [
                "I'd swirl my wine and claim I spend weekends",
                "I would casually drop that I collect antique"
          ],
          "The petty reason I would cut a family member completely out of my will.": [
                "They're getting zero inheritance because of the time they",
                "My lawyer will read a clause explicitly disinheriting them for"
          ],
          "The role I would inevitably end up playing in a post-apocalyptic survivor settlement.": [
                "I'm neither the leader nor the scout; I'm the settlement's",
                "The warlord would keep me alive solely because I can"
          ],
          "The harmless lie about myself I plan on taking all the way to my grave.": [
                "I will never admit to anyone that I actually",
                "To this day, everyone thinks I know how to"
          ],
          "The weird item I would definitely try to smuggle through airport security.": [
                "TSA is going to tackle me over my carry-on full of",
                "I'm risking a federal offense just to bring home"
          ],
          "The minor annoyance I would ban nationwide on my first day in power.": [
                "An immediate federal ban on anyone who",
                "Effective tomorrow, it is illegal to"
          ],
          "The completely irrational phobia that would get me killed first in a horror movie.": [
                "The killer gets me because I was paralyzed by a",
                "I'd run straight into the woods just to avoid a"
          ],
          "The stupid internet argument that would actually tempt me to show up at someone's house.": [
                "I would book a flight just to settle who is right about",
                "Send me your address if you genuinely believe that"
          ],
          "The chaotic text I would send to my group chats if an asteroid hit tomorrow.": [
                "My final message to everyone would simply read:",
                "Before the impact I'm texting the group chat:"
          ],
          "The trashy reality TV competition I would secretly dominate.": [
                "Put me on Survivor and watch me ruthlessly",
                "I would sweep the season on"
          ],
          "The oddly specific task I would gladly pay someone two hundred dollars an hour to do.": [
                "Take my money if you will just come over and",
                "I'd happily pay top dollar for someone to deal with my"
          ],
          "The dumb thing I would do with a time machine before fixing any historical events.": [
                "Before saving anyone, I'm travelling back to 1999 to",
                "First stop: five hundred years ago just to show them"
          ],
          "The fake profession I would tell a stranger next to me on a long flight.": [
                "For six hours I am an undercover",
                "I'd introduce myself as a high-profile consultant for"
          ],
          "The stupid mistake that would get me caught during an otherwise flawless bank heist.": [
                "We'd get busted because I stopped to grab",
                "The alarm triggers when I accidentally drop my"
          ]
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
    stems: {
          "The weirdest belief I had as a kid.": [
                "I genuinely believed for years that",
                "Until middle school, I was convinced"
          ],
          "The dumbest way I've ever injured myself.": [
                "I had to go to urgent care because I tried to",
                "I bruised myself badly by simply"
          ],
          "A food combination I actually enjoy that grosses people out.": [
                "Don't knock it until you try dipping",
                "My secret culinary crime is mixing"
          ],
          "The most embarrassing phase I went through growing up.": [
                "There was a full year where I insisted on wearing",
                "Please never dig up photos from when I was obsessed with"
          ],
          "My most irrational pet peeve.": [
                "I see red the moment someone",
                "It drives me quietly insane when people"
          ],
          "The pettiest reason I stopped talking to someone.": [
                "I ghosted them entirely because they",
                "Our friendship ended the day they had the nerve to"
          ],
          "The worst gift I've ever received and pretended to like.": [
                "I had to smile through receiving an awful",
                "Someone gave me a completely useless"
          ],
          "The dumbest lie I ever told my parents.": [
                "With a straight face, I told them that",
                "I panicked and convinced my mom that"
          ],
          "A weird habit I have when I'm home alone.": [
                "The second the door closes, I start",
                "When nobody is around, I always narrate my"
          ],
          "The most trouble I ever got into at school.": [
                "The principal called my house after I was caught",
                "I received detention for orchestrating a"
          ],
          "A time I completely blanked on someone's name.": [
                "I talked to them for twenty minutes calling them",
                "I panicked in an introduction and called my own"
          ],
          "The worst first impression I ever made on someone.": [
                "Within thirty seconds of meeting them, I managed to",
                "They definitely thought I was unhinged because I"
          ],
          "Something I accidentally broke and never confessed to.": [
                "To this day, they have no idea I shattered the",
                "I hid the pieces behind the couch after breaking"
          ],
          "The artist or guilty pleasure song I secretly listen to.": [
                "When nobody is in the car, I blast",
                "My Spotify Wrapped is ruined every year by"
          ],
          "The most useless item I spent my own money on.": [
                "I spent hard-earned cash on a ridiculous",
                "It gathers dust on my shelf: an expensive"
          ],
          "A trend I participated in that aged terribly.": [
                "I thought I looked so cool participating in",
                "I burned all the photos of me following the"
          ],
          "Something I pretend to understand just to fit in.": [
                "I just nod along whenever anyone brings up",
                "I have no clue what is happening when people talk about"
          ],
          "The most awkward interaction I've had with a stranger.": [
                "In an elevator, a stranger and I had a mortifying moment when",
                "I tried making casual small talk, but accidentally blurted out"
          ],
          "The weirdest thing currently in my room or car.": [
                "If you opened my glovebox, you'd find an unexplainable",
                "Tucked under my bed is a very suspicious"
          ],
          "A bizarre hidden talent or useless skill I have.": [
                "My party trick is that I can surprisingly",
                "Give me thirty seconds and I can"
          ],
          "The longest I have ever gone without leaving my house.": [
                "During peak hermitude, I didn't see sunlight for",
                "I stayed inside for days surviving exclusively on"
          ],
          "A popular movie or show that I secretly cannot stand.": [
                "Everyone loves it, but I find it unwatchable:",
                "I will gladly die on the hill that everyone is lying about"
          ],
          "The worst haircut or style choice I've ever had.": [
                "I walked out of the salon with a disastrous",
                "The barber gave me a horrific cut that looked like"
          ],
          "A time I got completely lost in a place I knew well.": [
                "I managed to wander in circles inside",
                "I had lived there for years, yet I needed GPS to find"
          ],
          "My biggest irrational fear that makes no sense.": [
                "I am deeply terrified that one day",
                "It sounds ridiculous, but I live in fear of"
          ]
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
    stems: {
          "A weird habit I have when I think nobody is watching.": [
                "The second I'm alone, I start",
                "I regularly catch myself whispering to"
          ],
          "The dumbest routine I do every single day.": [
                "Every morning I waste ten minutes",
                "My brain forces me to repeatedly check"
          ],
          "A normal food I eat in a completely wrong way.": [
                "I peel apart my",
                "People look horrified when I eat"
          ],
          "The imaginary argument I rehearse the most in the shower.": [
                "I deliver a devastating monologue destroying anyone who says",
                "I stand under the water passionately debating"
          ],
          "Something stupid I do when I'm bored alone in my room.": [
                "I will pace back and forth pretending to be",
                "Boredom leads me to spend an hour"
          ],
          "A sound or texture that makes me unreasonably angry.": [
                "The sound and texture of",
                "I will shudder violently if I accidentally touch"
          ],
          "The weirdest thing I do while pacing on the phone.": [
                "Whenever a call starts, my body instinctively begins",
                "I will walk three miles around my kitchen island while"
          ],
          "A ridiculous personal rule I follow that makes zero sense.": [
                "Under no circumstances will I ever let my",
                "I have a strict, arbitrary mental rule that"
          ],
          "The random thing I hoard and stubbornly refuse to throw away.": [
                "I have an entire drawer overflowing with empty",
                "I cannot bring myself to part with my collection of"
          ],
          "A habit of mine that would drive a roommate crazy.": [
                "Anyone living with me has to endure my habit of",
                "A roommate would definitely snap after seeing me constantly"
          ],
          "The strange way I organize something or do a basic chore.": [
                "Everything has to be arranged in an unhinged order by",
                "I do my laundry in a bizarre sequence that requires"
          ],
          "Something I have to do before bed or I can't sleep.": [
                "I will lie awake in agony unless I first",
                "My bedtime ritual strictly requires me to"
          ],
          "A totally normal phrase or noise that instantly annoys me.": [
                "My eye twitches whenever someone says the phrase",
                "Nothing fills me with instant rage faster than"
          ],
          "The random hobby I obsessed over for two weeks and then dropped forever.": [
                "I dropped two hundred dollars on equipment to learn",
                "For fourteen days I was completely convinced my calling was"
          ],
          "The trick I use to avoid making small talk with people in public.": [
                "The second I see an acquaintance, I immediately fake a call about",
                "I pretend to be deeply engrossed in reading the ingredients on"
          ],
          "The weirdest thing I've caught myself doing on autopilot.": [
                "My brain short-circuited and I put my phone into the",
                "I caught myself pouring milk directly onto the"
          ],
          "A superstition I claim not to believe in but still follow anyway.": [
                "I know it's nonsense, but I still refuse to ever",
                "Just to be safe from bad karma, I always"
          ],
          "Something petty that immediately makes me judge a person.": [
                "I instantly write someone off if they carry their",
                "My respect drops to zero the moment I notice their"
          ],
          "The song or short video I've listened to on loop an embarrassing amount.": [
                "I played it forty-two times in a row:",
                "My brain has been hijacked on repeat by"
          ],
          "A basic everyday task I do in a backwards way.": [
                "People tell me I'm a psycho for putting on my",
                "I handle this routine chore entirely backwards by"
          ],
          "The irrational thing I do whenever I get slightly stressed out.": [
                "Minor pressure causes me to clean my entire",
                "When anxiety spikes, I immediately start obsessing over"
          ],
          "A weird food order or modification I insist on every time.": [
                "The server always gives me a weird look when I ask for extra",
                "I must have my meal served with a side of"
          ],
          "The random topic I could rant about for an hour with zero prep.": [
                "Do not get me started on the absolute disaster that is",
                "I have an unhinged 60-minute thesis ready on"
          ],
          "The weirdest note or search tab currently open on my phone.": [
                "In my Notes app sits a cryptic draft titled",
                "A search tab that has been open for months asks:"
          ],
          "The absurdly over-the-top way I react to a minor inconvenience.": [
                "A minor setback makes me want to fake my death and move to",
                "Dropping a pencil makes me feel like the universe has"
          ]
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
    stems: {
          "The most awkward first date I've ever been on.": [
                "Within ten minutes, they confessed that their",
                "We sat in painful silence after I accidentally spilled"
          ],
          "The pettiest romantic ick that immediately turned me off.": [
                "Attraction died instantly when they chewed their",
                "I checked out the second they referred to their shoes as"
          ],
          "The most cringe thing I did to impress a crush.": [
                "I spent three weeks pretending I was deeply into",
                "I staged an entire fake encounter just to casually show them"
          ],
          "The worst gift I've ever given or received in a relationship.": [
                "For our anniversary, I unwrapped a half-used",
                "I thought it was romantic, but I gave them an awful"
          ],
          "A time a date went so badly I actively looked for an escape.": [
                "I had a friend call me with a fake emergency about a",
                "I excused myself to the restroom and seriously contemplated"
          ],
          "The dumbest reason I ever broke up with someone.": [
                "I ended things because their laugh sounded like an injured",
                "I couldn't date someone whose mother still"
          ],
          "The weirdest thing I've found while snooping on a crush's profile.": [
                "Ten pages deep into their feed, I found photos of them dressed as",
                "I discovered they run an active fan account dedicated to"
          ],
          "The most embarrassing romantic rejection I've ever experienced.": [
                "They laughed in my face before telling me",
                "I poured my heart out and their response was simply:"
          ],
          "A cliché romantic gesture I secretly love.": [
                "It's corny as hell, but I melt when someone",
                "My secret weakness is receiving unexpected"
          ],
          "The worst outfit I wore on a date thinking I looked great.": [
                "I showed up wearing an embarrassing combination of",
                "I thought I looked like a model, but I resembled an unwashed"
          ],
          "The strangest place I've ever gone on a date.": [
                "They took me to an eerie, abandoned",
                "Our romantic evening took place in the parking lot of a"
          ],
          "A time I accidentally completely ruined a romantic moment.": [
                "Right as we leaned in to kiss, I let out a loud",
                "The romantic mood was shattered when I awkwardly asked about"
          ],
          "The obvious red flag I ignored for way too long.": [
                "I somehow overlooked the fact that they literally had no",
                "Everyone warned me, but I ignored their habit of"
          ],
          "The most dramatic argument I've had over something tiny with a partner.": [
                "A screaming match ensued over who ate the last",
                "We almost broke up over the correct way to fold"
          ],
          "The weirdest habit I learned about someone after staying at their place.": [
                "I woke up to discover they sleep clutching a",
                "Their morning routine involved an unsettling amount of"
          ],
          "The most embarrassing pet name I've ever been called or used.": [
                "They insisted on calling me their little",
                "I still cringe remembering that I unironically called someone"
          ],
          "The worst excuse I used to turn down a second date.": [
                "I texted back saying my pet had an emergency",
                "I claimed I was suddenly entering a spiritual vow of"
          ],
          "A weird celebrity crush I had that makes no sense.": [
                "Don't judge me, but I had an inexplicable crush on",
                "My friends roasted me endlessly for being attracted to"
          ],
          "A time I caught feelings for someone at the worst possible time.": [
                "Butterflies hit me right as they were getting engaged to my",
                "I developed a terrible crush on my best friend's"
          ],
          "The most awkward interaction I've had with a partner's parents.": [
                "Their dad walked in while I was making a fool of myself trying to",
                "At dinner with their parents, I accidentally insulted their"
          ],
          "The most desperate thing I did right after a breakup.": [
                "Within 48 hours, I posted a staged, dramatic photo of",
                "I drove past their gym three times pretending I was"
          ],
          "A bizarre dealbreaker I secretly have when dating.": [
                "I will immediately swipe left on anyone whose profile mentions",
                "We cannot be together if you don't appreciate"
          ],
          "The worst dating advice a friend gave me that I actually followed.": [
                "They told me to play hard to get by pretending I had an ex who was a",
                "Following their awful advice, I showed up unannounced at their"
          ],
          "A lie I told on a date just to seem more interesting.": [
                "I claimed I spent a summer backpacking through",
                "I made up an entire fictitious story about being an expert in"
          ],
          "The quickest I have ever lost interest in someone.": [
                "Interest dropped to zero in four seconds after they",
                "The spark vanished the second they snapped their fingers at the"
          ]
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
    stems: {
          "The most desperate public bathroom emergency I barely survived.": [
                "My stomach made a ungodly noise in the middle of a",
                "I had to sprint through a crowded venue searching for a stall after eating"
          ],
          "The weirdest thing in my private browsing history that I'd die if someone saw.": [
                "If the FBI leaks my search for",
                "No one can ever find out I spent forty minutes researching"
          ],
          "The most humiliating accidental nudity moment I've ever experienced.": [
                "The towel dropped in front of my",
                "A sudden gust of wind or wardrobe malfunction left me fully exposed to"
          ],
          "The absolute grossest personal hygiene shortcut I take when nobody is around.": [
                "Instead of doing laundry, I've been known to sniff-test and re-wear",
                "When showers aren't happening, my solution is drowning in"
          ],
          "The political figure or president I'd reluctantly sleep with to save humanity.": [
                "To prevent global annihilation, I am taking one for the team with",
                "If the aliens demand a sacrifice, I suppose I could endure a night with"
          ],
          "The most NSFW thing I've ever done in a semi-public place.": [
                "We risked everything in the backseat of a parked car near a",
                "Under the table at that dimly lit bar, things escalated to"
          ],
          "The most embarrassing item a bag checker or TSA agent has pulled out of my luggage.": [
                "The officer held up my questionable",
                "The entire security line stared as the agent inspected my"
          ],
          "The lowest amount of money I'd accept to publicly stream my entire camera roll.": [
                "Deposit twenty grand and you can see all my",
                "My price to show every deleted photo and screenshot is"
          ],
          "The weirdest object I've used as makeshift toilet paper in an emergency.": [
                "When the roll was empty, I had no choice but to sacrifice a",
                "Desperation in that rest stop forced me to wipe with"
          ],
          "A time someone walked in on me at the absolute worst possible moment.": [
                "The door swung open right as I was in the middle of",
                "My roommate walked into the living room while I was unclothed and"
          ],
          "The most humiliating bodily malfunction I've had during a quiet, crowded event.": [
                "During a silent pause in the ceremony, my body produced a deafening",
                "In a crowded elevator, I couldn't hold back the sudden"
          ],
          "The longest I have ever gone without showering or changing my clothes.": [
                "During a dark depression week, I went a shocking five days without",
                "I set a personal low record when I realized I had been wearing the same"
          ],
          "The most NSFW thing I accidentally broadcasted onto a shared screen or speaker.": [
                "My Bluetooth auto-connected to the family speaker playing",
                "During a work presentation, my open tabs revealed"
          ],
          "The grossest thing I've eaten off the floor or out of desperation.": [
                "The five-second rule was stretched to twenty minutes for a piece of",
                "I was so hungry and broke that I dug a half-eaten"
          ],
          "The sketchiest place I've peed or thrown up in public.": [
                "Under cover of darkness, I relieved myself behind a",
                "The alcohol hit hard and I projectile vomited into a"
          ],
          "The absolute worst or most forbidden person I've had a fleeting dirty thought about.": [
                "My brain committed a thought crime when I briefly imagined",
                "I need holy water after catching myself looking lustfully at my"
          ],
          "The most degenerate thing I've done while drunk or blacked out.": [
                "I came to hours later clutching a stolen",
                "According to eyewitnesses, three tequila shots turned me into someone who"
          ],
          "The grossest injury, rash, or infection I stubbornly ignored for way too long.": [
                "I watched in denial as a festering",
                "WebMD told me to go to the ER, but I just put a band-aid on my oozing"
          ],
          "The most unhinged thing currently sitting in my phone's hidden album.": [
                "Behind Face ID lies a deeply cursed photo of",
                "The hidden folder is strictly reserved for my terrifying"
          ],
          "The absolute lowest, dirtiest state my bedroom or bathroom has ever reached.": [
                "The floor was covered in a crusty layer of",
                "My shower was developing its own sentient ecosystem of"
          ],
          "The pettiest reason I immediately lost attraction right before hooking up.": [
                "Clothes were coming off until I noticed their bizarre",
                "Everything paused because their bedroom smelled distinctly of"
          ],
          "The weirdest thing I would let someone pay me five thousand dollars to do.": [
                "Hand me five grand and I'll happily let you",
                "For five thousand in cash, I wouldn't hesitate to eat a"
          ],
          "The most awkward walk of shame or late-night escape I've ever made.": [
                "At 6 AM I was tiptoeing down the street wearing yesterday's",
                "I climbed out an apartment window barefoot holding my shoes after"
          ],
          "The degenerate vice or bad habit I spend way too much money hiding.": [
                "My bank statement hides thousands spent on my shameful addiction to",
                "Nobody in my family knows about my secret stash of"
          ],
          "A time an intimate or serious moment was completely ruined by an unsexy bodily noise.": [
                "Just as things got heated, my stomach let out a demonic",
                "We were leaning in for a kiss when I suddenly let out an unholy"
          ]
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

export function validateDeckStems(decks: DeckDefinition[]): void {
  for (const deck of decks) {
    if (deck.stems) {
      const promptSet = new Set(deck.prompts);
      for (const promptKey of Object.keys(deck.stems)) {
        if (!promptSet.has(promptKey)) {
          throw new Error(
            `Stem prompt key "${promptKey}" does not match any prompt in deck "${deck.id}".`
          );
        }
      }
    }
  }
}
validateDeckStems(DECK_LIST);

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

  static getStemsForPrompt(promptText: string): string[] | undefined {
    for (const d of DECK_LIST) {
      if (d.stems && d.stems[promptText]) {
        return d.stems[promptText];
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
