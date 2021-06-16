import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:async/async.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart';
import 'package:meetinghelper/models/history_property.dart';
import 'package:meetinghelper/models/models.dart';
import 'package:meetinghelper/models/user.dart';
import 'package:meetinghelper/utils/globals.dart';
import 'package:meetinghelper/utils/helpers.dart';
import 'package:meetinghelper/utils/typedefs.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'analytics_indicators.dart';

class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage(
      {Key? key,
      this.classes,
      this.range,
      this.historyColection = 'History',
      this.day})
      : super(key: key);

  final List<Class>? classes;
  final HistoryDay? day;
  final String historyColection;
  final DateTimeRange? range;

  @override
  _AnalyticsPageState createState() => _AnalyticsPageState();
}

class PersonAnalyticsPage extends StatefulWidget {
  const PersonAnalyticsPage({Key? key, this.person, this.colection = 'History'})
      : super(key: key);

  final String colection;
  final Person? person;

  @override
  _PersonAnalyticsPageState createState() => _PersonAnalyticsPageState();
}

class ActivityAnalysis extends StatefulWidget {
  const ActivityAnalysis({Key? key, this.classes}) : super(key: key);

  final List<Class>? classes;

  @override
  _ActivityAnalysisState createState() => _ActivityAnalysisState();
}

class _ActivityAnalysisState extends State<ActivityAnalysis> {
  List<Class>? classes;
  DateTime minAvaliable = DateTime.now().subtract(const Duration(days: 30));
  bool minAvaliableSet = false;
  DateTimeRange range = DateTimeRange(
      start: DateTime.now().subtract(const Duration(days: 30)),
      end: DateTime.now());

  final _screenKey = GlobalKey();

