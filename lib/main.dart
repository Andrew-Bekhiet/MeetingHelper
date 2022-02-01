import 'dart:async';

import 'package:async/async.dart';
import 'package:churchdata_core/churchdata_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart' as firestore
    show Settings;
import 'package:cloud_firestore/cloud_firestore.dart' show FirebaseFirestore;
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth show FirebaseAuth;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get_it/get_it.dart';
import 'package:meetinghelper/admin.dart';
import 'package:meetinghelper/models.dart';
import 'package:meetinghelper/repositories.dart';
import 'package:meetinghelper/secrets.dart';
import 'package:meetinghelper/services.dart';
import 'package:meetinghelper/updates.dart';
import 'package:meetinghelper/utils/globals.dart';
import 'package:meetinghelper/utils/helpers.dart';
import 'package:meetinghelper/views.dart';
import 'package:meetinghelper/widgets.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:timeago/timeago.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await initMeetingHelper();

  runApp(
    const App(),
  );
}

Future<void> initMeetingHelper() async {
  await initFirebase();

  await initCore(
    sentryDSN: sentryDSN,
    overrides: {
      AuthRepository: () {
        final instance = MHAuthRepository();

        GetIt.I.registerSingleton<MHAuthRepository>(
          instance,
          signalsReady: true,
        );

        return instance;
      },
      DatabaseRepository: () {
        final instance = MHDatabaseRepo();

        GetIt.I.registerSingleton<MHDatabaseRepo>(instance);

        return instance;
      },
      NotificationsService: () {
        final instance = MHNotificationsService();

        GetIt.I.registerSingleton<MHNotificationsService>(
          instance,
          signalsReady: true,
        );

        return instance;
      },
    },
  );

  final shareService = MHShareService();
  GetIt.I.registerSingleton<ShareService>(shareService);
  GetIt.I.registerSingleton<MHShareService>(shareService);

  final mhDataObjectTapHandler = MHDataObjectTapHandler(navigator);
  GetIt.I
      .registerSingleton<DefaultDataObjectTapHandler>(mhDataObjectTapHandler);
  GetIt.I.registerSingleton<MHDataObjectTapHandler>(mhDataObjectTapHandler);

  final themeNotifier = MHThemeNotifier();
  GetIt.I.registerSingleton<ThemeNotifier>(themeNotifier);
  GetIt.I.registerSingleton<MHThemeNotifier>(themeNotifier);
}

Future<void> initFirebase() async {
  try {
    await dotenv.load();

    final String? kEmulatorsHost = dotenv.env['kEmulatorsHost'];
    //Firebase initialization
    if (kDebugMode &&
        kEmulatorsHost != null &&
        dotenv.env['kUseFirebaseEmulators']?.toString() == 'true') {
      await Firebase.initializeApp();

      await auth.FirebaseAuth.instance.useAuthEmulator(kEmulatorsHost, 9099);
      await FirebaseStorage.instance.useStorageEmulator(kEmulatorsHost, 9199);
      FirebaseFirestore.instance.useFirestoreEmulator(kEmulatorsHost, 8080);
      FirebaseFunctions.instance.useFunctionsEmulator(kEmulatorsHost, 5001);
      FirebaseDatabase.instance.useDatabaseEmulator(kEmulatorsHost, 9000);
    } else {
      await Firebase.initializeApp();
    }
  } catch (e) {
    await Firebase.initializeApp();
  }

  registerFirebaseDependencies();
}

class App extends StatefulWidget {
  const App({Key? key}) : super(key: key);

  @override
  AppState createState() => AppState();
}

