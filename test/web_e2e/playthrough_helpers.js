// test/web_e2e/playthrough_helpers.js
//
// Shared helpers for the web playthroughs (Wave AK / AK1). Both scripts are emulator-only by
// design (scripts/run_web_smoke.sh builds the app with USE_EMULATOR=true), which is what makes
// the room-document oracle below safe.
//
// Rules this file enforces for both scripts:
//   - Screenshots never go into the tracked tree (docs/playthroughs/evidence/); see EVIDENCE_DIR.
//   - Every page.evaluate is raced against 15 s, so an app freeze reads "PAGE UNRESPONSIVE P<n>"
//     instead of looking like a script stall.
//   - Progress is judged from the emulator's room document (readRoom), not from timers.
//   - A loop that stops making progress throws STALLED; a loop that runs out of ticks throws.
//     Neither can fall through to a success message.
const fs = require('fs');
const os = require('os');
const path = require('path');
const { UI } = require('./ui_strings');

const PROJECT_ID = 'gaslight-46368';
const EVAL_TIMEOUT_MS = 15000;
const STALL_TICKS = 6;
const SCRIPT_BUDGET_MS = 570000; // the runner's hard kill is 600 s; this reports a reason first

const TRACKED_EVIDENCE_DIR = path.resolve(__dirname, '../../docs/playthroughs/evidence');

const sleep = ms => new Promise(resolve => setTimeout(resolve, ms));

function assertThat(condition, message) {
  if (!condition) throw new Error(`ASSERTION FAILED: ${message}`);
}

// ---------------------------------------------------------------------------------------------
// Screenshot directory
// ---------------------------------------------------------------------------------------------

function resolveShotDir() {
  const fromEnv = process.env.WEB_E2E_SHOT_DIR;
  const dir = fromEnv ? path.resolve(fromEnv) : fs.mkdtempSync(path.join(os.tmpdir(), 'gaslight-web-e2e-'));
  const rel = path.relative(TRACKED_EVIDENCE_DIR, dir);
  if (rel === '' || (!rel.startsWith('..') && !path.isAbsolute(rel))) {
    throw new Error(`WEB_E2E_SHOT_DIR (${dir}) is the tracked evidence folder; refusing to write screenshots there`);
  }
  fs.mkdirSync(dir, { recursive: true });
  return dir;
}

// Named EVIDENCE_DIR for compatibility; it is a scratch directory, never docs/playthroughs/evidence.
const EVIDENCE_DIR = resolveShotDir();
console.log(`[SHOTS] Screenshots go to ${EVIDENCE_DIR}`);

async function saveScreenshot(page, filename) {
  const fullPath = path.join(EVIDENCE_DIR, filename);
  await page.screenshot({ path: fullPath, timeout: EVAL_TIMEOUT_MS });
  console.log(`[SCREENSHOT] ${fullPath}`);
  return fullPath;
}

// ---------------------------------------------------------------------------------------------
// Pages: labels and a guarded evaluate
// ---------------------------------------------------------------------------------------------

function labelPage(page, label) {
  page.__label = label;
  return page;
}

function pageLabel(page) {
  return page.__label || 'P?';
}

async function evalOnPage(page, fn, arg) {
  let timer;
  const work = page.evaluate(fn, arg);
  work.catch(() => {}); // a rejection that arrives after the race is decided must not go unhandled
  const guard = new Promise((_, reject) => {
    timer = setTimeout(() => reject(new Error(`PAGE UNRESPONSIVE ${pageLabel(page)}`)), EVAL_TIMEOUT_MS);
  });
  try {
    return await Promise.race([work, guard]);
  } finally {
    clearTimeout(timer);
  }
}

async function pageText(page) {
  return evalOnPage(page, () => document.body.innerText || '');
}

// ---------------------------------------------------------------------------------------------
// Flutter web semantics DOM
// ---------------------------------------------------------------------------------------------

async function enableSemantics(page) {
  const clicked = await evalOnPage(page, () => {
    let did = false;
    const placeholder = document.querySelector('flt-semantics-placeholder');
    if (placeholder) {
      placeholder.click();
      did = true;
    }
    const btn = document.querySelector('[aria-label="Enable accessibility"]');
    if (btn) {
      btn.click();
      did = true;
    }
    return did;
  });
  if (clicked) await page.waitForTimeout(300);
}

async function getSemanticsElements(page) {
  await enableSemantics(page);
  return await evalOnPage(page, () => {
    const nodes = document.querySelectorAll('flt-semantics, input, textarea, button');
    return Array.from(nodes).map(n => {
      const rect = n.getBoundingClientRect();
      return {
        tag: n.tagName,
        type: n.getAttribute('type'),
        role: n.getAttribute('role'),
        ariaLabel: n.getAttribute('aria-label') || '',
        disabled: n.getAttribute('aria-disabled') === 'true',
        checked: n.getAttribute('aria-checked'),
        text: (n.innerText || n.textContent || '').trim(),
        value: n.value || '',
        rect: { x: rect.x, y: rect.y, width: rect.width, height: rect.height }
      };
    }).filter(n => n.rect.width > 0 && n.rect.height > 0);
  });
}

async function findSemanticsElement(page, filterFn) {
  const elements = await getSemanticsElements(page);
  return elements.find(filterFn);
}

function describeElements(elements) {
  return elements
    .filter(n => n.role === 'button' || n.role === 'checkbox' || n.role === 'switch' || n.tag === 'TEXTAREA' || n.tag === 'INPUT')
    .map(n => {
      const name = (n.text || n.ariaLabel).replace(/\s+/g, ' ').slice(0, 100);
      return `${n.tag}[${n.role || ''}] "${name}"${n.disabled ? ' (disabled)' : ''}${n.value ? ` value="${n.value.slice(0, 60)}"` : ''} @${Math.round(n.rect.x)},${Math.round(n.rect.y)} ${Math.round(n.rect.width)}x${Math.round(n.rect.height)}`;
    });
}

function allText(elements) {
  return elements.map(n => `${n.text}\n${n.ariaLabel}`).join('\n');
}

function hasText(elements, s) {
  return elements.some(n => n.text.includes(s) || n.ariaLabel.includes(s));
}

function hasButtonText(elements, s) {
  return elements.some(n => n.role === 'button' && n.text === s);
}

async function dismissAnyDialog(page) {
  await enableSemantics(page);
  const elements = await getSemanticsElements(page);
  const dismissBtn = elements.find(e =>
    e.role === 'button' && e.text === UI.CANCEL
  );
  if (dismissBtn) {
    console.log(`[DISMISS] Dismissing dialog via button "${dismissBtn.text}"`);
    const cx = dismissBtn.rect.x + dismissBtn.rect.width / 2;
    const cy = dismissBtn.rect.y + dismissBtn.rect.height / 2;
    await page.mouse.click(cx, cy);
    await page.waitForTimeout(500);
  }
}

