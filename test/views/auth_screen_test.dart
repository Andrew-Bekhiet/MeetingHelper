import 'package:churchdata_core/churchdata_core.dart';
import 'package:churchdata_core_mocks/churchdata_core.dart';
import 'package:churchdata_core_mocks/churchdata_core.mocks.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:local_auth_platform_interface/local_auth_platform_interface.dart';
import 'package:meetinghelper/repositories/auth_repository.dart';
import 'package:meetinghelper/utils/encryption_keys.dart';
import 'package:meetinghelper/views/auth_screen.dart';
import 'package:mockito/mockito.dart';

import '../utils.dart';

void main() {
  group(
    'AuthScreen tests:',
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
        'With Biometrics:',
        () {
          setUp(
            () async {
              LocalAuthPlatform.instance = FakeLocalAuthPlatform(true);
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

            expect(
              find.widgetWithText(TextFormField, 'كلمة السر'),
              findsOneWidget,
            );

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
              LocalAuthPlatform.instance = FakeLocalAuthPlatform(false);
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

              expect(
                find.widgetWithText(TextFormField, 'كلمة السر'),
                findsOneWidget,
              );

              await tester.scrollUntilVisible(
                find.text('تسجيل الدخول'),
                70,
                scrollable: find.byType(Scrollable).first,
              );

              expect(find.text('تسجيل الدخول'), findsOneWidget);

              expect(
                find.text('إعادة المحاولة عن طريق بصمة الاصبع/الوجه'),
                findsNothing,
              );
            },
          );

          group(
            'Authentication with password',
            () {
              const _passwordString = '1%Pass word*)';

              setUp(() async {
                GetIt.I.pushNewScope();
                await initFakeCore();

                await signInMockUser(
                  claims: {
                    'password': Encryption.encryptPassword(_passwordString),
                  },
                );
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

class FakeLocalAuthPlatform extends LocalAuthPlatform {
  final bool authSupported;

  FakeLocalAuthPlatform(this.authSupported);

  @override
  Future<bool> authenticate({
    required String localizedReason,
    required Iterable<AuthMessages> authMessages,
    AuthenticationOptions options = const AuthenticationOptions(),
  }) async =>
      true;

  @override
  Future<bool> deviceSupportsBiometrics() async {
    return authSupported;
  }
}
