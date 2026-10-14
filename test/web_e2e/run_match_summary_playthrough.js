const { chromium } = require('playwright');
const {
  assertThat,
  labelPage,
  getSemanticsElements,
  hasText,
  clickElement,
  saveScreenshot,
  readRoom,
  readPlayers,
  waitFor,
  waitForRoom,
  waitForScreen,
  markerOf,
  openApp,
  createRoom,
  joinRoom,
  ensureTimersDisabled,
  ensureRounds,
  driveToGameOver,
  runMain
} = require('./playthrough_helpers');
const { UI, FIXTURE } = require('./ui_strings');

const APP_URL = 'http://127.0.0.1:8777';
const VIEWPORT = { width: 1280, height: 800 };

// A 2-round game needs, per round, one truth tick, two forgery ticks and about three ticks for
// each of the three cards (vote, reveal and a retry); this is generous headroom, not a target.
const MAX_TICKS = 90;

// 100% disjoint single-word vocabulary pools (no overlap, Jaccard = 0.0)
const WORD_POOLS = [
  ['Emerald', 'Sapphire', 'Diamond', 'Amethyst', 'Topaz', 'Ruby', 'Obsidian', 'Opal', 'Quartz', 'Garnet'],
  ['Falcon', 'Panther', 'Grizzly', 'Stallion', 'Cheetah', 'Badger', 'Dolphin', 'Condor', 'Jaguar', 'Mammoth'],
  ['Archimedes', 'Galileo', 'Copernicus', 'Newton', 'Kepler', 'Pascal', 'Descartes', 'Tesla', 'Aristotle', 'Edison']
];

async function run(browser) {
  console.log('===========================================================');
  console.log('=== RUNNING MATCH SUMMARY MULTI-ROUND PLAYTHROUGH (§2) ===');
  console.log('===========================================================\n');

  const ctx1 = await browser.newContext({ viewport: VIEWPORT });
  const ctx2 = await browser.newContext({ viewport: VIEWPORT });
  const ctx3 = await browser.newContext({ viewport: VIEWPORT });

  const p1 = labelPage(await ctx1.newPage(), 'P1');
  const p2 = labelPage(await ctx2.newPage(), 'P2');
  const p3 = labelPage(await ctx3.newPage(), 'P3');

  // 1. P1 Host Room
  console.log('[1/7] P1 loading app & hosting room...');
  await openApp(p1, APP_URL);
  const roomCode = await createRoom(p1, FIXTURE.ALICE);
  console.log(`[1/7] Room Created! Code: "${roomCode}"`);

  // Adjust Lobby Settings: Total Rounds = 2, Disable Timers = ON. Each is read before it is
  // clicked and asserted afterwards (timers start disabled, so the switch is usually left alone).
  console.log('[2/7] Setting 2 rounds & disabling timers on P1...');
  await ensureRounds(p1, roomCode, 2);
  const settings = await ensureTimersDisabled(p1, roomCode);
  assertThat(settings.totalRounds === 2, '[2/7] totalRounds === 2');
  assertThat(settings.isTimerDisabled === true, '[2/7] isTimerDisabled === true');

  // 2. P2 Join Room (Bob)
  console.log('[3/7] P2 (Bob) joining room from Context 2...');
  await openApp(p2, APP_URL);
  await joinRoom(p2, FIXTURE.BOB, roomCode);

  // 3. P3 Join Room (Charlie)
  console.log('[4/7] P3 (Charlie) joining room from Context 3...');
  await openApp(p3, APP_URL);
  await joinRoom(p3, FIXTURE.CHARLIE, roomCode);

  // Ready up P2 & P3
  console.log('[5/7] Readying up P2 & P3...');
  await clickElement(p2, n => n.text === UI.IM_READY, "P2 I'M READY");
  await clickElement(p3, n => n.text === UI.IM_READY, "P3 I'M READY");
  await waitFor(async () => (await readPlayers(roomCode)).filter(p => !p.isHost).every(p => p.lobbyReady === true), {
    timeoutMs: 10000,
    description: 'Bob and Charlie to be lobbyReady'
  });

  // Start Game
  console.log('[6/7] Starting Game on P1...');
  await clickElement(p1, n => n.role === 'button' && n.text === UI.START_GAME, 'START GAME');
  await waitForRoom(roomCode, r => r.currentPhase === 'truth', { timeoutMs: 20000, description: 'the room to enter the truth phase' });

  // Run match to game over
  console.log('[7/7] Advancing multi-round match to GameOver...');
  const seats = [
    { name: FIXTURE.ALICE, page: p1 },
    { name: FIXTURE.BOB, page: p2 },
    { name: FIXTURE.CHARLIE, page: p3 }
  ];
  await driveToGameOver({
    code: roomCode,
    players: seats,
    maxTicks: MAX_TICKS,
    // Each seat's n-th answer is the n-th word of its own pool, so no answer is ever too similar to
    // another seat's.
    craftTextFor: (seat, name, phase, n) => WORD_POOLS[seat][n % WORD_POOLS[seat].length],
    // Bob and Charlie vote for Alice's words (so Alice's forgeries get voted on); Alice takes the first card she can.
    votePreferFor: name => (name === FIXTURE.ALICE ? null : WORD_POOLS[0])
  });

  const finalRoom = await readRoom(roomCode);
  assertThat(finalRoom.currentPhase === 'gameOver', 'the room is in the gameOver phase');
  assertThat(finalRoom.currentRound === 2, `the match reached round 2 (currentRound === ${finalRoom.currentRound})`);

  // Wait 10 seconds for engraving ceremony to finish
  console.log('Reached GameOver! Waiting for engraving ceremony and match summary...');
  await p1.waitForTimeout(10000);

  // Capture top of GameOver (Standings & Podium)
  await saveScreenshot(p1, 'w20_gameover_standings.png');

  // Scroll down to reveal Match Highlights
  console.log('Scrolling down to Match Highlights...');
  await p1.mouse.move(640, 500);
  await p1.mouse.wheel(0, 600);
  await p1.waitForTimeout(500);
  await p1.mouse.down();
  await p1.mouse.move(640, 150, { steps: 15 });
  await p1.mouse.up();
  await p1.waitForTimeout(1500);

  const scrolledEls = await waitForScreen(p1, els => hasText(els, UI.MATCH_HIGHLIGHTS), {
    timeoutMs: 10000,
    description: `to show "${UI.MATCH_HIGHLIGHTS}" on the game over screen`
  });
  const scrolledTexts = scrolledEls.map(e => `[${e.role || e.tag}] ${e.text}`).filter(t => t.length > 3);
  console.log('\n=== P1 SCROLLED SEMANTICS ON GAME OVER ===');
  console.log(scrolledTexts.join('\n'));

  // Save screenshot of Match Highlights section
  await saveScreenshot(p1, 'w20_match_summary.png');

  // Drag a bit more to capture detail
  await p1.mouse.move(640, 500);
  await p1.mouse.down();
  await p1.mouse.move(640, 250, { steps: 15 });
  await p1.mouse.up();
  await p1.waitForTimeout(1000);
  await saveScreenshot(p1, 'w20_best_lie_detail.png');

  assertThat(markerOf(await getSemanticsElements(p1)) === 'gameover', 'P1 is still on the game over screen after scrolling');
  console.log('\n=== MATCH SUMMARY OBSERVATION RUN FINISHED SUCCESSFULLY ===');
}

runMain('run_match_summary_playthrough.js', async () => {
  const browser = await chromium.launch({ headless: true });
  try {
    await run(browser);
  } finally {
    await browser.close().catch(() => {});
  }
});
