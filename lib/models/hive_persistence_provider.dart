import 'package:churchdata_core/churchdata_core.dart';
import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';

class HivePersistenceProvider {
  HivePersistenceProvider._();

  static HivePersistenceProvider _instance = HivePersistenceProvider._();

  static HivePersistenceProvider get instance => _instance;

  @visibleForTesting
  static set instance(HivePersistenceProvider instance) => _instance = instance;

  final _box = GetIt.I<CacheRepository>().box<bool>('FeatureDiscovery');

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
        .where(
          (element) => element.value && featuresIds!.contains(element.key),
        )
        .map((e) => e.key)
        .toSet()
        .cast<String>();
  }

  bool hasCompletedStep(String featureId) {
    return _box.get(featureId) ?? false;
  }
}
