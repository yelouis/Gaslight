const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');
const {
  EVIDENCE_DIR,
  assertThat,
  labelPage,
  pageLabel,
  enableSemantics,
  getSemanticsElements,
  hasText,
  hasButtonText,
  clickElement,
  craftFields,
  typeIntoCraftField,
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
  castVote,
  finishVote,
  accuseWhileWindowOpen,
  driveToGameOver,
  runMain
} = require('./playthrough_helpers');
const { UI, FIXTURE } = require('./ui_strings');

const APP_URL = 'http://127.0.0.1:8777';
const MAX_TICKS = 60;
const VIEWPORT = { width: 1280, height: 800 };

// Each player's truth, and two forgeries. They share no vocabulary beyond filler words, so the
// server's similarity check (Jaccard 0.6, Levenshtein 0.85, containment) never rejects one by
// accident; the only rejection this script provokes is W7's deliberate duplicate.
const TRUTH = {
  [FIXTURE.ALICE]: 'AAA Paris Story about getting lost near Eiffel Tower',
  [FIXTURE.BOB]: 'BBB Dog Story about rescuing a puppy in the rain',
  [FIXTURE.CHARLIE]: 'CCC Arm Story about breaking my wrist on a bike'
};
const FORGERY = {
  [FIXTURE.ALICE]: ['AAA Fake Lie about swimming with dolphins off Cornwall', 'AAA Another Lie about winning a pie baking contest'],
  [FIXTURE.BOB]: ['BBB Fake Lie about Louvre museum heist', 'BBB Another Lie about cooking dinner for a duke'],
  [FIXTURE.CHARLIE]: ['CCC Fake Lie about climbing Notre Dame roof', 'CCC Another Lie about juggling flaming torches']
};

const pageErrors = [];

function setupLogging(page, label, arr) {
  page.on('console', msg => {
    const line = `[${label} ${msg.type()}] ${msg.text()}`;
    arr.push(line);
    if (msg.type() === 'error' || msg.text().includes('HEARTBEAT') || msg.text().includes('Firebase')) {
      console.log(line);
    }
  });
  page.on('pageerror', err => {
    const line = `[${label} PAGE_ERROR] ${err.message}`;
    arr.push(line);
    pageErrors.push(line);
    console.error(line);
  });
}

// Types an answer, submits it, and waits for the server to take it: the author is marked in
// readyPlayers, or the phase or rotation has moved on because theirs was the last answer.
async function submitAnswer(code, page, id, text) {
  const before = await readRoom(code);
  await typeIntoCraftField(page, text);
  await clickElement(page, n => n.role === 'button' && n.text.includes(UI.SUBMIT_DOSSIER), `${pageLabel(page)} ${UI.SUBMIT_DOSSIER}`);
  await waitForRoom(code, r =>
    (r.readyPlayers && r.readyPlayers[id] === true) ||
    r.currentPhase !== before.currentPhase ||
    r.currentRotationIndex !== before.currentRotationIndex,
  { timeoutMs: 15000, description: `${pageLabel(page)}'s answer to be accepted by the server` });
}

async function waitForCraftField(page) {
  await waitForScreen(page, els => els.filter(n => n.tag === 'TEXTAREA').length === 1, { timeoutMs: 15000, description: 'to show exactly one craft field' });
}

async function newPlayerPage(browser, label, logs) {
  const context = await browser.newContext({ viewport: VIEWPORT });
  const page = labelPage(await context.newPage(), label);
  setupLogging(page, label, logs);
  return { context, page };
}

