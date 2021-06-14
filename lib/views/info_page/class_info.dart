import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:feature_discovery/feature_discovery.dart';
import 'package:flutter/material.dart';
import 'package:meetinghelper/models/models.dart';
import 'package:meetinghelper/utils/globals.dart';
import 'package:provider/provider.dart';
import 'package:rxdart/rxdart.dart';
import 'package:share_plus/share_plus.dart';
import 'package:tinycolor/tinycolor.dart';

import '../../models/history_property.dart';
import '../../models/list_controllers.dart';
import '../../models/order_options.dart';
import '../../models/search_filters.dart';
import '../../models/user.dart';
import '../../utils/helpers.dart';
import '../data_map.dart';
import '../list.dart';

class ClassInfo extends StatefulWidget {
  final Class? class$;

  const ClassInfo({Key? key, this.class$}) : super(key: key);

  @override
  _ClassInfoState createState() => _ClassInfoState();
}

class _ClassInfoState extends State<ClassInfo> {
  final BehaviorSubject<OrderOptions> _orderOptions =
      BehaviorSubject<OrderOptions>.seeded(OrderOptions());

  void addTap(BuildContext context) {
    navigator.currentState!
        .pushNamed('Data/EditPerson', arguments: widget.class$!.ref);
  }

  @override
  Future<void> dispose() async {
    super.dispose();
    await _orderOptions.close();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance!.addPostFrameCallback((_) {
      FeatureDiscovery.discoverFeatures(context, [
        if (User.instance.write) 'Edit',
        'Share',
        'MoreOptions',
        'EditHistory',
        'Class.Analytics',
        if (User.instance.write) 'Add'
      ]);
    });
  }

