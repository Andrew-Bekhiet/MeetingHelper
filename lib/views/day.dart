import 'package:feature_discovery/feature_discovery.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:meetinghelper/models/list_controllers.dart';
import 'package:meetinghelper/models/models.dart';
import 'package:meetinghelper/models/user.dart';
import 'package:meetinghelper/utils/globals.dart';
import 'package:meetinghelper/utils/helpers.dart';
import 'package:meetinghelper/views/list.dart';
import 'package:provider/provider.dart';
import 'package:rxdart/rxdart.dart';

class Day extends StatefulWidget {
  final HistoryDay record;

  const Day({Key? key, required this.record}) : super(key: key);

  @override
  State<Day> createState() => _DayState();
}

class _DayState extends State<Day> with SingleTickerProviderStateMixin {
  TabController? _tabs;
  final BehaviorSubject<bool> _showSearch = BehaviorSubject<bool>.seeded(false);
  final FocusNode _searchFocus = FocusNode();

  final List<CheckListController> _listControllers = [];

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        if (widget.record is! ServantsHistoryDay)
          Provider<CheckListController<Person>>(
            create: (_) {
              bool isSameDay = DateTime.now()
                      .difference(widget.record.day.toDate())
                      .inDays ==
                  0;
              return CheckListController(
                  itemsStream: Person.getAllForUser(orderBy: 'Name'),
                  day: widget.record,
                  dayOptions: HistoryDayOptions(
                    grouped: !isSameDay,
                    showOnly: isSameDay ? null : true,
                    enabled: isSameDay,
                    sortByTimeASC: isSameDay ? null : true,
                  ),
                  groupBy: personsByClassRef,
                  type: DayListType.Meeting);
            },
            dispose: (context, c) => c.dispose(),
          )
        else
          Provider<CheckListController<User>>(
            create: (_) {
              bool isSameDay = DateTime.now()
                      .difference(widget.record.day.toDate())
                      .inDays ==
                  0;
              return CheckListController(
                  itemsStream: User.getAllForUser(),
                  day: widget.record,
                  dayOptions: HistoryDayOptions(
                    grouped: !isSameDay,
                    showOnly: isSameDay ? null : true,
                    enabled: isSameDay,
                    sortByTimeASC: isSameDay ? null : true,
                  ),
                  groupBy: usersByClassRef,
                  type: DayListType.Meeting);
            },
            dispose: (context, c) => c.dispose(),
          ),
      ],
      builder: (context, body) {
        return Scaffold(
          appBar: AppBar(
            title: StreamBuilder<bool>(
              initialData: _showSearch.value,
              stream: _showSearch,
              builder: (context, data) => data.requireData
                  ? TextField(
                      focusNode: _searchFocus,
                      style: Theme.of(context).textTheme.headline6!.copyWith(
                          color: Theme.of(context)
                              .primaryTextTheme
                              .headline6!
                              .color),
                      decoration: InputDecoration(
                          suffixIcon: IconButton(
                            icon: Icon(Icons.close,
                                color: Theme.of(context)
                                    .primaryTextTheme
                                    .headline6!
                                    .color),
                            onPressed: () => setState(
                              () {
                                if (widget.record is! ServantsHistoryDay)
                                  context
                                      .read<CheckListController<Person>>()
                                      .searchQuery
                                      .add('');
                                else
                                  context
                                      .read<CheckListController<User>>()
                                      .searchQuery
                                      .add('');
                                _showSearch.add(false);
                              },
                            ),
                          ),
                          hintStyle: Theme.of(context)
                              .textTheme
                              .headline6!
                              .copyWith(
                                  color: Theme.of(context)
                                      .primaryTextTheme
                                      .headline6!
                                      .color),
                          icon: Icon(Icons.search,
                              color: Theme.of(context)
                                  .primaryTextTheme
                                  .headline6!
                                  .color),
                          hintText: 'بحث ...'),
                      onChanged: widget.record is! ServantsHistoryDay
                          ? context
                              .read<CheckListController<Person>>()
                              .searchQuery
                              .add
                          : context
                              .read<CheckListController<User>>()
                              .searchQuery
                              .add,
                    )
                  : const Text('كشف الحضور'),
            ),
            actions: [
              StreamBuilder<bool>(
                initialData: _showSearch.value,
                stream: _showSearch,
                builder: (context, data) => !data.requireData
                    ? IconButton(
                        icon: const Icon(Icons.search),
                        onPressed: () => setState(() {
                          _searchFocus.requestFocus();
                          _showSearch.add(true);
                        }),
                        tooltip: 'بحث',
                      )
                    : Container(),
              ),
              IconButton(
                tooltip: 'تحليل بيانات كشف اليوم',
                icon: DescribedFeatureOverlay(
                  barrierDismissible: false,
                  contentLocation: ContentLocation.below,
                  featureId: 'AnalyticsToday',
                  tapTarget: const Icon(Icons.analytics_outlined),
                  title: const Text('عرض تحليل لبيانات كشف اليوم'),
                  description: Column(
                    children: <Widget>[
                      const Text(
                          'الأن يمكنك عرض تحليل لبيانات المخدومين خلال اليوم من هنا'),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.forward),
                        label: Text(
                          'التالي',
                          style: TextStyle(
                            color: Theme.of(context).textTheme.bodyText2!.color,
                          ),
                        ),
                        onPressed: () {
                          FeatureDiscovery.completeCurrentStep(context);
                        },
                      ),
                      OutlinedButton(
                        onPressed: () => FeatureDiscovery.dismissAll(context),
                        child: Text(
                          'تخطي',
                          style: TextStyle(
                            color: Theme.of(context).textTheme.bodyText2!.color,
                          ),
                        ),
                      ),
                    ],
                  ),
                  backgroundColor: Theme.of(context).accentColor,
                  targetColor: Colors.transparent,
                  textColor:
                      Theme.of(context).primaryTextTheme.bodyText1!.color!,
                  child: const Icon(Icons.analytics_outlined),
                ),
                onPressed: () {
                  navigator.currentState!.pushNamed('Analytics', arguments: {
                    'Day': widget.record,
                    'HistoryCollection': widget.record.ref.parent.id
                  });
                },
              ),
              DescribedFeatureOverlay(
                barrierDismissible: false,
                featureId: 'Sorting',
                tapTarget: const Icon(Icons.library_add_check_outlined),
                title: const Text('تنظيم الليستة'),
                description: Column(
                  children: <Widget>[
                    const Text('يمكنك تقسيم المخدومين حسب الفصول أو'
                        ' اظهار المخدومين الحاضرين فقط أو '
                        'الغائبين والترتيب حسب وقت الحضور فقط من هنا'),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.forward),
                      label: Text(
                        'التالي',
                        style: TextStyle(
                          color: Theme.of(context).textTheme.bodyText2?.color,
                        ),
                      ),
                      onPressed: () =>
                          FeatureDiscovery.completeCurrentStep(context),
                    ),
                    OutlinedButton(
                      onPressed: () => FeatureDiscovery.dismissAll(context),
                      child: Text(
                        'تخطي',
                        style: TextStyle(
                          color: Theme.of(context).textTheme.bodyText2?.color,
                        ),
                      ),
                    ),
                  ],
                ),
                backgroundColor: Theme.of(context).accentColor,
                targetColor: Theme.of(context).primaryColor,
                textColor:
                    Theme.of(context).primaryTextTheme.bodyText1?.color ??
                        Colors.black,
                child: PopupMenuButton(
                  onSelected: (v) async {
                    if (v == 'delete' && User.instance.superAccess) {
                      await _delete();
                    } else if (v == 'sorting') {
                      await _showSortingOptions(context);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'sorting',
                      child: Text('تنظيم الليستة'),
                    ),
                    if (User.instance.superAccess)
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text('حذف الكشف'),
                      ),
                  ],
                ),
              ),
            ],
            bottom: TabBar(
              controller: _tabs,
              tabs: const [
                Tab(text: 'حضور الاجتماع'),
                Tab(text: 'حضور القداس'),
                Tab(text: 'التناول'),
              ],
            ),
          ),
          body: body,
          bottomNavigationBar: BottomAppBar(
            color: Theme.of(context).primaryColor,
            shape: const CircularNotchedRectangle(),
            child: AnimatedBuilder(
              animation: _tabs!,
              builder: (context, _) => StreamBuilder<Tuple2<int, int>>(
                stream: Rx.combineLatest2<Map, Map, Tuple2<int, int>>(
                  widget.record is! ServantsHistoryDay
                      ? context
                          .read<CheckListController<Person>>()
                          .originalObjectsData
                      : context
                          .read<CheckListController<User>>()
                          .originalObjectsData,
                  () {
                    var rslt = widget.record is! ServantsHistoryDay
                        ? context.read<CheckListController<Person>>()
                        : context.read<CheckListController<User>>();
                    if (_tabs!.index == 0) {
                      return rslt.copyWith(type: DayListType.Meeting).attended;
                    } else if (_tabs!.index == 1) {
                      return rslt.copyWith(type: DayListType.Kodas).attended;
                    } else {
                      //if (_tabs.index == 2) {
                      return rslt.copyWith(type: DayListType.Tanawol).attended;
                    }
                  }(),
                  (Map a, Map b) => Tuple2<int, int>(a.length, b.length),
                ),
                builder: (context, snapshot) {
                  TextTheme theme = Theme.of(context).primaryTextTheme;
                  return ExpansionTile(
                    expandedAlignment: Alignment.centerRight,
                    title: Text(
                      'الحضور: ' +
                          (snapshot.data?.item2 ?? 0).toString() +
                          ' مخدوم',
                      style: theme.bodyText2,
                    ),
                    trailing:
                        Icon(Icons.expand_more, color: theme.bodyText2?.color),
                    leading: DescribedFeatureOverlay(
                      barrierDismissible: false,
                      contentLocation: ContentLocation.above,
                      featureId: 'LockUnchecks',
                      tapTarget: const Icon(Icons.lock_open_outlined),
                      title: const Text('تثبيت الحضور'),
                      description: Column(
                        children: <Widget>[
                          const Text(
                              'يقوم البرنامج تلقائيًا بطلب تأكيد لإزالة حضور مخدوم\nاذا اردت الغاء هذه الخاصية يمكنك الضغط هنا'),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.forward),
                            label: Text(
                              'التالي',
                              style: TextStyle(
                                color: Theme.of(context)
                                    .textTheme
                                    .bodyText2
                                    ?.color,
                              ),
                            ),
                            onPressed: () {
                              FeatureDiscovery.completeCurrentStep(context);
                            },
                          ),
                          OutlinedButton(
                            onPressed: () =>
                                FeatureDiscovery.dismissAll(context),
                            child: Text(
                              'تخطي',
                              style: TextStyle(
                                color: Theme.of(context)
                                    .textTheme
                                    .bodyText2
                                    ?.color,
                              ),
                            ),
                          ),
                        ],
                      ),
                      backgroundColor: Theme.of(context).accentColor,
                      targetColor: Colors.transparent,
                      textColor:
                          Theme.of(context).primaryTextTheme.bodyText1!.color!,
                      child: StreamBuilder<bool>(
                        initialData: (widget.record is! ServantsHistoryDay
                                ? context.read<CheckListController<Person>>()
                                : context.read<CheckListController<User>>())
                            .dayOptions
                            .lockUnchecks
                            .value,
                        stream: (widget.record is! ServantsHistoryDay
                                ? context.read<CheckListController<Person>>()
                                : context.read<CheckListController<User>>())
                            .dayOptions
                            .lockUnchecks,
                        builder: (context, data) {
                          return IconButton(
                            icon: Icon(
                                !data.data!
                                    ? Icons.lock_open
                                    : Icons.lock_outlined,
                                color: theme.bodyText2?.color),
                            tooltip: 'تثبيت الحضور',
                            onPressed: () => (widget.record
                                        is! ServantsHistoryDay
                                    ? context
                                        .read<CheckListController<Person>>()
                                    : context.read<CheckListController<User>>())
                                .dayOptions
                                .lockUnchecks
                                .add(!data.data!),
                          );
                        },
                      ),
                    ),
                    children: [
                      Text('الغياب: ' +
                          ((snapshot.data?.item1 ?? 0) -
                                  (snapshot.data?.item2 ?? 0))
                              .toString() +
                          ' مخدوم'),
                      Text('اجمالي: ' +
                          (snapshot.data?.item1 ?? 0).toString() +
                          ' مخدوم'),
                    ],
                  );
                },
              ),
            ),
          ),
          extendBody: true,
        );
      },
      child: Builder(builder: (context) {
        return TabBarView(
          controller: _tabs,
          children: widget.record is! ServantsHistoryDay
              ? [
                  DataObjectCheckList<Person>(
                    autoDisposeController: false,
                    key: PageStorageKey('PersonsMeeting' + widget.record.id),
                    options: () {
                      final tmp = context
                          .read<CheckListController<Person>>()
                          .copyWith(type: DayListType.Meeting);
                      _listControllers.add(tmp);
                      return tmp;
                    }(),
                  ),
                  DataObjectCheckList<Person>(
                    autoDisposeController: false,
                    key: PageStorageKey('PersonsKodas' + widget.record.id),
                    options: () {
                      final tmp = context
                          .read<CheckListController<Person>>()
                          .copyWith(type: DayListType.Kodas);
                      _listControllers.add(tmp);
                      return tmp;
                    }(),
                  ),
                  DataObjectCheckList<Person>(
                    autoDisposeController: false,
                    key: PageStorageKey('PersonsTanawol' + widget.record.id),
                    options: () {
                      final tmp = context
                          .read<CheckListController<Person>>()
                          .copyWith(type: DayListType.Tanawol);
                      _listControllers.add(tmp);
                      return tmp;
                    }(),
                  ),
                ]
              : [
                  DataObjectCheckList<User>(
                    autoDisposeController: false,
                    key: PageStorageKey('UsersMeeting' + widget.record.id),
                    options: () {
                      final tmp = context
                          .read<CheckListController<User>>()
                          .copyWith(type: DayListType.Meeting);
                      _listControllers.add(tmp);
                      return tmp;
                    }(),
                  ),
                  DataObjectCheckList<User>(
                    autoDisposeController: false,
                    key: PageStorageKey('UsersKodas' + widget.record.id),
                    options: () {
                      final tmp = context
                          .read<CheckListController<User>>()
                          .copyWith(type: DayListType.Kodas);
                      _listControllers.add(tmp);
                      return tmp;
                    }(),
                  ),
                  DataObjectCheckList<User>(
                    autoDisposeController: false,
                    key: PageStorageKey('UsersTanawol' + widget.record.id),
                    options: () {
                      final tmp = context
                          .read<CheckListController<User>>()
                          .copyWith(type: DayListType.Tanawol);
                      _listControllers.add(tmp);
                      return tmp;
                    }(),
                  ),
                ],
        );
      }),
    );
  }

  Future<void> _showSortingOptions(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (context2) => AlertDialog(
        insetPadding: const EdgeInsets.symmetric(vertical: 24.0),
        content: StatefulBuilder(builder: (innerContext, setState) {
          var dayOptions = (widget.record is! ServantsHistoryDay
                  ? context.read<CheckListController<Person>>()
                  : context.read<CheckListController<User>>())
              .dayOptions;
          return SizedBox(
            width: 350,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Checkbox(
                      value: dayOptions.grouped.value,
                      onChanged: (value) {
                        dayOptions.grouped.add(value!);
                        setState(() {});
                      },
                    ),
                    GestureDetector(
                      onTap: () {
                        dayOptions.grouped.add(!dayOptions.grouped.value);
                        setState(() {});
                      },
                      child: const Text('تقسيم حسب الفصول'),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Container(width: 10),
                    Checkbox(
                      value: dayOptions.showSubtitlesInGroups.value,
                      onChanged: dayOptions.grouped.value
                          ? (value) {
                              dayOptions.showSubtitlesInGroups.add(value!);
                              setState(() {});
                            }
                          : null,
                    ),
                    GestureDetector(
                      onTap: dayOptions.grouped.value
                          ? () {
                              dayOptions.showSubtitlesInGroups
                                  .add(!dayOptions.showSubtitlesInGroups.value);
                              setState(() {});
                            }
                          : null,
                      child: const Text('اظهار عدد المخدومين داخل كل فصل'),
                    ),
                  ],
                ),
                Container(height: 5),
                ListTile(
                  title: const Text('ترتيب حسب:'),
                  subtitle: Wrap(
                    direction: Axis.vertical,
                    children: [null, true, false]
                        .map(
                          (i) => Row(
                            children: [
                              Radio<bool?>(
                                value: i,
                                groupValue: dayOptions.sortByTimeASC.value,
                                onChanged: (v) {
                                  dayOptions.sortByTimeASC.add(v);
                                  setState(() {});
                                },
                              ),
                              GestureDetector(
                                onTap: () {
                                  dayOptions.sortByTimeASC.add(i);
                                  setState(() {});
                                },
                                child: Text(i == null
                                    ? 'الاسم'
                                    : i == true
                                        ? 'وقت الحضور'
                                        : 'وقت الحضور (المتأخر أولا)'),
                              )
                            ],
                          ),
                        )
                        .toList(),
                  ),
                ),
                Container(height: 5),
                ListTile(
                  enabled: dayOptions.sortByTimeASC.value == null,
                  title: const Text('إظهار:'),
                  subtitle: Wrap(
                    direction: Axis.vertical,
                    children: [null, true, false]
                        .map(
                          (i) => Row(
                            children: [
                              Radio<bool?>(
                                value: i,
                                groupValue:
                                    dayOptions.sortByTimeASC.value == null
                                        ? dayOptions.showOnly.value
                                        : true,
                                onChanged:
                                    dayOptions.sortByTimeASC.value == null
                                        ? (v) {
                                            dayOptions.showOnly.add(v);
                                            setState(() {});
                                          }
                                        : null,
                              ),
                              GestureDetector(
                                onTap: dayOptions.sortByTimeASC.value == null
                                    ? () {
                                        dayOptions.showOnly.add(i);
                                        setState(() {});
                                      }
                                    : null,
                                child: Text(i == null
                                    ? 'الكل'
                                    : i == true
                                        ? 'الحاضرين فقط'
                                        : 'الغائبين فقط'),
                              )
                            ],
                          ),
                        )
                        .toList(),
                  ),
                ),
              ],
            ),
          );
        }),
        actions: [
          TextButton(
            onPressed: () {
              navigator.currentState!.pop();
            },
            child: const Text('إغلاق'),
          )
        ],
      ),
    );
  }

  Future<void> _delete() async {
    if (await showDialog(
          context: context,
          builder: (context) => AlertDialog(actions: [
            TextButton(
              onPressed: () => navigator.currentState!.pop(true),
              child: const Text('نعم'),
            ),
            TextButton(
              onPressed: () => navigator.currentState!.pop(false),
              child: const Text('لا'),
            )
          ], content: const Text('هل أنت متأكد من الحذف؟')),
        ) ==
        true) {
      await widget.record.ref.delete();
      navigator.currentState!.pop();
    }
  }

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    WidgetsBinding.instance!.addPostFrameCallback((timeStamp) async {
      if (DateTime.now().difference(widget.record.day.toDate()).inDays != 0)
        return;
      try {
        if (!(await widget.record.ref.get(dataSource)).exists) {
          await widget.record.ref.set(widget.record.getMap());
        }
      } catch (err, stkTrace) {
        await FirebaseCrashlytics.instance.recordError(err, stkTrace);
        await showErrorDialog(context, err.toString(), title: 'حدث خطأ');
      }
      if (!(Hive.box<bool>('FeatureDiscovery').get('DayInstructions') ??
          false)) {
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('كيفية استخدام كشف الحضور'),
            content: const Text('1.يمكنك تسجيل حضور مخدوم بالضغط عليه وسيقوم'
                ' البرنامج بتسجيل الحضور في الوقت الحالي'
                '\n2.يمكنك تغيير وقت حضور المخدوم'
                ' عن طريق الضغط مطولا عليه ثم تغيير الوقت'
                '\n3.يمكنك اضافة ملاحظات على حضور المخدوم (مثلا: جاء متأخرًا بسبب كذا) عن'
                ' طريق الضغط مطولا على المخدوم واضافة الملاحظات'
                '\n4.يمكنك عرض معلومات المخدوم عن طريق الضغط مطولا عليه'
                ' ثم الضغط على عرض بيانات المخدوم'),
            actions: [
              TextButton(
                onPressed: () => navigator.currentState!.pop(),
                child: const Text('تم'),
              )
            ],
          ),
        );
        await Hive.box<bool>('FeatureDiscovery').put('DayInstructions', true);
      }
      FeatureDiscovery.discoverFeatures(
          context, ['Sorting', 'AnalyticsToday', 'LockUnchecks']);
    });
  }

  @override
  Future<void> dispose() async {
    super.dispose();
    await _showSearch.close();
    await Future.wait(_listControllers.map((c) => c.dispose()));
  }
}
