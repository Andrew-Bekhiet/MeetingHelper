import 'package:hive/hive.dart';

class HivePersistenceProvider {
  HivePersistenceProvider._();

  static HivePersistenceProvider instance = HivePersistenceProvider._();

  final _box = Hive.box<bool>('FeatureDiscovery');

  Future<void> clearStep(String featureId) async {
    await _box.delete(featureId);
  }

  Future<void> clearSteps(Iterable<String> featuresIds) async {
    await _box.deleteAll(featuresIds);
  }

  Future<void> completeStep(String? featureId) async {
    await _box.put(featureId, true);
  }

  Set<String> completedSteps(Iterable<String?>? featuresIds) {
    return _box
        .toMap()
        .entries
        .where((element) =>
            element.value == true && featuresIds!.contains(element.key))
        .map((e) => e.key)
        .toSet()
        .cast<String>();
  }

  bool hasCompletedStep(String featureId) {
    return _box.get(featureId) ?? false;
  }
}
