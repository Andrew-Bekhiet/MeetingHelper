import 'package:churchdata_core/churchdata_core.dart';
import 'package:churchdata_core_mocks/churchdata_core.dart';
import 'package:device_info_plus_platform_interface/device_info_plus_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:meetinghelper/models.dart';
import 'package:meetinghelper/repositories/auth_repository.dart';
import 'package:meetinghelper/views/root.dart';
import 'package:meetinghelper/widgets.dart';
import 'package:mockito/annotations.dart';

import '../utils.dart';

@GenerateMocks([MHAuthRepository])
void main() {
  late GlobalKey<NavigatorState> navigatorKey;

  group(
    'Root View tests:',
    () {
      setUp(() async {
        registerFirebaseMocks();
        setUpMHPlatformChannels();
        await initFakeCore();

        DeviceInfoPlatform.instance = FakeDeviceInfo();

        navigatorKey = GlobalKey();

        GetIt.I.registerSingleton<MHViewableObjectTapHandler>(
            MHViewableObjectTapHandler(navigatorKey));

        HivePersistenceProvider.instance =
            AllCompletedHivePersistenceProvider();
      });

      tearDown(() async {
        await GetIt.I.reset();
      });

      final structureTestVariants = StructureTestVariants();
      testWidgets(
        'Structure',
        (tester) async {
          await tester.binding.setSurfaceSize(const Size(1080 * 3, 2400 * 3));

          await tester.pumpWidget(
            wrapWithMaterialApp(
              const Root(),
              navigatorKey: navigatorKey,
            ),
          );
          await tester.pumpAndSettle();

          final currentPermissions = structureTestVariants.current!;

          expect(find.byIcon(Icons.search), findsOneWidget);
          expect(find.byIcon(Icons.notifications), findsOneWidget);
          expect(
            find.widgetWithIcon(FloatingActionButton, Icons.group_add),
            findsNWidgets(currentPermissions.write ? 1 : 0),
          );

          expect(
            find.descendant(
                of: find.byType(TabBar), matching: find.text('الخدام')),
            findsNWidgets(currentPermissions.manageUsers ||
                    currentPermissions.manageAllowedUsers
                ? 1
                : 0),
          );
          expect(
            find.descendant(
                of: find.byType(TabBar), matching: find.text('الخدمات')),
            findsOneWidget,
          );
          expect(
            find.descendant(
                of: find.byType(TabBar), matching: find.text('المخدومين')),
            findsOneWidget,
          );

          if (currentPermissions.manageUsers ||
              currentPermissions.manageAllowedUsers) {
            await tester.tap(
              find.descendant(
                  of: find.byType(TabBar), matching: find.text('الخدام')),
            );
            await tester.pumpAndSettle();
            expect(
              find.byType(
                DataObjectListView<Class?, UserWithPerson>,
              ),
              findsOneWidget,
            );
            expect(find.text('0 خادم'), findsOneWidget);
          }

          await tester.tap(
            find.descendant(
                of: find.byType(TabBar), matching: find.text('الخدمات')),
          );
          await tester.pumpAndSettle();
          expect(find.byType(ServicesList), findsOneWidget);
          expect(find.text('0 خدمة'), findsOneWidget);

          await tester.tap(
            find.descendant(
                of: find.byType(TabBar), matching: find.text('المخدومين')),
          );
          await tester.pumpAndSettle();
          expect(
            find.byType(
              DataObjectListView<void, Person>,
            ),
            findsOneWidget,
          );
          expect(find.text('0 مخدوم'), findsOneWidget);

          //Drawer
          expect(find.byIcon(Icons.menu), findsOneWidget);
          await tester.tap(
            find.byIcon(Icons.menu),
          );
          await tester.pumpAndSettle();

          expect(find.widgetWithText(ListTile, 'حسابي'), findsOneWidget);
          expect(
            find.widgetWithText(ListTile, 'إدارة المستخدمين'),
            findsNWidgets(currentPermissions.manageUsers ||
                    currentPermissions.manageAllowedUsers
                ? 1
                : 0),
          );
          expect(
            find.widgetWithText(ListTile, 'كشف حضور المخدومين'),
            findsNWidgets(currentPermissions.recordHistory ? 1 : 0),
          );
          expect(
            find.widgetWithText(ListTile, 'كشف حضور الخدام'),
            findsNWidgets(currentPermissions.secretary ? 1 : 0),
          );
          expect(find.widgetWithText(ListTile, 'السجل'), findsOneWidget);
          expect(
            find.widgetWithText(ListTile, 'سجل الخدام'),
            findsNWidgets(currentPermissions.secretary ? 1 : 0),
          );
          expect(find.widgetWithText(ListTile, 'تحليل سجل المخدومين'),
              findsOneWidget);
          expect(
            find.widgetWithText(ListTile, 'تحليل بيانات سجل الخدام'),
            findsNWidgets(currentPermissions.secretary ? 1 : 0),
          );
          expect(
            find.widgetWithText(ListTile, 'تحليل بيانات الخدمة'),
            findsNWidgets(currentPermissions.manageUsers ||
                    currentPermissions.manageAllowedUsers
                ? 1
                : 0),
          );
          expect(find.widgetWithText(ListTile, 'بحث مفصل'), findsOneWidget);
          expect(
            find.widgetWithText(ListTile, 'سلة المحذوفات'),
            findsNWidgets(currentPermissions.manageDeleted ? 1 : 0),
          );
          expect(find.widgetWithText(ListTile, 'عرض خريطة الافتقاد'),
              findsOneWidget);
          expect(find.widgetWithText(ListTile, 'الإعدادات'), findsOneWidget);
          expect(find.widgetWithText(ListTile, 'استيراد من ملف اكسل'),
              findsOneWidget);
          expect(
            find.widgetWithText(ListTile, 'تصدير فصل إلى ملف اكسل'),
            findsNWidgets(currentPermissions.export ? 1 : 0),
          );
          expect(
            find.widgetWithText(ListTile, 'تصدير جميع البيانات'),
            findsNWidgets(currentPermissions.export ? 1 : 0),
          );
          expect(
            find.widgetWithText(ListTile, 'عمليات التصدير السابقة'),
            findsNWidgets(currentPermissions.export ? 1 : 0),
          );
          expect(
              find.widgetWithText(ListTile, 'تحديث البرنامج'), findsOneWidget);
          expect(find.widgetWithText(ListTile, 'حول البرنامج'), findsOneWidget);
          expect(find.widgetWithText(ListTile, 'تسجيل الخروج'), findsOneWidget);
        },
        variant: structureTestVariants,
      );
    },
  );
}

