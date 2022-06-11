import 'package:churchdata_core/churchdata_core.dart';
import 'package:churchdata_core_mocks/churchdata_core.mocks.dart';
import 'package:churchdata_core_mocks/fakes/fake_cache_repo.dart';
import 'package:churchdata_core_mocks/fakes/fake_firebase_auth.dart';
import 'package:churchdata_core_mocks/fakes/fake_notifications_repo.dart';
import 'package:churchdata_core_mocks/fakes/mock_user.dart';
import 'package:churchdata_core_mocks/models/basic_data_object.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_dynamic_links/firebase_dynamic_links.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:meetinghelper/models/data/user.dart' as u;
import 'package:meetinghelper/repositories.dart';
import 'package:meetinghelper/services.dart';
import 'package:mock_data/mock_data.dart';
import 'package:mockito/mockito.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:rxdart/rxdart.dart';

import 'fakes/fake_secure_storage.dart';
import 'views/root_test.mocks.dart';

void setUpMHPlatformChannels() {
  FlutterSecureStoragePlatform.instance = FakeFlutterSecureStoragePlatform();

  TestDefaultBinaryMessengerBinding.instance!.defaultBinaryMessenger
      .setMockMessageHandler(
    'dev.fluttercommunity.plus/android_alarm_manager',
    (_) async => const JSONMessageCodec().encodeMessage([true]),
  );

  PackageInfo.setMockInitialValues(
    appName: 'meetinghelper',
    packageName: 'meetinghelper',
    version: '8.0.0',
    buildNumber: '1',
    buildSignature: 'buildSignature',
  );

  when(
    (GetIt.I<FirebaseRemoteConfig>() as MockFirebaseRemoteConfig)
        .setDefaults(any),
  ).thenAnswer((_) async {});
  when(
    (GetIt.I<FirebaseRemoteConfig>() as MockFirebaseRemoteConfig)
        .setConfigSettings(any),
  ).thenAnswer((_) async {});
  when(
    (GetIt.I<FirebaseRemoteConfig>() as MockFirebaseRemoteConfig)
        .fetchAndActivate(),
  ).thenAnswer((_) async => true);
  when(
    (GetIt.I<FirebaseRemoteConfig>() as MockFirebaseRemoteConfig)
        .getString('LoadApp'),
  ).thenReturn('true');

  when((GetIt.I<FirebaseDynamicLinks>() as MockFirebaseDynamicLinks).onLink)
      .thenAnswer(
    (_) async* {},
  );
  when((GetIt.I<FirebaseDynamicLinks>() as MockFirebaseDynamicLinks)
          .getInitialLink())
      .thenAnswer((_) async => null);
  when(GetIt.I<FirebaseMessaging>().getInitialMessage())
      .thenAnswer((_) async => null);
  when((GetIt.I<FirebaseMessaging>() as MockFirebaseMessaging).isSupported())
      .thenReturn(false);
}

Future<void> initFakeCore() async {
  await initCore(
    sentryDSN: 'sentryDSN',
    overrides: {
      LoggingService: () {
        final instance = FakeLoggingService();

        GetIt.I.registerSingleton<FakeLoggingService>(
          instance,
          signalsReady: true,
        );

        return instance;
      },
      CacheRepository: () {
        final instance = FakeCacheRepo();

        GetIt.I.registerSingleton<FakeCacheRepo>(
          instance,
          signalsReady: true,
          dispose: (a) => a.dispose(),
        );
        GetIt.I.signalReady(instance);

        return instance;
      },
      // StorageRepository:FakeCacheRepo.new,
      // LauncherService: Object.new,
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
      FlutterLocalNotificationsPlugin: FakeFlutterLocalNotificationsPlugin.new,
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
    },
  );
}

Future<MyMockUser> signInMockUser(
    {MyMockUser? user, Map<String, dynamic>? claims}) async {
  final mockUser = user ??
      MyMockUser(
        uid: 'uid',
        displayName: 'User Name',
        email: 'email@email.com',
        phoneNumber: '+201234567890',
      );

  when(mockUser.getIdTokenResult()).thenAnswer(
    (_) async => IdTokenResult(
      {
        'claims': claims ??
            {
              'approved': false,
            },
      },
    ),
  );
  await (GetIt.I<FirebaseAuth>() as MockFirebaseAuth).signInUser(mockUser);
  return mockUser;
}

Future<void> mockMHUser({u.User? user}) async {
  GetIt.I.pushNewScope();
  GetIt.I.registerSingleton<MHAuthRepository>(MockMHAuthRepository());
  GetIt.I.registerSingleton<AuthRepository>(MHAuthRepository.I);

  when(GetIt.I<MHAuthRepository>().isSignedIn).thenReturn(user != null);
  when(GetIt.I<MHAuthRepository>().currentUser).thenReturn(user);
  when(GetIt.I<MHAuthRepository>().userStream).thenAnswer(
    (_) => BehaviorSubject.seeded(
      user,
    ),
  );
}

MaterialApp wrapWithMaterialApp(
  Widget home, {
  Map<String, Widget Function(BuildContext)>? routes,
  GlobalKey<NavigatorState>? navigatorKey,
  GlobalKey<ScaffoldMessengerState>? scaffoldMessengerKey,
}) {
  return MaterialApp(
    home: home,
    navigatorKey: navigatorKey,
    scaffoldMessengerKey: scaffoldMessengerKey,
    routes: routes ?? {},
  );
}

Future<List<BasicDataObject>> populateWithRandomPersons(JsonCollectionRef ref,
    [int count = 100]) async {
  final list = List.generate(
    count,
    (_) => BasicDataObject(
      ref: ref.doc(),
      name: mockName() + '-' + mockString(),
    ),
  );
  await Future.wait(
    list.map(
      (p) => p.set(),
    ),
  );
  return list;
}

class FakeLoggingService implements LoggingService {
  FakeLoggingService() {
    Future.wait([]).then((_) => GetIt.I.signalReady(GetIt.I<LoggingService>()));
  }
  @override
  Future<void> log(String msg) async {}

  @override
  Future<void> reportError(Exception error,
      {Map<String, dynamic>? data,
      Map<String, dynamic>? extras,
      StackTrace? stackTrace}) async {}

  @override
  Future<void> reportFlutterError(FlutterErrorDetails flutterError,
      {Map<String, dynamic>? data, Map<String, dynamic>? extras}) async {}
}
