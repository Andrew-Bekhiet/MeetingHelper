import 'dart:async';
import 'dart:ui';

import 'package:async/async.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_stream_notifiers/flutter_stream_notifiers.dart';
import 'package:hive/hive.dart';
import 'package:meetinghelper/utils/globals.dart';

import 'super_classes.dart';

class User extends DataObject
    with PhotoObject, ChangeNotifier, ChangeNotifierStream<User> {
  static final User instance = User._initInstance();

  Completer<bool> _initialized = Completer<bool>();

  Future<bool> get initialized => _initialized.future;

  String _uid;

  String get uid => _uid;

  set uid(String uid) {
    _uid = uid;
    if (!_initialized.isCompleted) _initialized.complete(uid != null);
  }

  String email;
  String password;

  String servingStudyYear;
  bool servingStudyGender;

  bool superAccess;
  bool write;
  bool secretary;

  bool manageUsers;
  bool manageAllowedUsers;
  bool exportClasses;
  List<String> allowedUsers = [];

  bool birthdayNotify;
  bool confessionsNotify;
  bool tanawolNotify;
  bool kodasNotify;
  bool meetingNotify;

  bool approveLocations;
  bool approved;

  int lastConfession;
  int lastTanawol;

  DateTime get lastConfessionDate => lastConfession != null
      ? DateTime.fromMillisecondsSinceEpoch(lastConfession)
      : null;
  DateTime get lastTanawolDate => lastTanawol != null
      ? DateTime.fromMillisecondsSinceEpoch(lastTanawol)
      : null;

  StreamSubscription<Event> userTokenListener;
  StreamSubscription<Event> connectionListener;
  StreamSubscription<auth.User> authListener;

  final AsyncCache<String> _photoUrlCache =
      AsyncCache<String>(Duration(days: 1));

  User._initInstance()
      : allowedUsers = [],
        super(null, null, null) {
    hasPhoto = true;
    defaultIcon = Icons.account_circle;
    _initListeners();
  }

  factory User(
      {String uid,
      String name,
      String password,
      bool manageUsers,
      bool manageAllowedUsers,
      bool superAccess,
      bool write,
      bool secretary,
      bool exportClasses,
      bool birthdayNotify,
      bool confessionsNotify,
      bool tanawolNotify,
      bool kodasNotify,
      bool meetingNotify,
      bool approved,
      int lastConfession,
      int lastTanawol,
      String servingStudyYear,
      bool servingStudyGender,
      List<String> allowedUsers,
      String email}) {
    if (uid == null || uid == auth.FirebaseAuth.instance.currentUser.uid) {
      return instance;
    }
    return User._new(
        uid,
        name,
        password,
        manageUsers,
        manageAllowedUsers,
        superAccess,
        write,
        secretary,
        exportClasses,
        birthdayNotify,
        confessionsNotify,
        tanawolNotify,
        kodasNotify,
        meetingNotify,
        approved,
        lastConfession,
        lastTanawol,
        servingStudyYear,
        servingStudyGender,
        allowedUsers,
        email: email);
  }

  User._new(
      this._uid,
      String name,
      this.password,
      this.manageUsers,
      bool manageAllowedUsers,
      this.superAccess,
      this.write,
      this.secretary,
      this.exportClasses,
      this.birthdayNotify,
      this.confessionsNotify,
      this.tanawolNotify,
      this.kodasNotify,
      this.meetingNotify,
      this.approved,
      this.lastConfession,
      this.lastTanawol,
      this.servingStudyYear,
      this.servingStudyGender,
      List<String> allowedUsers,
      {this.email})
      : super(_uid, name, null) {
    hasPhoto = true;
    defaultIcon = Icons.account_circle;
    this.manageAllowedUsers = manageAllowedUsers ?? false;
    this.allowedUsers = allowedUsers ?? [];
  }

  void _initListeners() {
    authListener = auth.FirebaseAuth.instance.userChanges().listen(
      (user) async {
        if (user != null) {
          userTokenListener = FirebaseDatabase.instance
              .reference()
              .child('Users/${user.uid}/forceRefresh')
              .onValue
              .listen((e) async {
            auth.User currentUser = user;
            if (currentUser?.uid == null ||
                e.snapshot == null ||
                e.snapshot.value != true) return;

            Map<dynamic, dynamic> idTokenClaims;
            try {
              var idToken = await currentUser.getIdTokenResult(true);
              for (var item in idToken.claims.entries) {
                await flutterSecureStorage.write(
                    key: item.key, value: item.value?.toString());
              }
              await FirebaseDatabase.instance
                  .reference()
                  .child('Users/${currentUser.uid}/forceRefresh')
                  .set(false);
              connectionListener ??= FirebaseDatabase.instance
                  .reference()
                  .child('.info/connected')
                  .onValue
                  .listen((snapshot) {
                if (snapshot.snapshot.value == true) {
                  FirebaseDatabase.instance
                      .reference()
                      .child('Users/${user.uid}/lastSeen')
                      .onDisconnect()
                      .set(ServerValue.timestamp);
                  FirebaseDatabase.instance
                      .reference()
                      .child('Users/${user.uid}/lastSeen')
                      .set('Active');
                }
              });
              idTokenClaims = idToken.claims;
            } on Exception {
              idTokenClaims = await flutterSecureStorage.readAll();
              if (idTokenClaims?.isEmpty ?? true) rethrow;
            }
            uid = user.uid;
            name = user.displayName;
            password = idTokenClaims['password'];
            manageUsers = idTokenClaims['manageUsers'].toString() == 'true';
            manageAllowedUsers =
                idTokenClaims['manageAllowedUsers'].toString() == 'true';
            superAccess = idTokenClaims['superAccess'].toString() == 'true';
            write = idTokenClaims['write'].toString() == 'true';
            secretary = idTokenClaims['secretary'].toString() == 'true';
            exportClasses = idTokenClaims['exportClasses'].toString() == 'true';
            birthdayNotify =
                idTokenClaims['birthdayNotify'].toString() == 'true';
            confessionsNotify =
                idTokenClaims['confessionsNotify'].toString() == 'true';
            tanawolNotify = idTokenClaims['tanawolNotify'].toString() == 'true';
            kodasNotify = idTokenClaims['kodasNotify'].toString() == 'true';
            meetingNotify = idTokenClaims['meetingNotify'].toString() == 'true';
            approveLocations =
                idTokenClaims['approveLocations'].toString() == 'true';
            approved = idTokenClaims['approved'].toString() == 'true';
            lastConfession = idTokenClaims['lastConfession'] != null
                ? int.parse(idTokenClaims['lastConfession'].toString())
                : null;
            lastTanawol = idTokenClaims['lastTanawol'] != null
                ? int.parse(idTokenClaims['lastTanawol'].toString())
                : null;
            servingStudyYear = idTokenClaims['servingStudyYear'].toString();
            servingStudyGender =
                idTokenClaims['servingStudyGender'].toString() == 'true';
            email = user.email;

            notifyListeners();
          });
          Map<dynamic, dynamic> idTokenClaims;
          try {
            var idToken;
            if ((await Connectivity().checkConnectivity()) !=
                ConnectivityResult.none) {
              idToken = await user.getIdTokenResult();
              for (var item in idToken.claims.entries) {
                await flutterSecureStorage.write(
                    key: item.key, value: item.value?.toString());
              }
              await FirebaseDatabase.instance
                  .reference()
                  .child('Users/${user.uid}/forceRefresh')
                  .set(false);
            }
            connectionListener ??= FirebaseDatabase.instance
                .reference()
                .child('.info/connected')
                .onValue
                .listen((snapshot) {
              if (snapshot.snapshot.value == true) {
                FirebaseDatabase.instance
                    .reference()
                    .child('Users/${user.uid}/lastSeen')
                    .onDisconnect()
                    .set(ServerValue.timestamp);
                FirebaseDatabase.instance
                    .reference()
                    .child('Users/${user.uid}/lastSeen')
                    .set('Active');
              }
            });
            idTokenClaims =
                idToken?.claims ?? await flutterSecureStorage.readAll();
          } on Exception {
            idTokenClaims = await flutterSecureStorage.readAll();
            if (idTokenClaims?.isEmpty ?? true) rethrow;
          }
          uid = user.uid;
          name = user.displayName;
          password = idTokenClaims['password'];
          manageUsers = idTokenClaims['manageUsers'].toString() == 'true';
          manageAllowedUsers =
              idTokenClaims['manageAllowedUsers'].toString() == 'true';
          superAccess = idTokenClaims['superAccess'].toString() == 'true';
          write = idTokenClaims['write'].toString() == 'true';
          secretary = idTokenClaims['secretary'].toString() == 'true';
          exportClasses = idTokenClaims['exportClasses'].toString() == 'true';
          birthdayNotify = idTokenClaims['birthdayNotify'].toString() == 'true';
          confessionsNotify =
              idTokenClaims['confessionsNotify'].toString() == 'true';
          tanawolNotify = idTokenClaims['tanawolNotify'].toString() == 'true';
          kodasNotify = idTokenClaims['kodasNotify'].toString() == 'true';
          meetingNotify = idTokenClaims['meetingNotify'].toString() == 'true';
          approveLocations =
              idTokenClaims['approveLocations'].toString() == 'true';
          approved = idTokenClaims['approved'].toString() == 'true';
          lastConfession = idTokenClaims['lastConfession'] != null
              ? int.parse(idTokenClaims['lastConfession'].toString())
              : null;
          lastTanawol = idTokenClaims['lastTanawol'] != null
              ? int.parse(idTokenClaims['lastTanawol'].toString())
              : null;
          servingStudyYear = idTokenClaims['servingStudyYear'].toString();
          servingStudyGender =
              idTokenClaims['servingStudyGender'].toString() == 'true';
          email = user.email;
          notifyListeners();
        } else if (uid != null) {
          if (!_initialized.isCompleted) _initialized.complete(false);
          _initialized = Completer<bool>();
          await userTokenListener?.cancel();
          uid = null;
          notifyListeners();
        }
      },
    );
  }

  Future<void> signOut() async {
    await recordLastSeen();
    await userTokenListener?.cancel();
    if (!_initialized.isCompleted) _initialized.complete(false);
    _initialized = Completer<bool>();
    uid = null;
    notifyListeners();
    await auth.FirebaseAuth.instance.signOut();
    await connectionListener?.cancel();
  }

  User._createFromData(this._uid, Map<String, dynamic> data)
      : super.createFromData(data, _uid) {
    name = data['Name'] ?? data['name'];
    uid = data['uid'] ?? _uid;
    password = data['password'];
    manageUsers = data['manageUsers'];
    manageAllowedUsers = data['manageAllowedUsers'];
    allowedUsers = data['allowedUsers']?.cast<String>();
    superAccess = data['superAccess'];
    write = data['write'];
    secretary = data['secretary'];
    exportClasses = data['exportClasses'];
    birthdayNotify = data['birthdayNotify'];
    confessionsNotify = data['confessionsNotify'];
    tanawolNotify = data['tanawolNotify'];
    kodasNotify = data['kodasNotify'];
    meetingNotify = data['meetingNotify'];
    approved = data['approved'];
    lastConfession = data['lastConfession'];
    lastTanawol = data['lastTanawol'];
    servingStudyYear = data['servingStudyYear'];
    servingStudyGender = data['servingStudyGender'];
    email = data['email'];
    hasPhoto = true;
    defaultIcon = Icons.account_circle;
  }

  @override
  Color get color => Colors.transparent;

  @override
  int get hashCode => hashValues(
      uid,
      name,
      password,
      manageUsers,
      manageAllowedUsers,
      superAccess,
      write,
      secretary,
      exportClasses,
      birthdayNotify,
      confessionsNotify,
      tanawolNotify,
      kodasNotify,
      meetingNotify,
      approved,
      lastConfession,
      lastTanawol,
      servingStudyYear,
      servingStudyGender,
      email);

  DocumentReference get servingStudyYearRef => servingStudyYear == null
      ? null
      : FirebaseFirestore.instance.doc('StudyYears/$servingStudyYear');

  @override
  bool operator ==(other) {
    return other is User && other.uid == uid;
  }

  @override
  Future dispose() async {
    await recordLastSeen();
    await userTokenListener?.cancel();
    await connectionListener?.cancel();
    await authListener?.cancel();
    await super.dispose();
  }

  Map<String, bool> getNotificationsPermissions() => {
        'birthdayNotify': birthdayNotify ?? false,
        'confessionsNotify': confessionsNotify ?? false,
        'tanawolNotify': tanawolNotify ?? false,
        'kodasNotify': kodasNotify ?? false,
        'meetingNotify': meetingNotify ?? false,
      };

  String getPermissions() {
    if (approved ?? false) {
      String permissions = '';
      if (manageUsers ?? false) permissions += 'تعديل المستخدمين،';
      if (manageAllowedUsers ?? false) permissions += 'تعديل مستخدمين محددين،';
      if (superAccess ?? false) permissions += 'رؤية جميع البيانات،';
      if (secretary ?? false) permissions += 'تسجيل حضور الخدام،';
      if (exportClasses ?? false) permissions += 'تصدير فصل،';
      if (approveLocations ?? false) permissions += 'تأكيد المواقع،';
      if (birthdayNotify ?? false) permissions += 'اشعار أعياد الميلاد،';
      if (confessionsNotify ?? false) permissions += 'اشعار الاعتراف،';
      if (tanawolNotify ?? false) permissions += 'اشعار التناول،';
      if (kodasNotify ?? false) permissions += 'اشعار القداس';
      if (meetingNotify ?? false) permissions += 'اشعار حضور الاجتماع';
      if (write ?? false) permissions += 'تعديل البيانات،';
      return permissions;
    }
    return 'غير مُنشط';
  }

  Widget getPhoto([bool showCircle = true, bool showActiveStatus = true]) {
    return AspectRatio(
      aspectRatio: 1,
      child: StreamBuilder(
        stream: FirebaseDatabase.instance
            .reference()
            .child('Users/$uid/lastSeen')
            .onValue,
        builder: (context, activity) {
          if (!hasPhoto)
            return Stack(
              children: [
                Positioned.fill(
                    child: Icon(Icons.account_circle,
                        size: MediaQuery.of(context).size.height / 16.56)),
                if (showActiveStatus &&
                    activity.data?.snapshot?.value == 'Active')
                  Align(
                    alignment: Alignment.bottomLeft,
                    child: Container(
                      height: 15,
                      width: 15,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: Colors.white),
                        color: Colors.greenAccent,
                      ),
                    ),
                  ),
              ],
            );
          return StatefulBuilder(
            builder: (context, setState) => FutureBuilder<String>(
              future: _photoUrlCache.fetch(
                () async {
                  String cache = Hive.box<String>('PhotosURLsCache')
                      .get(photoRef.fullPath);

                  if (cache == null) {
                    String url = await photoRef
                        .getDownloadURL()
                        .catchError((onError) => '');
                    await Hive.box<String>('PhotosURLsCache')
                        .put(photoRef.fullPath, url);

                    return url;
                  }
                  void Function(String) _updateCache = (String cache) async {
                    String url = await photoRef
                        .getDownloadURL()
                        .catchError((onError) => '');
                    if (cache != url) {
                      await Hive.box<String>('PhotosURLsCache')
                          .put(photoRef.fullPath, url);
                      _photoUrlCache.invalidate();
                      setState(() {});
                    }
                  };
                  _updateCache(cache);
                  return cache;
                },
              ),
              builder: (context, photoUrl) {
                return Stack(
                  children: [
                    Positioned.fill(
                      child: photoUrl.hasData
                          ? showCircle
                              ? CircleAvatar(
                                  backgroundImage:
                                      CachedNetworkImageProvider(photoUrl.data),
                                )
                              : CachedNetworkImage(imageUrl: photoUrl.data)
                          : CircularProgressIndicator(),
                    ),
                    if (showActiveStatus &&
                        activity.data?.snapshot?.value == 'Active')
                      Align(
                        alignment: Alignment.bottomLeft,
                        child: Container(
                          height: 15,
                          width: 15,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(color: Colors.white),
                            color: Colors.greenAccent,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }

  @override
  Future<String> getSecondLine() async => getPermissions();

  Future<String> getStudyYearName() async {
    var tmp = (await servingStudyYearRef?.get(dataSource))?.data();
    if (tmp == null) return '';
    return tmp['Name'] ?? 'لا يوجد';
  }

  Map<String, dynamic> getUpdateMap() {
    return {
      'name': name,
      'manageUsers': manageUsers,
      'manageAllowedUsers': manageAllowedUsers,
      'superAccess': superAccess,
      'write': write,
      'secretary': secretary,
      'exportClasses': exportClasses,
      'approveLocations': approveLocations,
      'birthdayNotify': birthdayNotify,
      'confessionsNotify': confessionsNotify,
      'tanawolNotify': tanawolNotify,
      'kodasNotify': kodasNotify,
      'meetingNotify': meetingNotify,
      'approved': approved,
      'lastConfession': lastConfession,
      'lastTanawol': lastTanawol,
      'servingStudyYear': servingStudyYear,
      'servingStudyGender': servingStudyGender,
      'allowedUsers': allowedUsers ?? [],
    };
  }

  static User fromDoc(DocumentSnapshot data) =>
      User._createFromData(data.id, data.data());

  static Future<User> fromID(String uid) async {
    return (await User.getUsersForEdit()).singleWhere((u) => u.uid == uid);
  }

  static Future<QuerySnapshot> getAllUsersLive() {
    return FirebaseFirestore.instance
        .collection('Users')
        .orderBy('Name')
        .get(dataSource);
  }

  /* static Future<User> getCurrentUser(
      {bool checkForForceRefresh = true, bool fromCache = false}) async {
    auth.User currentUser = auth.FirebaseAuth.instance.currentUser;
    if (currentUser?.uid == null) return User._initInstance();

    Map<dynamic, dynamic> idTokenClaims;
    try {
      if (await Connectivity().checkConnectivity() != ConnectivityResult.none &&
          !fromCache) {
        var idToken = await currentUser.getIdTokenResult();
        if ((checkForForceRefresh &&
                (await FirebaseDatabase.instance
                            .reference()
                            .child('Users/${currentUser.uid}/forceRefresh')
                            .once())
                        .value ==
                    true) ||
            (await flutterSecureStorage.readAll()).isEmpty) {
          idToken = await currentUser.getIdTokenResult(true);
          for (var item in idToken.claims.entries) {
            await flutterSecureStorage.write(
                key: item.key, value: item.value?.toString());
          }
          await FirebaseDatabase.instance
              .reference()
              .child('Users/${currentUser.uid}/forceRefresh')
              .set(false);
        }
        idTokenClaims = idToken.claims;
      } else {
        idTokenClaims = await flutterSecureStorage.readAll();
        if (idTokenClaims?.isEmpty ?? true)
          throw Exception("Couldn't find User cache");
      }
    } on Exception {
      idTokenClaims = await flutterSecureStorage.readAll();
      if (idTokenClaims?.isEmpty ?? true) rethrow;
    }
    instance
      ..uid = currentUser.uid
      ..name = currentUser.displayName
      ..password = idTokenClaims['password']
      ..manageUsers = idTokenClaims['manageUsers'].toString() == 'true'
      ..superAccess = idTokenClaims['superAccess'].toString() == 'true'
      ..write = idTokenClaims['write'].toString() == 'true'
      ..secretary = idTokenClaims['secretary'].toString() == 'true'
      ..exportClasses = idTokenClaims['exportClasses'].toString() == 'true'
      ..birthdayNotify = idTokenClaims['birthdayNotify'].toString() == 'true'
      ..confessionsNotify =
          idTokenClaims['confessionsNotify'].toString() == 'true'
      ..tanawolNotify = idTokenClaims['tanawolNotify'].toString() == 'true'
      ..kodasNotify = idTokenClaims['kodasNotify'].toString() == 'true'
      ..meetingNotify = idTokenClaims['meetingNotify'].toString() == 'true'
      ..approveLocations =
          idTokenClaims['approveLocations'].toString() == 'true'
      ..approved = idTokenClaims['approved'].toString() == 'true'
      ..lastConfession = idTokenClaims['lastConfession'] != null
          ? int.parse(idTokenClaims['lastConfession'].toString())
          : null
      ..lastTanawol = idTokenClaims['lastTanawol'] != null
          ? int.parse(idTokenClaims['lastTanawol'].toString())
          : null
      ..servingStudyYear = idTokenClaims['servingStudyYear'].toString()
      ..servingStudyGender =
          idTokenClaims['servingStudyGender'].toString() == 'true'
      ..email = currentUser.email;
    instance.notifyListeners();
    return instance;
  } */

  static Future<List<User>> getUsers(List<String> users) async {
    return (await Future.wait(users.map((s) => FirebaseFirestore.instance
            .collection('Users')
            .doc(s)
            .get(dataSource))))
        .map((e) => User.fromDoc(e))
        .toList();
  }

  static Future<List<User>> getUsersForEdit() async {
    final users = {
      for (var u in (await User.getAllUsersLive()).docs)
        u.id: (u.data()['allowedUsers'] as List)?.cast<String>()
    };
    return (await FirebaseFunctions.instance.httpsCallable('getUsers').call())
        .data
        .map((u) => User(
            uid: u['uid'],
            name: u['name'],
            password: u['password'],
            manageUsers: u['manageUsers'],
            manageAllowedUsers: u['manageAllowedUsers'],
            superAccess: u['superAccess'],
            write: u['write'],
            secretary: u['secretary'],
            exportClasses: u['exportClasses'],
            birthdayNotify: u['birthdayNotify'],
            confessionsNotify: u['confessionsNotify'],
            tanawolNotify: u['tanawolNotify'],
            kodasNotify: u['kodasNotify'],
            meetingNotify: u['meetingNotify'],
            approved: u['approved'],
            lastConfession: u['lastConfession'],
            lastTanawol: u['lastTanawol'],
            servingStudyYear: u['servingStudyYear'],
            servingStudyGender: u['servingStudyGender'],
            email: u['email'],
            allowedUsers: users[u['uid']]))
        .toList()
        ?.cast<User>();
  }

  Future<void> recordActive() async {
    if (uid == null) return;
    await FirebaseDatabase.instance
        .reference()
        .child('Users/$uid/lastSeen')
        .set('Active');
  }

  Future<void> recordLastSeen() async {
    if (uid == null) return;
    await FirebaseDatabase.instance
        .reference()
        .child('Users/$uid/lastSeen')
        .set(Timestamp.now().millisecondsSinceEpoch);
  }

  Future<bool> userDataUpToDate() async {
    return lastTanawol != null &&
        lastConfession != null &&
        ((lastTanawol + 2592000000) >= DateTime.now().millisecondsSinceEpoch &&
            (lastConfession + 5184000000) >=
                DateTime.now().millisecondsSinceEpoch);
  }

  @override
  Map<String, dynamic> getHumanReadableMap() {
    throw UnimplementedError();
  }

  @override
  Map<String, dynamic> getMap() {
    return getUpdateMap();
  }

  @override
  DocumentReference get ref =>
      FirebaseFirestore.instance.collection('Users').doc(uid);

  @override
  Reference get photoRef =>
      FirebaseStorage.instance.ref().child('UsersPhotos/$uid');

  void reloadImage() {
    _photoUrlCache.invalidate();
  }

  static Future<List<User>> getAllSemiManagers() async {
    return (await getUsersForEdit())
        .where((u) => u.manageAllowedUsers == true)
        .toList();
  }

  static Future<String> onlyName(String id) async {
    return (await FirebaseFirestore.instance
            .collection('Users')
            .doc(id)
            .get(dataSource))
        .data()['Name'];
  }
}
