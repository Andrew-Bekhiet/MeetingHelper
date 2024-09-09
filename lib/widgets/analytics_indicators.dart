import 'package:churchdata_core/churchdata_core.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:intl/intl.dart' as intl;
import 'package:meetinghelper/models.dart';
import 'package:meetinghelper/repositories.dart';
import 'package:meetinghelper/utils/helpers.dart';
import 'package:meetinghelper/widgets.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:random_color/random_color.dart';
import 'package:rxdart/rxdart.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:tuple/tuple.dart';

class AttendanceChart extends StatelessWidget {
  AttendanceChart({
    required this.range,
    required this.collectionGroup,
    required this.title,
    super.key,
    this.classes,
    this.studyYears,
    this.days,
    this.isServant = false,
  }) : assert(
          classes != null ||
              (collectionGroup != 'Meeting' &&
                  collectionGroup != 'Kodas' &&
                  collectionGroup != 'Confession' &&
                  studyYears != null),
        );

  final List<Class>? classes;
  final List<StudyYear>? studyYears;
  final String collectionGroup;
  final List<HistoryDayBase>? days;
  final bool isServant;
  final DateTimeRange range;
  final rnd = RandomColor();
  final String title;
  final Map<String, Color> usedColorsMap = {};

  Stream<List<HistoryRecord>> _getStream() {
    if (classes == null) {
      var query =
          GetIt.I<DatabaseRepository>().collectionGroup(collectionGroup).where(
                'Services',
                arrayContains: GetIt.I<DatabaseRepository>()
                    .collection('Services')
                    .doc(collectionGroup),
              );

      query = query
          .where(
            'Time',
            isGreaterThanOrEqualTo: Timestamp.fromDate(range.start),
          )
          .where(
            'Time',
            isLessThan:
                Timestamp.fromDate(range.end.add(const Duration(days: 1))),
          );
      if (isServant) {
        query = query.where('IsServant', isEqualTo: isServant);
      }
      return query
          .orderBy('Time', descending: true)
          .snapshots()
          .map((s) => s.docs.map(HistoryRecord.fromQueryDoc).toList());
    }

    return Rx.combineLatestList<JsonQuery>(
      classes!.split(10).map((c) {
        var query =
            GetIt.I<DatabaseRepository>().collectionGroup(collectionGroup);
        if (notService(collectionGroup)) {
          query = query.where('ClassId', whereIn: c.map((e) => e.ref).toList());
        }
        query = query
            .where(
              'Time',
              isGreaterThanOrEqualTo: Timestamp.fromDate(range.start),
            )
            .where(
              'Time',
              isLessThan:
                  Timestamp.fromDate(range.end.add(const Duration(days: 1))),
            );
        if (isServant) {
          query = query.where('IsServant', isEqualTo: isServant);
        }
        return query.orderBy('Time', descending: true).snapshots();
      }).toList(),
    ).map(
      (s) => s.expand((n) => n.docs).map(HistoryRecord.fromQueryDoc).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<HistoryRecord>>(
      stream: _getStream(),
      builder: (context, history) {
        if (history.hasError) return ErrorWidget(history.error!);
        if (!history.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (history.data!.isEmpty) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              const Center(child: Text('لا يوجد سجل')),
            ],
          );
        }

        mergeSort(
          history.data!,
          compare: (o, n) => o.time.millisecondsSinceEpoch
              .compareTo(n.time.millisecondsSinceEpoch),
        );

        final Map<Timestamp, List<HistoryRecord>> historyMap =
            groupBy<HistoryRecord, Timestamp>(
          history.data!,
          (d) => d.time.toDate().truncateToDay().toTimestamp(),
        );

        final Map<JsonRef, DataObject> groupedClasses = {
          for (final c in classes ?? studyYears!) c.ref: c,
        };

        return history.data!.isNotEmpty && (classes ?? studyYears!).length > 1
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CartesianChart(
                    data: historyMap,
                    title: title,
                    parents: [
                      if (classes != null)
                        ...classes!.map((c) => c.ref)
                      else
                        GetIt.I<DatabaseRepository>()
                            .collection('Service')
                            .doc(collectionGroup),
                    ],
                    range: range,
                  ),
                  PieChart<DataObject>(
                    total: (classes ?? studyYears)!.length,
                    pointColorMapper: (parent, _) =>
                        usedColorsMap[parent.item2.id] ??=
                            parent.item2.color == null
                                ? rnd.randomColor(
                                    colorBrightness:
                                        Theme.of(context).brightness ==
                                                Brightness.dark
                                            ? ColorBrightness.dark
                                            : ColorBrightness.light,
                                  )
                                : parent.item2.color!,
                    pieData: groupBy<HistoryRecord, JsonRef?>(
                      history.data!,
                      (r) => classes != null ? r.classId : r.studyYear,
                    )
                        .entries
                        .map(
                          (e) => Tuple2<int, DataObject>(
                            e.value.length,
                            groupedClasses[e.key] ??
                                Class(
                                  ref: GetIt.I<DatabaseRepository>()
                                      .collection('Classes')
                                      .doc('null'),
                                  name: 'غير معروف',
                                ),
                          ),
                        )
                        .toList(),
                    nameGetter: (c) => c.name,
                  ),
                ],
              )
            : CartesianChart(
                data: historyMap,
                title: title,
                parents: [
                  if (classes != null)
                    ...classes!.map((c) => c.ref)
                  else
                    GetIt.I<DatabaseRepository>()
                        .collection('Service')
                        .doc(collectionGroup),
                ],
                range: range,
              );
      },
    );
  }
}

