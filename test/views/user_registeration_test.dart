import 'package:churchdata_core/churchdata_core.dart';
import 'package:churchdata_core_mocks/churchdata_core.dart';
import 'package:churchdata_core_mocks/churchdata_core.mocks.dart';
import 'package:churchdata_core_mocks/fakes/fake_functions_repo.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:meetinghelper/models.dart';
import 'package:meetinghelper/repositories/auth_repository.dart';
import 'package:meetinghelper/utils/encryption_keys.dart';
import 'package:meetinghelper/utils/globals.dart';
import 'package:meetinghelper/views/user_registeration.dart';
import 'package:mockito/mockito.dart';

import '../utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group(
    'UserRegisteration View tests: ',
    () {
      setUp(() async {
        registerFirebaseMocks();
        setUpMHPlatformChannels();
        await initFakeCore();

        when(
          (GetIt.I<FirebaseMessaging>() as MockFirebaseMessaging).isSupported(),
        ).thenAnswer((_) async => false);
      });

      tearDown(GetIt.I.reset);

      group(
        'User not approved: ',
        () {
          setUp(
            () async {
              await mockMHUser(
                user: User(
                  ref: GetIt.I<DatabaseRepository>()
                      .collection('UsersData')
                      .doc('personId'),
                  uid: 'uid',
                  name: 'displayName',
                  email: 'email',
                  password: 'password',
                  permissions: MHPermissionsSet(),
                  lastTanawol: DateTime.now(),
                  lastConfession: DateTime.now(),
                ),
              );

              when(GetIt.I<MHAuthRepository>().signOut())
                  .thenAnswer((_) async {});
            },
          );

          testWidgets(
            'Structure',
            (tester) async {
              await tester
                  .pumpWidget(wrapWithMaterialApp(const UserRegistration()));

              expect(
                find.widgetWithText(AppBar, 'في انتظار الموافقة'),
                findsOneWidget,
              );
              expect(find.byTooltip('تسجيل الخروج'), findsOneWidget);
              expect(find.byType(TextFormField), findsOneWidget);
              expect(
                find.widgetWithText(ElevatedButton, 'تفعيل الحساب باللينك'),
                findsOneWidget,
              );
            },
          );

          testWidgets(
            'Registering with link',
            (tester) async {
              final fakeHttpsCallable = FakeHttpsCallable();
              final fakeHttpsCallableResult = FakeHttpsCallableResult();
              when(
                (GetIt.I<FirebaseFunctions>() as MockFirebaseFunctions)
                    .httpsCallable('registerWithLink'),
              ).thenReturn(fakeHttpsCallable);
              when(fakeHttpsCallable.call(captureAny))
                  .thenAnswer((_) async => fakeHttpsCallableResult);
              when(fakeHttpsCallableResult.data).thenReturn(true);

              await tester.pumpWidget(
                wrapWithMaterialApp(
                  const UserRegistration(),
                  navigatorKey: navigator,
                ),
              );

              await tester.enterText(
                find.byType(TextFormField),
                'https://meetinghelper.page.link/XpPh3EjCxn8C8EC67',
              );
              await tester.tap(find.text('تفعيل الحساب باللينك'));
              await tester.pump();

              expect(find.text('جار تفعيل الحساب...'), findsOneWidget);

              await tester.pumpAndSettle();
              await tester.pumpAndSettle();

              expect(find.text('جار تفعيل الحساب...'), findsNothing);
              verify(
                fakeHttpsCallable.call(
                  argThat(
                    predicate<Map>(
                      (a) =>
                          a['link'] ==
                          'https://meetinghelper.page.link/XpPh3EjCxn8C8EC67',
                    ),
                  ),
                ),
              );
            },
          );

          testWidgets(
            'SignOut',
            (tester) async {
              await tester
                  .pumpWidget(wrapWithMaterialApp(const UserRegistration()));

              await tester.tap(find.byTooltip('تسجيل الخروج'));
              await tester.idle();

              verify(MHAuthRepository.I.signOut());
            },
          );
        },
      );

      group(
        'User approved: ',
        () {
          setUp(
            () async {
              await mockMHUser(
                user: User(
                  ref: GetIt.I<DatabaseRepository>()
                      .collection('UsersData')
                      .doc('personId'),
                  uid: 'uid',
                  name: 'displayName',
                  email: 'email',
                  password: 'password',
                  permissions: MHPermissionsSet(approved: true),
                ),
              );

              when(GetIt.I<MHAuthRepository>().signOut())
                  .thenAnswer((_) async {});
            },
          );

          testWidgets(
            'Structure',
            (tester) async {
              await tester.pumpWidget(
                wrapWithMaterialApp(
                  DefaultAssetBundle(
                    bundle: TestAssetBundle(),
                    child: const UserRegistration(),
                  ),
                ),
              );

              expect(
                find.widgetWithText(AppBar, 'تسجيل حساب جديد'),
                findsOneWidget,
              );
              expect(find.byTooltip('تسجيل الخروج'), findsOneWidget);
              expect(
                find.widgetWithText(TextFormField, 'اسم المستخدم'),
                findsOneWidget,
              );
              expect(
                find.widgetWithText(TextFormField, 'كلمة السر'),
                findsOneWidget,
              );
              expect(
                find.widgetWithText(TextFormField, 'تأكيد كلمة السر'),
                findsOneWidget,
              );
              expect(
                find.widgetWithText(GestureDetector, 'تاريخ أخر تناول'),
                findsOneWidget,
              );
              expect(
                find.widgetWithText(GestureDetector, 'تاريخ أخر اعتراف'),
                findsOneWidget,
              );
              expect(
                find.widgetWithText(ElevatedButton, 'انشاء حساب جديد'),
                findsOneWidget,
              );
            },
          );

          testWidgets(
            'Invalid input',
            (tester) async {
              await tester.binding.setSurfaceSize(const Size(1024, 1365 * 3));
              await tester.pumpWidget(
                wrapWithMaterialApp(
                  DefaultAssetBundle(
                    bundle: TestAssetBundle(),
                    child: const UserRegistration(),
                  ),
                ),
              );

              await tester.enterText(
                find.widgetWithText(TextFormField, 'اسم المستخدم'),
                '',
              );

              await tester.pump();

              await tester.enterText(
                find.widgetWithText(TextFormField, 'كلمة السر'),
                'ss',
              );
              await tester
                  .tap(find.widgetWithText(ElevatedButton, 'انشاء حساب جديد'));

              await tester.pumpAndSettle();

              expect(find.text('لا يمكن أن يكون اسمك فارغًا'), findsOneWidget);
              expect(
                find.text('يرجى كتابة كلمة سر قوية تتكون من أكثر '
                    'من 10 أحرف وتحتوي على رموز وأرقام'),
                findsOneWidget,
              );
              expect(find.text('كلمتا السر غير متطابقتين'), findsOneWidget);
              expect(find.text('يجب تحديد تاريخ أخر تناول'), findsOneWidget);
              expect(find.text('يجب تحديد تاريخ أخر اعتراف'), findsOneWidget);
            },
          );

          testWidgets(
            'New account creation',
            (tester) async {
              await tester.binding.setSurfaceSize(const Size(1024, 1365 * 3));
              await tester.pumpWidget(
                wrapWithMaterialApp(
                  DefaultAssetBundle(
                    bundle: TestAssetBundle(),
                    child: const UserRegistration(),
                  ),
                  scaffoldMessengerKey: scaffoldMessenger,
                ),
              );

              final fakeHttpsCallable = FakeHttpsCallable();
              final fakeHttpsCallableResult = FakeHttpsCallableResult();
              when(
                (GetIt.I<FirebaseFunctions>() as MockFirebaseFunctions)
                    .httpsCallable('registerAccount'),
              ).thenReturn(fakeHttpsCallable);
              when(fakeHttpsCallable.call(captureAny))
                  .thenAnswer((_) async => fakeHttpsCallableResult);
              when(fakeHttpsCallableResult.data).thenReturn(true);
              when(GetIt.I<FirebaseMessaging>().getToken())
                  .thenAnswer((_) async => 'token');

              const username = 'user';
              const password = 'password22*?=';
              final lastTanawol = DateTime.now().millisecondsSinceEpoch - 23;
              final lastConfession = DateTime.now().millisecondsSinceEpoch + 23;

              await tester.enterText(
                find.widgetWithText(TextFormField, 'اسم المستخدم'),
                username,
              );

              await tester.enterText(
                find.widgetWithText(TextFormField, 'كلمة السر'),
                password,
              );
              await tester.enterText(
                find.widgetWithText(TextFormField, 'تأكيد كلمة السر'),
                password,
              );

              (tester.state(find.byType(UserRegistration)) as dynamic)
                  .lastTanawol = lastTanawol;
              (tester.state(find.byType(UserRegistration)) as dynamic)
                  .lastConfession = lastConfession;

              await tester
                  .tap(find.widgetWithText(ElevatedButton, 'انشاء حساب جديد'));

              await tester.pumpAndSettle();

              verify(
                fakeHttpsCallable.call(
                  argThat(
                    predicate<Map>(
                      (a) =>
                          a['name'] == username &&
                          a['password'] ==
                              Encryption.encryptPassword(password) &&
                          a['lastConfession'] == lastConfession &&
                          a['lastTanawol'] == lastTanawol &&
                          a['fcmToken'] == 'token',
                    ),
                  ),
                ),
              );
            },
          );

          testWidgets(
            'SignOut',
            (tester) async {
              await tester
                  .pumpWidget(wrapWithMaterialApp(const UserRegistration()));

              await tester.tap(find.byTooltip('تسجيل الخروج'));
              await tester.idle();

              verify(MHAuthRepository.I.signOut());
            },
          );
        },
      );
    },
  );
}

class TestAssetBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async {
    if (key == 'AssetManifest.json' || key == 'AssetManifest.bin') {
      return const StandardMessageCodec().encodeMessage(
        <Object?, Object?>{},
      )!;
    }

    return rootBundle.load(key);
  }
}
