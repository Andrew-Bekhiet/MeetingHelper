import 'package:churchdata_core/churchdata_core.dart';
import 'package:collection/collection.dart';
import 'package:get_it/get_it.dart';
import 'package:meetinghelper/models/data/class.dart';
import 'package:meetinghelper/models/data/person.dart';
import 'package:meetinghelper/models/data/service.dart';
import 'package:meetinghelper/models/data/user.dart';
import 'package:rxdart/rxdart.dart';
import 'package:tuple/tuple.dart';

class MHDatabaseRepo extends DatabaseRepository {
  static MHDatabaseRepo get instance => GetIt.I<MHDatabaseRepo>();

  @override
  Future<DataObject?> getObjectFromLink(Uri deepLink) async {
    if (deepLink.pathSegments[0] == 'viewPerson') {
      if (deepLink.queryParameters['PersonId'] == '')
        throw Exception('PersonId has an empty value which is not allowed');

      return getPerson(
        deepLink.queryParameters['PersonId']!,
      );
    } else if (deepLink.pathSegments[0] == 'viewUser') {
      if (deepLink.queryParameters['UID'] == '')
        throw Exception('UID has an empty value which is not allowed');

      return getUserData(
        deepLink.queryParameters['UID']!,
      );
    } else if (deepLink.pathSegments[0] == 'viewQuery') {
      return QueryInfo.fromJson(deepLink.queryParameters);
    } else if (deepLink.pathSegments[0] == 'viewClass') {
      if (deepLink.queryParameters['ClassId'] == '')
        throw Exception('ClassId has an empty value which is not allowed');

      return getClass(
        deepLink.queryParameters['ClassId']!,
      );
    }

    return null;
  }

  @override
  Future<Person?> getPerson(String id) async {
    final doc = await collection('Persons').doc(id).get();

    if (!doc.exists) return null;

    return Person.fromDoc(
      doc,
    );
  }

  Future<Class?> getClass(String id) async {
    final doc = await collection('Classes').doc(id).get();

    if (!doc.exists) return null;

    return Class.fromDoc(
      doc,
    );
  }

  Future<Service?> getService(String id) async {
    final doc = await collection('Services').doc(id).get();

    if (!doc.exists) return null;

    return Service.fromDoc(
      doc,
    );
  }

  Stream<List<Person>> getAllPersons({
    String orderBy = 'Name',
    bool descending = false,
    QueryCompleter queryCompleter = kDefaultQueryCompleter,
  }) {
    return Rx.combineLatest2<User?, List<Class>, Tuple2<User?, List<Class>>>(
      MHAuthRepository.I.userStream,
      Class.getAllForUser(),
      Tuple2.new,
    ).switchMap(
      (u) {
        if (u.item1 == null) return Stream.value([]);

        if (u.item1!.permissions.superAccess) {
          return queryCompleter(collection('Persons'), orderBy, descending)
              .snapshots()
              .map((p) => p.docs.map(Person.fromDoc).toList());
        }

        return Rx.combineLatest2<List<Person>, List<Person>, List<Person>>(
          //Persons from Classes
          u.item2.isNotEmpty
              ? u.item2.length <= 10
                  ? queryCompleter(
                          collection('Persons').where('ClassId',
                              whereIn: u.item2.map((e) => e.ref).toList()),
                          orderBy,
                          descending)
                      .snapshots()
                      .map((p) => p.docs.map(Person.fromDoc).toList())
                  : Rx.combineLatestList<JsonQuery>(
                      u.item2.split(10).map(
                            (c) => queryCompleter(
                                    collection('Persons').where('ClassId',
                                        whereIn: c.map((e) => e.ref).toList()),
                                    orderBy,
                                    descending)
                                .snapshots(),
                          ),
                    ).map(
                      (s) =>
                          s.expand((n) => n.docs).map(Person.fromDoc).toList(),
                    )
              : Stream.value([]),
          //Persons from Services
          u.item1!.adminServices.isNotEmpty
              ? u.item1!.adminServices.length <= 10
                  ? queryCompleter(
                          collection('Persons').where(
                            'Services',
                            arrayContainsAny: u.item1!.adminServices,
                          ),
                          orderBy,
                          descending)
                      .snapshots()
                      .map((p) => p.docs.map(Person.fromDoc).toList())
                  : Rx.combineLatestList<JsonQuery>(
                      u.item1!.adminServices.split(10).map(
                            (c) => queryCompleter(
                              collection('Persons')
                                  .where('Services', arrayContainsAny: c),
                              orderBy,
                              descending,
                            ).snapshots(),
                          ),
                    ).map(
                      (s) =>
                          s.expand((n) => n.docs).map(Person.fromDoc).toList(),
                    )
              : Stream.value([]),
          (a, b) => {...a, ...b}.sortedByCompare(
            (p) => p.toJson()[orderBy],
            (o, n) {
              if (o is String && n is String)
                return descending ? -o.compareTo(n) : o.compareTo(n);
              if (o is int && n is int)
                return descending ? -o.compareTo(n) : o.compareTo(n);
              if (o is Timestamp && n is Timestamp)
                return descending ? -o.compareTo(n) : o.compareTo(n);
              if (o is Timestamp && n is Timestamp)
                return descending ? -o.compareTo(n) : o.compareTo(n);
              if (o is DateTime && n is DateTime)
                return descending ? -o.compareTo(n) : o.compareTo(n);
              if (o is DateTime && n is DateTime)
                return descending ? -o.compareTo(n) : o.compareTo(n);
              return 0;
            },
          ),
        );
      },
    );
  }

