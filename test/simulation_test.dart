import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../lib/services/game_service.dart';
import '../lib/models/game_state.dart';
import '../lib/models/player_state.dart';
import '../lib/models/card_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
  Stream<QuerySnapshot<Map<String, dynamic>>> snapshots({bool includeMetadataChanges = false}) async* {
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
  Future<DocumentSnapshot<T>> get([GetOptions? options]) async {
    return FakeDocumentSnapshot(path, Map<String, dynamic>.from(firestore.data[path] ?? {})) as DocumentSnapshot<T>;
  }

  @override
  Stream<DocumentSnapshot<T>> snapshots({bool includeMetadataChanges = false}) async* {
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
      gameService = GameService(db: mockDb);
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
      expect(gameService.gameState!.currentPhase, GamePhase.sabotage);
      print('Game started. Phase: Sabotage Round 1');

      // 4. Sabotage Round 1
      await gameService.setPlayerReady(true); // Host ready
      await gameService.debugSimulateBotResponses();
      await Future.delayed(Duration(milliseconds: 100));
      await gameService.evaluateReadyState(); // Advance manually as host
      await Future.delayed(Duration(milliseconds: 100));
      
      expect(gameService.gameState!.currentRotationIndex, 2);
      print('Phase: Sabotage Round 2');

      // 5. Sabotage Round 2
      await gameService.setPlayerReady(true);
      await gameService.debugSimulateBotResponses();
      await Future.delayed(Duration(milliseconds: 100));
      await gameService.evaluateReadyState();
      await Future.delayed(Duration(milliseconds: 100));
      
      expect(gameService.gameState!.currentPhase, GamePhase.truth);
      print('Phase: Truth Round');

      // 6. Truth Round
      await gameService.setPlayerReady(true);
      await gameService.debugSimulateBotResponses();
      await Future.delayed(Duration(milliseconds: 100));
      await gameService.evaluateReadyState();
      await Future.delayed(Duration(milliseconds: 100));
      
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
        await gameService.evaluateReadyState();
        await Future.delayed(Duration(milliseconds: 100));
        
        expect(gameService.gameState!.currentPhase, GamePhase.reveal);
        
        // Reveal Phase
        await gameService.setPlayerReady(true);
        await gameService.debugSimulateBotResponses();
        await Future.delayed(Duration(milliseconds: 100));
        await gameService.evaluateReadyState();
        await Future.delayed(Duration(milliseconds: 100));
        
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
  });
}
