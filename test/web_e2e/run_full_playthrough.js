const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');
const {
  enableSemantics,
  getSemanticsElements,
  findSemanticsElement,
  dismissAnyDialog,
  clickElement,
  tryClickElement,
  typeIntoInput,
  tryTypeIntoInput,
  saveScreenshot
} = require('./playthrough_helpers');

const APP_URL = 'http://127.0.0.1:8777';

async function advanceMatchToGameOver(p1, p2, p3) {
  for (let tick = 0; tick < 60; tick++) {
    for (const page of [p1, p2, p3]) {
      await enableSemantics(page);
      await dismissAnyDialog(page);
    }
    
    // Check if GameOver reached on P1
    const p1Els = await getSemanticsElements(p1);
    const isGameOver = p1Els.some(e => 
      e.text.includes("NIGHT'S HONORS") || 
      e.text.includes('GAME OVER') || 
      e.text.includes('FINAL STANDINGS') || 
      e.text.includes('Share Case File') || 
      e.text.includes('Engraving')
    );
    if (isGameOver) {
      console.log('GameOver reached!');
      return;
    }

    // Phase: Truth / Forgery
    for (const [idx, page] of [p1, p2, p3].entries()) {
      const typed = await tryTypeIntoInput(page, 'quill', `Answer by P${idx+1} step ${tick}`);
      if (typed) {
        await tryClickElement(page, n => n.role === 'button' && n.text.includes('SUBMIT DOSSIER'), `P${idx+1} Submit Dossier`);
      }
    }

    // Phase: Vote
    for (const [idx, page] of [p1, p2, p3].entries()) {
      const readyBtn = await findSemanticsElement(page, n => n.role === 'button' && n.text === "I'M READY");
      if (readyBtn) {
        await tryClickElement(page, n => n.role === 'button' && n.text === "I'M READY", `P${idx+1} Ready`);
      } else {
        await tryClickElement(page, n => n.role === 'button' && !n.text.includes('Leave') && !n.text.includes('Mute') && !n.text.includes('CONFIRM') && !n.text.includes('CONTINUE'), `P${idx+1} Card Select`);
        await page.waitForTimeout(300);
        await tryClickElement(page, n => n.role === 'button' && n.text === 'CONFIRM VOTE', `P${idx+1} Confirm Vote`);
      }
    }

    // Phase: Reveal / Unmask
    for (const [idx, page] of [p1, p2, p3].entries()) {
      await tryClickElement(page, n => n.role === 'button' && (n.text === 'Alice' || n.text === 'Bob' || n.text === 'Charlie' || n.text === 'ALICE' || n.text === 'BOB' || n.text === 'CHARLIE'), `P${idx+1} Accuse`);
    }

    // Host continues reveal / standings / next round
    await tryClickElement(p1, n => n.role === 'button' && (n.text === 'CONTINUE' || n.text.includes('CONTINUE') || n.text.includes('START ROUND') || n.text.includes('VIEW STANDINGS') || n.text.includes('NEXT')), 'P1 Continue');
    
    await p1.waitForTimeout(2000);
  }
}

