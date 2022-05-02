import 'package:churchdata_core/churchdata_core.dart';
import 'package:churchdata_core_mocks/churchdata_core.dart';
import 'package:churchdata_core_mocks/churchdata_core.mocks.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:local_auth/local_auth.dart';
import 'package:meetinghelper/repositories/auth_repository.dart';
import 'package:meetinghelper/utils/encryption_keys.dart';
import 'package:meetinghelper/views/auth_screen.dart';
import 'package:mockito/mockito.dart';
import 'package:platform/platform.dart';

import '../utils.dart';

void main() {
  group(
    'AuthScreen tests:',
    () {
      setUp(() async {
        registerFirebaseMocks();
        setUpMHPlatformChannels();
        await initFakeCore();

        when((GetIt.I<FirebaseMessaging>() as MockFirebaseMessaging)
                .isSupported())
            .thenReturn(false);
      });

      tearDown(() async {
        await GetIt.I.reset();
      });

      group(
        'With Biometrics:',
        () {
          setUp(
            () async {
              setMockPathProviderPlatform(
                FakePlatform(
                  operatingSystem: Platform.android,
                ),
              );

              TestDefaultBinaryMessengerBinding.instance!.defaultBinaryMessenger
                  .setMockMessageHandler(
                'plugins.flutter.io/local_auth',
                (c) async {
                  final methodName =
                      const StandardMethodCodec().decodeMethodCall(c).method;
                  if (methodName == 'getAvailableBiometrics') {
                    return const StandardMethodCodec()
                        .encodeSuccessEnvelope(['fingerprint']);
                  } else if (methodName == 'authenticate') {
                    return const StandardMethodCodec()
                        .encodeSuccessEnvelope(true);
                  }
                  return null;
                },
              );
            },
          );

          testWidgets('Structure', (tester) async {
            await tester.binding.setSurfaceSize(const Size(1080 * 3, 2400 * 3));

            await tester.pumpWidget(
              wrapWithMaterialApp(
                AuthScreen(
                  onSuccess: () {},
                ),
              ),
            );
            await tester.pump();

            expect(find.byType(BackButton), findsNothing);
            expect(find.text('برجاء التحقق للمتابعة'), findsOneWidget);

            await tester.scrollUntilVisible(
              find.byType(
                Image,
                skipOffstage: false,
              ),
              70,
              scrollable: find.byType(Scrollable).first,
            );

            expect(
              find.byType(
                Image,
                skipOffstage: false,
              ),
              findsOneWidget,
            );

            await tester.scrollUntilVisible(
              find.text(
                'كلمة السر',
                skipOffstage: false,
              ),
              70,
              scrollable: find.byType(Scrollable).first,
            );

            expect(find.widgetWithText(TextFormField, 'كلمة السر'),
                findsOneWidget);

            await tester.scrollUntilVisible(
              find.text(
                'تسجيل الدخول',
                skipOffstage: false,
              ),
              70,
              scrollable: find.byType(Scrollable).first,
            );

            expect(find.text('تسجيل الدخول'), findsOneWidget);

            await tester.scrollUntilVisible(
              find.text(
                'إعادة المحاولة عن طريق بصمة الاصبع/الوجه',
                skipOffstage: false,
              ),
              70,
              scrollable: find.byType(Scrollable).first,
            );

            expect(
              find.text('إعادة المحاولة عن طريق بصمة الاصبع/الوجه'),
              findsOneWidget,
            );
          });

          testWidgets('Authentication with Biometrics', (tester) async {
            await tester.binding.setSurfaceSize(const Size(1080 * 3, 2400 * 3));

            bool succeeded = false;

            await tester.pumpWidget(
              wrapWithMaterialApp(
                AuthScreen(
                  onSuccess: () => succeeded = true,
                ),
              ),
            );
            await tester.pumpAndSettle();

            expect(succeeded, isTrue);
          });
        },
      );

      group(
        'Without Biometrics:',
        () {
          setUp(
            () async {
              setMockPathProviderPlatform(
                FakePlatform(
                  operatingSystem: Platform.android,
                ),
              );

              TestDefaultBinaryMessengerBinding.instance!.defaultBinaryMessenger
                  .setMockMessageHandler(
                'plugins.flutter.io/local_auth',
                (c) async {
                  final methodName =
                      const StandardMethodCodec().decodeMethodCall(c).method;
                  if (methodName == 'getAvailableBiometrics') {
                    return const StandardMethodCodec()
                        .encodeSuccessEnvelope([]);
                  }
                  return null;
                },
              );
            },
          );

          testWidgets(
            'Strucure',
            (tester) async {
              await tester.pumpWidget(
                wrapWithMaterialApp(
                  AuthScreen(
                    onSuccess: () {},
                  ),
                ),
              );
              await tester.pump();

              expect(find.byType(BackButton), findsNothing);
              expect(find.text('برجاء التحقق للمتابعة'), findsOneWidget);

              await tester.scrollUntilVisible(
                find.byType(
                  Image,
                  skipOffstage: false,
                ),
                70,
                scrollable: find.byType(Scrollable).first,
              );

              expect(
                find.byType(
                  Image,
                  skipOffstage: false,
                ),
                findsOneWidget,
              );

              await tester.scrollUntilVisible(
                find.widgetWithText(TextFormField, 'كلمة السر'),
                70,
                scrollable: find.byType(Scrollable).first,
              );

              expect(find.widgetWithText(TextFormField, 'كلمة السر'),
                  findsOneWidget);

              await tester.scrollUntilVisible(
                find.text('تسجيل الدخول'),
                70,
                scrollable: find.byType(Scrollable).first,
              );

              expect(find.text('تسجيل الدخول'), findsOneWidget);

              expect(find.text('إعادة المحاولة عن طريق بصمة الاصبع/الوجه'),
                  findsNothing);
            },
          );

          group(
            'Authentication with password',
            () {
              const _passwordString = '1%Pass word*)';

              setUp(() async {
                GetIt.I.pushNewScope();
                await initFakeCore();

                await signInMockUser(claims: {
                  'password': Encryption.encryptPassword(_passwordString),
                });
                await MHAuthRepository.I.userStream.nextNonNull;
              });

              testWidgets('Entering password', (tester) async {
                await tester.binding
                    .setSurfaceSize(const Size(1080 * 3, 2400 * 3));

                bool succeeded = false;

                await tester.pumpWidget(
                  wrapWithMaterialApp(
                    AuthScreen(
                      onSuccess: () => succeeded = true,
                    ),
                  ),
                );
                await tester.pumpAndSettle();

                await tester.enterText(
                  find.widgetWithText(TextFormField, 'كلمة السر'),
                  _passwordString,
                );

                await tester.tap(find.text('تسجيل الدخول'));

                await tester.pump();
                await tester.pump();

                expect(succeeded, isTrue);
              });
              group('Errors', () {
                testWidgets('Empty Password', (tester) async {
                  await tester.binding
                      .setSurfaceSize(const Size(1080 * 3, 2400 * 3));

                  bool succeeded = false;

                  await tester.pumpWidget(
                    wrapWithMaterialApp(
                      AuthScreen(
                        onSuccess: () => succeeded = true,
                      ),
                    ),
                  );
                  await tester.pump();

                  await tester.enterText(
                    find.widgetWithText(TextFormField, 'كلمة السر'),
                    '',
                  );
                  await tester.tap(find.text('تسجيل الدخول'));
                  await tester.pump();

                  expect(find.text('كلمة سر فارغة!'), findsOneWidget);
                  expect(succeeded, isFalse);
                });
                testWidgets('Wrong Password', (tester) async {
                  await tester.binding
                      .setSurfaceSize(const Size(1080 * 3, 2400 * 3));

                  bool succeeded = false;

                  await tester.pumpWidget(
                    wrapWithMaterialApp(
                      AuthScreen(
                        onSuccess: () => succeeded = true,
                      ),
                    ),
                  );
                  await tester.pumpAndSettle();

                  await tester.enterText(
                    find.widgetWithText(TextFormField, 'كلمة السر'),
                    'Wrong',
                  );
                  await tester.tap(find.text('تسجيل الدخول'));
                  await tester.pumpAndSettle();

                  expect(find.text('كلمة سر خاطئة!'), findsOneWidget);
                  expect(succeeded, isFalse);
                });
              });
            },
          );
        },
      );
    },
  );
}