  @override
  Widget build(BuildContext context) {
    final _listOptions = DataObjectListController<Person>(
      tap: (p) => personTap(p, context),
      itemsStream: _orderOptions.switchMap(
        (order) => widget.class$!.getMembersLive(
            orderBy: order.orderBy ?? 'Name', descending: !order.asc!),
      ),
    );
    return Selector<User, bool?>(
      selector: (_, user) => user.write,
      builder: (context, permission, _) => StreamBuilder<Class?>(
        initialData: widget.class$,
        stream: widget.class$!.ref.snapshots().map(Class.fromDoc),
        builder: (context, data) {
          Class? class$ = data.data;
          if (class$ == null)
            return const Scaffold(
              body: Center(
                child: Text('تم حذف الفصل'),
              ),
            );
          return Scaffold(
            body: NestedScrollView(
              headerSliverBuilder: (context, _) => <Widget>[
                SliverAppBar(
                  backgroundColor: class$.color != Colors.transparent
                      ? (Theme.of(context).brightness == Brightness.light
                          ? TinyColor(class$.color).lighten().color
                          : TinyColor(class$.color).darken().color)
                      : null,
                  actions: class$.ref.path.startsWith('Deleted')
                      ? <Widget>[
                          if (permission!)
                            IconButton(
                              icon: const Icon(Icons.restore),
                              tooltip: 'استعادة',
                              onPressed: () {
                                recoverDoc(context, class$.ref.path);
                              },
                            )
                        ]
                      : <Widget>[
                          Selector<User, bool?>(
                            selector: (_, user) => user.write,
                            builder: (c, permission, data) => permission!
                                ? IconButton(
                                    icon: DescribedFeatureOverlay(
                                      barrierDismissible: false,
                                      contentLocation: ContentLocation.below,
                                      featureId: 'Edit',
                                      tapTarget: Icon(
                                        Icons.edit,
                                        color: IconTheme.of(context).color,
                                      ),
                                      title: const Text('تعديل'),
                                      description: Column(
                                        children: <Widget>[
                                          const Text(
                                              'يمكنك تعديل البيانات من هنا'),
                                          OutlinedButton.icon(
                                            icon: const Icon(Icons.forward),
                                            label: Text(
                                              'التالي',
                                              style: TextStyle(
                                                color: Theme.of(context)
                                                    .textTheme
                                                    .bodyText2!
                                                    .color,
                                              ),
                                            ),
                                            onPressed: () => FeatureDiscovery
                                                .completeCurrentStep(context),
                                          ),
                                          OutlinedButton(
                                            onPressed: () =>
                                                FeatureDiscovery.dismissAll(
                                                    context),
                                            child: Text(
                                              'تخطي',
                                              style: TextStyle(
                                                color: Theme.of(context)
                                                    .textTheme
                                                    .bodyText2!
                                                    .color,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      backgroundColor:
                                          Theme.of(context).accentColor,
                                      targetColor: Colors.transparent,
                                      textColor: Theme.of(context)
                                          .primaryTextTheme
                                          .bodyText1!
                                          .color!,
                                      child: Builder(
                                        builder: (context) => Stack(
                                          children: <Widget>[
                                            const Positioned(
                                              left: 1.0,
                                              top: 2.0,
                                              child: Icon(Icons.edit,
                                                  color: Colors.black54),
                                            ),
                                            Icon(Icons.edit,
                                                color: IconTheme.of(context)
                                                    .color),
                                          ],
                                        ),
                                      ),
                                    ),
                                    onPressed: () async {
                                      dynamic result = await navigator
                                          .currentState!
                                          .pushNamed('Data/EditClass',
                                              arguments: class$);
                                      if (result is DocumentReference) {
                                        scaffoldMessenger.currentState!
                                            .showSnackBar(
                                          const SnackBar(
                                            content: Text('تم الحفظ بنجاح'),
                                          ),
                                        );
                                      } else if (result == 'deleted')
                                        navigator.currentState!.pop();
                                    },
                                    tooltip: 'تعديل',
                                  )
                                : Container(),
                          ),
                          IconButton(
                            icon: DescribedFeatureOverlay(
                              barrierDismissible: false,
                              contentLocation: ContentLocation.below,
                              featureId: 'Share',
                              tapTarget: const Icon(
                                Icons.share,
                              ),
                              title: const Text('مشاركة البيانات'),
                              description: Column(
                                children: <Widget>[
                                  const Text(
                                      'يمكنك مشاركة البيانات بلينك يفتح البيانات مباشرة داخل البرنامج'),
                                  OutlinedButton.icon(
                                    icon: const Icon(Icons.forward),
                                    label: Text(
                                      'التالي',
                                      style: TextStyle(
                                        color: Theme.of(context)
                                            .textTheme
                                            .bodyText2!
                                            .color,
                                      ),
                                    ),
                                    onPressed: () =>
                                        FeatureDiscovery.completeCurrentStep(
                                            context),
                                  ),
                                  OutlinedButton(
                                    onPressed: () =>
                                        FeatureDiscovery.dismissAll(context),
                                    child: Text(
                                      'تخطي',
                                      style: TextStyle(
                                        color: Theme.of(context)
                                            .textTheme
                                            .bodyText2!
                                            .color,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              backgroundColor: Theme.of(context).accentColor,
                              targetColor: Colors.transparent,
                              textColor: Theme.of(context)
                                  .primaryTextTheme
                                  .bodyText1!
                                  .color!,
                              child: Builder(
                                builder: (context) => Stack(
                                  children: <Widget>[
                                    const Positioned(
                                      left: 1.0,
                                      top: 2.0,
                                      child: Icon(Icons.share,
                                          color: Colors.black54),
                                    ),
                                    Icon(Icons.share,
                                        color: IconTheme.of(context).color),
                                  ],
                                ),
                              ),
                            ),
                            onPressed: () async {
                              // navigator.currentState.pop();
                              await Share.share(await shareClass(class$));
                            },
                            tooltip: 'مشاركة برابط',
                          ),
                          DescribedFeatureOverlay(
                            barrierDismissible: false,
                            contentLocation: ContentLocation.below,
                            featureId: 'MoreOptions',
                            tapTarget: const Icon(
                              Icons.more_vert,
                            ),
                            title: const Text('المزيد من الخيارات'),
                            description: Column(
                              children: <Widget>[
                                const Text(
                                    'يمكنك ايجاد المزيد من الخيارات من هنا مثل: اشعار المستخدمين عن الفصل'),
                                OutlinedButton.icon(
                                  icon: const Icon(Icons.forward),
                                  label: Text(
                                    'التالي',
                                    style: TextStyle(
                                      color: Theme.of(context)
                                          .textTheme
                                          .bodyText2!
                                          .color,
                                    ),
                                  ),
                                  onPressed: () =>
                                      FeatureDiscovery.completeCurrentStep(
                                          context),
                                ),
                                OutlinedButton(
                                  onPressed: () =>
                                      FeatureDiscovery.dismissAll(context),
                                  child: Text(
                                    'تخطي',
                                    style: TextStyle(
                                      color: Theme.of(context)
                                          .textTheme
                                          .bodyText2!
                                          .color,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            backgroundColor: Theme.of(context).accentColor,
                            targetColor: Colors.transparent,
                            textColor: Theme.of(context)
                                .primaryTextTheme
                                .bodyText1!
                                .color!,
                            child: PopupMenuButton(
                              onSelected: (dynamic _) =>
                                  sendNotification(context, class$),
                              itemBuilder: (context) {
                                return [
                                  const PopupMenuItem(
                                    value: '',
                                    child:
                                        Text('ارسال إشعار للمستخدمين عن الفصل'),
                                  ),
                                ];
                              },
                            ),
                          ),
                        ],
                  expandedHeight: 250.0,
                  floating: false,
                  stretch: true,
                  pinned: true,
                  flexibleSpace: LayoutBuilder(
                    builder: (context, constraints) => FlexibleSpaceBar(
                      title: AnimatedOpacity(
                        duration: const Duration(milliseconds: 300),
                        opacity:
                            constraints.biggest.height > kToolbarHeight * 1.7
                                ? 0
                                : 1,
                        child: Text(class$.name,
                            style: const TextStyle(fontSize: 16.0)),
                      ),
                      background: class$.photo(),
                    ),
                  ),
                ),
                SliverList(
                  delegate: SliverChildListDelegate(
                    <Widget>[
                      ListTile(
                        title: Text(
                          class$.name,
                          style: Theme.of(context)
                              .textTheme
                              .headline5
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                      ListTile(
                        title: const Text('السنة الدراسية:'),
                        subtitle: FutureBuilder<String>(
                            future: class$.getStudyYearName(),
                            builder: (context, data) {
                              if (data.hasData)
                                return Text(data.data! +
                                    ' - ' +
                                    class$.getGenderName());
                              return const LinearProgressIndicator();
                            }),
                      ),
                      if (!class$.ref.path.startsWith('Deleted'))
                        ElevatedButton.icon(
                          icon: const Icon(Icons.map),
                          onPressed: () => showMap(context, class$),
                          label: const Text('إظهار المخدومين على الخريطة'),
                        ),
                      if (User.instance.manageUsers ||
                          User.instance.manageAllowedUsers)
                        ElevatedButton.icon(
                          icon: const Icon(Icons.analytics_outlined),
                          onPressed: () => Navigator.pushNamed(
                            context,
                            'ActivityAnalysis',
                            arguments: [class$],
                          ),
                          label: const Text('تحليل نشاط الخدام'),
                        ),
                      if (!class$.ref.path.startsWith('Deleted'))
                        ElevatedButton.icon(
                          icon: DescribedFeatureOverlay(
                            featureId: 'Class.Analytics',
                            tapTarget: const Icon(Icons.analytics_outlined),
                            title: const Text('عرض تحليل لبيانات سجلات الحضور'),
                            description: Column(
                              children: <Widget>[
                                const Text(
                                    'الأن يمكنك عرض تحليل لبيانات حضور مخدومين الفصل خلال فترة معينة من هنا'),
                                OutlinedButton.icon(
                                  icon: const Icon(Icons.forward),
                                  label: Text(
                                    'التالي',
                                    style: TextStyle(
                                      color: Theme.of(context)
                                          .textTheme
                                          .bodyText2!
                                          .color,
                                    ),
                                  ),
                                  onPressed: () {
                                    FeatureDiscovery.completeCurrentStep(
                                        context);
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
                                          .bodyText2!
                                          .color,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            backgroundColor: Theme.of(context).accentColor,
                            targetColor: Colors.transparent,
                            textColor: Theme.of(context)
                                .primaryTextTheme
                                .bodyText1!
                                .color!,
                            child: const Icon(Icons.analytics_outlined),
                          ),
                          label: const Text('احصائيات الحضور'),
                          onPressed: () => _showAnalytics(context, class$),
                        ),
                      const Divider(thickness: 1),
                      EditHistoryProperty(
                        'أخر تحديث للبيانات:',
                        class$.lastEdit,
                        class$.ref.collection('EditHistory'),
                        discoverFeature: true,
                      ),
                      Text(
                        'المخدومين بالفصل:',
                        style: Theme.of(context).textTheme.headline6,
                      ),
                      SearchFilters(
                        1,
                        options: _listOptions,
                        orderOptions: _orderOptions,
                        textStyle: Theme.of(context).textTheme.bodyText2,
                      ),
                    ],
                  ),
                ),
              ],
              body: SafeArea(
                child: class$.ref.path.startsWith('Deleted')
                    ? const Text('يجب استعادة الفصل لرؤية المخدومين بداخله')
                    : DataObjectList<Person>(
                        options: _listOptions, disposeController: true),
              ),
            ),
            bottomNavigationBar: BottomAppBar(
              color: Theme.of(context).primaryColor,
              shape: const CircularNotchedRectangle(),
              child: StreamBuilder<List>(
                stream: _listOptions.objectsData,
                builder: (context, snapshot) {
                  return Text(
                    (snapshot.data?.length ?? 0).toString() + ' مخدوم',
                    textAlign: TextAlign.center,
                    strutStyle:
                        StrutStyle(height: IconTheme.of(context).size! / 7.5),
                    style: Theme.of(context).primaryTextTheme.bodyText1,
                  );
                },
              ),
            ),
            floatingActionButtonLocation:
                FloatingActionButtonLocation.endDocked,
            floatingActionButton: permission! &&
                    !class$.ref.path.startsWith('Deleted')
                ? FloatingActionButton(
                    onPressed: () => addTap(context),
                    child: DescribedFeatureOverlay(
                      onBackgroundTap: () async {
                        await FeatureDiscovery.completeCurrentStep(context);
                        return true;
                      },
                      onDismiss: () async {
                        await FeatureDiscovery.completeCurrentStep(context);
                        return true;
                      },
                      backgroundDismissible: true,
                      contentLocation: ContentLocation.above,
                      featureId: 'Add',
                      tapTarget: const Icon(Icons.person_add),
                      title: const Text('اضافة مخدوم داخل الفصل'),
                      description: Column(
                        children: [
                          const Text(
                              'يمكنك اضافة مخدوم داخل الفصل بسرعة وسهولة من هنا'),
                          OutlinedButton(
                            onPressed: () =>
                                FeatureDiscovery.completeCurrentStep(context),
                            child: Text(
                              'تخطي',
                              style: TextStyle(
                                color: Theme.of(context)
                                    .textTheme
                                    .bodyText2!
                                    .color,
                              ),
                            ),
                          ),
                        ],
                      ),
                      backgroundColor: Theme.of(context).accentColor,
                      targetColor: Theme.of(context).primaryColor,
                      textColor:
                          Theme.of(context).primaryTextTheme.bodyText1!.color!,
                      child: const Icon(Icons.person_add),
                    ),
                  )
                : null,
          );
        },
      ),
    );
  }

  void showMap(BuildContext context, Class class$) {
    navigator.currentState!
        .push(MaterialPageRoute(builder: (context) => DataMap(class$: class$)));
  }

  void _showAnalytics(BuildContext context, Class _class) {
    navigator.currentState!.pushNamed('Analytics', arguments: _class);
  }
}
