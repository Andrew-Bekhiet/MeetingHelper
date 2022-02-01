import 'package:churchdata_core/churchdata_core.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:meetinghelper/models/data/class.dart';
import 'package:meetinghelper/models/data/person.dart';
import 'package:meetinghelper/models/data/service.dart';
import 'package:meetinghelper/models/data/user.dart';
import 'package:meetinghelper/models/history/history_record.dart';
import 'package:rxdart/rxdart.dart';
import 'package:tuple/tuple.dart';

class MHDatabaseRepo extends DatabaseRepository {
  static MHDatabaseRepo get instance => GetIt.I<MHDatabaseRepo>();
  static MHDatabaseRepo get I => instance;

  @override
  Future<DataObject?> getObjectFromLink(Uri deepLink) async {
    if (deepLink.pathSegments[0] == 'PersonInfo') {
      if (deepLink.queryParameters['Id'] == '')
        throw Exception('Id has an empty value which is not allowed');

      return getPerson(
        deepLink.queryParameters['Id']!,
      );
    } else if (deepLink.pathSegments[0] == 'UserInfo') {
      if (deepLink.queryParameters['UID'] == '')
        throw Exception('UID has an empty value which is not allowed');

      return getUserData(
        deepLink.queryParameters['UID']!,
      );
    } else if (deepLink.pathSegments[0] == 'ClassInfo') {
      if (deepLink.queryParameters['Id'] == '')
        throw Exception('Id has an empty value which is not allowed');

      return getClass(
        deepLink.queryParameters['Id']!,
      );
    } else if (deepLink.pathSegments[0] == 'ServiceInfo') {
      if (deepLink.queryParameters['Id'] == '')
        throw Exception('Id has an empty value which is not allowed');

      return getService(
        deepLink.queryParameters['Id']!,
      );
    } else if (deepLink.pathSegments[0] == 'Day') {
      if (deepLink.queryParameters['Id'] == '')
        throw Exception('Id has an empty value which is not allowed');

      return getDay(
        deepLink.queryParameters['Id']!,
      );
    } else if (deepLink.pathSegments[0] == 'ServantsDay') {
      if (deepLink.queryParameters['Id'] == '')
        throw Exception('Id has an empty value which is not allowed');

      return getServantsDay(
        deepLink.queryParameters['Id']!,
      );
    } else if (deepLink.pathSegments[0] == 'viewQuery') {
      return QueryInfo.fromJson(deepLink.queryParameters);
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

  Future<HistoryDay?> getDay(String id) async {
    final doc = await collection('History').doc(id).get();

    if (!doc.exists) return null;

    return HistoryDay.fromDoc(
      doc,
    );
  }

  Future<ServantsHistoryDay?> getServantsDay(String id) async {
    final doc = await collection('ServantsHistory').doc(id).get();

    if (!doc.exists) return null;

    return ServantsHistoryDay.fromDoc(
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
    return Rx.combineLatest2<User, List<Class>, Tuple2<User, List<Class>>>(
      User.loggedInStream,
      Class.getAllForUser(),
      Tuple2.new,
    ).switchMap(
      (u) {
        if (u.item1.permissions.superAccess) {
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
          u.item1.adminServices.isNotEmpty
              ? u.item1.adminServices.length <= 10
                  ? queryCompleter(
                          collection('Persons').where(
                            'Services',
                            arrayContainsAny: u.item1.adminServices,
                          ),
                          orderBy,
                          descending)
                      .snapshots()
                      .map((p) => p.docs.map(Person.fromDoc).toList())
                  : Rx.combineLatestList<JsonQuery>(
                      u.item1.adminServices.split(10).map(
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

  Stream<Map<PreferredStudyYear?, List<T>>>
      groupServicesByStudyYearRef<T extends DataObject>([
    List<T>? services,
  ]) {
    assert(isSubtype<Class, T>() ||
        isSubtype<Service, T>() ||
        (T == DataObject && services == null));

    return Rx.combineLatest3<Map<JsonRef, StudyYear>, List<Class>,
        List<Service>, Map<PreferredStudyYear?, List<T>>>(
      collection('StudyYears')
          .orderBy('Grade')
          .snapshots()
          .map<Map<JsonRef, StudyYear>>(
            (sys) => {
              for (final sy in sys.docs) sy.reference: StudyYear.fromDoc(sy)
            },
          ),
      isSubtype<Class, T>() || T == DataObject
          ? services != null
              ? Stream.value(services as List<Class>)
              : User.loggedInStream.switchMap(
                  (user) => (user.permissions.superAccess
                          ? collection('Classes')
                              .orderBy('StudyYear')
                              .orderBy('Gender')
                              .snapshots()
                          : collection('Classes')
                              .where('Allowed', arrayContains: user.uid)
                              .orderBy('StudyYear')
                              .orderBy('Gender')
                              .snapshots())
                      .map(
                    (cs) => cs.docs.map(Class.fromDoc).toList(),
                  ),
                )
          : Stream.value([]),
      isSubtype<Service, T>() || T == DataObject
          ? services != null
              ? Stream.value(services as List<Service>)
              : Service.getAllForUser()
          : Stream.value([]),
      //

      _groupServices<T>,
    );
  }

  Stream<Map<PreferredStudyYear?, List<T>>>
      groupServicesByStudyYearRefForUser<T extends DataObject>(
    String? uid,
    List<JsonRef> adminServices,
  ) {
    assert(isSubtype<Class, T>() || isSubtype<Service, T>() || T == DataObject);

    return Rx.combineLatest3<Map<JsonRef, StudyYear>, List<Class>,
        List<Service>, Map<PreferredStudyYear?, List<T>>>(
      collection('StudyYears')
          .orderBy('Grade')
          .snapshots()
          .map<Map<JsonRef, StudyYear>>(
            (sys) => {
              for (final sy in sys.docs) sy.reference: StudyYear.fromDoc(sy)
            },
          ),
      isSubtype<Service, T>()
          ? Stream.value([])
          : collection('Classes')
              .where('Allowed', arrayContains: uid)
              .orderBy('StudyYear')
              .orderBy('Gender')
              .snapshots()
              .map((cs) => cs.docs.map(Class.fromDoc).toList()),
      adminServices.isEmpty || isSubtype<Class, T>()
          ? Stream.value([])
          : Rx.combineLatestList(
              adminServices.map((r) =>
                  r.snapshots().map(Service.fromDoc).whereType<Service>()),
            ),
      _groupServices<T>,
    );
  }

  Map<PreferredStudyYear?, List<T>> _groupServices<T>(
    Map<JsonRef, StudyYear> studyYears,
    List<Class> classes,
    List<Service> services,
  ) {
    final combined = [...classes, ...services];

    mergeSort<T>(combined.cast<T>(), compare: (c, c2) {
      if (c is Class && c2 is Class) {
        if (c.studyYear == c2.studyYear) return c.gender.compareTo(c2.gender);
        return studyYears[c.studyYear]!
            .grade
            .compareTo(studyYears[c2.studyYear]!.grade);
      } else if (c is Service && c2 is Service) {
        return ((studyYears[c.studyYearRange?.from]?.grade ?? 0) -
                (studyYears[c.studyYearRange?.to]?.grade ?? 0))
            .compareTo((studyYears[c2.studyYearRange?.from]?.grade ?? 0) -
                (studyYears[c2.studyYearRange?.to]?.grade ?? 0));
      } else if (c is Class &&
          c2 is Service &&
          c2.studyYearRange?.from != c2.studyYearRange?.to)
        return -1;
      else if (c2 is Class &&
          c is Service &&
          c.studyYearRange?.from != c.studyYearRange?.to) return 1;
      return 0;
    });

    double? _getPreferredGrade(int? from, int? to) {
      if (from == null || to == null) return null;

      if (from >= -3 && to <= 0)
        return 0.1;
      else if (from >= 1 && to <= 6)
        return 1.1;
      else if (from >= 7 && to <= 9)
        return 2.1;
      else if (from >= 10 && to <= 12)
        return 3.1;
      else if (from >= 13 && to <= 18) return 4.1;
      return null;
    }

    return groupBy<T, PreferredStudyYear?>(
      combined.cast<T>(),
      (c) {
        if (c is Class)
          return studyYears[c.studyYear] != null
              ? PreferredStudyYear.fromStudyYear(studyYears[c.studyYear]!)
              : null;
        else if (c is Service && c.studyYearRange?.from == c.studyYearRange?.to)
          return studyYears[c.studyYearRange?.from] != null
              ? PreferredStudyYear.fromStudyYear(
                  studyYears[c.studyYearRange?.from]!)
              : null;
        else if (c is Service)
          return studyYears[c.studyYearRange?.to] != null
              ? PreferredStudyYear.fromStudyYear(
                  studyYears[c.studyYearRange?.to]!,
                  _getPreferredGrade(studyYears[c.studyYearRange?.from]!.grade,
                      studyYears[c.studyYearRange?.to]!.grade),
                )
              : null;

        return null;
      },
    );
  }

  Stream<Map<Class?, List<User>>> groupUsersByClass(List<User> users) {
    return Rx.combineLatest2<JsonQuery, JsonQuery, Map<Class?, List<User>>>(
      collection('StudyYears').orderBy('Grade').snapshots(),
      User.loggedInStream.whereType<User>().switchMap(
            (user) => user.permissions.superAccess
                ? collection('Classes')
                    .orderBy('StudyYear')
                    .orderBy('Gender')
                    .snapshots()
                : collection('Classes')
                    .where('Allowed', arrayContains: user.uid)
                    .orderBy('StudyYear')
                    .orderBy('Gender')
                    .snapshots(),
          ),
      (sys, cs) {
        final Map<JsonRef, StudyYear> studyYears = {
          for (final sy in sys.docs) sy.reference: StudyYear.fromDoc(sy)
        };
        final unknownStudyYearRef = collection('StudyYears').doc('Unknown');

        studyYears[unknownStudyYearRef] = StudyYear(
          ref: unknownStudyYearRef,
          name: 'غير معروفة',
          grade: 10000000,
        );

        final classesByRef = {
          for (final c in cs.docs.map(Class.fromDoc).toList()) c.ref: c
        };

        final rslt = groupBy<User, Class?>(
          users,
          (user) => user.classId == null
              ? null
              : classesByRef[user.classId] ??
                  Class(
                    name: '{لا يمكن قراءة اسم الفصل}',
                    color: Colors.redAccent,
                    ref: collection('Classes').doc('Unknown'),
                  ),
        ).entries;

        mergeSort<MapEntry<Class?, List<User>>>(rslt.toList(),
            compare: (c, c2) {
          if (c.key == null || c.key!.name == '{لا يمكن قراءة اسم الفصل}')
            return 1;

          if (c2.key == null || c2.key!.name == '{لا يمكن قراءة اسم الفصل}')
            return -1;

          if (studyYears[c.key!.studyYear!] == studyYears[c2.key!.studyYear!])
            return c.key!.gender.compareTo(c2.key!.gender);

          return studyYears[c.key!.studyYear]!
              .grade
              .compareTo(studyYears[c2.key!.studyYear]!.grade);
        });

        return {for (final e in rslt) e.key: e.value};
      },
    );
  }

  Stream<Map<Class?, List<Person>>> groupPersonsByClassRef(
      [List<Person>? persons]) {
    return Rx.combineLatest3<Map<JsonRef, StudyYear>, List<Person>, JsonQuery,
        Map<Class, List<Person>>>(
      collection('StudyYears').orderBy('Grade').snapshots().map(
            (sys) => {
              for (final sy in sys.docs) sy.reference: StudyYear.fromDoc(sy)
            },
          ),
      persons != null ? Stream.value(persons) : getAllPersons(),
      User.loggedInStream.whereType().switchMap(
            (user) => user.superAccess
                ? collection('Classes')
                    .orderBy('StudyYear')
                    .orderBy('Gender')
                    .snapshots()
                : collection('Classes')
                    .where('Allowed', arrayContains: user.uid)
                    .orderBy('StudyYear')
                    .orderBy('Gender')
                    .snapshots(),
          ),
      (studyYears, persons, cs) {
        final Map<JsonRef?, List<Person>> personsByClassRef =
            groupBy(persons, (p) => p.classId);

        final classes = cs.docs
            .map(Class.fromDoc)
            .where((c) => personsByClassRef[c.ref] != null)
            .toList();

        mergeSort<Class>(classes, compare: (c, c2) {
          if (c.studyYear == c2.studyYear) return c.gender.compareTo(c2.gender);
          return studyYears[c.studyYear]!
              .grade
              .compareTo(studyYears[c2.studyYear]!.grade);
        });

        return {for (final c in classes) c: personsByClassRef[c.ref]!};
      },
    );
  }

  Stream<Map<StudyYear?, List<T>>> groupPersonsByStudyYearRef<T extends Person>(
      [List<T>? persons]) {
    return Rx.combineLatest2<Map<JsonRef, StudyYear>, List<T>,
        Map<StudyYear?, List<T>>>(
      collection('StudyYears').orderBy('Grade').snapshots().map(
            (sys) => {
              for (final sy in sys.docs) sy.reference: StudyYear.fromDoc(sy)
            },
          ),
      (persons != null ? Stream.value(persons) : getAllPersons())
          .map((p) => p.whereType<T>().toList()),
      (studyYears, persons) {
        return {
          for (final person in persons.groupListsBy((p) => p.studyYear).entries)
            if (person.key != null && studyYears[person.key] != null)
              studyYears[person.key]: person.value
        };
      },
    );
  }
}
