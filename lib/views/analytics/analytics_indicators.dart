import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:meetinghelper/models/models.dart';
import 'package:meetinghelper/models/user.dart';
import 'package:meetinghelper/utils/helpers.dart';
import 'package:meetinghelper/utils/typedefs.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:random_color/random_color.dart';
import 'package:rxdart/rxdart.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:tuple/tuple.dart';

class AttendanceChart extends StatelessWidget {
  AttendanceChart(
      {Key? key,
      required this.classes,
      required this.range,
      this.days,
      required this.collectionGroup,
      this.isServant = false,
      required this.title})
      : super(key: key);

  final List<Class> classes;
  final String collectionGroup;
  final List<HistoryDay>? days;
  final bool isServant;
  final DateTimeRange range;
  final rnd = RandomColor();
  final String title;
  final Map<String, Color> usedColorsMap = {};

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<HistoryRecord>>(
      stream: Rx.combineLatestList<JsonQuery>(classes
              .split(10)
              .map((c) => isServant
                  ? FirebaseFirestore.instance
                      .collectionGroup(collectionGroup)
                      .where('ClassId', whereIn: c.map((e) => e.ref).toList())
                      .where('Time',
                          isGreaterThanOrEqualTo:
                              Timestamp.fromDate(range.start))
                      .where(
                        'Time',
                        isLessThan: Timestamp.fromDate(
                            range.end.add(const Duration(days: 1))),
                      )
                      .where('IsServant', isEqualTo: isServant)
                      .orderBy('Time', descending: true)
                      .snapshots()
                  : FirebaseFirestore.instance
                      .collectionGroup(collectionGroup)
                      .where('ClassId', whereIn: c.map((e) => e.ref).toList())
                      .where('Time',
                          isGreaterThanOrEqualTo:
                              Timestamp.fromDate(range.start))
                      .where(
                        'Time',
                        isLessThan: Timestamp.fromDate(
                            range.end.add(const Duration(days: 1))),
                      )
                      .orderBy('Time', descending: true)
                      .snapshots())
              .toList())
          .map((s) =>
              s.expand((n) => n.docs).map(HistoryRecord.fromQueryDoc).toList()),
      builder: (context, history) {
        if (history.hasError) return ErrorWidget(history.error!);
        if (!history.hasData)
          return const Center(child: CircularProgressIndicator());
        if (history.data!.isEmpty)
          return const Center(child: Text('لا يوجد سجل'));
        mergeSort(history.data!,
            compare: (dynamic o, dynamic n) => o.time.millisecondsSinceEpoch
                .compareTo(n.time.millisecondsSinceEpoch));
        final Map<Timestamp, List<HistoryRecord>> historyMap =
            groupBy<HistoryRecord, Timestamp>(
                history.data!, (d) => tranucateToDay(time: d.time.toDate()));

        final Map<JsonRef, Class> groupedClasses = {
          for (final c in classes) c.ref: c
        };

        return history.data!.isNotEmpty && classes.length > 1
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CartesianChart(
                    data: historyMap,
                    title: title,
                    classes: classes,
                    range: range,
                  ),
                  PieChart<Class>(
                    total: classes.length,
                    pointColorMapper: (_class, _) =>
                        usedColorsMap[_class.item2.id] ??=
                            _class.item2.color == Colors.transparent
                                ? rnd.randomColor(
                                    colorBrightness:
                                        Theme.of(context).brightness ==
                                                Brightness.dark
                                            ? ColorBrightness.dark
                                            : ColorBrightness.light,
                                  )
                                : _class.item2.color,
                    pieData: groupBy<HistoryRecord, JsonRef?>(
                            history.data!, (r) => r.classId)
                        .entries
                        .map(
                          (e) => Tuple2<int, Class>(
                            e.value.length,
                            groupedClasses[e.key]!,
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
                classes: classes,
                range: range,
              );
      },
    );
  }
}

class AttendancePercent extends StatelessWidget {
  const AttendancePercent({
    Key? key,
    this.label,
    this.attendanceLabel,
    this.absenseLabel,
    this.totalLabel,
    required this.total,
    required this.attends,
  }) : super(key: key);

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
                  child: Text(label!,
                      style: Theme.of(context).textTheme.headline6),
                )
              : null,
          radius: 160.0,
          lineWidth: 15.0,
          percent: attends / total,
          animation: true,
          center: Text(
              (attends / total * 100).toStringAsFixed(1).replaceAll('.0', '') +
                  '%'),
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
                .bodyText2!
                .copyWith(color: Colors.amber[300]),
          ),
        ),
        ListTile(
          title: Text(absenseLabel ?? 'اجمالي عدد أيام الغياب'),
          trailing: Text(
            (total - attends).toString(),
            style: Theme.of(context)
                .textTheme
                .bodyText2!
                .copyWith(color: Colors.amber[700]),
          ),
        ),
        ListTile(
          title: Text(totalLabel ?? 'الاجمالي'),
          trailing: Text(
            total.toString(),
            style: Theme.of(context)
                .textTheme
                .bodyText2!
                .copyWith(color: Colors.amberAccent),
          ),
        ),
      ],
    );
  }
}

