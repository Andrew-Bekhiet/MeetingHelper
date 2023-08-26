import 'package:churchdata_core/churchdata_core.dart';
import 'package:collection/collection.dart';
import 'package:meetinghelper/models/data.dart';
import 'package:meetinghelper/repositories/database/table_base.dart';
import 'package:rxdart/rxdart.dart';

class Services extends TableBase<Service> {
  const Services(super.repository);

  @override
  Future<Service?> getById(String id) async {
    final doc = await repository.collection('Services').doc(id).get();

    if (!doc.exists) return null;

    return Service.fromDoc(
      doc,
    );
  }

  @override
  Stream<List<Service>> getAll({
    String orderBy = 'Name',
    bool descending = false,
    bool onlyShownInHistory = false,
    QueryCompleter queryCompleter = kDefaultQueryCompleter,
  }) {
    if (onlyShownInHistory) {
      return getAll(
        orderBy: orderBy,
        descending: descending,
        queryCompleter: (q, o, d) =>
            queryCompleter(q.where('ShowInHistory', isEqualTo: true), o, d),
      ).map(
        (services) => services
            .where(
              (service) =>
                  service.showInHistory &&
                  (service.validity == null ||
                      (DateTime.now().isAfter(service.validity!.start) &&
                          DateTime.now().isBefore(service.validity!.end))),
            )
            .toList(),
      );
    }

    return User.loggedInStream.switchMap(
      (u) {
        if (u.permissions.superAccess) {
          return queryCompleter(
            repository.collection('Services'),
            orderBy,
            descending,
          ).snapshots().map((c) => c.docs.map(Service.fromQueryDoc).toList());
        } else {
          return u.adminServices.isEmpty
              ? Stream.value([])
              : Rx.combineLatestList(
                  u.adminServices.map(
                    (r) => r.snapshots().map(Service.fromDoc),
                  ),
                ).map((s) => s.whereType<Service>().toList());
        }
      },
    );
  }

  Stream<Map<PreferredStudyYear?, List<T>>>
      groupServicesByStudyYearRef<T extends DataObject>([
    List<T>? services,
  ]) {
    assert(
      isSubtype<T, Class>() ||
          isSubtype<T, Service>() ||
          (T == DataObject && services == null),
    );

    return Rx.combineLatest3<Map<JsonRef, StudyYear>, List<Class>,
        List<Service>, Map<PreferredStudyYear?, List<T>>>(
      repository
          .collection('StudyYears')
          .orderBy('Grade')
          .snapshots()
          .map<Map<JsonRef, StudyYear>>(
            (sys) => {
              for (final sy in sys.docs) sy.reference: StudyYear.fromDoc(sy),
            },
          ),
      isSubtype<T, Class>() || T == DataObject
          ? services != null
              ? Stream.value(services as List<Class>)
              : User.loggedInStream.switchMap(
                  (user) => (user.permissions.superAccess
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
                              .snapshots())
                      .map(
                    (cs) => cs.docs.map(Class.fromDoc).toList(),
                  ),
                )
          : Stream.value([]),
      isSubtype<T, Service>() || T == DataObject
          ? services != null
              ? Stream.value(services as List<Service>)
              : getAll()
          : Stream.value([]),
      //

      _groupServices<T>,
    );
  }

  Map<PreferredStudyYear?, List<T>> _groupServices<T>(
    Map<JsonRef, StudyYear> studyYears,
    List<Class> classes,
    List<Service> services,
  ) {
    final combined = [...classes, ...services].cast<T>();

    mergeSort<T>(
      combined,
      compare: (c, c2) {
        if (c is Class && c2 is Class) {
          if (c.studyYear == c2.studyYear) return c.gender.compareTo(c2.gender);
          return studyYears[c.studyYear]!
              .grade
              .compareTo(studyYears[c2.studyYear]!.grade);
        } else if (c is Service && c2 is Service) {
          return ((studyYears[c.studyYearRange?.from]?.grade ?? 0) +
                  (studyYears[c.studyYearRange?.to]?.grade ?? 0))
              .compareTo(
            (studyYears[c2.studyYearRange?.from]?.grade ?? 0) +
                (studyYears[c2.studyYearRange?.to]?.grade ?? 0),
          );
        } else if (c is Class &&
            c2 is Service &&
            c2.studyYearRange?.from != c2.studyYearRange?.to) {
          return -1;
        } else if (c2 is Class &&
            c is Service &&
            c.studyYearRange?.from != c.studyYearRange?.to) {
          return 1;
        }
        return 0;
      },
    );

    double? _getPreferredGrade(int? from, int? to) {
      if (from == null || to == null) return null;

      if (from >= -3 && to <= 0) {
        return 0.1;
      } else if (from >= 1 && to <= 6) {
        return 1.1;
      } else if (from >= 7 && to <= 9) {
        return 2.1;
      } else if (from >= 10 && to <= 12) {
        return 3.1;
      } else if (from >= 13 && to <= 18) {
        return 4.1;
      }
      return null;
    }

    return groupBy<T, PreferredStudyYear?>(
      combined,
      (c) {
        if (c is Class) {
          return studyYears[c.studyYear] != null
              ? PreferredStudyYear.fromStudyYear(studyYears[c.studyYear]!)
              : null;
        } else if (c is Service &&
            c.studyYearRange?.from == c.studyYearRange?.to) {
          return studyYears[c.studyYearRange?.from] != null
              ? PreferredStudyYear.fromStudyYear(
                  studyYears[c.studyYearRange?.from]!,
                )
              : null;
        } else if (c is Service) {
          return studyYears[c.studyYearRange?.to] != null
              ? PreferredStudyYear.fromStudyYear(
                  studyYears[c.studyYearRange?.to]!,
                  _getPreferredGrade(
                    studyYears[c.studyYearRange?.from]?.grade,
                    studyYears[c.studyYearRange?.to]?.grade,
                  ),
                )
              : null;
        }

        return null;
      },
    );
  }

  Stream<Map<PreferredStudyYear?, List<T>>>
      groupServicesByStudyYearRefForUser<T extends DataObject>(
    String? uid,
    List<JsonRef> adminServices,
  ) {
    assert(isSubtype<T, Class>() || isSubtype<T, Service>() || T == DataObject);

    return Rx.combineLatest3<Map<JsonRef, StudyYear>, List<Class>,
        List<Service>, Map<PreferredStudyYear?, List<T>>>(
      repository
          .collection('StudyYears')
          .orderBy('Grade')
          .snapshots()
          .map<Map<JsonRef, StudyYear>>(
            (sys) => {
              for (final sy in sys.docs) sy.reference: StudyYear.fromDoc(sy),
            },
          ),
      isSubtype<Service, T>()
          ? Stream.value([])
          : repository
              .collection('Classes')
              .where('Allowed', arrayContains: uid)
              .orderBy('StudyYear')
              .orderBy('Gender')
              .snapshots()
              .map((cs) => cs.docs.map(Class.fromDoc).toList()),
      adminServices.isEmpty || isSubtype<Class, T>()
          ? Stream.value([])
          : Rx.combineLatestList(
              adminServices.map(
                (r) => r.snapshots().map(Service.fromDoc).whereType<Service>(),
              ),
            ),
      _groupServices<T>,
    );
  }
}
