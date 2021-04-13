import 'dart:async';

import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart' as firestore;
import 'package:cloud_functions/cloud_functions.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:feature_discovery/feature_discovery.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart'
    hide Day, Person;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:meetinghelper/admin.dart';
import 'package:meetinghelper/views/day.dart';
import 'package:meetinghelper/views/edit_page/edit_invitation.dart';
import 'package:meetinghelper/views/exports.dart';
import 'package:meetinghelper/views/invitations_page.dart';
import 'package:meetinghelper/views/trash.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart';

import 'models/history_record.dart';
import 'models/hive_persistence_provider.dart';
import 'models/invitation.dart';
import 'models/models.dart';
import 'models/theme_notifier.dart';
import 'models/user.dart';
import 'views/analytics/analytics_page.dart';
import 'views/auth_screen.dart';
import 'views/info_page/class_info.dart';
import 'views/data_map.dart';
import 'views/edit_page/edit_class.dart';
import 'views/edit_page/edit_person.dart';
import 'views/history.dart';
import 'views/info_page/invitation_info.dart';
import 'views/loading_widget.dart';
import 'views/login.dart';
import 'views/my_account.dart';
import 'views/notifications_page.dart';
import 'views/info_page/person_info.dart';
import 'views/root.dart';
import 'views/search_query.dart';
import 'views/settings.dart' as s;
import 'views/update_user_data.dart';
import 'views/info_page/user_info.dart';
import 'views/user_registeration.dart';
import 'updates.dart';
import 'utils/globals.dart';
import 'utils/helpers.dart';

void main() {
  FlutterError.onError = (flutterError) {
    FirebaseCrashlytics.instance.recordFlutterError(flutterError);
  };
  ErrorWidget.builder = (error) {
    if (kReleaseMode) {
      FirebaseCrashlytics.instance.recordFlutterError(error);
    }
    return Material(
      child: Container(
          color: Colors.white,
          child: Text('حدث خطأ:\n' + error.summary.toString())),
    );
  };

  WidgetsFlutterBinding.ensureInitialized();
  Firebase.initializeApp().then(
    (app) async {
      if (auth.FirebaseAuth.instance.currentUser != null &&
          (await Connectivity().checkConnectivity()) != ConnectivityResult.none)
        await User.instance.initialized;
      User user = User.instance;
      await _initConfigs();

      var settings = Hive.box('Settings');
      var primary = settings.get('PrimaryColorIndex', defaultValue: 13);
      var accent = primary;
      var darkTheme = settings.get('DarkTheme');
      runApp(
        MultiProvider(
          providers: [
            StreamProvider<User>.value(value: user.stream, initialData: user),
            ChangeNotifierProvider<ThemeNotifier>(
              create: (_) => ThemeNotifier(
                ThemeData(
                  floatingActionButtonTheme: FloatingActionButtonThemeData(
                      backgroundColor: primaries[primary ?? 13]),
                  visualDensity: VisualDensity.adaptivePlatformDensity,
                  outlinedButtonTheme: OutlinedButtonThemeData(
                      style: OutlinedButton.styleFrom(
                          primary: primaries[primary ?? 13])),
                  textButtonTheme: TextButtonThemeData(
                      style: TextButton.styleFrom(
                          primary: primaries[primary ?? 13])),
                  elevatedButtonTheme: ElevatedButtonThemeData(
                      style: ElevatedButton.styleFrom(
                          primary: primaries[primary ?? 13])),
                  brightness: darkTheme != null
                      ? (darkTheme ? Brightness.dark : Brightness.light)
                      : WidgetsBinding.instance.window.platformBrightness,
                  accentColor: accents[accent ?? 13],
                  primaryColor: primaries[primary ?? 13],
                ),
              ),
            ),
          ],
          builder: (context, _) => App(),
        ),
      );
    },
  );
}

