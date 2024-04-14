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
        final adminsStudyYearRef =
            repository.collection('StudyYears').doc('-Admins-');

        final unknownStudyYearRef =
            repository.collection('StudyYears').doc('Unknown');

        final Map<JsonRef, StudyYear> studyYears = {
          for (final sy in sys.docs) sy.reference: StudyYear.fromDoc(sy),
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

        final Map<String, User> usersByUID = {
          for (final user in users) user.uid: user,
        };
        final Map<String?, List<User>> usersByClassId =
            users.groupListsBy((u) => u.classId?.id);

        final Map<Class?, List<User>> unsortedResult = {
          Class(
            name: 'مسؤولون',
            studyYear: adminsStudyYearRef,
            ref: repository.collection('Classes').doc('-Admins-'),
          ): users
              .where(
                (u) =>
                    u.permissions.manageUsers ||
                    u.permissions.manageAllowedUsers ||
                    u.permissions.superAccess,
              )
              .toList(),
          null: [],
        };

        for (final Class class$ in cs.docs.map(Class.fromDoc)) {
          final newUsers = class$.allowedUsers
              .map((uid) => usersByUID[uid])
              .whereNotNull()
              .followedBy(usersByClassId[class$.id] ?? [])
              .sortedByCompare(
                (u) => users.indexOf(u),
                (a, b) => a.compareTo(b),
              )
              .toSet()
              .toList();

          unsortedResult[class$] = newUsers;
        }

        final groupedUsersSet = EqualitySet.from(
          EqualityBy<User, String>((u) => u.uid),
          unsortedResult.values.expand((e) => e),
        );
        final allUsersSet = EqualitySet.from(
          EqualityBy<User, String>((u) => u.uid),
          users,
        );

        final ungroupedUsers = allUsersSet.difference(groupedUsersSet).toList();

        for (final user in ungroupedUsers) {
          unsortedResult[null]!.add(user);
        }

        final List<MapEntry<Class?, List<User>>> sortedResult =
            unsortedResult.entries.sorted(
          (c, c2) {
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

        return {
          for (final e in sortedResult)
            if (e.value.isNotEmpty) e.key: e.value,
        };
      },
    );
  }
}
