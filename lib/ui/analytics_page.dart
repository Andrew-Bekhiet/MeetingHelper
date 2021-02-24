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
  final HistoryDay day;
  GeneralAnalyticsPage({Key key, this.day}) : super(key: key);

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
  DateTimeRange range =
      DateTimeRange(start: DateTime(2020), end: DateTime.now());
  var minAvaliable;
  var globalKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('الاحصائيات'),
        actions: [
          IconButton(
            icon: Icon(Icons.mobile_screen_share),
            onPressed: () async {
              RenderRepaintBoundary boundary =
                  globalKey.currentContext.findRenderObject();
              ui.Image image = await boundary.toImage();
              ByteData byteData =
                  await image.toByteData(format: ui.ImageByteFormat.png);
              Uint8List pngBytes = byteData.buffer.asUint8List();
              await Share.shareFiles([
                (await (await File((await getApplicationDocumentsDirectory())
                                    .path +
                                DateTime.now()
                                    .millisecondsSinceEpoch
                                    .toString() +
                                '.png')
                            .create())
                        .writeAsBytes(pngBytes.toList()))
                    .path
              ]);
              ;
            },
            tooltip: 'حفظ كصورة',
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        key: globalKey,
        stream: FirebaseFirestore.instance
            .collection('History')
            .orderBy('Day', descending: true)
            .where(
              'Day',
              isLessThanOrEqualTo:
                  Timestamp.fromDate(range.end.add(Duration(days: 1))),
            )
            .where('Day',
                isGreaterThanOrEqualTo:
                    Timestamp.fromDate(range.start.subtract(Duration(days: 1))))
            .snapshots(),
        builder: (context, daysData) {
          if (daysData.hasError) return ErrorWidget(daysData.error);
          if (daysData.connectionState == ConnectionState.waiting)
            return const Center(child: CircularProgressIndicator());
          if (daysData.data.docs.isEmpty)
            return const Center(child: Text('لا يوجد سجل'));
          var days =
              daysData.data.docs.map((o) => HistoryDay.fromDoc(o)).toList();

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
                        child: dialog,
                        data: Theme.of(context).copyWith(
                          textTheme: Theme.of(context).textTheme.copyWith(
                                overline: TextStyle(
                                  fontSize: 0,
                                ),
                              ),
                        ),
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
              ListTile(
                title: Text('حضور الاجتماع'),
              ),
              AttendanceChart(
                classes: [widget.class$],
                range: range,
                days: days,
                collectionGroup: 'Meeting',
              ),
              ListTile(
                title: Text('حضور القداس'),
              ),
              AttendanceChart(
                classes: [widget.class$],
                range: range,
                days: days,
                collectionGroup: 'Kodas',
              ),
              ListTile(
                title: Text('التناول'),
              ),
              AttendanceChart(
                classes: [widget.class$],
                range: range,
                days: days,
                collectionGroup: 'Tanawol',
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _setRangeStart();
  }

  void _setRangeStart() async {
    minAvaliable = ((await FirebaseFirestore.instance
                .collection('History')
                .orderBy('Day')
                .limit(1)
                .get(dataSource))
            .docs[0]
            .data()['Day'] as Timestamp)
        .toDate();
    range = DateTimeRange(start: minAvaliable, end: DateTime.now());
    setState(() {});
  }
}

class _HistoryDayAnalyticsPageState extends State<HistoryDayAnalyticsPage> {
  List<Class> classes;
  var globalKey = GlobalKey();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('الاحصائيات'),
        actions: [
          IconButton(
            icon: Icon(Icons.mobile_screen_share),
            onPressed: () async {
              RenderRepaintBoundary boundary =
                  globalKey.currentContext.findRenderObject();
              ui.Image image = await boundary.toImage();
              ByteData byteData =
                  await image.toByteData(format: ui.ImageByteFormat.png);
              Uint8List pngBytes = byteData.buffer.asUint8List();
              await Share.shareFiles([
                (await (await File((await getApplicationDocumentsDirectory())
                                    .path +
                                DateTime.now()
                                    .millisecondsSinceEpoch
                                    .toString() +
                                '.png')
                            .create())
                        .writeAsBytes(pngBytes.toList()))
                    .path
              ]);
              ;
            },
            tooltip: 'حفظ كصورة',
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        key: globalKey,
        stream: Class.getAllForUser(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return ErrorWidget(snapshot.error);
          if (snapshot.connectionState != ConnectionState.active)
            return const Center(child: CircularProgressIndicator());
          classes ??= snapshot.data.docs.map((c) => Class.fromDoc(c)).toList();
          return ListView(
            children: [
              ListTile(
                title: Text('احصائيات الحضور ليوم ' +
                    DateFormat.yMMMEd('ar_EG').format(widget.day.day.toDate())),
              ),
              ListTile(
                title: Text('لفصول: '),
                subtitle: Text(
                  classes.map((c) => c.name).toList().join(', '),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: IconButton(
                  icon: Icon(Icons.list),
                  tooltip: 'اختيار الفصول',
                  onPressed: () async {
                    var rslt = await selectClasses(context, classes);
                    if (rslt != null)
                      setState(() => classes = rslt);
                    else if (rslt.isEmpty)
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
    );
  }
}

class _PersonAnalyticsPageState extends State<PersonAnalyticsPage> {
  DateTimeRange range =
      DateTimeRange(start: DateTime(2020), end: DateTime.now());
  var minAvaliable;
  var globalKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('الاحصائيات'),
        actions: [
          IconButton(
            icon: Icon(Icons.mobile_screen_share),
            onPressed: () async {
              RenderRepaintBoundary boundary =
                  globalKey.currentContext.findRenderObject();
              ui.Image image = await boundary.toImage();
              ByteData byteData =
                  await image.toByteData(format: ui.ImageByteFormat.png);
              Uint8List pngBytes = byteData.buffer.asUint8List();
              await Share.shareFiles([
                (await (await File((await getApplicationDocumentsDirectory())
                                    .path +
                                DateTime.now()
                                    .millisecondsSinceEpoch
                                    .toString() +
                                '.png')
                            .create())
                        .writeAsBytes(pngBytes.toList()))
                    .path
              ]);
              ;
            },
            tooltip: 'حفظ كصورة',
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        key: globalKey,
        stream: FirebaseFirestore.instance
            .collection('History')
            .orderBy('Day', descending: true)
            .where(
              'Day',
              isLessThanOrEqualTo:
                  Timestamp.fromDate(range.end.add(Duration(days: 1))),
            )
            .where('Day',
                isGreaterThanOrEqualTo:
                    Timestamp.fromDate(range.start.subtract(Duration(days: 1))))
            .snapshots(),
        builder: (context, data) {
          if (data.hasError) return ErrorWidget(data.error);
          if (data.connectionState != ConnectionState.active)
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
                        child: dialog,
                        data: Theme.of(context).copyWith(
                          textTheme: Theme.of(context).textTheme.copyWith(
                                overline: TextStyle(
                                  fontSize: 0,
                                ),
                              ),
                        ),
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
              DayHistoryProperty('تاريخ أخر تناول:', widget.person.lastTanawol,
                  widget.person.id, 'Tanawol'),
            ],
          );
        },
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _setRangeStart();
  }

  void _setRangeStart() async {
    minAvaliable = ((await FirebaseFirestore.instance
                .collection('History')
                .orderBy('Day')
                .limit(1)
                .get(dataSource))
            .docs[0]
            .data()['Day'] as Timestamp)
        .toDate();
    range = DateTimeRange(start: minAvaliable, end: DateTime.now());
    setState(() {});
  }
}

class _GeneralAnalyticsPageState extends State<GeneralAnalyticsPage> {
  List<Class> classes;
  DateTimeRange range =
      DateTimeRange(start: DateTime(2020), end: DateTime.now());
  var minAvaliable;
  var globalKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _setRangeStart();
  }

  void _setRangeStart() async {
    minAvaliable = ((await FirebaseFirestore.instance
                .collection('History')
                .orderBy('Day')
                .limit(1)
                .get(dataSource))
            .docs[0]
            .data()['Day'] as Timestamp)
        .toDate();
    range = DateTimeRange(start: minAvaliable, end: DateTime.now());
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('الاحصائيات'),
        actions: [
          IconButton(
            icon: Icon(Icons.mobile_screen_share),
            onPressed: () async {
              RenderRepaintBoundary boundary =
                  globalKey.currentContext.findRenderObject();
              ui.Image image = await boundary.toImage();
              ByteData byteData =
                  await image.toByteData(format: ui.ImageByteFormat.png);
              Uint8List pngBytes = byteData.buffer.asUint8List();
              await Share.shareFiles([
                (await (await File((await getApplicationDocumentsDirectory())
                                    .path +
                                DateTime.now()
                                    .millisecondsSinceEpoch
                                    .toString() +
                                '.png')
                            .create())
                        .writeAsBytes(pngBytes.toList()))
                    .path
              ]);
              ;
            },
            tooltip: 'حفظ كصورة',
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        key: globalKey,
        stream: Class.getAllForUser(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return ErrorWidget(snapshot.error);
          if (snapshot.connectionState != ConnectionState.active)
            return const Center(child: CircularProgressIndicator());
          classes ??= snapshot.data.docs.map((c) => Class.fromDoc(c)).toList();
          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('History')
                .orderBy('Day', descending: true)
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
              var days =
                  daysData.data.docs.map((o) => HistoryDay.fromDoc(o)).toList();
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
                            child: dialog,
                            data: Theme.of(context).copyWith(
                              textTheme: Theme.of(context).textTheme.copyWith(
                                    overline: TextStyle(
                                      fontSize: 0,
                                    ),
                                  ),
                            ),
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
                  ListTile(
                    title: Text('لفصول: '),
                    subtitle: Text(
                      classes.map((c) => c.name).toList().join(', '),
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: IconButton(
                      icon: Icon(Icons.list),
                      tooltip: 'اختيار الفصول',
                      onPressed: () async {
                        var rslt = await selectClasses(context, classes);
                        if (rslt?.isEmpty ?? false)
                          await showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                  content: Text('برجاء اختيار فصل على الأقل')));
                        else if (rslt != null) setState(() => classes = rslt);
                      },
                    ),
                  ),
                  ListTile(
                    title: Text('حضور الاجتماع'),
                  ),
                  AttendanceChart(
                    classes: classes,
                    range: range,
                    days: days,
                    collectionGroup: 'Meeting',
                  ),
                  ListTile(
                    title: Text('حضور القداس'),
                  ),
                  AttendanceChart(
                    classes: classes,
                    range: range,
                    days: days,
                    collectionGroup: 'Kodas',
                  ),
                  ListTile(
                    title: Text('التناول'),
                  ),
                  AttendanceChart(
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
      ),
    );
  }
}
