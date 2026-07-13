import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../lib/services/game_service.dart';
import '../lib/models/game_state.dart';
import '../lib/models/player_state.dart';
import '../lib/models/card_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../lib/utils/semantic_filter.dart';
import 'fake_functions.dart';

// Minimal manual mock for Firestore
class FakeFirestore extends Fake implements FirebaseFirestore {
  final Map<String, dynamic> data = {};
  final _streams = <String, StreamController<DocumentSnapshot<Map<String, dynamic>>>>{};
  final _queryStreams = <String, StreamController<QuerySnapshot<Map<String, dynamic>>>>{};

  @override
  CollectionReference<Map<String, dynamic>> collection(String path) {
    return FakeCollectionReference(this, path);
  }

  @override
  WriteBatch batch() => FakeWriteBatch(this);

  @override
  Future<T> runTransaction<T>(TransactionHandler<T> transactionHandler, {Duration timeout = const Duration(seconds: 30), int maxAttempts = 5}) async {
    final tx = FakeTransaction(this);
    return await transactionHandler(tx);
  }
}

class FakeCollectionReference extends Fake implements CollectionReference<Map<String, dynamic>> {
  final FakeFirestore firestore;
  final String path;

  FakeCollectionReference(this.firestore, this.path);

  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) {
    return FakeDocumentReference(firestore, '${this.path}/${path ?? 'auto_id'}');
  }

  @override
  Future<QuerySnapshot<Map<String, dynamic>>> get([GetOptions? options]) async {
    final docs = firestore.data.entries
        .where((e) => e.key.startsWith('$path/'))
        .map((e) => FakeDocumentSnapshot(e.key, Map<String, dynamic>.from(e.value)))
        .toList();
    return FakeQuerySnapshot(docs);
  }

  @override
  Stream<QuerySnapshot<Map<String, dynamic>>> snapshots({
    bool includeMetadataChanges = false,
    ListenSource source = ListenSource.defaultSource,
  }) async* {
    if (firestore.data.entries.any((e) => e.key.startsWith('$path/'))) {
      final docs = firestore.data.entries
          .where((e) => e.key.startsWith('$path/'))
          .map((e) => FakeDocumentSnapshot(e.key, Map<String, dynamic>.from(e.value)))
          .toList();
      yield FakeQuerySnapshot(docs);
    }
    final controller = firestore._queryStreams.putIfAbsent(path, () => StreamController.broadcast());
    yield* controller.stream;
  }
}

class FakeDocumentReference<T extends Object?> extends Fake implements DocumentReference<T> {
  final FakeFirestore firestore;
  final String path;

  FakeDocumentReference(this.firestore, this.path);

  @override
  String get id => path.split('/').last;

  @override
  Future<void> set(T data, [SetOptions? options]) async {
    final mapData = data as Map<String, dynamic>;
    if (options?.merge ?? false) {
      firestore.data[path] = {...(firestore.data[path] ?? {}), ...mapData};
    } else {
      firestore.data[path] = mapData;
    }
    _triggerListeners();
  }

  @override
  Future<void> update(Map<Object, Object?> data) async {
    firestore.data[path] = {...(firestore.data[path] ?? {}), ...data};
    _triggerListeners();
  }

  @override
  Future<void> delete() async {
    firestore.data.remove(path);
    _triggerListeners();
  }

  @override
  Future<DocumentSnapshot<T>> get([GetOptions? options]) async {
    final rawData = firestore.data[path];
    return FakeDocumentSnapshot(path, rawData != null ? Map<String, dynamic>.from(rawData) : null) as DocumentSnapshot<T>;
  }

  @override
  Stream<DocumentSnapshot<T>> snapshots({
    bool includeMetadataChanges = false,
    ListenSource source = ListenSource.defaultSource,
  }) async* {
    if (firestore.data.containsKey(path)) {
      yield FakeDocumentSnapshot(path, Map<String, dynamic>.from(firestore.data[path]!)) as DocumentSnapshot<T>;
    }
    final controller = firestore._streams.putIfAbsent(path, () => StreamController.broadcast());
    yield* controller.stream as Stream<DocumentSnapshot<T>>;
  }

