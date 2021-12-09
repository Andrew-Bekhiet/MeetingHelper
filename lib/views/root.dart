import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_dynamic_links/firebase_dynamic_links.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_storage/firebase_storage.dart' hide ListOptions;
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:meetinghelper/models/data/class.dart';
import 'package:meetinghelper/models/data/person.dart';
import 'package:meetinghelper/models/data/service.dart';
import 'package:meetinghelper/models/hive_persistence_provider.dart';
import 'package:meetinghelper/models/super_classes.dart';
import 'package:meetinghelper/views/lists/lists.dart';
import 'package:open_file/open_file.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:rxdart/rxdart.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

import '../models/data/user.dart';
import '../models/list_controllers.dart';
import '../utils/globals.dart';
import '../utils/helpers.dart';
import 'auth_screen.dart';
import 'edit_page/edit_person.dart';
import 'list.dart';
import 'services_list.dart';

class Root extends StatefulWidget {
  const Root({Key? key}) : super(key: key);

  @override
  _RootState createState() => _RootState();
}

class _RootState extends State<Root>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final StreamSubscription<PendingDynamicLinkData>
      _dynamicLinksSubscription;
  late final StreamSubscription<RemoteMessage> _firebaseMessagingSubscription;

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

  void addTap() async {
    if (_tabController!.index == _tabController!.length - 2) {
      if (User.instance.manageUsers || User.instance.manageAllowedUsers) {
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
        if (rslt == true)
          unawaited(navigator.currentState!.pushNamed('Data/EditClass'));
        else if (rslt == false)
          unawaited(navigator.currentState!.pushNamed('Data/EditService'));
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
              person: User(
                name: '',
                email: '',
                ref: FirebaseFirestore.instance.collection('UsersData').doc(),
              ),
            );
          },
        ),
      ));
    }
  }

  late ServicesListController _servicesOptions;
  late DataObjectListController<Person> _personsOptions;
  late DataObjectListController<User> _usersOptions;

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
                                  _personsOptions.selectNone();
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
                                              orderBy: value,
                                              asc: _personsOrder.value.asc),
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
            if (User.instance.manageUsers || User.instance.manageAllowedUsers)
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
      floatingActionButton: FloatingActionButton(
        onPressed: addTap,
        child: AnimatedBuilder(
          animation: _tabController!,
          builder: (context, _) => Icon(
              _tabController!.index == _tabController!.length - 2
                  ? Icons.group_add
                  : Icons.person_add),
        ),
      ),
      bottomNavigationBar: BottomAppBar(
        color: Theme.of(context).colorScheme.primary,
        shape: const CircularNotchedRectangle(),
        child: AnimatedBuilder(
          animation: _tabController!,
          builder: (context, _) => StreamBuilder<dynamic>(
            stream: _tabController!.index == _tabController!.length - 1
                ? _personsOptions.objectsData
                : _tabController!.index == _tabController!.length - 2
                    ? _servicesOptions.objectsData
                    : _usersOptions.objectsData,
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
          if (User.instance.manageUsers || User.instance.manageAllowedUsers)
            UsersList(
              key: const PageStorageKey('mainUsersList'),
              autoDisposeController: false,
              listOptions: _usersOptions,
            ),
          ServicesList(
            key: const PageStorageKey('mainClassesList'),
            autoDisposeController: false,
            options: _servicesOptions,
          ),
          DataObjectList<Person>(
            key: const PageStorageKey('mainPersonsList'),
            disposeController: false,
            options: _personsOptions,
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
              leading: StreamBuilder<User>(
                stream: User.instance.stream,
                initialData: User.instance,
                builder: (context, snapshot) {
                  return snapshot.data!.getPhoto(true, false);
                },
              ),
              title: const Text('حسابي'),
              onTap: () {
                mainScfld.currentState!.openEndDrawer();
                navigator.currentState!.pushNamed('MyAccount');
              },
            ),
            Selector<User, bool>(
              key: _createOrGetFeatureKey('ManageUsers'),
              selector: (_, user) =>
                  user.manageUsers || user.manageAllowedUsers,
              builder: (c, permission, data) {
                if (!permission)
                  return const SizedBox(
                    width: 0,
                    height: 0,
                  );
                return ListTile(
                  leading: const Icon(Icons.admin_panel_settings),
                  onTap: () async {
                    mainScfld.currentState!.openEndDrawer();
                    if (await Connectivity().checkConnectivity() !=
                        ConnectivityResult.none) {
                      // ignore: unawaited_futures
                      navigator.currentState!.push(
                        MaterialPageRoute(
                          builder: (context) => const AuthScreen(
                            nextRoute: 'ManageUsers',
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
            ListTile(
              key: _createOrGetFeatureKey('AddHistory'),
              leading: const Icon(Icons.add),
              title: const Text('كشف حضور المخدومين'),
              onTap: () {
                mainScfld.currentState!.openEndDrawer();
                navigator.currentState!.pushNamed('Day');
              },
            ),
            Selector<User, bool?>(
              key: _createOrGetFeatureKey('AddServantsHistory'),
              selector: (_, user) => user.secretary,
              builder: (c, permission, data) => permission!
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
            Selector<User, bool?>(
              key: _createOrGetFeatureKey('ServantsHistory'),
              selector: (_, user) => user.secretary,
              builder: (c, permission, data) => permission!
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
            ListTile(
              leading: const Icon(Icons.analytics_outlined),
              title: const Text('تحليل بيانات سجل الخدام'),
              onTap: () {
                mainScfld.currentState!.openEndDrawer();
                navigator.currentState!.pushNamed('Analytics',
                    arguments: {'HistoryCollection': 'ServantsHistory'});
              },
            ),
            Consumer<User>(
              key: _createOrGetFeatureKey('ActivityAnalysis'),
              builder: (context, user, _) => user.manageUsers ||
                      user.manageAllowedUsers
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
            Selector<User, bool?>(
              key: _createOrGetFeatureKey('ManageDeleted'),
              selector: (_, user) => user.manageDeleted,
              builder: (context, permission, _) {
                if (!permission!)
                  return const SizedBox(
                    width: 0,
                    height: 0,
                  );
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
            Selector<User, bool?>(
              selector: (_, user) => user.export,
              builder: (context2, permission, _) {
                return permission!
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
                                      options: ServicesListController(
                                        tap: (_class) =>
                                            navigator.currentState!.pop(
                                          _class,
                                        ),
                                        itemsStream: servicesByStudyYearRef(),
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
                                  (await FirebaseFunctions.instance
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
                              await FirebaseStorage.instance
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
            Selector<User, bool?>(
              selector: (_, user) => user.export,
              builder: (context2, permission, _) {
                return permission!
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
                                (await FirebaseFunctions.instance
                                        .httpsCallable('exportToExcel')
                                        .call())
                                    .data);
                            final file = await File(
                                    (await getApplicationDocumentsDirectory())
                                            .path +
                                        '/' +
                                        filename.replaceAll(':', ''))
                                .create(recursive: true);
                            await FirebaseStorage.instance
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
            Selector<User, bool?>(
              selector: (_, user) => user.export,
              builder: (context, user, _) => ListTile(
                leading: const Icon(Icons.list_alt),
                title: const Text('عمليات التصدير السابقة'),
                onTap: () => navigator.currentState!.pushNamed('ExportOps'),
              ),
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
                await Hive.box('Settings').put('FCM_Token_Registered', false);
                await User.instance.signOut();
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
                child: const AuthScreen(),
              ),
            ),
          )
              .then((value) {
            _pushed = false;
            _timeout = false;
            if (_dynamicLinksSubscription.isPaused)
              _dynamicLinksSubscription.resume();
            if (_firebaseMessagingSubscription.isPaused)
              _firebaseMessagingSubscription.resume();
          });
        }
        _keepAlive(true);
        _recordActive();
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
      case AppLifecycleState.paused:
        _keepAlive(false);
        _recordLastSeen();
        if (!_dynamicLinksSubscription.isPaused)
          _dynamicLinksSubscription.pause();
        if (!_firebaseMessagingSubscription.isPaused)
          _firebaseMessagingSubscription.pause();
        break;
    }
  }

  @override
  void didChangePlatformBrightness() {
    changeTheme(context: mainScfld.currentContext!);
  }

  @override
  Future<void> dispose() async {
    super.dispose();
    WidgetsBinding.instance!.removeObserver(this);

    await _firebaseMessagingSubscription.cancel();
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
    _usersOptions = DataObjectListController<User>(
      searchQuery: _searchQuery,
      tap: personTap,
      itemsStream: User.getAllForUser(),
    );
    _servicesOptions = ServicesListController(
      searchQuery: _searchQuery,
      itemsStream: servicesByStudyYearRef(),
      tap: dataObjectTap,
    );
    _personsOptions = DataObjectListController<Person>(
      searchQuery: _searchQuery,
      tap: personTap,
      //Listen to Ordering options and combine it
      //with the Data Stream from Firestore
      itemsStream: _personsOrder.switchMap(
        (order) => Person.getAllForUser(
            orderBy: order.orderBy ?? 'Name', descending: !order.asc!),
      ),
    );
    _tabController = TabController(
        vsync: this,
        initialIndex:
            User.instance.manageUsers || User.instance.manageAllowedUsers
                ? 1
                : 0,
        length: User.instance.manageUsers || User.instance.manageAllowedUsers
            ? 3
            : 2);
    WidgetsBinding.instance!.addObserver(this);
    _keepAlive(true);
    WidgetsBinding.instance!.addPostFrameCallback((_) {
      if (dialogsNotShown) showPendingUIDialogs();
    });
  }

  Future<void> showBatteryOptimizationDialog() async {
    if (!kIsWeb &&
        (await DeviceInfoPlugin().androidInfo).version.sdkInt! >= 23 &&
        !(await Permission.ignoreBatteryOptimizations.status).isGranted &&
        Hive.box('Settings').get('ShowBatteryDialog', defaultValue: true)) {
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
                await Hive.box('Settings').put('ShowBatteryDialog', false);
                navigator.currentState!.pop();
              },
              child: const Text('عدم الاظهار مجددًا'),
            ),
          ],
        ),
      );
    }
  }

  Future showDynamicLink() async {
    if (kIsWeb) return;
    final PendingDynamicLinkData? data =
        await FirebaseDynamicLinks.instance.getInitialLink();

    _dynamicLinksSubscription = FirebaseDynamicLinks.instance.onLink.listen(
      (dynamicLink) async {
        final Uri deepLink = dynamicLink.link;

        await processLink(deepLink);
      },
      onError: (e) async {
        debugPrint('DynamicLinks onError $e');
      },
    );
    if (data == null) return;
    final Uri deepLink = data.link;
    await processLink(deepLink);
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
      if (User.instance.manageUsers || User.instance.manageAllowedUsers)
        'ManageUsers',
      'AddHistory',
      if (User.instance.secretary) 'AddServantsHistory',
      'History',
      if (User.instance.secretary) 'ServantsHistory',
      'Analytics',
      if (User.instance.manageUsers || User.instance.manageAllowedUsers)
        'ActivityAnalysis',
      'AdvancedSearch',
      if (User.instance.manageDeleted) 'ManageDeleted',
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

  void showPendingUIDialogs() async {
    dialogsNotShown = false;
    if (!await User.instance.userDataUpToDate()) {
      await showErrorUpdateDataDialog(context: context, pushApp: false);
    }
    listenToFirebaseMessaging();
    await showDynamicLink();
    await showPendingMessage();
    await processClickedNotification(context);
    await showBatteryOptimizationDialog();
    await showFeatures();
  }

  void listenToFirebaseMessaging() {
    FirebaseMessaging.onBackgroundMessage(onBackgroundMessage);
    FirebaseMessaging.onMessage.listen(onForegroundMessage);
    _firebaseMessagingSubscription =
        FirebaseMessaging.onMessageOpenedApp.listen((m) async {
      await showPendingMessage();
    });
  }

  void _keepAlive(bool visible) {
    _keepAliveTimer?.cancel();
    if (visible) {
      _keepAliveTimer = null;
    } else {
      _keepAliveTimer = Timer(
        const Duration(minutes: 1),
        () => _timeout = true,
      );
    }
  }

  Future<void> _recordActive() async {
    await User.instance.recordActive();
  }

  Future<void> _recordLastSeen() async {
    await User.instance.recordLastSeen();
  }
}
