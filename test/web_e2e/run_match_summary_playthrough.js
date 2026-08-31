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

// 100% disjoint single-word vocabulary pools (no overlap, Jaccard = 0.0)
const WORD_POOLS = [
  ['Emerald', 'Sapphire', 'Diamond', 'Amethyst', 'Topaz', 'Ruby', 'Obsidian', 'Opal', 'Quartz', 'Garnet'],
  ['Falcon', 'Panther', 'Grizzly', 'Stallion', 'Cheetah', 'Badger', 'Dolphin', 'Condor', 'Jaguar', 'Mammoth'],
  ['Archimedes', 'Galileo', 'Copernicus', 'Newton', 'Kepler', 'Pascal', 'Descartes', 'Tesla', 'Aristotle', 'Edison']
];

async function advanceMatchToGameOver(p1, p2, p3) {
  let submitCount = [0, 0, 0];

  for (let tick = 0; tick < 120; tick++) {
    for (const page of [p1, p2, p3]) {
      await enableSemantics(page);
      await dismissAnyDialog(page);
      // Dismiss Dealt Card Overlay (INSPECT button) if present
      await tryClickElement(page, n => n.role === 'button' && (n.text === 'INSPECT' || n.text.includes('INSPECT')), 'INSPECT Overlay');
    }
    
    // Check if GameOver reached on P1
    const p1Els = await getSemanticsElements(p1);
    const isGameOver = p1Els.some(e => 
      e.text.includes("NIGHT'S HONORS") || 
      e.text.includes('GAME OVER') || 
      e.text.includes('FINAL STANDINGS') || 
      e.text.includes('Share Case File')
    );
    if (isGameOver) {
      console.log('GameOver reached!');
      return;
    }

    // 1. Phase: Truth / Forgery Crafting
    for (const [idx, page] of [p1, p2, p3].entries()) {
      // First make sure overlay is dismissed
      await tryClickElement(page, n => n.role === 'button' && (n.text === 'INSPECT' || n.text.includes('INSPECT')), `P${idx+1} Inspect`);

      const submitBtn = await findSemanticsElement(page, n => n.role === 'button' && n.text.includes('SUBMIT DOSSIER'));
      if (submitBtn) {
        const pool = WORD_POOLS[idx];
        const uniqueWord = pool[submitCount[idx] % pool.length];
        submitCount[idx]++;

        console.log(`[CRAFT] P${idx+1} typing: "${uniqueWord}"`);
        const typed = await tryTypeIntoInput(page, 'quill', uniqueWord);
        if (typed) {
          await page.waitForTimeout(300);
          await tryClickElement(page, n => n.role === 'button' && n.text.includes('SUBMIT DOSSIER'), `P${idx+1} Submit Dossier`);
          for (let w = 0; w < 10; w++) {
            await page.waitForTimeout(300);
            await enableSemantics(page);
            const stillSubmit = await findSemanticsElement(page, n => n.role === 'button' && n.text.includes('SUBMIT DOSSIER'));
            if (!stillSubmit) break;
          }
        }
      }
    }

    // 2. Phase: Vote
    let allVotersDone = true;
    for (const [idx, page] of [p1, p2, p3].entries()) {
      const readyBtn = await findSemanticsElement(page, n => n.role === 'button' && n.text === "I'M READY");
      if (readyBtn) {
        await tryClickElement(page, n => n.role === 'button' && n.text === "I'M READY", `P${idx+1} Ready`);
      } else {
        const confirmBtn = await findSemanticsElement(page, n => n.role === 'button' && n.text === 'CONFIRM VOTE');
        if (confirmBtn) {
          allVotersDone = false;
          const els = await getSemanticsElements(page);
          const optionCards = els.filter(n => 
            n.role === 'button' && 
            !n.text.includes('Leave') && 
            !n.text.includes('Mute') && 
            !n.text.includes('CONFIRM') && 
            !n.text.includes('CONTINUE') && 
            !n.text.includes('READY') && 
            !n.text.includes('PROCEED') && 
            !n.text.includes('SEALED') && 
            !n.text.includes('Your Forgery') && 
            !n.text.includes('SILENT') &&
            n.rect.height > 25
          );

          if (optionCards.length > 0) {
            // Target Alice's gems for P2 and P3 so Alice's forgeries get voted on
            const aliceOption = optionCards.find(o => 
              WORD_POOLS[0].some(w => o.text.trim() === w || o.text.includes(w))
            );
            const chosen = (idx > 0 && aliceOption) ? aliceOption : optionCards[0];
            const targetText = chosen.text;
            console.log(`[VOTE] P${idx+1} selecting: "${targetText}"`);
            await tryClickElement(page, n => n.role === 'button' && (n.text === targetText || n.text.includes(targetText)), `P${idx+1} Option "${targetText}"`);
            await page.waitForTimeout(400);
            await tryClickElement(page, n => n.role === 'button' && n.text === 'CONFIRM VOTE', `P${idx+1} Confirm Vote`);
            for (let w = 0; w < 10; w++) {
              await page.waitForTimeout(300);
              await enableSemantics(page);
              const stillConfirm = await findSemanticsElement(page, n => n.role === 'button' && n.text === 'CONFIRM VOTE');
              if (!stillConfirm) break;
            }
          }
        }
      }
    }

    // 3. Phase: Reveal / Unmask
    const isReveal = p1Els.some(e => e.text.includes('RESOLVING') || e.text.includes('THE REVEAL') || e.text.includes('UNMASK') || e.text.includes('ACCUSE'));
    if (isReveal) {
      for (const [idx, page] of [p1, p2, p3].entries()) {
        await tryClickElement(page, n => n.role === 'button' && (n.text === 'Alice' || n.text === 'Bob' || n.text === 'Charlie' || n.text === 'ALICE' || n.text === 'BOB' || n.text === 'CHARLIE'), `P${idx+1} Accuse`);
      }
    }

    // 4. Host Advance / Continue / Proceed
    if (allVotersDone || isReveal) {
      await tryClickElement(p1, n => n.role === 'button' && (
        n.text === 'CONTINUE' || 
        n.text.includes('CONTINUE') || 
        n.text.includes('START ROUND') || 
        n.text.includes('VIEW STANDINGS') || 
        n.text.includes('NEXT')
      ), 'P1 Continue');
    }
    
    await p1.waitForTimeout(1500);
  }
}

