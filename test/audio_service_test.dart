import 'package:flutter_test/flutter_test.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:gaslight/services/audio_service.dart';

class FakeAudioPlayer implements AudioPlayer {
  int playCallCount = 0;
  Source? playedSource;
  PlayerMode? playedMode;

  @override
  Future<void> play(
    Source source, {
    double? volume,
    double? balance,
    AudioContext? ctx,
    Duration? position,
    PlayerMode? mode,
  }) async {
    playCallCount++;
    playedSource = source;
    playedMode = mode;
  }

  @override
  Future<void> stop() async {
    // no-op
  }

  @override
  Future<void> dispose() async {
    // no-op
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    return null;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('AudioService Mute Contract Tests', () {
    late FakeAudioPlayer submitPlayer;
    late FakeAudioPlayer votePlayer;
    late FakeAudioPlayer revealPlayer;
    late FakeAudioPlayer unmaskPlayer;

    setUp(() {
      submitPlayer = FakeAudioPlayer();
      votePlayer = FakeAudioPlayer();
      revealPlayer = FakeAudioPlayer();
      unmaskPlayer = FakeAudioPlayer();

      AudioService.instance.setPlayers(
        submitPlayer: submitPlayer,
        votePlayer: votePlayer,
        revealPlayer: revealPlayer,
        unmaskPlayer: unmaskPlayer,
      );
    });

    test('should play audio when soundEnabled is true', () async {
      AudioService.instance.soundEnabled = true;

      await AudioService.instance.playSubmit();
      expect(submitPlayer.playCallCount, 1);
      expect(submitPlayer.playedSource, isA<AssetSource>());
      expect((submitPlayer.playedSource as AssetSource).path, 'audio/quill_scratch.wav');

      await AudioService.instance.playVote();
      expect(votePlayer.playCallCount, 1);
      expect((votePlayer.playedSource as AssetSource).path, 'audio/wax_stamp.wav');

      await AudioService.instance.playReveal();
      expect(revealPlayer.playCallCount, 1);
      expect((revealPlayer.playedSource as AssetSource).path, 'audio/truth_reveal.wav');

      await AudioService.instance.playUnmaskSuccess();
      expect(unmaskPlayer.playCallCount, 1);
      expect((unmaskPlayer.playedSource as AssetSource).path, 'audio/unmask_success.wav');
    });

    test('should NOT play audio when soundEnabled is false', () async {
      AudioService.instance.soundEnabled = false;

      await AudioService.instance.playSubmit();
      expect(submitPlayer.playCallCount, 0);

      await AudioService.instance.playVote();
      expect(votePlayer.playCallCount, 0);

      await AudioService.instance.playReveal();
      expect(revealPlayer.playCallCount, 0);

      await AudioService.instance.playUnmaskSuccess();
      expect(unmaskPlayer.playCallCount, 0);
    });
  });
}
