import 'package:churchdata_core/churchdata_core.dart';
import 'package:collection/collection.dart';
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

  Stream<Map<Class?, List<T>>> groupUsersByClass<T extends User>(
    List<T> users,
  ) {
    final adminsStudyYearRef =
        repository.collection('StudyYears').doc('-Admins-');

    final unknownStudyYearRef =
        repository.collection('StudyYears').doc('Unknown');

    return Rx.combineLatest2<JsonQuery, JsonQuery, Map<Class?, List<T>>>(
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
      (studyYears, classes) {
        final Map<JsonRef, StudyYear> studyYearByRef = {
          for (final sy in studyYears.docs) sy.reference: StudyYear.fromDoc(sy),
          unknownStudyYearRef: StudyYear(
            ref: unknownStudyYearRef,
            name: 'غير معروفة',
            grade: double.maxFinite.toInt(),
          ),
          adminsStudyYearRef: StudyYear(
            ref: adminsStudyYearRef,
            name: 'مسؤولون',
            grade: -double.maxFinite.toInt(),
          ),
        };

        final Map<String, User> usersByUID = {};
        final Map<String?, Set<String>> uidsByClassId = {};
        final List<String> adminsUIDs = [];
        final List<String> allUIDs = [];

        for (final user in users) {
          usersByUID[user.uid] = user;

          uidsByClassId[user.classId?.id] = {
            ...(uidsByClassId[user.classId?.id] ?? {}),
            user.uid,
          };

          allUIDs.add(user.uid);

          if (user.permissions.manageUsers ||
              user.permissions.manageAllowedUsers ||
              user.permissions.superAccess) {
            adminsUIDs.add(user.uid);
          }
        }

        final Map<Class?, List<String>> uidsByClass = {
          Class(
            name: 'مسؤولون',
            studyYear: adminsStudyYearRef,
            ref: repository.collection('Classes').doc('-Admins-'),
          ): adminsUIDs,
        };

        final Set<String> groupedUsersUIDs = {...adminsUIDs};

        final sortedClasses = classes.docs.map(Class.fromDoc).sorted(
          (c, c2) {
            if (c.name == '{لا يمكن قراءة اسم الفصل}' || c.studyYear == null) {
              return 1;
            }

            if (c2.name == '{لا يمكن قراءة اسم الفصل}' ||
                c2.studyYear == null) {
              return -1;
            }

            if (studyYearByRef[c.studyYear!] == studyYearByRef[c2.studyYear!]) {
              return c.gender.compareTo(c2.gender);
            }

            return studyYearByRef[c.studyYear]!
                .grade
                .compareTo(studyYearByRef[c2.studyYear]!.grade);
          },
        );

        for (final Class class$ in sortedClasses) {
          final allowedUsersSet = class$.allowedUsers.toSet();

          final newUsers = allUIDs
              .where(
                (u) =>
                    allowedUsersSet.contains(u) ||
                    (uidsByClassId[class$.id]?.contains(u) ?? false),
              )
              .toList();

          if (newUsers.isEmpty) continue;

          uidsByClass[class$] = newUsers;
          groupedUsersUIDs.addAll(newUsers);
        }

        final ungroupedUsers = {
          ...uidsByClassId[null]?.toList() ?? [],
          ...allUIDs,
        }.whereNot(groupedUsersUIDs.contains).toList();

        if (ungroupedUsers.isNotEmpty) {
          uidsByClass[null] = ungroupedUsers;
        } else {
          uidsByClass.remove(null);
        }

        return uidsByClass.map(
          (key, value) => MapEntry(
            key,
            value.map((uid) => usersByUID[uid]!).cast<T>().toList(),
          ),
        );
      },
    );
  }
}
