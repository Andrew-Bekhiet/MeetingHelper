import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:meetinghelper/models/data/class.dart';
import 'package:meetinghelper/models/data/person.dart';
import 'package:meetinghelper/models/data/service.dart';
import 'package:meetinghelper/models/data/user.dart';
import 'package:meetinghelper/models/history/history_record.dart';
import 'package:meetinghelper/models/hive_persistence_provider.dart';
import 'package:meetinghelper/models/list_controllers.dart';
import 'package:meetinghelper/models/mini_models.dart';
import 'package:meetinghelper/utils/globals.dart';
import 'package:meetinghelper/utils/helpers.dart';
import 'package:meetinghelper/views/list.dart';
import 'package:provider/provider.dart';
import 'package:rxdart/rxdart.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

class Day extends StatefulWidget {
  final HistoryDay record;

  const Day({Key? key, required this.record}) : super(key: key);

  @override
  State<Day> createState() => _DayState();
}

class _DayState extends State<Day> with TickerProviderStateMixin {
  TabController? _previous;
  final BehaviorSubject<bool> _showSearch = BehaviorSubject<bool>.seeded(false);
  final FocusNode _searchFocus = FocusNode();

  final Map<String, CheckListController> _listControllers = {};

  final _sorting = GlobalKey();
  final _analyticsToday = GlobalKey();
  final _lockUnchecks = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Tuple2<TabController, List<Service>>>(
      initialData: Tuple2(_previous!, []),
      stream: Service.getAllForUserForHistory().map((snapshot) {
        if (snapshot.length + 3 != _previous?.length)
          _previous = TabController(
              length: snapshot.length + 3,
              vsync: this,
              initialIndex: _previous?.index ?? 0);

        return Tuple2(_previous!, snapshot);
      }),
      builder: (context, snapshot) {
        return MultiProvider(
          providers: [
            if (widget.record is! ServantsHistoryDay)
              Provider<CheckListController<Person, Class>>(
                create: (_) {
                  final bool isSameDay = DateTime.now()
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
                    type: 'Meeting',
                  );
                },
                dispose: (context, c) => c.dispose(),
              )
            else
              Provider<CheckListController<User, Class>>(
                create: (_) {
                  final bool isSameDay = DateTime.now()
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
                    type: 'Meeting',
                  );
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
                  builder: _buildSearchBar,
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
                    key: _analyticsToday,
                    tooltip: 'تحليل بيانات كشف اليوم',
                    icon: const Icon(Icons.analytics_outlined),
                    onPressed: () {
                      navigator.currentState!.pushNamed('Analytics',
                          arguments: {
                            'Day': widget.record,
                            'HistoryCollection': widget.record.ref.parent.id
                          });
                    },
                  ),
                  PopupMenuButton(
                    key: _sorting,
                    onSelected: (v) async {
                      if (v == 'delete' && User.instance.superAccess) {
                        await _delete();
                      } else if (v == 'sorting') {
                        await _showSortingOptions(context);
                      } else if (v == 'edit') {
                        final dayOptions = (widget.record is! ServantsHistoryDay
                                ? context
                                    .read<CheckListController<Person, Class>>()
                                : context
                                    .read<CheckListController<User, Class>>())
                            .dayOptions;
                        dayOptions.enabled.add(!dayOptions.enabled.value);
                        dayOptions.sortByTimeASC.add(null);
                        dayOptions.showOnly.add(null);
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'sorting',
                        child: Text('تنظيم الليستة'),
                      ),
                      if (User.instance.changeHistory &&
                          DateTime.now()
                                  .difference(widget.record.day.toDate())
                                  .inDays !=
                              0)
                        PopupMenuItem(
                          value: 'edit',
                          child: (widget.record is! ServantsHistoryDay
                                      ? context.read<
                                          CheckListController<Person, Class>>()
                                      : context.read<
                                          CheckListController<User, Class>>())
                                  .dayOptions
                                  .enabled
                                  .value
                              ? const Text('اغلاق وضع التعديل')
                              : const Text('تعديل الكشف'),
                        ),
                      if (User.instance.superAccess)
                        const PopupMenuItem(
                          value: 'delete',
                          child: Text('حذف الكشف'),
                        ),
                    ],
                  ),
                ],
                bottom: TabBar(
                  isScrollable: true,
                  controller: snapshot.requireData.item1,
                  tabs: [
                    const Tab(text: 'حضور الاجتماع'),
                    const Tab(text: 'حضور القداس'),
                    const Tab(text: 'الاعتراف'),
                    ...snapshot.requireData.item2.map(
                      (service) => Tab(text: service.name),
                    ),
                  ],
                ),
              ),
              body: body,
              bottomNavigationBar: BottomAppBar(
                color: Theme.of(context).colorScheme.primary,
                shape: const CircularNotchedRectangle(),
                child: AnimatedBuilder(
                  animation: snapshot.requireData.item1,
                  builder: (context, _) => StreamBuilder<Tuple2<int, int>>(
                    stream: Rx.combineLatest2<Map, Map, Tuple2<int, int>>(
                      (snapshot.requireData.item1.index <= 2
                              ? _listControllers[snapshot
                                              .requireData.item1.index ==
                                          0
                                      ? 'Meeting'
                                      : snapshot.requireData.item1.index == 1
                                          ? 'Kodas'
                                          : 'Confesion']
                                  ?.originalObjectsData
                              : _listControllers[snapshot
                                      .requireData
                                      .item2[
                                          snapshot.requireData.item1.index - 3]
                                      .id]
                                  ?.originalObjectsData) ??
                          Stream.value({}),
                      (snapshot.requireData.item1.index <= 2
                              ? _listControllers[snapshot
                                              .requireData.item1.index ==
                                          0
                                      ? 'Meeting'
                                      : snapshot.requireData.item1.index == 1
                                          ? 'Kodas'
                                          : 'Confession']
                                  ?.attended
                              : _listControllers[snapshot
                                      .requireData
                                      .item2[
                                          snapshot.requireData.item1.index - 3]
                                      .id]
                                  ?.attended) ??
                          Stream.value({}),
                      (Map a, Map b) => Tuple2<int, int>(a.length, b.length),
                    ),
                    builder: (context, snapshot) {
                      final TextTheme theme =
                          Theme.of(context).primaryTextTheme;
                      return ExpansionTile(
                        expandedAlignment: Alignment.centerRight,
                        title: Text(
                          'الحضور: ' +
                              (snapshot.data?.item2.toString() ?? '0') +
                              ' مخدوم',
                          style: theme.bodyText2,
                        ),
                        trailing: Icon(Icons.expand_more,
                            color: theme.bodyText2?.color),
                        leading: StreamBuilder<bool>(
                          initialData: (widget.record is! ServantsHistoryDay
                                  ? context.read<
                                      CheckListController<Person, Class>>()
                                  : context
                                      .read<CheckListController<User, Class>>())
                              .dayOptions
                              .lockUnchecks
                              .value,
                          stream: (widget.record is! ServantsHistoryDay
                                  ? context.read<
                                      CheckListController<Person, Class>>()
                                  : context
                                      .read<CheckListController<User, Class>>())
                              .dayOptions
                              .lockUnchecks,
                          builder: (context, data) {
                            return IconButton(
                              key: _lockUnchecks,
                              icon: Icon(
                                  !data.data!
                                      ? Icons.lock_open
                                      : Icons.lock_outlined,
                                  color: theme.bodyText2?.color),
                              tooltip: 'تثبيت الحضور',
                              onPressed: () => (widget.record
                                          is! ServantsHistoryDay
                                      ? context.read<
                                          CheckListController<Person, Class>>()
                                      : context.read<
                                          CheckListController<User, Class>>())
                                  .dayOptions
                                  .lockUnchecks
                                  .add(!data.data!),
                            );
                          },
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
          child: Builder(
            builder: (context) {
              return TabBarView(
                controller: snapshot.requireData.item1,
                children: widget.record is! ServantsHistoryDay
                    ? [
                        DataObjectCheckList<Person, Class>(
                          autoDisposeController: false,
                          key: PageStorageKey(
                              'PersonsMeeting' + widget.record.id),
                          options: () {
                            final tmp = context
                                .read<CheckListController<Person, Class>>()
                                .copyWith(type: 'Meeting');
                            _listControllers['Meeting'] = tmp;
                            return tmp;
                          }(),
                        ),
                        DataObjectCheckList<Person, Class>(
                          autoDisposeController: false,
                          key:
                              PageStorageKey('PersonsKodas' + widget.record.id),
                          options: () {
                            final tmp = context
                                .read<CheckListController<Person, Class>>()
                                .copyWith(type: 'Kodas');
                            _listControllers['Kodas'] = tmp;
                            return tmp;
                          }(),
                        ),
                        DataObjectCheckList<Person, Class>(
                          autoDisposeController: false,
                          key: PageStorageKey(
                              'PersonsConfession' + widget.record.id),
                          options: () {
                            final tmp = context
                                .read<CheckListController<Person, Class>>()
                                .copyWith(type: 'Confession');
                            _listControllers['Confession'] = tmp;
                            return tmp;
                          }(),
                        ),
                        ...snapshot.requireData.item2.map(
                          (service) => DataObjectCheckList<Person, StudyYear>(
                            autoDisposeController: false,
                            key: PageStorageKey(
                                'Persons' + service.id + widget.record.id),
                            options: () {
                              final parent = context
                                  .read<CheckListController<Person, Class>>();

                              final tmp =
                                  CheckListController<Person, StudyYear>(
                                day: parent.day,
                                dayOptions: parent.dayOptions,
                                type: service.id,
                                groupBy: personsByStudyYearRef,
                                itemBuilder: parent.itemBuilder,
                                items: parent.items,
                                itemsStream: service.getPersonsMembersLive(),
                                onLongPress: parent.onLongPress,
                                searchQuery: parent.searchQuery,
                                tap: parent.tap,
                              );

                              _listControllers[service.id] = tmp;
                              return tmp;
                            }(),
                          ),
                        )
                      ]
                    : [
                        DataObjectCheckList<User, Class>(
                          autoDisposeController: false,
                          key:
                              PageStorageKey('UsersMeeting' + widget.record.id),
                          options: () {
                            final tmp = context
                                .read<CheckListController<User, Class>>()
                                .copyWith(type: 'Meeting');
                            _listControllers['Meeting'] = tmp;
                            return tmp;
                          }(),
                        ),
                        DataObjectCheckList<User, Class>(
                          autoDisposeController: false,
                          key: PageStorageKey('UsersKodas' + widget.record.id),
                          options: () {
                            final tmp = context
                                .read<CheckListController<User, Class>>()
                                .copyWith(type: 'Kodas');
                            _listControllers['Kodas'] = tmp;
                            return tmp;
                          }(),
                        ),
                        DataObjectCheckList<User, Class>(
                          autoDisposeController: false,
                          key: PageStorageKey(
                              'UsersConfession' + widget.record.id),
                          options: () {
                            final tmp = context
                                .read<CheckListController<User, Class>>()
                                .copyWith(type: 'Confession');
                            _listControllers['Confession'] = tmp;
                            return tmp;
                          }(),
                        ),
                        ...snapshot.requireData.item2.map(
                          (service) => DataObjectCheckList<User, StudyYear>(
                            autoDisposeController: false,
                            key: PageStorageKey(
                                'Users' + service.id + widget.record.id),
                            options: () {
                              final parent = context
                                  .read<CheckListController<User, Class>>();

                              final tmp = CheckListController<User, StudyYear>(
                                day: parent.day,
                                dayOptions: parent.dayOptions,
                                type: service.id,
                                groupBy: personsByStudyYearRef,
                                itemBuilder: parent.itemBuilder,
                                items: parent.items,
                                itemsStream: service.getUsersMembersLive(),
                                onLongPress: parent.onLongPress,
                                searchQuery: parent.searchQuery,
                                tap: parent.tap,
                              );

                              _listControllers[service.id] = tmp;
                              return tmp;
                            }(),
                          ),
                        )
                      ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildSearchBar(BuildContext context, AsyncSnapshot<bool> data) {
    if (data.requireData) {
      return TextField(
        focusNode: _searchFocus,
        style: Theme.of(context).textTheme.headline6!.copyWith(
            color: Theme.of(context).primaryTextTheme.headline6!.color),
        decoration: InputDecoration(
            suffixIcon: IconButton(
              icon: Icon(Icons.close,
                  color: Theme.of(context).primaryTextTheme.headline6!.color),
              onPressed: () => setState(
                () {
                  if (widget.record is! ServantsHistoryDay)
                    context
                        .read<CheckListController<Person, Class>>()
                        .searchQuery
                        .add('');
                  else
                    context
                        .read<CheckListController<User, Class>>()
                        .searchQuery
                        .add('');
                  _showSearch.add(false);
                },
              ),
            ),
            hintStyle: Theme.of(context).textTheme.headline6!.copyWith(
                color: Theme.of(context).primaryTextTheme.headline6!.color),
            icon: Icon(Icons.search,
                color: Theme.of(context).primaryTextTheme.headline6!.color),
            hintText: 'بحث ...'),
        onChanged: widget.record is! ServantsHistoryDay
            ? context.read<CheckListController<Person, Class>>().searchQuery.add
            : context.read<CheckListController<User, Class>>().searchQuery.add,
      );
    } else {
      return const Text('كشف الحضور');
    }
  }

  Future<void> _showSortingOptions(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (context2) => AlertDialog(
        insetPadding: const EdgeInsets.symmetric(vertical: 24.0),
        content: StatefulBuilder(builder: (innerContext, setState) {
          final dayOptions = (widget.record is! ServantsHistoryDay
                  ? context.read<CheckListController<Person, Class>>()
                  : context.read<CheckListController<User, Class>>())
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
                      child: const Text('تقسيم حسب الفصول/السنوات الدراسية'),
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
    _previous = TabController(length: 3, vsync: this);
    WidgetsBinding.instance!.addPostFrameCallback((timeStamp) async {
      if (DateTime.now().difference(widget.record.day.toDate()).inDays != 0)
        return;
      try {
        if (!(await widget.record.ref.get(dataSource)).exists) {
          await widget.record.ref.set(widget.record.getMap());
        }
      } catch (err, stack) {
        await Sentry.captureException(
          err,
          stackTrace: stack,
          withScope: (scope) => scope
            ..setTag('LasErrorIn', 'Day.initState')
            ..setExtra('Record', widget.record.getMap()),
        );
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
        await HivePersistenceProvider.instance.completeStep('DayInstructions');
      }

      if ((['Sorting', 'AnalyticsToday', 'LockUnchecks']
            ..removeWhere(HivePersistenceProvider.instance.hasCompletedStep))
          .isNotEmpty)
        TutorialCoachMark(
          context,
          focusAnimationDuration: const Duration(milliseconds: 200),
          targets: [
            TargetFocus(
              enableOverlayTab: true,
              contents: [
                TargetContent(
                  child: Text(
                    'يمكنك تقسيم المخدومين حسب الفصول أو'
                    ' السنوات الدراسية أو '
                    ' اظهار المخدومين الحاضرين فقط أو '
                    'الغائبين والترتيب حسب وقت الحضور فقط من هنا',
                    style: Theme.of(context).textTheme.subtitle1?.copyWith(
                        color: Theme.of(context).colorScheme.onSecondary),
                  ),
                ),
              ],
              identify: 'Sorting',
              keyTarget: _sorting,
              color: Theme.of(context).colorScheme.secondary,
            ),
            TargetFocus(
              enableOverlayTab: true,
              contents: [
                TargetContent(
                  child: Text(
                    'عرض تحليل واحصاء لعدد الحضور اليوم من هنا',
                    style: Theme.of(context).textTheme.subtitle1?.copyWith(
                        color: Theme.of(context).colorScheme.onSecondary),
                  ),
                ),
              ],
              identify: 'AnalyticsToday',
              keyTarget: _analyticsToday,
              color: Theme.of(context).colorScheme.secondary,
            ),
            TargetFocus(
              enableOverlayTab: true,
              alignSkip: Alignment.topLeft,
              contents: [
                TargetContent(
                  align: ContentAlign.top,
                  child: Text(
                    'يقوم البرنامج تلقائيًا بطلب تأكيد لإزالة حضور مخدوم'
                    '\nاذا اردت الغاء هذه الخاصية يمكنك الضغط هنا',
                    style: Theme.of(context).textTheme.subtitle1?.copyWith(
                        color: Theme.of(context).colorScheme.onSecondary),
                  ),
                ),
              ],
              identify: 'LockUnchecks',
              keyTarget: _lockUnchecks,
              color: Theme.of(context).colorScheme.secondary,
            ),
          ],
          alignSkip: Alignment.bottomLeft,
          textSkip: 'تخطي',
          onClickOverlay: (t) async {
            await HivePersistenceProvider.instance.completeStep(t.identify);
          },
          onClickTarget: (t) async {
            await HivePersistenceProvider.instance.completeStep(t.identify);
          },
        ).show();
    });
  }

  @override
  Future<void> dispose() async {
    super.dispose();
    await _showSearch.close();
    await Future.wait(_listControllers.values.map((c) => c.dispose()));
  }
}