// options.dismiss === false: do not dismiss a CANCEL dialog first. A step that opened a dialog on
// purpose (the host's End Voting dialog has CANCEL and PROCEED) must not have it cancelled.
async function clickElement(page, filterFn, description, clickOffset = null, options = {}) {
  if (options.dismiss !== false) await dismissAnyDialog(page);
  let el = await findSemanticsElement(page, filterFn);
  if (!el) {
    // Try scrolling down to find off-screen element
    await page.mouse.move(640, 400);
    await page.mouse.wheel(0, 300);
    await page.waitForTimeout(300);
    el = await findSemanticsElement(page, filterFn);
  }
  if (!el) {
    const all = await getSemanticsElements(page);
    console.error(`[CLICK FAILED] Element not found: ${description}. Available elements:`, describeElements(all));
    throw new Error(`Could not find element: ${description}`);
  }

  let cx = el.rect.x + el.rect.width / 2;
  let cy = el.rect.y + el.rect.height / 2;
  if (clickOffset) {
    cx = el.rect.x + clickOffset.x;
    cy = el.rect.y + clickOffset.y;
  }

  // Scroll into view if below 720px, or clipped to a sliver (the stacked deck's Next option is
  // 1 px high on a voter's screen until the page is scrolled).
  if (cy > 720 || el.rect.height < 8) {
    const scrollAmount = Math.max(200, cy - 500);
    await page.mouse.move(640, 400);
    await page.mouse.wheel(0, scrollAmount);
    await page.waitForTimeout(300);
    const newEl = await findSemanticsElement(page, filterFn);
    if (newEl) {
      cx = newEl.rect.x + (clickOffset ? clickOffset.x : newEl.rect.width / 2);
      cy = newEl.rect.y + (clickOffset ? clickOffset.y : newEl.rect.height / 2);
    }
  }

  console.log(`[CLICK] ${description} at (${cx.toFixed(1)}, ${cy.toFixed(1)})`);
  await page.mouse.click(Math.min(1270, Math.max(10, cx)), Math.min(790, Math.max(10, cy)));
  await page.waitForTimeout(400);
  return { x: cx, y: cy };
}

// try* helpers swallow "not found" only. An unresponsive page is never optional.
function rethrowIfUnresponsive(e) {
  if (/PAGE UNRESPONSIVE/.test(String(e && e.message))) throw e;
}

async function tryClickElement(page, filterFn, description, clickOffset = null) {
  try {
    await clickElement(page, filterFn, description, clickOffset);
    return true;
  } catch (e) {
    rethrowIfUnresponsive(e);
    return false;
  }
}

// Clicks a semantics node through the DOM instead of with the pointer. The lobby's House Rules (the
// rounds chips and the timers switch) sit behind the full-width suspects sheet, and how much of them
// it covers grows with the players who have joined. A pointer click that lands on the sheet does
// nothing (measured: three pointer clicks left totalRounds at 1, and the old click offset left
// isTimerDisabled unchanged), while the node's own click is the semantic tap a screen reader would
// send and works wherever the sheet is. el comes from getSemanticsElements.
async function domClick(page, el, description) {
  console.log(`[DOM CLICK] ${description}`);
  const clicked = await evalOnPage(page, target => {
    const near = (a, b) => Math.abs(a - b) < 2;
    const node = Array.from(document.querySelectorAll('flt-semantics, input, textarea, button')).find(n => {
      const r = n.getBoundingClientRect();
      return (n.getAttribute('role') || '') === target.role &&
        (n.getAttribute('aria-label') || '') === target.ariaLabel &&
        near(r.x, target.x) && near(r.y, target.y) && near(r.width, target.width) && near(r.height, target.height);
    });
    if (!node) return false;
    node.click();
    return true;
  }, { role: el.role || '', ariaLabel: el.ariaLabel, x: el.rect.x, y: el.rect.y, width: el.rect.width, height: el.rect.height });
  if (!clicked) throw new Error(`domClick: no semantics node matches ${description}`);
  await page.waitForTimeout(400);
}

async function typeIntoInput(page, labelOrPlaceholder, textToType) {
  await dismissAnyDialog(page);
  const matches = n =>
    (n.tag === 'INPUT' || n.tag === 'TEXTAREA') &&
    (n.ariaLabel.toLowerCase().includes(labelOrPlaceholder.toLowerCase()) || n.text.toLowerCase().includes(labelOrPlaceholder.toLowerCase()));
  let el = await findSemanticsElement(page, matches);
  if (!el) {
    await page.mouse.move(640, 400);
    await page.mouse.wheel(0, -300);
    await page.waitForTimeout(300);
    el = await findSemanticsElement(page, matches);
  }
  if (!el) {
    const all = await getSemanticsElements(page);
    console.error(`[TYPE FAILED] Input not found: ${labelOrPlaceholder}. Inputs:`, all.filter(a => a.tag === 'INPUT' || a.tag === 'TEXTAREA'));
    throw new Error(`Could not find input: ${labelOrPlaceholder}`);
  }
  let cx = el.rect.x + el.rect.width / 2;
  let cy = el.rect.y + el.rect.height / 2;
  if (cy > 720) {
    await page.mouse.move(640, 400);
    await page.mouse.wheel(0, cy - 500);
    await page.waitForTimeout(300);
    const newEl = await findSemanticsElement(page, matches);
    if (newEl) {
      cx = newEl.rect.x + newEl.rect.width / 2;
      cy = newEl.rect.y + newEl.rect.height / 2;
    }
  }
  console.log(`[TYPE] "${textToType}" into ${labelOrPlaceholder} at (${cx.toFixed(1)}, ${cy.toFixed(1)})`);
  await page.mouse.click(Math.min(1270, Math.max(10, cx)), Math.min(790, Math.max(10, cy)));
  await page.waitForTimeout(200);
  await page.keyboard.press('Control+A');
  await page.keyboard.press('Meta+A');
  for (let i = 0; i < 40; i++) {
    await page.keyboard.press('Backspace');
  }
  await page.keyboard.type(textToType, { delay: 30 });
  await page.waitForTimeout(300);
}

async function tryTypeIntoInput(page, labelOrPlaceholder, textToType) {
  try {
    await typeIntoInput(page, labelOrPlaceholder, textToType);
    return true;
  } catch (e) {
    rethrowIfUnresponsive(e);
    return false;
  }
}

// The craft field is found by tag, never by its label. Its only label is the hint "Dip the
// quill…", which Flutter drops from the DOM as soon as the field holds text (Issue 195), so a
// field that still holds a rejected answer cannot be found by label.
async function craftFields(page) {
  const elements = await getSemanticsElements(page);
  return { elements, areas: elements.filter(n => n.tag === 'TEXTAREA') };
}

