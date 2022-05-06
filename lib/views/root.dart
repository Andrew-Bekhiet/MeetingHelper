import 'dart:async';
import 'dart:io';

import 'package:churchdata_core/churchdata_core.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_dynamic_links/firebase_dynamic_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart' hide Notification;
import 'package:get_it/get_it.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:meetinghelper/controllers.dart';
import 'package:meetinghelper/models.dart';
import 'package:meetinghelper/repositories.dart';
import 'package:meetinghelper/services.dart';
import 'package:meetinghelper/utils/globals.dart';
import 'package:meetinghelper/utils/helpers.dart';
import 'package:meetinghelper/views.dart';
import 'package:meetinghelper/widgets.dart';
import 'package:open_file/open_file.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:rxdart/rxdart.dart' hide Notification;
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

class Root extends StatefulWidget {
  const Root({Key? key}) : super(key: key);

  @override
  _RootState createState() => _RootState();
}

class _RootState extends State<Root>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final StreamSubscription<PendingDynamicLinkData>
      _dynamicLinksSubscription;

  TabController? _tabController;
  Timer? _keepAliveTimer;
  bool _timeout = false;
  bool _pushed = false;
  bool dialogsNotShown = true;

  final BehaviorSubject<bool> _showSearch = BehaviorSubject<bool>.seeded(false);
  final FocusNode _searchFocus = FocusNode();

  final Map<String, GlobalKey> _features = {};

  final BehaviorSubject<OrderOptions> _personsOrder =
      BehaviorSubject.seeded(const OrderOptions());

  final BehaviorSubject<String> _searchQuery =
      BehaviorSubject<String>.seeded('');

  Future<void> addTap() async {
    if (_tabController!.index == _tabController!.length - 2) {
      if (User.instance.permissions.manageUsers ||
          User.instance.permissions.manageAllowedUsers) {
        final rslt = await showDialog(
          context: context,
          builder: (context) => SimpleDialog(
            children: [
              SimpleDialogOption(
                child: const Text('اضافة فصل'),
                onPressed: () => navigator.currentState!.pop(true),
              ),
              SimpleDialogOption(
                child: const Text('اضافة خدمة'),
                onPressed: () => navigator.currentState!.pop(false),
              ),
            ],
          ),
        );
        if (rslt == true) {
          unawaited(navigator.currentState!.pushNamed('Data/EditClass'));
        } else if (rslt == false) {
          unawaited(navigator.currentState!.pushNamed('Data/EditService'));
        }
      } else {
        unawaited(navigator.currentState!.pushNamed('Data/EditClass'));
      }
    } else if (_tabController!.index == _tabController!.length - 1) {
      unawaited(navigator.currentState!.pushNamed('Data/EditPerson'));
    } else {
      unawaited(navigator.currentState!.push(
        MaterialPageRoute(
          builder: (context) {
            return EditPerson(
              person: Person(
                ref:
                    GetIt.I<DatabaseRepository>().collection('UsersData').doc(),
              ),
            );
          },
        ),
      ));
    }
  }

  late final ServicesListController _servicesOptions;
  late final ListController<void, Person> _personsOptions;
  late final ListController<Class?, UserWithPerson> _usersOptions;

  GlobalKey _createOrGetFeatureKey(String key) {
    _features[key] ??= GlobalKey();
    return _features[key]!;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: mainScfld,
      appBar: AppBar(
        actions: <Widget>[
          StreamBuilder<bool>(
            initialData: false,
            stream: _showSearch,
            builder: (context, data) => data.data!
                ? AnimatedBuilder(
                    animation: _tabController!,
                    builder: (context, child) =>
                        _tabController!.index == 1 ? child! : Container(),
                    child: IconButton(
                      icon: const Icon(Icons.filter_list),
                      onPressed: () async {
                        await showDialog(
                          context: context,
                          builder: (context) => SimpleDialog(
                            children: [
                              TextButton.icon(
                                icon: const Icon(Icons.select_all),
                                label: const Text('تحديد الكل'),
                                onPressed: () {
                                  _personsOptions.selectAll();
                                  navigator.currentState!.pop();
                                },
                              ),
                              TextButton.icon(
                                icon: const Icon(Icons.select_all),
                                label: const Text('تحديد لا شئ'),
                                onPressed: () {
                                  _personsOptions.deselectAll();
                                  navigator.currentState!.pop();
                                },
                              ),
                              const Text('ترتيب حسب:',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold)),
                              ...Person.propsMetadata()
                                  .entries
                                  .map(
                                    (e) => RadioListTile<String>(
                                      value: e.key,
                                      groupValue: _personsOrder.value.orderBy,
                                      title: Text(e.value.label),
                                      onChanged: (value) {
                                        _personsOrder.add(
                                          OrderOptions(
                                            orderBy: value!,
                                            asc: _personsOrder.value.asc,
                                          ),
                                        );
                                        navigator.currentState!.pop();
                                      },
                                    ),
                                  )
                                  .toList(),
                              RadioListTile(
                                value: true,
                                groupValue: _personsOrder.value.asc,
                                title: const Text('تصاعدي'),
                                onChanged: (dynamic value) {
                                  _personsOrder.add(
                                    OrderOptions(
                                        orderBy: _personsOrder.value.orderBy,
                                        asc: value),
                                  );
                                  navigator.currentState!.pop();
                                },
                              ),
                              RadioListTile(
                                value: false,
                                groupValue: _personsOrder.value.asc,
                                title: const Text('تنازلي'),
                                onChanged: (dynamic value) {
                                  _personsOrder.add(
                                    OrderOptions(
                                        orderBy: _personsOrder.value.orderBy,
                                        asc: value),
                                  );
                                  navigator.currentState!.pop();
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  )
                : IconButton(
                    key: _createOrGetFeatureKey('Search'),
                    icon: const Icon(Icons.search),
                    onPressed: () {
                      _searchFocus.requestFocus();
                      _showSearch.add(true);
                    },
                  ),
          ),
          IconButton(
            icon: const Icon(Icons.notifications),
            tooltip: 'الإشعارات',
            onPressed: () {
              navigator.currentState!.pushNamed('Notifications');
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            if (User.instance.permissions.manageUsers ||
                User.instance.permissions.manageAllowedUsers)
              Tab(
                key: _createOrGetFeatureKey('Servants'),
                text: 'الخدام',
                icon: const Icon(Icons.person),
              ),
            Tab(
              key: _createOrGetFeatureKey('Services'),
              text: 'الخدمات',
              icon: const Icon(Icons.miscellaneous_services),
            ),
            Tab(
              key: _createOrGetFeatureKey('Persons'),
              text: 'المخدومين',
              icon: const Icon(Icons.person),
            ),
          ],
        ),
        title: StreamBuilder<bool>(
          initialData: _showSearch.value,
          stream: _showSearch,
          builder: (context, data) => data.data!
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
                        onPressed: () {
                          _searchQuery.add('');
                          _showSearch.add(false);
                        },
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
              : const Text('البيانات'),
        ),
      ),
      extendBody: true,
      floatingActionButtonLocation: FloatingActionButtonLocation.endDocked,
      floatingActionButton: StreamBuilder<bool>(
        stream: User.loggedInStream.map((u) => u.permissions.write).distinct(),
        builder: (context, userData) {
          if (userData.data ?? false) {
            return FloatingActionButton(
              onPressed: addTap,
              child: AnimatedBuilder(
                animation: _tabController!,
                builder: (context, _) => Icon(
                    _tabController!.index == _tabController!.length - 2
                        ? Icons.group_add
                        : Icons.person_add),
              ),
            );
          }

          return const SizedBox(width: 0, height: 0);
        },
      ),
      bottomNavigationBar: BottomAppBar(
        color: Theme.of(context).colorScheme.primary,
        shape: const CircularNotchedRectangle(),
        child: AnimatedBuilder(
          animation: _tabController!,
          builder: (context, _) => StreamBuilder<dynamic>(
            stream: _tabController!.index == _tabController!.length - 1
                ? _personsOptions.objectsStream
                : _tabController!.index == _tabController!.length - 2
                    ? _servicesOptions.objectsStream
                    : _usersOptions.objectsStream,
            builder: (context, snapshot) {
              return Text(
                (snapshot.data?.length ?? 0).toString() +
                    ' ' +
                    (_tabController!.index == _tabController!.length - 1
                        ? 'مخدوم'
                        : _tabController!.index == _tabController!.length - 2
                            ? 'خدمة'
                            : 'خادم'),
                textAlign: TextAlign.center,
                strutStyle:
                    StrutStyle(height: IconTheme.of(context).size! / 7.5),
                style: Theme.of(context).primaryTextTheme.bodyText1,
              );
            },
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          if (User.instance.permissions.manageUsers ||
              User.instance.permissions.manageAllowedUsers)
            DataObjectListView<Class?, UserWithPerson>(
              key: const PageStorageKey('mainUsersList'),
              autoDisposeController: false,
              controller: _usersOptions,
              onTap: GetIt.I<MHViewableObjectTapHandler>().personTap,
            ),
          ServicesList(
            key: const PageStorageKey('mainClassesList'),
            autoDisposeController: false,
            options: _servicesOptions,
          ),
          DataObjectListView<void, Person>(
            key: const PageStorageKey('mainPersonsList'),
            autoDisposeController: false,
            controller: _personsOptions,
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          children: <Widget>[
            DrawerHeader(
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('assets/Logo.png'),
                ),
                gradient: LinearGradient(
                  colors: [Colors.limeAccent, Colors.amber],
                  stops: [0, 1],
                ),
              ),
              child: Container(),
            ),
            ListTile(
              key: _createOrGetFeatureKey('MyAccount'),
              leading: StreamBuilder<User?>(
                stream: User.loggedInStream,
                initialData: User.instance,
                builder: (context, snapshot) {
                  return UserPhotoWidget(snapshot.data!);
                },
              ),
              title: const Text('حسابي'),
              onTap: () {
                mainScfld.currentState!.openEndDrawer();
                navigator.currentState!.pushNamed('MyAccount');
              },
            ),
            StreamBuilder<bool>(
              key: _createOrGetFeatureKey('ManageUsers'),
              initialData: false,
              stream: User.loggedInStream
                  .map((u) =>
                      u.permissions.manageUsers ||
                      u.permissions.manageAllowedUsers)
                  .distinct(),
              builder: (context, data) {
                if (!data.data!) {
                  return const SizedBox(
                    width: 0,
                    height: 0,
                  );
                }

                return ListTile(
                  leading: const Icon(Icons.admin_panel_settings),
                  onTap: () async {
                    mainScfld.currentState!.openEndDrawer();
                    if (await Connectivity().checkConnectivity() !=
                        ConnectivityResult.none) {
                      // ignore: unawaited_futures
                      navigator.currentState!.push(
                        MaterialPageRoute(
                          builder: (context) => AuthScreen(
                            onSuccess: () => navigator.currentState!
                                .pushReplacementNamed('ManageUsers'),
                          ),
                        ),
                      );
                    } else {
                      await showDialog(
                          context: context,
                          builder: (context) => const AlertDialog(
                              content: Text('لا يوجد اتصال انترنت')));
                    }
                  },
                  title: const Text('إدارة المستخدمين'),
                );
              },
            ),
            const Divider(),
            StreamBuilder<bool>(
              key: _createOrGetFeatureKey('AddHistory'),
              initialData: false,
              stream: User.loggedInStream
                  .map((u) => u.permissions.recordHistory)
                  .distinct(),
              builder: (context, data) => data.data!
                  ? ListTile(
                      leading: const Icon(Icons.add),
                      title: const Text('كشف حضور المخدومين'),
                      onTap: () {
                        mainScfld.currentState!.openEndDrawer();
                        navigator.currentState!.pushNamed('Day');
                      },
                    )
                  : Container(),
            ),
            StreamBuilder<bool>(
              key: _createOrGetFeatureKey('AddServantsHistory'),
              initialData: false,
              stream: User.loggedInStream
                  .map((u) => u.permissions.secretary)
                  .distinct(),
              builder: (context, data) => data.data!
                  ? ListTile(
                      leading: const Icon(Icons.add),
                      title: const Text('كشف حضور الخدام'),
                      onTap: () {
                        mainScfld.currentState!.openEndDrawer();
                        navigator.currentState!.pushNamed('ServantsDay');
                      },
                    )
                  : Container(),
            ),
            ListTile(
              key: _createOrGetFeatureKey('History'),
              leading: const Icon(Icons.history),
              title: const Text('السجل'),
              onTap: () {
                mainScfld.currentState!.openEndDrawer();
                navigator.currentState!.pushNamed('History');
              },
            ),
            StreamBuilder<bool>(
              key: _createOrGetFeatureKey('ServantsHistory'),
              initialData: false,
              stream: User.loggedInStream
                  .map((u) => u.permissions.secretary)
                  .distinct(),
              builder: (context, data) => data.data!
                  ? ListTile(
                      leading: const Icon(Icons.history),
                      title: const Text('سجل الخدام'),
                      onTap: () {
                        mainScfld.currentState!.openEndDrawer();
                        navigator.currentState!.pushNamed('ServantsHistory');
                      },
                    )
                  : Container(),
            ),
            const Divider(),
            ListTile(
              key: _createOrGetFeatureKey('Analytics'),
              leading: const Icon(Icons.analytics_outlined),
              title: const Text('تحليل سجل المخدومين'),
              onTap: () {
                mainScfld.currentState!.openEndDrawer();
                navigator.currentState!.pushNamed('Analytics',
                    arguments: {'HistoryCollection': 'History'});
              },
            ),
            if (User.instance.permissions.secretary)
              ListTile(
                leading: const Icon(Icons.analytics_outlined),
                title: const Text('تحليل بيانات سجل الخدام'),
                onTap: () {
                  mainScfld.currentState!.openEndDrawer();
                  navigator.currentState!.pushNamed('Analytics',
                      arguments: {'HistoryCollection': 'ServantsHistory'});
                },
              ),
            StreamBuilder<bool>(
              initialData: false,
              stream: User.loggedInStream
                  .map((u) =>
                      u.permissions.manageUsers ||
                      u.permissions.manageAllowedUsers)
                  .distinct(),
              key: _createOrGetFeatureKey('ActivityAnalysis'),
              builder: (context, user) => user.data!
                  ? ListTile(
                      leading: const Icon(Icons.analytics_outlined),
                      title: const Text('تحليل بيانات الخدمة'),
                      onTap: () {
                        mainScfld.currentState!.openEndDrawer();
                        navigator.currentState!.pushNamed('ActivityAnalysis');
                      },
                    )
                  : Container(),
            ),
            const Divider(),
            ListTile(
              key: _createOrGetFeatureKey('AdvancedSearch'),
              leading: const Icon(Icons.search),
              title: const Text('بحث مفصل'),
              onTap: () {
                mainScfld.currentState!.openEndDrawer();
                navigator.currentState!.pushNamed('Search');
              },
            ),
            StreamBuilder<bool>(
              key: _createOrGetFeatureKey('ManageDeleted'),
              initialData: false,
              stream: User.loggedInStream
                  .map((u) => u.permissions.manageDeleted)
                  .distinct(),
              builder: (context, data) {
                if (!data.data!) {
                  return const SizedBox(
                    width: 0,
                    height: 0,
                  );
                }

                return ListTile(
                  leading: const Icon(Icons.delete_outline),
                  onTap: () {
                    mainScfld.currentState!.openEndDrawer();
                    navigator.currentState!.pushNamed('Trash');
                  },
                  title: const Text('سلة المحذوفات'),
                );
              },
            ),
            ListTile(
              key: _createOrGetFeatureKey('DataMap'),
              leading: const Icon(Icons.map),
              title: const Text('عرض خريطة الافتقاد'),
              onTap: () {
                mainScfld.currentState!.openEndDrawer();
                navigator.currentState!.pushNamed('DataMap');
              },
            ),
            const Divider(),
            ListTile(
              key: _createOrGetFeatureKey('Settings'),
              leading: const Icon(Icons.settings),
              title: const Text('الإعدادات'),
              onTap: () {
                mainScfld.currentState!.openEndDrawer();
                navigator.currentState!.pushNamed('Settings');
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.cloud_upload),
              title: const Text('استيراد من ملف اكسل'),
              onTap: () {
                mainScfld.currentState!.openEndDrawer();
                import(context);
              },
            ),
            StreamBuilder<bool>(
              initialData: false,
              stream: User.loggedInStream
                  .map((u) => u.permissions.export)
                  .distinct(),
              builder: (context, data) {
                return data.data!
                    ? ListTile(
                        leading: const Icon(Icons.cloud_download),
                        title: const Text('تصدير فصل إلى ملف اكسل'),
                        onTap: () async {
                          mainScfld.currentState!.openEndDrawer();
                          final DataObject? rslt = await showDialog(
                            context: context,
                            builder: (context) => Dialog(
                              child: Column(
                                children: [
                                  Text('برجاء اختيار الفصل او الخدمة للتصدير:',
                                      style: Theme.of(context)
                                          .textTheme
                                          .headline5),
                                  Expanded(
                                    child: ServicesList(
                                      autoDisposeController: true,
                                      onTap: (_class) =>
                                          navigator.currentState!.pop(
                                        _class,
                                      ),
                                      options:
                                          ServicesListController<DataObject>(
                                        objectsPaginatableStream:
                                            PaginatableStream.loadAll(
                                          stream: Stream.value(
                                            [],
                                          ),
                                        ),
                                        groupByStream: (_) => MHDatabaseRepo.I
                                            .groupServicesByStudyYearRef(),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                          if (rslt != null) {
                            scaffoldMessenger.currentState!.showSnackBar(
                              SnackBar(
                                content: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('جار تصدير ' + rslt.name + '...'),
                                    const LinearProgressIndicator(),
                                  ],
                                ),
                                duration: const Duration(minutes: 9),
                              ),
                            );
                            try {
                              final String filename = Uri.decodeComponent(
                                  (await GetIt.I<FunctionsService>()
                                          .httpsCallable('exportToExcel')
                                          .call(
                                {
                                  if (rslt is Class)
                                    'onlyClass': rslt.id
                                  else if (rslt is Service)
                                    'onlyService': rslt.id
                                },
                              ))
                                      .data);
                              final file = await File(
                                      (await getApplicationDocumentsDirectory())
                                              .path +
                                          '/' +
                                          filename.replaceAll(':', ''))
                                  .create(recursive: true);
                              await GetIt.I<StorageRepository>()
                                  .ref(filename)
                                  .writeToFile(file);
                              scaffoldMessenger.currentState!
                                  .hideCurrentSnackBar();
                              scaffoldMessenger.currentState!.showSnackBar(
                                SnackBar(
                                  content:
                                      const Text('تم تصدير البيانات ينجاح'),
                                  action: SnackBarAction(
                                    label: 'فتح',
                                    onPressed: () {
                                      OpenFile.open(file.path);
                                    },
                                  ),
                                ),
                              );
                            } catch (err, stack) {
                              scaffoldMessenger.currentState!
                                  .hideCurrentSnackBar();
                              scaffoldMessenger.currentState!.showSnackBar(
                                const SnackBar(
                                    content: Text('فشل تصدير البيانات')),
                              );
                              await Sentry.captureException(err,
                                  stackTrace: stack,
                                  withScope: (scope) => scope.setTag(
                                      'LasErrorIn', '_RootState.dataExport'));
                            }
                          }
                        },
                      )
                    : Container();
              },
            ),
            StreamBuilder<bool>(
              initialData: false,
              stream: User.loggedInStream
                  .map((u) => u.permissions.export)
                  .distinct(),
              builder: (context, data) {
                return data.data!
                    ? ListTile(
                        leading: const Icon(Icons.cloud_download),
                        title: const Text('تصدير جميع البيانات'),
                        onTap: () async {
                          mainScfld.currentState!.openEndDrawer();
                          scaffoldMessenger.currentState!.showSnackBar(
                            SnackBar(
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: const [
                                  Text(
                                      'جار تصدير جميع البيانات...\nيرجى الانتظار...'),
                                  LinearProgressIndicator(),
                                ],
                              ),
                              duration: const Duration(minutes: 9),
                            ),
                          );
                          try {
                            final String filename = Uri.decodeComponent(
                                (await GetIt.I<FunctionsService>()
                                        .httpsCallable('exportToExcel')
                                        .call())
                                    .data);
                            final file = await File(
                                    (await getApplicationDocumentsDirectory())
                                            .path +
                                        '/' +
                                        filename.replaceAll(':', ''))
                                .create(recursive: true);
                            await GetIt.I<StorageRepository>()
                                .ref(filename)
                                .writeToFile(file);
                            scaffoldMessenger.currentState!
                                .hideCurrentSnackBar();
                            scaffoldMessenger.currentState!.showSnackBar(
                              SnackBar(
                                content: const Text('تم تصدير البيانات ينجاح'),
                                action: SnackBarAction(
                                  label: 'فتح',
                                  onPressed: () {
                                    OpenFile.open(file.path);
                                  },
                                ),
                              ),
                            );
                          } catch (err, stack) {
                            scaffoldMessenger.currentState!
                                .hideCurrentSnackBar();
                            scaffoldMessenger.currentState!.showSnackBar(
                              const SnackBar(
                                  content: Text('فشل تصدير البيانات')),
                            );
                            await Sentry.captureException(err,
                                stackTrace: stack,
                                withScope: (scope) => scope.setTag(
                                    'LasErrorIn', '_RootState.dataExport'));
                          }
                        },
                      )
                    : Container();
              },
            ),
            StreamBuilder<bool>(
              initialData: false,
              stream: User.loggedInStream
                  .map((u) => u.permissions.export)
                  .distinct(),
              builder: (context, data) => data.data!
                  ? ListTile(
                      leading: const Icon(Icons.list_alt),
                      title: const Text('عمليات التصدير السابقة'),
                      onTap: () =>
                          navigator.currentState!.pushNamed('ExportOps'),
                    )
                  : Container(),
            ),
            const Divider(),
            if (!kIsWeb)
              ListTile(
                leading: const Icon(Icons.system_update_alt),
                title: const Text('تحديث البرنامج'),
                onTap: () {
                  mainScfld.currentState!.openEndDrawer();
                  navigator.currentState!.pushNamed('Update');
                },
              ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('حول البرنامج'),
              onTap: () async {
                mainScfld.currentState!.openEndDrawer();
                showAboutDialog(
                  context: context,
                  applicationIcon:
                      Image.asset('assets/Logo.png', width: 50, height: 50),
                  applicationName: 'خدمة مدارس الأحد',
                  applicationLegalese:
                      'جميع الحقوق محفوظة: كنيسة السيدة العذراء مريم بالاسماعيلية',
                  applicationVersion:
                      (await PackageInfo.fromPlatform()).version,
                  children: [
                    RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        children: [
                          TextSpan(
                            style:
                                Theme.of(context).textTheme.bodyText2!.copyWith(
                                      color: Colors.blue,
                                    ),
                            text: 'شروط الاستخدام',
                            recognizer: TapGestureRecognizer()
                              ..onTap = () async {
                                //   final url =
                                //       'https://church-data.flycricket.io/terms.html';
                                //   if (await canLaunch(url)) {
                                //     await launch(url);
                                //   }
                              },
                          ),
                          TextSpan(
                            style: Theme.of(context).textTheme.bodyText2,
                            text: ' • ',
                          ),
                          TextSpan(
                            style:
                                Theme.of(context).textTheme.bodyText2!.copyWith(
                                      color: Colors.blue,
                                    ),
                            text: 'سياسة الخصوصية',
                            recognizer: TapGestureRecognizer()
                              ..onTap = () async {
                                // final url =
                                //     'https://church-data.flycricket.io/privacy.html';
                                // if (await canLaunch(url)) {
                                //   await launch(url);
                                // }
                              },
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
            ListTile(
              leading:
                  const Icon(IconData(0xe9ba, fontFamily: 'MaterialIconsR')),
              title: const Text('تسجيل الخروج'),
              onTap: () async {
                mainScfld.currentState!.openEndDrawer();
                await GetIt.I<CacheRepository>()
                    .box('Settings')
                    .put('FCM_Token_Registered', false);
                await MHAuthRepository.I.signOut();
                unawaited(navigator.currentState!.pushReplacementNamed('/'));
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        if (_timeout && !_pushed) {
          _pushed = true;
          navigator.currentState!
              .push(
            MaterialPageRoute(
              builder: (context) => WillPopScope(
                onWillPop: () => Future.delayed(Duration.zero, () => false),
                child: AuthScreen(
                  onSuccess: () => navigator.currentState!.pop(true),
                ),
              ),
            ),
          )
              .then((value) {
            _pushed = false;
            _timeout = false;

            if (_dynamicLinksSubscription.isPaused) {
              _dynamicLinksSubscription.resume();
            }
            if (MHNotificationsService
                .I.onMessageOpenedAppSubscription.isPaused) {
              MHNotificationsService.I.onMessageOpenedAppSubscription.resume();
            }
            if (MHNotificationsService
                    .I.onForegroundMessageSubscription?.isPaused ??
                false) {
              MHNotificationsService.I.onForegroundMessageSubscription
                  ?.resume();
            }
          });
        } else {
          if (_dynamicLinksSubscription.isPaused) {
            _dynamicLinksSubscription.resume();
          }
          if (MHNotificationsService
              .I.onMessageOpenedAppSubscription.isPaused) {
            MHNotificationsService.I.onMessageOpenedAppSubscription.resume();
          }
          if (MHNotificationsService
                  .I.onForegroundMessageSubscription?.isPaused ??
              false) {
            MHNotificationsService.I.onForegroundMessageSubscription?.resume();
          }
        }
        _keepAlive(true);
        _recordActive();
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
      case AppLifecycleState.paused:
        _keepAlive(false);
        _recordLastSeen();
        if (!_dynamicLinksSubscription.isPaused) {
          _dynamicLinksSubscription.pause();
        }
        break;
    }
  }

  @override
  void didChangePlatformBrightness() {
    GetIt.I<MHThemingService>().switchTheme(
        WidgetsBinding.instance?.window.platformBrightness == Brightness.dark);
  }

  @override
  Future<void> dispose() async {
    super.dispose();
    WidgetsBinding.instance?.removeObserver(this);

    await _dynamicLinksSubscription.cancel();

    await _showSearch.close();
    await _personsOrder.close();
    await _searchQuery.close();
    await _usersOptions.dispose();
    await _servicesOptions.dispose();
    await _personsOptions.dispose();
  }

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('ar_EG');
    _usersOptions = ListController<Class?, UserWithPerson>(
      searchStream: _searchQuery,
      objectsPaginatableStream: PaginatableStream.loadAll(
        stream: MHDatabaseRepo.instance.getAllUsersData(),
      ),
      groupByStream: (u) => MHDatabaseRepo.I.groupUsersByClass(u).map(
            (event) => event.map(
              (key, value) => MapEntry(
                key,
                value.cast<UserWithPerson>(),
              ),
            ),
          ),
      groupingStream: Stream.value(true),
    );

    _servicesOptions = ServicesListController(
      searchQuery: _searchQuery,
      objectsPaginatableStream: PaginatableStream.loadAll(
        stream: Stream.value([]),
      ),
      groupByStream: (_) => MHDatabaseRepo.I.groupServicesByStudyYearRef(),
    );

    _personsOptions = ListController<void, Person>(
      searchStream: _searchQuery,
      //Listen to Ordering options and combine it
      //with the Data Stream from Firestore
      objectsPaginatableStream: PaginatableStream.loadAll(
        stream: _personsOrder.switchMap(
          (order) => MHDatabaseRepo.instance.getAllPersons(
            orderBy: order.orderBy,
            descending: !order.asc,
          ),
        ),
      ),
    );

    _tabController = TabController(
        vsync: this,
        initialIndex: User.instance.permissions.manageUsers ||
                User.instance.permissions.manageAllowedUsers
            ? 1
            : 0,
        length: User.instance.permissions.manageUsers ||
                User.instance.permissions.manageAllowedUsers
            ? 3
            : 2);
    WidgetsBinding.instance?.addObserver(this);
    _keepAlive(true);
    WidgetsBinding.instance?.addPostFrameCallback((_) {
      if (dialogsNotShown) showPendingUIDialogs();
    });
  }

  Future<void> showBatteryOptimizationDialog() async {
    if (!kIsWeb &&
        (await DeviceInfoPlugin().androidInfo).version.sdkInt! >= 23 &&
        !(await Permission.ignoreBatteryOptimizations.status).isGranted &&
        GetIt.I<CacheRepository>()
            .box('Settings')
            .get('ShowBatteryDialog', defaultValue: true)) {
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          content: const Text(
              'برجاء الغاء تفعيل حفظ الطاقة للبرنامج لإظهار الاشعارات في الخلفية'),
          actions: [
            TextButton(
              onPressed: () async {
                navigator.currentState!.pop();
                await Permission.ignoreBatteryOptimizations.request();
              },
              child: const Text('الغاء حفظ الطاقة للبرنامج'),
            ),
            TextButton(
              onPressed: () async {
                await GetIt.I<CacheRepository>()
                    .box('Settings')
                    .put('ShowBatteryDialog', false);
                navigator.currentState!.pop();
              },
              child: const Text('عدم الاظهار مجددًا'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> showDynamicLink() async {
    if (kIsWeb) return;
    final PendingDynamicLinkData? data =
        await GetIt.I<FirebaseDynamicLinks>().getInitialLink();

    _dynamicLinksSubscription = GetIt.I<FirebaseDynamicLinks>().onLink.listen(
      (dynamicLink) async {
        final object =
            await MHDatabaseRepo.I.getObjectFromLink(dynamicLink.link);

        if (object != null) GetIt.I<MHViewableObjectTapHandler>().onTap(object);
      },
      onError: (e) async {
        debugPrint('DynamicLinks onError $e');
      },
    );
    if (data == null) return;

    final object = await MHDatabaseRepo.I.getObjectFromLink(data.link);
    if (object != null) GetIt.I<MHViewableObjectTapHandler>().onTap(object);
  }

  TargetFocus _getTarget(String key, GlobalKey v) {
    const alignSkip = Alignment.bottomLeft;
    late final List<TargetContent> contents;
    ShapeLightFocus shape = ShapeLightFocus.Circle;

    switch (key) {
      case 'Services':
        contents = [
          TargetContent(
            child: Text(
              'هنا تجد قائمة بكل الفصول في'
              ' البرنامج مقسمة الى الخدمات وسنوات الدراسة',
              style: Theme.of(context)
                  .textTheme
                  .subtitle2
                  ?.copyWith(color: Theme.of(context).colorScheme.onSecondary),
            ),
          ),
        ];
        break;
      case 'Servants':
        contents = [
          TargetContent(
            child: Text(
              'الخدام: قائمة الخدام الموجودين في التطبيق',
              style: Theme.of(context)
                  .textTheme
                  .subtitle2
                  ?.copyWith(color: Theme.of(context).colorScheme.onSecondary),
            ),
          ),
        ];
        break;
      case 'Persons':
        contents = [
          TargetContent(
            child: Text(
              'المخدومين: قائمة المخدومين الموجودين في التطبيق',
              style: Theme.of(context)
                  .textTheme
                  .subtitle2
                  ?.copyWith(color: Theme.of(context).colorScheme.onSecondary),
            ),
          ),
        ];
        break;
      case 'Search':
        contents = [
          TargetContent(
            child: Text(
              'البحث: يمكنك استخدام البحث السريع لإيجاد المخدومين او الفصول',
              style: Theme.of(context)
                  .textTheme
                  .subtitle2
                  ?.copyWith(color: Theme.of(context).colorScheme.onSecondary),
            ),
          ),
        ];
        break;
      case 'MyAccount':
        contents = [
          TargetContent(
            child: Text(
              'حسابي:من خلاله يمكنك رؤية صلاحياتك او تغيير تاريخ أخر تناول واخر اعتراف',
              style: Theme.of(context)
                  .textTheme
                  .subtitle2
                  ?.copyWith(color: Theme.of(context).colorScheme.onSecondary),
            ),
          )
        ];
        shape = ShapeLightFocus.RRect;
        break;
      case 'ManageUsers':
        contents = [
          TargetContent(
            child: Text(
              'ادارة المستخدمين: يمكنك من خلالها تغيير وادارة صلاحيات الخدام في التطبيق',
              style: Theme.of(context)
                  .textTheme
                  .subtitle2
                  ?.copyWith(color: Theme.of(context).colorScheme.onSecondary),
            ),
          )
        ];
        shape = ShapeLightFocus.RRect;
        break;
      case 'AddHistory':
        contents = [
          TargetContent(
            child: Text(
              'كشف حضور المخدومين: تسجيل كشف حضور جديد في كشوفات المخدومين',
              style: Theme.of(context)
                  .textTheme
                  .subtitle2
                  ?.copyWith(color: Theme.of(context).colorScheme.onSecondary),
            ),
          )
        ];
        shape = ShapeLightFocus.RRect;
        break;
      case 'AddServantsHistory':
        contents = [
          TargetContent(
            child: Text(
              'كشف حضور الخدام: تسجيل كشف حضور جديد في كشوفات الخدام',
              style: Theme.of(context)
                  .textTheme
                  .subtitle2
                  ?.copyWith(color: Theme.of(context).colorScheme.onSecondary),
            ),
          )
        ];
        shape = ShapeLightFocus.RRect;
        break;
      case 'History':
        contents = [
          TargetContent(
            child: Text(
              'سجل المخدومين: سجل كشوفات المخدومين لأي يوم تم تسجيله',
              style: Theme.of(context)
                  .textTheme
                  .subtitle2
                  ?.copyWith(color: Theme.of(context).colorScheme.onSecondary),
            ),
          )
        ];
        shape = ShapeLightFocus.RRect;
        break;
      case 'ServantsHistory':
        contents = [
          TargetContent(
            child: Text(
              'سجل الخدام: سجل كشوفات الخدام لأي يوم تم تسجيله',
              style: Theme.of(context)
                  .textTheme
                  .subtitle2
                  ?.copyWith(color: Theme.of(context).colorScheme.onSecondary),
            ),
          )
        ];
        shape = ShapeLightFocus.RRect;
        break;
      case 'Analytics':
        contents = [
          TargetContent(
            child: Text(
              'تحليل سجل المخدومين: يمكنك '
              'من خلالها تحليل واحصاء '
              'أعداد المخدومين الحاضرين خلال مدة معينة ',
              style: Theme.of(context)
                  .textTheme
                  .subtitle2
                  ?.copyWith(color: Theme.of(context).colorScheme.onSecondary),
            ),
          )
        ];
        shape = ShapeLightFocus.RRect;
        break;
      case 'ActivityAnalysis':
        contents = [
          TargetContent(
            child: Text(
              'تحليل سجل الخدام: يمكنك '
              'من خلالها تحليل واحصاء '
              'أعداد الخدام الحاضرين خلال مدة معينة ',
              style: Theme.of(context)
                  .textTheme
                  .subtitle2
                  ?.copyWith(color: Theme.of(context).colorScheme.onSecondary),
            ),
          ),
        ];
        shape = ShapeLightFocus.RRect;
        break;
      case 'AdvancedSearch':
        contents = [
          TargetContent(
            child: Text(
              'بحث متقدم: بحث عن البيانات بصورة دقيقة ومفصلة',
              style: Theme.of(context)
                  .textTheme
                  .subtitle2
                  ?.copyWith(color: Theme.of(context).colorScheme.onSecondary),
            ),
          ),
        ];
        shape = ShapeLightFocus.RRect;
        break;
      case 'ManageDeleted':
        contents = [
          TargetContent(
            child: Text(
              'سلة المحذوفات: يمكنك '
              'من خلالها استرجاع المحذوفات التي تم حذفها خلال الشهر الحالي ',
              style: Theme.of(context)
                  .textTheme
                  .subtitle2
                  ?.copyWith(color: Theme.of(context).colorScheme.onSecondary),
            ),
          ),
        ];
        shape = ShapeLightFocus.RRect;
        break;
      case 'DataMap':
        contents = [
          TargetContent(
            child: Text(
              'خريطة الافتقاد: عرض لخريطة في موقعك'
              ' الحالي ومواقع المخدومين ويمكنك ايضًا تحديد'
              ' فصول معينة والذهاب لمكان المخدوم'
              ' من خلال خرائط جوجل',
              style: Theme.of(context)
                  .textTheme
                  .subtitle2
                  ?.copyWith(color: Theme.of(context).colorScheme.onSecondary),
            ),
          ),
        ];
        shape = ShapeLightFocus.RRect;
        break;
      case 'Settings':
        contents = [
          TargetContent(
            child: Text(
              'الاعدادات: ضبط بعض الاعدادات والتفضيلات وضبط مواعيد الاشعارت اليومية',
              style: Theme.of(context)
                  .textTheme
                  .subtitle2
                  ?.copyWith(color: Theme.of(context).colorScheme.onSecondary),
            ),
          ),
        ];
        shape = ShapeLightFocus.RRect;
        break;

      default:
        contents = [];
    }

    return TargetFocus(
      identify: key,
      shape: shape,
      alignSkip: alignSkip,
      enableOverlayTab: true,
      contents: contents,
      keyTarget: v,
      color: Theme.of(context).colorScheme.secondary,
    );
  }

  Future<void> showFeatures() async {
    final Completer<void> _completer = Completer();

    final featuresInOrder = [
      'Services',
      'Persons',
      'Servants',
      'Search',
      'MyAccount',
      if (User.instance.permissions.manageUsers ||
          User.instance.permissions.manageAllowedUsers)
        'ManageUsers',
      if (User.instance.permissions.recordHistory) 'AddHistory',
      if (User.instance.permissions.secretary) 'AddServantsHistory',
      'History',
      if (User.instance.permissions.secretary) 'ServantsHistory',
      'Analytics',
      if (User.instance.permissions.manageUsers ||
          User.instance.permissions.manageAllowedUsers)
        'ActivityAnalysis',
      'AdvancedSearch',
      if (User.instance.permissions.manageDeleted) 'ManageDeleted',
      'DataMap',
      'Settings'
    ]..removeWhere(HivePersistenceProvider.instance.hasCompletedStep);

    bool drawerOpened = false;
    Future<void> _next(TargetFocus t) async {
      await HivePersistenceProvider.instance.completeStep(t.identify);
      if (!['Services', 'Persons', 'Servants'].contains(t.identify)) {
        if (!drawerOpened) {
          mainScfld.currentState!.openDrawer();
          drawerOpened = true;
          await Future.delayed(const Duration(seconds: 1));
        }
        await Scrollable.ensureVisible(_features[t.identify]!.currentContext!);
      }
    }

    if (featuresInOrder.isNotEmpty) {
      if (!['Services', 'Persons', 'Servants'].contains(featuresInOrder[0])) {
        if (!drawerOpened) {
          mainScfld.currentState!.openDrawer();
          drawerOpened = true;
          await Future.delayed(const Duration(seconds: 1));
        }
        await Scrollable.ensureVisible(
            _features[featuresInOrder[0]]!.currentContext!);
      }

      TutorialCoachMark(
        context,
        focusAnimationDuration: const Duration(milliseconds: 200),
        targets:
            featuresInOrder.map((k) => _getTarget(k, _features[k]!)).toList(),
        alignSkip: Alignment.bottomLeft,
        textSkip: 'تخطي',
        onClickOverlay: _next,
        onClickTarget: _next,
        onFinish: _completer.complete,
        onSkip: _completer.complete,
      ).show();
    } else {
      _completer.complete();
    }
    return _completer.future;
  }

  Future<void> showPendingUIDialogs() async {
    dialogsNotShown = false;
    if (!User.instance.userDataUpToDate()) {
      await showErrorUpdateDataDialog(context: context, pushApp: false);
    }

    await showDynamicLink();
    await GetIt.I<MHNotificationsService>().showInitialNotification(context);
    await showBatteryOptimizationDialog();
    await showFeatures();
  }

  void _keepAlive(bool visible) {
    _keepAliveTimer?.cancel();
    if (visible) {
      _keepAliveTimer = null;
    } else {
      _keepAliveTimer = Timer(
        const Duration(minutes: 1),
        () {
          _timeout = true;
          _dynamicLinksSubscription.pause();
          MHNotificationsService.I.onMessageOpenedAppSubscription.pause();
          MHNotificationsService.I.onForegroundMessageSubscription?.pause();
        },
      );
    }
  }

  Future<void> _recordActive() async {
    await MHAuthRepository.I.recordActive();
  }

  Future<void> _recordLastSeen() async {
    await MHAuthRepository.I.recordLastSeen();
  }
}