class AttendancePercent extends StatelessWidget {
  const AttendancePercent({
    required this.total,
    required this.attends,
    super.key,
    this.label,
    this.attendanceLabel,
    this.absenseLabel,
    this.totalLabel,
  });

  final String? absenseLabel;
  final String? attendanceLabel;
  final int attends;
  final String? label;
  final int total;
  final String? totalLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircularPercentIndicator(
          header: label != null
              ? Center(
                  child: Text(
                    label!,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                )
              : null,
          radius: 80.0,
          lineWidth: 15.0,
          percent: attends / total,
          animation: true,
          center: Text(
            (attends / total * 100).toStringAsFixed(1).replaceAll('.0', '') +
                '%',
          ),
          linearGradient: LinearGradient(
            colors: [
              Colors.amber[300]!,
              Colors.amber[700]!,
            ],
            stops: const [0, 1],
          ),
        ),
        ListTile(
          title: Text(attendanceLabel ?? 'اجمالي عدد أيام الحضور'),
          trailing: Text(
            attends.toString(),
            style: Theme.of(context)
                .textTheme
                .bodyMedium!
                .copyWith(color: Colors.amber[300]),
          ),
        ),
        ListTile(
          title: Text(absenseLabel ?? 'اجمالي عدد أيام الغياب'),
          trailing: Text(
            (total - attends).toString(),
            style: Theme.of(context)
                .textTheme
                .bodyMedium!
                .copyWith(color: Colors.amber[700]),
          ),
        ),
        ListTile(
          title: Text(totalLabel ?? 'الاجمالي'),
          trailing: Text(
            total.toString(),
            style: Theme.of(context)
                .textTheme
                .bodyMedium!
                .copyWith(color: Colors.amberAccent),
          ),
        ),
      ],
    );
  }
}

class ClassesAttendanceIndicator extends StatelessWidget {
  ClassesAttendanceIndicator({
    required this.collection,
    super.key,
    this.classes,
    this.isServant = false,
    this.studyYears,
  }) : assert(
          classes != null ||
              (collection.id != 'Meeting' &&
                  collection.id != 'Kodas' &&
                  collection.id != 'Confession' &&
                  studyYears != null),
        );

