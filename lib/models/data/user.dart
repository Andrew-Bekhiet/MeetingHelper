import 'dart:async';

import 'package:churchdata_core/churchdata_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart'
    show SetOptions, DocumentReference;
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:meetinghelper/repositories.dart';
import 'package:rxdart/rxdart.dart';

part 'user.g.dart';

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
          lastConfession: DateTime.fromMillisecondsSinceEpoch(
              permissions['lastConfession']),
          lastTanawol:
              DateTime.fromMillisecondsSinceEpoch(permissions['lastTanawol']),
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

@immutable
@CopyWith(copyWithNull: true)
class User extends UserBase implements DataObjectWithPhoto {
  static const String emptyUID = '{EmptyUID}';

  static User get instance => User.instance;
  static ValueStream<User?> get stream => MHAuthRepository.I.userStream;
  static Stream<User> get loggedInStream =>
      MHAuthRepository.I.userStream.whereType<User>();

  final String? password;

  final List<String> allowedUsers;
  final List<JsonRef> adminServices;

  @override
  // ignore: overridden_fields
  final MHPermissionsSet permissions;

  @override
  final JsonRef ref;
  final JsonRef? classId;

  User({
    required this.ref,
    required String uid,
    this.classId,
    String? email,
    this.password,
    required String name,
    this.permissions = const MHPermissionsSet.empty(),
    this.allowedUsers = const [],
    this.adminServices = const [],
  }) : super(uid: uid, name: name, email: email, permissions: permissions);

  User.fromJson(Json data, this.ref)
      : password = null,
        classId = data['ClassId'],
        permissions = MHPermissionsSet.fromJson(data['Permissions'] ?? {}),
        allowedUsers = data['AllowedUsers']?.cast<String>() ?? [],
        adminServices = data['AdminServices']?.cast<JsonRef>() ?? [],
        super(
          uid: data['UID'] ?? emptyUID,
          name: data['Name'] ?? '',
          email: data['Email'] ?? '',
        );

  User.fromDoc(JsonDoc data) : this.fromJson(data.data()!, data.reference);

  @override
  Color? get color => null;

  @override
  IconData get defaultIcon => Icons.account_circle;

  @override
  bool get hasPhoto => true;

  @override
  Reference get photoRef =>
      GetIt.I<StorageRepository>().ref().child('UsersPhotos/$uid');

  String getPermissions() {
    if (permissions.approved) {
      String rslt = '';
      if (permissions.manageUsers) rslt += 'تعديل المستخدمين،';
      if (permissions.manageAllowedUsers) rslt += 'تعديل مستخدمين محددين،';
      if (permissions.superAccess) rslt += 'رؤية جميع البيانات،';
      if (permissions.manageDeleted) rslt += 'استرجاع المحئوفات،';
      if (permissions.secretary) rslt += 'تسجيل حضور الخدام،';
      if (permissions.changeHistory) rslt += 'تعديل كشوفات القديمة';
      if (permissions.export) rslt += 'تصدير فصل،';
      if (permissions.birthdayNotify) rslt += 'اشعار أعياد الميلاد،';
      if (permissions.confessionsNotify) rslt += 'اشعار الاعتراف،';
      if (permissions.tanawolNotify) rslt += 'اشعار التناول،';
      if (permissions.kodasNotify) rslt += 'اشعار القداس';
      if (permissions.meetingNotify) rslt += 'اشعار حضور الاجتماع';
      if (permissions.write) rslt += 'تعديل البيانات،';
      if (permissions.visitNotify) rslt += 'اشعار الافتقاد';
      return rslt;
    }
    return 'غير مُنشط';
  }

  @override
  Future<String> getSecondLine() async => getPermissions();

  Json getUpdateMap() {
    return {
      'name': name,
      'permissions': permissions.toJson(),
    };
  }

  void reloadImage() {
    photoUrlCache.invalidate();
  }

  @override
  Json toJson() => {
        ...super.toJson(),
        'AllowedUsers': allowedUsers,
        'AdminServices': adminServices,
      };

  bool userDataUpToDate() {
    return permissions.lastTanawol != null &&
        permissions.lastConfession != null &&
        ((permissions.lastTanawol!.millisecondsSinceEpoch + 2592000000) >=
                DateTime.now().millisecondsSinceEpoch &&
            (permissions.lastConfession!.millisecondsSinceEpoch + 5184000000) >=
                DateTime.now().millisecondsSinceEpoch);
  }

  static Widget photoFromUID(String uid, {bool removeHero = false}) =>
      PhotoObjectWidget(
        SimplePhotoObject(
            GetIt.I<StorageRepository>().ref().child('UsersPhotos/$uid')),
        heroTag: removeHero ? Object() : null,
      );

  @override
  String get id => ref.id;

  @override
  Future<void> set({Json? merge}) async {
    await ref.set(
      merge ?? toJson(),
      merge != null ? SetOptions(merge: true) : null,
    );
  }

  @override
  Future<void> update({Json old = const {}}) async {
    await ref.update(toJson()..removeWhere((key, value) => old[key] == value));
  }

  Map<String, bool> getNotificationsPermissions() {
    return {
      'birthdayNotify': permissions.permissions.contains('birthdayNotify'),
      'confessionsNotify':
          permissions.permissions.contains('confessionsNotify'),
      'tanawolNotify': permissions.permissions.contains('tanawolNotify'),
      'kodasNotify': permissions.permissions.contains('kodasNotify'),
      'meetingNotify': permissions.permissions.contains('meetingNotify'),
      'visitNotify': permissions.permissions.contains('visitNotify'),
    };
  }
}
