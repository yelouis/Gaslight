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
  UNMASK: 'UNMASK'
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
