import 'dart:async';

import 'package:churchdata_core/churchdata_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart'
    show DocumentReference, SetOptions;
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:meetinghelper/models/meta.dart';
import 'package:meetinghelper/repositories.dart';
import 'package:rxdart/rxdart.dart';

part 'user.g.dart';

@immutable
@CopyWith(copyWithNull: true)
class User extends UserBase implements DataObjectWithPhoto {
  static const String emptyUID = '{EmptyUID}';

  static User get instance => MHAuthRepository.I.currentUser!;
  static ValueStream<User?> get stream => MHAuthRepository.I.userStream;
  static Stream<User> get loggedInStream =>
      MHAuthRepository.I.userStream.whereType<User>();

  final String? password;
  final String? supabaseToken;

  final List<String> allowedUsers;
  final List<JsonRef> adminServices;
  final DateTime? lastTanawol;
  final DateTime? lastConfession;

  @override
  // ignore: overridden_fields
  final MHPermissionsSet permissions;

  @override
  final JsonRef ref;
  final JsonRef? classId;

  User({
    required this.ref,
    required super.name,
    required super.uid,
    this.lastTanawol,
    this.lastConfession,
    this.classId,
    super.email,
    this.password,
    this.supabaseToken,
    this.permissions = const MHPermissionsSet.empty(),
    this.allowedUsers = const [],
    this.adminServices = const [],
  }) : super(permissions: permissions);

  /* User.fromJson(Json data, this.ref)
      : password = null,
        classId = data['ClassId'],
        permissions = MHPermissionsSet.fromJson(data['Permissions'] ?? {}),
        allowedUsers = data['AllowedUsers']?.cast<String>() ?? [],
        adminServices = data['AdminServices']?.cast<JsonRef>() ?? [],
        lastTanawol = (data['LastTanawol'] as Timestamp?)?.toDate(),
  lastConfession = (data['LastConfession'] as Timestamp?)?.toDate(),
        super(
          uid: data['UID'] ?? emptyUID,
          name: data['Name'] ?? '',
          email: data['Email'] ?? '',
        );

  User.fromDoc(JsonDoc data) : this.fromJson(data.data()!, data.reference); */

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
      if (permissions.recordHistory) rslt += 'تسجيل حضور المخدومين';
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

  void reloadImage() {
    photoUrlCache.invalidate();
  }

  @override
  Json toJson() => {
        ...super.toJson(),
        'LastTanawol': lastTanawol,
        'LastConfession': lastConfession,
        'AllowedUsers': allowedUsers,
        'AdminServices': adminServices,
      };

  bool userDataUpToDate() {
    return lastTanawol != null &&
        lastConfession != null &&
        ((lastTanawol!.millisecondsSinceEpoch + 5184000000) >=
                DateTime.now().millisecondsSinceEpoch &&
            (lastConfession!.millisecondsSinceEpoch + 5184000000) >=
                DateTime.now().millisecondsSinceEpoch);
  }

  static Widget photoFromUID(String uid, {bool removeHero = false}) =>
      PhotoObjectWidget(
        SimplePhotoObject(
          GetIt.I<StorageRepository>().ref().child('UsersPhotos/$uid'),
        ),
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