  final List<Class>? classes;
  final List<StudyYear>? studyYears;
  final JsonCollectionRef collection;
  final bool isServant;
  final rnd = RandomColor();
  final Map<String, Color> usedColorsMap = {};

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<HistoryRecord>>(
      stream: classes != null
          ? Rx.combineLatestList<JsonQuery>(
              classes!
                  .split(10)
                  .map(
                    (o) => collection
                        .where('ClassId', whereIn: o.map((e) => e.ref).toList())
                        .snapshots(),
                  )
                  .toList(),
            ).map(
              (s) => s
                  .expand((e) => e.docs)
                  .map(HistoryRecord.fromQueryDoc)
                  .toList(),
            )
          : collection
              .snapshots()
              .map((s) => s.docs.map(HistoryRecord.fromQueryDoc).toList()),
      builder: (context, snapshot) {
        if (snapshot.hasError) return ErrorWidget(snapshot.error!);
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        return StreamBuilder<int>(
          stream: classes != null
              ? Rx.combineLatestList<JsonQuery>(
                  classes!
                      .split(10)
                      .map(
                        (o) => isServant
                            ? GetIt.I<DatabaseRepository>()
                                .collection('UsersData')
                                .where(
                                  'ClassId',
                                  whereIn: o.map((e) => e.ref).toList(),
                                )
                                .snapshots()
                            : GetIt.I<DatabaseRepository>()
                                .collection('Persons')
                                .where(
                                  'ClassId',
                                  whereIn: o.map((e) => e.ref).toList(),
                                )
                                .snapshots(),
                      )
                      .toList(),
                ).map((s) => s.fold<int>(0, (o, n) => o + n.size))
              : isServant
                  ? GetIt.I<DatabaseRepository>()
                      .collection('UsersData')
                      .where(
                        'Services',
                        arrayContains: GetIt.I<DatabaseRepository>()
                            .collection('Services')
                            .doc(collection.id),
                      )
                      .snapshots()
                      .map((s) => s.size)
                  : GetIt.I<DatabaseRepository>()
                      .collection('Persons')
                      .where(
                        'Services',
                        arrayContains: GetIt.I<DatabaseRepository>()
                            .collection('Services')
                            .doc(collection.id),
                      )
                      .snapshots()
                      .map((s) => s.size),
          builder: (context, persons) {
            if (persons.hasError) return ErrorWidget(persons.error!);
            if (!persons.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            if (persons.data == 0) {
              return const Center(
                child: Text('لا يوجد مخدومين في الفصول المحددة'),
              );
            }

            final Map<JsonRef, DataObject> groupedClasses = {
              for (final c in classes ?? studyYears!) c.ref: c,
            };

            return snapshot.data!.isNotEmpty &&
                    (classes ?? studyYears!).length > 1
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AttendancePercent(
                        attendanceLabel: 'اجمالي عدد الحضور',
                        absenseLabel: 'اجمالي عدد الغياب',
                        totalLabel: 'اجمالي عدد المخدومين',
                        attends: snapshot.data!.length,
                        total: persons.data!,
                      ),
                      PieChart<DataObject>(
                        total: classes != null
                            ? classes!.length
                            : studyYears!.length,
                        pointColorMapper: (parent, _) =>
                            usedColorsMap[parent.item2.id] ??=
                                parent.item2.color == null ||
                                        parent.item2.color == Colors.transparent
                                    ? rnd.randomColor(
                                        colorBrightness:
                                            Theme.of(context).brightness ==
                                                    Brightness.dark
                                                ? ColorBrightness.dark
                                                : ColorBrightness.light,
                                      )
                                    : parent.item2.color!,
                        pieData: groupBy<HistoryRecord, JsonRef?>(
                          snapshot.data!,
                          (p) => classes != null ? p.classId! : p.studyYear,
                        )
                            .entries
                            .map(
                              (e) => Tuple2<int, DataObject>(
                                e.value.length,
                                groupedClasses[e.key] ??
                                    Class(
                                      ref: GetIt.I<DatabaseRepository>()
                                          .collection('Classes')
                                          .doc('null'),
                                      name: 'غير معروف',
                                    ),
                              ),
                            )
                            .toList(),
                        nameGetter: (c) => c.name,
                      ),
                    ],
                  )
                : AttendancePercent(
                    attendanceLabel: 'اجمالي عدد الحضور',
                    absenseLabel: 'اجمالي عدد الغياب',
                    totalLabel: 'اجمالي عدد المخدومين',
                    attends: snapshot.data!.length,
                    total: persons.data!,
                  );
          },
        );
      },
    );
  }
}

class PersonAttendanceIndicator extends StatelessWidget {
  const PersonAttendanceIndicator({
    required this.id,
    required this.total,
    required this.range,
    required this.collectionGroup,
    super.key,
    this.label,
    this.attendanceLabel,
    this.absenseLabel,
  });

  final String? absenseLabel;
  final String? attendanceLabel;
  final String collectionGroup;
  final String id;
  final String? label;
  final DateTimeRange range;
  final int total;

