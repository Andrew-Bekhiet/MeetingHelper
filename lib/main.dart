import 'dart:async';

import 'package:async/async.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:churchdata_core/churchdata_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart' as firestore
    show Settings;
import 'package:cloud_firestore/cloud_firestore.dart' show FirebaseFirestore;
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth show FirebaseAuth;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get_it/get_it.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:meetinghelper/exceptions/update_user_data_exception.dart';
import 'package:meetinghelper/models.dart';
import 'package:meetinghelper/repositories.dart';
import 'package:meetinghelper/secrets.dart';
import 'package:meetinghelper/services.dart';
import 'package:meetinghelper/utils/globals.dart';
import 'package:meetinghelper/utils/helpers.dart';
import 'package:meetinghelper/views.dart';
import 'package:meetinghelper/widgets.dart';
import 'package:meetinghelper/widgets/update_widget.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase/supabase.dart' hide User;
import 'package:timeago/timeago.dart';

import 'exceptions/unsupported_version_exception.dart';

Completer<void> _initialization = Completer();
bool _initializing = false;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await initMeetingHelper();

  runApp(
    const MeetingHelperApp(),
  );
}

Future<void> initMeetingHelper() async {
  if (_initializing) return _initialization.future;
  _initializing = true;

  await initFirebase();

  await initCore(
    sentryDSN: sentryDSN,
    overrides: {
      AuthRepository: () {
        final instance = MHAuthRepository();

        GetIt.I.registerSingleton<MHAuthRepository>(
          instance,
          signalsReady: true,
          dispose: (a) => a.dispose(),
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
          dispose: (n) => n.dispose(),
        );

        return instance;
      },
      FunctionsService: () {
        final instance = MHFunctionsService();

        GetIt.I.registerSingleton<MHFunctionsService>(instance);

        return instance;
      },
      ThemingService: () {
        final instance = MHThemingService();

        GetIt.I.registerSingleton<MHThemingService>(
          instance,
          dispose: (t) => t.dispose(),
        );

        return instance;
      },
      ShareService: () {
        final instance = MHShareService();

        GetIt.I.registerSingleton<MHShareService>(instance);

        return instance;
      },
      UpdatesService: UpdatesService.new,
    },
  );

  final mhDataObjectTapHandler = MHViewableObjectService(navigator);
  GetIt.I
      .registerSingleton<DefaultViewableObjectService>(mhDataObjectTapHandler);
  GetIt.I.registerSingleton<MHViewableObjectService>(mhDataObjectTapHandler);

  if (kDebugMode) {
    final devBox = await Hive.openBox('Dev');

    GetIt.I<FirebaseFirestore>().settings = firestore.Settings(
      persistenceEnabled: true,
      sslEnabled: devBox.get('kEmulatorsHost') == null ||
          devBox.get('kEmulatorsHost') == '',
      cacheSizeBytes: GetIt.I<CacheRepository>()
          .box('Settings')
          .get('cacheSize', defaultValue: 300 * 1024 * 1024),
    );
  } else {
    GetIt.I<FirebaseFirestore>().settings = firestore.Settings(
      persistenceEnabled: true,
      sslEnabled: true,
      cacheSizeBytes: GetIt.I<CacheRepository>()
          .box('Settings')
          .get('cacheSize', defaultValue: 300 * 1024 * 1024),
    );
  }

  GetIt.I.registerSingleton<SupabaseClient>(
    SupabaseClient(supabaseURL, supabaseKey),
  );

  return _initialization.complete();
}

Future<void> initFirebase() async {
  String? kEmulatorsHost;

  if (kDebugMode) {
    await Hive.initFlutter();

    final devBox = await Hive.openBox('Dev');
    kEmulatorsHost = devBox.get('kEmulatorsHost');
  }

  try {
    //Firebase initialization
    if (kEmulatorsHost != null) {
      await Firebase.initializeApp();

      await auth.FirebaseAuth.instance.useAuthEmulator(kEmulatorsHost, 9099);
      // await FirebaseStorage.instance.useStorageEmulator(kEmulatorsHost, 9199);
      FirebaseFirestore.instance.useFirestoreEmulator(kEmulatorsHost, 8080);
      FirebaseFunctions.instance.useFunctionsEmulator(kEmulatorsHost, 5001);
      FirebaseDatabase.instance.useDatabaseEmulator(kEmulatorsHost, 9000);
    } else {
      await Firebase.initializeApp();
    }
  } catch (e) {
    await Firebase.initializeApp();
  }
  await FirebaseAppCheck.instance.activate();
  FirebaseDatabase.instance.setPersistenceEnabled(false);

  registerFirebaseDependencies();
}

