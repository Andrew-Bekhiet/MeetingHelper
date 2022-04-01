import 'package:firebase_database/firebase_database.dart';

class FakeOnDisconnect implements OnDisconnect {
  @override
  Future<void> cancel() async {}

  @override
  Future<void> remove() async {}

  @override
  Future<void> set(Object? value) async {}

  @override
  Future<void> setWithPriority(Object? value, Object? priority) async {}

  @override
  Future<void> update(Map<String, Object?> value) async {}
}
