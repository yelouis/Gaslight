# Playthrough Manifest

Single source of truth for block titles and their specified assertions.
Rule R6 in `scripts/check_playthrough_evidence.sh` fails the gate when a governed block's
title or `**Specified assertion:**` field does not match this manifest **verbatim**
(whitespace-normalised only — case and punctuation are preserved).

**Blocks with no row here are unaffected by R6.** The 22 legacy blocks (E22–E43) were not
written under a verbatim-assertion contract and must not start failing.

**When a block is legitimately re-scoped**, change its row in this manifest **in the same
commit** — the manifest diff is the point. R6's failure message names this file and the
offending row so a legitimate update is a ten-second fix, not a mystery.

**What R6 does not prove:** that the assertion is true, or that the artefact shows what
`Artefact depicts:` claims. R6 only proves the block still carries the assertion it was given.
Opening every cited artefact and asking what it shows remains a standing rule (§9 of
`agent_execution_guide.md`).

---

| Report | Block | Title | Specified assertion | Artefact must depict |
|---|---|---|---|---|
| docs/playthroughs/findings_5player.md | E47 | Own answer is sealed in round 2, and it is the option authored this round | In round 2, on a card where the player wrote a forgery, that player's own option is stamped SEALED / (Your Forgery), is not tappable, and its text is the forgery they authored in round 2 — not round 1. | The round-2 vote screen with the sealed option and its text both legible |
| docs/playthroughs/findings_5player.md | E48 | Unmask window withholds then publishes deltas, including with the host absent | During the unmask window no per-player points are displayed; after it closes the tray appears with values that include the unmask ±1 and standings badges update; and on a second fooled card the tray fills on remaining devices while the host is absent before the deadline expires. | (a) Reveal screen during the window with no tray and no deltas; (b) reveal screen after close with tray and updated badges; (c) a remaining player's device showing the tray filled while the host is absent |
| docs/playthroughs/findings_5player.md | E49 | Presence: still seated at ~2 min, gone at ~11 | After xcrun simctl terminate on P5 (no relaunch), P5 is still present in every other device's roster at approximately 2 minutes and absent at approximately 11 minutes, with both wall-clock timestamps recorded. | A remaining device's roster with P5 present and the device status-bar clock legible; and the same roster with P5 absent, clock legible |
| docs/playthroughs/findings_waveAA.md | E50 | Craft screen first paint with no modal dialog overlay | Upon entering the craft phase, the screen paints immediately with prompt and interactive answer field visible without any modal overlay dialog. | Craft screen on first paint after a phase change with no modal dialog over it; answer field immediately interactive |
| docs/playthroughs/findings_waveAA.md | E51 | Live character counter normal reading and overflow error color | The live character counter reads the current character count against the 100 limit, and switches to error styling when exceeding 100 characters without capping input. | The live character counter reading a value below 100, and reading it in the error colour past 100 (two shots) |
| docs/playthroughs/findings_waveAA.md | E52 | Sentence stem rendered beneath field with answer field empty | A curated sentence stem is displayed below the answer field as guidance while the text field remains completely empty. | A sentence stem rendered beneath the field with the answer field still empty — the stem is never pre-filled |
| docs/playthroughs/findings_waveAA.md | E53 | Craft waiting screen recaps submitted answer and prompt | After submitting an answer, the waiting screen displays the player's own submitted text alongside the prompt recap. | The craft waiting screen showing this player's own submitted answer and its prompt |
| docs/playthroughs/findings_waveAA.md | E54 | Answer field visible above keyboard during input | When focusing the answer field and bringing up the on-screen keyboard, the input field scrolls above the keyboard and remains visible. | The answer field visible above the on-screen keyboard while typing |
| docs/playthroughs/findings_waveAA.md | E55 | Stacked deck vote options with backward navigation | Vote options render as a stacked deck showing active card in front with next card peeking, PREV/NEXT controls and jump dots; swiping right navigates backward. | Stacked deck active card in front with next peeking behind, PREV/NEXT and jump dots; and a second shot after right-swipe showing previous card back in front |
| docs/playthroughs/findings_waveAA.md | E56 | Target attribution chips on forgeries and absent on truth | The target player's vote screen displays a row of author attribution chips on forgery options with selection affordance, and no attribution chips on their own truth option. | The target's attribution chip row on a forgery with one author chip selected, plus a shot of the target's own truth showing no attribution affordance |
| docs/playthroughs/findings_waveAA.md | E57 | Target ready control toggles between ready and not ready | The target's ready control functions as a server-driven toggle, updating to NOT READY upon being tapped while ready. | The target's ready control reading NOT READY after being tapped once |
| docs/playthroughs/findings_waveAA.md | E58 | Reveal score breakdown with named rule lines and totals | The reveal screen points tray displays an itemized score breakdown detailing named scoring rules alongside cumulative player totals. | The reveal screen's itemised score breakdown, showing named rule lines and the player totals still visible |
| docs/playthroughs/findings_waveAA.md | E59 | Running rivalries block withheld during unmask and published on reveal | The reveal screen withholds the THE PARLOUR REMEMBERS rivalries block during an active unmask window, and displays it with running rivalry lines once author identities flip. | AB2's rivalries block on the reveal present after author flip, plus a shot of the same screen during an open unmask window showing it absent |
| docs/playthroughs/findings_waveAA.md | E60 | Game over final results with standings above honors | The Game Over screen presents the FINAL RESULTS heading with final standings placed above the honors section. | Game over: FINAL RESULTS heading with standings above the honors |
| docs/playthroughs/findings_waveAA.md | E61 | Match highlight card with full-width title and badge on separate line | The match-highlight card displays BEST LIE OF THE NIGHT across full card width with its deception badge positioned on a separate line. | A match-highlight card with BEST LIE OF THE NIGHT fully legible and its badge on a separate line |
| docs/playthroughs/findings_waveAA.md | E62 | Manual button in in-game AppBar and modal sheet over phase | The in-game AppBar provides a dedicated Game Manual button across gameplay phases that opens the rules sheet without interrupting match state. | The manual affordance in the in-game AppBar, and the manual open over a phase screen |
| docs/playthroughs/findings_waveAA.md | E63 | Best-forgery banner suppressed when forgeries draw below two votes | In a 3-player match where candidate forgeries draw at most one vote, the BEST FORGERY OF THE ROUND banner is suppressed on the reveal screen. | A three-player reveal where a forgery drew one vote and no best-forgery banner is shown |
