import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:meetinghelper/models/data/person.dart';
import 'package:meetinghelper/models/data/service.dart';
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
import '../../models/search/search_filters.dart';
import '../../utils/helpers.dart';
import '../data_map.dart';
import '../list.dart';

class ServiceInfo extends StatefulWidget {
  final Service service;

  const ServiceInfo({Key? key, required this.service}) : super(key: key);

  @override
  _ServiceInfoState createState() => _ServiceInfoState();
}

class _ServiceInfoState extends State<ServiceInfo> {
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
        (order) => widget.service.getPersonsMembersLive(
          orderBy: order.orderBy ?? 'Name',
          descending: !order.asc!,
        ),
      ),
    );
    WidgetsBinding.instance!.addPostFrameCallback((_) {
      if (([
        if (User.instance.write) 'Edit',
        'Share',
        'MoreOptions',
        'EditHistory',
        'Service.Analytics',
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
                      'تعديل بيانات الخدمة',
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
                    'يمكنك ايجاد المزيد من الخيارات من هنا مثل: اشعار المستخدمين عن الخدمة',
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
                    'الاطلاع على سجل التعديلات في بيانات الخدمة',
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
                    'الأن يمكنك عرض تحليل لبيانات حضور مخدومين في الخدمة خلال فترة معينة من هنا',
                    style: Theme.of(context).textTheme.subtitle1?.copyWith(
                        color: Theme.of(context).colorScheme.onSecondary),
                  ),
                ),
              ],
              identify: 'Service.Analytics',
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
                      'يمكنك اضافة مخدوم داخل الخدمة بسرعة وسهولة من هنا',
                      style: Theme.of(context).textTheme.subtitle1?.copyWith(
                          color: Theme.of(context).colorScheme.onSecondary),
                    ),
                  ),
                ],
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
      builder: (context, permission, _) => StreamBuilder<Service?>(
        initialData: widget.service,
        stream: widget.service.ref.snapshots().map(Service.fromDoc),
        builder: (context, data) {
          if (data.data == null)
            return const Scaffold(
              body: Center(
                child: Text('تم حذف الخدمة'),
              ),
            );

          final Service service = data.requireData!;

          return Scaffold(
            body: NestedScrollView(
              headerSliverBuilder: (context, _) => <Widget>[
                SliverAppBar(
                  backgroundColor: service.color != Colors.transparent
                      ? (Theme.of(context).brightness == Brightness.light
                          ? TinyColor(service.color).lighten().color
                          : TinyColor(service.color).darken().color)
                      : null,
                  actions: service.ref.path.startsWith('Deleted')
                      ? <Widget>[
                          if (permission!)
                            IconButton(
                              icon: const Icon(Icons.restore),
                              tooltip: 'استعادة',
                              onPressed: () {
                                recoverDoc(context, service.ref.path);
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
                                          .pushNamed('Data/EditService',
                                              arguments: service);
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
                              await Share.share(await shareService(service));
                            },
                            tooltip: 'مشاركة برابط',
                          ),
                          PopupMenuButton(
                            key: _moreOptions,
                            onSelected: (dynamic _) =>
                                sendNotification(context, service),
                            itemBuilder: (context) {
                              return [
                                const PopupMenuItem(
                                  value: '',
                                  child:
                                      Text('ارسال إشعار للمستخدمين عن الخدمة'),
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
                        child: Text(service.name,
                            style: const TextStyle(fontSize: 16.0)),
                      ),
                      background: service.photo(cropToCircle: false),
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
                            service.name,
                            style: Theme.of(context)
                                .textTheme
                                .headline5
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ),
                        if (service.studyYearRange != null)
                          ListTile(
                            title: const Text('السنوات الدراسية:'),
                            subtitle: FutureBuilder<String>(
                              future: () async {
                                if (service.studyYearRange?.from ==
                                    service.studyYearRange?.to)
                                  return (await service.studyYearRange!.from
                                              ?.get())
                                          ?.data()?['Name'] as String? ??
                                      'غير موجودة';

                                final from =
                                    (await service.studyYearRange!.from?.get())
                                            ?.data()?['Name'] ??
                                        'غير موجودة';
                                final to =
                                    (await service.studyYearRange!.to?.get())
                                            ?.data()?['Name'] ??
                                        'غير موجودة';

                                return 'من $from الى $to';
                              }(),
                              builder: (context, data) {
                                if (data.hasData) return Text(data.data!);
                                return const LinearProgressIndicator();
                              },
                            ),
                          ),
                        if (service.validity != null)
                          ListTile(
                            title: const Text('الصلاحية:'),
                            subtitle: Builder(
                              builder: (context) {
                                final from =
                                    DateFormat('yyyy/M/d', 'ar-EG').format(
                                  service.validity!.start,
                                );
                                final to =
                                    DateFormat('yyyy/M/d', 'ar-EG').format(
                                  service.validity!.end,
                                );

                                return Text('من $from الى $to');
                              },
                            ),
                          ),
                        ListTile(
                          title: const Text('اظهار البند في السجل'),
                          subtitle: Text(service.showInHistory ? 'نعم' : 'لا'),
                        ),
                        if (!service.ref.path.startsWith('Deleted'))
                          ElevatedButton.icon(
                            icon: const Icon(Icons.map),
                            onPressed: () => showMap(context, service),
                            label: const Text('إظهار المخدومين على الخريطة'),
                          ),
                        if (!service.ref.path.startsWith('Deleted') &&
                            (User.instance.manageUsers ||
                                User.instance.manageAllowedUsers))
                          ElevatedButton.icon(
                            icon: const Icon(Icons.analytics_outlined),
                            onPressed: () => Navigator.pushNamed(
                              context,
                              'ActivityAnalysis',
                              arguments: [service],
                            ),
                            label: const Text('تحليل نشاط الخدام'),
                          ),
                        if (!service.ref.path.startsWith('Deleted'))
                          ElevatedButton.icon(
                            key: _analytics,
                            icon: const Icon(Icons.analytics_outlined),
                            label: const Text('احصائيات الحضور'),
                            onPressed: () => _showAnalytics(context, service),
                          ),
                        const Divider(thickness: 1),
                        EditHistoryProperty(
                          'أخر تحديث للبيانات:',
                          service.lastEdit,
                          service.ref.collection('EditHistory'),
                          key: _editHistory,
                        ),
                        if (User.instance.manageUsers ||
                            User.instance.manageAllowedUsers)
                          _ServiceServants(service: service),
                        Text(
                          'المخدومين المشتركين بالخدمة:',
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
                child: service.ref.path.startsWith('Deleted')
                    ? const Text('يجب استعادة الخدمة لرؤية المخدومين بداخله')
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
                permission! && !service.ref.path.startsWith('Deleted')
                    ? FloatingActionButton(
                        key: _add,
                        onPressed: () => navigator.currentState!.pushNamed(
                            'Data/EditPerson',
                            arguments: widget.service.ref),
                        child: const Icon(Icons.person_add),
                      )
                    : null,
          );
        },
      ),
    );
  }

  void showMap(BuildContext context, Service service) {
    navigator.currentState!.push(
        MaterialPageRoute(builder: (context) => DataMap(service: service)));
  }

  void _showAnalytics(BuildContext context, Service _class) {
    navigator.currentState!.pushNamed('Analytics', arguments: _class);
  }
}

class _ServiceServants extends StatelessWidget {
  const _ServiceServants({
    Key? key,
    required this.service,
  }) : super(key: key);

  final Service service;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<User>>(
      stream: User.instance.stream
          .switchMap((u) => u.manageUsers
              ? FirebaseFirestore.instance
                  .collection('UsersData')
                  .where('AdminServices', arrayContains: service.ref)
                  .snapshots()
              : FirebaseFirestore.instance
                  .collection('UsersData')
                  .where('AllowedUsers', arrayContains: User.instance.ref)
                  .where('AdminServices', arrayContains: service.ref)
                  .snapshots())
          .map((s) => s.docs.map(User.fromDoc).toList()),
      builder: (context, usersSnashot) {
        if (!usersSnashot.hasData) return const LinearProgressIndicator();

        final users = usersSnashot.requireData;

        return ListTile(
          title: Text(
            'الخدام المسؤلين عن الخدمة',
            style: Theme.of(context).textTheme.headline6,
          ),
          subtitle: users.isNotEmpty
              ? GridView.builder(
                  padding: EdgeInsets.zero,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    mainAxisSpacing: 10,
                    childAspectRatio: 1,
                    crossAxisSpacing: 10,
                  ),
                  shrinkWrap: true,
                  itemCount: users.length > 7 ? 7 : users.length,
                  physics: const NeverScrollableScrollPhysics(),
                  itemBuilder: (context, i) {
                    if (users.length > 7 && i == 6) {
                      return SizedBox.expand(
                        child: ClipOval(
                          child: Container(
                            color:
                                Theme.of(context).brightness == Brightness.light
                                    ? Colors.black26
                                    : Colors.black54,
                            child: Center(
                              child: Text('+' + (users.length - 6).toString()),
                            ),
                          ),
                        ),
                      );
                    }
                    return IgnorePointer(
                      child: users[i].photo(removeHero: true),
                    );
                  },
                )
              : const Text('لا يوجد خدام محددين في هذه الخدمة'),
          onTap: users.isNotEmpty
              ? () async {
                  await showDialog(
                    context: context,
                    builder: (context) => Dialog(
                      child: ListView.builder(
                        padding: const EdgeInsetsDirectional.all(8),
                        shrinkWrap: true,
                        itemCount: users.length,
                        itemBuilder: (context, i) {
                          return Container(
                            margin: const EdgeInsets.symmetric(vertical: 5),
                            child: IgnorePointer(
                              child: DataObjectWidget(
                                users[i],
                                showSubTitle: false,
                                wrapInCard: false,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  );
                }
              : null,
        );
      },
    );
  }
}
