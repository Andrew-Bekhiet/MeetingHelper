import 'package:churchdata_core_mocks/churchdata_core.dart';
import 'package:churchdata_core_mocks/churchdata_core.mocks.dart';
import 'package:churchdata_core_mocks/fakes/fake_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:meetinghelper/main.dart';
import 'package:meetinghelper/models.dart';
import 'package:meetinghelper/views.dart';
import 'package:meetinghelper/widgets.dart';
import 'package:mockito/mockito.dart';

import 'utils.dart';

void main() {
  group(
    'App main initialization:',
    () {
      final AppInitTestVariants appInitTestVariants = AppInitTestVariants();

      setUp(() async {
        registerFirebaseMocks();
        setUpMHPlatformChannels();
        await initFakeCore();

        when(
          (GetIt.I<FirebaseMessaging>() as MockFirebaseMessaging).isSupported(),
        ).thenAnswer((_) async => false);

        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMessageHandler('plugins.flutter.io/local_auth', (c) async {
          if (const StandardMethodCodec().decodeMethodCall(c).method ==
              'getAvailableBiometrics') {
            return const StandardMethodCodec().encodeSuccessEnvelope([]);
          }
          return null;
        });
      });

      tearDown(GetIt.I.reset);

      testWidgets(
        'Normal',
        (tester) async {
          await tester.pumpWidget(const MeetingHelperApp());
          await tester.pumpAndSettle();

          expect(
            find.byType(UserRegistration),
            appInitTestVariants.current != null &&
                    appInitTestVariants.current!.password == null
                ? findsOneWidget
                : findsNothing,
          );
          expect(
            find.byType(AuthScreen),
            appInitTestVariants.current != null &&
                    appInitTestVariants.current!.permissions.approved &&
                    appInitTestVariants.current!.password != null &&
                    appInitTestVariants.current!.userDataUpToDate()
                ? findsOneWidget
                : findsNothing,
          );
          expect(
            find.byType(LoginScreen),
            appInitTestVariants.current == null ? findsOneWidget : findsNothing,
          );
          expect(
            find.byType(
              Loading,
              skipOffstage: false,
            ),
            appInitTestVariants.current != null &&
                    !appInitTestVariants.current!.userDataUpToDate() &&
                    appInitTestVariants.current!.password != null
                ? findsOneWidget
                : findsNothing,
          );
          expect(
            find.byType(Dialog),
            appInitTestVariants.current != null &&
                    !appInitTestVariants.current!.userDataUpToDate() &&
                    appInitTestVariants.current!.password != null
                ? findsOneWidget
                : findsNothing,
          );

          if (appInitTestVariants.current != null &&
              !appInitTestVariants.current!.userDataUpToDate() &&
              appInitTestVariants.current!.password != null) {
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

            expect(
              find.text('لا يمكن تحميل البرنامج في الوقت الحالي'),
              findsOneWidget,
            );
            expect(find.text('اضغط لمزيد من المعلومات'), findsOneWidget);
          }
        },
        variant: appInitTestVariants,
      );

      testWidgets(
        'Unsupported version',
        (tester) async {
          await GetIt.I<FirebaseDatabase>()
              .ref()
              .child('config')
              .child('updates')
              .child('latest_version')
              .set('10.0.0');
          await GetIt.I<FirebaseDatabase>()
              .ref()
              .child('config')
              .child('updates')
              .child('deprecated_from')
              .set('9.0.0');

          await tester.pumpWidget(const MeetingHelperApp());
          await tester.pumpAndSettle();

          expect(find.byType(UserRegistration), findsNothing);
          expect(find.byType(AuthScreen), findsNothing);
          expect(find.byType(LoginScreen), findsNothing);
          expect(find.byType(Loading, skipOffstage: false), findsOneWidget);
          expect(find.byType(Dialog), findsOneWidget);

          expect(
            find.widgetWithText(OutlinedButton, 'تحديث'),
            findsOneWidget,
          );
        },
      );
    },
  );
}

class AppInitTestVariants extends TestVariant<User?> {
  User? _current;
  User? get current => _current;

  @override
  String describeValue(User? user) {
    if (user == null) {
      return 'No signed in user';
    } else if (!user.permissions.approved) {
      return 'Unapproved User';
    } else if (!user.userDataUpToDate()) {
      return 'Outdated lastTanawol and lastConfession';
    } else if (user.permissions.approved) {
      return 'Approved User';
    }
    throw UnsupportedError('Unknown variant');
  }

  @override
  Future<User?> setUp(User? value) async {
    await mockMHUser(
      user: value,
    );
    return _current = value;
  }

  @override
  Future<void> tearDown(
    User? value,
    covariant Object? memento,
  ) async {
    await GetIt.I.popScope();
  }

  @override
  Iterable<User?> get values sync* {
    yield null;

    User baseUser = User(
      ref: FakeFirebaseFirestore().collection('UsersData').doc('personId'),
      uid: 'uid',
      name: 'displayName',
      email: 'email',
      permissions: MHPermissionsSet.fromJson(
        const {
          'approved': false,
          'birthdayNotify': true,
          'changeHistory': true,
          'confessionsNotify': true,
          'export': true,
          'kodasNotify': true,
          'manageAllowedUsers': true,
          'manageDeleted': true,
          'manageUsers': true,
          'meetingNotify': true,
          'secretary': true,
          'recordHistory': true,
          'superAccess': true,
          'tanawolNotify': true,
          'visitNotify': true,
          'write': true,
          'personId': 'personId',
        },
      ),
      lastTanawol: DateTime.now().subtract(const Duration(days: 61)),
      lastConfession: DateTime.now().subtract(const Duration(days: 61)),
    );

    yield baseUser;
    yield baseUser = baseUser.copyWith(
      permissions: baseUser.permissions.copyWith(approved: true),
    );
    yield baseUser.copyWith(
      password: 'password',
      lastTanawol: DateTime.now(),
      lastConfession: DateTime.now(),
    );
  }
}
