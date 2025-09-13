import 'dart:async';

import 'package:churchdata_core/churchdata_core.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:intl/intl.dart';
import 'package:meetinghelper/controllers.dart';
import 'package:meetinghelper/models.dart';
import 'package:meetinghelper/repositories.dart';
import 'package:meetinghelper/services/share_service.dart';
import 'package:meetinghelper/utils/globals.dart';
import 'package:meetinghelper/utils/helpers.dart';
import 'package:meetinghelper/widgets.dart';
import 'package:meetinghelper/widgets/lazy_tab_page.dart';
import 'package:provider/provider.dart';
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
  late TabController _previous = TabController(length: 3, vsync: this);
  final BehaviorSubject<bool> _showSearch = BehaviorSubject<bool>.seeded(false);
  final BehaviorSubject<String> _searchSubject = BehaviorSubject<String>.seeded(
    '',
  );
  final FocusNode _searchFocus = FocusNode();

  late final HistoryDayOptions dayOptions;
  late final DayCheckListController<Class?, Person> baseController;

  final Map<String, DayCheckListController<DataObject?, Person>>
  _listControllers = {};

  final _sorting = GlobalKey();
  final _lockUnchecks = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Tuple2<TabController, List<Service>>>(
      initialData: Tuple2(_previous, []),
      stream: MHDatabaseRepo.I.services.getAll(onlyShownInHistory: true).map((
        services,
      ) {
        if (services.length + 3 != _previous.length) {
          _previous = TabController(
            length: services.length + 3,
            vsync: this,
            initialIndex: _previous.index,
          );
        }

        return Tuple2(_previous, services);
      }),
      builder: (context, servicesSnapshot) {
        final tabController = servicesSnapshot.requireData.item1;

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
                tooltip: 'تنظيم الليستة',
                icon: const Icon(Icons.filter_list),
                onPressed: () => _showShareAttendanceDialog(context),
              ),
              PopupMenuButton(
                key: _sorting,
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'analysis',
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      spacing: 8,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.analytics_outlined),
                        Text('تحليل بيانات كشف اليوم'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'share',
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      spacing: 8,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [Icon(Icons.share), Text('مشاركة الكشف')],
                    ),
                  ),
                  if (User.instance.permissions.changeHistory &&
                      DateTime.now()
                              .difference(widget.record.day.toDate())
                              .inDays !=
                          0)
                    PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        spacing: 8,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (dayOptions.enabled.value) ...[
                            const Icon(Icons.check_circle),
                            const Text('اغلاق وضع التعديل'),
                          ] else ...[
                            const Icon(Icons.edit),
                            const Text('تعديل الكشف'),
                          ],
                        ],
                      ),
                    ),
                  if (User.instance.permissions.superAccess)
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        spacing: 8,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.delete_forever, color: Colors.red),
                          Text('حذف الكشف'),
                        ],
                      ),
                    ),
                ],
                onSelected: (v) async {
                  if (v == 'delete' && User.instance.permissions.superAccess) {
                    await _delete();
                  } else if (v == 'analysis') {
                    unawaited(
                      Navigator.of(context).pushNamed(
                        'Analytics',
                        arguments: {
                          'Day': widget.record,
                          'HistoryCollection': widget.record.ref.parent.id,
                        },
                      ),
                    );
                  } else if (v == 'share') {
                    final tabIndex = tabController.index;

                    final initialTitle =
                        switch (tabIndex) {
                          0 => 'حضور الاجتماع',
                          1 => 'حضور القداس',
                          2 => 'الاعتراف',
                          final int i =>
                            'حضور ' +
                                servicesSnapshot.requireData.item2[i - 3].name,
                        } +
                        ' ليوم ' +
                        widget.record.name.replaceAll('\t', ' ');

                    bool selectGroups = false;

                    final title = await _showShareAttendanceDialog(
                      context,
                      initialTitle: initialTitle,
                      submitText: 'مشاركة الكل',
                      secondaryText: 'مشاركة فصول محددة',
                      secondaryAction: (context, title) {
                        selectGroups = true;
                        Navigator.of(context).pop(title);
                      },
                    );

                    if (title == null) {
                      return;
                    }

                    final tabIndexToListControllerName = [
                      'Meeting',
                      'Kodas',
                      'Confession',
                      ...servicesSnapshot.requireData.item2.map(
                        (service) => service.id,
                      ),
                    ];

                    final controller =
                        _listControllers[tabIndexToListControllerName[tabIndex]]!;

                    final selectedGroups = selectGroups
                        ? await _showSelectGroupsDialog(context, controller)
                        : null;

                    if (selectGroups && selectedGroups == null) return;

                    await _shareAttendance(
                      controller: controller,
                      title: title,
                      selectedGroups: selectedGroups,
                      grouped: dayOptions.grouped.value,
                      showOnly: dayOptions.sortByTimeASC.valueOrNull == null
                          ? dayOptions.showOnly.value
                          : true,
                      showSubtitlesInGroups:
                          dayOptions.showSubtitlesInGroups.value,
                    );
                  } else if (v == 'edit') {
                    dayOptions.enabled.add(!dayOptions.enabled.value);
                    dayOptions.sortByTimeASC.add(null);
                    dayOptions.showOnly.add(null);
                  }
                },
              ),
            ],
            bottom: TabBar(
              isScrollable: true,
              controller: tabController,
              tabs: [
                const Tab(text: 'حضور الاجتماع'),
                const Tab(text: 'حضور القداس'),
                const Tab(text: 'الاعتراف'),
                ...servicesSnapshot.requireData.item2.map(
                  (service) => Tab(text: service.name),
                ),
              ],
            ),
          ),
          body: TabBarView(
            controller: tabController,
            children: [
              LazyTabPage(
                tabController: tabController,
                index: 0,
                builder: (context) => DayCheckList<Class?, Person>(
                  autoDisposeController: false,
                  key: PageStorageKey(
                    (widget.record is ServantsHistoryDay
                            ? 'Users'
                            : 'Persons') +
                        'Meeting' +
                        widget.record.id,
                  ),
                  controller:
                      _listControllers.putIfAbsent(
                            'Meeting',
                            () => baseController.forType('Meeting'),
                          )
                          as DayCheckListController<Class?, Person>,
                ),
              ),
              LazyTabPage(
                tabController: tabController,
                index: 1,
                builder: (context) => DayCheckList<Class?, Person>(
                  autoDisposeController: false,
                  key: PageStorageKey(
                    (widget.record is ServantsHistoryDay
                            ? 'Users'
                            : 'Persons') +
                        'Kodas' +
                        widget.record.id,
                  ),
                  controller:
                      _listControllers.putIfAbsent(
                            'Kodas',
                            () => baseController.forType('Kodas'),
                          )
                          as DayCheckListController<Class?, Person>,
                ),
              ),
              LazyTabPage(
                tabController: tabController,
                index: 1,
                builder: (context) => DayCheckList<Class?, Person>(
                  autoDisposeController: false,
                  key: PageStorageKey(
                    (widget.record is ServantsHistoryDay
                            ? 'Users'
                            : 'Persons') +
                        'Confession' +
                        widget.record.id,
                  ),
                  controller:
                      _listControllers.putIfAbsent(
                            'Confession',
                            () => baseController.forType('Confession'),
                          )
                          as DayCheckListController<Class?, Person>,
                ),
              ),
              ...servicesSnapshot.requireData.item2.map(
                (service) => LazyTabPage(
                  tabController: tabController,
                  index: 1,
                  builder: (context) => DayCheckList<StudyYear?, Person>(
                    autoDisposeController: false,
                    key: PageStorageKey(
                      (widget.record is ServantsHistoryDay
                              ? 'Users'
                              : 'Persons') +
                          service.id +
                          widget.record.id,
                    ),
                    controller:
                        _listControllers.putIfAbsent(
                              service.id,
                              () => baseController.copyWithNewG<StudyYear?>(
                                type: service.id,
                                groupByStream: MHDatabaseRepo
                                    .I
                                    .persons
                                    .groupPersonsByStudyYearRef,
                                objectsPaginatableStream:
                                    PaginatableStream.loadAll(
                                      stream: service.getPersonsMembers(),
                                    ),
                              ),
                            )
                            as DayCheckListController<StudyYear?, Person>,
                  ),
                ),
              ),
            ],
          ),
          bottomNavigationBar: BottomAppBar(
            color: Theme.of(context).colorScheme.primary,
            shape: const CircularNotchedRectangle(),
            child: AnimatedBuilder(
              animation: tabController,
              builder: (context, _) =>
                  StreamBuilder<({int attended, int total})>(
                    stream:
                        Rx.combineLatest2<
                          List,
                          Map,
                          ({int attended, int total})
                        >(
                          (tabController.index <= 2
                                  ? _listControllers[tabController.index == 0
                                            ? 'Meeting'
                                            : servicesSnapshot
                                                      .requireData
                                                      .item1
                                                      .index ==
                                                  1
                                            ? 'Kodas'
                                            : 'Confesion']
                                        ?.objectsPaginatableStream
                                        .stream
                                  : _listControllers[servicesSnapshot
                                            .requireData
                                            .item2[tabController.index - 3]
                                            .id]
                                        ?.objectsPaginatableStream
                                        .stream) ??
                              Stream.value([]),
                          (tabController.index <= 2
                                  ? _listControllers[tabController.index == 0
                                            ? 'Meeting'
                                            : servicesSnapshot
                                                      .requireData
                                                      .item1
                                                      .index ==
                                                  1
                                            ? 'Kodas'
                                            : 'Confession']
                                        ?.attended
                                  : _listControllers[servicesSnapshot
                                            .requireData
                                            .item2[tabController.index - 3]
                                            .id]
                                        ?.attended) ??
                              Stream.value({}),
                          (a, b) => (total: a.length, attended: b.length),
                        ),
                    builder: (context, summarySnapshot) {
                      final TextTheme theme = Theme.of(
                        context,
                      ).primaryTextTheme;

                      final (:attended, :total) =
                          summarySnapshot.data ?? (attended: 0, total: 0);

                      return ExpansionTile(
                        expandedAlignment: Alignment.centerRight,
                        title: Text(
                          'الحضور: $attended مخدوم',
                          style: theme.bodyMedium,
                        ),
                        trailing: Icon(
                          Icons.expand_more,
                          color: theme.bodyMedium?.color,
                        ),
                        leading: StreamBuilder<bool>(
                          initialData: dayOptions.lockUnchecks.value,
                          stream: dayOptions.lockUnchecks,
                          builder: (context, data) {
                            return IconButton(
                              key: _lockUnchecks,
                              icon: Icon(
                                !data.data!
                                    ? Icons.lock_open
                                    : Icons.lock_outlined,
                                color: theme.bodyMedium?.color,
                              ),
                              tooltip: 'تثبيت الحضور',
                              onPressed: () =>
                                  dayOptions.lockUnchecks.add(!data.data!),
                            );
                          },
                        ),
                        children: [
                          Text('الغياب: ${total - attended} مخدوم'),
                          Text('اجمالي: $total مخدوم'),
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

  Future<dynamic> _showSelectGroupsDialog(
    BuildContext context,
    DayCheckListController<DataObject?, Person> fromController,
  ) async {
    final rslt = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Provider(
          create: (_) {
            final groupsStream = fromController.objectsStream
                .switchMap(
                  (currentObjects) => fromController.groupByStream != null
                      ? fromController.groupByStream!(currentObjects)
                      : Stream.value(fromController.groupBy!(currentObjects)),
                )
                .map(
                  (o) => o.keys
                      .map(
                        (g) => g ?? Class.empty().copyWith(name: 'غير محددة'),
                      )
                      .toList(),
                );

            final controller = ListController<void, DataObject>(
              objectsPaginatableStream: PaginatableStream.loadAll(
                stream: groupsStream,
              ),
            );

            groupsStream.first.then(controller.selectAll);

            return controller;
          },
          child: Builder(
            builder: (context) {
              final groupSelectionController = context
                  .read<ListController<void, DataObject>>();

              return Scaffold(
                appBar: AppBar(
                  title: const Text('اختر الفصول'),
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.select_all),
                      onPressed: groupSelectionController.selectAll,
                      tooltip: 'تحديد الكل',
                    ),
                    IconButton(
                      icon: const Icon(Icons.check_box_outline_blank),
                      onPressed: groupSelectionController.deselectAll,
                      tooltip: 'تحديد لا شئ',
                    ),
                    IconButton(
                      icon: const Icon(Icons.done),
                      onPressed: () => navigator.currentState!.pop(
                        groupSelectionController.currentSelection,
                      ),
                      tooltip: 'تم',
                    ),
                  ],
                ),
                body: DataObjectListView<void, DataObject>(
                  controller: groupSelectionController,
                  autoDisposeController: true,
                ),
              );
            },
          ),
        ),
      ),
    );

    return rslt;
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
            onPressed: () => setState(() {
              _searchSubject.add('');
              _showSearch.add(false);
            }),
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
    }
    return Text(
      'كشف ' +
          DateFormat(
            'EEEE، d MMMM y',
            'ar-EG',
          ).format(widget.record.day.toDate()),
    );
  }

  Future<String?> _showShareAttendanceDialog(
    BuildContext context, {
    String submitText = 'إغلاق',
    String? secondaryText,
    void Function(BuildContext, String)? secondaryAction,
    String? initialTitle,
  }) async {
    final TextEditingController titleController = TextEditingController(
      text: initialTitle,
    );

    return showDialog<String?>(
      context: context,
      builder: (context) => AlertDialog(
        insetPadding: const EdgeInsets.symmetric(vertical: 24.0),
        content: StatefulBuilder(
          builder: (innerContext, setState) {
            return SizedBox(
              width: 350,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (initialTitle != null)
                      TextFormField(
                        controller: titleController,
                        decoration: const InputDecoration(labelText: 'العنوان'),
                        textInputAction: TextInputAction.newline,
                        autofocus: true,
                        maxLines: null,
                      ),
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
                          child: const Text(
                            'تقسيم حسب الفصول/السنوات الدراسية',
                          ),
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
                    RadioGroup(
                      groupValue: dayOptions.sortByTimeASC.value,
                      onChanged: (v) {
                        dayOptions.sortByTimeASC.add(v);
                        setState(() {});
                      },
                      child: ListTile(
                        title: const Text('ترتيب حسب:'),
                        subtitle: Wrap(
                          direction: Axis.vertical,
                          children: [null, true, false]
                              .map(
                                (i) => Row(
                                  children: [
                                    Radio<bool?>(value: i),
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
                    ),
                    Container(height: 5),
                    RadioGroup(
                      groupValue: dayOptions.sortByTimeASC.value == null
                          ? dayOptions.showOnly.value
                          : true,
                      onChanged: (v) {
                        dayOptions.showOnly.add(v);
                        setState(() {});
                      },
                      child: ListTile(
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
                                      enabled:
                                          dayOptions.sortByTimeASC.value ==
                                          null,
                                    ),
                                    GestureDetector(
                                      onTap:
                                          dayOptions.sortByTimeASC.value == null
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
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        actions: [
          if (secondaryText != null)
            TextButton(
              onPressed: () => secondaryAction!(context, titleController.text),
              child: Text(secondaryText),
            ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(titleController.text),
            child: Text(submitText),
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
            ..setContexts('Record', widget.record.toJson()),
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
            content: const Text(
              '1.يمكنك تسجيل حضور مخدوم بالضغط عليه وسيقوم'
              ' البرنامج بتسجيل الحضور في الوقت الحالي'
              '\n2.يمكنك تغيير وقت حضور المخدوم'
              ' عن طريق الضغط مطولا عليه ثم تغيير الوقت'
              '\n3.يمكنك اضافة ملاحظات على حضور المخدوم (مثلا: جاء متأخرًا بسبب كذا) عن'
              ' طريق الضغط مطولا على المخدوم واضافة الملاحظات'
              '\n4.يمكنك عرض معلومات المخدوم عن طريق الضغط مطولا عليه'
              ' ثم الضغط على عرض بيانات المخدوم',
            ),
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
  // When grouped:
  // title (n of total attended):
  //   group-name (n of total attended):
  //     person 1
  //     person 2 (absent)
  // When not grouped:
  // title (n of total attended):
  //   person 1
  //   person 2 (absent)

  Future<void> _shareAttendance({
    required DayCheckListController<DataObject?, Person> controller,
    required String title,
    required bool grouped,
    required bool? showOnly,
    required bool showSubtitlesInGroups,
    Set<DataObject?>? selectedGroups,
  }) async {
    final StringBuffer buffer = StringBuffer(title)
      ..write(' (الحضور ')
      ..write(controller.currentAttended?.length ?? '0')
      ..write(' من ')
      ..write((await controller.objectsPaginatableStream.stream.first).length)
      ..write('):\n');

    void _writePersons(List<Person> persons, {bool indent = false}) {
      for (final person in persons) {
        if (indent) buffer.write('  ');

        buffer.write(person.name);

        if (!(controller.currentAttended ?? {}).containsKey(person.id)) {
          buffer
            ..write(' (')
            ..write('غياب')
            ..write(')');
        }
        buffer.write('\n');
      }
    }

    final allGroupedObjects = grouped || selectedGroups != null
        ? controller.groupByStream != null
              ? await controller.groupByStream!(controller.currentObjects).first
              : controller.groupBy!(controller.currentObjects)
        : <DataObject?, List<Person>>{};

    if (grouped) {
      for (final entry in allGroupedObjects.entries) {
        if (selectedGroups != null && !selectedGroups.contains(entry.key)) {
          continue;
        }

        buffer.write(entry.key?.name ?? 'غير محددة');

        if (showSubtitlesInGroups) {
          if (showOnly == null) {
            buffer
              ..write(' (الحضور ')
              ..write(
                entry.value
                    .where(
                      (p) =>
                          (controller.currentAttended ?? {}).containsKey(p.id),
                    )
                    .length,
              )
              ..write(' من ')
              ..write(entry.value.length);
          } else if (showOnly) {
            buffer
              ..write(' (')
              ..write(
                entry.value
                    .where(
                      (p) =>
                          (controller.currentAttended ?? {}).containsKey(p.id),
                    )
                    .length,
              );
          } else {
            buffer
              ..write(' (')
              ..write(
                entry.value
                    .where(
                      (p) =>
                          !(controller.currentAttended ?? {}).containsKey(p.id),
                    )
                    .length,
              );
          }

          buffer.write(')');
        }

        buffer.write(':\n');

        _writePersons(entry.value, indent: true);

        buffer.write('\n');
      }
    } else if (selectedGroups != null) {
      final filteredPersons = selectedGroups
          .map((g) => allGroupedObjects[g] ?? [])
          .expand((e) => e)
          .toSet();

      _writePersons(
        controller.currentObjects.where(filteredPersons.contains).toList(),
      );
    } else {
      _writePersons(controller.currentObjects);
    }

    unawaited(MHShareService.I.shareText(buffer.toString()));
  }

  @override
  Future<void> dispose() async {
    super.dispose();
    await _showSearch.close();
    await Future.wait(_listControllers.values.map((c) => c.dispose()));
  }
}