class AllCompletedHivePersistenceProvider implements HivePersistenceProvider {
  @override
  Future<void> clearStep(String featureId) async {}

  @override
  Future<void> clearSteps(Iterable<String> featuresIds) async {}

  @override
  Future<void> completeStep(String? featureId) async {}

  @override
  Set<String> completedSteps(Iterable<String?>? featuresIds) {
    return featuresIds?.whereType<String>().toSet() ?? {};
  }

  @override
  bool hasCompletedStep(String featureId) {
    return true;
  }
}

class FakeDeviceInfo extends DeviceInfoPlatform {
  @override
  Future<AndroidDeviceInfo> androidInfo() async {
    return AndroidDeviceInfo(
      version: FakeAndroidBuildVersion(),
      supported32BitAbis: [],
      supported64BitAbis: [],
      supportedAbis: [],
      systemFeatures: [],
    );
  }
}

class FakeAndroidBuildVersion implements AndroidBuildVersion {
  @override
  String? get baseOS => null;

  @override
  String? get codename => null;

  @override
  String? get incremental => null;

  @override
  int? get previewSdkInt => null;

  @override
  String? get release => null;

  @override
  int? get sdkInt => 22;

  @override
  String? get securityPatch => null;

  @override
  Map<String, dynamic> toMap() {
    return {};
  }
}

class StructureTestVariants extends TestVariant<MHPermissionsSet> {
  MHPermissionsSet? _current;
  MHPermissionsSet? get current => _current;

  @override
  String describeValue(MHPermissionsSet value) {
    final filtered = value.toJson().entries.where((kv) => !kv.value);
    return filtered.isEmpty ? 'Admin' : Map.fromEntries(filtered).toString();
  }

  @override
  Future<MHPermissionsSet> setUp(MHPermissionsSet value) async {
    await mockMHUser(
      user: User(
        ref: GetIt.I<DatabaseRepository>()
            .collection('UsersData')
            .doc('personId'),
        uid: 'uid',
        name: 'displayName',
        email: 'email',
        password: 'password',
        permissions: value,
        lastTanawol: DateTime.now(),
        lastConfession: DateTime.now(),
      ),
    );
    return _current = value;
  }

  @override
  Future<void> tearDown(
      MHPermissionsSet value, covariant Object? memento) async {
    await GetIt.I.popScope();
  }

  @override
  Iterable<MHPermissionsSet> get values sync* {
    final basePermissions = MHPermissionsSet.fromJson(
      const {
        'approved': true,
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
    );

    yield basePermissions;
    yield basePermissions.copyWith(write: false);
    yield basePermissions.copyWith(manageUsers: false);
    yield basePermissions.copyWith(manageAllowedUsers: false);
    yield basePermissions.copyWith(recordHistory: false);
    yield basePermissions.copyWith(secretary: false);
    yield basePermissions.copyWith(manageDeleted: false);
    yield basePermissions.copyWith(export: false);
  }
}