async function typeIntoCraftField(page, text) {
  const label = pageLabel(page);
  await dismissAnyDialog(page);
  const { elements, areas } = await craftFields(page);
  if (areas.length !== 1) {
    console.error(`[CRAFT FAILED] ${label}: expected exactly one visible TEXTAREA, found ${areas.length}. Elements:`, describeElements(elements));
    throw new Error(`typeIntoCraftField ${label}: expected exactly 1 visible TEXTAREA, found ${areas.length}`);
  }
  const el = areas[0];
  const cx = el.rect.x + el.rect.width / 2;
  let cy = el.rect.y + el.rect.height / 2;
  if (cy > 720) {
    await page.mouse.move(640, 400);
    await page.mouse.wheel(0, cy - 500);
    await page.waitForTimeout(300);
    const again = (await craftFields(page)).areas;
    if (again.length === 1) cy = again[0].rect.y + again[0].rect.height / 2;
  }
  console.log(`[TYPE] ${label} craft field: "${text}"`);
  await page.mouse.click(Math.min(1270, Math.max(10, cx)), Math.min(790, Math.max(10, cy)));
  await page.waitForTimeout(200);
  await page.keyboard.press('Control+A');
  await page.keyboard.press('Meta+A');
  await page.keyboard.press('Backspace');
  await page.keyboard.type(text, { delay: 25 });
  await page.waitForTimeout(250);
  const after = (await craftFields(page)).areas;
  if (after.length !== 1 || after[0].value !== text) {
    console.error(`[CRAFT FAILED] ${label}: the field holds ${JSON.stringify(after.map(a => a.value))}, expected ${JSON.stringify(text)}`);
    throw new Error(`typeIntoCraftField ${label}: the field does not hold the typed text`);
  }
}

// ---------------------------------------------------------------------------------------------
// The emulator's room document: the oracle for every end state
// ---------------------------------------------------------------------------------------------

function firestoreBase() {
  return process.env.WEB_E2E_FIRESTORE || 'http://127.0.0.1:8080';
}

function decodeValue(v) {
  if ('stringValue' in v) return v.stringValue;
  if ('integerValue' in v) return Number(v.integerValue);
  if ('doubleValue' in v) return v.doubleValue;
  if ('booleanValue' in v) return v.booleanValue;
  if ('nullValue' in v) return null;
  if ('timestampValue' in v) return v.timestampValue;
  if ('mapValue' in v) return decodeFields(v.mapValue.fields || {});
  if ('arrayValue' in v) return (v.arrayValue.values || []).map(decodeValue);
  return undefined;
}

function decodeFields(fields) {
  return Object.fromEntries(Object.entries(fields).map(([k, v]) => [k, decodeValue(v)]));
}

async function firestoreGet(documentPath) {
  const url = `${firestoreBase()}/v1/projects/${PROJECT_ID}/databases/(default)/documents/${documentPath}`;
  const res = await fetch(url, { headers: { Authorization: 'Bearer owner' }, signal: AbortSignal.timeout(10000) });
  if (!res.ok) throw new Error(`Firestore GET ${documentPath} -> HTTP ${res.status}`);
  return res.json();
}

// The room's fields: currentPhase, currentReaderId, currentRound, currentRotationIndex,
// isTimerDisabled, totalRounds, readyPlayers, rotationPlan, unmaskDeadline, cards[] (each with
// targetPlayerId, options, votes keyed by voter, unmaskGuesses) ... Submitted answers are
// sealed and not on the room, but each submission marks its author in readyPlayers.
async function readRoom(code) {
  const doc = await firestoreGet(`rooms/${code}`);
  return decodeFields(doc.fields || {});
}

// The players subcollection: id, name, isHost, role, lobbyReady, totalScore ...
async function readPlayers(code) {
  const doc = await firestoreGet(`rooms/${code}/players`);
  return (doc.documents || []).map(d => ({ id: d.name.split('/').pop(), ...decodeFields(d.fields || {}) }));
}

function voteCount(room) {
  return (room.cards || []).reduce((n, c) => n + Object.keys(c.votes || {}).length, 0);
}

function shortId(id) {
  return id ? String(id).slice(0, 6) : '-';
}

function summarizeRoom(room, nameOf = null) {
  const reader = nameOf && nameOf[room.currentReaderId] ? nameOf[room.currentReaderId] : shortId(room.currentReaderId);
  return `phase=${room.currentPhase} round=${room.currentRound} rot=${room.currentRotationIndex} reader=${reader} ready=${Object.keys(room.readyPlayers || {}).length} votes=${voteCount(room)}`;
}

// Polls fn() until it returns something truthy. On timeout it throws, naming what it waited for
// and the last thing it saw.
async function waitFor(fn, { timeoutMs = 10000, intervalMs = 250, description = 'condition', describeLast = null } = {}) {
  const deadline = Date.now() + timeoutMs;
  let last;
  let lastError = null;
  for (;;) {
    try {
      last = await fn();
      if (last) return last;
    } catch (e) {
      rethrowIfUnresponsive(e);
      lastError = e;
      last = undefined;
    }
    if (Date.now() >= deadline) break;
    await sleep(intervalMs);
  }
  const seen = describeLast ? `; last seen: ${await describeLast().catch(() => '(unavailable)')}` : '';
  const failure = lastError ? `; last error: ${lastError.message}` : '';
  throw new Error(`TIMEOUT after ${timeoutMs} ms waiting for ${description}${seen}${failure}`);
}

async function waitForRoom(code, predicate, { timeoutMs = 15000, description = 'room condition' } = {}) {
  let lastRoom = null;
  return waitFor(async () => {
    lastRoom = await readRoom(code);
    return predicate(lastRoom) ? lastRoom : null;
  }, { timeoutMs, description, describeLast: async () => (lastRoom ? summarizeRoom(lastRoom) : 'no room read') });
}

let timeoutShots = 0;

async function waitForScreen(page, predicate, { timeoutMs = 10000, description = 'screen condition' } = {}) {
  let lastElements = [];
  try {
    return await waitFor(async () => {
      lastElements = await getSemanticsElements(page);
      return predicate(lastElements) ? lastElements : null;
    }, {
      timeoutMs,
      description: `${pageLabel(page)} ${description}`,
      describeLast: async () => JSON.stringify(describeElements(lastElements).slice(0, 30))
    });
  } catch (e) {
    // A timeout is the moment a screenshot is worth most; it is best effort and never masks the error.
    if (/^TIMEOUT/.test(e.message)) {
      await saveScreenshot(page, `timeout_${pageLabel(page)}_${++timeoutShots}.png`).catch(() => {});
    }
    throw e;
  }
}

// ---------------------------------------------------------------------------------------------
// Screen markers
// ---------------------------------------------------------------------------------------------

