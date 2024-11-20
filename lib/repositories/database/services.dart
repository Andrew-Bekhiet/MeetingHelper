import 'package:churchdata_core/churchdata_core.dart';
import 'package:collection/collection.dart';
import 'package:meetinghelper/models/data.dart';
import 'package:meetinghelper/repositories/database/table_base.dart';
import 'package:rxdart/rxdart.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

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

    Sentry.addBreadcrumb(
      Breadcrumb.console(
        message: 'getting services grouped by study year',
        data: {
          'T': T.toString(),
          'services': services?.map((e) => e.id).toList(),
        },
      ),
    );

    final bool shouldGetClasses = isSubtype<T, Class>() || T == DataObject;
    final bool shouldGetServices = isSubtype<T, Service>() || T == DataObject;

    return Rx.combineLatest3<List<StudyYear>, List<Class>, List<Service>,
        Map<PreferredStudyYear?, List<T>>>(
      repository
          .collection('StudyYears')
          .orderBy('Grade')
          .snapshots()
          .map((s) => s.docs.map(StudyYear.fromDoc).toList()),
      shouldGetClasses
          ? services != null
              ? Stream.value(services as List<Class>)
              : User.loggedInStream.switchMap(
                  (user) {
                    Sentry.addBreadcrumb(
                      Breadcrumb.console(
                        message: 'getting classes for user ${user.uid}',
                        data: {
                          'T': T.toString(),
                          'user': user.toJson(),
                        },
                      ),
                    );

                    return (user.permissions.superAccess
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
                    );
                  },
                )
          : Stream.value([]),
      shouldGetServices
          ? services != null
              ? Stream.value(services as List<Service>)
              : getAll()
          : Stream.value([]),
      //

      _groupServicesAndClasses<T>,
    );
  }

  Map<PreferredStudyYear?, List<T>> _groupServicesAndClasses<T>(
    List<StudyYear> studyYears,
    List<Class> classes,
    List<Service> services,
  ) {
    Sentry.addBreadcrumb(
      Breadcrumb.console(
        message: 'grouping services and classes by study year',
        data: {
          'T': T.toString(),
          'studyYears': studyYears.map((e) => e.id).toList(),
          'classes': classes.map((e) => e.id).toList(),
          'services': services.map((e) => e.id).toList(),
        },
      ),
    );

    final Map<JsonRef, StudyYear> studyYearsByRef = {
      for (final sy in studyYears) sy.ref: sy,
    };

    final List<T> combined = [...classes, ...services].cast<T>();

    mergeSort<T>(
      combined,
      compare: (c1, c2) {
        switch ((c1, c2)) {
          case (final Class c1, final Class c2)
              when c1.studyYear == c2.studyYear:
            return c1.gender.compareTo(c2.gender);

          case (final Class c1, final Class c2):
            return (studyYearsByRef[c1.studyYear]?.grade ?? -10)
                .compareTo(studyYearsByRef[c2.studyYear]?.grade ?? -10);

          case (final Service s1, final Service s2):
            final s1StudyYearFrom =
                studyYearsByRef[s1.studyYearRange?.from]?.grade ?? 0;
            final s2StudyYearFrom =
                studyYearsByRef[s2.studyYearRange?.from]?.grade ?? 0;

            final s1StudyYearTo =
                studyYearsByRef[s1.studyYearRange?.to]?.grade ?? 0;
            final s2StudyYearTo =
                studyYearsByRef[s2.studyYearRange?.to]?.grade ?? 0;

            return (s1StudyYearFrom + s1StudyYearTo)
                .compareTo(s2StudyYearFrom + s2StudyYearTo);

          case (Class(), final Service service)
              when service.studyYearRange?.from != service.studyYearRange?.to:
            return -1;

          case (final Service service, Class())
              when service.studyYearRange?.from != service.studyYearRange?.to:
            return 1;

          default:
            return 0;
        }
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
        final StudyYear? studyYear = studyYearsByRef[switch (c) {
          final Class c => c.studyYear,
          final Service s when s.studyYearRange?.from == s.studyYearRange?.to =>
            s.studyYearRange?.from,
          final Service s => s.studyYearRange?.to,
          _ => null,
        }];

        if (studyYear == null) return null;

        final double? preferredGroup =
            c is Service && c.studyYearRange?.from != c.studyYearRange?.to
                ? _getPreferredGrade(
                    studyYearsByRef[c.studyYearRange?.from]?.grade,
                    studyYearsByRef[c.studyYearRange?.to]?.grade,
                  )
                : null;

        return PreferredStudyYear.fromStudyYear(studyYear, preferredGroup);
      },
    );
  }

  Stream<Map<PreferredStudyYear?, List<T>>>
      groupServicesByStudyYearRefForUser<T extends DataObject>(
    String? uid,
    List<JsonRef> adminServices,
  ) {
    assert(isSubtype<T, Class>() || isSubtype<T, Service>() || T == DataObject);

    return Rx.combineLatest3<List<StudyYear>, List<Class>, List<Service>,
        Map<PreferredStudyYear?, List<T>>>(
      repository
          .collection('StudyYears')
          .orderBy('Grade')
          .snapshots()
          .map((s) => s.docs.map(StudyYear.fromDoc).toList()),
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
      _groupServicesAndClasses<T>,
    );
  }
}
