import 'package:churchdata_core/churchdata_core.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:get_it/get_it.dart';
import 'package:meetinghelper/models.dart';

class MHFunctionsService extends FunctionsService {
  static MHFunctionsService get I => GetIt.I<MHFunctionsService>();

  Future<String> dumpImages({Class? class$, Service? service}) async {
    if (class$ == null && service == null) {
      throw ArgumentError.value(
        class$,
        r'class$',
        'You must provide either a class or a service',
      );
    }

    final result = await httpsCallable('dumpImages').call(
      {
        if (class$ != null) 'classId': class$.id,
        if (service != null) 'serviceId': service.id,
      },
    );

    return result.data as String;
  }

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