// One short word for what a page is showing. Used in every tick line, and by end-state assertions.
function markerOf(elements) {
  const t = allText(elements);
  if ([UI.NIGHTS_HONORS, UI.GAME_OVER, UI.FINAL_STANDINGS, UI.SHARE_CASE_FILE, UI.ENGRAVING].some(s => t.includes(s))) return 'gameover';
  if (t.includes(UI.THE_REVEAL)) return 'reveal';
  if (t.includes(UI.THE_VOTE)) {
    if (t.includes(UI.YOUR_BALLOT_IS_SEALED)) return 'vote-sealed';
    if (hasButtonText(elements, UI.IM_READY) || hasButtonText(elements, UI.NOT_READY)) return 'vote-target';
    return 'vote';
  }
  if (elements.some(n => n.tag === 'TEXTAREA')) return 'craft';
  if (t.includes(UI.THE_INK_DRIES)) return 'craft-sealed';
  if (t.includes(UI.ROOM_CODE)) return 'lobby';
  if (t.includes(UI.GUEST_LEDGER)) return 'title';
  return '?';
}

async function screenMarker(page) {
  return markerOf(await getSemanticsElements(page));
}

// ---------------------------------------------------------------------------------------------
// Joining a room
// ---------------------------------------------------------------------------------------------

async function openApp(page, appUrl) {
  await page.goto(appUrl, { waitUntil: 'domcontentloaded' });
  await enableSemantics(page);
  await waitForScreen(page, els => hasText(els, UI.GUEST_LEDGER), { timeoutMs: 30000, description: 'the title screen (THE GUEST LEDGER)' });
}

async function readRoomCode(page) {
  const elements = await getSemanticsElements(page);
  const el = elements.find(e => e.text.includes(UI.ROOM_CODE) || e.ariaLabel.includes(UI.ROOM_CODE));
  if (!el) throw new Error(`${pageLabel(page)}: ROOM CODE not found on the lobby`);
  const match = (el.text + ' ' + el.ariaLabel).match(new RegExp(`${UI.ROOM_CODE}\\s+([A-Z]{4})`));
  if (!match) throw new Error(`${pageLabel(page)}: could not parse a 4-letter room code from "${el.text}"`);
  return match[1];
}

async function createRoom(page, name) {
  await typeIntoInput(page, 'Your Name', name);
  await clickElement(page, n => n.text === UI.CREATE_ROOM || n.ariaLabel === UI.CREATE_ROOM, 'CREATE ROOM');
  const code = await waitFor(async () => {
    try {
      return await readRoomCode(page);
    } catch (e) {
      rethrowIfUnresponsive(e);
      return null;
    }
  }, { timeoutMs: 20000, description: `${pageLabel(page)} to show a ROOM CODE after CREATE ROOM` });
  await waitForRoom(code, r => r.currentPhase === 'lobby', { description: `room ${code} to exist in the lobby phase` });
  console.log(`Room successfully created with code: ${code}`);
  return code;
}

async function joinRoom(page, name, code) {
  await typeIntoInput(page, 'Your Name', name);
  await typeIntoInput(page, 'Room Code', code);
  await clickElement(page, n => n.text === UI.JOIN_ROOM, `JOIN ROOM ${pageLabel(page)}`);
  await waitFor(async () => (await readPlayers(code)).some(p => p.name === name), {
    timeoutMs: 20000,
    description: `${name} to appear in room ${code}'s players`
  });
}

// ---------------------------------------------------------------------------------------------
// Lobby settings: read before clicking, then assert
// ---------------------------------------------------------------------------------------------

async function ensureTimersDisabled(hostPage, code) {
  let room = await readRoom(code);
  if (room.isTimerDisabled !== true) {
    const before = room.isTimerDisabled;
    const timers = await findSemanticsElement(hostPage, n => n.role === 'switch' && n.ariaLabel === UI.DISABLE_GAME_TIMERS);
    if (!timers) throw new Error(`ensureTimersDisabled: the "${UI.DISABLE_GAME_TIMERS}" switch was not found`);
    await domClick(hostPage, timers, `${UI.DISABLE_GAME_TIMERS} switch`);
    // The switch is a callable. Wait for the room to show the change before judging the result, or a
    // read taken before the write lands could satisfy the assertion below by accident.
    await waitForRoom(code, r => r.isTimerDisabled !== before, { timeoutMs: 8000, description: 'the switch click to reach the room' });
  } else {
    console.log('[SETTINGS] isTimerDisabled is already true; the switch is not clicked');
  }
  room = await waitForRoom(code, r => r.isTimerDisabled === true, { timeoutMs: 8000, description: 'isTimerDisabled === true' });
  return room;
}

// The lobby has two checkbox rows with the same labels ("Forgeries Per Card" 1-2 and "Rounds" 1-5),
// so a checkbox is picked by the row under the "Rounds:" label, never by its label alone.
async function ensureRounds(hostPage, code, rounds) {
  let room = await readRoom(code);
  if (room.totalRounds !== rounds) {
    const elements = await getSemanticsElements(hostPage);
    const heading = elements.find(n => n.text === UI.ROUNDS_LABEL);
    if (!heading) throw new Error(`ensureRounds: the "${UI.ROUNDS_LABEL}" label was not found`);
    const box = elements
      .filter(n => n.role === 'checkbox' && n.ariaLabel === String(rounds) && n.rect.y > heading.rect.y && n.rect.y < heading.rect.y + 90)
      .sort((a, b) => a.rect.y - b.rect.y)[0];
    if (!box) throw new Error(`ensureRounds: no checkbox "${rounds}" under the "${UI.ROUNDS_LABEL}" label`);
    await domClick(hostPage, box, `Rounds ${rounds} checkbox`);
  }
  room = await waitForRoom(code, r => r.totalRounds === rounds, { timeoutMs: 8000, description: `totalRounds === ${rounds}` });
  return room;
}

// ---------------------------------------------------------------------------------------------
// Voting on the stacked deck
// ---------------------------------------------------------------------------------------------

function deckSize(elements) {
  const re = new RegExp(`^${UI.SHOW_OPTION} (\\d+) of (\\d+)$`);
  let n = 0;
  for (const e of elements) {
    const m = re.exec(e.ariaLabel || e.text);
    if (m) n = Math.max(n, Number(m[2]));
  }
  return n;
}

// The deck shows one card at a time. A card is votable when the front card is a button whose text
// starts with "OPTION " and offers "Tap to choose this one"; the voter's own forgery and the
// target's cards are not.
function frontVotable(elements) {
  return elements.find(n => n.role === 'button' && n.text.startsWith(UI.OPTION + ' ') && n.text.includes(UI.TAP_TO_CHOOSE));
}

function makePreference(prefer) {
  if (prefer === undefined || prefer === null) return null;
  if (typeof prefer === 'function') return prefer;
  const list = Array.isArray(prefer) ? prefer : [prefer];
  return text => list.some(s => text.includes(s));
}

