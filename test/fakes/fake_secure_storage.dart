import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';

class FakeFlutterSecureStoragePlatform extends FlutterSecureStoragePlatform {
  Map<String, String> data = {};
  @override
  Future<bool> containsKey({
    required String key,
    required Map<String, String> options,
  }) async {
    return data.containsKey(key);
  }

  @override
  Future<void> delete({
    required String key,
    required Map<String, String> options,
  }) async {
    data.remove(key);
  }

  @override
  Future<void> deleteAll({required Map<String, String> options}) async {
    data.removeWhere((key, value) => true);
  }

  @override
  Future<String?> read({
    required String key,
    required Map<String, String> options,
  }) async {
    return data[key];
  }

  @override
  Future<Map<String, String>> readAll({
    required Map<String, String> options,
  }) async {
    return data;
  }

  @override
  Future<void> write({
    required String key,
    required String value,
    required Map<String, String> options,
  }) async {
    data[key] = value;
  }
}
