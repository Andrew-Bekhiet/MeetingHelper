import 'package:churchdata_core/churchdata_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart' show FirebaseFirestore;
import 'package:collection/collection.dart';
import 'package:get_it/get_it.dart';
import 'package:meetinghelper/models.dart';
import 'package:meetinghelper/repositories/database/table_base.dart';
import 'package:rxdart/rxdart.dart';
import 'package:tuple/tuple.dart';

class Persons extends TableBase<Person> {
  const Persons(super.repository);

  @override
  Future<Person?> getById(String id) async {
    final doc = await repository.collection('Persons').doc(id).get();

    if (!doc.exists) return null;

    return Person.fromDoc(
      doc,
    );
  }

  @override
  Stream<List<Person>> getAll({
    String orderBy = 'Name',
    bool descending = false,
    bool useRootCollection = false,
    QueryCompleter queryCompleter = kDefaultQueryCompleter,
  }) {
    if (useRootCollection) {
      return queryCompleter(
        repository.collection('Persons'),
        orderBy,
        descending,
      ).snapshots().map((p) => p.docs.map(Person.fromDoc).toSet().toList());
    }

    return Rx.combineLatest2<User, List<Class>, Tuple2<User, List<Class>>>(
      User.loggedInStream,
      repository.classes.getAll(),
      Tuple2.new,
    ).switchMap(
      (u) {
        if (u.item1.permissions.superAccess) {
          return queryCompleter(
            repository.collection('Persons'),
            orderBy,
            descending,
          ).snapshots().map((p) => p.docs.map(Person.fromDoc).toList());
        }

        return Rx.combineLatest2<List<Person>, List<Person>, List<Person>>(
          //Persons from Classes
          u.item2.isNotEmpty
              ? u.item2.length <= 30
                  ? queryCompleter(
                      repository.collection('Persons').where(
                            'ClassId',
                            whereIn: u.item2.map((e) => e.ref).toList(),
                          ),
                      orderBy,
                      descending,
                    )
                      .snapshots()
                      .map((p) => p.docs.map(Person.fromDoc).toList())
                  : Rx.combineLatestList<JsonQuery>(
                      u.item2.split(30).map(
                            (c) => queryCompleter(
                              repository.collection('Persons').where(
                                    'ClassId',
                                    whereIn: c.map((e) => e.ref).toList(),
                                  ),
                              orderBy,
                              descending,
                            ).snapshots(),
                          ),
                    ).map(
                      (s) =>
                          s.expand((n) => n.docs).map(Person.fromDoc).toList(),
                    )
              : Stream.value([]),
          //Persons from Services
          u.item1.adminServices.isNotEmpty
              ? u.item1.adminServices.length <= 30
                  ? queryCompleter(
                      repository.collection('Persons').where(
                            'Services',
                            arrayContainsAny: u.item1.adminServices,
                          ),
                      orderBy,
                      descending,
                    )
                      .snapshots()
                      .map((p) => p.docs.map(Person.fromDoc).toList())
                  : Rx.combineLatestList<JsonQuery>(
                      u.item1.adminServices.split(30).map(
                            (c) => queryCompleter(
                              repository
                                  .collection('Persons')
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
              if (o is String && n is String) {
                return descending ? -o.compareTo(n) : o.compareTo(n);
              }
              if (o is int && n is int) {
                return descending ? -o.compareTo(n) : o.compareTo(n);
              }
              if (o is Timestamp && n is Timestamp) {
                return descending ? -o.compareTo(n) : o.compareTo(n);
              }
              if (o is Timestamp && n is Timestamp) {
                return descending ? -o.compareTo(n) : o.compareTo(n);
              }
              if (o is DateTime && n is DateTime) {
                return descending ? -o.compareTo(n) : o.compareTo(n);
              }
              if (o is DateTime && n is DateTime) {
                return descending ? -o.compareTo(n) : o.compareTo(n);
              }
              return 0;
            },
          ),
        );
      },
    );
  }

  Stream<Map<Class, List<Person>>> groupPersonsByClassRef([
    List<Person>? persons,
  ]) {
    return Rx.combineLatest3<JsonQuery, List<Person>, JsonQuery,
        Map<Class, List<Person>>>(
      repository.collection('StudyYears').orderBy('Grade').snapshots(),
      persons != null ? Stream.value(persons) : getAll(),
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
      (studyYears, persons, cs) {
        final studyYearsByRef = {
          for (final sy in studyYears.docs) sy.reference: StudyYear.fromDoc(sy),
        };

        final List<Class> sortedClasses =
            cs.docs.map(Class.fromDoc).sortedByCompare(
          (c) => c,
          (c, c2) {
            if (c.studyYear == c2.studyYear) {
              return c.gender.compareTo(c2.gender);
            }

            return studyYearsByRef[c.studyYear]!
                .grade
                .compareTo(studyYearsByRef[c2.studyYear]!.grade);
          },
        );

        final Map<String, Class> classesById = {
          for (final c in sortedClasses) c.ref.id: c,
        };

        final Map<Class, List<Person>> personsByClass = {};
        final List<Person> unknownClassPersons = [];

        for (final person in persons) {
          if (person.classId != null &&
              classesById[person.classId?.id] != null) {
            final class$ = classesById[person.classId!.id]!;

            personsByClass[class$] = [
              ...(personsByClass[class$] ?? []),
              person,
            ];
          } else {
            unknownClassPersons.add(person);
          }
        }

        return {
          for (final c in sortedClasses)
            if (personsByClass[c]?.isNotEmpty ?? false) c: personsByClass[c]!,
          if (unknownClassPersons.isNotEmpty)
            Class(
              name: 'غير معروف',
              ref: GetIt.I<FirebaseFirestore>()
                  .collection('Classes')
                  .doc('unknown'),
            ): unknownClassPersons,
        };
      },
    );
  }

  Stream<Map<StudyYear?, List<T>>>
      groupPersonsByStudyYearRef<T extends Person>([
    List<T>? persons,
  ]) {
    return Rx.combineLatest2<JsonQuery, List<T>, Map<StudyYear?, List<T>>>(
      repository.collection('StudyYears').orderBy('Grade').snapshots(),
      (persons != null ? Stream.value(persons) : getAll())
          .map((p) => p.whereType<T>().toList()),
      (studyYears, persons) {
        final Map<JsonRef?, List<T>> personsByStudyYear =
            persons.groupListsBy((p) => p.studyYear);

        return {
          for (final sy in studyYears.docs)
            if (personsByStudyYear[sy.reference]?.isNotEmpty ?? false)
              StudyYear.fromDoc(sy): personsByStudyYear[sy.reference]!,
        };
      },
    );
  }

  Future<List<Person>> todaysBirthdays([int? limit]) {
    final now = DateTime.now();

    return getAll(
      queryCompleter: (q, _, __) {
        final query = q.where(
          'BirthDateMonthDay',
          isEqualTo: '${now.month}-${now.day}',
        );

        if (limit != null) {
          return query.limit(limit);
        }

        return query;
      },
    ).first;
  }
}