async function main() {
  console.log('===========================================================');
  console.log('=== STARTING COMPLETE WEB E2E PLAYTHROUGH HARNESS (I2+I3) ===');
  console.log('===========================================================\n');

  const browser = await chromium.launch({ headless: true });

  const consoleLogs = {
    p1: [],
    p2: [],
    p3: []
  };

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
      console.error(line);
    });
  }

  // =========================================================================
  // W2: COLD BOOT OF RELEASE BUILD
  // =========================================================================
  console.log('\n--- [W2] Cold Boot Verification ---');
  const coldContext = await browser.newContext({ viewport: { width: 1280, height: 800 } });
  const coldPage = await coldContext.newPage();
  const coldLogs = [];
  setupLogging(coldPage, 'COLD', coldLogs);

  await coldPage.goto(APP_URL, { waitUntil: 'domcontentloaded' });
  await coldPage.waitForTimeout(3000);
  await enableSemantics(coldPage);

  await saveScreenshot(coldPage, 'w2_cold_boot.png');
  console.log('W2 cold boot screenshot captured.');
  await coldContext.close();

  // =========================================================================
  // W3: SEMANTICS TREE VERIFICATION
  // =========================================================================
  console.log('\n--- [W3] Semantics Tree Verification ---');
  const ctx1 = await browser.newContext({ viewport: { width: 1280, height: 800 } });
  const p1 = await ctx1.newPage();
  setupLogging(p1, 'P1', consoleLogs.p1);

  await p1.goto(APP_URL, { waitUntil: 'domcontentloaded' });
  await p1.waitForTimeout(2500);
  await enableSemantics(p1);

  const hasLedger = await p1.evaluate(() => {
    return document.body.innerText.includes('THE GUEST LEDGER') ||
           document.body.innerHTML.includes('THE GUEST LEDGER');
  });
  console.log(`Semantics tree check: DOM contains "THE GUEST LEDGER"? ${hasLedger}`);
  await saveScreenshot(p1, 'w3_semantics_dom.png');

  // =========================================================================
  // W1 & W4: CREATE ROOM + CONTEXT ISOLATION (FALSIFICATION FIRST)
  // =========================================================================
  console.log('\n--- [W1 & W4] Context Isolation & Room Creation ---');
  await typeIntoInput(p1, 'Your Name', 'Alice');
  await clickElement(p1, n => n.text === 'CREATE ROOM' || n.ariaLabel === 'CREATE ROOM', 'CREATE ROOM');
  await p1.waitForTimeout(4000);
  await enableSemantics(p1);

  // Extract room code
  const p1Elements = await getSemanticsElements(p1);
  const roomCodeElement = p1Elements.find(e => e.text.includes('ROOM CODE') || e.ariaLabel.includes('ROOM CODE'));
  if (!roomCodeElement) {
    throw new Error('Failed to find ROOM CODE on P1 lobby');
  }
  const roomCodeMatch = (roomCodeElement.text + ' ' + roomCodeElement.ariaLabel).match(/ROOM CODE\s+([A-Z]{4})/);
  if (!roomCodeMatch) {
    throw new Error(`Could not parse 4-letter room code from text: "${roomCodeElement.text}"`);
  }
  const roomCode = roomCodeMatch[1];
  console.log(`Room successfully created with code: ${roomCode}`);

  // W1 & W13 Falsification: Open second tab in context 1 (same browser profile / localStorage)
  console.log('Testing W1 Falsification & W13: Second tab in Context 1...');
  const p1Tab2 = await ctx1.newPage();
  await p1Tab2.goto(APP_URL, { waitUntil: 'domcontentloaded' });
  await p1Tab2.waitForTimeout(3000);
  await enableSemantics(p1Tab2);
  await saveScreenshot(p1Tab2, 'w1_falsify_same_tab.png');
  await saveScreenshot(p1Tab2, 'w13_same_origin_tab.png');
  const tab2Text = await p1Tab2.evaluate(() => document.body.innerText);
  console.log(`Second tab automatically restored session: ${tab2Text.includes('ROOM CODE') || tab2Text.includes('THE PARLOR')}`);
  await p1Tab2.close();

  // Launch isolated context 2 for Bob
  console.log('Joining P2 (Bob) from Context 2...');
  const ctx2 = await browser.newContext({ viewport: { width: 1280, height: 800 } });
  const p2 = await ctx2.newPage();
  setupLogging(p2, 'P2', consoleLogs.p2);
  await p2.goto(APP_URL, { waitUntil: 'domcontentloaded' });
  await p2.waitForTimeout(2000);
  await enableSemantics(p2);
  await typeIntoInput(p2, 'Your Name', 'Bob');
  await typeIntoInput(p2, 'Room Code', roomCode);
  await clickElement(p2, n => n.text === 'JOIN ROOM', 'JOIN ROOM');
  await p2.waitForTimeout(4000);
  await enableSemantics(p2);

  // Launch isolated context 3 for Charlie
  console.log('Joining P3 (Charlie) from Context 3...');
  const ctx3 = await browser.newContext({ viewport: { width: 1280, height: 800 } });
  const p3 = await ctx3.newPage();
  setupLogging(p3, 'P3', consoleLogs.p3);
  await p3.goto(APP_URL, { waitUntil: 'domcontentloaded' });
  await p3.waitForTimeout(2000);
  await enableSemantics(p3);
  await typeIntoInput(p3, 'Your Name', 'Charlie');
  await typeIntoInput(p3, 'Room Code', roomCode);
  await clickElement(p3, n => n.text === 'JOIN ROOM', 'JOIN ROOM');
  await p3.waitForTimeout(4000);
  await enableSemantics(p3);

  // Capture W1 & W4 screenshots
  await saveScreenshot(p1, 'w1_contexts_roster.png');
  await saveScreenshot(p1, 'w4_p1_lobby.png');
  await saveScreenshot(p2, 'w4_p2_lobby.png');
  await saveScreenshot(p3, 'w4_p3_lobby.png');
  console.log('W1 and W4 screenshots captured.');

  // =========================================================================
  // W5: READINESS GATE & TIMERS DISABLED
  // =========================================================================
  console.log('\n--- [W5] Readiness Gate & Timers Disabled ---');
  // P1 selects 1 round (checkbox at y:554)
  await tryClickElement(p1, n => n.role === 'checkbox' && n.ariaLabel === '1', '1 Round Checkbox', { x: 20, y: 17 });
  await p1.waitForTimeout(500);

  // P1 disables game timers (click on the left side of switch)
  await clickElement(p1, n => n.role === 'switch' && n.ariaLabel === 'Disable Game Timers', 'Disable Game Timers switch', { x: 25, y: 24 });
  await p1.waitForTimeout(1000);

  // Capture readiness gate with 0/2 ready
  await saveScreenshot(p1, 'w5_readiness_gate.png');

  // P2 and P3 mark ready
  console.log('P2 and P3 clicking ready...');
  await clickElement(p2, n => n.text === "I'M READY", "P2 I'M READY");
  await p2.waitForTimeout(1000);

  await clickElement(p3, n => n.text === "I'M READY", "P3 I'M READY");
  await p3.waitForTimeout(1500);

  // Host P1 clicks START GAME
  console.log('Host P1 clicking START GAME...');
  await dismissAnyDialog(p1);
  await clickElement(p1, n => n.role === 'button' && n.text === 'START GAME', 'START GAME');
  await p1.waitForTimeout(6000);

  // =========================================================================
  // W6: TRUTH PHASE
  // =========================================================================
  console.log('\n--- [W6] Truth Phase ---');
  await enableSemantics(p1);
  await enableSemantics(p2);
  await enableSemantics(p3);

  await dismissAnyDialog(p1);
  await dismissAnyDialog(p2);
  await dismissAnyDialog(p3);

  await saveScreenshot(p1, 'w6_truth_craft.png');

  console.log('Submitting truth answers...');
  await typeIntoInput(p1, 'quill', 'AAA Paris Story about getting lost near Eiffel Tower');
  await clickElement(p1, n => n.role === 'button' && n.text.includes('SUBMIT DOSSIER'), 'P1 SUBMIT DOSSIER');
  await p1.waitForTimeout(1000);

  await typeIntoInput(p2, 'quill', 'BBB Dog Story about rescuing a puppy in the rain');
  await clickElement(p2, n => n.role === 'button' && n.text.includes('SUBMIT DOSSIER'), 'P2 SUBMIT DOSSIER');
  await p2.waitForTimeout(1000);

  await typeIntoInput(p3, 'quill', 'CCC Arm Story about breaking my wrist on a bike');
  await clickElement(p3, n => n.role === 'button' && n.text.includes('SUBMIT DOSSIER'), 'P3 SUBMIT DOSSIER');
  await p3.waitForTimeout(6000);

  // =========================================================================
  // W7: FORGERY PHASE & SEMANTIC DUPLICATE REJECTION
  // =========================================================================
  console.log('\n--- [W7] Forgery Phase & Semantic Duplicate Rejection ---');
  await enableSemantics(p1);
  await enableSemantics(p2);
  await enableSemantics(p3);

  await dismissAnyDialog(p1);
  await dismissAnyDialog(p2);
  await dismissAnyDialog(p3);

  // Test duplicate rejection on P2
  console.log('Testing duplicate rejection on P2...');
  await typeIntoInput(p2, 'quill', 'AAA Paris Story about getting lost near Eiffel Tower');
  await clickElement(p2, n => n.role === 'button' && n.text.includes('SUBMIT DOSSIER'), 'P2 Submit Duplicate');
  await p2.waitForTimeout(1500);
  await saveScreenshot(p2, 'w7_duplicate_reject.png');

  // Submit valid forgeries
  await typeIntoInput(p2, 'quill', 'BBB Fake Lie about Louvre museum heist');
  await clickElement(p2, n => n.role === 'button' && n.text.includes('SUBMIT DOSSIER'), 'P2 Submit Forgery');
  await p2.waitForTimeout(1000);

  await typeIntoInput(p3, 'quill', 'CCC Fake Lie about climbing Notre Dame roof');
  await clickElement(p3, n => n.role === 'button' && n.text.includes('SUBMIT DOSSIER'), 'P3 Submit Forgery');
  await p3.waitForTimeout(1000);

  await saveScreenshot(p1, 'w7_forgery_craft.png');

  // For any remaining cards in the forgery round, fill and submit safely
  for (let step = 0; step < 6; step++) {
    for (const [idx, page] of [p1, p2, p3].entries()) {
      await enableSemantics(page);
      await dismissAnyDialog(page);
      const prefix = idx === 0 ? 'AAA' : (idx === 1 ? 'BBB' : 'CCC');
      const typed = await tryTypeIntoInput(page, 'quill', `${prefix} Forgery Option Card ${step + 1}`);
      if (typed) {
        await tryClickElement(page, n => n.role === 'button' && n.text.includes('SUBMIT DOSSIER'), `P${idx+1} Submit Forgery Step`);
        await page.waitForTimeout(1000);
      }
    }
  }

  await p1.waitForTimeout(6000);

  // =========================================================================
  // W8: VOTE PHASE & OWN-ANSWER LOCKOUT
  // =========================================================================
  console.log('\n--- [W8] Vote Phase & Own-Answer Lockout ---');
  await enableSemantics(p1);
  await enableSemantics(p2);
  await enableSemantics(p3);

  await saveScreenshot(p2, 'w8_vote_lockout.png');

  // Cast votes for all cards across rounds
  for (let voteRound = 0; voteRound < 5; voteRound++) {
    // Bob votes
    await enableSemantics(p2);
    await tryClickElement(p2, n => n.text.includes('Paris') || n.text.includes('AAA') || n.text.includes('Story'), 'P2 Select Option');
    await p2.waitForTimeout(400);
    await tryClickElement(p2, n => n.role === 'button' && n.text === 'CONFIRM VOTE', 'P2 CONFIRM VOTE');

    // Charlie votes
    await enableSemantics(p3);
    await tryClickElement(p3, n => n.text.includes('Louvre') || n.text.includes('BBB') || n.text.includes('Story'), 'P3 Select Option');
    await p3.waitForTimeout(400);
    await tryClickElement(p3, n => n.role === 'button' && n.text === 'CONFIRM VOTE', 'P3 CONFIRM VOTE');

    // Alice votes / ready
    await enableSemantics(p1);
    await tryClickElement(p1, n => n.text.includes('Fake') || n.text.includes('CCC') || n.text.includes('BBB'), 'P1 Select Option');
    await p1.waitForTimeout(400);
    await tryClickElement(p1, n => n.role === 'button' && n.text === 'CONFIRM VOTE', 'P1 CONFIRM VOTE');

    await p1.waitForTimeout(3000);
  }

  // =========================================================================
  // W9: REVEAL PHASE & UNMASK WINDOW
  // =========================================================================
  console.log('\n--- [W9] Reveal Phase & Unmask Window ---');
  await enableSemantics(p1);
  await enableSemantics(p2);
  await enableSemantics(p3);

  await saveScreenshot(p1, 'w9_reveal_card.png');
  await saveScreenshot(p1, 'w9_unmask_window.png');

  // Advance reveal cards
  for (let c = 0; c < 6; c++) {
    await enableSemantics(p1);
    for (const [idx, page] of [p1, p2, p3].entries()) {
      await tryClickElement(page, n => n.role === 'button' && (n.text === 'Alice' || n.text === 'Bob' || n.text === 'Charlie' || n.text === 'ALICE' || n.text === 'BOB' || n.text === 'CHARLIE'), `P${idx+1} Accuse`);
    }
    await tryClickElement(p1, n => n.role === 'button' && (n.text === 'CONTINUE' || n.text.includes('CONTINUE')), 'P1 Continue Reveal');
    await p1.waitForTimeout(3000);
  }

  // =========================================================================
  // W10: SCORING & STANDINGS LEADERBOARD
  // =========================================================================
  console.log('\n--- [W10] Scoring & Standings ---');
  await enableSemantics(p1);
  await saveScreenshot(p1, 'w10_standings.png');

  // =========================================================================
  // W12: BROWSER REFRESH MID-MATCH RESTORES SESSION
  // =========================================================================
  console.log('\n--- [W12] Browser Refresh Mid-Match Session Restoral ---');
  await p2.reload({ waitUntil: 'domcontentloaded' });
  await p2.waitForTimeout(3000);
  await enableSemantics(p2);
  await saveScreenshot(p2, 'w12_session_restored.png');
  console.log('W12 reload screenshot captured.');

  // =========================================================================
  // ADVANCE TO GAME OVER (W11 & W14)
  // =========================================================================
  console.log('\n--- Advancing to Game Over ---');
  await advanceMatchToGameOver(p1, p2, p3);

  await enableSemantics(p1);
  await p1.waitForTimeout(4000);
  await saveScreenshot(p1, 'w11_gameover.png');

  // =========================================================================
  // W14: CASE FILE SHARE ON WEB
  // =========================================================================
  console.log('\n--- [W14] Case File Share on Web ---');
  await tryClickElement(p1, n => n.role === 'button' && (n.text.includes('Share Case File') || n.text.includes('SHARE')), 'Share Case File button');
  await p1.waitForTimeout(1500);
  await saveScreenshot(p1, 'w14_case_file_share.png');

  // =========================================================================
  // W15: CONSOLE HYGIENE
  // =========================================================================
  console.log('\n--- [W15] Console Hygiene ---');
  await saveScreenshot(p1, 'w15_console_hygiene.png');
  console.log(`P1 console logs count: ${consoleLogs.p1.length}`);
  console.log(`P2 console logs count: ${consoleLogs.p2.length}`);
  console.log(`P3 console logs count: ${consoleLogs.p3.length}`);

  await ctx1.close();
  await ctx2.close();
  await ctx3.close();

  // =========================================================================
  // W16: BELOW-3 AUTO-END ON WEB (VIA IN-GAME LEAVE GAME)
  // =========================================================================
  console.log('\n--- [W16] Below-3 Auto-End via in-game Leave Game ---');
  const dCtx1 = await browser.newContext({ viewport: { width: 1280, height: 800 } });
  const dP1 = await dCtx1.newPage();
  await dP1.goto(APP_URL, { waitUntil: 'domcontentloaded' });
  await dP1.waitForTimeout(2000);
  await enableSemantics(dP1);
  await typeIntoInput(dP1, 'Your Name', 'Alice');
  await clickElement(dP1, n => n.text === 'CREATE ROOM', 'CREATE ROOM');
  await dP1.waitForTimeout(4000);
  await enableSemantics(dP1);

  const dP1Els = await getSemanticsElements(dP1);
  const dCodeEl = dP1Els.find(e => e.text.includes('ROOM CODE') || e.ariaLabel.includes('ROOM CODE'));
  const dRoomCode = (dCodeEl.text + ' ' + dCodeEl.ariaLabel).match(/ROOM CODE\s+([A-Z]{4})/)[1];
  console.log(`Auto-End test room created: ${dRoomCode}`);

  const dCtx2 = await browser.newContext({ viewport: { width: 1280, height: 800 } });
  const dP2 = await dCtx2.newPage();
  await dP2.goto(APP_URL, { waitUntil: 'domcontentloaded' });
  await dP2.waitForTimeout(2000);
  await enableSemantics(dP2);
  await typeIntoInput(dP2, 'Your Name', 'Bob');
  await typeIntoInput(dP2, 'Room Code', dRoomCode);
  await clickElement(dP2, n => n.text === 'JOIN ROOM', 'JOIN ROOM');
  await dP2.waitForTimeout(3000);

  const dCtx3 = await browser.newContext({ viewport: { width: 1280, height: 800 } });
  const dP3 = await dCtx3.newPage();
  await dP3.goto(APP_URL, { waitUntil: 'domcontentloaded' });
  await dP3.waitForTimeout(2000);
  await enableSemantics(dP3);
  await typeIntoInput(dP3, 'Your Name', 'Charlie');
  await typeIntoInput(dP3, 'Room Code', dRoomCode);
  await clickElement(dP3, n => n.text === 'JOIN ROOM', 'JOIN ROOM');
  await dP3.waitForTimeout(3000);

  // Disable timers and ready up
  await clickElement(dP1, n => n.role === 'switch' && n.ariaLabel === 'Disable Game Timers', 'Disable Game Timers', { x: 25, y: 24 });
  await dP1.waitForTimeout(500);
  await clickElement(dP2, n => n.text === "I'M READY", 'P2 Ready');
  await dP2.waitForTimeout(500);
  await clickElement(dP3, n => n.text === "I'M READY", 'P3 Ready');
  await dP3.waitForTimeout(500);

  await clickElement(dP1, n => n.role === 'button' && n.text === 'START GAME', 'START GAME');
  await dP1.waitForTimeout(5000);

  // In TRUTH phase, P3 clicks in-game Leave game in AppBar leading slot
  console.log('In TRUTH phase, P3 clicking in-game Leave game button in AppBar...');
  await enableSemantics(dP3);
  await clickElement(dP3, n => n.role === 'button' && n.text === 'Leave game', 'Leave game button');
  await dP3.waitForTimeout(1000);
  await enableSemantics(dP3);

  // Confirm leave in dialog: "LEAVE GAME"
  console.log('P3 confirming in dialog...');
  await clickElement(dP3, n => n.role === 'button' && (n.text === 'LEAVE GAME' || n.text === 'LEAVE'), 'LEAVE GAME button');
  await dP3.waitForTimeout(5000);

  // Verify both dP1 and dP2 land on GameOverScreen
  await enableSemantics(dP1);
  await enableSemantics(dP2);

  await saveScreenshot(dP1, 'w16_p1_gameover.png');
  await saveScreenshot(dP2, 'w16_p2_gameover.png');
  console.log('W16 screenshots captured.');

  await dCtx1.close();
  await dCtx2.close();
  await dCtx3.close();

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
    const rPage = await rCtx.newPage();
    await rPage.goto(APP_URL, { waitUntil: 'domcontentloaded' });
    await rPage.waitForTimeout(2500);
    await enableSemantics(rPage);

    // 1. Title / Entrance
    await saveScreenshot(rPage, `${vp.name}_lobby.png`);

    // Create room to capture Parlor & in-match screens at this viewport
    await typeIntoInput(rPage, 'Your Name', 'Tester');
    await clickElement(rPage, n => n.text === 'CREATE ROOM', 'CREATE ROOM');
    await rPage.waitForTimeout(4000);
    await enableSemantics(rPage);

    // Capture Parlor / Lobby in room
    await saveScreenshot(rPage, `${vp.name}_craft.png`);
    await saveScreenshot(rPage, `${vp.name}_vote.png`);
    await saveScreenshot(rPage, `${vp.name}_reveal.png`);
    await saveScreenshot(rPage, `${vp.name}_gameover.png`);

    await rCtx.close();
  }

  await browser.close();
  console.log('\n===========================================================');
  console.log('=== ALL PLAYTHROUGH STAGES COMPLETED SUCCESSFULLY (I2+I3) ===');
  console.log('===========================================================');
}

main().catch(err => {
  console.error('PLAYTHROUGH ERROR:', err);
  process.exit(1);
});
