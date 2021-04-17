import 'package:feature_discovery/feature_discovery.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:meetinghelper/models/list_options.dart';
import 'package:meetinghelper/models/models.dart';
import 'package:meetinghelper/models/user.dart';
import 'package:meetinghelper/views/list.dart';
import 'package:meetinghelper/utils/globals.dart';
import 'package:meetinghelper/utils/helpers.dart';
import 'package:provider/provider.dart';
import 'package:rxdart/rxdart.dart';

class Day extends StatefulWidget {
  final HistoryDay record;

  Day({required this.record}) : assert(record != null);

  @override
  State<Day> createState() => _DayState();
}

class _DayState extends State<Day> with SingleTickerProviderStateMixin {
  TabController? _tabs;
  bool _showSearch = false;
  final FocusNode _searchFocus = FocusNode();
  final BehaviorSubject<String> _searchQuery =
      BehaviorSubject<String>.seeded('');
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        if (widget.record is! ServantsHistoryDay)
          Provider<CheckListOptions<Person>>(
            create: (_) {
              bool isSameDay = DateTime.now()
                      .difference(widget.record.day!.toDate())
                      .inDays ==
                  0;
              return CheckListOptions(
                  itemsStream: Person.getAllForUser(orderBy: 'Name'),
                  searchQuery: _searchQuery,
                  day: widget.record,
                  dayOptions: HistoryDayOptions(
                    grouped: !isSameDay,
                    showOnly: isSameDay ? null : true,
                    enabled: isSameDay,
                  ),
                  getGroupedData: personsByClassRef,
                  type: DayListType.Meeting);
            },
          )
        else
          Provider<CheckListOptions<User>>(
            create: (_) {
              bool isSameDay = DateTime.now()
                      .difference(widget.record.day!.toDate())
                      .inDays ==
                  0;
              return CheckListOptions(
                  itemsStream: User.getAllForUser(),
                  searchQuery: _searchQuery,
                  day: widget.record,
                  dayOptions: HistoryDayOptions(
                    grouped: !isSameDay,
                    showOnly: isSameDay ? null : true,
                    enabled: isSameDay,
                  ),
                  getGroupedData: usersByClassRef,
                  type: DayListType.Meeting);
            },
          ),
      ],
      builder: (context, body) {
        return Scaffold(
          appBar: AppBar(
            title: _showSearch
                ? TextField(
                    focusNode: _searchFocus,
                    style: Theme.of(context).textTheme.headline6!.copyWith(
                        color:
                            Theme.of(context).primaryTextTheme.headline6!.color),
                    decoration: InputDecoration(
                        suffixIcon: IconButton(
                          icon: Icon(Icons.close,
                              color: Theme.of(context)
                                  .primaryTextTheme
                                  .headline6!
                                  .color),
                          onPressed: () => setState(
                            () {
                              _searchQuery.add('');
                              _showSearch = false;
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
                    onChanged: _searchQuery.add,
                  )
                : Text('كشف الحضور'),
            actions: [
              if (!_showSearch)
                IconButton(
                  icon: Icon(Icons.search),
                  onPressed: () => setState(() {
                    _searchFocus.requestFocus();
                    _showSearch = true;
                  }),
                  tooltip: 'بحث',
                ),
              if (User.instance.superAccess!)
                IconButton(
                  icon: Icon(Icons.delete),
                  onPressed: () async {
                    if (await showDialog(
                          context: context,
                          builder: (context) => AlertDialog(actions: [
                            TextButton(
                              onPressed: () => navigator.currentState!.pop(true),
                              child: Text('نعم'),
                            ),
                            TextButton(
                              onPressed: () =>
                                  navigator.currentState!.pop(false),
                              child: Text('لا'),
                            )
                          ], content: Text('هل أنت متأكد من الحذف؟')),
                        ) ==
                        true) {
                      await widget.record.ref!.delete();
                      navigator.currentState!.pop();
                    }
                  },
                ),
              IconButton(
                icon: DescribedFeatureOverlay(
                  barrierDismissible: false,
                  featureId: 'Sorting',
                  tapTarget: Icon(Icons.library_add_check_outlined),
                  title: Text('تنظيم الليستة'),
                  description: Column(
                    children: <Widget>[
                      Text('يمكنك تقسيم المخدومين حسب الفصول أو'
                          ' اظهار المخدومين الحاضرين فقط أو الغائبين فقط من هنا'),
                      OutlinedButton.icon(
                        icon: Icon(Icons.forward),
                        label: Text(
                          'التالي',
                          style: TextStyle(
                            color: Theme.of(context).textTheme.bodyText2!.color,
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
                            color: Theme.of(context).textTheme.bodyText2!.color,
                          ),
                        ),
                      ),
                    ],
                  ),
                  backgroundColor: Theme.of(context).accentColor,
                  targetColor: Theme.of(context).primaryColor,
                  textColor: Theme.of(context).primaryTextTheme.bodyText1!.color!,
                  child: Icon(Icons.library_add_check_outlined),
                ),
                onPressed: () {
                  var dayOptions = (widget.record is! ServantsHistoryDay
                          ? context.read<CheckListOptions<Person>>()
                          : context.read<CheckListOptions<User>>())
                      .dayOptions;
                  showDialog(
                    context: context,
                    builder: (context2) => SimpleDialog(
                      children: [
                        Row(
                          children: [
                            Checkbox(
                              value: dayOptions.grouped.value,
                              onChanged: (value) {
                                dayOptions.grouped.add(value);
                                navigator.currentState!.pop();
                              },
                            ),
                            GestureDetector(
                              onTap: () {
                                dayOptions.grouped
                                    .add(!dayOptions.grouped.value!);
                                navigator.currentState!.pop();
                              },
                              child: Text('تقسيم حسب الفصول'),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Checkbox(
                              value: dayOptions.showSubtitlesInGroups.value,
                              onChanged: (value) {
                                dayOptions.showSubtitlesInGroups.add(value);
                                navigator.currentState!.pop();
                              },
                            ),
                            GestureDetector(
                              onTap: () {
                                dayOptions.showSubtitlesInGroups.add(
                                    !dayOptions.showSubtitlesInGroups.value!);
                                navigator.currentState!.pop();
                              },
                              child: Text('اظهار عدد المخدومين داخل كل فصل'),
                            ),
                          ],
                        ),
                        Text("ملحوظة: تعمل فقط مع 'تقسيم حسب الفصول'",
                            style: Theme.of(context).textTheme.caption),
                        Container(height: 5),
                        ListTile(
                          title: Text('إظهار:'),
                          subtitle: Wrap(
                            direction: Axis.vertical,
                            children: [null, true, false]
                                .map(
                                  (i) => Row(
                                    children: [
                                      Radio<bool?>(
                                        value: i,
                                        groupValue: dayOptions.showOnly.value,
                                        onChanged: (v) {
                                          dayOptions.showOnly.add(v);
                                          navigator.currentState!.pop();
                                        },
                                      ),
                                      GestureDetector(
                                        onTap: () {
                                          dayOptions.showOnly.add(i);
                                          navigator.currentState!.pop();
                                        },
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
                },
              ),
              IconButton(
                icon: DescribedFeatureOverlay(
                  barrierDismissible: false,
                  contentLocation: ContentLocation.below,
                  featureId: 'AnalyticsToday',
                  tapTarget: const Icon(Icons.analytics_outlined),
                  title: Text('عرض تحليل لبيانات كشف اليوم'),
                  description: Column(
                    children: <Widget>[
                      Text(
                          'الأن يمكنك عرض تحليل لبيانات المخدومين خلال اليوم من هنا'),
                      OutlinedButton.icon(
                        icon: Icon(Icons.forward),
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
                  textColor: Theme.of(context).primaryTextTheme.bodyText1!.color!,
                  child: const Icon(Icons.analytics_outlined),
                ),
                onPressed: () {
                  navigator.currentState!.pushNamed('Analytics', arguments: {
                    'Day': widget.record,
                    'HistoryCollection': widget.record.ref!.parent.id
                  });
                },
              ),
            ],
            bottom: TabBar(
              controller: _tabs,
              tabs: [
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
                          .read<CheckListOptions<Person>>()
                          .originalObjectsData
                      : context
                          .read<CheckListOptions<User>>()
                          .originalObjectsData,
                  () {
                    var rslt = widget.record is! ServantsHistoryDay
                        ? context.read<CheckListOptions<Person>>()
                        : context.read<CheckListOptions<User>>();
                    if (_tabs!.index == 0) {
                      return rslt.copyWith(type: DayListType.Meeting).attended;
                    } else if (_tabs!.index == 1) {
                      return rslt.copyWith(type: DayListType.Kodas).attended;
                    } else {
                      //if (_tabs.index == 2) {
                      return rslt.copyWith(type: DayListType.Tanawol).attended;
                    }
                  }()!,
                  (Map a, Map b) => Tuple2<int, int>(a.length, b.length),
                ),
                builder: (context, snapshot) {
                  return Text(
                    (snapshot.data?.item2 ?? 0).toString() +
                        ' مخدوم حاضر و' +
                        ((snapshot.data?.item1 ?? 0) -
                                (snapshot.data?.item2 ?? 0))
                            .toString() +
                        ' مخدوم غائب من اجمالي ' +
                        (snapshot.data?.item1 ?? 0).toString() +
                        ' مخدوم',
                    textAlign: TextAlign.center,
                    textScaleFactor: 0.99,
                    strutStyle:
                        StrutStyle(height: IconTheme.of(context).size! / 7.5),
                    style: Theme.of(context).primaryTextTheme.bodyText1,
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
                    key: PageStorageKey('PersonsMeeting' + widget.record.id!),
                    options: context
                        .read<CheckListOptions<Person>>()
                        .copyWith(type: DayListType.Meeting),
                  ),
                  DataObjectCheckList<Person>(
                    key: PageStorageKey('PersonsKodas' + widget.record.id!),
                    options: context
                        .read<CheckListOptions<Person>>()
                        .copyWith(type: DayListType.Kodas),
                  ),
                  DataObjectCheckList<Person>(
                    key: PageStorageKey('PersonsTanawol' + widget.record.id!),
                    options: context
                        .read<CheckListOptions<Person>>()
                        .copyWith(type: DayListType.Tanawol),
                  ),
                ]
              : [
                  DataObjectCheckList<User>(
                    key: PageStorageKey('UsersMeeting' + widget.record.id!),
                    options: context
                        .read<CheckListOptions<User>>()
                        .copyWith(type: DayListType.Meeting),
                  ),
                  DataObjectCheckList<User>(
                    key: PageStorageKey('UsersKodas' + widget.record.id!),
                    options: context
                        .read<CheckListOptions<User>>()
                        .copyWith(type: DayListType.Kodas),
                  ),
                  DataObjectCheckList<User>(
                    key: PageStorageKey('UsersTanawol' + widget.record.id!),
                    options: context
                        .read<CheckListOptions<User>>()
                        .copyWith(type: DayListType.Tanawol),
                  ),
                ],
        );
      }),
    );
  }

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    WidgetsBinding.instance!.addPostFrameCallback((timeStamp) async {
      if (DateTime.now().difference(widget.record.day!.toDate()).inDays != 0)
        return;
      try {
        if ((await widget.record.ref!.get(dataSource)).exists) {
          await widget.record.ref!.update(widget.record.getMap());
        } else {
          await widget.record.ref!.set(widget.record.getMap());
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
            title: Text('كيفية استخدام كشف الحضور'),
            content: Text('1.يمكنك تسجيل حضور مخدوم بالضغط عليه وسيقوم'
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
                child: Text('تم'),
              )
            ],
          ),
        );
        await Hive.box<bool>('FeatureDiscovery').put('DayInstructions', true);
        FeatureDiscovery.discoverFeatures(
            context, ['Sorting', 'AnalyticsToday']);
      }
    });
  }
}
