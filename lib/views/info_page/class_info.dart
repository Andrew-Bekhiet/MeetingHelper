import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:feature_discovery/feature_discovery.dart';
import 'package:flutter/material.dart';
import 'package:meetinghelper/models/models.dart';
import 'package:provider/provider.dart';
import 'package:rxdart/rxdart.dart';
import 'package:share_plus/share_plus.dart';
import 'package:tinycolor/tinycolor.dart';
import 'package:meetinghelper/utils/globals.dart';

import '../../models/user.dart';
import '../../models/history_property.dart';
import '../../models/list_options.dart';
import '../../models/order_options.dart';
import '../../models/search_filters.dart';
import '../../utils/helpers.dart';
import '../data_map.dart';
import '../list.dart';

class ClassInfo extends StatefulWidget {
  final Class class$;
  const ClassInfo({Key key, this.class$}) : super(key: key);

  @override
  _ClassInfoState createState() => _ClassInfoState();
}

class _ClassInfoState extends State<ClassInfo> {
  final BehaviorSubject<String> _searchStream =
      BehaviorSubject<String>.seeded('');

  final BehaviorSubject<OrderOptions> _orderOptions =
      BehaviorSubject<OrderOptions>.seeded(OrderOptions());

  void addTap(BuildContext context) {
    navigator.currentState
        .pushNamed('Data/EditPerson', arguments: widget.class$.ref);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
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
    final _listOptions = DataObjectListOptions<Person>(
      searchQuery: _searchStream,
      tap: (p) => personTap(p, context),
      itemsStream: _orderOptions.switchMap(
        (order) => widget.class$
            .getMembersLive(orderBy: order.orderBy, descending: !order.asc),
      ),
    );
    return Selector<User, bool>(
      selector: (_, user) => user.write,
      builder: (context, permission, _) => StreamBuilder<Class>(
        initialData: widget.class$,
        stream: widget.class$.ref.snapshots().map(Class.fromDoc),
        builder: (context, data) {
          Class class$ = data.data;
          if (class$ == null)
            return Scaffold(
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
                          if (permission)
                            IconButton(
                              icon: Icon(Icons.restore),
                              tooltip: 'استعادة',
                              onPressed: () {
                                recoverDoc(context, class$.ref.path);
                              },
                            )
                        ]
                      : <Widget>[
                          Selector<User, bool>(
                            selector: (_, user) => user.write,
                            builder: (c, permission, data) => permission
                                ? IconButton(
                                    icon: DescribedFeatureOverlay(
                                      barrierDismissible: false,
                                      contentLocation: ContentLocation.below,
                                      featureId: 'Edit',
                                      tapTarget: Icon(
                                        Icons.edit,
                                        color: IconTheme.of(context).color,
                                      ),
                                      title: Text('تعديل'),
                                      description: Column(
                                        children: <Widget>[
                                          Text('يمكنك تعديل البيانات من هنا'),
                                          OutlinedButton.icon(
                                            icon: Icon(Icons.forward),
                                            label: Text(
                                              'التالي',
                                              style: TextStyle(
                                                color: Theme.of(context)
                                                    .textTheme
                                                    .bodyText2
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
                                                    .bodyText2
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
                                          .bodyText1
                                          .color,
                                      child: Builder(
                                        builder: (context) => Stack(
                                          children: <Widget>[
                                            Positioned(
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
                                          .currentState
                                          .pushNamed('Data/EditClass',
                                              arguments: class$);
                                      if (result is DocumentReference) {
                                        scaffoldMessenger.currentState
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text('تم الحفظ بنجاح'),
                                          ),
                                        );
                                      } else if (result == 'deleted')
                                        navigator.currentState.pop();
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
                              tapTarget: Icon(
                                Icons.share,
                              ),
                              title: Text('مشاركة البيانات'),
                              description: Column(
                                children: <Widget>[
                                  Text(
                                      'يمكنك مشاركة البيانات بلينك يفتح البيانات مباشرة داخل البرنامج'),
                                  OutlinedButton.icon(
                                    icon: Icon(Icons.forward),
                                    label: Text(
                                      'التالي',
                                      style: TextStyle(
                                        color: Theme.of(context)
                                            .textTheme
                                            .bodyText2
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
                                            .bodyText2
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
                                  .bodyText1
                                  .color,
                              child: Builder(
                                builder: (context) => Stack(
                                  children: <Widget>[
                                    Positioned(
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
                            tapTarget: Icon(
                              Icons.more_vert,
                            ),
                            title: Text('المزيد من الخيارات'),
                            description: Column(
                              children: <Widget>[
                                Text(
                                    'يمكنك ايجاد المزيد من الخيارات من هنا مثل: اشعار المستخدمين عن الفصل'),
                                OutlinedButton.icon(
                                  icon: Icon(Icons.forward),
                                  label: Text(
                                    'التالي',
                                    style: TextStyle(
                                      color: Theme.of(context)
                                          .textTheme
                                          .bodyText2
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
                                          .bodyText2
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
                                .bodyText1
                                .color,
                            child: PopupMenuButton(
                              onSelected: (_) =>
                                  sendNotification(context, class$),
                              itemBuilder: (context) {
                                return [
                                  PopupMenuItem(
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
                        duration: Duration(milliseconds: 300),
                        opacity:
                            constraints.biggest.height > kToolbarHeight * 1.7
                                ? 0
                                : 1,
                        child:
                            Text(class$.name, style: TextStyle(fontSize: 16.0)),
                      ),
                      background: class$.photo(),
                    ),
                  ),
                ),
                SliverList(
                  delegate: SliverChildListDelegate(
                    <Widget>[
                      ListTile(
                        title: Text(class$.name,
                            style: Theme.of(context).textTheme.headline6),
                      ),
                      ListTile(
                        title: Text('السنة الدراسية:'),
                        subtitle: FutureBuilder(
                            future: class$.getStudyYearName(),
                            builder: (context, data) {
                              if (data.hasData)
                                return Text(
                                    data.data + ' - ' + class$.getGenderName());
                              return LinearProgressIndicator();
                            }),
                      ),
                      if (!class$.ref.path.startsWith('Deleted'))
                        ElevatedButton.icon(
                          icon: Icon(Icons.map),
                          onPressed: () => showMap(context, class$),
                          label: Text('إظهار المخدومين على الخريطة'),
                        ),
                      if (User.instance.manageUsers ||
                          User.instance.manageAllowedUsers)
                        ElevatedButton.icon(
                          icon: Icon(Icons.analytics_outlined),
                          onPressed: () => Navigator.pushNamed(
                            context,
                            'ActivityAnalysis',
                            arguments: [class$],
                          ),
                          label: Text('تحليل نشاط الخدام'),
                        ),
                      if (!class$.ref.path.startsWith('Deleted'))
                        ElevatedButton.icon(
                          icon: DescribedFeatureOverlay(
                            featureId: 'Class.Analytics',
                            tapTarget: const Icon(Icons.analytics_outlined),
                            title: Text('عرض تحليل لبيانات سجلات الحضور'),
                            description: Column(
                              children: <Widget>[
                                Text(
                                    'الأن يمكنك عرض تحليل لبيانات حضور مخدومين الفصل خلال فترة معينة من هنا'),
                                OutlinedButton.icon(
                                  icon: Icon(Icons.forward),
                                  label: Text(
                                    'التالي',
                                    style: TextStyle(
                                      color: Theme.of(context)
                                          .textTheme
                                          .bodyText2
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
                                          .bodyText2
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
                                .bodyText1
                                .color,
                            child: const Icon(Icons.analytics_outlined),
                          ),
                          label: Text('احصائيات الحضور'),
                          onPressed: () => _showAnalytics(context, class$),
                        ),
                      Divider(thickness: 1),
                      EditHistoryProperty(
                        'أخر تحديث للبيانات:',
                        class$.lastEdit,
                        class$.ref.collection('EditHistory'),
                        discoverFeature: true,
                      ),
                      Text('المخدومين بالفصل:'),
                      SearchFilters(
                        1,
                        searchStream: _searchStream,
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
                    ? Text('يجب استعادة الفصل لرؤية المخدومين بداخله')
                    : DataObjectList<Person>(options: _listOptions),
              ),
            ),
            bottomNavigationBar: BottomAppBar(
              color: Theme.of(context).primaryColor,
              shape: const CircularNotchedRectangle(),
              child: StreamBuilder(
                stream: _listOptions.objectsData,
                builder: (context, snapshot) {
                  return Text(
                    (snapshot.data?.length ?? 0).toString() + ' مخدوم',
                    textAlign: TextAlign.center,
                    strutStyle:
                        StrutStyle(height: IconTheme.of(context).size / 7.5),
                    style: Theme.of(context).primaryTextTheme.bodyText1,
                  );
                },
              ),
            ),
            floatingActionButtonLocation:
                FloatingActionButtonLocation.endDocked,
            floatingActionButton: permission &&
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
                      tapTarget: Icon(Icons.person_add),
                      title: Text('اضافة مخدوم داخل الفصل'),
                      description: Column(
                        children: [
                          Text(
                              'يمكنك اضافة مخدوم داخل الفصل بسرعة وسهولة من هنا'),
                          OutlinedButton(
                            onPressed: () =>
                                FeatureDiscovery.completeCurrentStep(context),
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
                      child: Icon(Icons.person_add),
                    ),
                  )
                : null,
          );
        },
      ),
    );
  }

  void showMap(BuildContext context, Class class$) {
    navigator.currentState
        .push(MaterialPageRoute(builder: (context) => DataMap(classO: class$)));
  }

  void _showAnalytics(BuildContext context, Class _class) {
    navigator.currentState.pushNamed('Analytics', arguments: _class);
  }
}