Future _initConfigs() async {
  //Hive initialization:
  await Hive.initFlutter();

  await Hive.openBox('Settings');
  await Hive.openBox<bool>('FeatureDiscovery');
  await Hive.openBox<Map>('NotificationsSettings');
  await Hive.openBox<String>('PhotosURLsCache');
  await Hive.openBox<Map>('Notifications');

  //Notifications:
  await AndroidAlarmManager.initialize();

  await FlutterLocalNotificationsPlugin().initialize(
      InitializationSettings(android: AndroidInitializationSettings('warning')),
      onSelectNotification: onNotificationClicked);
}

class App extends StatefulWidget {
  App({Key key}) : super(key: key);

  @override
  AppState createState() => AppState();
}

class AppState extends State<App> {
  StreamSubscription<ConnectivityResult> connection;
  StreamSubscription userTokenListener;

  bool configureMessaging = true;

  @override
  Widget build(BuildContext context) {
    return FeatureDiscovery.withProvider(
      persistenceProvider: HivePersistenceProvider(),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'خدمة مدارس الأحد',
        initialRoute: '/',
        routes: {
          '/': buildLoadAppWidget,
          'Login': (context) => LoginScreen(),
          'Data/EditClass': (context) =>
              EditClass(class$: ModalRoute.of(context).settings.arguments),
          'Data/EditPerson': (context) {
            if (ModalRoute.of(context).settings.arguments is Person)
              return EditPerson(
                  person: ModalRoute.of(context).settings.arguments);
            else {
              Person person = Person()
                ..classId = ModalRoute.of(context).settings.arguments;
              return EditPerson(person: person);
            }
          },
          'EditInvitation': (context) => EditInvitation(
              invitation: ModalRoute.of(context).settings.arguments ??
                  Invitation.empty()),
          'Day': (context) {
            if (ModalRoute.of(context).settings.arguments != null)
              return Day(record: ModalRoute.of(context).settings.arguments);
            else
              return Day(record: HistoryDay());
          },
          'ServantsDay': (context) {
            if (ModalRoute.of(context).settings.arguments != null)
              return Day(record: ModalRoute.of(context).settings.arguments);
            else
              return Day(record: ServantsHistoryDay());
          },
          'Trash': (context) => Trash(),
          'History': (context) => History(),
          'ExportOps': (context) => Exports(),
          'ServantsHistory': (context) => ServantsHistory(),
          'MyAccount': (context) => MyAccount(),
          'Notifications': (context) => NotificationsPage(),
          'ClassInfo': (context) =>
              ClassInfo(class$: ModalRoute.of(context).settings.arguments),
          'PersonInfo': (context) =>
              PersonInfo(person: ModalRoute.of(context).settings.arguments),
          'UserInfo': (context) => UserInfo(),
          'InvitationInfo': (context) => InvitationInfo(
              invitation: ModalRoute.of(context).settings.arguments),
          'Update': (context) => Update(),
          'Search': (context) => SearchQuery(),
          'DataMap': (context) => DataMap(),
          'Settings': (context) => s.Settings(),
          'Settings/Churches': (context) => ChurchesPage(),
          /*MiniList(
                parent: FirebaseFirestore.instance.collection('Churches'),
                pageTitle: 'الكنائس',
              ),*/
          'Settings/Fathers': (context) => FathersPage(),
          /* MiniList(
                parent: FirebaseFirestore.instance.collection('Fathers'),
                pageTitle: 'الأباء الكهنة',
              ) */
          'Settings/StudyYears': (context) =>
              StudyYearsPage() /* MiniList(
                parent: FirebaseFirestore.instance.collection('StudyYears'),
                pageTitle: 'السنوات الدراسية',
              ) */
          ,
          'Settings/Schools': (context) =>
              SchoolsPage() /* MiniList(
                parent: FirebaseFirestore.instance.collection('Schools'),
                pageTitle: 'المدارس',
              ) */
          ,
          'UpdateUserDataError': (context) => UpdateUserDataErrorPage(),
          'ManageUsers': (context) => UsersPage(),
          'Invitations': (context) => InvitationsPage(),
          'ActivityAnalysis': (context) => ActivityAnalysis(),
          'Analytics': (context) {
            if (ModalRoute.of(context).settings.arguments is Person)
              return PersonAnalyticsPage(
                  person: ModalRoute.of(context).settings.arguments);
            else if (ModalRoute.of(context).settings.arguments is Class)
              return AnalyticsPage(
                  classes: [ModalRoute.of(context).settings.arguments]);
            else if (ModalRoute.of(context).settings.arguments is HistoryDay)
              return AnalyticsPage(
                  day: ModalRoute.of(context).settings.arguments);
            else {
              final Map<String, dynamic> args =
                  ModalRoute.of(context).settings.arguments;
              return AnalyticsPage(
                historyColection: args['HistoryCollection'] ?? 'History',
                classes: args['Classes'],
                day: args['Day'],
                range: args['Range'],
              );
            }
          },
        },
        localizationsDelegates: [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: [
          Locale('ar', 'EG'),
        ],
        themeMode: context.watch<ThemeNotifier>().getTheme().brightness ==
                Brightness.dark
            ? ThemeMode.dark
            : ThemeMode.light,
        locale: Locale('ar', 'EG'),
        theme: context.watch<ThemeNotifier>().getTheme(),
        darkTheme: context.watch<ThemeNotifier>().getTheme(),
      ),
    );
  }