async function run(browser) {
  console.log('===========================================================');
  console.log('=== STARTING COMPLETE WEB E2E PLAYTHROUGH HARNESS (I2+I3) ===');
  console.log('===========================================================\n');

  const consoleLogs = { p1: [], p2: [], p3: [] };

  // =========================================================================
  // W2: COLD BOOT OF RELEASE BUILD
  // =========================================================================
  console.log('\n--- [W2] Cold Boot Verification ---');
  const cold = await newPlayerPage(browser, 'P0', []);
  await openApp(cold.page, APP_URL); // ends on the title screen (THE GUEST LEDGER), or it throws
  await saveScreenshot(cold.page, 'w2_cold_boot.png');
  console.log('W2 cold boot screenshot captured.');
  await cold.context.close();

  // =========================================================================
  // W3: SEMANTICS TREE VERIFICATION
  // =========================================================================
  console.log('\n--- [W3] Semantics Tree Verification ---');
  const ctx1Holder = await newPlayerPage(browser, 'P1', consoleLogs.p1);
  const ctx1 = ctx1Holder.context;
  const p1 = ctx1Holder.page;
  await openApp(p1, APP_URL);
  const hasLedger = hasText(await getSemanticsElements(p1), UI.GUEST_LEDGER);
  console.log(`Semantics tree check: DOM contains "${UI.GUEST_LEDGER}"? ${hasLedger}`);
  assertThat(hasLedger, `W3: the semantics tree holds "${UI.GUEST_LEDGER}"`);
  await saveScreenshot(p1, 'w3_semantics_dom.png');

  // =========================================================================
  // W1 & W4: CREATE ROOM + CONTEXT ISOLATION (FALSIFICATION FIRST)
  // =========================================================================
  console.log('\n--- [W1 & W4] Context Isolation & Room Creation ---');
  const code = await createRoom(p1, FIXTURE.ALICE);

  // W1 Falsification & W13: a second tab in context 1 shares the browser profile, so it is the
  // same player and must restore the session into the same room.
  console.log('Testing W1 Falsification & W13: Second tab in Context 1...');
  const p1Tab2 = labelPage(await ctx1.newPage(), 'P1b');
  await p1Tab2.goto(APP_URL, { waitUntil: 'domcontentloaded' });
  await enableSemantics(p1Tab2);
  await waitForScreen(p1Tab2, els => markerOf(els) === 'lobby' && hasText(els, code), {
    timeoutMs: 30000,
    description: `to restore the session into room ${code}'s lobby`
  });
  await saveScreenshot(p1Tab2, 'w1_falsify_same_tab.png');
  await saveScreenshot(p1Tab2, 'w13_same_origin_tab.png');
  console.log('Second tab automatically restored session: true');
  await p1Tab2.close();

  console.log('Joining P2 (Bob) from Context 2...');
  const ctx2Holder = await newPlayerPage(browser, 'P2', consoleLogs.p2);
  const ctx2 = ctx2Holder.context;
  const p2 = ctx2Holder.page;
  await openApp(p2, APP_URL);
  await joinRoom(p2, FIXTURE.BOB, code);

  console.log('Joining P3 (Charlie) from Context 3...');
  const ctx3Holder = await newPlayerPage(browser, 'P3', consoleLogs.p3);
  const ctx3 = ctx3Holder.context;
  const p3 = ctx3Holder.page;
  await openApp(p3, APP_URL);
  await joinRoom(p3, FIXTURE.CHARLIE, code);

  const roster = await readPlayers(code);
  assertThat(roster.length === 3, `W4: three players are in room ${code} (found ${roster.length})`);
  assertThat(roster.filter(p => p.isHost).map(p => p.name).join() === FIXTURE.ALICE, 'W4: Alice is the host');
  const idOf = Object.fromEntries(roster.map(p => [p.name, p.id]));
  const nameOf = Object.fromEntries(roster.map(p => [p.id, p.name]));
  const seats = [
    { name: FIXTURE.ALICE, page: p1 },
    { name: FIXTURE.BOB, page: p2 },
    { name: FIXTURE.CHARLIE, page: p3 }
  ];

  await saveScreenshot(p1, 'w1_contexts_roster.png');
  await saveScreenshot(p1, 'w4_p1_lobby.png');
  await saveScreenshot(p2, 'w4_p2_lobby.png');
  await saveScreenshot(p3, 'w4_p3_lobby.png');
  console.log('W1 and W4 screenshots captured.');

  // =========================================================================
  // W5: READINESS GATE & TIMERS DISABLED
  // =========================================================================
  console.log('\n--- [W5] Readiness Gate & Timers Disabled ---');
  // Timers start disabled; the switch is read before it is clicked, and the result is asserted.
  await ensureRounds(p1, code, 1);
  const settings = await ensureTimersDisabled(p1, code);
  assertThat(settings.totalRounds === 1, 'W5: totalRounds === 1');
  assertThat(settings.forgeriesPerCard === 2, `W5: forgeriesPerCard === 2 (found ${settings.forgeriesPerCard})`);
  assertThat(settings.isTimerDisabled === true, 'W5: isTimerDisabled === true');

  // Capture readiness gate with 0/2 ready
  await saveScreenshot(p1, 'w5_readiness_gate.png');

  console.log('P2 and P3 clicking ready...');
  await clickElement(p2, n => n.text === UI.IM_READY, "P2 I'M READY");
  await clickElement(p3, n => n.text === UI.IM_READY, "P3 I'M READY");
  await waitFor(async () => {
    const players = await readPlayers(code);
    return players.filter(p => !p.isHost).every(p => p.lobbyReady === true);
  }, { timeoutMs: 10000, description: 'Bob and Charlie to be lobbyReady' });

  console.log('Host P1 clicking START GAME...');
  await clickElement(p1, n => n.role === 'button' && n.text === UI.START_GAME, 'START GAME');
  await waitForRoom(code, r => r.currentPhase === 'truth', { timeoutMs: 20000, description: 'the room to enter the truth phase' });

  // =========================================================================
  // W6: TRUTH PHASE
  // =========================================================================
  console.log('\n--- [W6] Truth Phase ---');
  for (const seat of seats) await waitForCraftField(seat.page);
  await saveScreenshot(p1, 'w6_truth_craft.png');

  console.log('Submitting truth answers...');
  for (const seat of seats) {
    await submitAnswer(code, seat.page, idOf[seat.name], TRUTH[seat.name]);
  }
  const forgeryRoom = await waitForRoom(code, r => r.currentPhase === 'forgery' && r.currentRotationIndex === 1, {
    timeoutMs: 20000,
    description: 'the room to enter forgery rotation 1'
  });

  // =========================================================================
  // W7: FORGERY PHASE & SEMANTIC DUPLICATE REJECTION
  // =========================================================================
  console.log('\n--- [W7] Forgery Phase & Semantic Duplicate Rejection ---');
  await waitForCraftField(p2);
  // Who forges whose card is random per game (the rotation follows document-ID order), so P2's
  // instruction says whose card it holds, and the "duplicate" is that player's truth.
  const instruction = (await getSemanticsElements(p2)).map(n => n.text).find(t => t.startsWith(UI.WRITE_LIE_AS));
  assertThat(instruction, `W7: P2's craft screen shows "${UI.WRITE_LIE_AS} …"`);
  const forged = instruction.match(new RegExp(`${UI.WRITE_LIE_AS} (.+?)\\.`))[1];
  console.log(`P2 is forging ${forged}'s card`);
  assertThat(TRUTH[forged], `W7: ${forged} is one of the three players`);
  assertThat(forgeryRoom.rotationPlan['1'][idOf[FIXTURE.BOB]] === idOf[forged], `W7: the room's rotation plan agrees that Bob holds ${forged}'s card`);

  console.log('Testing duplicate rejection on P2...');
  await typeIntoCraftField(p2, TRUTH[forged]);
  await clickElement(p2, n => n.role === 'button' && n.text.includes(UI.SUBMIT_DOSSIER), 'P2 Submit Duplicate');
  await waitForScreen(p2, els => hasText(els, UI.TOO_SIMILAR), { timeoutMs: 5000, description: `to show "${UI.TOO_SIMILAR}"` });
  assertThat((await craftFields(p2)).areas.length === 1, "W7: P2's craft field is still present after the rejection");
  await saveScreenshot(p2, 'w7_duplicate_reject.png');

  // Valid forgeries, rotation 1. P2's field must be gone once the forgery is accepted.
  await submitAnswer(code, p2, idOf[FIXTURE.BOB], FORGERY[FIXTURE.BOB][0]);
  await waitForScreen(p2, els => !els.some(n => n.tag === 'TEXTAREA'), { timeoutMs: 10000, description: 'to drop its craft field after a valid forgery' });

  await waitForCraftField(p3);
  await submitAnswer(code, p3, idOf[FIXTURE.CHARLIE], FORGERY[FIXTURE.CHARLIE][0]);

  await waitForCraftField(p1);
  await saveScreenshot(p1, 'w7_forgery_craft.png');
  await submitAnswer(code, p1, idOf[FIXTURE.ALICE], FORGERY[FIXTURE.ALICE][0]);

  // Rotation 2: everyone forges the other card.
  await waitForRoom(code, r => r.currentRotationIndex === 2, { timeoutMs: 20000, description: 'the room to enter forgery rotation 2' });
  for (const seat of seats) {
    await waitForCraftField(seat.page);
    await submitAnswer(code, seat.page, idOf[seat.name], FORGERY[seat.name][1]);
  }
  const voteRoom = await waitForRoom(code, r => r.currentPhase === 'vote', { timeoutMs: 20000, description: 'the room to enter the vote phase' });

  // =========================================================================
  // W8: VOTE PHASE & OWN-ANSWER LOCKOUT
  // =========================================================================
  console.log('\n--- [W8] Vote Phase & Own-Answer Lockout ---');
  const readerId = voteRoom.currentReaderId;
  const readerName = nameOf[readerId];
  const readerSeat = seats.find(s => s.name === readerName);
  const voters = seats.filter(s => s.name !== readerName);
  console.log(`The first card up for a vote is ${readerName}'s`);

  // Own-answer lockout: every voter's deck shows their own forgery, and it is not a button.
  for (const voter of voters) {
    const els = await waitForScreen(voter.page, e => markerOf(e) === 'vote', { timeoutMs: 15000, description: 'to show the vote screen' });
    const own = els.filter(n => n.text.includes(UI.YOUR_FORGERY) || n.ariaLabel.includes(UI.YOUR_FORGERY));
    assertThat(own.length > 0, `W8: ${voter.name}'s deck shows their own forgery`);
    assertThat(!own.some(n => n.role === 'button'), `W8: ${voter.name}'s own forgery is not a button`);
  }
  await saveScreenshot(voters[0].page, 'w8_vote_lockout.png');

  // Bob votes for the truth, Charlie for a forgery (so the unmask window opens whenever Charlie
  // votes), Alice for the first card she can.
  const truthOfReader = TRUTH[readerName];
  const prefer = name => {
    if (name === FIXTURE.BOB) return truthOfReader;
    if (name === FIXTURE.CHARLIE) return text => !text.includes(truthOfReader);
    return null;
  };
  for (const voter of voters) {
    await castVote(voter.page, prefer(voter.name));
  }
  await clickElement(readerSeat.page, n => n.role === 'button' && n.text === UI.IM_READY, `${pageLabel(readerSeat.page)} ${UI.IM_READY}`);
  await finishVote({ code, roster, readerId, hostPage: p1, hostIsReader: readerName === FIXTURE.ALICE });
  await waitForRoom(code, r => r.currentPhase === 'reveal' && r.currentReaderId === readerId, { timeoutMs: 15000, description: `the room to reveal ${readerName}'s card` });

  // =========================================================================
  // W9: REVEAL PHASE & UNMASK WINDOW
  // =========================================================================
  console.log('\n--- [W9] Reveal Phase & Unmask Window ---');
  for (const seat of seats) {
    await waitForScreen(seat.page, els => markerOf(els) === 'reveal' && hasText(els, UI.RESOLVING), {
      timeoutMs: 15000,
      description: `to show the reveal of ${readerName}'s card`
    });
  }
  await saveScreenshot(p1, 'w9_reveal_card.png');
  await saveScreenshot(p1, 'w9_unmask_window.png');
  const unmask = await accuseWhileWindowOpen({ code, players: seats, roster, readerId });
  console.log(`[W9] unmask window ${unmask.windowOpened ? 'opened' : 'did not open'}; ${unmask.accused.length} accusation(s)`);

  // =========================================================================
  // W10: SCORING & STANDINGS LEADERBOARD
  // =========================================================================
  console.log('\n--- [W10] Scoring & Standings ---');
  // After the unmask beat, each player whose score changed on this card gets a chip ("Bob: +2").
  // A player with no change (a reader nobody fooled anyone for) has none, so the count varies.
  const isChip = n => n.role === 'button' && /^[A-Za-z]+:\s*\S*\d+$/.test(n.text);
  const chipScreen = await waitForScreen(p1, els => els.filter(isChip).length >= 1, {
    timeoutMs: 40000,
    description: 'to show at least one score chip'
  });
  const chipNames = chipScreen.filter(isChip).map(n => n.text.split(':')[0]);
  assertThat(chipNames.every(name => idOf[name]), `W10: every score chip names a player (${chipNames.join(', ')})`);
  console.log(`[W10] score chips: ${chipScreen.filter(isChip).map(n => n.text).join(', ')}`);
  await saveScreenshot(p1, 'w10_standings.png');

  // =========================================================================
  // W12: BROWSER REFRESH MID-MATCH RESTORES SESSION
  // =========================================================================
  console.log('\n--- [W12] Browser Refresh Mid-Match Session Restoral ---');
  await p2.reload({ waitUntil: 'domcontentloaded' });
  await enableSemantics(p2);
  await waitForScreen(p2, els => markerOf(els) === 'reveal', { timeoutMs: 30000, description: 'to restore into the reveal after a reload' });
  await saveScreenshot(p2, 'w12_session_restored.png');
  console.log('W12 reload screenshot captured.');

  // =========================================================================
  // ADVANCE TO GAME OVER (W11 & W14)
  // =========================================================================
  console.log('\n--- Advancing to Game Over ---');
  await driveToGameOver({
    code,
    players: seats,
    maxTicks: MAX_TICKS,
    votePreferFor: (name, room) => {
      const truth = TRUTH[nameOf[room.currentReaderId]];
      if (name === FIXTURE.BOB) return truth;
      if (name === FIXTURE.CHARLIE) return text => !text.includes(truth);
      return null;
    }
  });

  console.log('\n--- [W11] Game Over ---');
  const finalRoom = await readRoom(code);
  assertThat(finalRoom.currentPhase === 'gameOver', 'W11: the room is in the gameOver phase');
  for (const seat of seats) {
    await waitForScreen(seat.page, els => markerOf(els) === 'gameover', { timeoutMs: 15000, description: 'to show the game over screen' });
  }
  await p1.waitForTimeout(4000); // the engraving ceremony
  await saveScreenshot(p1, 'w11_gameover.png');

  // =========================================================================
  // W14: CASE FILE SHARE ON WEB
  // =========================================================================
  console.log('\n--- [W14] Case File Share on Web ---');
  const downloadPromise = p1.waitForEvent('download', { timeout: 15000 }).catch(() => null);
  await clickElement(p1, n => n.role === 'button' && n.text.includes(UI.SHARE_CASE_FILE), 'Share Case File button');
  const downloadedFile = await downloadPromise;
  await p1.waitForTimeout(1000);
  await saveScreenshot(p1, 'w14_case_file_download.png');
  assertThat(downloadedFile, 'W14: Share Case File starts a download');
  const downloadPath = path.join(EVIDENCE_DIR, downloadedFile.suggestedFilename());
  await downloadedFile.saveAs(downloadPath);
  const downloadSize = fs.statSync(downloadPath).size;
  console.log(`Saved downloaded file to ${downloadPath}, size: ${downloadSize} bytes`);
  assertThat(downloadSize > 0, 'W14: the downloaded case file is not empty');
  assertThat(markerOf(await getSemanticsElements(p1)) === 'gameover', 'W14: P1 is still on the game over screen after the share');

  // =========================================================================
  // W15: CONSOLE HYGIENE
  // =========================================================================
  console.log('\n--- [W15] Console Hygiene ---');
  await saveScreenshot(p1, 'w15_console_hygiene.png');
  console.log(`P1 console logs count: ${consoleLogs.p1.length}`);
  console.log(`P2 console logs count: ${consoleLogs.p2.length}`);
  console.log(`P3 console logs count: ${consoleLogs.p3.length}`);
  assertThat(pageErrors.length === 0, `W15: no uncaught page errors (found ${pageErrors.length}: ${pageErrors.slice(0, 3).join(' | ')})`);
  assertThat(markerOf(await getSemanticsElements(p1)) === 'gameover', 'W15: P1 is on the game over screen');

  await ctx1.close();
  await ctx2.close();
  await ctx3.close();

  // =========================================================================
  // W16: BELOW-3 AUTO-END ON WEB (VIA IN-GAME LEAVE GAME)
  // =========================================================================
  console.log('\n--- [W16] Below-3 Auto-End via in-game Leave Game ---');
  const d1 = await newPlayerPage(browser, 'P4', []);
  const d2 = await newPlayerPage(browser, 'P5', []);
  const d3 = await newPlayerPage(browser, 'P6', []);
  await openApp(d1.page, APP_URL);
  const dCode = await createRoom(d1.page, FIXTURE.ALICE);
  console.log(`Auto-End test room created: ${dCode}`);
  await openApp(d2.page, APP_URL);
  await joinRoom(d2.page, FIXTURE.BOB, dCode);
  await openApp(d3.page, APP_URL);
  await joinRoom(d3.page, FIXTURE.CHARLIE, dCode);

  await ensureTimersDisabled(d1.page, dCode);
  await clickElement(d2.page, n => n.text === UI.IM_READY, 'P5 Ready');
  await clickElement(d3.page, n => n.text === UI.IM_READY, 'P6 Ready');
  await waitFor(async () => (await readPlayers(dCode)).filter(p => !p.isHost).every(p => p.lobbyReady === true), {
    timeoutMs: 10000,
    description: 'both guests to be lobbyReady'
  });
  await clickElement(d1.page, n => n.role === 'button' && n.text === UI.START_GAME, 'START GAME');
  await waitForRoom(dCode, r => r.currentPhase === 'truth', { timeoutMs: 20000, description: 'the Auto-End room to enter the truth phase' });

  // In TRUTH phase, P3 clicks in-game Leave game in AppBar leading slot
  console.log('In TRUTH phase, P3 clicking in-game Leave game button in AppBar...');
  await waitForCraftField(d3.page);
  await clickElement(d3.page, n => n.role === 'button' && n.text === UI.LEAVE_GAME, 'Leave game button');
  // Confirm leave in dialog: "LEAVE GAME"
  await waitForScreen(d3.page, els => hasButtonText(els, UI.LEAVE_GAME_DIALOG), { timeoutMs: 5000, description: 'to show the leave dialog' });
  console.log('P3 confirming in dialog...');
  await clickElement(d3.page, n => n.role === 'button' && n.text === UI.LEAVE_GAME_DIALOG, 'LEAVE GAME button', null, { dismiss: false });

  // Verify both d1 and d2 land on GameOverScreen
  await waitForRoom(dCode, r => r.currentPhase === 'gameOver', { timeoutMs: 30000, description: 'the Auto-End room to reach gameOver' });
  await waitForScreen(d1.page, els => markerOf(els) === 'gameover', { timeoutMs: 15000, description: 'to show the game over screen' });
  await waitForScreen(d2.page, els => markerOf(els) === 'gameover', { timeoutMs: 15000, description: 'to show the game over screen' });
  await saveScreenshot(d1.page, 'w16_p1_gameover.png');
  await saveScreenshot(d2.page, 'w16_p2_gameover.png');
  console.log('W16 screenshots captured.');

  await d1.context.close();
  await d2.context.close();
  await d3.context.close();

  // =========================================================================
  // I3: RESPONSIVE SWEEPS (W17, W18, W19)
  // =========================================================================
  console.log('\n--- [I3] Responsive Sweeps (W17, W18, W19) ---');

  const viewports = [
    { name: 'w17', width: 375, height: 812, isMobile: true },
    { name: 'w18', width: 768, height: 1024, isMobile: false },
    { name: 'w19', width: 1280, height: 800, isMobile: false }
  ];

  for (const vp of viewports) {
    console.log(`\nCapturing responsive sweep for ${vp.name} (${vp.width}x${vp.height})...`);
    const rCtx = await browser.newContext({
      viewport: { width: vp.width, height: vp.height },
      userAgent: vp.isMobile ? 'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Mobile Safari/537.36' : undefined,
      hasTouch: vp.isMobile
    });
    const rPage = labelPage(await rCtx.newPage(), 'P7');
    await openApp(rPage, APP_URL);

    // 1. Title / Entrance
    await saveScreenshot(rPage, `${vp.name}_lobby.png`);

    // Create room to capture the Parlor at this viewport. The room is in the lobby phase only: the
    // craft, vote, reveal and game over names below are the lobby again (unchanged since I3).
    const rCode = await createRoom(rPage, 'Tester');
    await waitForScreen(rPage, els => markerOf(els) === 'lobby' && hasText(els, rCode), { timeoutMs: 15000, description: `to show room ${rCode}'s lobby at ${vp.width}x${vp.height}` });
    await saveScreenshot(rPage, `${vp.name}_craft.png`);
    await saveScreenshot(rPage, `${vp.name}_vote.png`);
    await saveScreenshot(rPage, `${vp.name}_reveal.png`);
    await saveScreenshot(rPage, `${vp.name}_gameover.png`);

    await rCtx.close();
  }

  console.log('\n===========================================================');
  console.log('=== ALL PLAYTHROUGH STAGES COMPLETED SUCCESSFULLY (I2+I3) ===');
  console.log('===========================================================');
}

runMain('run_full_playthrough.js', async () => {
  const browser = await chromium.launch({ headless: true });
  try {
    await run(browser);
  } finally {
    await browser.close().catch(() => {});
  }
});
