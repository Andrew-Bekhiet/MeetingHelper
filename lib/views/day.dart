import 'package:feature_discovery/feature_discovery.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:meetinghelper/models/list_options.dart';
import 'package:meetinghelper/models/models.dart';
import 'package:meetinghelper/models/user.dart';
import 'package:meetinghelper/views/list.dart';
import 'package:meetinghelper/views/lists/lists.dart';
import 'package:meetinghelper/utils/globals.dart';
import 'package:meetinghelper/utils/helpers.dart';
import 'package:provider/provider.dart';

class Day extends StatefulWidget {
  final HistoryDay record;

  Day({@required this.record}) : assert(record != null);

  @override
  State<Day> createState() => _DayState();
}

class _DayState extends State<Day> with SingleTickerProviderStateMixin {
  TabController _tabs;
  bool _showSearch = false;
  final FocusNode _searchFocus = FocusNode();

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ListenableProvider<SearchString>(create: (_) => SearchString('')),
        ListenableProvider<HistoryDayOptions>(
            create: (_) => HistoryDayOptions(
                grouped: DateTime.now()
                        .difference(widget.record.day.toDate())
                        .inDays !=
                    0,
                showTrueOnly: DateTime.now()
                        .difference(widget.record.day.toDate())
                        .inDays !=
                    0,
                enabled: DateTime.now()
                        .difference(widget.record.day.toDate())
                        .inDays ==
                    0)),
      ],
      builder: (context, body) {
        return Scaffold(
          appBar: AppBar(
            title: _showSearch
                ? TextField(
                    focusNode: _searchFocus,
                    style: Theme.of(context).textTheme.headline6.copyWith(
                        color:
                            Theme.of(context).primaryTextTheme.headline6.color),
                    decoration: InputDecoration(
                        suffixIcon: IconButton(
                          icon: Icon(Icons.close,
                              color: Theme.of(context)
                                  .primaryTextTheme
                                  .headline6
                                  .color),
                          onPressed: () => setState(
                            () {
                              context.read<SearchString>().value = '';
                              _showSearch = false;
                            },
                          ),
                        ),
                        hintStyle: Theme.of(context)
                            .textTheme
                            .headline6
                            .copyWith(
                                color: Theme.of(context)
                                    .primaryTextTheme
                                    .headline6
                                    .color),
                        icon: Icon(Icons.search,
                            color: Theme.of(context)
                                .primaryTextTheme
                                .headline6
                                .color),
                        hintText: 'بحث ...'),
                    onChanged: (t) => context.read<SearchString>().value = t,
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
              IconButton(
                icon: Icon(Icons.delete),
                onPressed: () async {
                  if (await showDialog(
                    context: context,
                    builder: (context) => AlertDialog(actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: Text('نعم'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: Text('لا'),
                      )
                    ], content: Text('هل أنت متأكد من الحذف؟')),
                  )) {
                    await widget.record.ref.delete();
                    Navigator.pop(context);
                  }
                },
              ),
              Consumer<HistoryDayOptions>(
                builder: (context, options, _) => IconButton(
                  icon: DescribedFeatureOverlay(
                    barrierDismissible: false,
                    featureId: 'Sorting',
                    tapTarget: Icon(Icons.filter_list),
                    title: Text('تنظيم الليستة'),
                    description: Column(
                      children: <Widget>[
                        Text('يمكنك تقسيم المخدومين حسب الفصول أو'
                            ' اظهار المخدومين الحاضرين فقط من هنا'),
                        OutlinedButton.icon(
                          icon: Icon(Icons.forward),
                          label: Text(
                            'التالي',
                            style: TextStyle(
                              color:
                                  Theme.of(context).textTheme.bodyText2.color,
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
                              color:
                                  Theme.of(context).textTheme.bodyText2.color,
                            ),
                          ),
                        ),
                      ],
                    ),
                    backgroundColor: Theme.of(context).accentColor,
                    targetColor: Theme.of(context).primaryColor,
                    textColor:
                        Theme.of(context).primaryTextTheme.bodyText1.color,
                    child: Icon(Icons.filter_list),
                  ),
                  onPressed: () {
                    var orderOptions = context.read<OrderOptions>();
                    showDialog(
                      context: context,
                      builder: (context) => SimpleDialog(
                        children: [
                          Row(
                            children: [
                              Checkbox(
                                value: options.grouped,
                                onChanged: (value) {
                                  options.grouped = value;
                                  Navigator.pop(context);
                                },
                              ),
                              GestureDetector(
                                onTap: () {
                                  options.grouped = !options.grouped;
                                  Navigator.pop(context);
                                },
                                child: Text('تقسيم حسب الفصول'),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Checkbox(
                                value: options.showTrueOnly,
                                onChanged: (value) {
                                  options.showTrueOnly = value;
                                  Navigator.pop(context);
                                },
                              ),
                              GestureDetector(
                                onTap: () {
                                  options.showTrueOnly = !options.showTrueOnly;
                                  Navigator.pop(context);
                                },
                                child: Text('إظهار الحاضرين فقط'),
                              ),
                            ],
                          ),
                          Divider(),
                          Text('ترتيب حسب:',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          ...Person.getHumanReadableMap2()
                              .entries
                              .map((e) => RadioListTile(
                                    value: e.key,
                                    groupValue: orderOptions.personOrderBy,
                                    title: Text(e.value),
                                    onChanged: (value) {
                                      orderOptions.setPersonOrderBy(value);
                                      Navigator.pop(context);
                                    },
                                  ))
                              .toList(),
                          Divider(),
                          RadioListTile(
                            value: true,
                            groupValue: orderOptions.personASC,
                            title: Text('تصاعدي'),
                            onChanged: (value) {
                              orderOptions.setPersonASC(value);
                              Navigator.pop(context);
                            },
                          ),
                          RadioListTile(
                            value: false,
                            groupValue: orderOptions.personASC,
                            title: Text('تنازلي'),
                            onChanged: (value) {
                              orderOptions.setPersonASC(value);
                              Navigator.pop(context);
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
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
                            color: Theme.of(context).textTheme.bodyText2.color,
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
                            color: Theme.of(context).textTheme.bodyText2.color,
                          ),
                        ),
                      ),
                    ],
                  ),
                  backgroundColor: Theme.of(context).accentColor,
                  targetColor: Colors.transparent,
                  textColor: Theme.of(context).primaryTextTheme.bodyText1.color,
                  child: const Icon(Icons.analytics_outlined),
                ),
                onPressed: () {
                  Navigator.of(context)
                      .pushNamed('Analytics', arguments: widget.record);
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
        );
      },
      child: Consumer<OrderOptions>(
        builder: (context, personOrder, _) => TabBarView(
          key: ValueKey(personOrder),
          controller: _tabs,
          children: widget.record is! ServantsHistoryDay
              ? [
                  PersonsCheckList(
                    key: ValueKey(OrderOptions(
                        personOrderBy: personOrder.personOrderBy + '1',
                        personASC: personOrder.personASC)),
                    options: CheckListOptions(
                        day: widget.record,
                        documentsData: Person.getAllForUser(
                          orderBy: personOrder.personOrderBy,
                          descending: !personOrder.personASC,
                        ).map((s) => s.docs.map(Person.fromDoc).toList()),
                        type: DayListType.Meeting),
                  ),
                  PersonsCheckList(
                    key: ValueKey(OrderOptions(
                        personOrderBy: personOrder.personOrderBy + '2',
                        personASC: personOrder.personASC)),
                    options: CheckListOptions(
                        day: widget.record,
                        documentsData: Person.getAllForUser(
                          orderBy: personOrder.personOrderBy,
                          descending: !personOrder.personASC,
                        ).map((s) => s.docs.map(Person.fromDoc).toList()),
                        type: DayListType.Kodas),
                  ),
                  PersonsCheckList(
                    key: ValueKey(OrderOptions(
                        personOrderBy: personOrder.personOrderBy + '3',
                        personASC: personOrder.personASC)),
                    options: CheckListOptions(
                        day: widget.record,
                        documentsData: Person.getAllForUser(
                          orderBy: personOrder.personOrderBy,
                          descending: !personOrder.personASC,
                        ).map((s) => s.docs.map(Person.fromDoc).toList()),
                        type: DayListType.Tanawol),
                  )
                ]
              : [
                  UsersCheckList(
                    options: CheckListOptions<User>(
                        items: [],
                        day: widget.record,
                        type: DayListType.Meeting),
                  ),
                  UsersCheckList(
                    options: CheckListOptions<User>(
                        items: [], day: widget.record, type: DayListType.Kodas),
                  ),
                  UsersCheckList(
                    options: CheckListOptions<User>(
                        items: [],
                        day: widget.record,
                        type: DayListType.Tanawol),
                  ),
                ],
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) async {
      if (DateTime.now().difference(widget.record.day.toDate()).inDays != 0)
        return;
      try {
        if ((await widget.record.ref.get(dataSource)).exists) {
          await widget.record.ref.update(widget.record.getMap());
        } else {
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
                onPressed: () => Navigator.pop(context),
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
