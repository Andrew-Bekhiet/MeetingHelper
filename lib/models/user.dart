import 'dart:async';
import 'dart:ui';

import 'package:async/async.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_stream_notifiers/flutter_stream_notifiers.dart';
import 'package:hive/hive.dart';
import 'package:meetinghelper/models/class.dart';
import 'package:rxdart/rxdart.dart';
import 'package:meetinghelper/utils/globals.dart';
import 'package:meetinghelper/utils/helpers.dart';
import 'package:meetinghelper/models/person.dart';

class User extends Person with ChangeNotifier, ChangeNotifierStream<User> {
  static final User instance = User._initInstance();

  Completer<bool> _initialized = Completer<bool>();

  Future<bool> get initialized => _initialized.future;

  @override
  bool get hasPhoto => uid != null;

  @override
  set hasPhoto(bool _) {}

  String _uid;

  String get uid => _uid;

  set uid(String uid) {
    _uid = uid;
    if (!_initialized.isCompleted) _initialized.complete(uid != null);
  }

  String email;
  String password;

  bool superAccess;
  bool manageDeleted;
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

  bool approved;

  DateTime get lastConfessionDate => lastConfession?.toDate();
  DateTime get lastTanawolDate => lastTanawol?.toDate();

  StreamSubscription<Event> userTokenListener;
  StreamSubscription<Event> connectionListener;
  StreamSubscription<DocumentSnapshot> personListener;
  StreamSubscription<auth.User> authListener;

  final AsyncCache<String> _photoUrlCache =
      AsyncCache<String>(Duration(days: 1));

  User._initInstance()
      : allowedUsers = [],
        super() {
    defaultIcon = Icons.account_circle;
    _initListeners();
  }

  factory User(
      {DocumentReference ref,
      String uid,
      String name,
      String password,
      bool manageUsers,
      bool manageAllowedUsers,
      bool manageDeleted,
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
      Timestamp lastConfession,
      Timestamp lastTanawol,
      String servingStudyYear,
      bool servingStudyGender,
      List<String> allowedUsers,
      String email}) {
    if (uid == auth.FirebaseAuth.instance.currentUser.uid) {
      return instance;
    }
    return User._new(
      ref: ref,
      uid: uid,
      name: name,
      password: password,
      manageUsers: manageUsers,
      manageAllowedUsers: manageAllowedUsers,
      superAccess: superAccess,
      manageDeleted: manageDeleted,
      write: write,
      secretary: secretary,
      exportClasses: exportClasses,
      birthdayNotify: birthdayNotify,
      confessionsNotify: confessionsNotify,
      tanawolNotify: tanawolNotify,
      kodasNotify: kodasNotify,
      meetingNotify: meetingNotify,
      approved: approved,
      lastConfession: lastConfession,
      lastTanawol: lastTanawol,
      allowedUsers: allowedUsers,
      email: email,
    );
  }