class ClassesAttendanceIndicator extends StatelessWidget {
  ClassesAttendanceIndicator(
      {Key? key,
      required this.collection,
      required this.classes,
      this.isServant = false})
      : super(key: key);

  final List<Class> classes;
  final JsonCollectionRef collection;
  final bool isServant;
  final rnd = RandomColor();
  final Map<String, Color> usedColorsMap = {};

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Person>>(
      stream: Rx.combineLatestList<JsonQuery>(classes
              .split(10)
              .map((c) => collection
                  .where('ClassId', whereIn: c.map((e) => e.ref).toList())
                  .snapshots())
              .toList())
          .map(
              (s) => s.expand((e) => e.docs).map(Person.fromQueryDoc).toList()),
      builder: (context, snapshot) {
        if (snapshot.hasError) return ErrorWidget(snapshot.error!);
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        return StreamBuilder<int>(
          stream: Rx.combineLatestList<JsonQuery>(classes
                  .split(10)
                  .map((c) => isServant
                      ? FirebaseFirestore.instance
                          .collection('UsersData')
                          .where('ClassId',
                              whereIn: c.map((e) => e.ref).toList())
                          .snapshots()
                      : FirebaseFirestore.instance
                          .collection('Persons')
                          .where('ClassId',
                              whereIn: c.map((e) => e.ref).toList())
                          .snapshots())
                  .toList())
              .map((s) => s.fold<int>(0, (o, n) => o + n.size)),
          builder: (context, persons) {
            if (persons.hasError) return ErrorWidget(persons.error!);
            if (!persons.hasData)
              return const Center(child: CircularProgressIndicator());
            if (persons.data == 0)
              return const Center(
                  child: Text('لا يوجد مخدومين في الفصول المحددة'));

            final Map<JsonRef, Class> groupedClasses = {
              for (final c in classes) c.ref: c
            };

            return snapshot.data!.isNotEmpty && classes.length > 1
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
                      PieChart<Class>(
                        total: classes.length,
                        pointColorMapper: (_class, _) =>
                            usedColorsMap[_class.item2.id] ??=
                                _class.item2.color == Colors.transparent
                                    ? rnd.randomColor(
                                        colorBrightness:
                                            Theme.of(context).brightness ==
                                                    Brightness.dark
                                                ? ColorBrightness.dark
                                                : ColorBrightness.light,
                                      )
                                    : _class.item2.color,
                        pieData: groupBy<Person, JsonRef>(
                                snapshot.data!, (p) => p.classId!)
                            .entries
                            .map(
                              (e) => Tuple2<int, Class>(
                                e.value.length,
                                groupedClasses[e.key]!,
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
    Key? key,
    required this.id,
    required this.total,
    required this.range,
    required this.collectionGroup,
    this.label,
    this.attendanceLabel,
    this.absenseLabel,
  }) : super(key: key);

  final String? absenseLabel;
  final String? attendanceLabel;
  final String collectionGroup;
  final String id;
  final String? label;
  final DateTimeRange range;
  final int total;

  Stream<List<JsonQueryDoc>> _getHistoryForUser() {
    return Rx.combineLatest2<User, List<Class>, Tuple2<User, List<Class>>>(
        User.instance.stream,
        Class.getAllForUser(),
        (a, b) => Tuple2<User, List<Class>>(a, b)).switchMap((u) {
      if (u.item1.superAccess) {
        return FirebaseFirestore.instance
            .collectionGroup(collectionGroup)
            .where('ID', isEqualTo: id)
            .where('Time',
                isGreaterThanOrEqualTo: Timestamp.fromDate(range.start))
            .where(
              'Time',
              isLessThan:
                  Timestamp.fromDate(range.end.add(const Duration(days: 1))),
            )
            .orderBy('Time', descending: true)
            .snapshots()
            .map((s) => s.docs);
      } else {
        return Rx.combineLatestList<JsonQuery>(u.item2
                .split(10)
                .map((c) => FirebaseFirestore.instance
                    .collectionGroup(collectionGroup)
                    .where('ClassId', whereIn: c.map((e) => e.ref).toList())
                    .where('ID', isEqualTo: id)
                    .where(
                      'Time',
                      isLessThan: Timestamp.fromDate(
                          range.end.add(const Duration(days: 1))),
                    )
                    .where('Time',
                        isGreaterThanOrEqualTo: Timestamp.fromDate(range.start))
                    .orderBy('Time', descending: true)
                    .snapshots())
                .toList())
            .map((s) => s.expand((n) => n.docs).toList());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<JsonQueryDoc>>(
      stream: _getHistoryForUser(),
      builder: (context, history) {
        if (history.hasError) return ErrorWidget(history.error!);
        if (!history.hasData)
          return const Center(child: CircularProgressIndicator());
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
    Key? key,
    required this.range,
    required this.classes,
    required this.classesByRef,
    required this.collectionGroup,
    required this.title,
    this.showUsers = true,
  }) : super(key: key);

  final List<Class> classes;
  final Map<String, Class> classesByRef;
  final String collectionGroup;
  final DateTimeRange range;
  final rnd = RandomColor();
  final bool showUsers;
  final String title;
  final Map<Tuple2<int, String?>, Color> usedColorsMap =
      <Tuple2<int, String?>, Color>{};

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<JsonQueryDoc>>(
      stream: MinimalHistoryRecord.getAllForUser(
          collectionGroup: collectionGroup, range: range, classes: classes),
      builder: (context, daysData) {
        if (daysData.hasError) return ErrorWidget(daysData.error!);
        if (!daysData.hasData)
          return const Center(child: CircularProgressIndicator());
        if (daysData.data!.isEmpty)
          return const Center(child: Text('لا يوجد سجل'));

        final List<MinimalHistoryRecord> data =
            daysData.data!.map(MinimalHistoryRecord.fromQueryDoc).toList();

        mergeSort(data,
            compare: (dynamic o, dynamic n) => o.time.millisecondsSinceEpoch
                .compareTo(n.time.millisecondsSinceEpoch));
        final Map<Timestamp, List<MinimalHistoryRecord>> groupedData =
            groupBy<MinimalHistoryRecord, Timestamp>(
                data, (d) => tranucateToDay(time: d.time.toDate()));

        final list =
            groupBy<MinimalHistoryRecord, String>(data, (s) => s.classId!.path)
                .entries
                .toList();
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CartesianChart(
              title: title,
              classes: classes,
              range: range,
              data: groupedData,
              showMax: false,
            ),
            ListTile(
              title: Center(child: Text('تحليل ' + title + ' لكل فصل')),
            ),
            PieChart<String?>(
              total: data.length,
              pieData: list
                  .map((e) => Tuple2<int, String?>(
                      e.value.length, classesByRef[e.key]?.name))
                  .toList(),
              pointColorMapper: (entry, __) => usedColorsMap[entry] ??=
                  (classesByRef[entry.item2!]?.color == null ||
                          classesByRef[entry.item2!]?.color ==
                              Colors.transparent
                      ? rnd.randomColor(
                          colorBrightness:
                              Theme.of(context).brightness == Brightness.dark
                                  ? ColorBrightness.dark
                                  : ColorBrightness.light,
                        )
                      : classesByRef[entry.item2!]?.color)!,
            ),
            if (showUsers)
              ListTile(
                title: Center(child: Text('تحليل ' + title + ' لكل خادم')),
              ),
            if (showUsers)
              FutureBuilder<List<User>>(
                future: User.getAllNames().first,
                builder: (context, usersData) {
                  if (usersData.hasError) return ErrorWidget(usersData.error!);
                  if (!usersData.hasData)
                    return const Center(child: CircularProgressIndicator());
                  final usersByID = {for (var u in usersData.data!) u.refId: u};
                  final pieData =
                      groupBy<MinimalHistoryRecord, String?>(data, (s) => s.by)
                          .entries
                          .toList();
                  return PieChart<String?>(
                    pointColorMapper: (entry, __) =>
                        usedColorsMap[entry] ??= rnd.randomColor(
                      colorBrightness:
                          Theme.of(context).brightness == Brightness.dark
                              ? ColorBrightness.dark
                              : ColorBrightness.light,
                    ),
                    total: data.length,
                    pieData: pieData
                        .map((e) => Tuple2<int, String?>(
                            e.value.length, usersByID[e.key!]?.name))
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
  const CartesianChart(
      {Key? key,
      required this.classes,
      required this.range,
      this.showMax = false,
      required this.data,
      required this.title})
      : super(key: key);

  final List<Class> classes;
  final Map<Timestamp, List<T>> data;
  final DateTimeRange range;
  final bool showMax;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18.0),
      child: StreamBuilder<List<Person>?>(
        stream: showMax
            ? Rx.combineLatestList<List<Person>>(
                classes.split(10).map(
                      (c) => FirebaseFirestore.instance
                          .collection('Persons')
                          .where('ClassId',
                              whereIn: c.map((e) => e.ref).toList())
                          .snapshots()
                          .map(
                            (s) => s.docs.map(Person.fromQueryDoc).toList(),
                          ),
                    ),
              ).map((p) => p.expand((o) => o).toList())
            : Stream.value(null),
        builder: (context, persons) {
          if (data.isEmpty) return const Center(child: Text('لا يوجد سجل'));
          if (persons.hasError) return ErrorWidget(persons.error!);
          if (!persons.hasData && showMax)
            return const Center(child: CircularProgressIndicator.adaptive());

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.headline6,
                ),
              ),
              Directionality(
                textDirection: TextDirection.ltr,
                child: SfCartesianChart(
                  enableAxisAnimation: true,
                  primaryYAxis: NumericAxis(
                      decimalPlaces: 0,
                      maximum: persons.data?.length.toDouble()),
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
                            Text(intl.DateFormat('yyy/M/d', 'ar-EG')
                                .format(data.key.toDate())),
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
                          Colors.amber[800]!.withOpacity(0.5)
                        ],
                      ),
                      gradient: LinearGradient(
                        colors: [
                          Colors.amber[300]!.withOpacity(0.5),
                          Colors.amber[800]!.withOpacity(0.5)
                        ],
                      ),
                      borderWidth: 2,
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
  PieChart({
    Key? key,
    required this.total,
    required this.pieData,
    this.nameGetter,
    this.pointColorMapper,
  })  : assert(nameGetter != null || T == String || null is T),
        super(key: key);

  final Color Function(Tuple2<int, T>, int)? pointColorMapper;
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
        legend: Legend(
          isVisible: true,
          position: LegendPosition.bottom,
          overflowMode: LegendItemOverflowMode.scroll,
          orientation: LegendItemOrientation.vertical,
          isResponsive: true,
          alignment: ChartAlignment.center,
        ),
        series: [
          PieSeries<Tuple2<int, T>, String>(
              enableTooltip: true,
              enableSmartLabels: true,
              dataLabelMapper: (entry, _) =>
                  (_getName(entry.item2) ?? 'غير معروف') +
                  ': ' +
                  (entry.item1 / total * 100).toStringAsFixed(2) +
                  '%',
              pointColorMapper: pointColorMapper,
              dataSource: pieData.sorted((n, o) => o.item1.compareTo(n.item1)),
              xValueMapper: (entry, _) => _getName(entry.item2) ?? 'غير معروف',
              yValueMapper: (entry, _) => entry.item1),
        ],
      ),
    );
  }
}
