import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
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
  Future<T> runTransaction<T>(
    TransactionHandler<T> transactionHandler, {
    Duration timeout = const Duration(seconds: 30),
    int maxAttempts = 5,
  }) async {
    final tx = FakeTransaction(this);
    return await transactionHandler(tx);
  }
}

class FakeCollectionReference extends Fake
    implements CollectionReference<Map<String, dynamic>> {
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
  }) async* {
    if (firestore.data.entries.any((e) => e.key.startsWith('$path/'))) {
      final docs = firestore.data.entries
          .where((e) => e.key.startsWith('$path/'))
          .map((e) => FakeDocumentSnapshot(e.key, Map<String, dynamic>.from(e.value)))
          .toList();
      yield FakeQuerySnapshot(docs);
    }
    final controller = firestore._queryStreams.putIfAbsent(
      path,
      () => StreamController.broadcast(),
    );
    yield* controller.stream;
  }
}

class FakeDocumentReference<T extends Object?> extends Fake
    implements DocumentReference<T> {
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
    return FakeDocumentSnapshot(
      path,
      rawData != null ? Map<String, dynamic>.from(rawData) : null,
    ) as DocumentSnapshot<T>;
  }

  @override
  Stream<DocumentSnapshot<T>> snapshots({
    bool includeMetadataChanges = false,
  }) async* {
    if (firestore.data.containsKey(path)) {
      yield FakeDocumentSnapshot(
        path,
        Map<String, dynamic>.from(firestore.data[path]!),
      ) as DocumentSnapshot<T>;
    }
    final controller = firestore._streams.putIfAbsent(
      path,
      () => StreamController.broadcast(),
    );
    yield* controller.stream as Stream<DocumentSnapshot<T>>;
  }

  void _triggerListeners() {
    if (firestore._streams.containsKey(path)) {
      firestore._streams[path]!.add(
        FakeDocumentSnapshot(
          path,
          Map<String, dynamic>.from(firestore.data[path] ?? {}),
        ),
      );
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

class FakeDocumentSnapshot extends Fake
    implements
        DocumentSnapshot<Map<String, dynamic>>,
        QueryDocumentSnapshot<Map<String, dynamic>> {
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
  DocumentReference<Map<String, dynamic>> get reference =>
      throw UnimplementedError();

  @override
  dynamic operator [](Object field) => _data?[field];

  @override
  dynamic get(Object field) => _data?[field];
}

class FakeQuerySnapshot extends Fake
    implements QuerySnapshot<Map<String, dynamic>> {
  @override
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;

  FakeQuerySnapshot(List<FakeDocumentSnapshot> snapshots) : docs = snapshots;
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