// Votes on the current card. preferText may be a string, an array of strings (any match), or a
// predicate on the card text; with no preference the first votable card is chosen. The preferred
// votable card is chosen if one is seen, otherwise the first votable one.
async function castVote(page, preferText) {
  const label = pageLabel(page);
  const prefers = makePreference(preferText);
  let elements = await getSemanticsElements(page);
  const total = deckSize(elements);
  if (total < 1) {
    console.error(`[VOTE FAILED] ${label}: no "${UI.SHOW_OPTION} k of N" labels. Elements:`, describeElements(elements));
    throw new Error(`castVote ${label}: the stacked deck was not found`);
  }

  // Start from the first card, whatever the deck's initial index: Previous option is disabled there.
  for (let back = 0; back < total; back++) {
    const previous = elements.find(n => n.role === 'button' && (n.ariaLabel === UI.PREVIOUS_OPTION || n.text === UI.PREVIOUS_OPTION));
    if (!previous || previous.disabled) break;
    await clickElement(page, n => n.role === 'button' && (n.ariaLabel === UI.PREVIOUS_OPTION || n.text === UI.PREVIOUS_OPTION), `${label} ${UI.PREVIOUS_OPTION}`);
    elements = await getSemanticsElements(page);
  }

  const seen = [];
  let chosen = null;
  for (let step = 0; step < total; step++) {
    const front = frontVotable(elements);
    if (front) {
      seen.push({ index: step, text: front.text });
      if (!prefers || prefers(front.text)) {
        chosen = seen[seen.length - 1];
        break;
      }
    }
    if (step < total - 1) {
      await clickElement(page, n => n.role === 'button' && (n.ariaLabel === UI.NEXT_OPTION || n.text === UI.NEXT_OPTION), `${label} ${UI.NEXT_OPTION}`);
      elements = await getSemanticsElements(page);
    }
  }

  if (!chosen) {
    if (seen.length === 0) {
      console.error(`[VOTE FAILED] ${label}: no votable card among ${total}. Elements:`, describeElements(elements));
      throw new Error(`castVote ${label}: no votable card after looking at ${total} cards`);
    }
    // Only a non-preferred card was seen: walk back to the first votable one.
    chosen = seen[0];
    for (let back = total - 1; back > chosen.index; back--) {
      await clickElement(page, n => n.role === 'button' && (n.ariaLabel === UI.PREVIOUS_OPTION || n.text === UI.PREVIOUS_OPTION), `${label} ${UI.PREVIOUS_OPTION}`);
    }
  }

  console.log(`[VOTE] ${label} chooses: "${chosen.text}"`);
  await clickElement(page, n => n.role === 'button' && n.text.startsWith(UI.OPTION + ' ') && n.text.includes(UI.TAP_TO_CHOOSE), `${label} card`);
  await waitForScreen(page, els => hasButtonText(els, UI.CONFIRM_VOTE), { timeoutMs: 5000, description: `to offer ${UI.CONFIRM_VOTE} after choosing a card` });
  await clickElement(page, n => n.role === 'button' && n.text === UI.CONFIRM_VOTE, `${label} ${UI.CONFIRM_VOTE}`);
  await waitForScreen(page, els => !hasText(els, UI.CONFIRM_VOTE) && !hasText(els, UI.TAP_A_CARD_TO_CHOOSE), {
    timeoutMs: 10000,
    description: `to leave the voting controls after ${UI.CONFIRM_VOTE}`
  });
}

// The host's PROCEED TO REVEAL (HOST) opens the End Voting dialog; its confirm button is PROCEED
// and its cancel button is CANCEL, which dismissAnyDialog would press. Hence dismiss: false.
async function hostProceedToReveal(hostPage) {
  await clickElement(hostPage, n => n.role === 'button' && n.text === UI.PROCEED_TO_REVEAL, UI.PROCEED_TO_REVEAL);
  await waitForScreen(hostPage, els => hasButtonText(els, UI.PROCEED), { timeoutMs: 5000, description: 'to show the End Voting dialog (PROCEED)' });
  await clickElement(hostPage, n => n.role === 'button' && n.text === UI.PROCEED, 'PROCEED (End Voting dialog)', null, { dismiss: false });
}

// Once every voter's vote is in, the phase should leave vote by itself (the target's ready toggle
// is their ballot). Only if it has not within 10 s does the host press PROCEED TO REVEAL (HOST).
// Returns 'auto', 'host', 'host-is-target' or 'waiting-for-votes', and logs which one happened.
async function finishVote({ code, roster, readerId, hostPage, hostIsReader }) {
  const leaves = r => r.currentPhase !== 'vote' || r.currentReaderId !== readerId;
  const room = await readRoom(code);
  if (leaves(room)) {
    console.log('[VOTE] the phase advanced by itself');
    return 'auto';
  }
  const card = (room.cards || []).find(c => c.targetPlayerId === readerId) || { votes: {} };
  const votes = card.votes || {};
  if (!roster.filter(r => r.id !== readerId).every(r => votes[r.id])) return 'waiting-for-votes';
  try {
    await waitForRoom(code, leaves, { timeoutMs: 10000, description: 'the phase to leave vote by itself' });
    console.log('[VOTE] every vote is in; the phase advanced by itself');
    return 'auto';
  } catch (e) {
    rethrowIfUnresponsive(e);
  }
  if (hostIsReader) {
    console.log('[VOTE] every vote is in but the host is the target, so there is no PROCEED button; waiting');
    return 'host-is-target';
  }
  console.log(`[VOTE] every vote is in and the phase did not advance in 10 s; the host presses ${UI.PROCEED_TO_REVEAL}`);
  await hostProceedToReveal(hostPage);
  await waitForRoom(code, leaves, { timeoutMs: 10000, description: `the phase to leave vote after ${UI.PROCEED_TO_REVEAL}` });
  return 'host';
}

// ---------------------------------------------------------------------------------------------
// Stall detection
// ---------------------------------------------------------------------------------------------

function progressSignature(room) {
  return [
    room.currentPhase,
    room.currentReaderId,
    room.currentRound,
    room.currentRotationIndex,
    Object.keys(room.readyPlayers || {}).length,
    voteCount(room)
  ].join('|');
}

async function failStalled(room, pages, ticks) {
  console.error(`STALLED: the room made no progress for ${ticks} consecutive ticks (${summarizeRoom(room)})`);
  for (const page of pages) {
    const label = pageLabel(page);
    try {
      const elements = await getSemanticsElements(page);
      console.error(`[${label}] marker=${markerOf(elements)} buttons:`, describeElements(elements));
      await saveScreenshot(page, `stalled_${label}.png`);
    } catch (e) {
      console.error(`[${label}] could not be dumped: ${e.message}`);
    }
  }
  throw new Error(`STALLED: no room progress for ${ticks} consecutive ticks (${summarizeRoom(room)})`);
}