  User._new(
      {String uid,
      String id,
      String name,
      this.password,
      this.manageUsers,
      bool manageAllowedUsers,
      this.superAccess,
      this.manageDeleted,
      this.write,
      this.secretary,
      this.exportClasses,
      this.birthdayNotify,
      this.confessionsNotify,
      this.tanawolNotify,
      this.kodasNotify,
      this.meetingNotify,
      this.approved,
      Timestamp lastConfession,
      Timestamp lastTanawol,
      List<String> allowedUsers,
      this.email,
      DocumentReference ref,
      DocumentReference classId,
      String phone,
      Map<String, dynamic> phones,
      String fatherPhone,
      String motherPhone,
      String address,
      GeoPoint location,
      Timestamp birthDate,
      Timestamp lastKodas,
      Timestamp lastMeeting,
      Timestamp lastCall,
      Timestamp lastVisit,
      String lastEdit,
      String notes,
      DocumentReference school,
      DocumentReference church,
      DocumentReference cFather,
      Color color = Colors.transparent})
      : _uid = uid,
        super(
          ref: ref ??
              FirebaseFirestore.instance
                  .collection('UsersData')
                  .doc(id ?? 'null'),
          name: name,
          classId: classId,
          phone: phone,
          phones: phones,
          fatherPhone: fatherPhone,
          motherPhone: motherPhone,
          address: address,
          location: location,
          birthDate: birthDate,
          lastTanawol: lastTanawol,
          lastConfession: lastConfession,
          lastKodas: lastKodas,
          lastMeeting: lastMeeting,
          lastCall: lastCall,
          lastVisit: lastVisit,
          lastEdit: lastEdit,
          notes: notes,
          school: school,
          church: church,
          cFather: cFather,
          color: color,
        ) {
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
            _refreshFromIdToken(user, idTokenClaims);
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

          _refreshFromIdToken(user, idTokenClaims);
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

  void _refreshFromIdToken(
      auth.User user, Map<dynamic, dynamic> idTokenClaims) {
    uid = user.uid;
    name = user.displayName;
    if (idTokenClaims['personId'] != ref.id) {
      ref = FirebaseFirestore.instance
          .collection('UsersData')
          .doc(idTokenClaims['personId']);
      personListener?.cancel();
      personListener = ref.snapshots().listen(_refreshFromDoc);
    }

    password = idTokenClaims['password'];
    manageUsers = idTokenClaims['manageUsers'].toString() == 'true';
    manageAllowedUsers =
        idTokenClaims['manageAllowedUsers'].toString() == 'true';
    superAccess = idTokenClaims['superAccess'].toString() == 'true';
    manageDeleted = idTokenClaims['manageDeleted'].toString() == 'true';
    write = idTokenClaims['write'].toString() == 'true';
    secretary = idTokenClaims['secretary'].toString() == 'true';
    exportClasses = idTokenClaims['exportClasses'].toString() == 'true';
    birthdayNotify = idTokenClaims['birthdayNotify'].toString() == 'true';
    confessionsNotify = idTokenClaims['confessionsNotify'].toString() == 'true';
    tanawolNotify = idTokenClaims['tanawolNotify'].toString() == 'true';
    kodasNotify = idTokenClaims['kodasNotify'].toString() == 'true';
    meetingNotify = idTokenClaims['meetingNotify'].toString() == 'true';
    approved = idTokenClaims['approved'].toString() == 'true';

    lastConfession = idTokenClaims['lastConfession'] != null
        ? Timestamp.fromMillisecondsSinceEpoch(
            int.parse(idTokenClaims['lastConfession'].toString()))
        : null;
    lastTanawol = idTokenClaims['lastTanawol'] != null
        ? Timestamp.fromMillisecondsSinceEpoch(
            int.parse(idTokenClaims['lastTanawol'].toString()))
        : null;
    email = user.email;

    notifyListeners();
  }

  void _refreshFromDoc(DocumentSnapshot doc) {
    final data = doc.data();
    classId = data['ClassId'];

    phone = data['Phone'];
    fatherPhone = data['FatherPhone'];
    motherPhone = data['MotherPhone'];
    phones = data['Phones']?.cast<String, dynamic>() ?? {};

    address = data['Address'];
    location = data['Location'];

    birthDate = data['BirthDate'];
    lastKodas = data['LastKodas'];
    lastMeeting = data['LastMeeting'];
    lastCall = data['LastCall'];

    lastVisit = data['LastVisit'];
    lastEdit = '';

    notes = data['Notes'];

    school = data['School'];
    church = data['Church'];
    cFather = data['CFather'];

    allowedUsers = data['AllowedUsers']?.cast<String>() ?? [];

    notifyListeners();
  }

  Future<void> signOut() async {
    await recordLastSeen();
    await userTokenListener?.cancel();
    await personListener?.cancel();
    if (!_initialized.isCompleted) _initialized.complete(false);
    _initialized = Completer<bool>();
    uid = null;
    notifyListeners();
    await auth.FirebaseAuth.instance.signOut();
    await connectionListener?.cancel();
  }

  User._createFromData(Map<String, dynamic> data, DocumentReference ref)
      : super.createFromData(data, ref) {
    _uid = data['UID'];
    email = data['Email'];

    final permissions = data['Permissions'] ?? {};
    allowedUsers = data['AllowedUsers']?.cast<String>() ?? [];
    manageUsers = permissions['ManageUsers'] ?? false;
    manageAllowedUsers = permissions['ManageAllowedUsers'] ?? false;
    superAccess = permissions['SuperAccess'] ?? false;
    manageDeleted = permissions['ManageDeleted'] ?? false;
    write = permissions['Write'] ?? false;
    secretary = permissions['Secretary'] ?? false;
    exportClasses = permissions['ExportClasses'] ?? false;
    birthdayNotify = permissions['BirthdayNotify'] ?? false;
    confessionsNotify = permissions['ConfessionsNotify'] ?? false;
    tanawolNotify = permissions['TanawolNotify'] ?? false;
    kodasNotify = permissions['KodasNotify'] ?? false;
    meetingNotify = permissions['MeetingNotify'] ?? false;
    approved = permissions['Approved'] ?? false;

    defaultIcon = Icons.account_circle;
  }

  @override
  Color get color => Colors.transparent;

  @override
  int get hashCode =>
      hashValues(
          email,
          uid,
          name,
          password,
          manageUsers,
          manageAllowedUsers,
          superAccess,
          manageDeleted,
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
          lastTanawol) ^
      super.hashCode;

  @override
  bool operator ==(other) {
    return other is User && other.uid == uid;
  }

  @override
  Future dispose() async {
    await recordLastSeen();
    await userTokenListener?.cancel();
    await personListener?.cancel();
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
      if (manageDeleted ?? false) permissions += 'استرجاع المحئوفات،';
      if (secretary ?? false) permissions += 'تسجيل حضور الخدام،';
      if (exportClasses ?? false) permissions += 'تصدير فصل،';
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

  @override
  Widget photo([bool b = false]) => getPhoto(b);

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

  Map<String, dynamic> getUpdateMap() {
    return {
      'name': name,
      'classId': classId?.path,
      'manageUsers': manageUsers ?? false,
      'manageAllowedUsers': manageAllowedUsers ?? false,
      'superAccess': superAccess ?? false,
      'manageDeleted': manageDeleted ?? false,
      'write': write ?? false,
      'secretary': secretary ?? false,
      'exportClasses': exportClasses ?? false,
      'birthdayNotify': birthdayNotify ?? false,
      'confessionsNotify': confessionsNotify ?? false,
      'tanawolNotify': tanawolNotify ?? false,
      'kodasNotify': kodasNotify ?? false,
      'meetingNotify': meetingNotify ?? false,
      'approved': approved ?? false,
      'lastConfession': lastConfession?.millisecondsSinceEpoch,
      'lastTanawol': lastTanawol?.millisecondsSinceEpoch,
    };
  }

  @override
  Map<String, dynamic> getMap() =>
      {...super.getMap(), 'AllowedUsers': allowedUsers};

  static User fromDoc(DocumentSnapshot data) =>
      User._createFromData(data.data(), data.reference);

  static Future<User> fromID(String uid) async {
    return fromDoc((await FirebaseFirestore.instance
        .collection('Users')
        .doc(uid)
        .get(dataSource)));
  }

  static Future<List<User>> getUsers(List<String> users) async {
    return (await Future.wait(users.map((s) => FirebaseFirestore.instance
            .collection('Users')
            .doc(s)
            .get(dataSource))))
        .map((e) => User.fromDoc(e))
        .toList();
  }

  static Stream<List<User>> getAllForUser() {
    return User.instance.stream.switchMap((u) {
      if (!u.manageUsers && !u.manageAllowedUsers && !u.secretary)
        return FirebaseFirestore.instance
            .collection('Users')
            .orderBy('Name')
            .snapshots()
            .map((p) => p.docs.map(fromDoc).toList());
      if (u.manageUsers || u.secretary) {
        if (!u.superAccess) {
          return Class.getAllForUser().switchMap(
            (cs) => Rx.combineLatestList<QuerySnapshot>(cs.split(10).map((c) =>
                    FirebaseFirestore.instance
                        .collection('UsersData')
                        .where('ClassId', whereIn: c.map((c) => c.ref).toList())
                        .orderBy('Name')
                        .snapshots()))
                .map((s) => s.expand((n) => n.docs).map(fromDoc).toList()),
          );
        }
        return FirebaseFirestore.instance
            .collection('UsersData')
            .orderBy('Name')
            .snapshots()
            .map((p) => p.docs.map(fromDoc).toList());
      } else {
        if (!u.superAccess) {
          return Class.getAllForUser().switchMap(
            (cs) => Rx.combineLatestList<QuerySnapshot>(cs.split(10).map((c) =>
                    FirebaseFirestore.instance
                        .collection('UsersData')
                        .where('AllowedUsers', arrayContains: u.uid)
                        .where('ClassId', whereIn: c.map((c) => c.ref).toList())
                        .orderBy('Name')
                        .snapshots()))
                .map((s) => s.expand((n) => n.docs).map(fromDoc).toList()),
          );
        }
        return FirebaseFirestore.instance
            .collection('UsersData')
            .where('AllowedUsers', arrayContains: u.uid)
            .orderBy('Name')
            .snapshots()
            .map((p) => p.docs.map(fromDoc).toList());
      }
    });
  }

  Stream<List<User>> getNamesOnly() {
    return FirebaseFirestore.instance
        .collection('Users')
        .snapshots()
        .map((s) => s.docs.map(User.fromDoc).toList());
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
        ((lastTanawol.millisecondsSinceEpoch + 2592000000) >=
                DateTime.now().millisecondsSinceEpoch &&
            (lastConfession.millisecondsSinceEpoch + 5184000000) >=
                DateTime.now().millisecondsSinceEpoch);
  }

  @override
  Reference get photoRef =>
      FirebaseStorage.instance.ref().child('UsersPhotos/$uid');

  void reloadImage() {
    _photoUrlCache.invalidate();
  }

  static Stream<List<User>> getAllSemiManagers() {
    return User.instance.stream.switchMap((u) {
      if (u.manageUsers || u.secretary) {
        if (!u.superAccess) {
          return Class.getAllForUser().switchMap(
            (cs) => Rx.combineLatestList<QuerySnapshot>(cs.split(10).map((c) =>
                FirebaseFirestore.instance
                    .collection('UsersData')
                    .where('ClassId', whereIn: c.map((c) => c.ref).toList())
                    .where('Permissions.ManageAllowedUsers', isEqualTo: true)
                    .orderBy('Name')
                    .snapshots())).map(
                (s) => s.expand((n) => n.docs).map(fromDoc).toList()),
          );
        }
        return FirebaseFirestore.instance
            .collection('UsersData')
            .where('Permissions.ManageAllowedUsers', isEqualTo: true)
            .orderBy('Name')
            .snapshots()
            .map((p) => p.docs.map(fromDoc).toList());
      } else {
        return FirebaseFirestore.instance
            .collection('UsersData')
            .where('AllowedUsers', arrayContains: u.uid)
            .where('Permissions.ManageAllowedUsers', isEqualTo: true)
            .orderBy('Name')
            .snapshots()
            .map((p) => p.docs.map(fromDoc).toList());
      }
    });
  }

  static Future<String> onlyName(String id) async {
    return (await FirebaseFirestore.instance
            .collection('Users')
            .doc(id)
            .get(dataSource))
        .data()['Name'];
  }
}
