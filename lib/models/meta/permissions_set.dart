import 'package:churchdata_core/churchdata_core.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:flutter/foundation.dart';

part 'permissions_set.g.dart';

@immutable
@CopyWith(copyWithNull: true)
class MHPermissionsSet extends PermissionsSet implements Serializable {
  MHPermissionsSet({
    bool superAccess = false,
    bool manageDeleted = false,
    bool write = false,
    bool secretary = false,
    bool recordHistory = false,
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
  }) : this.fromSet(
          permissions: {
            if (superAccess) 'superAccess',
            if (manageDeleted) 'manageDeleted',
            if (write) 'write',
            if (secretary) 'secretary',
            if (recordHistory) 'recordHistory',
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
        );

  const MHPermissionsSet.empty() : this.fromSet();

  MHPermissionsSet.fromJson(Json permissions)
      : this.fromSet(
          permissions: permissions.entries
              .where((kv) => kv.value.toString() == 'true')
              .map((kv) => kv.key)
              .toSet(),
        );

  const MHPermissionsSet.fromSet({
    Set<String> permissions = const <String>{},
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
  bool get recordHistory => permissions.contains('recordHistory');
  bool get superAccess => permissions.contains('superAccess');
  bool get tanawolNotify => permissions.contains('tanawolNotify');

  bool get visitNotify => permissions.contains('visitNotify');
  bool get write => permissions.contains('write');

  @override
  Json toJson() {
    return {
      'approved': approved,
      'birthdayNotify': birthdayNotify,
      'changeHistory': changeHistory,
      'confessionsNotify': confessionsNotify,
      'export': export,
      'kodasNotify': kodasNotify,
      'manageAllowedUsers': manageAllowedUsers,
      'manageDeleted': manageDeleted,
      'manageUsers': manageUsers,
      'meetingNotify': meetingNotify,
      'secretary': secretary,
      'recordHistory': recordHistory,
      'superAccess': superAccess,
      'tanawolNotify': tanawolNotify,
      'visitNotify': visitNotify,
      'write': write,
    };
  }
}
