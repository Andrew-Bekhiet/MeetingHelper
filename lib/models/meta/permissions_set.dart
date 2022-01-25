import 'package:churchdata_core/churchdata_core.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:flutter/foundation.dart';

part 'permissions_set.g.dart';

@immutable
@CopyWith(copyWithNull: true)
class MHPermissionsSet extends PermissionsSet implements Serializable {
  final DateTime? lastConfession;

  final DateTime? lastTanawol;

  MHPermissionsSet({
    bool superAccess = false,
    bool manageDeleted = false,
    bool write = false,
    bool secretary = false,
    bool changeHistory = false,
    bool manageUsers = false,
    bool manageAllowedUsers = false,
    bool export = false,
    bool birthdayNotify = false,
    bool confessionsNotify = false,
    bool tanawolNotify = false,
    bool kodasNotify = false,
    bool meetingNotify = false,
    bool visitNotify = false,
    bool approved = false,
    required DateTime? lastConfession,
    required DateTime? lastTanawol,
  }) : this.fromSet(
          permissions: {
            if (superAccess) 'superAccess',
            if (manageDeleted) 'manageDeleted',
            if (write) 'write',
            if (secretary) 'secretary',
            if (changeHistory) 'changeHistory',
            if (manageUsers) 'manageUsers',
            if (manageAllowedUsers) 'manageAllowedUsers',
            if (export) 'export',
            if (birthdayNotify) 'birthdayNotify',
            if (confessionsNotify) 'confessionsNotify',
            if (tanawolNotify) 'tanawolNotify',
            if (kodasNotify) 'kodasNotify',
            if (meetingNotify) 'meetingNotify',
            if (visitNotify) 'visitNotify',
            if (approved) 'approved',
          },
          lastConfession: lastConfession,
          lastTanawol: lastTanawol,
        );

  const MHPermissionsSet.empty()
      : this.fromSet(lastConfession: null, lastTanawol: null);

  MHPermissionsSet.fromJson(Json permissions)
      : this.fromSet(
          permissions: permissions.entries
              .where((kv) => kv.value.toString() == 'true')
              .map((kv) => kv.key)
              .toSet(),
          lastConfession: permissions['lastConfession']!=null?DateTime.fromMillisecondsSinceEpoch(
              permissions['lastConfession']):null,
          lastTanawol:
              permissions['lastTanawol']!=null?DateTime.fromMillisecondsSinceEpoch(permissions['lastTanawol']):null,
        );
  const MHPermissionsSet.fromSet({
    Set<String> permissions = const <String>{},
    required this.lastConfession,
    required this.lastTanawol,
  }) : super.fromSet(permissions);

  bool get approved => permissions.contains('approved');
  bool get birthdayNotify => permissions.contains('birthdayNotify');
  bool get changeHistory => permissions.contains('changeHistory');
  bool get confessionsNotify => permissions.contains('confessionsNotify');
  bool get export => permissions.contains('export');
  bool get kodasNotify => permissions.contains('kodasNotify');
  bool get manageAllowedUsers => permissions.contains('manageAllowedUsers');
  bool get manageDeleted => permissions.contains('manageDeleted');
  bool get manageUsers => permissions.contains('manageUsers');
  bool get meetingNotify => permissions.contains('meetingNotify');
  bool get secretary => permissions.contains('secretary');
  bool get superAccess => permissions.contains('superAccess');
  bool get tanawolNotify => permissions.contains('tanawolNotify');

  bool get visitNotify => permissions.contains('visitNotify');
  bool get write => permissions.contains('write');

  @override
  Json toJson() {
    return {
      'permissions': permissions,
      'lastConfession': lastConfession?.millisecondsSinceEpoch,
      'lastTanawol': lastTanawol?.millisecondsSinceEpoch,
    };
  }
}
