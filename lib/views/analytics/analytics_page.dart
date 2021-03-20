import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart';
import 'package:meetinghelper/models/history_property.dart';
import 'package:meetinghelper/models/models.dart';
import 'package:meetinghelper/utils/globals.dart';
import 'package:meetinghelper/utils/helpers.dart';

import 'analytics_indicators.dart';

class ClassAnalyticsPage extends StatefulWidget {
  final Class class$;
  ClassAnalyticsPage({Key key, this.class$}) : super(key: key);

  @override
  _ClassAnalyticsPageState createState() => _ClassAnalyticsPageState();
}

class HistoryDayAnalyticsPage extends StatefulWidget {
  final HistoryDay day;
  HistoryDayAnalyticsPage({Key key, this.day}) : super(key: key);

  @override
  _HistoryDayAnalyticsPageState createState() =>
      _HistoryDayAnalyticsPageState();
}

class GeneralAnalyticsPage extends StatefulWidget {
  GeneralAnalyticsPage({Key key}) : super(key: key);

  @override
  _GeneralAnalyticsPageState createState() => _GeneralAnalyticsPageState();
}

class PersonAnalyticsPage extends StatefulWidget {
  final Person person;
  PersonAnalyticsPage({Key key, this.person}) : super(key: key);

  @override
  _PersonAnalyticsPageState createState() => _PersonAnalyticsPageState();
}

class _ClassAnalyticsPageState extends State<ClassAnalyticsPage> {
  DateTimeRange range = DateTimeRange(
      start: DateTime.now().subtract(Duration(days: 30)), end: DateTime.now());
  DateTime minAvaliable = DateTime.now().subtract(Duration(days: 30));
  final _screenKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      key: _screenKey,
      child: Scaffold(
        appBar: AppBar(
          title: Text('الاحصائيات'),
          actions: [
            IconButton(
              icon: Icon(Icons.mobile_screen_share),
              onPressed: () => takeScreenshot(_screenKey),
              tooltip: 'حفظ كصورة',
            ),
          ],
        ),
        body: FutureBuilder(
          future: _setRangeStart(),
          builder: (context, _) {
            if (_.connectionState == ConnectionState.done) {
              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('History')
                    .orderBy('Day')
                    .where(
                      'Day',
                      isLessThanOrEqualTo:
                          Timestamp.fromDate(range.end.add(Duration(days: 1))),
                    )
                    .where('Day',
                        isGreaterThanOrEqualTo: Timestamp.fromDate(
                            range.start.subtract(Duration(days: 1))))
                    .snapshots(),
                builder: (context, daysData) {
                  if (daysData.hasError) return ErrorWidget(daysData.error);
                  if (daysData.connectionState == ConnectionState.waiting)
                    return const Center(child: CircularProgressIndicator());
                  if (daysData.data.docs.isEmpty)
                    return const Center(child: Text('لا يوجد سجل'));
                  var days = daysData.data.docs
                      .map((o) => HistoryDay.fromDoc(o))
                      .toList();

                  return ListView(
                    children: [
                      ListTile(
                        title: Text(
                            'احصائيات الحضور من ' +
                                DateFormat.yMMMEd('ar_EG').format(range.start) +
                                ' الى ' +
                                DateFormat.yMMMEd('ar_EG').format(range.end),
                            style: Theme.of(context).textTheme.bodyText1),
                        trailing: IconButton(
                          icon: Icon(Icons.date_range),
                          tooltip: 'اختيار نطاق السجل',
                          onPressed: () async {
                            var rslt = await showDateRangePicker(
                              builder: (context, dialog) => Theme(
                                data: Theme.of(context).copyWith(
                                  textTheme:
                                      Theme.of(context).textTheme.copyWith(
                                            overline: TextStyle(
                                              fontSize: 0,
                                            ),
                                          ),
                                ),
                                child: dialog,
                              ),
                              helpText: null,
                              context: context,
                              confirmText: 'حفظ',
                              saveText: 'حفظ',
                              initialDateRange: range,
                              firstDate: minAvaliable,
                              lastDate: DateTime.now(),
                            );
                            if (rslt != null) {
                              range = rslt;
                              setState(() {});
                            }
                          },
                        ),
                      ),
                      AttendanceChart(
                        title: 'حضور الاجتماع',
                        classes: [widget.class$],
                        range: range,
                        days: days,
                        collectionGroup: 'Meeting',
                      ),
                      AttendanceChart(
                        title: 'حضور القداس',
                        classes: [widget.class$],
                        range: range,
                        days: days,
                        collectionGroup: 'Kodas',
                      ),
                      AttendanceChart(
                        title: 'التناول',
                        classes: [widget.class$],
                        range: range,
                        days: days,
                        collectionGroup: 'Tanawol',
                      ),
                    ],
                  );
                },
              );
            } else {
              return const Center(child: CircularProgressIndicator());
            }
          },
        ),
      ),
    );
  }

  Future<void> _setRangeStart() async {
    minAvaliable = ((await FirebaseFirestore.instance
                .collection('History')
                .orderBy('Day')
                .limit(1)
                .get(dataSource))
            .docs[0]
            .data()['Day'] as Timestamp)
        .toDate();
    range = DateTimeRange(start: minAvaliable, end: DateTime.now());
  }
}

