import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:collection/collection.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:meetinghelper/models/models.dart';
import 'package:meetinghelper/models/user.dart';
import 'package:meetinghelper/utils/globals.dart';
import 'package:meetinghelper/utils/helpers.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:rxdart/rxdart.dart';

class AttendanceChart extends StatelessWidget {
  final List<Class> classes;
  final DateTimeRange range;
  final String collectionGroup;
  final List<HistoryDay> days;

  AttendanceChart({this.classes, this.range, this.days, this.collectionGroup});

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
          if (history.connectionState != ConnectionState.active)
            return const Center(child: CircularProgressIndicator());
          if (history.data.isEmpty)
            return const Center(child: Text('لا يوجد سجل'));
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
              if (persons.connectionState != ConnectionState.active)
                return const Center(child: CircularProgressIndicator());
              double maxY = persons.data.length.toDouble();
              var spots = historyMap.values
                  .mapIndexed(
                      (i, d) => FlSpot(i.toDouble(), d.length.toDouble()))
                  .toList();
              return LineChart(
                LineChartData(
                  axisTitleData: FlAxisTitleData(
                      topTitle: AxisTitle(titleText: 'حضور الاجتماع')),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: true,
                    checkToShowHorizontalLine: (v) => v % (maxY ~/ 5) == 0,
                    getDrawingHorizontalLine: (value) {
                      return FlLine(
                        color: Colors.grey,
                        strokeWidth: 1,
                      );
                    },
                    getDrawingVerticalLine: (value) {
                      return FlLine(
                        color: Colors.grey,
                        strokeWidth: 1,
                      );
                    },
                    horizontalInterval: (maxY ~/ 5).toDouble(),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: SideTitles(
                      rotateAngle: 90,
                      showTitles: true,
                      getTitles: (v) {
                        return DateFormat.yMd('ar-EG')
                            .format(days[v.toInt()].day.toDate());
                      },
                      getTextStyles: (value) =>
                          Theme.of(context).textTheme.overline.copyWith(
                                color: Theme.of(context)
                                    .textTheme
                                    .overline
                                    .color
                                    .withOpacity(0.5),
                              ),
                      reservedSize: 55,
                    ),
                    leftTitles: SideTitles(
                      showTitles: true,
                      interval: (maxY ~/ 5).toDouble(),
                      getTextStyles: (value) =>
                          Theme.of(context).textTheme.overline.copyWith(
                                color: Theme.of(context)
                                    .textTheme
                                    .overline
                                    .color
                                    .withOpacity(0.5),
                              ),
                      reservedSize: 22,
                    ),
                  ),
                  borderData: FlBorderData(
                    show: true,
                    border: Border.all(color: Colors.grey, width: 1),
                  ),
                  minX: 0,
                  maxX: (days.length - 1).toDouble(),
                  minY: 0,
                  maxY: maxY.toDouble(),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      colorStops: [0, 1],
                      colors: [Colors.amber[300], Colors.amber[800]],
                      isStrokeCapRound: true,
                      dotData: FlDotData(
                        show: false,
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        gradientColorStops: [0, 1],
                        colors: [Colors.amber[300], Colors.amber[800]]
                            .map((color) => color.withOpacity(0.3))
                            .toList(),
                      ),
                    ),
                  ],
                ),
                swapAnimationDuration: Duration(milliseconds: 200),
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

  final double percent;
  final String attendanceLabel;
  final String absenseLabel;
  final int total;
  final int attends;
  AttendancePercent({
    Key key,
    this.label,
    this.percent,
    this.attendanceLabel,
    this.absenseLabel,
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
          percent: percent,
          animation: true,
          center: Text(
              (percent * 100).toStringAsFixed(1).replaceAll('.0', '') + '%'),
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
        if (snapshot.connectionState != ConnectionState.active)
          return const Center(child: CircularProgressIndicator());
        return StreamBuilder<int>(
          stream: Rx.combineLatestList<QuerySnapshot>(
                  classes.map((c) => c.getMembersLive()).toList())
              .map((s) => s.fold<int>(0, (o, n) => o + n.size)),
          builder: (context, persons) {
            if (persons.hasError) return ErrorWidget(persons.error);
            if (persons.connectionState != ConnectionState.active)
              return const Center(child: CircularProgressIndicator());
            if (persons.data == 0)
              return const Center(
                  child: Text('لا يوجد مخدومين في الفصول المحددة'));

            var percent = snapshot.data / persons.data;

            return Column(
              children: [
                CircularPercentIndicator(
                  radius: 160.0,
                  lineWidth: 15.0,
                  percent: percent,
                  animation: true,
                  center: Text(
                      (percent * 100).toStringAsFixed(1).replaceAll('.0', '') +
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
                  title: Text('اجمالي عدد الحاضرين'),
                  trailing: Text(
                    snapshot.data.toString(),
                    style: Theme.of(context)
                        .textTheme
                        .bodyText2
                        .copyWith(color: Colors.amber[300]),
                  ),
                ),
                ListTile(
                  title: Text('اجمالي عدد الغياب'),
                  trailing: Text(
                    (persons.data - snapshot.data).toString(),
                    style: Theme.of(context)
                        .textTheme
                        .bodyText2
                        .copyWith(color: Colors.amber[700]),
                  ),
                ),
              ],
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
    return StreamBuilder<QuerySnapshot>(
      stream: getHistoryForUser(),
      builder: (context, history) {
        if (history.hasError) return ErrorWidget(history.error);
        if (history.connectionState != ConnectionState.active)
          return const Center(child: CircularProgressIndicator());
        final double percent = history.data.size / total;
        return AttendancePercent(
          label: label,
          percent: percent,
          attendanceLabel: attendanceLabel,
          absenseLabel: absenseLabel,
          total: total,
          attends: history.data.size,
        );
      },
    );
  }

  Stream<QuerySnapshot> getHistoryForUser() async* {
    await for (var u in User.instance.stream) {
      if (u.superAccess) {
        await for (var s in FirebaseFirestore.instance
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
            .snapshots()) yield s;
      } else {
        await for (var s in FirebaseFirestore.instance
            .collectionGroup(collectionGroup)
            .where('ClassId',
                whereIn: (await FirebaseFirestore.instance
                        .collection('Classes')
                        .where('Allowed',
                            arrayContains:
                                auth.FirebaseAuth.instance.currentUser.uid)
                        .get(dataSource))
                    .docs
                    .map((e) => e.reference)
                    .toList())
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
            .snapshots()) yield s;
      }
    }
  }
}