class MeetingHelperApp extends StatefulWidget {
  const MeetingHelperApp({super.key});

  @override
  _MeetingHelperAppState createState() => _MeetingHelperAppState();
}

class _MeetingHelperAppState extends State<MeetingHelperApp> {
  final AsyncMemoizer<void> _latestVersionChecker = AsyncMemoizer();
  bool errorDialogShown = false;

  @override
  void initState() {
    super.initState();
    setLocaleMessages('ar', ArMessages());
  }

  Future<void> checkLatestVersion(BuildContext context) async {
    final appVersion = (await PackageInfo.fromPlatform()).version;

    if (!kIsWeb &&
        (kReleaseMode ||
            GetIt.I<UpdatesService>().runtimeType != UpdatesService) &&
        await GetIt.I<UpdatesService>().currentIsDeprecated()) {
      throw UnsupportedVersionException(version: appVersion);
    }
  }

  Widget buildLoadAppWidget(BuildContext context) {
    return FutureBuilder<void>(
      future: _latestVersionChecker.runOnce(() => checkLatestVersion(context)),
      builder: (context, versionCheck) {
        if (versionCheck.connectionState != ConnectionState.done) {
          return const Loading();
        }

        return StreamBuilder<User?>(
          initialData:
              GetIt.I<MHAuthRepository>().currentUser?.userDataUpToDate() ??
                      false
                  ? GetIt.I<MHAuthRepository>().currentUser
                  : null,
          stream: GetIt.I<MHAuthRepository>().userStream.map(
                (event) => GetIt.I<MHAuthRepository>().isSignedIn &&
                        User.instance.password != null &&
                        !User.instance.userDataUpToDate()
                    ? throw UpdateUserDataException(
                        lastTanawol: User.instance.lastTanawol,
                        lastConfession: User.instance.lastConfession,
                      )
                    : event,
              ),
          builder: (context, userSnapshot) {
            final user = userSnapshot.data;

            if (userSnapshot.connectionState == ConnectionState.waiting &&
                user == null) return const Loading();

            if (!errorDialogShown) {
              if (userSnapshot.error is UpdateUserDataException) {
                WidgetsBinding.instance.addPostFrameCallback((_) async {
                  await showErrorUpdateDataDialog(context: context);
                  errorDialogShown = false;
                });
                errorDialogShown = true;
              } else if (versionCheck.error is UnsupportedVersionException) {
                WidgetsBinding.instance.addPostFrameCallback((_) async {
                  await GetIt.I<UpdatesService>().showUpdateDialog(
                    context,
                    image: const CachedNetworkImageProvider(
                      'https://github.com/Andrew-Bekhiet/MeetingHelper'
                      '/blob/master/android/app/src/main/ic_launcher-playstore.png?raw=true',
                    ),
                  );
                  errorDialogShown = false;
                });
                errorDialogShown = true;
              }
            }

            if (versionCheck.error is UnsupportedVersionException ||
                (userSnapshot.error is UpdateUserDataException)) {
              return Loading(
                exception: versionCheck.error ?? userSnapshot.error,
              );
            } else if (user == null) {
              return const LoginScreen();
            } else if (user.permissions.approved && user.password != null) {
              return AuthScreen(
                onSuccess: () => Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (context) => const Root(),
                  ),
                ),
              );
            } else {
              return const UserRegistration();
            }
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<ThemeData>(
      initialData: GetIt.I<MHThemingService>().theme,
      stream: GetIt.I<MHThemingService>().stream,
      builder: (context, theme) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          scaffoldMessengerKey: scaffoldMessenger,
          navigatorKey: navigator,
          navigatorObservers: [
            GetIt.I<LoggingService>().navigatorObserver,
          ],
          title: 'خدمة مدارس الأحد',
          initialRoute: '/',
          routes: {
            '/': buildLoadAppWidget,
            'Login': (context) => const LoginScreen(),
            'Data/EditClass': (context) => EditClass(
                  class$: ModalRoute.of(context)!.settings.arguments as Class?,
                ),
            'Data/EditService': (context) => EditService(
                  service:
                      ModalRoute.of(context)!.settings.arguments as Service?,
                ),
            'Data/EditPerson': (context) {
              if (ModalRoute.of(context)?.settings.arguments == null) {
                return EditPerson(person: Person.empty());
              } else if (ModalRoute.of(context)!.settings.arguments is Person) {
                return EditPerson(
                  person: ModalRoute.of(context)!.settings.arguments! as Person,
                );
              } else if (ModalRoute.of(context)!.settings.arguments
                  is JsonRef) {
                final parent =
                    ModalRoute.of(context)!.settings.arguments! as JsonRef;
                Person person = Person.empty();

                if (parent.parent.id == 'Classes') {
                  person = person.copyWith.classId(parent);
                } else if (parent.parent.id == 'Services') {
                  person = person.copyWith.services([parent]);
                }

                return EditPerson(person: person);
              }
              throw ArgumentError.value(
                ModalRoute.of(context)!.settings.arguments,
                'modal route args',
                'passed arg is neither Person nor JsonRef',
              );
            },
            'EditInvitation': (context) => EditInvitation(
                  invitation: ModalRoute.of(context)?.settings.arguments
                          as Invitation? ??
                      Invitation.empty(),
                ),
            'Day': (context) {
              if (ModalRoute.of(context)?.settings.arguments != null) {
                return Day(
                  record:
                      ModalRoute.of(context)!.settings.arguments! as HistoryDay,
                );
              } else {
                return Day(
                  record: HistoryDay(),
                );
              }
            },
            'ServantsDay': (context) {
              if (ModalRoute.of(context)?.settings.arguments != null) {
                return Day(
                  record: ModalRoute.of(context)!.settings.arguments!
                      as ServantsHistoryDay,
                );
              } else {
                return Day(
                  record: ServantsHistoryDay(),
                );
              }
            },
            'Trash': (context) => const Trash(),
            'History': (context) => const History(isServantsHistory: false),
            'ExportOps': (context) => const Exports(),
            'ServantsHistory': (context) =>
                const History(isServantsHistory: true),
            'MyAccount': (context) => const MyAccount(),
            'Notifications': (context) => const NotificationsPage(),
            'ClassInfo': (context) => ClassInfo(
                  class$: ModalRoute.of(context)!.settings.arguments! as Class,
                ),
            'ServiceInfo': (context) => ServiceInfo(
                  service:
                      ModalRoute.of(context)!.settings.arguments! as Service,
                ),
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
                  user: ModalRoute.of(context)!.settings.arguments!
                      as UserWithPerson,
                ),
            'InvitationInfo': (context) => InvitationInfo(
                  invitation:
                      ModalRoute.of(context)!.settings.arguments! as Invitation,
                ),
            'Update': (context) => const Update(),
            'Search': (context) => const SearchQuery(),
            'SearchQuery': (context) => SearchQuery(
                  query:
                      ModalRoute.of(context)!.settings.arguments as QueryInfo?,
                ),
            'DataMap': (context) => const MHMapView(),
            'Settings': (context) => const Settings(),
            'Settings/Churches': (context) => MiniModelList<Church>(
                  title: 'الكنائس',
                  transformer: Church.fromDoc,
                  add: (context) => churchTap(
                    context,
                    Church.createNew(),
                    true,
                    canDelete: false,
                  ),
                  modify: churchTap,
                  collection: GetIt.I<MHDatabaseRepo>().collection('Churches'),
                ),
            'Settings/Fathers': (context) => MiniModelList<Father>(
                  title: 'الأباء الكهنة',
                  transformer: Father.fromDoc,
                  add: (context) => fatherTap(
                    context,
                    Father.createNew(),
                    true,
                    canDelete: false,
                  ),
                  modify: fatherTap,
                  collection: GetIt.I<MHDatabaseRepo>().collection('Fathers'),
                ),
            'Settings/StudyYears': (context) => MiniModelList<StudyYear>(
                  title: 'السنوات الدراسية',
                  transformer: StudyYear.fromDoc,
                  add: (context) => studyYearTap(
                    context,
                    StudyYear.createNew(),
                    true,
                    canDelete: false,
                  ),
                  modify: studyYearTap,
                  completer: (q) => q.orderBy('Grade'),
                  collection:
                      GetIt.I<MHDatabaseRepo>().collection('StudyYears'),
                ),
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
              if (ModalRoute.of(context)!.settings.arguments is Person) {
                return PersonAnalyticsPage(
                  person: ModalRoute.of(context)!.settings.arguments! as Person,
                );
              } else if (ModalRoute.of(context)!.settings.arguments
                  is DataObject) {
                return AnalyticsPage(
                  parents: [
                    ModalRoute.of(context)!.settings.arguments! as DataObject
                  ],
                );
              } else if (ModalRoute.of(context)!.settings.arguments
                  is HistoryDayBase) {
                return AnalyticsPage(
                  day: ModalRoute.of(context)!.settings.arguments!
                      as HistoryDayBase,
                );
              } else {
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
