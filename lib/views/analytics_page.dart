import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:async/async.dart';
import 'package:churchdata_core/churchdata_core.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:get_it/get_it.dart';
import 'package:intl/intl.dart';
import 'package:meetinghelper/models.dart';
import 'package:meetinghelper/repositories.dart';
import 'package:meetinghelper/utils/helpers.dart';
import 'package:meetinghelper/widgets.dart';
import 'package:path_provider/path_provider.dart';
import 'package:rxdart/rxdart.dart';
import 'package:share_plus/share_plus.dart';

class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({
    super.key,
    this.parents,
    this.range,
    this.historyColection = 'History',
    this.day,
  });

  final List<DataObject>? parents;
  final HistoryDayBase? day;
  final String historyColection;
  final DateTimeRange? range;

  @override
  _AnalyticsPageState createState() => _AnalyticsPageState();
}

class PersonAnalyticsPage extends StatefulWidget {
  const PersonAnalyticsPage({
    required this.person,
    super.key,
    this.colection = 'History',
  });

  final String colection;
  final Person person;

  @override
  _PersonAnalyticsPageState createState() => _PersonAnalyticsPageState();
}

class ActivityAnalysis extends StatefulWidget {
  const ActivityAnalysis({super.key, this.parents});

  final List<DataObject>? parents;

  @override
  _ActivityAnalysisState createState() => _ActivityAnalysisState();
}

