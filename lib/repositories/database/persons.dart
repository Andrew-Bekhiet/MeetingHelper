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
              ? u.item2.length <= 10
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
                      u.item2.split(10).map(
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
              ? u.item1.adminServices.length <= 10
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
                      u.item1.adminServices.split(10).map(
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

  Stream<Map<Class?, List<Person>>> groupPersonsByClassRef([
    List<Person>? persons,
  ]) {
    return Rx.combineLatest3<Map<JsonRef, StudyYear>, List<Person>, JsonQuery,
        Map<Class, List<Person>>>(
      repository.collection('StudyYears').orderBy('Grade').snapshots().map(
            (sys) => {
              for (final sy in sys.docs) sy.reference: StudyYear.fromDoc(sy),
            },
          ),
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
        final Map<JsonRef?, List<Person>> personsByClassRef =
            groupBy(persons, (p) => p.classId);

        final classes = cs.docs
            .map(Class.fromDoc)
            .where((c) => personsByClassRef[c.ref] != null)
            .toList();

        final classesIds = classes.map((c) => c.ref).toSet();

        mergeSort<Class>(
          classes,
          compare: (c, c2) {
            if (c.studyYear == c2.studyYear) {
              return c.gender.compareTo(c2.gender);
            }
            return studyYears[c.studyYear]!
                .grade
                .compareTo(studyYears[c2.studyYear]!.grade);
          },
        );

        return {
          for (final c in classes) c: personsByClassRef[c.ref]!,
          Class(
            name: 'غير معروف',
            ref: GetIt.I<FirebaseFirestore>()
                .collection('Classes')
                .doc('unknown'),
          ): personsByClassRef.entries
              .where((kv) => !classesIds.contains(kv.key))
              .map((e) => e.value)
              .expand((e) => e)
              .sortedBy((c) => c.name)
              .toList(),
        };
      },
    );
  }

  Stream<Map<StudyYear?, List<T>>>
      groupPersonsByStudyYearRef<T extends Person>([
    List<T>? persons,
  ]) {
    return Rx.combineLatest2<Map<JsonRef, StudyYear>, List<T>,
        Map<StudyYear?, List<T>>>(
      repository.collection('StudyYears').orderBy('Grade').snapshots().map(
            (sys) => {
              for (final sy in sys.docs) sy.reference: StudyYear.fromDoc(sy),
            },
          ),
      (persons != null ? Stream.value(persons) : getAll())
          .map((p) => p.whereType<T>().toList()),
      (studyYears, persons) {
        return {
          for (final person in persons.groupListsBy((p) => p.studyYear).entries)
            if (person.key != null && studyYears[person.key] != null)
              studyYears[person.key]: person.value,
        };
      },
    );
  }
}
