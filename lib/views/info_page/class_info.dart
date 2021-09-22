import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:meetinghelper/models/data/class.dart';
import 'package:meetinghelper/models/data/person.dart';
import 'package:meetinghelper/models/data_object_widget.dart';
import 'package:meetinghelper/models/hive_persistence_provider.dart';
import 'package:meetinghelper/utils/globals.dart';
import 'package:meetinghelper/utils/typedefs.dart';
import 'package:provider/provider.dart';
import 'package:rxdart/rxdart.dart';
import 'package:share_plus/share_plus.dart';
import 'package:tinycolor2/tinycolor2.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

import '../../models/data/user.dart';
import '../../models/history/history_property.dart';
import '../../models/list_controllers.dart';
import '../../models/search/order_options.dart';
import '../../models/search/search_filters.dart';
import '../../utils/helpers.dart';
import '../data_map.dart';
import '../list.dart';

class ClassInfo extends StatefulWidget {
  final Class class$;

  const ClassInfo({Key? key, required this.class$}) : super(key: key);

  @override
  _ClassInfoState createState() => _ClassInfoState();
}

class _ClassInfoState extends State<ClassInfo> {
  final BehaviorSubject<OrderOptions> _orderOptions =
      BehaviorSubject<OrderOptions>.seeded(const OrderOptions());

  late final DataObjectListController<Person> _listOptions;

  final _edit = GlobalKey();
  final _share = GlobalKey();
  final _moreOptions = GlobalKey();
  final _editHistory = GlobalKey();
  final _analytics = GlobalKey();
  final _add = GlobalKey();

  @override
  Future<void> dispose() async {
    super.dispose();
    await _orderOptions.close();
  }

