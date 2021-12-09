import 'dart:async';

import 'package:async/async.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:firebase_database/firebase_database.dart' hide Query;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:hive/hive.dart';
import 'package:meetinghelper/models/data/person.dart';
import 'package:meetinghelper/utils/globals.dart';
import 'package:meetinghelper/utils/helpers.dart';
import 'package:meetinghelper/utils/typedefs.dart';
import 'package:rxdart/rxdart.dart';

import '../super_classes.dart';

class User extends Person {
  static final User instance = User._initInstance();

  Completer<bool> _initialized = Completer<bool>();
  Future<bool> get initialized => _initialized.future;

  Stream<User> get stream => _streamSubject.stream;
  final _streamSubject = BehaviorSubject<User>();

  @override
  bool get hasPhoto => uid != null;

  @override
  set hasPhoto(bool? _) {}

  String? _uid;

  String? get uid => _uid;

  set uid(String? uid) {
    _uid = uid;
    if (!_initialized.isCompleted) _initialized.complete(uid != null);
  }

  @Deprecated('Use either docId or uid')
  @override
  String get id => docId;

  String get docId => ref.id;

  late String email;
  String? password;

  bool superAccess = false;
  bool manageDeleted = false;
  bool write = false;
  bool secretary = false;
  bool changeHistory = false;

  bool manageUsers = false;
  bool manageAllowedUsers = false;
  bool export = false;
  List<String> allowedUsers = [];

  bool birthdayNotify = false;
  bool confessionsNotify = false;
  bool tanawolNotify = false;
  bool kodasNotify = false;
  bool meetingNotify = false;
  bool visitNotify = false;

  bool approved = false;

  List<JsonRef> adminServices = [];

  DateTime? get lastConfessionDate => lastConfession?.toDate();
  DateTime? get lastTanawolDate => lastTanawol?.toDate();

  StreamSubscription<Event>? userTokenListener;
  StreamSubscription<Event>? connectionListener;
  StreamSubscription<JsonDoc>? personListener;
  StreamSubscription<auth.User?>? authListener;

  final AsyncCache<String> _photoUrlCache =
      AsyncCache<String>(const Duration(days: 1));

  factory User(
      {JsonRef? ref,
      String? uid,
      required String name,
      String? password,
      bool manageUsers = false,
      bool manageAllowedUsers = false,
      bool manageDeleted = false,
      bool superAccess = false,
      bool write = false,
      bool secretary = false,
      bool changeHistory = false,
      bool export = false,
      bool birthdayNotify = false,
      bool confessionsNotify = false,
      bool tanawolNotify = false,
      bool kodasNotify = false,
      bool meetingNotify = false,
      bool visitNotify = false,
      bool approved = false,
      Timestamp? lastConfession,
      Timestamp? lastTanawol,
      List<String>? allowedUsers,
      List<JsonRef>? adminServices,
      required String email}) {
    if (uid == auth.FirebaseAuth.instance.currentUser!.uid) {
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
      changeHistory: changeHistory,
      export: export,
      birthdayNotify: birthdayNotify,
      confessionsNotify: confessionsNotify,
      tanawolNotify: tanawolNotify,
      kodasNotify: kodasNotify,
      meetingNotify: meetingNotify,
      visitNotify: visitNotify,
      approved: approved,
      lastConfession: lastConfession,
      lastTanawol: lastTanawol,
      allowedUsers: allowedUsers,
      adminServices: adminServices,
      email: email,
    );
  }

  User._initInstance() : super() {
    defaultIcon = Icons.account_circle;
    _initListeners();
  }