async function main() {
  console.log('===========================================================');
  console.log('=== RUNNING MATCH SUMMARY MULTI-ROUND PLAYTHROUGH (§2) ===');
  console.log('===========================================================\n');

  const browser = await chromium.launch({ headless: true });

  const ctx1 = await browser.newContext({ viewport: { width: 1280, height: 800 } });
  const ctx2 = await browser.newContext({ viewport: { width: 1280, height: 800 } });
  const ctx3 = await browser.newContext({ viewport: { width: 1280, height: 800 } });

  const p1 = await ctx1.newPage();
  const p2 = await ctx2.newPage();
  const p3 = await ctx3.newPage();

  // 1. P1 Host Room
  console.log('[1/7] P1 loading app & hosting room...');
  await p1.goto(APP_URL, { waitUntil: 'domcontentloaded' });
  await p1.waitForTimeout(2500);
  await enableSemantics(p1);

  await typeIntoInput(p1, 'Your Name', 'Alice');
  await clickElement(p1, n => n.text === 'CREATE ROOM' || n.ariaLabel === 'CREATE ROOM', 'CREATE ROOM');
  await p1.waitForTimeout(4000);
  await enableSemantics(p1);

  // Extract Room Code
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
  console.log(`[1/7] Room Created! Code: "${roomCode}"`);

  // Adjust Lobby Settings: Total Rounds = 2, Disable Timers = ON
  console.log('[2/7] Setting 2 rounds & disabling timers on P1...');
  await tryClickElement(p1, n => n.role === 'checkbox' && n.ariaLabel === '2', '2 Rounds Checkbox', { x: 20, y: 17 });
  await p1.waitForTimeout(500);

  // P1 disables game timers
  await clickElement(p1, n => n.role === 'switch' && n.ariaLabel === 'Disable Game Timers', 'Disable Game Timers switch', { x: 25, y: 24 });
  await p1.waitForTimeout(1000);

  // 2. P2 Join Room (Bob)
  console.log('[3/7] P2 (Bob) joining room from Context 2...');
  await p2.goto(APP_URL, { waitUntil: 'domcontentloaded' });
  await p2.waitForTimeout(2000);
  await enableSemantics(p2);
  await typeIntoInput(p2, 'Your Name', 'Bob');
  await typeIntoInput(p2, 'Room Code', roomCode);
  await clickElement(p2, n => n.text === 'JOIN ROOM', 'JOIN ROOM P2');
  await p2.waitForTimeout(4000);
  await enableSemantics(p2);

  // 3. P3 Join Room (Charlie)
  console.log('[4/7] P3 (Charlie) joining room from Context 3...');
  await p3.goto(APP_URL, { waitUntil: 'domcontentloaded' });
  await p3.waitForTimeout(2000);
  await enableSemantics(p3);
  await typeIntoInput(p3, 'Your Name', 'Charlie');
  await typeIntoInput(p3, 'Room Code', roomCode);
  await clickElement(p3, n => n.text === 'JOIN ROOM', 'JOIN ROOM P3');
  await p3.waitForTimeout(4000);
  await enableSemantics(p3);

  // Ready up P2 & P3
  console.log('[5/7] Readying up P2 & P3...');
  await clickElement(p2, n => n.text === "I'M READY", "P2 I'M READY");
  await p2.waitForTimeout(1000);

  await clickElement(p3, n => n.text === "I'M READY", "P3 I'M READY");
  await p3.waitForTimeout(1500);

  // Start Game
  console.log('[6/7] Starting Game on P1...');
  await dismissAnyDialog(p1);
  await clickElement(p1, n => n.role === 'button' && n.text === 'START GAME', 'START GAME');
  await p1.waitForTimeout(6000);

  // Run match to game over
  console.log('[7/7] Advancing multi-round match to GameOver...');
  await advanceMatchToGameOver(p1, p2, p3);

  // Wait 10 seconds for engraving ceremony to finish
  console.log('Reached GameOver! Waiting for engraving ceremony and match summary...');
  await p1.waitForTimeout(10000);
  await enableSemantics(p1);

  // Capture top of GameOver (Standings & Podium)
  await saveScreenshot(p1, 'w20_gameover_standings.png');
  console.log('Saved docs/playthroughs/evidence/w20_gameover_standings.png');

  // Scroll down to reveal Match Highlights
  console.log('Scrolling down to Match Highlights...');
  await p1.mouse.move(640, 500);
  await p1.mouse.wheel(0, 600);
  await p1.waitForTimeout(500);
  await p1.mouse.down();
  await p1.mouse.move(640, 150, { steps: 15 });
  await p1.mouse.up();
  await p1.waitForTimeout(1500);
  await enableSemantics(p1);

  const scrolledEls = await getSemanticsElements(p1);
  const scrolledTexts = scrolledEls.map(e => `[${e.role || e.tag}] ${e.text}`).filter(t => t.length > 3);
  console.log('\n=== P1 SCROLLED SEMANTICS ON GAME OVER ===');
  console.log(scrolledTexts.join('\n'));

  // Save screenshot of Match Highlights section
  await saveScreenshot(p1, 'w20_match_summary.png');
  console.log('Saved docs/playthroughs/evidence/w20_match_summary.png');

  // Drag a bit more to capture detail
  await p1.mouse.move(640, 500);
  await p1.mouse.down();
  await p1.mouse.move(640, 250, { steps: 15 });
  await p1.mouse.up();
  await p1.waitForTimeout(1000);
  await enableSemantics(p1);
  await saveScreenshot(p1, 'w20_best_lie_detail.png');
  console.log('Saved docs/playthroughs/evidence/w20_best_lie_detail.png');

  console.log('\n=== MATCH SUMMARY OBSERVATION RUN FINISHED SUCCESSFULLY ===');
  await browser.close();
}

main().catch(err => {
  console.error('MATCH SUMMARY PLAYTHROUGH ERROR:', err);
  process.exit(1);
});
