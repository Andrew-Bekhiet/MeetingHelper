import 'package:churchdata_core/churchdata_core.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:meetinghelper/models.dart';

class MHFunctionsService extends FunctionsService {
  Future<void> refreshSupabaseToken() async {
    await httpsCallable('refreshSupabaseToken').call();
  }

  Future<HttpsCallableResult> updateUser({
    required UserWithPerson old,
    required UserWithPerson new$,
    List<User>? childrenUsers,
  }) async {
    try {
      final oldJson = old.userJson();

      return await httpsCallable(
        'updateUser',
      ).call(
        {
          'UID': new$.uid,
          'Changes': {
            ...(new$.userJson()
                  ..removeWhere(
                    (key, value) =>
                        key == 'AllowedUsers' || oldJson[key] == value,
                  ))
                .map(
              (key, value) => MapEntry(
                key,
                value is Set
                    ? value.toList()
                    : key == 'AdminServices'
                        ? (value as List<JsonRef>).map((v) => v.path).toList()
                        : value,
              ),
            ),
            if (old.lastTanawol != new$.lastTanawol)
              'LastTanawol': new$.lastTanawol?.millisecondsSinceEpoch,
            if (old.lastConfession != new$.lastConfession)
              'LastConfession': new$.lastConfession?.millisecondsSinceEpoch,
            if (childrenUsers != null)
              'ChildrenUsers': childrenUsers.map((e) => e.uid).toList(),
          },
        },
      );
    } catch (e) {
      rethrow;
    }
  }
}
