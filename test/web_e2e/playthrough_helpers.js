const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');

const EVIDENCE_DIR = path.resolve(__dirname, '../../docs/playthrough_evidence');
if (!fs.existsSync(EVIDENCE_DIR)) {
  fs.mkdirSync(EVIDENCE_DIR, { recursive: true });
}

async function enableSemantics(page) {
  await page.evaluate(() => {
    const placeholder = document.querySelector('flt-semantics-placeholder');
    if (placeholder) placeholder.click();
    const btn = document.querySelector('[aria-label="Enable accessibility"]');
    if (btn) btn.click();
  });
  await page.waitForTimeout(300);
}

async function getSemanticsElements(page) {
  await enableSemantics(page);
  return await page.evaluate(() => {
    const nodes = document.querySelectorAll('flt-semantics, input, textarea, button');
    return Array.from(nodes).map(n => {
      const rect = n.getBoundingClientRect();
      return {
        tag: n.tagName,
        type: n.getAttribute('type'),
        role: n.getAttribute('role'),
        ariaLabel: n.getAttribute('aria-label') || '',
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

async function dismissAnyDialog(page) {
  await enableSemantics(page);
  const elements = await getSemanticsElements(page);
  const dismissBtn = elements.find(e => 
    e.role === 'button' && (e.text === 'CANCEL' || e.text === 'DISMISS' || e.text === 'Dismiss')
  );
  if (dismissBtn) {
    console.log(`[DISMISS] Dismissing dialog via button "${dismissBtn.text}"`);
    const cx = dismissBtn.rect.x + dismissBtn.rect.width / 2;
    const cy = dismissBtn.rect.y + dismissBtn.rect.height / 2;
    await page.mouse.click(cx, cy);
    await page.waitForTimeout(500);
  }
}

async function clickElement(page, filterFn, description, clickOffset = null) {
  await dismissAnyDialog(page);
  let el = await findSemanticsElement(page, filterFn);
  if (!el) {
    // Try scrolling down to find off-screen element
    await page.mouse.wheel(0, 300);
    await page.waitForTimeout(300);
    el = await findSemanticsElement(page, filterFn);
  }
  if (!el) {
    const all = await getSemanticsElements(page);
    console.error(`[CLICK FAILED] Element not found: ${description}. Available elements:`, all.map(a => `${a.tag}[${a.role || ''}]: "${a.text || a.ariaLabel}"`));
    throw new Error(`Could not find element: ${description}`);
  }
  
  let cx = el.rect.x + el.rect.width / 2;
  let cy = el.rect.y + el.rect.height / 2;
  if (clickOffset) {
    cx = el.rect.x + clickOffset.x;
    cy = el.rect.y + clickOffset.y;
  }

  // Scroll into view if below 720px
  if (cy > 720) {
    const scrollAmount = cy - 500;
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
}

async function tryClickElement(page, filterFn, description, clickOffset = null) {
  try {
    await clickElement(page, filterFn, description, clickOffset);
    return true;
  } catch (e) {
    return false;
  }
}

async function typeIntoInput(page, labelOrPlaceholder, textToType) {
  await dismissAnyDialog(page);
  let el = await findSemanticsElement(page, n => 
    (n.tag === 'INPUT' || n.tag === 'TEXTAREA') && 
    (n.ariaLabel.toLowerCase().includes(labelOrPlaceholder.toLowerCase()) || n.text.toLowerCase().includes(labelOrPlaceholder.toLowerCase()))
  );
  if (!el) {
    await page.mouse.wheel(0, -300);
    await page.waitForTimeout(300);
    el = await findSemanticsElement(page, n => 
      (n.tag === 'INPUT' || n.tag === 'TEXTAREA') && 
      (n.ariaLabel.toLowerCase().includes(labelOrPlaceholder.toLowerCase()) || n.text.toLowerCase().includes(labelOrPlaceholder.toLowerCase()))
    );
  }
  if (!el) {
    const all = await getSemanticsElements(page);
    console.error(`[TYPE FAILED] Input not found: ${labelOrPlaceholder}. Inputs:`, all.filter(a => a.tag === 'INPUT' || a.tag === 'TEXTAREA'));
    throw new Error(`Could not find input: ${labelOrPlaceholder}`);
  }
  let cx = el.rect.x + el.rect.width / 2;
  let cy = el.rect.y + el.rect.height / 2;
  if (cy > 720) {
    await page.mouse.wheel(0, cy - 500);
    await page.waitForTimeout(300);
    const newEl = await findSemanticsElement(page, n => 
      (n.tag === 'INPUT' || n.tag === 'TEXTAREA') && 
      (n.ariaLabel.toLowerCase().includes(labelOrPlaceholder.toLowerCase()) || n.text.toLowerCase().includes(labelOrPlaceholder.toLowerCase()))
    );
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
    return false;
  }
}

async function saveScreenshot(page, filename) {
  const fullPath = path.join(EVIDENCE_DIR, filename);
  await page.screenshot({ path: fullPath });
  console.log(`[SCREENSHOT] Saved ${filename}`);
  return `docs/playthrough_evidence/${filename}`;
}

module.exports = {
  enableSemantics,
  getSemanticsElements,
  findSemanticsElement,
  dismissAnyDialog,
  clickElement,
  tryClickElement,
  typeIntoInput,
  tryTypeIntoInput,
  saveScreenshot,
  EVIDENCE_DIR
};