class StallDetector {
  constructor(limit = STALL_TICKS) {
    this.limit = limit;
    this.last = null;
    this.count = 0;
  }

  async check(room, pages) {
    const signature = progressSignature(room);
    if (signature === this.last) {
      this.count += 1;
    } else {
      this.last = signature;
      this.count = 1;
    }
    if (this.count >= this.limit) await failStalled(room, pages, this.count);
  }
}

// ---------------------------------------------------------------------------------------------
// One card's reveal, and the generic driver
// ---------------------------------------------------------------------------------------------

function rectsAgree(a, b, tolerance) {
  return ['x', 'y', 'width', 'height'].every(k => Math.abs(a[k] - b[k]) <= tolerance);
}

// Reads the rect of the element `matcher` finds until two reads 300 ms apart agree within 1 px, for up
// to 3 s, and returns the element from the last read (null if it is gone). A panel that is still
// sliding in reads differently each time: that was Wave AL / AL2's false FAIL, a click aimed at
// y = 714.6 where every other run clicked at y = 505.0 (Wave AM / AM2). When the first two reads
// disagree, both rects are logged.
async function settledElement(page, matcher, description, { intervalMs = 300, timeoutMs = 3000, tolerance = 1 } = {}) {
  const started = Date.now();
  let previous = await findSemanticsElement(page, matcher);
  if (!previous) return null;
  let loggedDisagreement = false;
  for (;;) {
    await page.waitForTimeout(intervalMs);
    const current = await findSemanticsElement(page, matcher);
    if (!current) return null;
    if (rectsAgree(previous.rect, current.rect, tolerance)) return current;
    if (!loggedDisagreement) {
      console.log(`[SETTLE] ${description}: the first two reads disagree: ${describeRect(previous.rect)} then ${describeRect(current.rect)}`);
      loggedDisagreement = true;
    }
    if (Date.now() - started >= timeoutMs) {
      console.log(`[SETTLE] ${description}: still moving after ${timeoutMs} ms; clicking where it is now`);
      return current;
    }
    previous = current;
  }
}

// One accusation click: wait for the button to stop moving, then click its centre. Returns where it
// clicked, or null if the button is gone.
async function accuseClick(page, buttonText, description, attempt) {
  const matcher = n => n.role === 'button' && n.text === buttonText;
  const settled = await settledElement(page, matcher, description);
  if (!settled) return null;
  return clickElement(page, matcher, `${description}${attempt > 1 ? ' (attempt 2)' : ''}`, { x: settled.rect.width / 2, y: settled.rect.height / 2 });
}

const ACCUSATION_WAIT_MS = 4000;     // how long a click may take to show up in the room's unmaskGuesses
const RETRY_MIN_LEFT_MS = 3000;      // a retry needs at least this much of the unmask window left

// Fooled voters see "Accuse the player who wrote the forgery you voted for:" while the unmask
// window is open. Clicks each candidate, waits up to 4 s for the room to record it, and, if it was not
// recorded and the window still has 3 s left, clicks once more. A window that has closed is never
// retried: a late click is what the server's deadline_passed reason is for, not a test flake.
async function accuseWhileWindowOpen({ code, players, roster, readerId }) {
  const nameOf = Object.fromEntries(roster.map(p => [p.id, p.name]));
  const accused = new Set();
  let room = await readRoom(code);
  const deadline = Number(room.unmaskDeadline) || 0;
  if (deadline <= Date.now()) return { windowOpened: false, accused: [] };
  const giveUpAt = Math.min(deadline + 2000, Date.now() + 27000);
  while (Date.now() < giveUpAt) {
    for (const p of players) {
      const id = roster.find(r => r.name === p.name).id;
      if (id === readerId || accused.has(id)) continue;
      const elements = await getSemanticsElements(p.page);
      if (!hasText(elements, UI.ACCUSE_PROMPT)) continue;
      const others = roster.filter(r => r.id !== id && r.id !== readerId).map(r => r.name.toLowerCase());
      const candidate = elements.find(n => n.role === 'button' && others.includes(n.text.toLowerCase()));
      if (!candidate) continue;
      console.log(`[UNMASK] ${pageLabel(p.page)} (${p.name}) accuses ${candidate.text}`);
      const description = `${pageLabel(p.page)} accuses ${candidate.text}`;
      const waitingFor = `${nameOf[id]}'s accusation in the room's unmaskGuesses`;
      const recorded = r => {
        const card = (r.cards || []).find(c => c.targetPlayerId === readerId);
        return !!(card && card.unmaskGuesses && card.unmaskGuesses[id]);
      };
      const first = await accuseClick(p.page, candidate.text, description, 1);
      if (!first) throw new Error(`Could not find element: ${description}`);
      try {
        await waitForRoom(code, recorded, { timeoutMs: ACCUSATION_WAIT_MS, description: waitingFor });
      } catch (firstError) {
        rethrowIfUnresponsive(firstError);
        const now = await readRoom(code);
        if (!recorded(now)) {
          const stillRevealing = now.currentPhase === 'reveal' && now.currentReaderId === readerId;
          const msLeft = deadline - Date.now();
          const clickedAt = `(${first.x.toFixed(1)}, ${first.y.toFixed(1)})`;
          if (!stillRevealing || msLeft < RETRY_MIN_LEFT_MS) {
            throw new Error(`${firstError.message}; clicked at ${clickedAt}, not retried (${stillRevealing ? `${Math.max(0, msLeft)} ms of the window left` : 'the reveal has moved on'})`);
          }
          console.log(`[UNMASK] retrying accusation for ${nameOf[id]} (first click at ${first.x.toFixed(1)},${first.y.toFixed(1)})`);
          const second = await accuseClick(p.page, candidate.text, description, 2);
          if (!second) throw new Error(`${firstError.message}; clicked at ${clickedAt}, and the button was gone for the retry`);
          try {
            await waitForRoom(code, recorded, { timeoutMs: Math.max(1500, deadline - Date.now()), description: waitingFor });
          } catch (secondError) {
            rethrowIfUnresponsive(secondError);
            throw new Error(`${secondError.message}; clicked at ${clickedAt}, then retried at (${second.x.toFixed(1)}, ${second.y.toFixed(1)})`);
          }
        }
      }
      accused.add(id);
    }
    room = await readRoom(code);
    if (room.currentPhase !== 'reveal' || room.currentReaderId !== readerId) break;
    if ((Number(room.unmaskDeadline) || 0) <= Date.now()) break;
    await sleep(500);
  }
  return { windowOpened: true, accused: Array.from(accused) };
}

