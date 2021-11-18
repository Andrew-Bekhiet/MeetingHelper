import 'dart:async';
import 'dart:convert';

import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:async/async.dart';
import 'package:cloud_firestore/cloud_firestore.dart' as firestore;
import 'package:cloud_functions/cloud_functions.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart'
    if (dart.library.io) 'package:firebase_crashlytics/firebase_crashlytics.dart'
    if (dart.library.html) 'package:meetinghelper/crashlytics_web.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart'
    hide Day, Person;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:meetinghelper/admin.dart';
import 'package:meetinghelper/secrets.dart';
import 'package:meetinghelper/views/day.dart';
import 'package:meetinghelper/views/edit_page/edit_invitation.dart';
import 'package:meetinghelper/views/edit_users.dart';
import 'package:meetinghelper/views/exports.dart';
import 'package:meetinghelper/views/invitations_page.dart';
import 'package:meetinghelper/views/trash.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:timeago/timeago.dart';

import 'models/data/class.dart';
import 'models/data/invitation.dart';
import 'models/data/person.dart';
import 'models/data/service.dart';
import 'models/data/user.dart';
import 'models/history/history_record.dart';
import 'models/mini_models.dart' hide History;
import 'models/super_classes.dart';
import 'models/theme_notifier.dart';
import 'updates.dart';
import 'utils/globals.dart';
import 'utils/helpers.dart';
import 'utils/typedefs.dart';
import 'views/analytics/analytics_page.dart';
import 'views/auth_screen.dart';
import 'views/data_map.dart';
import 'views/edit_page/edit_class.dart';
import 'views/edit_page/edit_person.dart';
import 'views/edit_page/edit_service.dart';
import 'views/history.dart';
import 'views/info_page/class_info.dart';
import 'views/info_page/invitation_info.dart';
import 'views/info_page/person_info.dart';
import 'views/info_page/service_info.dart';
import 'views/info_page/user_info.dart';
import 'views/loading_widget.dart';
import 'views/login.dart';
import 'views/mini_lists/mini_list.dart';
import 'views/my_account.dart';
import 'views/notifications_page.dart';
import 'views/root.dart';
import 'views/search_query.dart';
import 'views/settings.dart' as s;
import 'views/update_user_data.dart';
import 'views/user_registeration.dart';

