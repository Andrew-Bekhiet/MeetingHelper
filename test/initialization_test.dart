import 'package:churchdata_core/churchdata_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:meetinghelper/main.dart';
import 'package:meetinghelper/repositories.dart';
import 'package:meetinghelper/views.dart';
import 'package:meetinghelper/widgets.dart';
import 'package:mockito/mockito.dart';

import 'package:churchdata_core_mocks/churchdata_core.dart';
import 'package:churchdata_core_mocks/churchdata_core.mocks.dart';
import 'utils.dart';

void main() {
  group(
    'App main initialization -> ',
    () {
      setUp(() async {
        registerFirebaseMocks();
        await setUpMHPlatformChannels();
        await initFakeCore();

        when((GetIt.I<FirebaseMessaging>() as MockFirebaseMessaging)
                .isSupported())
            .thenReturn(false);

        TestDefaultBinaryMessengerBinding.instance!.defaultBinaryMessenger
            .setMockMessageHandler('plugins.flutter.io/local_auth', (c) async {
          if (const StandardMethodCodec().decodeMethodCall(c).method ==
              'getAvailableBiometrics') {
            return const StandardMethodCodec().encodeSuccessEnvelope([]);
          }
          return null;
        });
      });

      tearDown(() async {
        await GetIt.I.reset();
      });

      group(
        'Normal ->',
        () {
          testWidgets(
            'No signed in user',
            (tester) async {
              await tester.pumpWidget(const MeetingHelperApp());
              await tester.pumpAndSettle();

              expect(find.byType(UserRegistration), findsNothing);
              expect(find.byType(AuthScreen), findsNothing);
              expect(find.byType(LoginScreen), findsOneWidget);
              expect(find.byType(Loading), findsNothing);
              expect(find.byType(Dialog), findsNothing);
            },
          );

          testWidgets(
            'With unapproved user',
            (tester) async {
              //Initiating with new scope because async operations
              //in tests don't work well with instances in setUp
              GetIt.I.pushNewScope();
              await initFakeCore();

              await signInMockUser();

              await tester.pumpWidget(const MeetingHelperApp());
              await tester.pumpAndSettle();

              expect(find.byType(UserRegistration), findsOneWidget);
              expect(find.byType(AuthScreen), findsNothing);
              expect(find.byType(LoginScreen), findsNothing);
              expect(find.byType(Loading), findsNothing);
              expect(find.byType(Dialog), findsNothing);
            },
          );

          testWidgets(
            'With approved user',
            (tester) async {
              //Initiating with new scope because async operations
              //in tests don't work well with instances in setUp
              GetIt.I.pushNewScope();
              await initFakeCore();

              await PersonBase(
                ref: MHDatabaseRepo.I.collection('UsersData').doc('personId'),
                name: '',
                lastTanawol: DateTime.now(),
                lastConfession: DateTime.now(),
              ).set();

              await signInMockUser(claims: {
                'personId': 'personId',
                'approved': true,
                'password': 'password',
              });

              await tester.pumpWidget(const MeetingHelperApp());
              await tester.pumpAndSettle();

              expect(find.byType(UserRegistration), findsNothing);
              expect(find.byType(AuthScreen), findsOneWidget);
              expect(find.byType(LoginScreen), findsNothing);
              expect(find.byType(Loading), findsNothing);
              expect(find.byType(Dialog), findsNothing);
            },
          );
        },
      );
      group(
        'Errors ->',
        () {
          testWidgets(
            'Outdated lastTanawol and lastConfession',
            (tester) async {
              //Initiating with new scope because async operations
              //in tests don't work well with instances in setUp
              GetIt.I.pushNewScope();
              await initFakeCore();

              await PersonBase(
                ref: MHDatabaseRepo.I.collection('UsersData').doc('personId'),
                name: '',
                lastTanawol: DateTime.now().subtract(const Duration(days: 61)),
                lastConfession:
                    DateTime.now().subtract(const Duration(days: 61)),
              ).set();

              await signInMockUser(claims: {
                'personId': 'personId',
                'approved': true,
                'password': 'password',
              });

              await tester.pumpWidget(const MeetingHelperApp());
              await tester.pumpAndSettle();

              expect(find.byType(UserRegistration), findsNothing);
              expect(find.byType(AuthScreen), findsNothing);
              expect(find.byType(LoginScreen), findsNothing);
              expect(find.byType(Loading, skipOffstage: false), findsOneWidget);
              expect(find.byType(Dialog), findsOneWidget);

              expect(
                find.text('تحديث بيانات التناول والاعتراف'),
                findsOneWidget,
              );

              await tester.tap(find.text('تحديث بيانات التناول والاعتراف'));
              await tester.pumpAndSettle();

              expect(find.byType(UpdateUserDataErrorPage), findsOneWidget);

              tester.firstState<NavigatorState>(find.byType(Navigator))
                ..pop()
                ..pop();
              await tester.pumpAndSettle();

              expect(find.text('لا يمكن تحميل البرنامج في الوقت الحالي'),
                  findsOneWidget);
              expect(find.text('اضغط لمزيد من المعلومات'), findsOneWidget);
            },
          );
          testWidgets(
            'Unsupported version',
            (tester) async {
              when(
                (GetIt.I<FirebaseRemoteConfig>() as MockFirebaseRemoteConfig)
                    .getString('LoadApp'),
              ).thenReturn('false');
              when(
                (GetIt.I<FirebaseRemoteConfig>() as MockFirebaseRemoteConfig)
                    .getString('LatestVersion'),
              ).thenReturn('9.0.0');

              await tester.pumpWidget(const MeetingHelperApp());
              await tester.pumpAndSettle();

              expect(find.byType(UserRegistration), findsNothing);
              expect(find.byType(AuthScreen), findsNothing);
              expect(find.byType(LoginScreen), findsNothing);
              expect(find.byType(Loading, skipOffstage: false), findsOneWidget);
              expect(find.byType(Dialog), findsOneWidget);

              expect(
                find.textContaining('يرجى تحديث البرنامج'),
                findsOneWidget,
              );
            },
          );
        },
      );
    },
  );
}
