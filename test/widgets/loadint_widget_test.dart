import 'package:churchdata_core_mocks/churchdata_core.dart';
import 'package:churchdata_core_mocks/churchdata_core.mocks.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:meetinghelper/exceptions.dart';
import 'package:meetinghelper/widgets/loading_widget.dart';
import 'package:mockito/mockito.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../utils.dart';

void main() {
  group(
    'Loading Widget tests ->',
    () {
      setUp(() async {
        registerFirebaseMocks();
        await setUpMHPlatformChannels();
      });

      tearDown(() async {
        await GetIt.I.reset();
      });

      testWidgets(
        'Normal',
        (tester) async {
          await tester.pumpWidget(wrapWithMaterialApp(const Loading()));

          expect(find.byType(Image), findsOneWidget);
          expect(find.byType(CircularProgressIndicator), findsOneWidget);
          expect(find.text('جار التحميل...'), findsOneWidget);
        },
      );
      testWidgets(
        'With UnsupportedVersion exception',
        (tester) async {
          when(
            (GetIt.I<FirebaseRemoteConfig>() as MockFirebaseRemoteConfig)
                .getString('LatestVersion'),
          ).thenReturn('9.0.0');

          final version = (await PackageInfo.fromPlatform()).version;

          await tester.pumpWidget(
            wrapWithMaterialApp(
              Loading(
                exception: UnsupportedVersionException(
                  version: version,
                ),
              ),
            ),
          );

          expect(find.byType(Image), findsOneWidget);
          expect(find.byType(CircularProgressIndicator), findsNothing);
          expect(find.text('جار التحميل...'), findsNothing);
          expect(find.text('لا يمكن تحميل البرنامج في الوقت الحالي'),
              findsOneWidget);
          expect(find.text('اضغط لمزيد من المعلومات'), findsOneWidget);

          await tester.tap(find.text('اضغط لمزيد من المعلومات'));
          await tester.pumpAndSettle();

          expect(find.textContaining('يرجى تحديث البرنامج'), findsOneWidget);
        },
      );
      testWidgets(
        'With UpdateUserData exception',
        (tester) async {
          await initFakeCore();

          await tester.pumpWidget(
            wrapWithMaterialApp(
              Loading(
                exception: UpdateUserDataException(
                  lastConfession: null,
                  lastTanawol: null,
                ),
              ),
            ),
          );

          expect(find.byType(Image), findsOneWidget);
          expect(find.byType(CircularProgressIndicator), findsNothing);
          expect(find.text('جار التحميل...'), findsNothing);
          expect(find.text('لا يمكن تحميل البرنامج في الوقت الحالي'),
              findsOneWidget);
          expect(find.text('اضغط لمزيد من المعلومات'), findsOneWidget);

          await tester.tap(find.text('اضغط لمزيد من المعلومات'));
          await tester.pumpAndSettle();

          expect(find.text('تحديث بيانات التناول والاعتراف'), findsOneWidget);
        },
      );
      testWidgets(
        'With unknown exception',
        (tester) async {
          await tester.pumpWidget(wrapWithMaterialApp(Loading(
            exception: Exception('Some exception'),
          )));

          expect(find.byType(Image), findsOneWidget);
          expect(find.byType(CircularProgressIndicator), findsNothing);
          expect(find.text('جار التحميل...'), findsNothing);
          expect(find.text('لا يمكن تحميل البرنامج في الوقت الحالي'),
              findsOneWidget);
          expect(find.text('اضغط لمزيد من المعلومات'), findsOneWidget);

          await tester.tap(find.text('اضغط لمزيد من المعلومات'));
          await tester.pumpAndSettle();

          expect(find.textContaining('Some exception'), findsOneWidget);
        },
      );
    },
  );
}
