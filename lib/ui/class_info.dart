import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:feature_discovery/feature_discovery.dart';
import 'package:flutter/material.dart';
import 'package:icon_shadow/icon_shadow.dart';
import 'package:meetinghelper/models/models.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:tinycolor/tinycolor.dart';

import '../models/user.dart';
import '../models/history_property.dart';
import '../models/list_options.dart';
import '../models/order_options.dart';
import '../models/search_filters.dart';
import '../models/search_string.dart';
import '../utils/helpers.dart';
import 'data_map.dart';
import 'list.dart';

class ClassInfo extends StatelessWidget {
  final Class class$;
  const ClassInfo({Key key, this.class$}) : super(key: key);

  void addTap(BuildContext context) {
    Navigator.of(context).pushNamed('Data/EditPerson', arguments: class$.ref);
  }

  @override
  Widget build(BuildContext context) {
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
    return Selector<User, bool>(
      selector: (_, user) => user.write,
      builder: (context, permission, _) => StreamBuilder<Class>(
        initialData: class$,
        stream: class$.ref.snapshots().map(Class.fromDoc),
        builder: (context, data) {
          Class _class = data.data;
          if (_class == null)
            return Scaffold(
              body: Center(
                child: Text('تم حذف الفصل'),
              ),
            );
          return Scaffold(
            body: ListenableProvider<SearchString>(
              create: (_) => SearchString(''),
              builder: (context, child) => NestedScrollView(
                headerSliverBuilder: (context, _) => <Widget>[
                  SliverAppBar(
                    backgroundColor: _class.color != Colors.transparent
                        ? (Theme.of(context).brightness == Brightness.light
                            ? TinyColor(_class.color).lighten().color
                            : TinyColor(_class.color).darken().color)
                        : null,
                    actions: <Widget>[
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
                                        child: Text(
                                          'تخطي',
                                          style: TextStyle(
                                            color: Theme.of(context)
                                                .textTheme
                                                .bodyText2
                                                .color,
                                          ),
                                        ),
                                        onPressed: () =>
                                            FeatureDiscovery.dismissAll(
                                                context),
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
                                    builder: (context) => IconShadowWidget(
                                      Icon(
                                        Icons.edit,
                                        color: IconTheme.of(context).color,
                                      ),
                                    ),
                                  ),
                                ),
                                onPressed: () async {
                                  dynamic result = await Navigator.of(context)
                                      .pushNamed('Data/EditClass',
                                          arguments: _class);
                                  if (result is DocumentReference) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('تم الحفظ بنجاح'),
                                      ),
                                    );
                                  } else if (result == 'deleted')
                                    Navigator.of(context).pop();
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
                                child: Text(
                                  'تخطي',
                                  style: TextStyle(
                                    color: Theme.of(context)
                                        .textTheme
                                        .bodyText2
                                        .color,
                                  ),
                                ),
                                onPressed: () =>
                                    FeatureDiscovery.dismissAll(context),
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
                            builder: (context) => IconShadowWidget(
                              Icon(
                                Icons.share,
                                color: IconTheme.of(context).color,
                              ),
                            ),
                          ),
                        ),
                        onPressed: () async {
                          // Navigator.of(context).pop();
                          await Share.share(await shareClass(_class));
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
                                  FeatureDiscovery.completeCurrentStep(context),
                            ),
                            OutlinedButton(
                              child: Text(
                                'تخطي',
                                style: TextStyle(
                                  color: Theme.of(context)
                                      .textTheme
                                      .bodyText2
                                      .color,
                                ),
                              ),
                              onPressed: () =>
                                  FeatureDiscovery.dismissAll(context),
                            ),
                          ],
                        ),
                        backgroundColor: Theme.of(context).accentColor,
                        targetColor: Colors.transparent,
                        textColor:
                            Theme.of(context).primaryTextTheme.bodyText1.color,
                        child: PopupMenuButton(
                          onSelected: (_) => sendNotification(context, _class),
                          itemBuilder: (context) {
                            return [
                              PopupMenuItem(
                                value: '',
                                child: Text('ارسال إشعار للمستخدمين عن الفصل'),
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
                          child: Text(_class.name,
                              style: TextStyle(fontSize: 16.0)),
                        ),
                        background: _class.photo(),
                      ),
                    ),
                  ),
                  SliverList(
                    delegate: SliverChildListDelegate(
                      <Widget>[
                        ListTile(
                          title: Text(_class.name,
                              style: Theme.of(context).textTheme.headline6),
                        ),
                        ListTile(
                          title: Text('السنة الدراسية:'),
                          subtitle: FutureBuilder(
                              future: _class.getStudyYearName(),
                              builder: (context, data) {
                                if (data.hasData)
                                  return Text(data.data +
                                      ' - ' +
                                      _class.getGenderName());
                                return LinearProgressIndicator();
                              }),
                        ),
                        ElevatedButton.icon(
                          icon: Icon(Icons.map),
                          onPressed: () => showMap(context, _class),
                          label: Text('إظهار المخدومين على الخريطة'),
                        ),
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
                                  child: Text(
                                    'تخطي',
                                    style: TextStyle(
                                      color: Theme.of(context)
                                          .textTheme
                                          .bodyText2
                                          .color,
                                    ),
                                  ),
                                  onPressed: () =>
                                      FeatureDiscovery.dismissAll(context),
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
                          onPressed: () => _showAnalytics(context, _class),
                        ),
                        Divider(thickness: 1),
                        EditHistoryProperty(
                          'أخر تحديث للبيانات:',
                          _class.lastEdit,
                          _class.ref.collection('EditHistory'),
                          discoverFeature: true,
                        ),
                        Text('الأشخاص بالفصل:'),
                        SearchFilters(
                          1,
                          textStyle: Theme.of(context).textTheme.bodyText2,
                        ),
                      ],
                    ),
                  ),
                ],
                body: SafeArea(
                  child: Consumer<OrderOptions>(
                    builder: (context, options, _) => DataObjectList<Person>(
                      options: ListOptions<Person>(
                          floatingActionButton: permission
                              ? FloatingActionButton(
                                  child: DescribedFeatureOverlay(
                                    onBackgroundTap: () async {
                                      await FeatureDiscovery
                                          .completeCurrentStep(context);
                                      return true;
                                    },
                                    onDismiss: () async {
                                      await FeatureDiscovery
                                          .completeCurrentStep(context);
                                      return true;
                                    },
                                    backgroundDismissible: true,
                                    contentLocation: ContentLocation.above,
                                    featureId: 'Add',
                                    tapTarget: Icon(Icons.person_add),
                                    title: Text('اضافة شخص داخل الفصل'),
                                    description: Column(
                                      children: [
                                        Text(
                                            'يمكنك اضافة شخص داخل الفصل بسرعة وسهولة من هنا'),
                                        OutlinedButton(
                                          child: Text(
                                            'تخطي',
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
                                      ],
                                    ),
                                    backgroundColor:
                                        Theme.of(context).accentColor,
                                    targetColor: Theme.of(context).primaryColor,
                                    textColor: Theme.of(context)
                                        .primaryTextTheme
                                        .bodyText1
                                        .color,
                                    child: Icon(Icons.person_add),
                                  ),
                                  onPressed: () => addTap(context))
                              : null,
                          tap: personTap,
                          generate: Person.fromDoc,
                          documentsData: _class.getMembersLive(
                              orderBy: options.personOrderBy,
                              descending: !options.personASC)),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void showMap(BuildContext context, Class class$) {
    Navigator.push(context,
        MaterialPageRoute(builder: (context) => DataMap(classO: class$)));
  }

  void _showAnalytics(BuildContext context, Class _class) {
    Navigator.pushNamed(context, 'Analytics', arguments: _class);
  }
}