void main() async {
  await SentryFlutter.init(
    (options) => options
      ..dsn = sentryDSN
      ..environment = kReleaseMode ? 'Production' : 'Debug',
  );

  FlutterError.onError = (flutterError) {
    Sentry.captureException(flutterError.exception,
        stackTrace: flutterError.stack, hint: flutterError);
    FirebaseCrashlytics.instance.recordFlutterError(flutterError);
  };
  ErrorWidget.builder = (error) {
    if (kReleaseMode) {
      Sentry.captureException(error.exception,
          stackTrace: error.stack, hint: error);
      FirebaseCrashlytics.instance.recordFlutterError(error);
    }
    return Material(
      child: Container(
          color: Colors.white,
          child: Text('حدث خطأ:\n' + error.summary.toString())),
    );
  };

  WidgetsFlutterBinding.ensureInitialized();

  await _initConfigs();

  if (auth.FirebaseAuth.instance.currentUser != null &&
      (await Connectivity().checkConnectivity()) != ConnectivityResult.none)
    await User.instance.initialized;
  final User user = User.instance;

  bool? darkSetting = Hive.box('Settings').get('DarkTheme');
  final bool greatFeastTheme =
      Hive.box('Settings').get('GreatFeastTheme', defaultValue: true);
  MaterialColor primary = Colors.amber;
  Color secondary = Colors.amberAccent;

  final riseDay = getRiseDay();
  if (greatFeastTheme &&
      DateTime.now()
          .isAfter(riseDay.subtract(const Duration(days: 7, seconds: 20))) &&
      DateTime.now().isBefore(riseDay.subtract(const Duration(days: 1)))) {
    primary = black;
    secondary = blackAccent;
    darkSetting = true;
  } else if (greatFeastTheme &&
      DateTime.now()
          .isBefore(riseDay.add(const Duration(days: 50, seconds: 20))) &&
      DateTime.now().isAfter(riseDay.subtract(const Duration(days: 1)))) {
    darkSetting = false;
  }

  runApp(
    MultiProvider(
      providers: [
        StreamProvider<User>.value(value: user.stream, initialData: user),
        Provider<ThemeNotifier>(
          create: (_) {
            final bool isDark = darkSetting ??
                WidgetsBinding.instance!.window.platformBrightness ==
                    Brightness.dark;

            return ThemeNotifier(
              ThemeData.from(
                colorScheme: ColorScheme.fromSwatch(
                  backgroundColor:
                      isDark ? Colors.grey[850]! : Colors.grey[50]!,
                  brightness: isDark ? Brightness.dark : Brightness.light,
                  primarySwatch: primary,
                  accentColor: secondary,
                ),
              ).copyWith(
                inputDecorationTheme: InputDecorationTheme(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide(color: primary),
                  ),
                ),
                floatingActionButtonTheme:
                    FloatingActionButtonThemeData(backgroundColor: primary),
                visualDensity: VisualDensity.adaptivePlatformDensity,
                brightness: isDark ? Brightness.dark : Brightness.light,
                textButtonTheme: TextButtonThemeData(
                  style: TextButton.styleFrom(
                    primary: secondary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                ),
                outlinedButtonTheme: OutlinedButtonThemeData(
                  style: OutlinedButton.styleFrom(
                    primary: secondary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                ),
                elevatedButtonTheme: ElevatedButtonThemeData(
                  style: ElevatedButton.styleFrom(
                    primary: secondary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                ),
                appBarTheme: AppBarTheme(
                  backgroundColor: primary,
                  foregroundColor: (isDark
                          ? Typography.material2018().white
                          : Typography.material2018().black)
                      .headline6
                      ?.color,
                  systemOverlayStyle: isDark
                      ? SystemUiOverlayStyle.light
                      : SystemUiOverlayStyle.dark,
                ),
                bottomAppBarTheme: BottomAppBarTheme(
                  color: secondary,
                  shape: const CircularNotchedRectangle(),
                ),
              ),
            );
          },
        ),
      ],
      builder: (context, _) => const App(),
    ),
  );
}

Future _initConfigs([bool retryOnHiveError = true]) async {
  //Hive initialization:
  try {
    await Hive.initFlutter();

    const FlutterSecureStorage secureStorage = FlutterSecureStorage();
    final containsEncryptionKey = await secureStorage.containsKey(key: 'key');
    if (!containsEncryptionKey)
      await secureStorage.write(
          key: 'key', value: base64Url.encode(Hive.generateSecureKey()));

    final encryptionKey =
        base64Url.decode((await secureStorage.read(key: 'key'))!);

    await Hive.openBox(
      'User',
      encryptionCipher: HiveAesCipher(encryptionKey),
    );

    await Hive.openBox('Settings');
    await Hive.openBox<bool>('FeatureDiscovery');
    await Hive.openBox<Map>('NotificationsSettings');
    await Hive.openBox<String?>('PhotosURLsCache');
    await Hive.openBox<Map>('Notifications');
  } catch (e, stackTrace) {
    await Hive.close();
    await Hive.deleteBoxFromDisk('User');
    await Hive.deleteBoxFromDisk('Settings');
    await Hive.deleteBoxFromDisk('FeatureDiscovery');
    await Hive.deleteBoxFromDisk('NotificationsSettings');
    await Hive.deleteBoxFromDisk('PhotosURLsCache');
    await Hive.deleteBoxFromDisk('Notifications');

    await Sentry.captureException(e,
        stackTrace: stackTrace,
        withScope: (scope) => scope.setTag('LastErrorIn', 'main._initConfigs'));
    if (retryOnHiveError) return _initConfigs(false);
    rethrow;
  }
  try {
    await dotenv.load(fileName: '.env');

    final String? kEmulatorsHost = dotenv.env['kEmulatorsHost'];
    //Firebase initialization
    if (kDebugMode &&
        dotenv.env['kUseFirebaseEmulators']?.toString() == 'true') {
      await Firebase.initializeApp(
        options: FirebaseOptions(
            apiKey: dotenv.env['apiKey'] ?? 'sss',
            appId: dotenv.env['appId'] ?? 'ss',
            messagingSenderId: 'messagingSenderId',
            projectId: dotenv.env['projectId']!,
            databaseURL: 'http://' +
                kEmulatorsHost! +
                ':9000?ns=' +
                dotenv.env['projectId']!),
      );
      await auth.FirebaseAuth.instance.useAuthEmulator(kEmulatorsHost, 9099);
      await FirebaseStorage.instance.useStorageEmulator(kEmulatorsHost, 9199);
      firestore.FirebaseFirestore.instance
          .useFirestoreEmulator(kEmulatorsHost, 8080, sslEnabled: false);
      FirebaseFunctions.instance.useFunctionsEmulator(kEmulatorsHost, 5001);
      dbInstance = FirebaseDatabase(
          databaseURL: 'http://' +
              kEmulatorsHost +
              ':9000?ns=' +
              dotenv.env['projectId']!);
    } else {
      await Firebase.initializeApp();
    }
  } catch (e) {
    await Firebase.initializeApp();
  }

  if (!kIsWeb) await AndroidAlarmManager.initialize();

  await FlutterLocalNotificationsPlugin().initialize(
      const InitializationSettings(
          android: AndroidInitializationSettings('warning')),
      onSelectNotification: onNotificationClicked);
}

class App extends StatefulWidget {
  const App({Key? key}) : super(key: key);

  @override
  AppState createState() => AppState();
}

class AppState extends State<App> {
  bool configureMessaging = true;
  StreamSubscription? userTokenListener;
  final AsyncMemoizer<void> _appLoader = AsyncMemoizer();

  @override
  void dispose() {
    userTokenListener?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    setLocaleMessages('ar', ArMessages());
  }

  Widget buildLoadAppWidget(BuildContext context) {
    return FutureBuilder<void>(
      future: _appLoader.runOnce(() => loadApp(context)),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done)
          return const Loading(
            showVersionInfo: true,
          );

        if (snapshot.hasError) {
          if (snapshot.error.toString() ==
                  'Exception: Error Update User Data' &&
              User.instance.password != null) {
            WidgetsBinding.instance!.addPostFrameCallback((_) {
              showErrorUpdateDataDialog(context: context);
            });
          } else if (snapshot.error.toString() ==
              'Exception: يجب التحديث لأخر إصدار لتشغيل البرنامج') {
            Updates.showUpdateDialog(context, canCancel: false);
          }
          if (snapshot.error.toString() !=
                  'Exception: Error Update User Data' ||
              User.instance.password != null)
            return Loading(
              error: true,
              message: snapshot.error.toString(),
              showVersionInfo: true,
            );
        }
        return StreamBuilder<User>(
          initialData: User.instance,
          stream: User.instance.stream,
          builder: (context, userSnapshot) {
            final user = userSnapshot.data!;
            if (user.uid == null) {
              return const LoginScreen();
            } else if (user.approved && user.password != null) {
              return const AuthScreen(nextWidget: Root());
            } else {
              return const UserRegistration();
            }
          },
        );
      },
    );
  }

  Future configureFirebaseMessaging() async {
    if (!Hive.box('Settings')
            .get('FCM_Token_Registered', defaultValue: false) &&
        auth.FirebaseAuth.instance.currentUser != null) {
      try {
        firestore.FirebaseFirestore.instance.settings = firestore.Settings(
          persistenceEnabled: true,
          sslEnabled: true,
          cacheSizeBytes: Hive.box('Settings')
              .get('cacheSize', defaultValue: 300 * 1024 * 1024),
        );
        // ignore: empty_catches
      } catch (e) {}
      try {
        final status = (await FirebaseMessaging.instance.requestPermission())
            .authorizationStatus;
        if (status != AuthorizationStatus.denied &&
            status != AuthorizationStatus.notDetermined) {
          await FirebaseFunctions.instance
              .httpsCallable('registerFCMToken')
              .call({'token': await FirebaseMessaging.instance.getToken()});
          await Hive.box('Settings').put('FCM_Token_Registered', true);
        }
      } catch (err, stack) {
        await Sentry.captureException(err,
            stackTrace: stack,
            withScope: (scope) =>
                scope.setTag('LasErrorIn', 'AppState.configureMessaging'));
      }
    }
    if (configureMessaging) {
      FirebaseMessaging.onBackgroundMessage(onBackgroundMessage);
      FirebaseMessaging.onMessage.listen(onForegroundMessage);
      FirebaseMessaging.onMessageOpenedApp.listen((m) async {
        await showPendingMessage();
      });
      configureMessaging = false;
    }
  }

  Future<void> loadApp(BuildContext context) async {
    try {
      await RemoteConfig.instance.setDefaults(<String, dynamic>{
        'LatestVersion': (await PackageInfo.fromPlatform()).version,
        'LoadApp': 'false',
        'DownloadLink':
            'https://github.com/Andrew-Bekhiet/MeetingHelper/releases/download/v' +
                (await PackageInfo.fromPlatform()).version +
                '/MeetingHelper.apk',
      });
      await RemoteConfig.instance.setConfigSettings(RemoteConfigSettings(
          fetchTimeout: const Duration(seconds: 30),
          minimumFetchInterval: const Duration(minutes: 2)));
      await RemoteConfig.instance.fetchAndActivate();
      // ignore: empty_catches
    } catch (err) {}

    if (!kIsWeb && RemoteConfig.instance.getString('LoadApp') == 'false') {
      await Updates.showUpdateDialog(context, canCancel: false);
      throw Exception('يجب التحديث لأخر إصدار لتشغيل البرنامج');
    } else {
      if (User.instance.uid != null) {
        await configureFirebaseMessaging();
        Sentry.configureScope((scope) => scope.user = SentryUser(
            id: User.instance.uid,
            email: User.instance.email,
            extras: User.instance.getUpdateMap()));
        if (!await User.instance.userDataUpToDate()) {
          throw Exception('Error Update User Data');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<ThemeData>(
      initialData: context.read<ThemeNotifier>().theme,
      stream: context.read<ThemeNotifier>().stream,
      builder: (context, theme) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          scaffoldMessengerKey: scaffoldMessenger,
          navigatorKey: navigator,
          title: 'خدمة مدارس الأحد',
          initialRoute: '/',
          routes: {
            '/': buildLoadAppWidget,
            'Login': (context) => const LoginScreen(),
            'Data/EditClass': (context) => EditClass(
                class$: ModalRoute.of(context)!.settings.arguments as Class?),
            'Data/EditService': (context) => EditService(
                service:
                    ModalRoute.of(context)!.settings.arguments as Service?),
            'Data/EditPerson': (context) {
              if (ModalRoute.of(context)?.settings.arguments == null)
                return EditPerson(person: Person());
              else if (ModalRoute.of(context)!.settings.arguments is Person)
                return EditPerson(
                    person:
                        ModalRoute.of(context)!.settings.arguments! as Person);
              else if (ModalRoute.of(context)!.settings.arguments is JsonRef) {
                final parent =
                    ModalRoute.of(context)!.settings.arguments! as JsonRef;
                final Person person = Person();

                if (parent.parent.id == 'Classes') {
                  person.classId = parent;
                } else if (parent.parent.id == 'Services') {
                  person.services.add(parent);
                }

                return EditPerson(person: person);
              }
              throw ArgumentError.value(
                  ModalRoute.of(context)!.settings.arguments,
                  'modal route args',
                  'passed arg is neither Person nor JsonRef');
            },
            'EditInvitation': (context) => EditInvitation(
                invitation:
                    ModalRoute.of(context)?.settings.arguments as Invitation? ??
                        Invitation.empty()),
            'Day': (context) {
              if (ModalRoute.of(context)?.settings.arguments != null)
                return Day(
                    record: ModalRoute.of(context)!.settings.arguments!
                        as HistoryDay);
              else
                return Day(record: HistoryDay());
            },
            'ServantsDay': (context) {
              if (ModalRoute.of(context)?.settings.arguments != null)
                return Day(
                    record: ModalRoute.of(context)!.settings.arguments!
                        as ServantsHistoryDay);
              else
                return Day(record: ServantsHistoryDay());
            },
            'Trash': (context) => const Trash(),
            'History': (context) => const History(iServantsHistory: false),
            'ExportOps': (context) => const Exports(),
            'ServantsHistory': (context) =>
                const History(iServantsHistory: true),
            'MyAccount': (context) => const MyAccount(),
            'Notifications': (context) => const NotificationsPage(),
            'ClassInfo': (context) => ClassInfo(
                class$: ModalRoute.of(context)!.settings.arguments! as Class),
            'ServiceInfo': (context) => ServiceInfo(
                service:
                    ModalRoute.of(context)!.settings.arguments! as Service),
            'PersonInfo': (context) => PersonInfo(
                person: ModalRoute.of(context)!.settings.arguments! as Person,
                converter: ModalRoute.of(context)!.settings.arguments is User
                    ? User.fromDoc
                    : Person.fromDoc,
                showMotherAndFatherPhones:
                    ModalRoute.of(context)!.settings.arguments is! User),
            'UserInfo': (context) => UserInfo(
                user: ModalRoute.of(context)!.settings.arguments! as User),
            'InvitationInfo': (context) => InvitationInfo(
                invitation:
                    ModalRoute.of(context)!.settings.arguments! as Invitation),
            'Update': (context) => const Update(),
            'Search': (context) => const SearchQuery(),
            'DataMap': (context) => const DataMap(),
            'Settings': (context) => const s.Settings(),
            'Settings/Churches': (context) => const ChurchesPage(),
            /*MiniList(
                parent: FirebaseFirestore.instance.collection('Churches'),
                pageTitle: 'الكنائس',
              ),*/
            'Settings/Fathers': (context) => const FathersPage(),
            /* MiniList(
                parent: FirebaseFirestore.instance.collection('Fathers'),
                pageTitle: 'الأباء الكهنة',
              ) */
            'Settings/StudyYears': (context) =>
                const StudyYearsPage() /* MiniList(
                parent: FirebaseFirestore.instance.collection('StudyYears'),
                pageTitle: 'السنوات الدراسية',
              ) */
            ,
            'Settings/Schools': (context) => MiniModelList<School>(
                  transformer: School.fromDoc,
                  collection: firestore.FirebaseFirestore.instance
                      .collection('Schools'),
                  title: 'المدارس',
                ),
            'Settings/Colleges': (context) => MiniModelList<College>(
                  transformer: College.fromDoc,
                  collection: firestore.FirebaseFirestore.instance
                      .collection('Colleges'),
                  title: 'الكليات',
                ),
            'UpdateUserDataError': (context) => const UpdateUserDataErrorPage(),
            'ManageUsers': (context) => const UsersPage(),
            'Invitations': (context) => const InvitationsPage(),
            'ActivityAnalysis': (context) => ActivityAnalysis(
                  parents: ModalRoute.of(context)?.settings.arguments
                      as List<DataObject>?,
                ),
            'Analytics': (context) {
              if (ModalRoute.of(context)!.settings.arguments is Person)
                return PersonAnalyticsPage(
                    person:
                        ModalRoute.of(context)!.settings.arguments! as Person);
              else if (ModalRoute.of(context)!.settings.arguments is DataObject)
                return AnalyticsPage(parents: [
                  ModalRoute.of(context)!.settings.arguments! as DataObject
                ]);
              else if (ModalRoute.of(context)!.settings.arguments is HistoryDay)
                return AnalyticsPage(
                    day: ModalRoute.of(context)!.settings.arguments!
                        as HistoryDay);
              else {
                final Json args =
                    ModalRoute.of(context)!.settings.arguments! as Json;
                return AnalyticsPage(
                  historyColection: args['HistoryCollection'] ?? 'History',
                  parents: args['Classes'],
                  day: args['Day'],
                  range: args['Range'],
                );
              }
            },
          },
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('ar', 'EG'),
          ],
          themeMode: theme.data!.brightness == Brightness.dark
              ? ThemeMode.dark
              : ThemeMode.light,
          locale: const Locale('ar', 'EG'),
          theme: theme.data,
          darkTheme: theme.data,
        );
      },
    );
  }
}
