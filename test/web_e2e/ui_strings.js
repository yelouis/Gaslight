// test/web_e2e/ui_strings.js
//
// Single source of truth for UI strings matched by web E2E scripts.
// - UI: strings rendered by the app, existence-checked against lib/**/*.dart by scripts/check_web_e2e_strings.sh.
// - FIXTURE: test-supplied data typed by scripts and matched in answers/names/rounds. Not existence-checked.

const UI = Object.freeze({
  CANCEL: 'CANCEL',
  // Invariant substring matching 'THE NIGHT\'S HONORS' in lib/screens/game_over_screen.dart
  NIGHTS_HONORS: "NIGHT'S HONORS",
  GAME_OVER: 'GAME OVER',
  FINAL_STANDINGS: 'FINAL STANDINGS',
  SHARE_CASE_FILE: 'Share Case File',
  ENGRAVING: 'Engraving',
  SUBMIT_DOSSIER: 'SUBMIT DOSSIER',
  IM_READY: "I'M READY",
  OPTION: 'OPTION',
  LEAVE: 'Leave',
  MUTE: 'Mute',
  CONFIRM: 'CONFIRM',
  TAP_A_CARD_TO_CHOOSE: 'TAP A CARD TO CHOOSE',
  CONTINUE: 'CONTINUE',
  CONFIRM_VOTE: 'CONFIRM VOTE',
  NEXT: 'NEXT',
  CREATE_ROOM: 'CREATE ROOM',
  ROOM_CODE: 'ROOM CODE',
  JOIN_ROOM: 'JOIN ROOM',
  DISABLE_GAME_TIMERS: 'Disable Game Timers',
  START_GAME: 'START GAME',
  LEAVE_GAME: 'Leave game',
  LEAVE_GAME_DIALOG: 'LEAVE GAME',
  LEAVE_DIALOG: 'LEAVE',
  READY: 'READY',
  PROCEED: 'PROCEED',
  SEALED: 'SEALED',
  YOUR_FORGERY: 'Your Forgery',
  SILENT: 'SILENT',
  RESOLVING: 'RESOLVING',
  THE_REVEAL: 'THE REVEAL',
  UNMASK: 'UNMASK',
  // Wave AK / AK1. Every value below was checked against lib/ (see check_web_e2e_strings.sh).
  GUEST_LEDGER: 'THE GUEST LEDGER',
  ROUNDS_LABEL: 'Rounds:',
  THE_INK_DRIES: 'THE INK DRIES',
  THE_VOTE: 'THE VOTE',
  YOUR_BALLOT_IS_SEALED: 'YOUR BALLOT IS SEALED',
  NOT_READY: 'NOT READY',
  // Invariant prefix of 'Write a convincing lie as $targetName. You score points ...' (phase2_craft.dart).
  WRITE_LIE_AS: 'Write a convincing lie as',
  TOO_SIMILAR: 'Too similar to an existing answer! Be more creative.',
  // Invariant prefix of 'Show option ${i + 1} of ${n}' (card_grid.dart): n is the deck size.
  SHOW_OPTION: 'Show option',
  NEXT_OPTION: 'Next option',
  PREVIOUS_OPTION: 'Previous option',
  TAP_TO_CHOOSE: 'Tap to choose this one',
  PROCEED_TO_REVEAL: 'PROCEED TO REVEAL (HOST)',
  ACCUSE_PROMPT: 'Accuse the player who wrote the forgery you voted for:',
  MATCH_HIGHLIGHTS: 'MATCH HIGHLIGHTS'
});

const FIXTURE = Object.freeze({
  ALICE: 'Alice',
  BOB: 'Bob',
  CHARLIE: 'Charlie',
  ALICE_UPPER: 'ALICE',
  BOB_UPPER: 'BOB',
  CHARLIE_UPPER: 'CHARLIE',
  PARIS: 'Paris',
  LOUVRE: 'Louvre',
  AAA: 'AAA',
  BBB: 'BBB',
  CCC: 'CCC',
  FAKE: 'Fake',
  STORY: 'Story',
  ROUNDS_1: '1',
  ROUNDS_2: '2'
});

module.exports = {
  UI,
  FIXTURE
};
