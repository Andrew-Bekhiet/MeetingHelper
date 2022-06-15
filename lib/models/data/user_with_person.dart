import 'package:churchdata_core/churchdata_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart' show DocumentReference;
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:meetinghelper/models.dart';

part 'user_with_person.g.dart';

@CopyWith(copyWithNull: true)
class UserWithPerson extends Person implements User {
  @override
  final String uid;
  @override
  final String? email;
  @override
  final MHPermissionsSet permissions;
  @override
  final String? password;
  @override
  String? get supabaseToken => null;

  @override
  final List<String> allowedUsers;
  @override
  final List<JsonRef> adminServices;

  UserWithPerson({
    required super.ref,
    required this.uid,
    required this.permissions,
    required this.allowedUsers,
    required this.adminServices,
    this.email,
    this.password,
    super.classId,
    super.name,
    super.phone,
    super.phones,
    super.fatherPhone,
    super.motherPhone,
    super.address,
    super.location,
    super.hasPhoto,
    super.birthDate,
    super.lastTanawol,
    super.lastConfession,
    super.lastKodas,
    super.lastMeeting,
    super.lastCall,
    super.lastVisit,
    super.lastEdit,
    super.notes,
    super.school,
    super.college,
    super.church,
    super.cFather,
    super.isShammas,
    super.gender,
    super.shammasLevel,
    super.studyYear,
    super.services,
    super.last,
    super.color,
  });

  UserWithPerson.fromDoc(JsonDoc doc)
      : this.fromJson(doc.data()!, doc.reference);

  UserWithPerson.fromJson(super.json, super.ref)
      : password = null,
        permissions = MHPermissionsSet.fromJson(
          {
            ...(json['Permissions'] as Map?)?.cast<String, dynamic>().map(
                      (key, value) => MapEntry(
                        key[0].toLowerCase() + key.substring(1, key.length),
                        value,
                      ),
                    ) ??
                {},
          },
        ),
        allowedUsers = json['AllowedUsers']?.cast<String>() ?? [],
        adminServices = json['AdminServices']?.cast<JsonRef>() ?? [],
        uid = json['UID'] ?? User.emptyUID,
        email = json['Email'] ?? '',
        super.fromJson();

  @override
  IconData get defaultIcon => Icons.account_circle;

  @override
  bool get hasPhoto => true;

  @override
  Reference get photoRef =>
      GetIt.I<StorageRepository>().ref().child('UsersPhotos/$uid');

  @override
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

  @override
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

  @override
  void reloadImage() {
    photoUrlCache.invalidate();
  }

  @override
  bool userDataUpToDate() {
    return lastTanawol != null &&
        lastConfession != null &&
        ((lastTanawol!.millisecondsSinceEpoch + 5184000000) >=
                DateTime.now().millisecondsSinceEpoch &&
            (lastConfession!.millisecondsSinceEpoch + 5184000000) >=
                DateTime.now().millisecondsSinceEpoch);
  }

  @Deprecated('Use personJson() or userJson() instead')
  @override
  Json toJson() => super.toJson();

  Json personJson() {
    return super.toJson();
  }

  Json userJson() {
    return {
      'Name': name,
      'Email': email,
      'Phone': phone,
      'Permissions': permissions.permissions,
      'AllowedUsers': allowedUsers,
      'AdminServices': adminServices,
    };
  }
}