  Future<void> _setRangeStart() async {
    if (minAvaliableSet) return;
    if (User.instance.superAccess)
      minAvaliable = ((await FirebaseFirestore.instance
                  .collectionGroup('EditHistory')
                  .orderBy('Time')
                  .limit(1)
                  .get(dataSource))
              .docs
              .first
              .data()['Time'] as Timestamp)
          .toDate();
    else {
      final allowed = await Class.getAllForUser().first;
      if (allowed.length <= 10) {
        minAvaliable = ((await FirebaseFirestore.instance
                    .collectionGroup('EditHistory')
                    .where('ClassId',
                        whereIn: allowed.map((c) => c.ref).toList())
                    .orderBy('Time')
                    .limit(1)
                    .get(dataSource))
                .docs
                .first
                .data()['Time'] as Timestamp)
            .toDate();
      } else {
        minAvaliable = DateTime.fromMillisecondsSinceEpoch((await Future.wait(
          allowed.map(
            (c) => FirebaseFirestore.instance
                .collectionGroup('EditHistory')
                .where('ClassId', isEqualTo: c)
                .orderBy('Time')
                .limit(1)
                .get(dataSource),
          ),
        ))
            .expand((e) => e.docs
                .map((e) =>
                    (e.data()['Time'] as Timestamp).millisecondsSinceEpoch)
                .toList())
            .reduce((a, b) => min<int>(a, b)));
      }
    }
    minAvaliableSet = true;
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      key: _screenKey,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('تحليل بيانات الخدمة'),
          actions: [
            IconButton(
              icon: const Icon(Icons.mobile_screen_share),
              onPressed: () => takeScreenshot(_screenKey),
              tooltip: 'حفظ كصورة',
            ),
          ],
        ),
        body: FutureBuilder(
          future: _setRangeStart(),
          builder: (context, _) {
            if (_.connectionState == ConnectionState.done) {
              return StreamBuilder<List<Class>>(
                initialData: widget.classes,
                stream: Class.getAllForUser(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) return ErrorWidget(snapshot.error!);
                  if (!snapshot.hasData)
                    return const Center(child: CircularProgressIndicator());

                  classes ??= snapshot.data;
                  final classesByRef = {
                    for (final a in classes!) a.ref.path: a
                  };

                  return SingleChildScrollView(
                    child: Column(
                      children: [
                        ListTile(
                          title: Text(
                              'احصائيات الخدمة من ' +
                                  DateFormat.yMMMEd('ar_EG')
                                      .format(range.start) +
                                  ' الى ' +
                                  DateFormat.yMMMEd('ar_EG').format(range.end),
                              style: Theme.of(context).textTheme.bodyText1),
                          trailing: IconButton(
                            icon: const Icon(Icons.date_range),
                            tooltip: 'اختيار نطاق السجل',
                            onPressed: () async {
                              final rslt = await showDateRangePicker(
                                builder: (context, dialog) => Theme(
                                  data: Theme.of(context).copyWith(
                                    textTheme:
                                        Theme.of(context).textTheme.copyWith(
                                              overline: const TextStyle(
                                                fontSize: 0,
                                              ),
                                            ),
                                  ),
                                  child: dialog!,
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
                                            .subtract(const Duration(days: 1)),
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
                          title: const Text('لفصول: '),
                          subtitle: Text(
                            classes!.map((c) => c.name).toList().join(', '),
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.list_alt),
                            tooltip: 'اختيار الفصول',
                            onPressed: () async {
                              final rslt =
                                  await selectClasses(context, classes);
                              if (rslt != null && rslt.isNotEmpty)
                                setState(() => classes = rslt);
                              else if (rslt!.isNotEmpty)
                                await showDialog(
                                  context: context,
                                  builder: (context) => const AlertDialog(
                                    content:
                                        Text('برجاء اختيار فصل واحد على الأقل'),
                                  ),
                                );
                            },
                          ),
                        ),
                        HistoryAnalysisWidget(
                          range: range,
                          classes: classes ?? [],
                          classesByRef: classesByRef,
                          collectionGroup: 'VisitHistory',
                          title: 'خدمة الافتقاد',
                        ),
                        const Divider(),
                        HistoryAnalysisWidget(
                          range: range,
                          classes: classes ?? [],
                          classesByRef: classesByRef,
                          collectionGroup: 'EditHistory',
                          title: 'تحديث البيانات',
                        ),
                        const Divider(),
                        HistoryAnalysisWidget(
                          range: range,
                          classes: classes ?? [],
                          classesByRef: classesByRef,
                          collectionGroup: 'CallHistory',
                          title: 'خدمة المكالمات',
                        ),
                      ],
                    ),
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
}

class _PersonAnalyticsPageState extends State<PersonAnalyticsPage> {
  DateTime minAvaliable = DateTime.now().subtract(const Duration(days: 30));
  bool minAvaliableSet = false;
  DateTimeRange range = DateTimeRange(
      start: DateTime.now().subtract(const Duration(days: 30)),
      end: DateTime.now());

  final _screenKey = GlobalKey();

  Future<void> _setRangeStart() async {
    if (minAvaliableSet) return;
    minAvaliable = ((await FirebaseFirestore.instance
                .collection(widget.colection)
                .orderBy('Day')
                .limit(1)
                .get(dataSource))
            .docs
            .first
            .data()['Day'] as Timestamp)
        .toDate();
    minAvaliableSet = true;

    range = DateTimeRange(start: minAvaliable, end: DateTime.now());
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      key: _screenKey,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('الاحصائيات'),
          actions: [
            IconButton(
              icon: const Icon(Icons.mobile_screen_share),
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
            return StreamBuilder<JsonQuery>(
              stream: FirebaseFirestore.instance
                  .collection(widget.colection)
                  .orderBy('Day')
                  .where(
                    'Day',
                    isLessThan: Timestamp.fromDate(
                        range.end.add(const Duration(days: 1))),
                  )
                  .where('Day',
                      isGreaterThanOrEqualTo: Timestamp.fromDate(range.start))
                  .snapshots(),
              builder: (context, data) {
                if (data.hasError) return ErrorWidget(data.error!);
                if (!data.hasData)
                  return const Center(child: CircularProgressIndicator());
                if (data.data!.docs.isEmpty)
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
                        icon: const Icon(Icons.date_range),
                        tooltip: 'اختيار نطاق السجل',
                        onPressed: () async {
                          final rslt = await showDateRangePicker(
                            builder: (context, dialog) => Theme(
                              data: Theme.of(context).copyWith(
                                textTheme: Theme.of(context).textTheme.copyWith(
                                      overline: const TextStyle(
                                        fontSize: 0,
                                      ),
                                    ),
                              ),
                              child: dialog!,
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
                      id: widget.person!.id,
                      range: range,
                      total: data.data!.size,
                      collectionGroup: 'Meeting',
                      label: 'حضور الاجتماع',
                    ),
                    DayHistoryProperty(
                        'تاريخ أخر حضور اجتماع:',
                        widget.person!.lastMeeting,
                        widget.person!.id,
                        'Meeting'),
                    Container(height: 10),
                    PersonAttendanceIndicator(
                      id: widget.person!.id,
                      range: range,
                      total: data.data!.size,
                      collectionGroup: 'Kodas',
                      label: 'حضور القداس',
                    ),
                    DayHistoryProperty('تاريخ أخر حضور قداس:',
                        widget.person!.lastKodas, widget.person!.id, 'Kodas'),
                    Container(height: 10),
                    PersonAttendanceIndicator(
                      id: widget.person!.id,
                      range: range,
                      total: data.data!.size,
                      collectionGroup: 'Tanawol',
                      label: 'التناول',
                    ),
                    DayHistoryProperty(
                        'تاريخ أخر تناول:',
                        widget.person!.lastTanawol,
                        widget.person!.id,
                        'Tanawol'),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  List<Class>? classes;
  DateTime day = DateTime.now();
  DateTimeRange range = DateTimeRange(
      start: DateTime.now().subtract(const Duration(days: 30)),
      end: DateTime.now());

  bool _isOneDay = false;
  DateTime _minAvaliable = DateTime.now().subtract(const Duration(days: 30));
  final AsyncMemoizer<void> _rangeStart = AsyncMemoizer<void>();
  final _screenKey = GlobalKey();
  bool _sourceChanged = false;

  Future<void> _setRangeStart() async {
    if (widget.range != null) range = widget.range!;
    _minAvaliable = ((await FirebaseFirestore.instance
                .collection(widget.historyColection)
                .orderBy('Day')
                .limit(1)
                .get(dataSource))
            .docs
            .first
            .data()['Day'] as Timestamp)
        .toDate();
  }

  Future<void> _selectRange() async {
    final DateTimeRange? rslt = await showDateRangePicker(
      context: context,
      builder: (context, dialog) => Theme(
        data: Theme.of(context).copyWith(
          textTheme: Theme.of(context).textTheme.copyWith(
                overline: const TextStyle(
                  fontSize: 0,
                ),
              ),
        ),
        child: dialog!,
      ),
      helpText: null,
      confirmText: 'حفظ',
      saveText: 'حفظ',
      initialDateRange: range.start.millisecondsSinceEpoch <=
                  range.end.millisecondsSinceEpoch &&
              !_isOneDay
          ? range
          : DateTimeRange(
              start: day.subtract(const Duration(days: 1)), end: day),
      firstDate: _minAvaliable,
      lastDate: DateTime.now(),
    );
    if (rslt != null) {
      range = rslt;
      _isOneDay = false;
      _sourceChanged = true;
      setState(() {});
    }
  }

  Future<void> _selectDay() async {
    final DateTime? rslt = await showDatePicker(
      builder: (context, dialog) => Theme(
        data: Theme.of(context).copyWith(
          textTheme: Theme.of(context).textTheme.copyWith(
                overline: const TextStyle(
                  fontSize: 0,
                ),
              ),
        ),
        child: dialog!,
      ),
      helpText: null,
      context: context,
      confirmText: 'حفظ',
      initialDate: _isOneDay ? day : range.end,
      firstDate: _minAvaliable,
      lastDate: DateTime.now(),
    );
    if (rslt != null) {
      day = rslt;
      _isOneDay = true;
      _sourceChanged = true;
      setState(() {});
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.day != null) {
      _isOneDay = true;
      day = widget.day!.day.toDate();
    }
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      key: _screenKey,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('الاحصائيات'),
          actions: [
            IconButton(
              icon: const Icon(Icons.mobile_screen_share),
              onPressed: () => takeScreenshot(_screenKey),
              tooltip: 'حفظ كصورة',
            ),
          ],
        ),
        body: FutureBuilder(
          future: _rangeStart.runOnce(_setRangeStart),
          builder: (context, _) {
            if (_.connectionState == ConnectionState.done) {
              return StreamBuilder<List<Class>>(
                initialData: widget.classes,
                stream: Class.getAllForUser(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) return ErrorWidget(snapshot.error!);
                  if (!snapshot.hasData)
                    return const Center(child: CircularProgressIndicator());
                  classes ??= snapshot.data;

                  return StreamBuilder<List<HistoryDay>>(
                    initialData: widget.day != null ? [widget.day!] : null,
                    stream: (_isOneDay
                            ? FirebaseFirestore.instance
                                .collection(widget.historyColection)
                                .where('Day',
                                    isGreaterThanOrEqualTo:
                                        Timestamp.fromDate(day))
                                .where(
                                  'Day',
                                  isLessThan: Timestamp.fromDate(
                                      day.add(const Duration(days: 1))),
                                )
                                .snapshots()
                            : FirebaseFirestore.instance
                                .collection(widget.historyColection)
                                .orderBy('Day')
                                .where('Day',
                                    isGreaterThanOrEqualTo:
                                        Timestamp.fromDate(range.start))
                                .where(
                                  'Day',
                                  isLessThan: Timestamp.fromDate(
                                      range.end.add(const Duration(days: 1))),
                                )
                                .snapshots())
                        .map((s) =>
                            s.docs.map(HistoryDay.fromQueryDoc).toList()),
                    builder: (context, daysData) {
                      if (daysData.hasError)
                        return ErrorWidget(daysData.error!);
                      if (!daysData.hasData || _sourceChanged) {
                        _sourceChanged = false;
                        return const Center(child: CircularProgressIndicator());
                      }

                      final days = daysData.data;

                      return SingleChildScrollView(
                        child: Column(
                          children: [
                            ListTile(
                              title: Text(
                                  _isOneDay
                                      ? 'احصائيات الحضور ليوم ' +
                                          DateFormat.yMMMEd('ar_EG').format(day)
                                      : 'احصائيات الحضور من ' +
                                          DateFormat.yMMMEd('ar_EG')
                                              .format(range.start) +
                                          ' الى ' +
                                          DateFormat.yMMMEd('ar_EG')
                                              .format(range.end),
                                  style: Theme.of(context).textTheme.bodyText1),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.date_range),
                                    tooltip: 'اختيار نطاق السجل',
                                    onPressed: _selectRange,
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                        Icons.calendar_today_outlined),
                                    tooltip: 'اختيار يوم واحد',
                                    onPressed: _selectDay,
                                  ),
                                ],
                              ),
                            ),
                            ListTile(
                              title: const Text('الفصول: '),
                              subtitle: Text(
                                classes!.map((c) => c.name).toList().join(', '),
                                maxLines: 4,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.list_alt),
                                tooltip: 'اختيار الفصول',
                                onPressed: () async {
                                  final rslt =
                                      await selectClasses(context, classes);
                                  if (rslt != null && rslt.isNotEmpty) {
                                    _sourceChanged = true;
                                    setState(() => classes = rslt);
                                  } else if (rslt != null)
                                    await showDialog(
                                      context: context,
                                      builder: (context) => const AlertDialog(
                                        content:
                                            Text('برجاء اختيار فصل على الأقل'),
                                      ),
                                    );
                                },
                              ),
                            ),
                            if (_isOneDay && days!.isNotEmpty) ...[
                              Text('حضور الاجتماع',
                                  style: Theme.of(context).textTheme.headline6),
                              ClassesAttendanceIndicator(
                                classes: classes ?? [],
                                collection: days.first.meeting,
                                isServant: widget.historyColection ==
                                    'ServantsHistory',
                              ),
                              const Divider(),
                              Text('حضور القداس',
                                  style: Theme.of(context).textTheme.headline6),
                              ClassesAttendanceIndicator(
                                classes: classes ?? [],
                                collection: days.first.kodas,
                                isServant: widget.historyColection ==
                                    'ServantsHistory',
                              ),
                              const Divider(),
                              Text('التناول',
                                  style: Theme.of(context).textTheme.headline6),
                              ClassesAttendanceIndicator(
                                classes: classes ?? [],
                                collection: days.first.tanawol,
                                isServant: widget.historyColection ==
                                    'ServantsHistory',
                              ),
                            ] else if (days!.isNotEmpty) ...[
                              AttendanceChart(
                                title: 'حضور الاجتماع',
                                classes: classes ?? [],
                                range: range,
                                days: days,
                                isServant: widget.historyColection ==
                                    'ServantsHistory',
                                collectionGroup: 'Meeting',
                              ),
                              const Divider(),
                              AttendanceChart(
                                title: 'حضور القداس',
                                classes: classes ?? [],
                                range: range,
                                days: days,
                                isServant: widget.historyColection ==
                                    'ServantsHistory',
                                collectionGroup: 'Kodas',
                              ),
                              const Divider(),
                              AttendanceChart(
                                title: 'التناول',
                                classes: classes ?? [],
                                range: range,
                                days: days,
                                isServant: widget.historyColection ==
                                    'ServantsHistory',
                                collectionGroup: 'Tanawol',
                              ),
                            ] else
                              const Center(
                                child: Text('لا يوجد سجل في المدة المحددة'),
                              ),
                          ],
                        ),
                      );
                    },
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
}

void takeScreenshot(GlobalKey key) async {
  RenderRepaintBoundary? boundary =
      key.currentContext!.findRenderObject() as RenderRepaintBoundary?;
  WidgetsBinding.instance!.addPostFrameCallback(
    (_) async {
      ui.Image image = await boundary!.toImage(pixelRatio: 2);
      ByteData byteData =
          (await image.toByteData(format: ui.ImageByteFormat.png))!;
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
