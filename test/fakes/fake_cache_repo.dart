import 'dart:typed_data';

import 'package:churchdata_core/src/repositories/cache_repo.dart';
import 'package:get_it/get_it.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:hive_flutter/hive_flutter.dart' as h;
import 'package:mockito/mockito.dart';

class FakeCacheRepo extends Fake implements CacheRepository {
  FakeCacheRepo() {
    Future.value().then((_) => GetIt.I.signalReady(this));
  }

  Map<String, BoxBase> boxes = {};

  @override
  Box<E> box<E>(String name) {
    final box = boxes[name];

    if (box != null) {
      return box as Box<E>;
    } else {
      throw HiveError('Box not found. Did you forget to call Hive.openBox()?');
    }
  }

  @override
  Future<bool> boxExists(String name, {String? path}) async {
    return boxes[name] != null;
  }

  @override
  Future<void> close() async {
    await Future.wait(boxes.values.map((box) => box.close()));
  }

  @override
  Future<void> deleteBoxFromDisk(String name, {String? path}) async {
    boxes.remove(name);
  }

  @override
  Future<void> deleteFromDisk() async {
    boxes = {};
  }

  @override
  Future<void> dispose() async {
    await close();
  }

  @override
  List<int> generateSecureKey() {
    return h.Hive.generateSecureKey();
  }

  @override
  void ignoreTypeId<T>(int typeId) {}

  @override
  void init(String path) {}

  @override
  bool isAdapterRegistered(int typeId) {
    return true;
  }

  @override
  bool isBoxOpen(String name) {
    return boxes[name] != null;
  }

  @override
  LazyBox<E> lazyBox<E>(String name) {
    final box = boxes[name];

    if (box != null) {
      return box as LazyBox<E>;
    } else {
      throw HiveError('Box not found. Did you forget to call Hive.openBox()?');
    }
  }

  @override
  Future<Box<E>> openBox<E>(String name,
      {HiveCipher? encryptionCipher,
      KeyComparator keyComparator = defaultKeyComparator,
      CompactionStrategy compactionStrategy = defaultCompactionStrategy,
      bool crashRecovery = true,
      String? path,
      Uint8List? bytes,
      List<int>? encryptionKey}) async {
    return boxes[name] = Box<E>(name);
  }

  @override
  Future<LazyBox<E>> openLazyBox<E>(String name,
      {HiveCipher? encryptionCipher,
      KeyComparator keyComparator = defaultKeyComparator,
      CompactionStrategy compactionStrategy = defaultCompactionStrategy,
      bool crashRecovery = true,
      String? path,
      List<int>? encryptionKey}) async {
    return boxes[name] = LazyBox<E>(name);
  }

  @override
  void registerAdapter<T>(TypeAdapter<T> adapter,
      {bool internal = false, bool override = false}) {}
}

class BoxBase<T> implements h.BoxBase<T> {
  Map<dynamic, T> data = {};

  BoxBase(this.name);

  @override
  Future<int> add(T value) async {
    data[data.length] = value;
    return data.length - 1;
  }

  @override
  Future<Iterable<int>> addAll(Iterable<T> values) async {
    return Future.wait(values.map(add));
  }

  @override
  Future<int> clear() async {
    data = {};
    return 0;
  }

  @override
  Future<void> close() async {}

  @override
  Future<void> compact() async {}

  @override
  bool containsKey(key) {
    return data.containsKey(key);
  }

  @override
  Future<void> delete(key) async {
    data.remove(key);
  }

  @override
  Future<void> deleteAll(Iterable keys) async {
    keys.forEach(delete);
  }

  @override
  Future<void> deleteAt(int index) async {
    data.remove(data.keys.elementAt(index));
  }

  @override
  Future<void> deleteFromDisk() async {
    data = {};
  }

  @override
  Future<void> flush() async {}

  @override
  bool get isEmpty => data.isEmpty;

  @override
  bool get isNotEmpty => data.isNotEmpty;

  @override
  bool get isOpen => true;

  @override
  dynamic keyAt(int index) {
    return data.keys.elementAt(index);
  }

  @override
  Iterable get keys => data.keys;

  @override
  int get length => data.length;

  @override
  final String name;

  @override
  String? get path => null;

  @override
  Future<void> put(key, value) async {
    data[key] = value;
  }

  @override
  Future<void> putAll(Map<dynamic, T> entries) async {
    data.addAll(entries);
  }

  @override
  Future<void> putAt(int index, value) async {
    data[data.keys.elementAt(index)] = value;
  }

  @override
  Stream<BoxEvent> watch({key}) {
    return const Stream.empty();
  }

  @override
  bool get lazy => false;
}

class Box<T> extends BoxBase<T> implements h.Box<T> {
  Box(String name) : super(name);

  @override
  T? get(key, {T? defaultValue}) {
    return super.data[key] ?? defaultValue;
  }

  @override
  T getAt(int index) {
    return super.data.values.elementAt(index);
  }

  @override
  bool get lazy => false;

  @override
  Map<dynamic, T> toMap() {
    return data;
  }

  @override
  Iterable<T> get values => data.values;

  @override
  Iterable<T> valuesBetween({startKey, endKey}) {
    return data.values
        .skip(data.keys.toList().indexOf(startKey))
        .take(data.keys.toList().indexOf(endKey) - data.length);
  }
}

class LazyBox<T> extends BoxBase<T> implements h.LazyBox<T> {
  LazyBox(String name) : super(name);

  @override
  Future<T?> get(key, {T? defaultValue}) async {
    return super.data[key] ?? defaultValue;
  }

  @override
  Future<T> getAt(int index) async {
    return super.data.values.elementAt(index);
  }
}