class _HistoryDayAnalyticsPageState extends State<HistoryDayAnalyticsPage> {
  List<Class> classes;
  final _screenKey = GlobalKey();
  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      key: _screenKey,
      child: Scaffold(
        appBar: AppBar(
          title: Text('الاحصائيات'),
          actions: [
            IconButton(
              icon: Icon(Icons.mobile_screen_share),
              onPressed: () => takeScreenshot(_screenKey),
              tooltip: 'حفظ كصورة',
            ),
          ],
        ),
        body: StreamBuilder<QuerySnapshot>(
          stream: Class.getAllForUser(),
          builder: (context, snapshot) {
            if (snapshot.hasError) return ErrorWidget(snapshot.error);
            if (!snapshot.hasData)
              return const Center(child: CircularProgressIndicator());
            classes ??=
                snapshot.data.docs.map((c) => Class.fromDoc(c)).toList();
            return ListView(
              children: [
                ListTile(
                  title: Text('احصائيات الحضور ليوم ' +
                      DateFormat.yMMMEd('ar_EG')
                          .format(widget.day.day.toDate())),
                ),
                ListTile(
                  title: Text('لفصول: '),
                  subtitle: Text(
                    classes.map((c) => c.name).toList().join(', '),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: IconButton(
                    icon: Icon(Icons.list_alt),
                    tooltip: 'اختيار الفصول',
                    onPressed: () async {
                      var rslt = await selectClasses(context, classes);
                      if (rslt != null && rslt.isNotEmpty)
                        setState(() => classes = rslt);
                      else
                        await showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                                content: Text('برجاء اختيار فصل على الأقل')));
                    },
                  ),
                ),
                ListTile(
                  title: Text('حضور الاجتماع'),
                ),
                ClassesAttendanceIndicator(
                  classes: classes,
                  collection: widget.day.meeting,
                ),
                ListTile(
                  title: Text('حضور القداس'),
                ),
                ClassesAttendanceIndicator(
                  classes: classes,
                  collection: widget.day.kodas,
                ),
                ListTile(
                  title: Text('التناول'),
                ),
                ClassesAttendanceIndicator(
                  classes: classes,
                  collection: widget.day.tanawol,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _PersonAnalyticsPageState extends State<PersonAnalyticsPage> {
  DateTimeRange range = DateTimeRange(
      start: DateTime.now().subtract(Duration(days: 30)), end: DateTime.now());
  DateTime minAvaliable = DateTime.now().subtract(Duration(days: 30));
  final _screenKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      key: _screenKey,
      child: Scaffold(
        appBar: AppBar(
          title: Text('الاحصائيات'),
          actions: [
            IconButton(
              icon: Icon(Icons.mobile_screen_share),
              onPressed: () => takeScreenshot(_screenKey),
              tooltip: 'حفظ كصورة',
            ),
          ],
        ),
        body: FutureBuilder(
          future: _setRangeStart(),
          builder: (context, _) {
            if (_.connectionState != ConnectionState.done)
              return const Center(child: CircularProgressIndicator());
            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('History')
                  .orderBy('Day')
                  .where(
                    'Day',
                    isLessThanOrEqualTo:
                        Timestamp.fromDate(range.end.add(Duration(days: 1))),
                  )
                  .where('Day',
                      isGreaterThanOrEqualTo: Timestamp.fromDate(
                          range.start.subtract(Duration(days: 1))))
                  .snapshots(),
              builder: (context, data) {
                if (data.hasError) return ErrorWidget(data.error);
                if (!data.hasData)
                  return const Center(child: CircularProgressIndicator());
                if (data.data.docs.isEmpty)
                  return const Center(child: Text('لا يوجد سجل'));
                return ListView(
                  children: [
                    ListTile(
                      title: Text(
                          'احصائيات الحضور من ' +
                              DateFormat.yMMMEd('ar_EG').format(range.start) +
                              ' الى ' +
                              DateFormat.yMMMEd('ar_EG').format(range.end),
                          style: Theme.of(context).textTheme.bodyText1),
                      trailing: IconButton(
                        icon: Icon(Icons.date_range),
                        tooltip: 'اختيار نطاق السجل',
                        onPressed: () async {
                          var rslt = await showDateRangePicker(
                            builder: (context, dialog) => Theme(
                              data: Theme.of(context).copyWith(
                                textTheme: Theme.of(context).textTheme.copyWith(
                                      overline: TextStyle(
                                        fontSize: 0,
                                      ),
                                    ),
                              ),
                              child: dialog,
                            ),
                            helpText: null,
                            context: context,
                            confirmText: 'حفظ',
                            saveText: 'حفظ',
                            initialDateRange: range,
                            firstDate: minAvaliable,
                            lastDate: DateTime.now(),
                          );
                          if (rslt != null) {
                            range = rslt;
                            setState(() {});
                          }
                        },
                      ),
                    ),
                    PersonAttendanceIndicator(
                      id: widget.person.id,
                      range: range,
                      total: data.data.size,
                      collectionGroup: 'Meeting',
                      label: 'حضور الاجتماع',
                    ),
                    DayHistoryProperty('تاريخ أخر حضور اجتماع:',
                        widget.person.lastMeeting, widget.person.id, 'Meeting'),
                    Container(height: 10),
                    PersonAttendanceIndicator(
                      id: widget.person.id,
                      range: range,
                      total: data.data.size,
                      collectionGroup: 'Kodas',
                      label: 'حضور القداس',
                    ),
                    DayHistoryProperty('تاريخ أخر حضور قداس:',
                        widget.person.lastKodas, widget.person.id, 'Kodas'),
                    Container(height: 10),
                    PersonAttendanceIndicator(
                      id: widget.person.id,
                      range: range,
                      total: data.data.size,
                      collectionGroup: 'Tanawol',
                      label: 'التناول',
                    ),
                    DayHistoryProperty('تاريخ أخر تناول:',
                        widget.person.lastTanawol, widget.person.id, 'Tanawol'),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  Future<void> _setRangeStart() async {
    minAvaliable = ((await FirebaseFirestore.instance
                .collection('History')
                .orderBy('Day')
                .limit(1)
                .get(dataSource))
            .docs[0]
            .data()['Day'] as Timestamp)
        .toDate();
    range = DateTimeRange(start: minAvaliable, end: DateTime.now());
  }
}

class _GeneralAnalyticsPageState extends State<GeneralAnalyticsPage> {
  List<Class> classes;
  DateTimeRange range = DateTimeRange(
      start: DateTime.now().subtract(Duration(days: 30)), end: DateTime.now());
  DateTime minAvaliable = DateTime.now().subtract(Duration(days: 30));
  final _screenKey = GlobalKey();

  Future<void> _setRangeStart() async {
    minAvaliable = ((await FirebaseFirestore.instance
                .collection('History')
                .orderBy('Day')
                .limit(1)
                .get(dataSource))
            .docs[0]
            .data()['Day'] as Timestamp)
        .toDate();
    range = DateTimeRange(start: minAvaliable, end: DateTime.now());
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      key: _screenKey,
      child: Scaffold(
        appBar: AppBar(
          title: Text('الاحصائيات'),
          actions: [
            IconButton(
              icon: Icon(Icons.mobile_screen_share),
              onPressed: () => takeScreenshot(_screenKey),
              tooltip: 'حفظ كصورة',
            ),
          ],
        ),
        body: FutureBuilder(
          future: _setRangeStart(),
          builder: (context, _) {
            if (_.connectionState == ConnectionState.done) {
              return StreamBuilder<QuerySnapshot>(
                stream: Class.getAllForUser(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) return ErrorWidget(snapshot.error);
                  if (!snapshot.hasData)
                    return const Center(child: CircularProgressIndicator());
                  classes ??=
                      snapshot.data.docs.map((c) => Class.fromDoc(c)).toList();
                  return StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('History')
                        .orderBy('Day')
                        .where(
                          'Day',
                          isLessThanOrEqualTo: Timestamp.fromDate(
                              range.end.add(Duration(days: 1))),
                        )
                        .where('Day',
                            isGreaterThanOrEqualTo: Timestamp.fromDate(
                                range.start.subtract(Duration(days: 1))))
                        .snapshots(),
                    builder: (context, daysData) {
                      if (daysData.hasError) return ErrorWidget(daysData.error);
                      if (!daysData.hasData)
                        return const Center(child: CircularProgressIndicator());
                      if (daysData.data.docs.isEmpty)
                        return const Center(child: Text('لا يوجد سجل'));
                      var days = daysData.data.docs
                          .map((o) => HistoryDay.fromDoc(o))
                          .toList();
                      return ListView(
                        children: [
                          ListTile(
                            title: Text(
                                'احصائيات الحضور من ' +
                                    DateFormat.yMMMEd('ar_EG')
                                        .format(range.start) +
                                    ' الى ' +
                                    DateFormat.yMMMEd('ar_EG')
                                        .format(range.end),
                                style: Theme.of(context).textTheme.bodyText1),
                            trailing: IconButton(
                              icon: Icon(Icons.date_range),
                              tooltip: 'اختيار نطاق السجل',
                              onPressed: () async {
                                var rslt = await showDateRangePicker(
                                  builder: (context, dialog) => Theme(
                                    data: Theme.of(context).copyWith(
                                      textTheme:
                                          Theme.of(context).textTheme.copyWith(
                                                overline: TextStyle(
                                                  fontSize: 0,
                                                ),
                                              ),
                                    ),
                                    child: dialog,
                                  ),
                                  helpText: null,
                                  context: context,
                                  confirmText: 'حفظ',
                                  saveText: 'حفظ',
                                  initialDateRange: range
                                              .start.millisecondsSinceEpoch <=
                                          minAvaliable.millisecondsSinceEpoch
                                      ? range
                                      : DateTimeRange(
                                          start: DateTime.now()
                                              .subtract(Duration(days: 1)),
                                          end: range.end),
                                  firstDate: minAvaliable,
                                  lastDate: DateTime.now(),
                                );
                                if (rslt != null) {
                                  range = rslt;
                                  setState(() {});
                                }
                              },
                            ),
                          ),
                          ListTile(
                            title: Text('لفصول: '),
                            subtitle: Text(
                              classes.map((c) => c.name).toList().join(', '),
                              maxLines: 4,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: IconButton(
                              icon: Icon(Icons.list_alt),
                              tooltip: 'اختيار الفصول',
                              onPressed: () async {
                                var rslt =
                                    await selectClasses(context, classes);
                                if (rslt != null && rslt.isNotEmpty)
                                  setState(() => classes = rslt);
                                else
                                  await showDialog(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                          content: Text(
                                              'برجاء اختيار فصل على الأقل')));
                              },
                            ),
                          ),
                          AttendanceChart(
                            title: 'حضور الاجتماع',
                            classes: classes,
                            range: range,
                            days: days,
                            collectionGroup: 'Meeting',
                          ),
                          AttendanceChart(
                            title: 'حضور القداس',
                            classes: classes,
                            range: range,
                            days: days,
                            collectionGroup: 'Kodas',
                          ),
                          AttendanceChart(
                            title: 'التناول',
                            classes: classes,
                            range: range,
                            days: days,
                            collectionGroup: 'Tanawol',
                          ),
                        ],
                      );
                    },
                  );
                },
              );
            } else {
              return const CircularProgressIndicator();
            }
          },
        ),
      ),
    );
  }
}

void takeScreenshot(GlobalKey key) async {
  RenderRepaintBoundary boundary = key.currentContext.findRenderObject();
  WidgetsBinding.instance.addPostFrameCallback(
    (_) async {
      ui.Image image = await boundary.toImage(pixelRatio: 2);
      ByteData byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      Uint8List pngBytes = byteData.buffer.asUint8List();
      await Share.shareFiles(
        [
          (await (await File((await getApplicationDocumentsDirectory()).path +
                          DateTime.now().millisecondsSinceEpoch.toString() +
                          '.png')
                      .create())
                  .writeAsBytes(pngBytes.toList()))
              .path
        ],
      );
    },
  );
}
