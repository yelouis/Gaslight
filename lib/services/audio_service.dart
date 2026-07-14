import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

class AudioService {
  AudioService._privateConstructor();
  static final AudioService instance = AudioService._privateConstructor();

  bool soundEnabled = true;

  AudioPlayer? _submitPlayer;
  AudioPlayer? _votePlayer;
  AudioPlayer? _revealPlayer;
  AudioPlayer? _unmaskPlayer;

  AudioPlayer get submitPlayer => _submitPlayer ??= AudioPlayer();
  AudioPlayer get votePlayer => _votePlayer ??= AudioPlayer();
  AudioPlayer get revealPlayer => _revealPlayer ??= AudioPlayer();
  AudioPlayer get unmaskPlayer => _unmaskPlayer ??= AudioPlayer();

  @visibleForTesting
  void setPlayers({
    required AudioPlayer submitPlayer,
    required AudioPlayer votePlayer,
    required AudioPlayer revealPlayer,
    required AudioPlayer unmaskPlayer,
  }) {
    _submitPlayer = submitPlayer;
    _votePlayer = votePlayer;
    _revealPlayer = revealPlayer;
    _unmaskPlayer = unmaskPlayer;
  }

  Future<void> playSubmit() async {
    if (!soundEnabled) return;
    try {
      await submitPlayer.stop();
      await submitPlayer.play(
        AssetSource('audio/quill_scratch.wav'),
        mode: PlayerMode.lowLatency,
      );
    } catch (e) {
      debugPrint('AudioService playSubmit error: $e');
    }
  }

  Future<void> playVote() async {
    if (!soundEnabled) return;
    try {
      await votePlayer.stop();
      await votePlayer.play(
        AssetSource('audio/wax_stamp.wav'),
        mode: PlayerMode.lowLatency,
      );
    } catch (e) {
      debugPrint('AudioService playVote error: $e');
    }
  }

  Future<void> playReveal() async {
    if (!soundEnabled) return;
    try {
      await revealPlayer.stop();
      await revealPlayer.play(
        AssetSource('audio/truth_reveal.wav'),
        mode: PlayerMode.lowLatency,
      );
    } catch (e) {
      debugPrint('AudioService playReveal error: $e');
    }
  }

  Future<void> playUnmaskSuccess() async {
    if (!soundEnabled) return;
    try {
      await unmaskPlayer.stop();
      await unmaskPlayer.play(
        AssetSource('audio/unmask_success.wav'),
        mode: PlayerMode.lowLatency,
      );
    } catch (e) {
      debugPrint('AudioService playUnmaskSuccess error: $e');
    }
  }

  void dispose() {
    _submitPlayer?.dispose();
    _votePlayer?.dispose();
    _revealPlayer?.dispose();
    _unmaskPlayer?.dispose();
  }
}