  void _triggerListeners() {
    if (firestore._streams.containsKey(path)) {
      firestore._streams[path]!.add(FakeDocumentSnapshot(path, Map<String, dynamic>.from(firestore.data[path] ?? {})));
    }
    // Also trigger collection queries
    final lastSlash = path.lastIndexOf('/');
    if (lastSlash != -1) {
      final collectionPath = path.substring(0, lastSlash);
      if (firestore._queryStreams.containsKey(collectionPath)) {
        final docs = firestore.data.entries
            .where((e) => e.key.startsWith('$collectionPath/'))
            .map((e) => FakeDocumentSnapshot(e.key, Map<String, dynamic>.from(e.value)))
            .toList();
        firestore._queryStreams[collectionPath]!.add(FakeQuerySnapshot(docs));
      }
    }
  }

  @override
  CollectionReference<Map<String, dynamic>> collection(String collectionPath) {
    return FakeCollectionReference(firestore, '$path/$collectionPath');
  }
}

class FakeDocumentSnapshot extends Fake implements DocumentSnapshot<Map<String, dynamic>>, QueryDocumentSnapshot<Map<String, dynamic>> {
  final String path;
  final Map<String, dynamic>? _data;

  FakeDocumentSnapshot(this.path, this._data);

  @override
  String get id => path.split('/').last;

  @override
  bool get exists => _data != null;

  @override
  Map<String, dynamic> data() => _data ?? {};

  @override
  SnapshotMetadata get metadata => throw UnimplementedError();

  @override
  DocumentReference<Map<String, dynamic>> get reference => throw UnimplementedError();

  @override
  dynamic operator [](Object field) => _data?[field];

  @override
  dynamic get(Object field) => _data?[field];
}

class FakeQuerySnapshot extends Fake implements QuerySnapshot<Map<String, dynamic>> {
  @override
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;

  FakeQuerySnapshot(List<FakeDocumentSnapshot> snapshots)
      : docs = snapshots;
}

class FakeWriteBatch extends Fake implements WriteBatch {
  final FakeFirestore firestore;
  final List<Function> operations = [];

  FakeWriteBatch(this.firestore);

  @override
  void update(DocumentReference ref, Map<Object, Object?> data) {
    operations.add(() => ref.update(data));
  }

  @override
  void set<T>(DocumentReference<T> ref, T data, [SetOptions? options]) {
    operations.add(() => ref.set(data, options));
  }

  @override
  Future<void> commit() async {
    for (var op in operations) {
      await op();
    }
  }
}

class FakeTransaction extends Fake implements Transaction {
  final FakeFirestore firestore;

  FakeTransaction(this.firestore);

  @override
  Future<DocumentSnapshot<T>> get<T>(DocumentReference<T> ref) async {
    return await ref.get();
  }

  @override
  Transaction update(DocumentReference ref, Map<Object, Object?> data) {
    ref.update(data);
    return this;
  }

