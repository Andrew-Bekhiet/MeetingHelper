import 'package:churchdata_core/churchdata_core.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:meetinghelper/models.dart';
import 'package:meetinghelper/repositories/database_repository.dart';
import 'package:rxdart/rxdart.dart';

class Users {
  final MHDatabaseRepo repository;

  const Users(this.repository);

  Future<User?> getUserName(String uid) async {
    final document = await repository.collection('Users').doc(uid).get();

    if (document.exists) {
      return User(
        ref: document.reference,
        uid: uid,
        name: document.data()?['Name'],
      );
    }

    return null;
  }

  Future<UserWithPerson?> getUser(String? uid) async {
    final user = (await repository
            .collection('UsersData')
            .where('UID', isEqualTo: uid)
            .get())
        .docs
        .singleOrNull;

    if (user == null) return null;

    return UserWithPerson.fromDoc(user);
  }

  Future<UserWithPerson?> getUserData(String uid) async {
    final user = (await repository
            .collection('UsersData')
            .where('UID', isEqualTo: uid)
            .get())
        .docs
        .singleOrNull;

    if (user == null) return null;

    return UserWithPerson.fromDoc(user);
  }

  Stream<List<User>> getAllUsers({
    QueryCompleter queryCompleter = kDefaultQueryCompleter,
  }) {
    return User.loggedInStream.switchMap(
      (u) {
        if (!u.permissions.manageUsers &&
            !u.permissions.manageAllowedUsers &&
            !u.permissions.secretary) {
          return queryCompleter(repository.collection('Users'), 'Name', false)
              .snapshots()
              .map(
                (p) => p.docs
                    .map(
                      (d) => User(
                        ref: d.reference,
                        uid: d.id,
                        name: d.data()['Name'],
                      ),
                    )
                    .toList(),
              );
        }
        if (u.permissions.manageUsers || u.permissions.secretary) {
          return queryCompleter(
            repository.collection('UsersData'),
            'Name',
            false,
          ).snapshots().map((p) => p.docs.map(UserWithPerson.fromDoc).toList());
        } else {
          return queryCompleter(
            repository
                .collection('UsersData')
                .where('AllowedUsers', arrayContains: u.uid),
            'Name',
            false,
          ).snapshots().map((p) => p.docs.map(UserWithPerson.fromDoc).toList());
        }
      },
    );
  }

  Stream<List<UserWithPerson>> getAllUsersData({
    QueryCompleter queryCompleter = kDefaultQueryCompleter,
  }) {
    return User.loggedInStream.switchMap(
      (u) {
        if (!u.permissions.manageUsers &&
            !u.permissions.manageAllowedUsers &&
            !u.permissions.secretary) {
          throw UnsupportedError('Insuffecient Permissions');
        }

        if (u.permissions.manageUsers || u.permissions.secretary) {
          return queryCompleter(
            repository.collection('UsersData'),
            'Name',
            false,
          ).snapshots().map(
                (p) => p.docs.map(UserWithPerson.fromDoc).toList(),
              );
        } else {
          return queryCompleter(
            repository
                .collection('UsersData')
                .where('AllowedUsers', arrayContains: u.uid),
            'Name',
            false,
          ).snapshots().map(
                (p) => p.docs.map(UserWithPerson.fromDoc).toList(),
              );
        }
      },
    );
  }

  Stream<List<User>> getAllUsersNames() {
    return repository.collection('Users').orderBy('Name').snapshots().map(
          (p) => p.docs
              .map(
                (d) =>
                    User(ref: d.reference, uid: d.id, name: d.data()['Name']),
              )
              .toList(),
        );
  }

  Stream<List<User>> getAllSemiManagers([
    QueryCompleter queryCompleter = kDefaultQueryCompleter,
  ]) {
    return User.loggedInStream.switchMap((u) {
      if (u.permissions.manageUsers || u.permissions.secretary) {
        return queryCompleter(
          repository
              .collection('UsersData')
              .where('Permissions.ManageAllowedUsers', isEqualTo: true),
          'Name',
          false,
        ).snapshots().map((p) => p.docs.map(UserWithPerson.fromDoc).toList());
      } else {
        return queryCompleter(
          repository
              .collection('UsersData')
              .where('AllowedUsers', arrayContains: u.uid)
              .where('Permissions.ManageAllowedUsers', isEqualTo: true),
          'Name',
          false,
        ).snapshots().map((p) => p.docs.map(UserWithPerson.fromDoc).toList());
      }
    });
  }

  Future<List<User>> getUsersNames(List<String> users) async {
    return (await Future.wait(users.map(getUserName))).whereNotNull().toList();
  }

  Stream<Map<Class?, List<User>>> groupUsersByClass(List<User> users) {
    return Rx.combineLatest2<JsonQuery, JsonQuery, Map<Class?, List<User>>>(
      repository.collection('StudyYears').orderBy('Grade').snapshots(),
      User.loggedInStream.whereType<User>().switchMap(
            (user) => user.permissions.superAccess
                ? repository
                    .collection('Classes')
                    .orderBy('StudyYear')
                    .orderBy('Gender')
                    .snapshots()
                : repository
                    .collection('Classes')
                    .where('Allowed', arrayContains: user.uid)
                    .orderBy('StudyYear')
                    .orderBy('Gender')
                    .snapshots(),
          ),
      (sys, cs) {
        final Map<JsonRef, StudyYear> studyYears = {
          for (final sy in sys.docs) sy.reference: StudyYear.fromDoc(sy),
        };
        final unknownStudyYearRef =
            repository.collection('StudyYears').doc('Unknown');

        studyYears[unknownStudyYearRef] = StudyYear(
          ref: unknownStudyYearRef,
          name: 'غير معروفة',
          grade: 10000000,
        );

        final classesByRef = {
          for (final c in cs.docs.map(Class.fromDoc).toList()) c.ref: c,
        };

        final rslt = groupBy<User, Class?>(
          users,
          (user) => user.classId == null
              ? null
              : classesByRef[user.classId] ??
                  Class(
                    name: '{لا يمكن قراءة اسم الفصل}',
                    color: Colors.redAccent,
                    ref: repository.collection('Classes').doc('Unknown'),
                  ),
        ).entries.toList();

        mergeSort<MapEntry<Class?, List<User>>>(
          rslt,
          compare: (c, c2) {
            if (c.key == null || c.key!.name == '{لا يمكن قراءة اسم الفصل}') {
              return 1;
            }

            if (c2.key == null || c2.key!.name == '{لا يمكن قراءة اسم الفصل}') {
              return -1;
            }

            if (studyYears[c.key!.studyYear!] ==
                studyYears[c2.key!.studyYear!]) {
              return c.key!.gender.compareTo(c2.key!.gender);
            }

            return studyYears[c.key!.studyYear]!
                .grade
                .compareTo(studyYears[c2.key!.studyYear]!.grade);
          },
        );

        return {for (final e in rslt) e.key: e.value};
      },
    );
  }
}