  @override
  void initState() {
    super.initState();
    _listOptions = DataObjectListController<Person>(
      tap: personTap,
      itemsStream: _orderOptions.switchMap(
        (order) => widget.class$.getMembersLive(
            orderBy: order.orderBy ?? 'Name', descending: !order.asc!),
      ),
    );
    WidgetsBinding.instance!.addPostFrameCallback((_) {
      if (([
        if (User.instance.write) 'Edit',
        'Share',
        'MoreOptions',
        'EditHistory',
        'Class.Analytics',
        if (User.instance.write) 'Add'
      ]..removeWhere(HivePersistenceProvider.instance.hasCompletedStep))
          .isNotEmpty)
        TutorialCoachMark(
          context,
          focusAnimationDuration: const Duration(milliseconds: 200),
          targets: [
            if (User.instance.write)
              TargetFocus(
                enableOverlayTab: true,
                contents: [
                  TargetContent(
                    child: Text(
                      'تعديل بيانات الفصل',
                      style: Theme.of(context).textTheme.subtitle1?.copyWith(
                          color: Theme.of(context).colorScheme.onSecondary),
                    ),
                  ),
                ],
                identify: 'Edit',
                keyTarget: _edit,
                color: Theme.of(context).colorScheme.secondary,
              ),
            TargetFocus(
              enableOverlayTab: true,
              contents: [
                TargetContent(
                  child: Text(
                    'يمكنك مشاركة البيانات بلينك يفتح البيانات مباشرة داخل البرنامج',
                    style: Theme.of(context).textTheme.subtitle1?.copyWith(
                        color: Theme.of(context).colorScheme.onSecondary),
                  ),
                ),
              ],
              identify: 'Share',
              keyTarget: _share,
              color: Theme.of(context).colorScheme.secondary,
            ),
            TargetFocus(
              enableOverlayTab: true,
              contents: [
                TargetContent(
                  child: Text(
                    'يمكنك ايجاد المزيد من الخيارات من هنا مثل: اشعار المستخدمين عن الفصل',
                    style: Theme.of(context).textTheme.subtitle1?.copyWith(
                        color: Theme.of(context).colorScheme.onSecondary),
                  ),
                ),
              ],
              identify: 'MoreOptions',
              keyTarget: _moreOptions,
              color: Theme.of(context).colorScheme.secondary,
            ),
            TargetFocus(
              shape: ShapeLightFocus.RRect,
              enableOverlayTab: true,
              contents: [
                TargetContent(
                  align: ContentAlign.top,
                  child: Text(
                    'الاطلاع على سجل التعديلات في بيانات الفصل',
                    style: Theme.of(context).textTheme.subtitle1?.copyWith(
                        color: Theme.of(context).colorScheme.onSecondary),
                  ),
                ),
              ],
              identify: 'EditHistory',
              keyTarget: _editHistory,
              color: Theme.of(context).colorScheme.secondary,
            ),
            TargetFocus(
              shape: ShapeLightFocus.RRect,
              enableOverlayTab: true,
              contents: [
                TargetContent(
                  align: ContentAlign.top,
                  child: Text(
                    'الأن يمكنك عرض تحليل لبيانات حضور مخدومين الفصل خلال فترة معينة من هنا',
                    style: Theme.of(context).textTheme.subtitle1?.copyWith(
                        color: Theme.of(context).colorScheme.onSecondary),
                  ),
                ),
              ],
              identify: 'Class.Analytics',
              keyTarget: _analytics,
              color: Theme.of(context).colorScheme.secondary,
            ),
            if (User.instance.write)
              TargetFocus(
                enableOverlayTab: true,
                contents: [
                  TargetContent(
                    align: ContentAlign.top,
                    child: Text(
                      'يمكنك اضافة مخدوم داخل الفصل بسرعة وسهولة من هنا',
                      style: Theme.of(context).textTheme.subtitle1?.copyWith(
                          color: Theme.of(context).colorScheme.onSecondary),
                    ),
                  ),
                ],
                alignSkip: Alignment.topRight,
                identify: 'Add',
                keyTarget: _add,
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
  Widget build(BuildContext context) {
    return Selector<User, bool?>(
      selector: (_, user) => user.write,
      builder: (context, permission, _) => StreamBuilder<Class?>(
        initialData: widget.class$,
        stream: widget.class$.ref.snapshots().map(Class.fromDoc),
        builder: (context, data) {
          final Class? class$ = data.data;
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
                                    key: _edit,
                                    icon: Builder(
                                      builder: (context) => Stack(
                                        children: <Widget>[
                                          const Positioned(
                                            left: 1.0,
                                            top: 2.0,
                                            child: Icon(Icons.edit,
                                                color: Colors.black54),
                                          ),
                                          Icon(Icons.edit,
                                              color:
                                                  IconTheme.of(context).color),
                                        ],
                                      ),
                                    ),
                                    onPressed: () async {
                                      final dynamic result = await navigator
                                          .currentState!
                                          .pushNamed('Data/EditClass',
                                              arguments: class$);
                                      if (result is JsonRef) {
                                        scaffoldMessenger.currentState!
                                            .showSnackBar(
                                          const SnackBar(
                                            content: Text('تم الحفظ بنجاح'),
                                          ),
                                        );
                                      } else if (result == 'deleted') {
                                        scaffoldMessenger.currentState!
                                            .hideCurrentSnackBar();
                                        scaffoldMessenger.currentState!
                                            .showSnackBar(
                                          const SnackBar(
                                            content: Text('تم الحذف بنجاح'),
                                            duration: Duration(seconds: 2),
                                          ),
                                        );
                                        navigator.currentState!.pop();
                                      }
                                    },
                                    tooltip: 'تعديل',
                                  )
                                : Container(),
                          ),
                          IconButton(
                            key: _share,
                            icon: Builder(
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
                            onPressed: () async {
                              // navigator.currentState.pop();
                              await Share.share(await shareClass(class$));
                            },
                            tooltip: 'مشاركة برابط',
                          ),
                          PopupMenuButton(
                            key: _moreOptions,
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
                      background: class$.photo(cropToCircle: false),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate(
                      [
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
                        if (!class$.ref.path.startsWith('Deleted') &&
                            (User.instance.manageUsers ||
                                User.instance.manageAllowedUsers))
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
                            key: _analytics,
                            icon: const Icon(Icons.analytics_outlined),
                            label: const Text('احصائيات الحضور'),
                            onPressed: () => _showAnalytics(context, class$),
                          ),
                        const Divider(thickness: 1),
                        EditHistoryProperty(
                          'أخر تحديث للبيانات:',
                          class$.lastEdit,
                          class$.ref.collection('EditHistory'),
                          key: _editHistory,
                        ),
                        _ClassServants(class$: class$),
                        Text(
                          'المخدومين بالفصل:',
                          style: Theme.of(context).textTheme.headline6,
                        ),
                        SearchFilters(
                          Person,
                          options: _listOptions,
                          orderOptions: _orderOptions,
                          textStyle: Theme.of(context).textTheme.bodyText2,
                        ),
                      ],
                    ),
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
              color: Theme.of(context).colorScheme.primary,
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
            floatingActionButton:
                permission! && !class$.ref.path.startsWith('Deleted')
                    ? FloatingActionButton(
                        key: _add,
                        onPressed: () => navigator.currentState!.pushNamed(
                            'Data/EditPerson',
                            arguments: widget.class$.ref),
                        child: const Icon(Icons.person_add),
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

class _ClassServants extends StatelessWidget {
  const _ClassServants({
    Key? key,
    required this.class$,
  }) : super(key: key);

  final Class class$;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(
        'خدام الفصل',
        style: Theme.of(context).textTheme.headline6,
      ),
      subtitle: class$.allowedUsers.isNotEmpty
          ? GridView.builder(
              padding: EdgeInsets.zero,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisSpacing: 10,
                childAspectRatio: 1,
                crossAxisSpacing: 10,
              ),
              shrinkWrap: true,
              itemCount: class$.allowedUsers.length > 7
                  ? 7
                  : class$.allowedUsers.length,
              physics: const NeverScrollableScrollPhysics(),
              itemBuilder: (context, i) {
                if (class$.allowedUsers.length > 7 && i == 6) {
                  return SizedBox.expand(
                    child: ClipOval(
                      child: Container(
                        color: Theme.of(context).brightness == Brightness.light
                            ? Colors.black26
                            : Colors.black54,
                        child: Center(
                          child: Text('+' +
                              (class$.allowedUsers.length - 6).toString()),
                        ),
                      ),
                    ),
                  );
                }
                return IgnorePointer(
                  child: User.photoFromUID(class$.allowedUsers[i],
                      removeHero: true),
                );
              },
            )
          : const Text('لا يوجد خدام محددين في هذا الفصل'),
      onTap: class$.allowedUsers.isNotEmpty
          ? () async {
              await showDialog(
                context: context,
                builder: (context) => Dialog(
                  child: FutureBuilder<List<User>>(
                    future: Future.wait(class$.allowedUsers.map(User.fromID)),
                    builder: (context, data) {
                      if (data.hasError) return ErrorWidget(data.error!);
                      if (!data.hasData)
                        return const Center(
                          child: CircularProgressIndicator(),
                        );

                      return ListView.builder(
                        padding: const EdgeInsetsDirectional.all(8),
                        shrinkWrap: true,
                        itemCount: class$.allowedUsers.length,
                        itemBuilder: (context, i) {
                          return Container(
                            margin: const EdgeInsets.symmetric(vertical: 5),
                            child: IgnorePointer(
                              child: DataObjectWidget(
                                data.requireData[i],
                                showSubTitle: false,
                                wrapInCard: false,
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              );
            }
          : null,
    );
  }
}
