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

| Block | Title | Specified assertion | Artefact must depict |
|---|---|---|---|
| E47 | Own answer is sealed in round 2, and it is the option authored this round | In round 2, on a card where the player wrote a forgery, that player's own option is stamped SEALED / (Your Forgery), is not tappable, and its text is the forgery they authored in round 2 — not round 1. | The round-2 vote screen with the sealed option and its text both legible |
| E48 | Unmask window withholds then publishes deltas, including with the host absent | During the unmask window no per-player points are displayed; after it closes the tray appears with values that include the unmask ±1 and standings badges update; and on a second fooled card the tray fills on remaining devices while the host is absent before the deadline expires. | (a) Reveal screen during the window with no tray and no deltas; (b) reveal screen after close with tray and updated badges; (c) a remaining player's device showing the tray filled while the host is absent |
| E49 | Presence: still seated at ~2 min, gone at ~11 | After xcrun simctl terminate on P5 (no relaunch), P5 is still present in every other device's roster at approximately 2 minutes and absent at approximately 11 minutes, with both wall-clock timestamps recorded. | A remaining device's roster with P5 present and the device status-bar clock legible; and the same roster with P5 absent, clock legible |