class AppState extends State<App> {
  final AsyncMemoizer<void> _appLoader = AsyncMemoizer();

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
                  'Exception: Error Update User Data' &&
              User.instance.password != null)
            return Loading(
              error: true,
              message: snapshot.error.toString(),
              showVersionInfo: true,
            );
        }

        return StreamBuilder<User?>(
          initialData: GetIt.I<MHAuthRepository>().currentUser,
          stream: GetIt.I<MHAuthRepository>().userStream,
          builder: (context, userSnapshot) {
            final user = userSnapshot.data;

            if (user == null) {
              return const LoginScreen();
            } else if (user.permissions.approved && user.password != null) {
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
    if (!GetIt.I<CacheRepository>()
            .box('Settings')
            .get('FCM_Token_Registered', defaultValue: false) &&
        GetIt.I<auth.FirebaseAuth>().currentUser != null) {
      try {
        GetIt.I<FirebaseFirestore>().settings = firestore.Settings(
          persistenceEnabled: true,
          sslEnabled: true,
          cacheSizeBytes: GetIt.I<CacheRepository>()
              .box('Settings')
              .get('cacheSize', defaultValue: 300 * 1024 * 1024),
        );
        // ignore: empty_catches
      } catch (e) {}
      try {
        final status = (await GetIt.I<FirebaseMessaging>().requestPermission())
            .authorizationStatus;
        if (status != AuthorizationStatus.denied &&
            status != AuthorizationStatus.notDetermined) {
          await GetIt.I<FunctionsService>()
              .httpsCallable('registerFCMToken')
              .call({'token': await GetIt.I<FirebaseMessaging>().getToken()});
          await GetIt.I<CacheRepository>()
              .box('Settings')
              .put('FCM_Token_Registered', true);
        }
      } catch (err, stack) {
        await GetIt.I<LoggingService>().reportError(
          err as Exception,
          stackTrace: stack,
        );
      }
    }
  }

  Future<void> loadApp(BuildContext context) async {
    try {
      await GetIt.I<FirebaseRemoteConfig>().setDefaults(<String, dynamic>{
        'LatestVersion': (await PackageInfo.fromPlatform()).version,
        'LoadApp': 'false',
        'DownloadLink':
            'https://github.com/Andrew-Bekhiet/MeetingHelper/releases/download/v' +
                (await PackageInfo.fromPlatform()).version +
                '/MeetingHelper.apk',
      });
      await GetIt.I<FirebaseRemoteConfig>().setConfigSettings(
        RemoteConfigSettings(
            fetchTimeout: const Duration(seconds: 30),
            minimumFetchInterval: const Duration(minutes: 2)),
      );

      await GetIt.I<FirebaseRemoteConfig>().fetchAndActivate();
      // ignore: empty_catches
    } catch (err) {}

    if (!kIsWeb &&
        GetIt.I<FirebaseRemoteConfig>().getString('LoadApp') == 'false') {
      await Updates.showUpdateDialog(context, canCancel: false);
      throw Exception('يجب التحديث لأخر إصدار لتشغيل البرنامج');
    } else {
      await configureFirebaseMessaging();

      if (GetIt.I<MHAuthRepository>().isSignedIn &&
          !User.instance.userDataUpToDate()) {
        throw Exception('Error Update User Data');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<ThemeData>(
      initialData: GetIt.I<ThemeNotifier>().theme,
      stream: GetIt.I<ThemeNotifier>().stream,
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
                return EditPerson(person: Person.empty());
              else if (ModalRoute.of(context)!.settings.arguments is Person)
                return EditPerson(
                    person:
                        ModalRoute.of(context)!.settings.arguments! as Person);
              else if (ModalRoute.of(context)!.settings.arguments is JsonRef) {
                final parent =
                    ModalRoute.of(context)!.settings.arguments! as JsonRef;
                final Person person = Person.empty();

                if (parent.parent.id == 'Classes') {
                  person.copyWith.classId(parent);
                } else if (parent.parent.id == 'Services') {
                  person.copyWith.services([parent]);
                }

                return EditPerson(person: person);
              }
              throw ArgumentError.value(
                  ModalRoute.of(context)!.settings.arguments,
                  'modal route args',
                  'passed arg is neither Person nor JsonRef');
            },
            'EditInvitation': (context) => EditInvitation(
                  invitation: ModalRoute.of(context)?.settings.arguments
                          as Invitation? ??
                      Invitation.empty(),
                ),
            'Day': (context) {
              if (ModalRoute.of(context)?.settings.arguments != null)
                return Day(
                    record: ModalRoute.of(context)!.settings.arguments!
                        as HistoryDay);
              else
                return Day(
                  record: HistoryDay(),
                );
            },
            'ServantsDay': (context) {
              if (ModalRoute.of(context)?.settings.arguments != null)
                return Day(
                    record: ModalRoute.of(context)!.settings.arguments!
                        as ServantsHistoryDay);
              else
                return Day(
                  record: ServantsHistoryDay(),
                );
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
                  person: ModalRoute.of(context)!.settings.arguments! is Person
                      ? ModalRoute.of(context)!.settings.arguments!
                      : (ModalRoute.of(context)!.settings.arguments!
                          as Json)['Person'],
                  showMotherAndFatherPhones: ModalRoute.of(context)!
                          .settings
                          .arguments is Map
                      ? ((ModalRoute.of(context)!.settings.arguments!
                              as Json)['showMotherAndFatherPhones'] ??
                          false)
                      : ModalRoute.of(context)!.settings.arguments is Person,
                ),
            'UserInfo': (context) => UserInfo(
                user: ModalRoute.of(context)!.settings.arguments! as User),
            'InvitationInfo': (context) => InvitationInfo(
                invitation:
                    ModalRoute.of(context)!.settings.arguments! as Invitation),
            'Update': (context) => const Update(),
            'Search': (context) => const SearchQuery(),
            'DataMap': (context) => const DataMap(),
            'Settings': (context) => const Settings(),
            'Settings/Churches': (context) => const ChurchesPage(),
            /*MiniList(
                parent: GetIt.I<MHDatabaseRepo>().collection('Churches'),
                pageTitle: 'الكنائس',
              ),*/
            'Settings/Fathers': (context) => const FathersPage(),
            /* MiniList(
                parent: GetIt.I<MHDatabaseRepo>().collection('Fathers'),
                pageTitle: 'الأباء الكهنة',
              ) */
            'Settings/StudyYears': (context) =>
                const StudyYearsPage() /* MiniList(
                parent: GetIt.I<MHDatabaseRepo>().collection('StudyYears'),
                pageTitle: 'السنوات الدراسية',
              ) */
            ,
            'Settings/Schools': (context) => MiniModelList<School>(
                  transformer: School.fromDoc,
                  collection: GetIt.I<MHDatabaseRepo>().collection('Schools'),
                  title: 'المدارس',
                ),
            'Settings/Colleges': (context) => MiniModelList<College>(
                  transformer: College.fromDoc,
                  collection: GetIt.I<MHDatabaseRepo>().collection('Colleges'),
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
