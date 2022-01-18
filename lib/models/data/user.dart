import 'dart:async';

import 'package:churchdata_core/churchdata_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart' show SetOptions;
import 'package:collection/collection.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:meetinghelper/models/data/person.dart';
import 'package:meetinghelper/utils/globals.dart';
import 'package:rxdart/rxdart.dart';

class MHAuthRepository extends AuthRepository<User, Person> {
  static MHAuthRepository get instance => GetIt.I<MHAuthRepository>();
  static MHAuthRepository get I => instance;

  static Future<User?> userNameFromUID(String uid) async {
    final document =
        await GetIt.I<DatabaseRepository>().collection('Users').doc(uid).get();

    if (document.exists)
      return User(
        ref: document.reference,
        uid: uid,
        name: document.data()?['Name'],
      );

    return null;
  }

  static Future<User?> userFromUID(String? uid) async {
    final user = (await GetIt.I<DatabaseRepository>()
            .collection('UsersData')
            .where('UID', isEqualTo: uid)
            .get())
        .docs
        .singleOrNull;

    if (user == null) return null;

    return User.fromDoc(user);
  }

  static Stream<List<User>> getAllUsers({
    QueryOfJson Function(QueryOfJson, String, bool) queryCompleter =
        kDefaultQueryCompleter,
  }) {
    return GetIt.I<MHAuthRepository>().userStream.switchMap(
      (u) {
        if (u == null) return Stream.value([]);

        if (!u.permissions.manageUsers &&
            !u.permissions.manageAllowedUsers &&
            !u.permissions.secretary)
          return queryCompleter(
                  GetIt.I<DatabaseRepository>().collection('Users'),
                  'Name',
                  false)
              .snapshots()
              .map((p) => p.docs.map(User.fromDoc).toList());
        if (u.permissions.manageUsers || u.permissions.secretary) {
          return queryCompleter(
                  GetIt.I<DatabaseRepository>().collection('UsersData'),
                  'Name',
                  false)
              .snapshots()
              .map((p) => p.docs.map(User.fromDoc).toList());
        } else {
          return queryCompleter(
                  GetIt.I<DatabaseRepository>()
                      .collection('UsersData')
                      .where('AllowedUsers', arrayContains: u.uid),
                  'Name',
                  false)
              .snapshots()
              .map((p) => p.docs.map(User.fromDoc).toList());
        }
      },
    );
  }

  static Stream<List<Person>> getAllUsersData({
    QueryOfJson Function(QueryOfJson, String, bool) queryCompleter =
        kDefaultQueryCompleter,
  }) {
    return GetIt.I<MHAuthRepository>().userStream.switchMap(
      (u) {
        if (u == null) return Stream.value([]);

        if (!u.permissions.manageUsers &&
            !u.permissions.manageAllowedUsers &&
            !u.permissions.secretary)
          throw UnsupportedError('Insuffecient Permissions');

        if (u.permissions.manageUsers || u.permissions.secretary) {
          return queryCompleter(
                  GetIt.I<DatabaseRepository>().collection('UsersData'),
                  'Name',
                  false)
              .snapshots()
              .map(
                (p) => p.docs.map(Person.fromDoc).toList(),
              );
        } else {
          return queryCompleter(
                  GetIt.I<DatabaseRepository>()
                      .collection('UsersData')
                      .where('AllowedUsers', arrayContains: u.uid),
                  'Name',
                  false)
              .snapshots()
              .map(
                (p) => p.docs.map(Person.fromDoc).toList(),
              );
        }
      },
    );
  }

  static Stream<List<User>> getAllNames() {
    return GetIt.I<DatabaseRepository>()
        .collection('Users')
        .orderBy('Name')
        .snapshots()
        .map((p) => p.docs.map(User.fromDoc).toList());
  }

  static Stream<List<User>> getAllSemiManagers(
      [QueryOfJson Function(QueryOfJson, String, bool) queryCompleter =
          kDefaultQueryCompleter]) {
    return GetIt.I<MHAuthRepository>().userStream.switchMap((u) {
      if (u == null) return Stream.value([]);

      if (u.permissions.manageUsers || u.permissions.secretary) {
        return queryCompleter(
                GetIt.I<DatabaseRepository>()
                    .collection('UsersData')
                    .where('Permissions.ManageAllowedUsers', isEqualTo: true),
                'Name',
                false)
            .snapshots()
            .map((p) => p.docs.map(User.fromDoc).toList());
      } else {
        return queryCompleter(
                GetIt.I<DatabaseRepository>()
                    .collection('UsersData')
                    .where('AllowedUsers', arrayContains: u.uid)
                    .where('Permissions.ManageAllowedUsers', isEqualTo: true),
                'Name',
                false)
            .snapshots()
            .map((p) => p.docs.map(User.fromDoc).toList());
      }
    });
  }