// The host leaves a card's reveal with CONTINUE. It is disabled while the unmask countdown runs, so
// a click that changes nothing is simply retried.
async function hostContinue({ code, hostPage, readerId, round }) {
  for (let attempt = 1; attempt <= 3; attempt++) {
    await clickElement(hostPage, n => n.role === 'button' && n.text === UI.CONTINUE, `${pageLabel(hostPage)} ${UI.CONTINUE}`);
    try {
      await waitForRoom(code, r => r.currentPhase !== 'reveal' || r.currentReaderId !== readerId || r.currentRound !== round, {
        timeoutMs: 6000,
        description: `the room to leave ${shortId(readerId)}'s reveal after ${UI.CONTINUE} (attempt ${attempt})`
      });
      return true;
    } catch (e) {
      rethrowIfUnresponsive(e);
    }
  }
  return false;
}

// Drives a whole game on observed state. players: [{ name, page }] in seat order; players[0] is the
// host. craftTextFor(seat, name, phase, n) gives the n-th answer of that seat (n counts from 0).
// votePreferFor(name, room, card) gives castVote's preference. Every tick logs one line. The loop
// throws STALLED when the room stops changing and throws when the ticks run out: it never ends in
// a success message by exhaustion.
async function driveToGameOver({ code, players, maxTicks, craftTextFor = null, votePreferFor = null, tickSleepMs = 1000 }) {
  const roster = await readPlayers(code);
  const idOf = Object.fromEntries(roster.map(p => [p.name, p.id]));
  const nameOf = Object.fromEntries(roster.map(p => [p.id, p.name]));
  const host = players[0];
  const pages = players.map(p => p.page);
  const stall = new StallDetector();
  const submitted = players.map(() => 0);

  for (let tick = 1; tick <= maxTicks; tick++) {
    let room = await readRoom(code);
    const markers = [];
    for (const p of players) markers.push(`${pageLabel(p.page)}:${await screenMarker(p.page)}`);
    console.log(`[TICK ${tick}] ${summarizeRoom(room, nameOf)} | ${markers.join(' ')}`);

    if (room.currentPhase === 'gameOver') {
      await waitForScreen(host.page, els => markerOf(els) === 'gameover', { timeoutMs: 15000, description: 'to show the game over screen' });
      console.log('GameOver reached!');
      return room;
    }
    await stall.check(room, pages);

    if (room.currentPhase === 'truth' || room.currentPhase === 'forgery') {
      if (!craftTextFor) throw new Error('driveToGameOver: a craft phase was reached but no craftTextFor was given');
      for (const [seat, p] of players.entries()) {
        if (room.readyPlayers && room.readyPlayers[idOf[p.name]] === true) continue;
        const { areas } = await craftFields(p.page);
        if (areas.length !== 1) continue; // the page has not caught up yet; the next tick retries
        await typeIntoCraftField(p.page, craftTextFor(seat, p.name, room.currentPhase, submitted[seat]++));
        await clickElement(p.page, n => n.role === 'button' && n.text.includes(UI.SUBMIT_DOSSIER), `${pageLabel(p.page)} ${UI.SUBMIT_DOSSIER}`);
      }
    } else if (room.currentPhase === 'vote') {
      const readerId = room.currentReaderId;
      const card = (room.cards || []).find(c => c.targetPlayerId === readerId) || { votes: {} };
      for (const p of players) {
        const id = idOf[p.name];
        const elements = await getSemanticsElements(p.page);
        if (id === readerId) {
          // The target does not vote; their toggle counts as their ballot. NOT READY means already ready.
          if (hasButtonText(elements, UI.IM_READY)) {
            await clickElement(p.page, n => n.role === 'button' && n.text === UI.IM_READY, `${pageLabel(p.page)} ${UI.IM_READY}`);
          }
        } else if (!(card.votes && card.votes[id])) {
          if (!hasButtonText(elements, UI.CONFIRM_VOTE) && !hasButtonText(elements, UI.TAP_A_CARD_TO_CHOOSE)) continue;
          await castVote(p.page, votePreferFor ? votePreferFor(p.name, room, card) : null);
        }
      }
      await finishVote({ code, roster, readerId, hostPage: host.page, hostIsReader: idOf[host.name] === readerId });
    } else if (room.currentPhase === 'reveal') {
      const readerId = room.currentReaderId;
      const round = room.currentRound;
      const unmask = await accuseWhileWindowOpen({ code, players, roster, readerId });
      console.log(`[REVEAL] ${nameOf[readerId]}'s card: unmask window ${unmask.windowOpened ? 'opened' : 'did not open'}, ${unmask.accused.length} accusation(s)`);
      await hostContinue({ code, hostPage: host.page, readerId, round });
    }
    await sleep(tickSleepMs);
  }
  throw new Error(`did not reach game over after ${maxTicks} ticks`);
}

// ---------------------------------------------------------------------------------------------
// The responsive sweep (Wave AL / AL2, Issue 197)
// ---------------------------------------------------------------------------------------------

// The three sizes every phase is checked at, and the size the rest of the script assumes: the click
// helpers above clamp to 1270 x 790 and scroll with the wheel at (640, 400).
const SWEEP_SIZES = Object.freeze([
  { width: 375, height: 812 },
  { width: 768, height: 1024 },
  { width: 1280, height: 800 }
]);
const SWEEP_RESTORE = Object.freeze({ width: 1280, height: 800 });
const SWEEP_LAYOUT_WAIT_MS = 1500; // Flutter lays the screen out again after a resize
const SWEEP_FIND_MS = 3000;        // how long a control may take to appear before the page is scrolled
const SWEEP_MAX_SCROLLS = 14;
const SWEEP_LOGGED_OVERFLOWS = 12;

// "w21_375x812_vote.png": the phase is the room's own phase name (lobby, truth, vote, reveal, gameOver).
function sweepShotName(size, phase) {
  return `w21_${size.width}x${size.height}_${phase}.png`;
}

async function wheelPage(page, size, deltaY) {
  await page.mouse.move(Math.round(size.width / 2), Math.round(size.height / 2));
  await page.mouse.wheel(0, deltaY);
  await page.waitForTimeout(300);
}

// Of the nodes that match, the smallest: an ancestor's text includes its children's, so the first
// match in document order is usually a container as wide as the screen and would pass vacuously.
function mostSpecific(matches) {
  return matches.slice().sort((a, b) => a.rect.width * a.rect.height - b.rect.width * b.rect.height)[0];
}

// Finds a key control: wait for it at the top of the page, then scroll down with the mouse wheel until
// it shows up. Flutter keeps a scroll view's children in the semantics tree, so a control below the
// fold is normally found at the top (measured October 14: the game over screen's MATCH HIGHLIGHTS
// at y=871 on an 812 px page); the wheel is for a control that is not built until it is scrolled near.
async function findKeyControl(page, size, control) {
  await wheelPage(page, size, -10000);
  const atTop = await waitFor(async () => {
    const matches = (await getSemanticsElements(page)).filter(control.find);
    return matches.length ? mostSpecific(matches) : null;
  }, { timeoutMs: SWEEP_FIND_MS, intervalMs: 300, description: 'a key control' }).catch(e => {
    rethrowIfUnresponsive(e);
    return null;
  });
  if (atTop) return { el: atTop, scrolled: 0 };
  for (let step = 1; step <= SWEEP_MAX_SCROLLS; step++) {
    await wheelPage(page, size, Math.round(size.height * 0.6));
    const matches = (await getSemanticsElements(page)).filter(control.find);
    if (matches.length) return { el: mostSpecific(matches), scrolled: step };
  }
  return null;
}

