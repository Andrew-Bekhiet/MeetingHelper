import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:meetinghelper/models/models.dart';
import 'package:meetinghelper/models/user.dart';
import 'package:meetinghelper/utils/globals.dart';
import 'package:meetinghelper/utils/helpers.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:rxdart/rxdart.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:tuple/tuple.dart';

class AttendanceChart extends StatelessWidget {
  final List<Class> classes;
  final DateTimeRange range;
  final String collectionGroup;
  final String title;
  final List<HistoryDay> days;

  AttendanceChart(
      {Key key,
      this.classes,
      this.range,
      this.days,
      this.collectionGroup,
      @required this.title})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18.0),
      child: StreamBuilder<List<QueryDocumentSnapshot>>(
        stream: Rx.combineLatestList<QuerySnapshot>(classes
                .map((c) => FirebaseFirestore.instance
                    .collectionGroup(collectionGroup)
                    .where('ClassId', isEqualTo: c.ref)
                    .where(
                      'Time',
                      isLessThanOrEqualTo:
                          Timestamp.fromDate(range.end.add(Duration(days: 1))),
                    )
                    .where('Time',
                        isGreaterThanOrEqualTo: Timestamp.fromDate(
                            range.start.subtract(Duration(days: 1))))
                    .orderBy('Time', descending: true)
                    .snapshots())
                .toList())
            .map((s) => s.expand((n) => n.docs).toList()),
        builder: (context, history) {
          if (history.hasError) return ErrorWidget(history.error);
          if (!history.hasData)
            return const Center(child: CircularProgressIndicator());
          if (history.data.isEmpty)
            return const Center(child: Text('لا يوجد سجل'));
          mergeSort(history.data,
              compare: (o, n) => (o.data()['Time'] as Timestamp)
                  .millisecondsSinceEpoch
                  .compareTo(
                      (n.data()['Time'] as Timestamp).millisecondsSinceEpoch));
          Map<Timestamp, List<QueryDocumentSnapshot>> historyMap =
              groupBy<QueryDocumentSnapshot, Timestamp>(
                  history.data,
                  (d) => tranucateToDay(
                      time: (d.data()['Time'] as Timestamp).toDate()));
          return StreamBuilder<List<QueryDocumentSnapshot>>(
            stream: Rx.combineLatestList<QuerySnapshot>(
                    classes.map((c) => c.getMembersLive()))
                .map((p) => p.expand((o) => o.docs).toList()),
            builder: (context, persons) {
              if (persons.hasError) return ErrorWidget(persons.error);
              if (!persons.hasData)
                return const Center(child: CircularProgressIndicator());
              return Directionality(
                textDirection: TextDirection.ltr,
                child: SfCartesianChart(
                  title: ChartTitle(text: title),
                  enableAxisAnimation: true,
                  primaryYAxis: NumericAxis(
                      maximum: persons.data.length.toDouble(),
                      decimalPlaces: 0),
                  primaryXAxis: DateTimeAxis(
                    minimum: range.start,
                    maximum: range.end,
                    dateFormat: intl.DateFormat('d/M/yyy', 'ar-EG'),
                    intervalType: DateTimeIntervalType.days,
                    labelRotation: 90,
                    desiredIntervals: historyMap.keys.length,
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
                          borderRadius: BorderRadius.all(Radius.circular(6.0)),
                        ),
                        height: 120,
                        width: 90,
                        padding: EdgeInsets.symmetric(horizontal: 5),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(intl.DateFormat('d/M/yyy', 'ar-EG')
                                .format(data.key.toDate())),
                            Text(
                              ((data.value.length as int) /
                                          persons.data.length *
                                          100)
                                      .toStringAsFixed(1)
                                      .replaceAll('.0', '') +
                                  '%',
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
                    StackedAreaSeries<
                        MapEntry<Timestamp, List<QueryDocumentSnapshot>>,
                        DateTime>(
                      markerSettings: MarkerSettings(isVisible: true),
                      borderGradient: LinearGradient(
                        colors: [
                          Colors.amber[300].withOpacity(0.5),
                          Colors.amber[800].withOpacity(0.5)
                        ],
                      ),
                      gradient: LinearGradient(
                        colors: [
                          Colors.amber[300].withOpacity(0.5),
                          Colors.amber[800].withOpacity(0.5)
                        ],
                      ),
                      borderWidth: 2,
                      dataSource: historyMap.entries.toList(),
                      xValueMapper: (item, index) => item.key.toDate(),
                      yValueMapper: (item, index) => item.value.length,
                      name: title,
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class AttendancePercent extends StatelessWidget {
  final String label;

  final String attendanceLabel;
  final String absenseLabel;
  final String totalLabel;
  final int total;
  final int attends;

  AttendancePercent({
    Key key,
    this.label,
    this.attendanceLabel,
    this.absenseLabel,
    this.totalLabel,
    this.total,
    this.attends,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircularPercentIndicator(
          header: label != null
              ? ListTile(
                  title: Text(label),
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
              Colors.amber[300],
              Colors.amber[700],
            ],
            stops: [0, 1],
          ),
        ),
        ListTile(
          title: Text(attendanceLabel ?? 'اجمالي عدد أيام الحضور'),
          trailing: Text(
            attends.toString(),
            style: Theme.of(context)
                .textTheme
                .bodyText2
                .copyWith(color: Colors.amber[300]),
          ),
        ),
        ListTile(
          title: Text(absenseLabel ?? 'اجمالي عدد أيام الغياب'),
          trailing: Text(
            (total - attends).toString(),
            style: Theme.of(context)
                .textTheme
                .bodyText2
                .copyWith(color: Colors.amber[700]),
          ),
        ),
        ListTile(
          title: Text(totalLabel ?? 'الاجمالي'),
          trailing: Text(
            total.toString(),
            style: Theme.of(context)
                .textTheme
                .bodyText2
                .copyWith(color: Colors.amberAccent),
          ),
        ),
      ],
    );
  }
}

class ClassesAttendanceIndicator extends StatelessWidget {
  final CollectionReference collection;

  final List<Class> classes;
  ClassesAttendanceIndicator({this.collection, this.classes});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: Rx.combineLatestList<QuerySnapshot>(classes
              .map((c) =>
                  collection.where('ClassId', isEqualTo: c.ref).snapshots())
              .toList())
          .map((s) => s.fold<int>(0, (o, n) => o + n.size)),
      builder: (context, snapshot) {
        if (snapshot.hasError) return ErrorWidget(snapshot.error);
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        return StreamBuilder<int>(
          stream: Rx.combineLatestList<QuerySnapshot>(
                  classes.map((c) => c.getMembersLive()).toList())
              .map((s) => s.fold<int>(0, (o, n) => o + n.size)),
          builder: (context, persons) {
            if (persons.hasError) return ErrorWidget(persons.error);
            if (!persons.hasData)
              return const Center(child: CircularProgressIndicator());
            if (persons.data == 0)
              return const Center(
                  child: Text('لا يوجد مخدومين في الفصول المحددة'));

            return AttendancePercent(
              attendanceLabel: 'اجمالي عدد الحضور',
              absenseLabel: 'اجمالي عدد الغياب',
              totalLabel: 'اجمالي عدد المخدومين',
              attends: snapshot.data,
              total: persons.data,
            );
          },
        );
      },
    );
  }
}

class PersonAttendanceIndicator extends StatelessWidget {
  final String id;

  final String collectionGroup;
  final String label;
  final String attendanceLabel;
  final String absenseLabel;
  final DateTimeRange range;
  final int total;
  PersonAttendanceIndicator({
    Key key,
    this.id,
    this.total,
    this.range,
    this.collectionGroup,
    this.label,
    this.attendanceLabel,
    this.absenseLabel,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<QueryDocumentSnapshot>>(
      stream: _getHistoryForUser(),
      builder: (context, history) {
        if (history.hasError) return ErrorWidget(history.error);
        if (!history.hasData)
          return const Center(child: CircularProgressIndicator());
        return AttendancePercent(
          label: label,
          attendanceLabel: attendanceLabel,
          absenseLabel: absenseLabel,
          total: total,
          attends: history.data.length,
        );
      },
    );
  }

  Stream<List<QueryDocumentSnapshot>> _getHistoryForUser() {
    return Rx.combineLatest2<User, List<Class>, Tuple2<User, List<Class>>>(
        User.instance.stream,
        Class.getAllForUser().map((s) => s.docs.map(Class.fromDoc).toList()),
        (a, b) => Tuple2<User, List<Class>>(a, b)).switchMap((u) {
      if (u.item1.superAccess) {
        return FirebaseFirestore.instance
            .collectionGroup(collectionGroup)
            .where('ID', isEqualTo: id)
            .where(
              'Time',
              isLessThanOrEqualTo:
                  Timestamp.fromDate(range.end.add(Duration(days: 1))),
            )
            .where('Time',
                isGreaterThanOrEqualTo:
                    Timestamp.fromDate(range.start.subtract(Duration(days: 1))))
            .orderBy('Time', descending: true)
            .snapshots()
            .map((s) => s.docs);
      } else {
        return Rx.combineLatestList<QuerySnapshot>(u.item2
                .map((c) => FirebaseFirestore.instance
                    .collectionGroup(collectionGroup)
                    .where('ClassId', isEqualTo: c.ref)
                    .where('ID', isEqualTo: id)
                    .where(
                      'Time',
                      isLessThanOrEqualTo:
                          Timestamp.fromDate(range.end.add(Duration(days: 1))),
                    )
                    .where('Time',
                        isGreaterThanOrEqualTo: Timestamp.fromDate(
                            range.start.subtract(Duration(days: 1))))
                    .orderBy('Time', descending: true)
                    .snapshots())
                .toList())
            .map((s) => s.expand((n) => n.docs).toList());
      }
    });
  }
}
