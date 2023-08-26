import 'package:churchdata_core_mocks/churchdata_core.dart';
import 'package:churchdata_core_mocks/churchdata_core.mocks.dart';
import 'package:churchdata_core_mocks/fakes/fake_firebase_auth.dart';
import 'package:churchdata_core_mocks/fakes/mock_user.dart';
import 'package:firebase_auth/firebase_auth.dart' hide User;
import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:meetinghelper/repositories/auth_repository.dart';
import 'package:meetinghelper/views.dart';
import 'package:mockito/mockito.dart';

import '../utils.dart';

void main() {
  group(
    'Login View tests: ',
    () {
      setUp(() async {
        registerFirebaseMocks();
        setUpMHPlatformChannels();
        await initFakeCore();

        GetIt.I.unregister(
          instance: MHAuthRepository.I,
          disposingFunction: (_) {},
        );

        await mockMHUser();

        when(
          (GetIt.I<FirebaseMessaging>() as MockFirebaseMessaging).isSupported(),
        ).thenAnswer((_) async => false);
      });

      tearDown(GetIt.I.reset);

      testWidgets(
        'Structure',
        (tester) async {
          await tester.pumpWidget(wrapWithMaterialApp(const LoginScreen()));

          expect(
            find.image(const AssetImage('assets/Logo.png')),
            findsOneWidget,
          );
          expect(
            find.image(const AssetImage('assets/google_logo.png')),
            findsOneWidget,
          );
          expect(find.text('تسجيل الدخول بجوجل'), findsOneWidget);
          expect(find.textContaining('تسجيل الدخول'), findsNWidgets(2));
        },
      );

      testWidgets(
        'Login',
        (tester) async {
          final mockUser = MyMockUser(
            uid: 'uid',
            displayName: 'User Name',
            email: 'email@email.com',
            phoneNumber: '+201234567890',
          );

          when(mockUser.getIdTokenResult()).thenAnswer(
            (_) async => IdTokenResult(
              PigeonIdTokenResult(
                claims: {
                  'approved': false,
                },
              ),
            ),
          );
          (GetIt.I<FirebaseAuth>() as MockFirebaseAuth).userWhenSignIn =
              mockUser;

          await tester.pumpWidget(wrapWithMaterialApp(const LoginScreen()));
          await tester.tap(
            find.image(const AssetImage('assets/google_logo.png')),
          );

          expect(GetIt.I<FirebaseAuth>().currentUser, mockUser);
        },
      );
    },
  );
}