  Stream<List<JsonQueryDoc>> _getHistoryForUser() {
    return Rx.combineLatest3<User?, List<Class>, List<Service>,
        Tuple3<User?, List<Class>, List<Service>>>(
      User.loggedInStream,
      MHDatabaseRepo.I.classes.getAll(),
      MHDatabaseRepo.I.services.getAll(),
      Tuple3.new,
    ).switchMap((u) {
      if (u.item1 == null) return Stream.value([]);

      if (u.item1!.permissions.superAccess) {
        return GetIt.I<DatabaseRepository>()
            .collectionGroup(collectionGroup)
            .where('ID', isEqualTo: id)
            .where(
              'Time',
              isGreaterThanOrEqualTo: Timestamp.fromDate(range.start),
            )
            .where(
              'Time',
              isLessThan:
                  Timestamp.fromDate(range.end.add(const Duration(days: 1))),
            )
            .orderBy('Time', descending: true)
            .snapshots()
            .map((s) => s.docs);
      } else if (notService(collectionGroup)
          ? u.item2.isEmpty
          : u.item3.isEmpty) {
        return Stream.value([]);
      } else {
        return Rx.combineLatestList<JsonQuery>(
          (notService(collectionGroup) ? u.item2 : u.item3).split(10).map((o) {
            return GetIt.I<DatabaseRepository>()
                .collectionGroup(collectionGroup)
                .where(
                  collectionGroup == 'Meeting' ||
                          collectionGroup == 'Kodas' ||
                          collectionGroup == 'Confession'
                      ? 'ClassId'
                      : 'Services',
                  whereIn: collectionGroup == 'Meeting' ||
                          collectionGroup == 'Kodas' ||
                          collectionGroup == 'Confession'
                      ? o.map((e) => e.ref).toList()
                      : null,
                  arrayContainsAny: collectionGroup == 'Meeting' ||
                          collectionGroup == 'Kodas' ||
                          collectionGroup == 'Confession'
                      ? null
                      : o.map((e) => e.ref).toList(),
                )
                .where('ID', isEqualTo: id)
                .where(
                  'Time',
                  isLessThan: Timestamp.fromDate(
                    range.end.add(const Duration(days: 1)),
                  ),
                )
                .where(
                  'Time',
                  isGreaterThanOrEqualTo: Timestamp.fromDate(range.start),
                )
                .orderBy('Time', descending: true)
                .snapshots();
          }).toList(),
        ).map((s) => s.expand((n) => n.docs).toList());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<JsonQueryDoc>>(
      stream: _getHistoryForUser(),
      builder: (context, history) {
        if (history.hasError) return ErrorWidget(history.error!);
        if (!history.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        return AttendancePercent(
          label: label,
          attendanceLabel: attendanceLabel,
          absenseLabel: absenseLabel,
          total: total,
          attends: history.data!.length,
        );
      },
    );
  }
}

class HistoryAnalysisWidget extends StatelessWidget {
  HistoryAnalysisWidget({
    required this.range,
    required this.parents,
    required this.classesByRef,
    required this.collectionGroup,
    required this.title,
    super.key,
    this.showUsers = true,
  });

  final List<DataObject> parents;
  final Map<JsonRef, DataObject> classesByRef;
  final String collectionGroup;
  final DateTimeRange range;
  final rnd = RandomColor();
  final bool showUsers;
  final String title;
  final Map<String, Color> usedColorsMap = <String, Color>{};

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<JsonQueryDoc>>(
      stream: MinimalHistoryRecord.getAllForUser(
        collectionGroup: collectionGroup,
        range: range,
        classes: parents.whereType<Class>().toList(),
        services: parents.whereType<Service>().toList(),
      ),
      builder: (context, daysData) {
        if (daysData.hasError) return ErrorWidget(daysData.error!);
        if (!daysData.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (daysData.data!.isEmpty) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              const Center(child: Text('لا يوجد سجل')),
            ],
          );
        }

        final List<MinimalHistoryRecord> data =
            daysData.data!.map(MinimalHistoryRecord.fromQueryDoc).toList();

        mergeSort(
          data,
          compare: (o, n) => o.time.millisecondsSinceEpoch
              .compareTo(n.time.millisecondsSinceEpoch),
        );

        final Map<Timestamp, List<MinimalHistoryRecord>> groupedData =
            groupBy<MinimalHistoryRecord, Timestamp>(
          data,
          (d) => d.time.toDate().truncateToDay().toTimestamp(),
        );

        final parentsRefs = parents.map((o) => o.ref).toList();

        final refsCount = <JsonRef, List<MinimalHistoryRecord>>{};
        for (final record in data) {
          if (record.classId != null && parentsRefs.contains(record.classId)) {
            (refsCount[record.classId!] ??= []).add(record);
          }
          if (record.services != null) {
            for (final s in record.services!) {
              if (parentsRefs.contains(s)) (refsCount[s] ??= []).add(record);
            }
          }
        }

        final list = refsCount.entries.toList();

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CartesianChart(
              title: title,
              parents: parents.map((o) => o.ref).toList(),
              range: range,
              data: groupedData,
            ),
            ListTile(
              title: Center(child: Text('تحليل ' + title + ' لكل فصل')),
            ),
            PieChart<JsonRef>(
              total: data.length,
              pieData: list
                  .map(
                    (e) => Tuple2<int, JsonRef>(
                      e.value.length,
                      e.key,
                    ),
                  )
                  .toList(),
              nameGetter: (c) => classesByRef[c]?.name,
              pointColorMapper: (entry, __) =>
                  usedColorsMap[entry.item2.path] ??= (classesByRef[entry.item2]
                                  ?.color ==
                              null ||
                          classesByRef[entry.item2]?.color == Colors.transparent
                      ? rnd.randomColor(
                          colorBrightness:
                              Theme.of(context).brightness == Brightness.dark
                                  ? ColorBrightness.dark
                                  : ColorBrightness.light,
                        )
                      : classesByRef[entry.item2]?.color)!,
            ),
            if (showUsers)
              ListTile(
                title: Center(child: Text('تحليل ' + title + ' لكل خادم')),
              ),
            if (showUsers)
              FutureBuilder<List<User>>(
                future: MHDatabaseRepo.instance.users.getAllUsersNames().first,
                builder: (context, usersData) {
                  if (usersData.hasError) return ErrorWidget(usersData.error!);
                  if (!usersData.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final usersByID = {for (final u in usersData.data!) u.id: u};
                  final pieData =
                      groupBy<MinimalHistoryRecord, String?>(data, (s) => s.by)
                          .entries
                          .toList();
                  return PieChart<String?>(
                    nameGetter: (c) => usersByID[c]?.name,
                    pointColorMapper: (entry, __) =>
                        usedColorsMap[entry.item2 ?? 'unknown'] ??=
                            rnd.randomColor(
                      colorBrightness:
                          Theme.of(context).brightness == Brightness.dark
                              ? ColorBrightness.dark
                              : ColorBrightness.light,
                    ),
                    total: data.length,
                    pieData: pieData
                        .map(
                          (e) => Tuple2<int, String?>(
                            e.value.length,
                            e.key,
                          ),
                        )
                        .toList(),
                  );
                },
              ),
          ],
        );
      },
    );
  }
}