  Widget buildLoadAppWidget(BuildContext context) {
    return FutureBuilder<void>(
      future: loadApp(context),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done)
          return Loading(
            showVersionInfo: true,
          );

        if (snapshot.hasError && User.instance.password != null) {
          if (snapshot.error.toString() ==
              'Exception: Error Update User Data') {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              showErrorUpdateDataDialog(context: context);
            });
          }
          return Loading(
            error: true,
            message: snapshot.error.toString(),
            showVersionInfo: true,
          );
        }
        return Consumer<User>(
          builder: (context, user, child) {
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
        await FirebaseFunctions.instance
            .httpsCallable('registerFCMToken')
            .call({'token': await FirebaseMessaging.instance.getToken()});
        await Hive.box('Settings').put('FCM_Token_Registered', true);
      } catch (err, stkTrace) {
        await FirebaseCrashlytics.instance
            .setCustomKey('LastErrorIn', 'AppState.initState');
        await FirebaseCrashlytics.instance.recordError(err, stkTrace);
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

  @override
  void dispose() {
    connection?.cancel();
    userTokenListener?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    connection = Connectivity()
        .onConnectivityChanged
        .listen((ConnectivityResult result) {
      if (result == ConnectivityResult.mobile ||
          result == ConnectivityResult.wifi) {
        dataSource =
            firestore.GetOptions(source: firestore.Source.serverAndCache);
        if (mainScfld?.currentState?.mounted ?? false)
          ScaffoldMessenger.of(mainScfld.currentContext).showSnackBar(SnackBar(
            backgroundColor: Colors.greenAccent,
            content: Text('تم استرجاع الاتصال بالانترنت'),
          ));
      } else {
        dataSource = firestore.GetOptions(source: firestore.Source.cache);

        if (mainScfld?.currentState?.mounted ?? false)
          ScaffoldMessenger.of(mainScfld.currentContext).showSnackBar(SnackBar(
            backgroundColor: Colors.redAccent,
            content: Text('لا يوجد اتصال بالانترنت!'),
          ));
      }
    });
    setLocaleMessages('ar', ArMessages());
  }

  Future<void> loadApp(BuildContext context) async {
    var result = await UpdateHelper.setupRemoteConfig();
    if (result.getString('LoadApp') == 'false') {
      await Updates.showUpdateDialog(context, canCancel: false);
      throw Exception('يجب التحديث لأخر إصدار لتشغيل البرنامج');
    } else {
      if (User.instance.uid != null) {
        await configureFirebaseMessaging();
        await FirebaseCrashlytics.instance
            .setCustomKey('UID', User.instance.uid);
        if (!await User.instance.userDataUpToDate()) {
          throw Exception('Error Update User Data');
        }
      }
    }
  }
}