class _ActivityAnalysisState extends State<ActivityAnalysis> {
  List<DataObject>? parents;
  DateTime minAvaliable = DateTime.now().subtract(const Duration(days: 30));
  bool minAvaliableSet = false;
  DateTimeRange range = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 30)),
    end: DateTime.now(),
  );

  final AsyncMemoizer<void> _rangeStart = AsyncMemoizer<void>();

  final _screenKey = GlobalKey();

  Future<void> _setRangeStart() async {
    if (minAvaliableSet) return;

    if (User.instance.permissions.superAccess) {
      minAvaliable = ((await GetIt.I<DatabaseRepository>()
                      .collectionGroup('EditHistory')
                      .orderBy('Time')
                      .limit(1)
                      .get())
                  .docs
                  .firstOrNull
                  ?.data()['Time'] as Timestamp?)
              ?.toDate() ??
          minAvaliable;
    } else {
      final allowed = await MHDatabaseRepo.I.classes.getAll().first;
      if (allowed.isEmpty) return;

      if (allowed.length <= 10) {
        minAvaliable = ((await GetIt.I<DatabaseRepository>()
                        .collectionGroup('EditHistory')
                        .where(
                          'ClassId',
                          whereIn: allowed.map((c) => c.ref).toList(),
                        )
                        .orderBy('Time')
                        .limit(1)
                        .get())
                    .docs
                    .firstOrNull
                    ?.data()['Time'] as Timestamp?)
                ?.toDate() ??
            minAvaliable;
      } else {
        minAvaliable = DateTime.fromMillisecondsSinceEpoch(
          (await Future.wait(
            allowed.map(
              (c) => GetIt.I<DatabaseRepository>()
                  .collectionGroup('EditHistory')
                  .where('ClassId', isEqualTo: c)
                  .orderBy('Time')
                  .limit(1)
                  .get(),
            ),
          ))
              .expand(
                (e) => e.docs
                    .map(
                      (e) => (e.data()['Time'] as Timestamp)
                          .millisecondsSinceEpoch,
                    )
                    .toList(),
              )
              .reduce((a, b) => min<int>(a, b)),
        );
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
        body: FutureBuilder<void>(
          future: _rangeStart.runOnce(_setRangeStart),
          builder: (context, rangeStartSnapshot) {
            if (rangeStartSnapshot.connectionState == ConnectionState.done) {
              return StreamBuilder<List<DataObject>>(
                initialData: widget.parents,
                stream: Rx.combineLatest2<List<Class>, List<Service>,
                    List<DataObject>>(
                  MHDatabaseRepo.I.classes.getAll(),
                  MHDatabaseRepo.I.services.getAll(),
                  (c, s) => [...c, ...s],
                ),
                builder: (context, snapshot) {
                  if (snapshot.hasError) return ErrorWidget(snapshot.error!);
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  parents ??= snapshot.data;
                  final classesByRef = {for (final a in parents!) a.ref: a};

                  return SingleChildScrollView(
                    child: Column(
                      children: [
                        ListTile(
                          title: Text(
                            'احصائيات الخدمة من ' +
                                DateFormat.yMMMEd('ar_EG').format(range.start) +
                                ' الى ' +
                                DateFormat.yMMMEd('ar_EG').format(range.end),
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.date_range),
                            tooltip: 'اختيار نطاق السجل',
                            onPressed: () async {
                              final rslt = await showDateRangePicker(
                                builder: (context, dialog) => Theme(
                                  data: Theme.of(context).copyWith(
                                    textTheme:
                                        Theme.of(context).textTheme.copyWith(
                                              labelSmall: const TextStyle(
                                                fontSize: 0,
                                              ),
                                            ),
                                  ),
                                  child: dialog!,
                                ),
                                context: context,
                                confirmText: 'حفظ',
                                saveText: 'حفظ',
                                initialDateRange: !range.start
                                        .isBefore(minAvaliable)
                                    ? range
                                    : DateTimeRange(
                                        start: DateTime.now()
                                            .subtract(const Duration(days: 1)),
                                        end: range.end,
                                      ),
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
                          title: const Text('الفصول والخدمات: '),
                          subtitle: Text(
                            parents!.map((c) => c.name).toList().join(', '),
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.list_alt),
                            tooltip: 'اختيار الفصول',
                            onPressed: () async {
                              final rslt = await selectServices(parents);
                              if (rslt != null && rslt.isNotEmpty) {
                                setState(() => parents = rslt);
                              } else if (rslt != null) {
                                await showDialog(
                                  context: context,
                                  builder: (context) => const AlertDialog(
                                    content:
                                        Text('برجاء اختيار فصل واحد على الأقل'),
                                  ),
                                );
                              }
                            },
                          ),
                        ),
                        HistoryAnalysisWidget(
                          range: range,
                          parents: parents ?? [],
                          classesByRef: classesByRef,
                          collectionGroup: 'VisitHistory',
                          title: 'خدمة الافتقاد',
                        ),
                        const Divider(),
                        HistoryAnalysisWidget(
                          range: range,
                          parents: parents ?? [],
                          classesByRef: classesByRef,
                          collectionGroup: 'EditHistory',
                          title: 'تحديث البيانات',
                        ),
                        const Divider(),
                        HistoryAnalysisWidget(
                          range: range,
                          parents: parents ?? [],
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
    end: DateTime.now(),
  );

  final AsyncMemoizer<void> _rangeStart = AsyncMemoizer<void>();

  final _screenKey = GlobalKey();

  Future<void> _setRangeStart() async {
    if (minAvaliableSet) return;
    minAvaliable = ((await GetIt.I<DatabaseRepository>()
                    .collection(widget.colection)
                    .orderBy('Day')
                    .limit(1)
                    .get())
                .docs
                .firstOrNull
                ?.data()['Day'] as Timestamp?)
            ?.toDate() ??
        minAvaliable;
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
        body: FutureBuilder<Map<JsonRef, Service>>(
          future: _rangeStart.runOnce(_setRangeStart).then((_) async {
            return {
              for (final service
                  in await MHDatabaseRepo.I.services.getAll().first)
                service.ref: service,
            };
          }),
          builder: (context, servicesSnapshot) {
            if (servicesSnapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }

            return StreamBuilder<JsonQuery>(
              stream: GetIt.I<DatabaseRepository>()
                  .collection(widget.colection)
                  .orderBy('Day')
                  .where(
                    'Day',
                    isLessThan: Timestamp.fromDate(
                      range.end.add(const Duration(days: 1)),
                    ),
                  )
                  .where(
                    'Day',
                    isGreaterThanOrEqualTo: Timestamp.fromDate(range.start),
                  )
                  .snapshots(),
              builder: (context, data) {
                if (data.hasError) return ErrorWidget(data.error!);
                if (!data.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (data.data!.docs.isEmpty) {
                  return const Center(child: Text('لا يوجد سجل'));
                }

                return SingleChildScrollView(
                  child: Column(
                    children: [
                      ListTile(
                        title: Text(
                          'احصائيات الحضور من ' +
                              DateFormat.yMMMEd('ar_EG').format(range.start) +
                              ' الى ' +
                              DateFormat.yMMMEd('ar_EG').format(range.end),
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.date_range),
                          tooltip: 'اختيار نطاق السجل',
                          onPressed: () async {
                            final rslt = await showDateRangePicker(
                              builder: (context, dialog) => Theme(
                                data: Theme.of(context).copyWith(
                                  textTheme:
                                      Theme.of(context).textTheme.copyWith(
                                            labelSmall: const TextStyle(
                                              fontSize: 0,
                                            ),
                                          ),
                                ),
                                child: dialog!,
                              ),
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
                        total: data.data!.size,
                        collectionGroup: 'Meeting',
                        label: 'حضور الاجتماع',
                      ),
                      DayHistoryProperty(
                        'تاريخ أخر حضور اجتماع:',
                        widget.person.lastMeeting,
                        widget.person.id,
                        'Meeting',
                      ),
                      Container(height: 10),
                      PersonAttendanceIndicator(
                        id: widget.person.id,
                        range: range,
                        total: data.data!.size,
                        collectionGroup: 'Kodas',
                        label: 'حضور القداس',
                      ),
                      DayHistoryProperty(
                        'تاريخ أخر حضور قداس:',
                        widget.person.lastKodas,
                        widget.person.id,
                        'Kodas',
                      ),
                      Container(height: 10),
                      PersonAttendanceIndicator(
                        id: widget.person.id,
                        range: range,
                        total: data.data!.size,
                        collectionGroup: 'Confession',
                        label: 'الاعتراف',
                      ),
                      DayHistoryProperty(
                        'تاريخ أخر اعتراف:',
                        widget.person.lastConfession,
                        widget.person.id,
                        'Confession',
                      ),
                      Container(height: 10),
                      ...widget.person.services
                          .map(
                            (s) => [
                              Container(height: 10),
                              PersonAttendanceIndicator(
                                id: widget.person.id,
                                range: range,
                                total: data.data!.size,
                                collectionGroup: s.id,
                                label:
                                    'حضور ' + servicesSnapshot.data![s]!.name,
                              ),
                              DayHistoryProperty(
                                'تاريخ أخر حضور ' +
                                    servicesSnapshot.data![s]!.name +
                                    ':',
                                widget.person.last[s.id],
                                widget.person.id,
                                s.id,
                              ),
                            ],
                          )
                          .expand((e) => e),
                    ],
                  ),
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
  List<DataObject>? parents;
  DateTime day = DateTime.now();
  DateTimeRange range = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 30)),
    end: DateTime.now(),
  );

  bool _isOneDay = false;
  DateTime _minAvaliable = DateTime.now().subtract(const Duration(days: 30));
  final AsyncMemoizer<void> _rangeStart = AsyncMemoizer<void>();
  final _screenKey = GlobalKey();
  bool _sourceChanged = false;

  Future<void> _setRangeStart() async {
    if (widget.range != null) range = widget.range!;
    _minAvaliable = ((await GetIt.I<DatabaseRepository>()
                    .collection(widget.historyColection)
                    .orderBy('Day')
                    .limit(1)
                    .get())
                .docs
                .firstOrNull
                ?.data()['Day'] as Timestamp?)
            ?.toDate() ??
        _minAvaliable;
  }

  Future<void> _selectRange() async {
    final DateTimeRange? rslt = await showDateRangePicker(
      context: context,
      builder: (context, dialog) => Theme(
        data: Theme.of(context).copyWith(
          textTheme: Theme.of(context).textTheme.copyWith(
                labelSmall: const TextStyle(
                  fontSize: 0,
                ),
              ),
        ),
        child: dialog!,
      ),
      confirmText: 'حفظ',
      saveText: 'حفظ',
      initialDateRange: !range.start.isBefore(_minAvaliable) && !_isOneDay
          ? range
          : DateTimeRange(
              start: day.subtract(const Duration(days: 1)),
              end: day,
            ),
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
                labelSmall: const TextStyle(
                  fontSize: 0,
                ),
              ),
        ),
        child: dialog!,
      ),
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
        body: FutureBuilder<List<StudyYear>>(
          future: _rangeStart.runOnce(_setRangeStart).then((_) async {
            return StudyYear.getAll().first;
          }),
          builder: (context, studyYearsData) {
            if (studyYearsData.connectionState == ConnectionState.done) {
              return StreamBuilder<List<DataObject>>(
                initialData: widget.parents,
                stream: Rx.combineLatest2<List<Class>, List<Service>,
                    List<DataObject>>(
                  MHDatabaseRepo.I.classes.getAll(),
                  MHDatabaseRepo.I.services.getAll(onlyShownInHistory: true),
                  (c, s) => [...c, ...s],
                ),
                builder: (context, snapshot) {
                  if (snapshot.hasError) return ErrorWidget(snapshot.error!);
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  parents ??= snapshot.data;

                  return StreamBuilder<List<HistoryDayBase>>(
                    initialData: widget.day != null ? [widget.day!] : null,
                    stream: (_isOneDay
                            ? GetIt.I<DatabaseRepository>()
                                .collection(widget.historyColection)
                                .where(
                                  'Day',
                                  isGreaterThanOrEqualTo:
                                      Timestamp.fromDate(day),
                                )
                                .where(
                                  'Day',
                                  isLessThan: Timestamp.fromDate(
                                    day.add(const Duration(days: 1)),
                                  ),
                                )
                                .snapshots()
                            : GetIt.I<DatabaseRepository>()
                                .collection(widget.historyColection)
                                .orderBy('Day')
                                .where(
                                  'Day',
                                  isGreaterThanOrEqualTo:
                                      Timestamp.fromDate(range.start),
                                )
                                .where(
                                  'Day',
                                  isLessThan: Timestamp.fromDate(
                                    range.end.add(const Duration(days: 1)),
                                  ),
                                )
                                .snapshots())
                        .map(
                      (s) => s.docs.map(HistoryDay.fromQueryDoc).toList(),
                    ),
                    builder: (context, daysData) {
                      if (daysData.hasError) {
                        return ErrorWidget(daysData.error!);
                      }
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
                                style: Theme.of(context).textTheme.bodyLarge,
                              ),
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
                                      Icons.calendar_today_outlined,
                                    ),
                                    tooltip: 'اختيار يوم واحد',
                                    onPressed: _selectDay,
                                  ),
                                ],
                              ),
                            ),
                            ListTile(
                              title: const Text('الفصول والخدمات: '),
                              subtitle: Text(
                                parents!.map((c) => c.name).toList().join(', '),
                                maxLines: 4,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.list_alt),
                                tooltip: 'اختيار الفصول',
                                onPressed: () async {
                                  final rslt = await selectServices(parents);
                                  if (rslt != null && rslt.isNotEmpty) {
                                    _sourceChanged = true;
                                    setState(() => parents = rslt);
                                  } else if (rslt != null) {
                                    await showDialog(
                                      context: context,
                                      builder: (context) => const AlertDialog(
                                        content:
                                            Text('برجاء اختيار فصل على الأقل'),
                                      ),
                                    );
                                  }
                                },
                              ),
                            ),
                            if (_isOneDay && days!.isNotEmpty) ...[
                              if ((parents?.whereType<Class>() ?? [])
                                  .isNotEmpty) ...[
                                Text(
                                  'حضور الاجتماع',
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                                ClassesAttendanceIndicator(
                                  classes:
                                      parents?.whereType<Class>().toList() ??
                                          [],
                                  collection:
                                      days.single.subcollection('Meeting')!,
                                  isServant: widget.historyColection ==
                                      'ServantsHistory',
                                ),
                                const Divider(),
                                Text(
                                  'حضور القداس',
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                                ClassesAttendanceIndicator(
                                  classes:
                                      parents?.whereType<Class>().toList() ??
                                          [],
                                  collection:
                                      days.single.subcollection('Kodas')!,
                                  isServant: widget.historyColection ==
                                      'ServantsHistory',
                                ),
                                const Divider(),
                                Text(
                                  'الاعتراف',
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                                ClassesAttendanceIndicator(
                                  classes:
                                      parents?.whereType<Class>().toList() ??
                                          [],
                                  collection:
                                      days.single.subcollection('Confession')!,
                                  isServant: widget.historyColection ==
                                      'ServantsHistory',
                                ),
                              ],
                              ...parents
                                      ?.whereType<Service>()
                                      .map(
                                        (s) => [
                                          const Divider(),
                                          Text(
                                            'حضور ' + s.name,
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleLarge,
                                          ),
                                          ClassesAttendanceIndicator(
                                            collection: days.single
                                                .subcollection(s.id)!,
                                            isServant:
                                                widget.historyColection ==
                                                    'ServantsHistory',
                                            studyYears: studyYearsData.data,
                                          ),
                                        ],
                                      )
                                      .expand((w) => w) ??
                                  [],
                            ] else if (days!.isNotEmpty) ...[
                              if ((parents?.whereType<Class>() ?? [])
                                  .isNotEmpty) ...[
                                AttendanceChart(
                                  title: 'حضور الاجتماع',
                                  classes:
                                      parents?.whereType<Class>().toList() ??
                                          [],
                                  range: range,
                                  days: days,
                                  isServant: widget.historyColection ==
                                      'ServantsHistory',
                                  collectionGroup: 'Meeting',
                                ),
                                const Divider(),
                                AttendanceChart(
                                  title: 'حضور القداس',
                                  classes:
                                      parents?.whereType<Class>().toList() ??
                                          [],
                                  range: range,
                                  days: days,
                                  isServant: widget.historyColection ==
                                      'ServantsHistory',
                                  collectionGroup: 'Kodas',
                                ),
                                const Divider(),
                                AttendanceChart(
                                  title: 'الاعتراف',
                                  classes:
                                      parents?.whereType<Class>().toList() ??
                                          [],
                                  range: range,
                                  days: days,
                                  isServant: widget.historyColection ==
                                      'ServantsHistory',
                                  collectionGroup: 'Confession',
                                ),
                              ],
                              ...parents
                                      ?.whereType<Service>()
                                      .map(
                                        (s) => [
                                          const Divider(),
                                          AttendanceChart(
                                            title: 'حضور ' + s.name,
                                            range: range,
                                            days: days,
                                            isServant:
                                                widget.historyColection ==
                                                    'ServantsHistory',
                                            collectionGroup: s.id,
                                            studyYears: studyYearsData.data,
                                          ),
                                        ],
                                      )
                                      .expand((w) => w) ??
                                  [],
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

Future<void> takeScreenshot(GlobalKey key) async {
  final RenderRepaintBoundary? boundary =
      key.currentContext!.findRenderObject() as RenderRepaintBoundary?;
  WidgetsBinding.instance.addPostFrameCallback(
    (_) async {
      final ui.Image image = await boundary!.toImage(pixelRatio: 2);
      final ByteData byteData =
          (await image.toByteData(format: ui.ImageByteFormat.png))!;
      final Uint8List pngBytes = byteData.buffer.asUint8List();

      final directory = await getApplicationDocumentsDirectory();

      final path = directory.path +
          DateTime.now().millisecondsSinceEpoch.toString() +
          '.png';
      await XFile.fromData(
        Uint8List.fromList(pngBytes.toList()),
      ).saveTo(path);

      await Share.shareXFiles(
        [XFile(path)],
      );
    },
  );
}
