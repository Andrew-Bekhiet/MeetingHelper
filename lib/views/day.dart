import 'package:churchdata_core/churchdata_core.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:meetinghelper/controllers.dart';
import 'package:meetinghelper/models.dart';
import 'package:meetinghelper/repositories.dart';
import 'package:meetinghelper/utils/globals.dart';
import 'package:meetinghelper/utils/helpers.dart';
import 'package:meetinghelper/widgets.dart';
import 'package:rxdart/rxdart.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

class Day extends StatefulWidget {
  final HistoryDayBase record;

  const Day({required this.record, super.key});

  @override
  State<Day> createState() => _DayState();
}

class _DayState extends State<Day> with TickerProviderStateMixin {
  TabController? _previous;
  final BehaviorSubject<bool> _showSearch = BehaviorSubject<bool>.seeded(false);
  final BehaviorSubject<String> _searchSubject =
      BehaviorSubject<String>.seeded('');
  final FocusNode _searchFocus = FocusNode();

  late final HistoryDayOptions dayOptions;
  late final DayCheckListController<Class?, Person> baseController;

  final Map<String, DayCheckListController<DataObject?, Person>>
      _listControllers = {};

  final _sorting = GlobalKey();
  final _analyticsToday = GlobalKey();
  final _lockUnchecks = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Tuple2<TabController, List<Service>>>(
      initialData: Tuple2(_previous!, []),
      stream: MHDatabaseRepo.I.services
          .getAll(onlyShownInHistory: true)
          .map((snapshot) {
        if (snapshot.length + 3 != _previous?.length) {
          _previous = TabController(
            length: snapshot.length + 3,
            vsync: this,
            initialIndex: _previous?.index ?? 0,
          );
        }

        return Tuple2(_previous!, snapshot);
      }),
      builder: (context, snapshot) {
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
                  navigator.currentState!.pushNamed(
                    'Analytics',
                    arguments: {
                      'Day': widget.record,
                      'HistoryCollection': widget.record.ref.parent.id,
                    },
                  );
                },
              ),
              PopupMenuButton(
                key: _sorting,
                onSelected: (v) async {
                  if (v == 'delete' && User.instance.permissions.superAccess) {
                    await _delete();
                  } else if (v == 'sorting') {
                    await _showSortingOptions(context);
                  } else if (v == 'edit') {
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
                  if (User.instance.permissions.changeHistory &&
                      DateTime.now()
                              .difference(widget.record.day.toDate())
                              .inDays !=
                          0)
                    PopupMenuItem(
                      value: 'edit',
                      child: dayOptions.enabled.value
                          ? const Text('اغلاق وضع التعديل')
                          : const Text('تعديل الكشف'),
                    ),
                  if (User.instance.permissions.superAccess)
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
          body: TabBarView(
            controller: snapshot.requireData.item1,
            children: [
              DayCheckList<Class?, Person>(
                autoDisposeController: false,
                key: PageStorageKey(
                  (widget.record is ServantsHistoryDay ? 'Users' : 'Persons') +
                      'Meeting' +
                      widget.record.id,
                ),
                controller: () {
                  final tmp = baseController.copyWith(type: 'Meeting');
                  _listControllers['Meeting'] = tmp;
                  return tmp;
                }(),
              ),
              DayCheckList<Class?, Person>(
                autoDisposeController: false,
                key: PageStorageKey(
                  (widget.record is ServantsHistoryDay ? 'Users' : 'Persons') +
                      'Kodas' +
                      widget.record.id,
                ),
                controller: () {
                  final tmp = baseController.copyWith(type: 'Kodas');
                  _listControllers['Kodas'] = tmp;
                  return tmp;
                }(),
              ),
              DayCheckList<Class?, Person>(
                autoDisposeController: false,
                key: PageStorageKey(
                  (widget.record is ServantsHistoryDay ? 'Users' : 'Persons') +
                      'Confession' +
                      widget.record.id,
                ),
                controller: () {
                  final tmp = baseController.copyWith(type: 'Confession');
                  _listControllers['Confession'] = tmp;
                  return tmp;
                }(),
              ),
              ...snapshot.requireData.item2.map(
                (service) => DayCheckList<StudyYear?, Person>(
                  autoDisposeController: false,
                  key: PageStorageKey(
                    (widget.record is ServantsHistoryDay
                            ? 'Users'
                            : 'Persons') +
                        service.id +
                        widget.record.id,
                  ),
                  controller: () {
                    final tmp = baseController.copyWithNewG<StudyYear?>(
                      type: service.id,
                      groupByStream:
                          MHDatabaseRepo.I.persons.groupPersonsByStudyYearRef,
                      objectsPaginatableStream: PaginatableStream.loadAll(
                        stream: service.getPersonsMembers(),
                      ),
                    );

                    _listControllers[service.id] = tmp;
                    return tmp;
                  }(),
                ),
              ),
            ],
          ),
          bottomNavigationBar: BottomAppBar(
            color: Theme.of(context).colorScheme.primary,
            shape: const CircularNotchedRectangle(),
            child: AnimatedBuilder(
              animation: snapshot.requireData.item1,
              builder: (context, _) => StreamBuilder<Tuple2<int, int>>(
                stream: Rx.combineLatest2<List, Map, Tuple2<int, int>>(
                  (snapshot.requireData.item1.index <= 2
                          ? _listControllers[
                                  snapshot.requireData.item1.index == 0
                                      ? 'Meeting'
                                      : snapshot.requireData.item1.index == 1
                                          ? 'Kodas'
                                          : 'Confesion']
                              ?.objectsStream
                          : _listControllers[snapshot
                                  .requireData
                                  .item2[snapshot.requireData.item1.index - 3]
                                  .id]
                              ?.objectsStream) ??
                      Stream.value([]),
                  (snapshot.requireData.item1.index <= 2
                          ? _listControllers[
                                  snapshot.requireData.item1.index == 0
                                      ? 'Meeting'
                                      : snapshot.requireData.item1.index == 1
                                          ? 'Kodas'
                                          : 'Confession']
                              ?.attended
                          : _listControllers[snapshot
                                  .requireData
                                  .item2[snapshot.requireData.item1.index - 3]
                                  .id]
                              ?.attended) ??
                      Stream.value({}),
                  (a, b) => Tuple2<int, int>(a.length, b.length),
                ),
                builder: (context, snapshot) {
                  final TextTheme theme = Theme.of(context).primaryTextTheme;
                  return ExpansionTile(
                    expandedAlignment: Alignment.centerRight,
                    title: Text(
                      'الحضور: ' +
                          (snapshot.data?.item2.toString() ?? '0') +
                          ' مخدوم',
                      style: theme.bodyMedium,
                    ),
                    trailing:
                        Icon(Icons.expand_more, color: theme.bodyMedium?.color),
                    leading: StreamBuilder<bool>(
                      initialData: dayOptions.lockUnchecks.value,
                      stream: dayOptions.lockUnchecks,
                      builder: (context, data) {
                        return IconButton(
                          key: _lockUnchecks,
                          icon: Icon(
                            !data.data! ? Icons.lock_open : Icons.lock_outlined,
                            color: theme.bodyMedium?.color,
                          ),
                          tooltip: 'تثبيت الحضور',
                          onPressed: () =>
                              dayOptions.lockUnchecks.add(!data.data!),
                        );
                      },
                    ),
                    children: [
                      Text(
                        'الغياب: ' +
                            ((snapshot.data?.item1 ?? 0) -
                                    (snapshot.data?.item2 ?? 0))
                                .toString() +
                            ' مخدوم',
                      ),
                      Text(
                        'اجمالي: ' +
                            (snapshot.data?.item1 ?? 0).toString() +
                            ' مخدوم',
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
          extendBody: true,
        );
      },
    );
  }

  Widget _buildSearchBar(BuildContext context, AsyncSnapshot<bool> data) {
    if (data.requireData) {
      return TextField(
        focusNode: _searchFocus,
        style: Theme.of(context).textTheme.titleLarge!.copyWith(
              color: Theme.of(context).primaryTextTheme.titleLarge!.color,
            ),
        decoration: InputDecoration(
          suffixIcon: IconButton(
            icon: Icon(
              Icons.close,
              color: Theme.of(context).primaryTextTheme.titleLarge!.color,
            ),
            onPressed: () => setState(
              () {
                _searchSubject.add('');
                _showSearch.add(false);
              },
            ),
          ),
          hintStyle: Theme.of(context).textTheme.titleLarge!.copyWith(
                color: Theme.of(context).primaryTextTheme.titleLarge!.color,
              ),
          icon: Icon(
            Icons.search,
            color: Theme.of(context).primaryTextTheme.titleLarge!.color,
          ),
          hintText: 'بحث ...',
        ),
        onChanged: _searchSubject.add,
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
        content: StatefulBuilder(
          builder: (innerContext, setState) {
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
                                dayOptions.showSubtitlesInGroups.add(
                                  !dayOptions.showSubtitlesInGroups.value,
                                );
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
                                  child: Text(
                                    i == null
                                        ? 'الاسم'
                                        : i
                                            ? 'وقت الحضور'
                                            : 'وقت الحضور (المتأخر أولا)',
                                  ),
                                ),
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
                                  child: Text(
                                    i == null
                                        ? 'الكل'
                                        : i
                                            ? 'الحاضرين فقط'
                                            : 'الغائبين فقط',
                                  ),
                                ),
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
        actions: [
          TextButton(
            onPressed: () {
              navigator.currentState!.pop();
            },
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }

  Future<void> _delete() async {
    if (await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            actions: [
              TextButton(
                onPressed: () => navigator.currentState!.pop(true),
                child: const Text('نعم'),
              ),
              TextButton(
                onPressed: () => navigator.currentState!.pop(false),
                child: const Text('لا'),
              ),
            ],
            content: const Text('هل أنت متأكد من الحذف؟'),
          ),
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

    final bool isSameDay =
        DateTime.now().difference(widget.record.day.toDate()).inDays == 0;
    dayOptions = HistoryDayOptions(
      grouped: !isSameDay,
      showOnly: isSameDay ? null : true,
      enabled: isSameDay && User.instance.permissions.recordHistory,
      sortByTimeASC: isSameDay ? null : true,
    );

    baseController = DayCheckListController(
      searchQuery: _searchSubject,
      query: PaginatableStream.loadAll(
        stream: widget.record is ServantsHistoryDay
            ? MHDatabaseRepo.instance.users.getAllUsersData()
            : MHDatabaseRepo.instance.persons.getAll(),
      ),
      day: widget.record,
      dayOptions: dayOptions,
      groupByStream: MHDatabaseRepo.I.persons.groupPersonsByClassRef,
      type: 'Meeting',
    );

    WidgetsBinding.instance.addPostFrameCallback((timeStamp) async {
      if (DateTime.now().difference(widget.record.day.toDate()).inDays != 0) {
        return;
      }
      try {
        if (!(await widget.record.ref.get()).exists) {
          await widget.record.ref.set(widget.record.toJson());
        }
      } catch (err, stack) {
        await Sentry.captureException(
          err,
          stackTrace: stack,
          withScope: (scope) => scope
            ..setTag('LasErrorIn', 'Day.initState')
            ..setExtra('Record', widget.record.toJson()),
        );
        await showErrorDialog(context, err.toString(), title: 'حدث خطأ');
      }
      if (!(GetIt.I<CacheRepository>()
              .box<bool>('FeatureDiscovery')
              .get('DayInstructions') ??
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
              ),
            ],
          ),
        );
        await HivePersistenceProvider.instance.completeStep('DayInstructions');
      }

      if ((['Sorting', 'AnalyticsToday', 'LockUnchecks']
            ..removeWhere(HivePersistenceProvider.instance.hasCompletedStep))
          .isNotEmpty) {
        TutorialCoachMark(
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
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSecondary,
                        ),
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
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSecondary,
                        ),
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
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSecondary,
                        ),
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
        ).show(context: context);
      }
    });
  }

  @override
  Future<void> dispose() async {
    super.dispose();
    await _showSearch.close();
    await Future.wait(_listControllers.values.map((c) => c.dispose()));
  }
}
