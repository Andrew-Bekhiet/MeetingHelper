import 'dart:convert';

import 'package:churchdata_core/churchdata_core.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:meetinghelper/models.dart';
import 'package:meetinghelper/repositories.dart';
import 'package:meetinghelper/services.dart';
import 'package:meetinghelper/utils/globals.dart';
import 'package:rxdart/rxdart.dart';
import 'package:supabase/supabase.dart' hide User;
import 'package:supabase/supabase.dart' as supabase show User;

class MHAuthRepository extends AuthRepository<User, Person> {
  static MHAuthRepository get instance => GetIt.I<MHAuthRepository>();
  static MHAuthRepository get I => instance;

  @override
  bool connectionChanged(DatabaseEvent snapshot) {
    final bool connected = super.connectionChanged(snapshot);

    if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
      return connected;
    }

    if (connected && (scaffoldMessenger.currentState?.mounted ?? false)) {
      scaffoldMessenger.currentState!.showSnackBar(
        const SnackBar(
          backgroundColor: Colors.greenAccent,
          content: Text('تم استرجاع الاتصال بالانترنت'),
        ),
      );
    } else if (scaffoldMessenger.currentState?.mounted ?? false) {
      scaffoldMessenger.currentState!.showSnackBar(
        const SnackBar(
          backgroundColor: Colors.redAccent,
          content: Text('لا يوجد اتصال بالانترنت!'),
        ),
      );
    }
    return connected;
  }

  @override
  MHPermissionsSet permissionsFromIdToken(Json idTokenClaims) =>
      MHPermissionsSet.fromJson(idTokenClaims);

  @override
  Future<User> refreshFromIdToken(
    Json idTokenClaims, {
    auth.User? firebaseUser,
    String? uid,
    String? name,
    String? email,
    String? phone,
  }) async {
    assert(
      firebaseUser != null || (name != null && uid != null && email != null),
    );

    await refreshSupabaseToken(idTokenClaims['supabaseToken']);

    if (idTokenClaims['personId'] != currentUserData?.ref.id) {
      await personListener?.cancel();
      personListener = MHDatabaseRepo.I
          .collection('UsersData')
          .doc(idTokenClaims['personId'])
          .snapshots()
          .map((doc) {
            userSubject.add(
              User(
                lastTanawol:
                    (doc.data()?['LastTanawol'] as Timestamp?)?.toDate(),
                lastConfession:
                    (doc.data()?['LastConfession'] as Timestamp?)?.toDate(),
                ref: doc.reference,
                uid: firebaseUser?.uid ?? uid!,
                name: firebaseUser?.displayName ?? name ?? '',
                email: firebaseUser?.email ?? email!,
                password: idTokenClaims['password'],
                supabaseToken: idTokenClaims['supabaseToken'],
                permissions: permissionsFromIdToken(idTokenClaims),
                classId: doc.data()?['ClassId'],
                allowedUsers: doc.data()?['AllowedUsers']?.cast<String>() ?? [],
                adminServices:
                    doc.data()?['AdminServices']?.cast<JsonRef>() ?? [],
              ),
            );
            return doc.exists ? Person.fromDoc(doc) : null;
          })
          .whereType<Person>()
          .listen(refreshFromDoc);
    } else {
      userSubject.add(
        User(
          ref: currentUser?.ref ??
              GetIt.I<DatabaseRepository>()
                  .collection('UsersData')
                  .doc(idTokenClaims['personId'] ?? 'null'),
          uid: firebaseUser?.uid ?? uid!,
          name: firebaseUser?.displayName ?? name ?? '',
          email: firebaseUser?.email ?? email!,
          password: idTokenClaims['password'],
          supabaseToken: idTokenClaims['supabaseToken'],
          permissions: permissionsFromIdToken(idTokenClaims),
          lastTanawol: currentUser?.lastTanawol,
          lastConfession: currentUser?.lastConfession,
          classId: currentUser?.classId,
          allowedUsers: currentUser?.allowedUsers ?? [],
          adminServices: currentUser?.adminServices ?? [],
        ),
      );
    }

    connectionListener ??= GetIt.I<FirebaseDatabase>()
        .ref()
        .child('.info/connected')
        .onValue
        .skip(2)
        .listen(connectionChanged);

    return User(
      ref: currentUser?.ref ??
          MHDatabaseRepo.I
              .collection('UsersData')
              .doc(idTokenClaims['personId'] ?? 'null'),
      uid: firebaseUser?.uid ?? uid!,
      name: firebaseUser?.displayName ?? name ?? '',
      email: firebaseUser?.email ?? email!,
      password: idTokenClaims['password'],
      supabaseToken: idTokenClaims['supabaseToken'],
      permissions: permissionsFromIdToken(idTokenClaims),
      lastTanawol: currentUser?.lastTanawol,
      lastConfession: currentUser?.lastConfession,
      classId: currentUser?.classId,
      allowedUsers: currentUser?.allowedUsers ?? [],
      adminServices: currentUser?.adminServices ?? [],
    );
  }

  Future<void> refreshSupabaseToken([String? supabaseToken]) async {
    if (!GetIt.I.isRegistered(instance: this) || !userSubject.hasValue) return;

    if (supabaseToken == null ||
        DateTime.fromMillisecondsSinceEpoch(
          json.decode(
                utf8.decode(
                  base64.decode(
                    supabaseToken.split('.')[1].padRight(
                          supabaseToken.split('.')[1].length +
                              4 -
                              (supabaseToken.split('.')[1].length % 4),
                          '=',
                        ),
                  ),
                ),
              )['exp'] *
              1000,
        ).isBefore(DateTime.now())) {
      await GetIt.I<MHFunctionsService>().refreshSupabaseToken();
    } else {
      await GetIt.I<SupabaseClient>().auth.recoverSession(
            json.encode(
              {
                'currentSession': Session(
                  accessToken: supabaseToken,
                  tokenType: 'bearer',
                  user: const supabase.User(
                    id: '',
                    appMetadata: {},
                    userMetadata: {},
                    aud: '',
                    role: '',
                    updatedAt: '',
                    createdAt: '',
                  ),
                ).toJson(),
                'expiresAt': json.decode(
                  utf8.decode(
                    base64.decode(
                      supabaseToken.split('.')[1].padRight(
                            supabaseToken.split('.')[1].length +
                                4 -
                                (supabaseToken.split('.')[1].length % 4),
                            '=',
                          ),
                    ),
                  ),
                )['exp'],
              },
            ),
          );
    }
  }
}