  @override
  Transaction set<T>(DocumentReference<T> ref, T data, [SetOptions? options]) {
    ref.set(data, options);
    return this;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('10-Player E2E Simulation', () {
    late FakeFirestore mockDb;
    late GameService gameService;
    final String hostId = 'host_user';
    final String hostName = 'Host';

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      mockDb = FakeFirestore();
      gameService = GameService(db: mockDb, functions: FakeFirebaseFunctions(mockDb));
    });

    test('Full Game Loop for 10 Players', () async {
      print('--- STARTING 10-PLAYER SIMULATION ---');

      // 1. Create Room
      await gameService.createRoom(hostName, hostId, sabotageAnswersCount: 2);
      await Future.delayed(Duration(milliseconds: 100));
      expect(gameService.gameState, isNotNull);
      final roomCode = gameService.gameState!.roomCode;
      print('Room created: $roomCode');

      // 2. Add 9 Bots
      await gameService.debugAddBots();
      await Future.delayed(Duration(milliseconds: 200));
      expect(gameService.players.length, 10);
      print('Players joined: ${gameService.players.length}');

      // 3. Start Game
      await gameService.startGame('the_daily_grind');
      await Future.delayed(Duration(milliseconds: 100));
      expect(gameService.gameState!.currentPhase, GamePhase.forgery);
      print('Game started. Phase: Sabotage Round 1');

      // 4. Sabotage Round 1
      await gameService.setPlayerReady(true); // Host ready
      await gameService.debugSimulateBotResponses();
      await Future.delayed(Duration(milliseconds: 100));
      if (gameService.gameState!.currentRotationIndex == 1) {
        await gameService.evaluateReadyState(); // Advance manually as host
        await Future.delayed(Duration(milliseconds: 100));
      }
      
      expect(gameService.gameState!.currentRotationIndex, 2);
      print('Phase: Sabotage Round 2');

      // 5. Sabotage Round 2
      await gameService.setPlayerReady(true);
      await gameService.debugSimulateBotResponses();
      await Future.delayed(Duration(milliseconds: 100));
      if (gameService.gameState!.currentPhase == GamePhase.forgery) {
        await gameService.evaluateReadyState();
        await Future.delayed(Duration(milliseconds: 100));
      }
      
      expect(gameService.gameState!.currentPhase, GamePhase.truth);
      print('Phase: Truth Round');

      // 6. Truth Round
      await gameService.setPlayerReady(true);
      await gameService.debugSimulateBotResponses();
      await Future.delayed(Duration(milliseconds: 100));
      if (gameService.gameState!.currentPhase == GamePhase.truth) {
        await gameService.evaluateReadyState();
        await Future.delayed(Duration(milliseconds: 100));
      }
      
      expect(gameService.gameState!.currentPhase, GamePhase.vote);
      print('Phase: Voting (Card 1/10)');

      // 7. Voting & Reveals for all 10 cards
      for (int i = 0; i < 10; i++) {
        final currentCardIdx = i + 1;
        print('Processing Card $currentCardIdx/10...');
        
        // Vote Phase
        await gameService.setPlayerReady(true);
        await gameService.debugSimulateBotResponses();
        await Future.delayed(Duration(milliseconds: 100));
        if (gameService.gameState!.currentPhase == GamePhase.vote) {
          await gameService.evaluateReadyState();
          await Future.delayed(Duration(milliseconds: 100));
        }
        
        expect(gameService.gameState!.currentPhase, GamePhase.reveal);
        
        // Reveal Phase
        await gameService.setPlayerReady(true);
        await gameService.debugSimulateBotResponses();
        await Future.delayed(Duration(milliseconds: 100));
        if (gameService.gameState!.currentPhase == GamePhase.reveal) {
          await gameService.evaluateReadyState();
          await Future.delayed(Duration(milliseconds: 100));
        }
        
        // Advance to next resolution
        await gameService.advanceToNextResolution();
        await Future.delayed(Duration(milliseconds: 100));
        
        if (i < 9) {
          expect(gameService.gameState!.currentPhase, GamePhase.vote);
        } else {
          expect(gameService.gameState!.currentPhase, GamePhase.gameOver);
        }
      }

      print('Phase: Game Over');
      print('--- FINAL SCORES ---');
      for (var p in gameService.players) {
        print('${p.name}: ${p.totalScore}');
      }

      print('--- SIMULATION COMPLETED SUCCESSFULLY ---');
    });

    test('Mid-game Disconnect & Spectator Join Simulation', () async {
      print('--- STARTING DISCONNECT & SPECTATOR JOIN SIMULATION ---');

      // 1. Create Room
      await gameService.createRoom(hostName, hostId, sabotageAnswersCount: 2);
      await Future.delayed(Duration(milliseconds: 100));
      expect(gameService.gameState, isNotNull);
      final roomCode = gameService.gameState!.roomCode;
      print('Room created: $roomCode');

      // 2. Add 9 Bots (10 total players)
      await gameService.debugAddBots();
      await Future.delayed(Duration(milliseconds: 200));
      expect(gameService.players.length, 10);
      print('Players joined: ${gameService.players.length}');

      // 3. Start Game
      await gameService.startGame('the_daily_grind');
      await Future.delayed(Duration(milliseconds: 100));
      expect(gameService.gameState!.currentPhase, GamePhase.forgery);
      print('Game started. Phase: Sabotage Round 1');

      // 4. Spectator Joins mid-game
      final specService = GameService(db: mockDb, functions: FakeFirebaseFunctions(mockDb));
      await specService.joinRoom(roomCode, 'Spectator User', 'spectator_user');
      await Future.delayed(Duration(milliseconds: 200));
      
      // Verify spectator is assigned the spectator role
      final spectatorPlayer = gameService.players.firstWhere((p) => p.id == 'spectator_user');
      expect(spectatorPlayer.role, PlayerRole.spectator);
      print('Spectator joined successfully with role: ${spectatorPlayer.role}');

      // 5. Sabotage Round 1 with Spectator present
      await gameService.setPlayerReady(true); // Host ready
      await gameService.debugSimulateBotResponses();
      await Future.delayed(Duration(milliseconds: 100));
      if (gameService.gameState!.currentRotationIndex == 1) {
        await gameService.evaluateReadyState(); // Advance manually as host
        await Future.delayed(Duration(milliseconds: 100));
      }
      
      // Verify transitioned to sabotage round 2, without needing spectator ready
      expect(gameService.gameState!.currentRotationIndex, 2);
      print('Advanced to Sabotage Round 2 (Spectator ignored for readiness)');

      // 6. Simulate player disconnect (delete bot_1)
      print('Simulating disconnect of bot_1...');
      await mockDb.collection('rooms').doc(roomCode).collection('players').doc('bot_1').delete();
      await Future.delayed(Duration(milliseconds: 200));

      // Verify bot_1 is removed and their card is removed/bridged
      final hasBot1 = gameService.players.any((p) => p.id == 'bot_1');
      expect(hasBot1, isFalse);
      
      final cardTargets = gameService.gameState!.cards.map((c) => c.targetPlayerId).toSet();
      expect(cardTargets.contains('bot_1'), isFalse);
      print('bot_1 successfully removed. Card count: ${gameService.gameState!.cards.length}');

      // 7. Finish Sabotage Round 2
      await gameService.setPlayerReady(true);
      await gameService.debugSimulateBotResponses();
      await Future.delayed(Duration(milliseconds: 100));
      if (gameService.gameState!.currentPhase == GamePhase.forgery) {
        await gameService.evaluateReadyState();
        await Future.delayed(Duration(milliseconds: 100));
      }
      
      expect(gameService.gameState!.currentPhase, GamePhase.truth);
      print('Phase: Truth Round');

      // 8. Truth Round
      await gameService.setPlayerReady(true);
      await gameService.debugSimulateBotResponses();
      await Future.delayed(Duration(milliseconds: 100));
      if (gameService.gameState!.currentPhase == GamePhase.truth) {
        await gameService.evaluateReadyState();
        await Future.delayed(Duration(milliseconds: 100));
      }
      
      expect(gameService.gameState!.currentPhase, GamePhase.vote);
      print('Phase: Voting (9 active cards remaining)');

      // 9. Voting & Reveals for remaining 9 cards
      final expectedCards = 9;
      for (int i = 0; i < expectedCards; i++) {
        final currentCardIdx = i + 1;
        print('Processing Card $currentCardIdx/$expectedCards...');
        
        // Vote Phase
        await gameService.setPlayerReady(true);
        await gameService.debugSimulateBotResponses();
        await Future.delayed(Duration(milliseconds: 100));
        if (gameService.gameState!.currentPhase == GamePhase.vote) {
          await gameService.evaluateReadyState();
          await Future.delayed(Duration(milliseconds: 100));
        }
        
        expect(gameService.gameState!.currentPhase, GamePhase.reveal);
        
        // Reveal Phase
        await gameService.setPlayerReady(true);
        await gameService.debugSimulateBotResponses();
        await Future.delayed(Duration(milliseconds: 100));
        if (gameService.gameState!.currentPhase == GamePhase.reveal) {
          await gameService.evaluateReadyState();
          await Future.delayed(Duration(milliseconds: 100));
        }
        
        // Advance to next resolution
        await gameService.advanceToNextResolution();
        await Future.delayed(Duration(milliseconds: 100));
        
        if (i < expectedCards - 1) {
          expect(gameService.gameState!.currentPhase, GamePhase.vote);
        } else {
          expect(gameService.gameState!.currentPhase, GamePhase.gameOver);
        }
      }

      print('Phase: Game Over');
      print('--- FINAL SCORES ---');
      for (var p in gameService.players) {
        print('${p.name}: ${p.totalScore}');
      }

      print('--- DISCONNECT SIMULATION COMPLETED SUCCESSFULLY ---');
    });

    test('Casual Mode (Disabled Game Timers) Simulation', () async {
      print('--- STARTING CASUAL MODE SIMULATION ---');

      // 1. Create Room with isTimerDisabled = true
      await gameService.createRoom(hostName, hostId, sabotageAnswersCount: 2, isTimerDisabled: true);
      await Future.delayed(Duration(milliseconds: 100));
      expect(gameService.gameState, isNotNull);
      expect(gameService.gameState!.isTimerDisabled, isTrue);

      // 2. Add bots to satisfy player count guards
      await gameService.debugAddBots();
      await Future.delayed(Duration(milliseconds: 200));

      // Start Game
      await gameService.startGame('the_daily_grind');
      await Future.delayed(Duration(milliseconds: 100));
      
      // Verify that currentPhase is forgery and endTime is null
      expect(gameService.gameState!.currentPhase, GamePhase.forgery);
      expect(gameService.gameState!.endTime, isNull);
      print('Game started in Casual Mode. endTime is verified to be null.');
    });

    test('Semantic Similarity Filtering Validation', () async {
      print('--- STARTING SEMANTIC INTEGRITY SIMULATION ---');

      // Setup cache mock embeddings using debugSetEmbedding
      SemanticFilter.clearCache();
      SemanticFilter.debugSetEmbedding('sleeping in my bed all day', [1.0, 0.0, 0.0]);
      SemanticFilter.debugSetEmbedding('sleep all day in bed', [0.95, 0.1, 0.0]); // Cosine Similarity: 0.95 / (1.0 * sqrt(0.9125)) ~= 0.99
      SemanticFilter.debugSetEmbedding('playing video games', [0.0, 1.0, 0.0]); // Cosine Similarity: 0.0

      // Test highly similar answer rejection
      bool isUniqueDuplicate = await SemanticFilter.isAnswerUnique(
        'sleep all day in bed',
        ['sleeping in my bed all day'],
      );
      expect(isUniqueDuplicate, isFalse);
      print('Verified: Highly similar answer was successfully rejected.');

      // Test unique answer acceptance
      bool isUniqueDifferent = await SemanticFilter.isAnswerUnique(
        'playing video games',
        ['sleeping in my bed all day'],
      );
      expect(isUniqueDifferent, isTrue);
      print('Verified: Unique answer was successfully accepted.');
    });
  });

  group('Wave B Unit Tests', () {
    test('startGame throws descriptive exceptions for invalid player counts and decks', () async {
      final db = FakeFirestore();
      final gs = GameService(db: db, functions: FakeFirebaseFunctions(db));
      SharedPreferences.setMockInitialValues({});

      await gs.createRoom('Host', 'host_user', sabotageAnswersCount: 2);
      await Future.delayed(Duration(milliseconds: 100));
      
      // Should throw for too few active players (< 2)
      expect(
        () => gs.startGame('the_daily_grind'),
        throwsA(isA<Exception>().having((e) => e.toString(), 'message', contains('Need at least 2 active players'))),
      );

      // Add a second player. Total players: 2, sabotageAnswersCount: 2. Need players > sabotageAnswersCount.
      await gs.joinRoom(gs.gameState!.roomCode, 'Player 2', 'player_2');
      await Future.delayed(Duration(milliseconds: 100));
      
      expect(
        () => gs.startGame('the_daily_grind'),
        throwsA(isA<Exception>().having((e) => e.toString(), 'message', contains('Need more players than forgery rounds'))),
      );
    });

    test('host transfer logic promotes earliest joined active player', () async {
      final db = FakeFirestore();
      final gs = GameService(db: db, functions: FakeFirebaseFunctions(db));
      SharedPreferences.setMockInitialValues({});

      // Host joins
      await gs.createRoom('Host', 'host_user', sabotageAnswersCount: 1);
      await Future.delayed(Duration(milliseconds: 100));
      final rCode = gs.gameState!.roomCode;

      // Add other players with different joinedAt values
      final p2 = PlayerState(id: 'player_2', name: 'Player 2', joinedAt: 200);
      final p3 = PlayerState(id: 'player_3', name: 'Player 3', joinedAt: 100); // earlier
      final spec = PlayerState(id: 'spec_1', name: 'Spectator', joinedAt: 50, role: PlayerRole.spectator); // earliest but spectator

      await db.collection('rooms').doc(rCode).collection('players').doc(p2.id).set(p2.toMap());
      await db.collection('rooms').doc(rCode).collection('players').doc(p3.id).set(p3.toMap());
      await db.collection('rooms').doc(rCode).collection('players').doc(spec.id).set(spec.toMap());
      await Future.delayed(Duration(milliseconds: 100));

      // Disconnect host
      await gs.handlePlayerDisconnect('host_user');
      await Future.delayed(Duration(milliseconds: 100));

      // Earliest active (non-spectator) player (player_3) should be promoted
      final newHost = gs.players.firstWhere((p) => p.isHost);
      expect(newHost.id, 'player_3');
    });

    test('tryRejoinSession mismatch clears preferences and returns false', () async {
      final db = FakeFirestore();
      final gs = GameService(db: db, functions: FakeFirebaseFunctions(db));
      // Mock preferences with mismatching player_id
      SharedPreferences.setMockInitialValues({
        'room_code': 'ABCD',
        'player_id': 'saved_player_id_mismatch',
      });

      final result = await gs.tryRejoinSession();
      expect(result, isFalse);
    });

    test('rerollMyPrompt swaps prompt and consumes re-roll token', () async {
      final db = FakeFirestore();
      final gs = GameService(db: db, functions: FakeFirebaseFunctions(db));
      SharedPreferences.setMockInitialValues({});

      // Host joins
      await gs.createRoom('Host', 'host_user', sabotageAnswersCount: 1);
      await Future.delayed(Duration(milliseconds: 100));
      final rCode = gs.gameState!.roomCode;

      // Add second player
      final p2 = PlayerState(id: 'player_2', name: 'Player 2', joinedAt: 100);
      await db.collection('rooms').doc(rCode).collection('players').doc(p2.id).set(p2.toMap());
      await Future.delayed(Duration(milliseconds: 100));

      // Start game
      await gs.startGame('the_daily_grind');
      await Future.delayed(Duration(milliseconds: 100));

      // Advance past sabotage round to truth round
      await gs.setPlayerReady(true, playerId: 'host_user');
      await gs.setPlayerReady(true, playerId: 'player_2');
      await Future.delayed(Duration(milliseconds: 100));

      expect(gs.gameState!.currentPhase, GamePhase.truth);

      // Verify initial prompt
      final originalCard = gs.gameState!.cards.firstWhere((c) => c.targetPlayerId == 'host_user');
      final originalPrompt = originalCard.promptText;

      // Call reroll
      await gs.rerollMyPrompt();
      await Future.delayed(Duration(milliseconds: 100));

      // Verify hasRerolled is true
      expect(gs.currentPlayer!.hasRerolled, isTrue);

      // Verify prompt has changed
      final newCard = gs.gameState!.cards.firstWhere((c) => c.targetPlayerId == 'host_user');
      expect(newCard.promptText, isNot(originalPrompt));

      // Verify subsequent call fails
      expect(() => gs.rerollMyPrompt(), throwsA(isA<Exception>()));
    });
  });
}