  static Future<List<User>> getUsersNames(List<String> users) async {
    return (await Future.wait(users.map(userNameFromUID)))
        .whereNotNull()
        .toList();
  }

  @override
  bool connectionChanged(DatabaseEvent snapshot) {
    final bool connected = super.connectionChanged(snapshot);

    if (connected && (scaffoldMessenger.currentState?.mounted ?? false))
      scaffoldMessenger.currentState!.showSnackBar(
        const SnackBar(
          backgroundColor: Colors.greenAccent,
          content: Text('تم استرجاع الاتصال بالانترنت'),
        ),
      );
    else if (scaffoldMessenger.currentState?.mounted ?? false)
      scaffoldMessenger.currentState!.showSnackBar(
        const SnackBar(
          backgroundColor: Colors.redAccent,
          content: Text('لا يوجد اتصال بالانترنت!'),
        ),
      );
    return connected;
  }

  @override
  MHPermissionsSet permissionsFromIdToken(Json idTokenClaims) =>
      MHPermissionsSet.fromJson(idTokenClaims);

  @override
  User refreshFromIdToken(
    Json idTokenClaims, {
    auth.User? firebaseUser,
    String? uid,
    String? name,
    String? email,
    String? phone,
  }) {
    assert(
        firebaseUser != null || (name != null && uid != null && email != null));

    if (idTokenClaims['personId'] != currentUserData?.ref.id) {
      personListener?.cancel();
      personListener = GetIt.I<DatabaseRepository>()
          .collection('UsersData')
          .doc(idTokenClaims['personId'])
          .snapshots()
          .map((doc) {
        userSubject.add(User(
          ref: doc.reference,
          uid: firebaseUser?.uid ?? uid!,
          name: firebaseUser?.displayName ?? name ?? '',
          email: firebaseUser?.email ?? email!,
          password: idTokenClaims['password'],
          permissions: permissionsFromIdToken(idTokenClaims),
          classId: doc.data()?['ClassId']?.cast<String>() ?? [],
          allowedUsers: doc.data()?['AllowedUsers']?.cast<String>() ?? [],
          adminServices: doc.data()?['AdminServices']?.cast<JsonRef>() ?? [],
        ));
        return Person.fromDoc(doc);
      }).listen(refreshFromDoc);
    } else {
      userSubject.add(User(
        ref: currentUser?.ref ??
            GetIt.I<DatabaseRepository>()
                .collection('UsersData')
                .doc(idTokenClaims['personId'] ?? 'null'),
        uid: firebaseUser?.uid ?? uid!,
        name: firebaseUser?.displayName ?? name ?? '',
        email: firebaseUser?.email ?? email!,
        password: idTokenClaims['password'],
        permissions: permissionsFromIdToken(idTokenClaims),
        classId: currentUser?.classId,
        allowedUsers: currentUser?.allowedUsers ?? [],
        adminServices: currentUser?.adminServices ?? [],
      ));
    }

    connectionListener ??= GetIt.I<FirebaseDatabase>()
        .ref()
        .child('.info/connected')
        .onValue
        .listen(connectionChanged);

    return User(
      ref: currentUser?.ref ??
          GetIt.I<DatabaseRepository>()
              .collection('UsersData')
              .doc(idTokenClaims['personId'] ?? 'null'),
      uid: firebaseUser?.uid ?? uid!,
      name: firebaseUser?.displayName ?? name ?? '',
      email: firebaseUser?.email ?? email!,
      password: idTokenClaims['password'],
      permissions: permissionsFromIdToken(idTokenClaims),
      classId: currentUser?.classId,
      allowedUsers: currentUser?.allowedUsers ?? [],
      adminServices: currentUser?.adminServices ?? [],
    );
  }
}

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

class User extends UserBase implements DataObjectWithPhoto {
  @Deprecated('Use "GetIt.I<MHAuthRepository>().currentUser" or'
      ' "MHAuthRepository.instance.currentUser" instead')
  static User get instance => GetIt.I<MHAuthRepository>().currentUser!;

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
            uid: data['UID'],
            name: data['Name'] ?? '',
            email: data['Email'] ?? '');

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
