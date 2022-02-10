import 'package:churchdata_core/churchdata_core.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:meetinghelper/models.dart';
import 'package:meetinghelper/utils/globals.dart';
import 'package:rxdart/rxdart.dart';

class MHAuthRepository extends AuthRepository<User, Person> {
  static MHAuthRepository get instance => GetIt.I<MHAuthRepository>();
  static MHAuthRepository get I => instance;

  @override
  bool connectionChanged(DatabaseEvent snapshot) {
    final bool connected = super.connectionChanged(snapshot);

    if (connected && (mainScfld.currentState?.mounted ?? false))
      scaffoldMessenger.currentState!.showSnackBar(
        const SnackBar(
          backgroundColor: Colors.greenAccent,
          content: Text('تم استرجاع الاتصال بالانترنت'),
        ),
      );
    else if (mainScfld.currentState?.mounted ?? false)
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
              lastTanawol: (doc.data()?['LastTanawol'] as Timestamp?)?.toDate(),
              lastConfession:
                  (doc.data()?['LastConfession'] as Timestamp?)?.toDate(),
              ref: doc.reference,
              uid: firebaseUser?.uid ?? uid!,
              name: firebaseUser?.displayName ?? name ?? '',
              email: firebaseUser?.email ?? email!,
              password: idTokenClaims['password'],
              permissions: permissionsFromIdToken(idTokenClaims),
              classId: doc.data()?['ClassId'],
              allowedUsers: doc.data()?['AllowedUsers']?.cast<String>() ?? [],
              adminServices:
                  doc.data()?['AdminServices']?.cast<JsonRef>() ?? [],
            ));
            return doc.exists ? Person.fromDoc(doc) : null;
          })
          .whereType<Person>()
          .listen(refreshFromDoc);
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
        lastTanawol: currentUser?.lastTanawol,
        lastConfession: currentUser?.lastConfession,
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
      lastTanawol: currentUser?.lastTanawol,
      lastConfession: currentUser?.lastConfession,
      classId: currentUser?.classId,
      allowedUsers: currentUser?.allowedUsers ?? [],
      adminServices: currentUser?.adminServices ?? [],
    );
  }
}