  Future<User?> getUserName(String uid) async {
    final document = await collection('Users').doc(uid).get();

    if (document.exists)
      return User(
        ref: document.reference,
        uid: uid,
        name: document.data()?['Name'],
      );

    return null;
  }

  Future<User?> getUser(String? uid) async {
    final user =
        (await collection('UsersData').where('UID', isEqualTo: uid).get())
            .docs
            .singleOrNull;

    if (user == null) return null;

    return User.fromDoc(user);
  }

  @override
  Future<Person?> getUserData(String uid) async {
    final user =
        (await collection('UsersData').where('UID', isEqualTo: uid).get())
            .docs
            .singleOrNull;

    if (user == null) return null;

    return Person.fromDoc(user);
  }

  Stream<List<User>> getAllUsers({
    QueryCompleter queryCompleter = kDefaultQueryCompleter,
  }) {
    return User.loggedInStream.switchMap(
      (u) {
        if (!u.permissions.manageUsers &&
            !u.permissions.manageAllowedUsers &&
            !u.permissions.secretary)
          return queryCompleter(collection('Users'), 'Name', false)
              .snapshots()
              .map((p) => p.docs.map(User.fromDoc).toList());
        if (u.permissions.manageUsers || u.permissions.secretary) {
          return queryCompleter(collection('UsersData'), 'Name', false)
              .snapshots()
              .map((p) => p.docs.map(User.fromDoc).toList());
        } else {
          return queryCompleter(
                  collection('UsersData')
                      .where('AllowedUsers', arrayContains: u.uid),
                  'Name',
                  false)
              .snapshots()
              .map((p) => p.docs.map(User.fromDoc).toList());
        }
      },
    );
  }

  Stream<List<Person>> getAllUsersData({
    QueryCompleter queryCompleter = kDefaultQueryCompleter,
  }) {
    return User.loggedInStream.switchMap(
      (u) {
        if (!u.permissions.manageUsers &&
            !u.permissions.manageAllowedUsers &&
            !u.permissions.secretary)
          throw UnsupportedError('Insuffecient Permissions');

        if (u.permissions.manageUsers || u.permissions.secretary) {
          return queryCompleter(collection('UsersData'), 'Name', false)
              .snapshots()
              .map(
                (p) => p.docs.map(Person.fromDoc).toList(),
              );
        } else {
          return queryCompleter(
                  collection('UsersData')
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

  Stream<List<User>> getAllUsersNames() {
    return collection('Users')
        .orderBy('Name')
        .snapshots()
        .map((p) => p.docs.map(User.fromDoc).toList());
  }

  Stream<List<User>> getAllSemiManagers([
    QueryCompleter queryCompleter = kDefaultQueryCompleter,
  ]) {
    return User.loggedInStream.switchMap((u) {
      if (u.permissions.manageUsers || u.permissions.secretary) {
        return queryCompleter(
                collection('UsersData')
                    .where('Permissions.ManageAllowedUsers', isEqualTo: true),
                'Name',
                false)
            .snapshots()
            .map((p) => p.docs.map(User.fromDoc).toList());
      } else {
        return queryCompleter(
                collection('UsersData')
                    .where('AllowedUsers', arrayContains: u.uid)
                    .where('Permissions.ManageAllowedUsers', isEqualTo: true),
                'Name',
                false)
            .snapshots()
            .map((p) => p.docs.map(User.fromDoc).toList());
      }
    });
  }

  Future<List<User>> getUsersNames(List<String> users) async {
    return (await Future.wait(users.map(getUserName))).whereNotNull().toList();
  }
}