function describeRect(rect) {
  return `x=${rect.x.toFixed(1)}..${(rect.x + rect.width).toFixed(1)} y=${rect.y.toFixed(1)}..${(rect.y + rect.height).toFixed(1)}`;
}

// Resizes `page` through the three sizes while the room is in `phase`, and at each one
//   1. waits for Flutter to lay out again and re-enables semantics;
//   2. asserts the room document says `phase`;
//   3. asserts every key control exists (scrolling to it if need be) and sits inside the viewport
//      horizontally: x >= -1 and x + width <= viewport width + 1;
//   4. saves w21_<w>x<h>_<phase>.png, scrolled back to the top;
//   5. logs, as information only, every node whose right edge passes the viewport width (the deck
//      carousel peeks past the edge on purpose).
// keyControls: [{ name, find }], find being a predicate on a semantics node. A missing control, a
// control outside the viewport or the wrong phase throws, so the run fails. The page goes back to
// 1280x800 in a finally, because every later step assumes that size. This is a resized desktop
// page: no touch emulation and no mobile user agent.
async function sweepViewports(page, { code, phase, keyControls }) {
  const label = pageLabel(page);
  assertThat(Array.isArray(keyControls) && keyControls.length > 0, `sweep ${phase}: at least one key control is required`);
  let failure = null;
  try {
    for (const size of SWEEP_SIZES) {
      const at = `${phase} @${size.width}x${size.height}`;
      await page.setViewportSize(size);
      await page.waitForTimeout(SWEEP_LAYOUT_WAIT_MS);
      await enableSemantics(page);

      const room = await readRoom(code);
      assertThat(room.currentPhase === phase, `sweep ${at}: the room is in phase "${room.currentPhase}", expected "${phase}"`);

      for (const control of keyControls) {
        const found = await findKeyControl(page, size, control);
        if (!found) {
          const all = await getSemanticsElements(page);
          console.error(`[SWEEP FAILED] ${label} ${at}: "${control.name}" not found. Controls on screen:`, describeElements(all));
          throw new Error(`ASSERTION FAILED: sweep ${at}: key control "${control.name}" is missing after ${SWEEP_MAX_SCROLLS} scrolls`);
        }
        const { rect } = found.el;
        const inside = rect.x >= -1 && rect.x + rect.width <= size.width + 1;
        console.log(`[SWEEP] ${label} ${at}: "${control.name}" ${found.el.tag}[${found.el.role || ''}] ${describeRect(rect)} ` +
          `${inside ? 'inside' : 'OUTSIDE'} the ${size.width}px viewport${found.scrolled ? ` (found after ${found.scrolled} scroll(s))` : ''}`);
        assertThat(inside, `sweep ${at}: key control "${control.name}" runs past the viewport horizontally (${describeRect(rect)}; the viewport is ${size.width} px wide)`);
      }

      await wheelPage(page, size, -10000);
      await saveScreenshot(page, sweepShotName(size, phase));

      const past = (await getSemanticsElements(page)).filter(n => n.rect.x + n.rect.width > size.width + 1);
      console.log(`[SWEEP] ${label} ${at}: ${past.length} semantics node(s) have a right edge past ${size.width} px (information only)`);
      for (const n of past.slice(0, SWEEP_LOGGED_OVERFLOWS)) {
        const name = (n.text || n.ariaLabel).replace(/\s+/g, ' ').slice(0, 60);
        console.log(`[SWEEP]   ${n.tag}[${n.role || ''}] "${name}" right edge ${(n.rect.x + n.rect.width).toFixed(1)}`);
      }
      if (past.length > SWEEP_LOGGED_OVERFLOWS) console.log(`[SWEEP]   ... and ${past.length - SWEEP_LOGGED_OVERFLOWS} more`);
    }
  } catch (e) {
    failure = e;
    throw e;
  } finally {
    try {
      await page.setViewportSize(SWEEP_RESTORE);
      await page.waitForTimeout(SWEEP_LAYOUT_WAIT_MS);
      await enableSemantics(page);
    } catch (e) {
      // A failed sweep reports its own reason; a sweep that passed must not hide a page that will not resize back.
      if (!failure) throw e;
      console.error(`[SWEEP] ${label}: could not restore ${SWEEP_RESTORE.width}x${SWEEP_RESTORE.height}: ${e.message}`);
    }
  }
}

// ---------------------------------------------------------------------------------------------
// Running a script
// ---------------------------------------------------------------------------------------------

// Runs main(), prints one verdict line and exits. A watchdog reports a reason shortly before the
// runner's hard kill, so a script that overruns still says why.
function runMain(name, main) {
  const started = Date.now();
  const watchdog = setTimeout(() => {
    console.error(`${name}: SCRIPT BUDGET EXCEEDED (${SCRIPT_BUDGET_MS / 1000} s)`);
    process.exit(3);
  }, SCRIPT_BUDGET_MS);
  main().then(() => {
    clearTimeout(watchdog);
    console.log(`${name}: PASSED in ${Math.round((Date.now() - started) / 1000)} s`);
    process.exit(0);
  }, err => {
    clearTimeout(watchdog);
    console.error(`${name} ERROR:`, err);
    console.error(`${name}: FAILED after ${Math.round((Date.now() - started) / 1000)} s`);
    process.exit(1);
  });
}

module.exports = {
  EVIDENCE_DIR,
  sleep,
  assertThat,
  labelPage,
  pageLabel,
  evalOnPage,
  pageText,
  enableSemantics,
  getSemanticsElements,
  findSemanticsElement,
  describeElements,
  allText,
  hasText,
  hasButtonText,
  dismissAnyDialog,
  clickElement,
  tryClickElement,
  domClick,
  typeIntoInput,
  tryTypeIntoInput,
  craftFields,
  typeIntoCraftField,
  saveScreenshot,
  readRoom,
  readPlayers,
  voteCount,
  summarizeRoom,
  waitFor,
  waitForRoom,
  waitForScreen,
  markerOf,
  screenMarker,
  openApp,
  readRoomCode,
  createRoom,
  joinRoom,
  ensureTimersDisabled,
  ensureRounds,
  castVote,
  hostProceedToReveal,
  finishVote,
  progressSignature,
  StallDetector,
  accuseWhileWindowOpen,
  hostContinue,
  driveToGameOver,
  sweepViewports,
  runMain
};