  User._new(
      {String? uid,
      String? id,
      required String name,
      this.password,
      required this.manageUsers,
      bool? manageAllowedUsers,
      required this.superAccess,
      required this.manageDeleted,
      required this.write,
      required this.secretary,
      required this.changeHistory,
      required this.export,
      required this.birthdayNotify,
      required this.confessionsNotify,
      required this.tanawolNotify,
      required this.kodasNotify,
      required this.meetingNotify,
      required this.visitNotify,
      required this.approved,
      Timestamp? lastConfession,
      Timestamp? lastTanawol,
      List<String>? allowedUsers,
      List<JsonRef>? adminServices,
      required this.email,
      JsonRef? ref,
      JsonRef? classId,
      String? phone,
      Json? phones,
      String? fatherPhone,
      String? motherPhone,
      String? address,
      GeoPoint? location,
      Timestamp? birthDate,
      Timestamp? lastKodas,
      Timestamp? lastMeeting,
      Timestamp? lastCall,
      Timestamp? lastVisit,
      String? lastEdit,
      String? notes,
      JsonRef? school,
      JsonRef? church,
      JsonRef? cFather,
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
    this.adminServices = adminServices ?? [];
  }

  void _initListeners() {
    if (Hive.box('User').toMap().isNotEmpty) {
      _refreshFromIdToken(
        Hive.box('User').toMap(),
        name: Hive.box('User').get('name'),
        email: Hive.box('User').get('email'),
        uid: Hive.box('User').get('sub'),
      );
    }

    authListener = auth.FirebaseAuth.instance.userChanges().listen(
      (user) async {
        if (user != null) {
          userTokenListener = dbInstance
              .reference()
              .child('Users/${user.uid}/forceRefresh')
              .onValue
              .listen((e) async {
            final auth.User currentUser = user;
            if (e.snapshot.value != true) return;

            late Map idTokenClaims;
            try {
              final auth.IdTokenResult idToken =
                  await currentUser.getIdTokenResult(true);

              await Hive.box('User')
                  .putAll(idToken.claims?.map((k, v) => MapEntry(k, v)) ?? {});

              await dbInstance
                  .reference()
                  .child('Users/${currentUser.uid}/forceRefresh')
                  .set(false);

              idTokenClaims = idToken.claims ?? {};
            } catch (e) {
              idTokenClaims = Hive.box('User').toMap();
              if (idTokenClaims.isEmpty) rethrow;
            }
            _refreshFromIdToken(idTokenClaims, user: user);
          });

          Map<dynamic, dynamic> idTokenClaims;
          try {
            auth.IdTokenResult? idToken;
            if ((await Connectivity().checkConnectivity()) !=
                ConnectivityResult.none) {
              idToken = await user.getIdTokenResult();

              await Hive.box('User')
                  .putAll(idToken.claims?.map((k, v) => MapEntry(k, v)) ?? {});

              await dbInstance
                  .reference()
                  .child('Users/${user.uid}/forceRefresh')
                  .set(false);
            }

            idTokenClaims = idToken?.claims ?? Hive.box('User').toMap();
          } on Exception {
            idTokenClaims = Hive.box('User').toMap();
            if (idTokenClaims.isEmpty) rethrow;
          }

          _refreshFromIdToken(idTokenClaims, user: user);
        } else if (uid != null) {
          if (!_initialized.isCompleted) _initialized.complete(false);
          _initialized = Completer<bool>();
          await userTokenListener?.cancel();
          _uid = null;

          notifyListeners();
        }
      },
    );
  }

  void _refreshFromIdToken(Map<dynamic, dynamic> idTokenClaims,
      {auth.User? user, String? name, String? uid, String? email}) {
    assert(user != null || (name != null && uid != null && email != null));
    this.uid = user?.uid ?? uid!;
    this.name = user?.displayName ?? name ?? '';
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
    changeHistory = idTokenClaims['changeHistory'].toString() == 'true';
    export = idTokenClaims['export'].toString() == 'true';
    birthdayNotify = idTokenClaims['birthdayNotify'].toString() == 'true';
    confessionsNotify = idTokenClaims['confessionsNotify'].toString() == 'true';
    tanawolNotify = idTokenClaims['tanawolNotify'].toString() == 'true';
    kodasNotify = idTokenClaims['kodasNotify'].toString() == 'true';
    meetingNotify = idTokenClaims['meetingNotify'].toString() == 'true';
    visitNotify = idTokenClaims['visitNotify'].toString() == 'true';
    approved = idTokenClaims['approved'].toString() == 'true';

    lastConfession = idTokenClaims['lastConfession'] != null
        ? Timestamp.fromMillisecondsSinceEpoch(
            int.parse(idTokenClaims['lastConfession'].toString()))
        : null;
    lastTanawol = idTokenClaims['lastTanawol'] != null
        ? Timestamp.fromMillisecondsSinceEpoch(
            int.parse(idTokenClaims['lastTanawol'].toString()))
        : null;
    this.email = user?.email ?? email!;

    connectionListener ??= dbInstance
        .reference()
        .child('.info/connected')
        .onValue
        .listen((snapshot) {
      if (snapshot.snapshot.value == true) {
        dbInstance
            .reference()
            .child('Users/${this.uid}/lastSeen')
            .onDisconnect()
            .set(ServerValue.timestamp);

        FirebaseFirestore.instance.enableNetwork();

        dbInstance
            .reference()
            .child('Users/${this.uid}/lastSeen')
            .set('Active');

        if (scaffoldMessenger.currentState?.mounted ?? false)
          scaffoldMessenger.currentState!.showSnackBar(
            const SnackBar(
              backgroundColor: Colors.greenAccent,
              content: Text('تم استرجاع الاتصال بالانترنت'),
            ),
          );
      } else if (mainScfld.currentState?.mounted ?? false) {
        if (!_streamSubject.hasValue) _streamSubject.add(this);

        FirebaseFirestore.instance.disableNetwork();

        scaffoldMessenger.currentState!.showSnackBar(
          const SnackBar(
            backgroundColor: Colors.redAccent,
            content: Text('لا يوجد اتصال بالانترنت!'),
          ),
        );
      }
    });

    notifyListeners();
  }

  void _refreshFromDoc(JsonDoc doc) {
    final data = doc.data()!;
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
    adminServices = data['AdminServices']?.cast<JsonRef>() ?? [];

    notifyListeners();
  }

  void notifyListeners() {
    _streamSubject.add(this);
  }

  Future<void> signOut() async {
    await recordLastSeen();
    await userTokenListener?.cancel();
    await personListener?.cancel();
    if (!_initialized.isCompleted) _initialized.complete(false);
    _initialized = Completer<bool>();
    _uid = null;

    await Hive.box('User').clear();
    await Hive.box('User').close();
    await Hive.openBox('User');

    notifyListeners();
    await GoogleSignIn().signOut();
    await auth.FirebaseAuth.instance.signOut();
    await connectionListener?.cancel();
  }

  User._createFromData(Json data, JsonRef ref)
      : super.createFromData(data, ref) {
    _uid = data['UID'];
    email = data['Email'] ?? '';

    final permissions = data['Permissions'] ?? {};
    allowedUsers = data['AllowedUsers']?.cast<String>() ?? [];
    adminServices = data['AdminServices']?.cast<JsonRef>() ?? [];
    manageUsers = permissions['ManageUsers'] ?? false;
    manageAllowedUsers = permissions['ManageAllowedUsers'] ?? false;
    superAccess = permissions['SuperAccess'] ?? false;
    manageDeleted = permissions['ManageDeleted'] ?? false;
    write = permissions['Write'] ?? false;
    secretary = permissions['Secretary'] ?? false;
    changeHistory = permissions['ChangeHistory'] ?? false;
    export = permissions['Export'] ?? false;
    birthdayNotify = permissions['BirthdayNotify'] ?? false;
    confessionsNotify = permissions['ConfessionsNotify'] ?? false;
    tanawolNotify = permissions['TanawolNotify'] ?? false;
    kodasNotify = permissions['KodasNotify'] ?? false;
    meetingNotify = permissions['MeetingNotify'] ?? false;
    visitNotify = permissions['VisitNotify'] ?? false;
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
        changeHistory,
        export,
        approved,
        lastConfession,
        lastTanawol,
        hashValues(
          birthdayNotify,
          confessionsNotify,
          tanawolNotify,
          kodasNotify,
          meetingNotify,
          visitNotify,
        ),
      ) ^
      super.hashCode;

  @override
  bool operator ==(other) {
    return other is User && other.uid == uid;
  }

  Future<void> dispose() async {
    await recordLastSeen();
    await userTokenListener?.cancel();
    await personListener?.cancel();
    await connectionListener?.cancel();
    await authListener?.cancel();
    await _streamSubject.close();
  }

  Map<String, bool> getNotificationsPermissions() => {
        'birthdayNotify': birthdayNotify,
        'confessionsNotify': confessionsNotify,
        'tanawolNotify': tanawolNotify,
        'kodasNotify': kodasNotify,
        'meetingNotify': meetingNotify,
        'visitNotify': visitNotify,
      };

  String getPermissions() {
    if (approved) {
      String permissions = '';
      if (manageUsers) permissions += 'تعديل المستخدمين،';
      if (manageAllowedUsers) permissions += 'تعديل مستخدمين محددين،';
      if (superAccess) permissions += 'رؤية جميع البيانات،';
      if (manageDeleted) permissions += 'استرجاع المحئوفات،';
      if (secretary) permissions += 'تسجيل حضور الخدام،';
      if (changeHistory) permissions += 'تعديل كشوفات القديمة';
      if (export) permissions += 'تصدير فصل،';
      if (birthdayNotify) permissions += 'اشعار أعياد الميلاد،';
      if (confessionsNotify) permissions += 'اشعار الاعتراف،';
      if (tanawolNotify) permissions += 'اشعار التناول،';
      if (kodasNotify) permissions += 'اشعار القداس';
      if (meetingNotify) permissions += 'اشعار حضور الاجتماع';
      if (visitNotify) permissions += 'اشعار الافتقاد';
      if (write) permissions += 'تعديل البيانات،';
      return permissions;
    }
    return 'غير مُنشط';
  }

  @override
  Widget photo({bool cropToCircle = true, bool removeHero = false}) =>
      getPhoto(cropToCircle);

  Widget getPhoto([bool showCircle = true, bool showActiveStatus = true]) {
    return AspectRatio(
      aspectRatio: 1,
      child: StreamBuilder<Event>(
        stream: dbInstance.reference().child('Users/$uid/lastSeen').onValue,
        builder: (context, activity) {
          if (!hasPhoto)
            return Stack(
              children: [
                Positioned.fill(
                    child: Icon(Icons.account_circle,
                        size: MediaQuery.of(context).size.height / 16.56)),
                if (showActiveStatus &&
                    activity.data?.snapshot.value == 'Active')
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
                  final String? cache = Hive.box<String?>('PhotosURLsCache')
                      .get(photoRef.fullPath);

                  if (cache == null) {
                    final String url = await photoRef
                        .getDownloadURL()
                        .catchError((onError) => '');
                    await Hive.box<String?>('PhotosURLsCache')
                        .put(photoRef.fullPath, url);

                    return url;
                  }
                  // ignore: prefer_function_declarations_over_variables
                  final void Function(String) _updateCache =
                      (String cache) async {
                    String? url;
                    try {
                      url = await photoRef.getDownloadURL();
                    } catch (e) {
                      url = null;
                    }
                    if (cache != url) {
                      await Hive.box<String?>('PhotosURLsCache')
                          .put(photoRef.fullPath, url);
                      await DefaultCacheManager().removeFile(cache);
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
                                  backgroundImage: CachedNetworkImageProvider(
                                      photoUrl.data!),
                                )
                              : CachedNetworkImage(imageUrl: photoUrl.data!)
                          : const CircularProgressIndicator(),
                    ),
                    if (showActiveStatus &&
                        activity.data?.snapshot.value == 'Active')
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

  Json getUpdateMap() {
    return {
      'name': name,
      'classId': classId?.path,
      'manageUsers': manageUsers,
      'manageAllowedUsers': manageAllowedUsers,
      'superAccess': superAccess,
      'manageDeleted': manageDeleted,
      'write': write,
      'secretary': secretary,
      'changeHistory': changeHistory,
      'export': export,
      'birthdayNotify': birthdayNotify,
      'confessionsNotify': confessionsNotify,
      'tanawolNotify': tanawolNotify,
      'kodasNotify': kodasNotify,
      'meetingNotify': meetingNotify,
      'visitNotify': visitNotify,
      'approved': approved,
      'lastConfession': lastConfession?.millisecondsSinceEpoch,
      'lastTanawol': lastTanawol?.millisecondsSinceEpoch,
    };
  }

  @override
  Json getMap() => {
        ...super.getMap(),
        'AllowedUsers': allowedUsers,
        'AdminServices': adminServices,
      };

  static User fromDoc(JsonDoc data) =>
      User._createFromData(data.data()!, data.reference);

  static Future<User> fromID(String? uid) async {
    return fromDoc(
        await FirebaseFirestore.instance.collection('Users').doc(uid).get())
      ..uid = uid;
  }

  static Future<User?> fromUsersData(String? uid) async {
    final user = (await FirebaseFirestore.instance
            .collection('UsersData')
            .where('UID', isEqualTo: uid)
            .get())
        .docs
        .singleOrNull;

    if (user == null) return null;

    return fromDoc(user);
  }

  static Future<List<User>> getUsers(List<String> users) async {
    return (await Future.wait(users.map((s) =>
            FirebaseFirestore.instance.collection('Users').doc(s).get())))
        .map(User.fromDoc)
        .toList();
  }

  static Stream<List<User>> getAllForUser(
      {Query<Json> Function(Query<Json>, String, bool) queryCompleter =
          kDefaultQueryCompleter}) {
    return User.instance.stream.switchMap((u) {
      if (!u.manageUsers && !u.manageAllowedUsers && !u.secretary)
        return queryCompleter(
                FirebaseFirestore.instance.collection('Users'), 'Name', false)
            .snapshots()
            .map((p) => p.docs.map(fromDoc).toList());
      if (u.manageUsers || u.secretary) {
        return queryCompleter(
                FirebaseFirestore.instance.collection('UsersData'),
                'Name',
                false)
            .snapshots()
            .map((p) => p.docs.map(fromDoc).toList());
      } else {
        return queryCompleter(
                FirebaseFirestore.instance
                    .collection('UsersData')
                    .where('AllowedUsers', arrayContains: u.uid),
                'Name',
                false)
            .snapshots()
            .map((p) => p.docs.map(fromDoc).toList());
      }
    });
  }

  static Stream<List<User>> getAllForUserForEdit(
      [Query<Json> Function(Query<Json>, String, bool) queryCompleter =
          kDefaultQueryCompleter]) {
    return User.instance.stream.switchMap((u) {
      if (u.manageUsers) {
        return queryCompleter(
                FirebaseFirestore.instance.collection('UsersData'),
                'Name',
                false)
            .snapshots()
            .map((p) => p.docs.map(fromDoc).toList());
      } else {
        return queryCompleter(
                FirebaseFirestore.instance
                    .collection('UsersData')
                    .where('AllowedUsers', arrayContains: u.uid),
                'Name',
                false)
            .snapshots()
            .map((p) => p.docs.map(fromDoc).toList());
      }
    });
  }

  static Stream<List<User>> getAllNames() {
    return FirebaseFirestore.instance
        .collection('Users')
        .orderBy('Name')
        .snapshots()
        .map((p) => p.docs.map(fromDoc).toList());
  }

  Future<void> recordActive() async {
    if (uid == null) return;
    await dbInstance.reference().child('Users/$uid/lastSeen').set('Active');
  }

  Future<void> recordLastSeen() async {
    if (uid == null) return;
    await dbInstance
        .reference()
        .child('Users/$uid/lastSeen')
        .set(Timestamp.now().millisecondsSinceEpoch);
  }

  Future<bool> userDataUpToDate() async {
    return lastTanawol != null &&
        lastConfession != null &&
        ((lastTanawol!.millisecondsSinceEpoch + 2592000000) >=
                DateTime.now().millisecondsSinceEpoch &&
            (lastConfession!.millisecondsSinceEpoch + 5184000000) >=
                DateTime.now().millisecondsSinceEpoch);
  }

  @override
  Reference get photoRef =>
      FirebaseStorage.instance.ref().child('UsersPhotos/$uid');

  void reloadImage() {
    _photoUrlCache.invalidate();
  }

  static Stream<List<User>> getAllSemiManagers(
      [Query<Json> Function(Query<Json>, String, bool) queryCompleter =
          kDefaultQueryCompleter]) {
    return User.instance.stream.switchMap((u) {
      if (u.manageUsers || u.secretary) {
        return queryCompleter(
                FirebaseFirestore.instance
                    .collection('UsersData')
                    .where('Permissions.ManageAllowedUsers', isEqualTo: true),
                'Name',
                false)
            .snapshots()
            .map((p) => p.docs.map(fromDoc).toList());
      } else {
        return queryCompleter(
                FirebaseFirestore.instance
                    .collection('UsersData')
                    .where('AllowedUsers', arrayContains: u.uid)
                    .where('Permissions.ManageAllowedUsers', isEqualTo: true),
                'Name',
                false)
            .snapshots()
            .map((p) => p.docs.map(fromDoc).toList());
      }
    });
  }

  static Future<String?> onlyName(String? id) async {
    if (id == null) return null;
    return (await FirebaseFirestore.instance.collection('Users').doc(id).get())
        .data()?['Name'];
  }

  static Widget photoFromUID(String uid, {bool removeHero = false}) =>
      PhotoWidget(FirebaseStorage.instance.ref().child('UsersPhotos/$uid'))
          .photo(removeHero: removeHero);

  @override
  User copyWith({
    String? uid,
    String? name,
    String? password,
    bool? manageUsers,
    bool? manageAllowedUsers,
    bool? superAccess,
    bool? manageDeleted,
    bool? write,
    bool? secretary,
    bool? changeHistory,
    bool? export,
    bool? birthdayNotify,
    bool? confessionsNotify,
    bool? tanawolNotify,
    bool? kodasNotify,
    bool? meetingNotify,
    bool? visitNotify,
    bool? approved,
    Timestamp? lastConfession,
    Timestamp? lastTanawol,
    List<String>? allowedUsers,
    List<JsonRef>? adminServices,
    String? email,
    JsonRef? ref,
    JsonRef? classId,
    String? phone,
    Json? phones,
    String? fatherPhone,
    String? motherPhone,
    String? address,
    GeoPoint? location,
    Timestamp? birthDate,
    Timestamp? lastKodas,
    Timestamp? lastMeeting,
    Timestamp? lastCall,
    Timestamp? lastVisit,
    String? lastEdit,
    String? notes,
    JsonRef? school,
    JsonRef? church,
    JsonRef? cFather,
    Color? color,
  }) {
    return User._new(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      password: password ?? this.password,
      manageUsers: manageUsers ?? this.manageUsers,
      manageAllowedUsers: manageAllowedUsers ?? this.manageAllowedUsers,
      superAccess: superAccess ?? this.superAccess,
      manageDeleted: manageDeleted ?? this.manageDeleted,
      write: write ?? this.write,
      secretary: secretary ?? this.secretary,
      changeHistory: changeHistory ?? this.changeHistory,
      export: export ?? this.export,
      birthdayNotify: birthdayNotify ?? this.birthdayNotify,
      confessionsNotify: confessionsNotify ?? this.confessionsNotify,
      tanawolNotify: tanawolNotify ?? this.tanawolNotify,
      kodasNotify: kodasNotify ?? this.kodasNotify,
      meetingNotify: meetingNotify ?? this.meetingNotify,
      visitNotify: visitNotify ?? this.visitNotify,
      approved: approved ?? this.approved,
      lastConfession: lastConfession ?? this.lastConfession,
      lastTanawol: lastTanawol ?? this.lastTanawol,
      allowedUsers: allowedUsers ?? this.allowedUsers,
      adminServices: adminServices ?? this.adminServices,
      email: email ?? this.email,
      ref: ref ?? this.ref,
      classId: classId ?? this.classId,
      phone: phone ?? this.phone,
      phones: phones ?? this.phones,
      fatherPhone: fatherPhone ?? this.fatherPhone,
      motherPhone: motherPhone ?? this.motherPhone,
      address: address ?? this.address,
      location: location ?? this.location,
      birthDate: birthDate ?? this.birthDate,
      lastKodas: lastKodas ?? this.lastKodas,
      lastMeeting: lastMeeting ?? this.lastMeeting,
      lastCall: lastCall ?? this.lastCall,
      lastVisit: lastVisit ?? this.lastVisit,
      lastEdit: lastEdit ?? this.lastEdit,
      notes: notes ?? this.notes,
      school: school ?? this.school,
      church: church ?? this.church,
      cFather: cFather ?? this.cFather,
      color: color ?? this.color,
    );
  }
}