class CartesianChart<T> extends StatelessWidget {
  const CartesianChart({
    required this.range,
    required this.data,
    required this.title,
    super.key,
    this.parents,
    this.showMax = false,
  }) : assert(parents != null || !showMax);

  final List<JsonRef>? parents;
  final Map<Timestamp, List<T>> data;
  final DateTimeRange range;
  final bool showMax;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18.0),
      child: StreamBuilder<List<Person>?>(
        stream: showMax && (parents?.isNotEmpty ?? false)
            ? Rx.combineLatestList<List<Person>>([
                ...parents!
                    .where((r) => r.parent.id == 'Classes')
                    .toList()
                    .split(10)
                    .map(
                      (c) => GetIt.I<DatabaseRepository>()
                          .collection('Persons')
                          .where('ClassId', whereIn: c)
                          .snapshots()
                          .map(
                            (s) => s.docs.map(Person.fromDoc).toList(),
                          ),
                    ),
                ...parents!
                    .where((r) => r.parent.id == 'Services')
                    .toList()
                    .split(10)
                    .map(
                      (c) => GetIt.I<DatabaseRepository>()
                          .collection('Persons')
                          .where('Services', arrayContainsAny: c)
                          .snapshots()
                          .map(
                            (s) => s.docs.map(Person.fromDoc).toList(),
                          ),
                    ),
              ]).map((p) => p.expand((o) => o).toList())
            : Stream.value(null),
        builder: (context, persons) {
          if (data.isEmpty) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                const Center(child: Text('لا يوجد سجل')),
              ],
            );
          }

          if (persons.hasError) return ErrorWidget(persons.error!);
          if (!persons.hasData && showMax) {
            return const Center(child: CircularProgressIndicator.adaptive());
          }

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              Directionality(
                textDirection: TextDirection.ltr,
                child: SfCartesianChart(
                  enableAxisAnimation: true,
                  primaryYAxis: NumericAxis(
                    decimalPlaces: 0,
                    maximum: persons.data?.length.toDouble(),
                  ),
                  primaryXAxis: DateTimeAxis(
                    minimum: range.start.subtract(const Duration(hours: 4)),
                    maximum: range.end.add(const Duration(hours: 4)),
                    dateFormat: intl.DateFormat('yyy/M/d', 'ar-EG'),
                    intervalType: DateTimeIntervalType.days,
                    labelRotation: 90,
                    desiredIntervals:
                        data.keys.length > 25 ? 25 : data.keys.length,
                  ),
                  tooltipBehavior: TooltipBehavior(
                    enable: true,
                    duration: 5000,
                    tooltipPosition: TooltipPosition.pointer,
                    builder: (data, point, series, pointIndex, seriesIndex) {
                      return Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.grey[400],
                          borderRadius:
                              const BorderRadius.all(Radius.circular(6.0)),
                        ),
                        height: 120,
                        width: 90,
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              intl.DateFormat('yyy/M/d', 'ar-EG')
                                  .format(data.key.toDate()),
                            ),
                            Text(
                              data.value.length.toString(),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  zoomPanBehavior: ZoomPanBehavior(
                    enablePinching: true,
                    enablePanning: true,
                    enableDoubleTapZooming: true,
                  ),
                  series: [
                    StackedAreaSeries<MapEntry<Timestamp, List<T>>, DateTime>(
                      markerSettings: const MarkerSettings(isVisible: true),
                      borderGradient: LinearGradient(
                        colors: [
                          Colors.amber[300]!.withOpacity(0.5),
                          Colors.amber[800]!.withOpacity(0.5),
                        ],
                      ),
                      gradient: LinearGradient(
                        colors: [
                          Colors.amber[300]!.withOpacity(0.5),
                          Colors.amber[800]!.withOpacity(0.5),
                        ],
                      ),
                      dataSource: data.entries.toList(),
                      xValueMapper: (item, index) => item.key.toDate().toUtc(),
                      yValueMapper: (item, index) => item.value.length,
                      name: title,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class PieChart<T> extends StatelessWidget {
  const PieChart({
    required this.total,
    required this.pieData,
    super.key,
    this.nameGetter,
    this.pointColorMapper,
  }) : assert(nameGetter != null || T == String || null is T);

  final Color? Function(Tuple2<int, T>, int)? pointColorMapper;
  final String? Function(T)? nameGetter;
  final List<Tuple2<int, T>> pieData;
  final int total;

  String? _getName(T t) => nameGetter != null ? nameGetter!(t) : t?.toString();

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: SfCircularChart(
        tooltipBehavior: TooltipBehavior(enable: true),
        legend: const Legend(
          isVisible: true,
          position: LegendPosition.bottom,
          orientation: LegendItemOrientation.vertical,
          isResponsive: true,
          width: '100%',
          height: '35%',
          padding: 0,
        ),
        series: [
          PieSeries<Tuple2<int, T>, String>(
            dataLabelMapper: (entry, _) =>
                (_getName(entry.item2) ?? 'غير معروف') +
                ': ' +
                (entry.item1 / total * 100).toStringAsFixed(2) +
                '%',
            pointColorMapper: pointColorMapper,
            dataSource: pieData.sorted((n, o) => o.item1.compareTo(n.item1)),
            xValueMapper: (entry, _) => _getName(entry.item2) ?? 'غير معروف',
            yValueMapper: (entry, _) => entry.item1,
          ),
        ],
      ),
    );
  }
}
