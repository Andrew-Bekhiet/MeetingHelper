import 'dart:async';
import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:collection/collection.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart'
    if (dart.library.io) 'package:firebase_crashlytics/firebase_crashlytics.dart'
    if (dart.library.html) 'package:meetinghelper/crashlytics_web.dart';
import 'package:firebase_dynamic_links/firebase_dynamic_links.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_storage/firebase_storage.dart' hide ListOptions;
import 'package:flutter/foundation.dart' as f;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart'
    hide Person;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:meetinghelper/models/data/class.dart';
import 'package:meetinghelper/models/data/service.dart';
import 'package:meetinghelper/models/data_object_widget.dart';
import 'package:meetinghelper/models/list_controllers.dart';
import 'package:meetinghelper/models/search/search_filters.dart';
import 'package:meetinghelper/utils/typedefs.dart';
import 'package:meetinghelper/views/lists/lists.dart';
import 'package:meetinghelper/views/services_list.dart';
import 'package:photo_view/photo_view.dart';
import 'package:provider/provider.dart';
import 'package:rxdart/rxdart.dart';
import 'package:spreadsheet_decoder/spreadsheet_decoder.dart';
import 'package:timeago/timeago.dart';

import '../main.dart';
import '../models/data/person.dart';
import '../models/data/user.dart';
import '../models/history/history_record.dart';
import '../models/mini_models.dart';
import '../models/super_classes.dart';
import '../models/theme_notifier.dart';
import '../utils/globals.dart';
import '../views/auth_screen.dart';
import '../views/list.dart';
import '../views/lists/users_list.dart';
import '../views/notification.dart' as no;
import '../views/search_query.dart';

void changeTheme({required BuildContext context}) {
  bool isDark = Hive.box('Settings').get('DarkTheme',
          defaultValue: WidgetsBinding.instance!.window.platformBrightness ==
              Brightness.dark) ??
      WidgetsBinding.instance!.window.platformBrightness == Brightness.dark;
  final bool greatFeastTheme =
      Hive.box('Settings').get('GreatFeastTheme', defaultValue: true);
  MaterialColor primary = Colors.amber;
  Color secondary = Colors.amberAccent;

  final riseDay = getRiseDay();
  if (greatFeastTheme &&
      DateTime.now()
          .isAfter(riseDay.subtract(const Duration(days: 7, seconds: 20))) &&
      DateTime.now().isBefore(riseDay.subtract(const Duration(days: 1)))) {
    primary = black;
    secondary = blackAccent;
    isDark = true;
  } else if (greatFeastTheme &&
      DateTime.now()
          .isBefore(riseDay.add(const Duration(days: 50, seconds: 20))) &&
      DateTime.now().isAfter(riseDay.subtract(const Duration(days: 1)))) {
    isDark = false;
  }

  context.read<ThemeNotifier>().theme = ThemeData.from(
    colorScheme: ColorScheme.fromSwatch(
      backgroundColor: isDark ? Colors.grey[850]! : Colors.grey[50]!,
      brightness: isDark ? Brightness.dark : Brightness.light,
      primarySwatch: primary,
      accentColor: secondary,
    ),
  ).copyWith(
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide(color: primary),
      ),
    ),
    floatingActionButtonTheme:
        FloatingActionButtonThemeData(backgroundColor: primary),
    visualDensity: VisualDensity.adaptivePlatformDensity,
    brightness: isDark ? Brightness.dark : Brightness.light,
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        primary: secondary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        primary: secondary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        primary: secondary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: primary,
      foregroundColor: (isDark
              ? Typography.material2018().white
              : Typography.material2018().black)
          .headline6
          ?.color,
      systemOverlayStyle:
          isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
    ),
    bottomAppBarTheme: BottomAppBarTheme(
      color: secondary,
      shape: const CircularNotchedRectangle(),
    ),
  );
}

Stream<Map<PreferredStudyYear?, List<T>>>
    servicesByStudyYearRef<T extends DataObject>() {
  assert(T == Class || T == Service || T == DataObject);

  return Rx.combineLatest3<Map<JsonRef, StudyYear>, List<Class>, List<Service>,
          Map<PreferredStudyYear?, List<T>>>(
      FirebaseFirestore.instance
          .collection('StudyYears')
          .orderBy('Grade')
          .snapshots()
          .map<Map<JsonRef, StudyYear>>(
            (sys) => {
              for (final sy in sys.docs) sy.reference: StudyYear.fromDoc(sy)
            },
          ),
      T == Service
          ? Stream.value([])
          : User.instance.stream.switchMap((user) => (user.superAccess
                  ? FirebaseFirestore.instance
                      .collection('Classes')
                      .orderBy('StudyYear')
                      .orderBy('Gender')
                      .snapshots()
                  : FirebaseFirestore.instance
                      .collection('Classes')
                      .where('Allowed', arrayContains: User.instance.uid)
                      .orderBy('StudyYear')
                      .orderBy('Gender')
                      .snapshots())
              .map((cs) => cs.docs.map(Class.fromQueryDoc).toList())),
      T == Class ? Stream.value([]) : Service.getAllForUser(),
      (studyYears, classes, services) {
    final combined = [...classes, ...services];

    mergeSort<T>(combined.cast<T>(), compare: (c, c2) {
      if (c is Class && c2 is Class) {
        if (c.studyYear == c2.studyYear) return c.gender.compareTo(c2.gender);
        return studyYears[c.studyYear]!
            .grade!
            .compareTo(studyYears[c2.studyYear]!.grade!);
      } else if (c is Service && c2 is Service) {
        return ((studyYears[c.studyYearRange?.from]?.grade ?? 0) -
                (studyYears[c.studyYearRange?.to]?.grade ?? 0))
            .compareTo((studyYears[c2.studyYearRange?.from]?.grade ?? 0) -
                (studyYears[c2.studyYearRange?.to]?.grade ?? 0));
      } else if (c is Class &&
          c2 is Service &&
          c2.studyYearRange?.from != c2.studyYearRange?.to)
        return -1;
      else if (c2 is Class &&
          c is Service &&
          c.studyYearRange?.from != c.studyYearRange?.to) return 1;
      return 0;
    });

    double? _getPreferredGrade(int? grade) {
      if (grade == null) return null;
      switch (grade) {
        case -1:
        case 0:
          return 0.1;
        case 1:
        case 2:
        case 3:
        case 4:
        case 5:
        case 6:
          return 1.2;
        case 7:
        case 8:
        case 9:
          return 2.3;
        case 10:
        case 11:
        case 12:
          return 3.4;
        case 13:
        case 14:
        case 15:
        case 16:
        case 17:
        case 18:
          return 4.5;
        default:
          return -1;
      }
    }

    return groupBy<T, PreferredStudyYear?>(combined.cast<T>(), (c) {
      if (c is Class)
        return studyYears[c.studyYear] != null
            ? PreferredStudyYear.fromStudyYear(studyYears[c.studyYear]!)
            : null;
      else if (c is Service && c.studyYearRange?.from == c.studyYearRange?.to)
        return studyYears[c.studyYearRange?.from] != null
            ? PreferredStudyYear.fromStudyYear(
                studyYears[c.studyYearRange?.from]!)
            : null;
      else if (c is Service)
        return studyYears[c.studyYearRange?.to] != null
            ? PreferredStudyYear.fromStudyYear(
                studyYears[c.studyYearRange?.to]!,
                _getPreferredGrade(studyYears[c.studyYearRange?.to]!.grade))
            : null;

      return null;
    });
  });
}

Stream<Map<PreferredStudyYear?, List<T>>>
    servicesByStudyYearRefForUser<T extends DataObject>(
        String? uid, List<JsonRef> adminServices) {
  assert(T == Class || T == Service);

  return Rx.combineLatest3<Map<JsonRef, StudyYear>, List<Class>, List<Service>,
          Map<PreferredStudyYear?, List<T>>>(
      FirebaseFirestore.instance
          .collection('StudyYears')
          .orderBy('Grade')
          .snapshots()
          .map<Map<JsonRef, StudyYear>>(
            (sys) => {
              for (final sy in sys.docs) sy.reference: StudyYear.fromDoc(sy)
            },
          ),
      T == Service
          ? Stream.value([])
          : FirebaseFirestore.instance
              .collection('Classes')
              .where('Allowed', arrayContains: uid)
              .orderBy('StudyYear')
              .orderBy('Gender')
              .snapshots()
              .map((cs) => cs.docs.map(Class.fromQueryDoc).toList()),
      adminServices.isEmpty || T == Class
          ? Stream.value([])
          : Rx.combineLatestList(
              adminServices.map((r) =>
                  r.snapshots().map(Service.fromDoc).whereType<Service>()),
            ), (studyYears, classes, services) {
    final combined = <DataObject>[...classes, ...services];

    mergeSort<DataObject>(combined, compare: (c, c2) {
      if (c is Class && c2 is Class) {
        if (c.studyYear == c2.studyYear) return c.gender.compareTo(c2.gender);
        return studyYears[c.studyYear]!
            .grade!
            .compareTo(studyYears[c2.studyYear]!.grade!);
      } else if (c is Service && c2 is Service) {
        return ((studyYears[c.studyYearRange?.from]?.grade ?? 0) -
                (studyYears[c.studyYearRange?.to]?.grade ?? 0))
            .compareTo((studyYears[c2.studyYearRange?.from]?.grade ?? 0) -
                (studyYears[c2.studyYearRange?.to]?.grade ?? 0));
      } else if (c is Class &&
          c2 is Service &&
          c2.studyYearRange?.from != c2.studyYearRange?.to)
        return -1;
      else if (c2 is Class &&
          c is Service &&
          c.studyYearRange?.from != c.studyYearRange?.to) return 1;
      return 0;
    });

    double? _getPreferredGrade(int? from, int? to) {
      if (from == null || to == null) return null;

      if (from == -1 && to == 0)
        return 0.1;
      else if (from >= 1 && to <= 6)
        return 1.1;
      else if (from >= 7 && to <= 9)
        return 2.1;
      else if (from >= 10 && to <= 12)
        return 3.1;
      else if (from >= 13 && to <= 18) return 4.1;
      return null;
    }

    return groupBy<T, PreferredStudyYear?>(combined.cast<T>(), (c) {
      if (c is Class)
        return studyYears[c.studyYear] != null
            ? PreferredStudyYear.fromStudyYear(studyYears[c.studyYear]!)
            : null;
      else if (c is Service && c.studyYearRange?.from == c.studyYearRange?.to)
        return studyYears[c.studyYearRange?.from] != null
            ? PreferredStudyYear.fromStudyYear(
                studyYears[c.studyYearRange?.from]!)
            : null;
      else if (c is Service)
        return studyYears[c.studyYearRange?.to] != null
            ? PreferredStudyYear.fromStudyYear(
                studyYears[c.studyYearRange?.to]!,
                _getPreferredGrade(studyYears[c.studyYearRange?.from]!.grade,
                    studyYears[c.studyYearRange?.to]!.grade))
            : null;

      return null;
    });
  });
}

void classTap(Class? _class) {
  navigator.currentState!.pushNamed('ClassInfo', arguments: _class);
}

void serviceTap(Service? service) {
  navigator.currentState!.pushNamed('ServiceInfo', arguments: service);
}

void dataObjectTap(DataObject? obj) {
  if (obj is Class)
    classTap(obj);
  else if (obj is Service)
    serviceTap(obj);
  else if (obj is Person)
    personTap(obj);
  else if (obj is User)
    userTap(obj);
  else
    throw UnimplementedError();
}

LatLng fromGeoPoint(GeoPoint point) {
  return LatLng(point.latitude, point.longitude);
}

GeoPoint fromLatLng(LatLng point) {
  return GeoPoint(point.latitude, point.longitude);
}

Future<dynamic> getLinkObject(Uri deepLink) async {
  try {
    if (deepLink.pathSegments[0] == 'viewImage') {
      return MessageIcon(deepLink.queryParameters['url']);
    } else if (deepLink.pathSegments[0] == 'viewClass') {
      return await Class.fromId(deepLink.queryParameters['ClassId'] ?? 'null');
    } else if (deepLink.pathSegments[0] == 'viewPerson') {
      return await Person.fromId(
          deepLink.queryParameters['PersonId'] ?? 'null');
    } else if (deepLink.pathSegments[0] == 'viewUser') {
      return await User.fromUsersData(
          deepLink.queryParameters['UID'] ?? 'null');
    } else if (deepLink.pathSegments[0] == 'viewQuery') {
      return const QueryIcon();
    }
    // ignore: empty_catches
  } catch (err) {}
  return null;
}

List<RadioListTile> getOrderingOptions(
    BehaviorSubject<OrderOptions> orderOptions, int? index) {
  return (index == 0
          ? Class.getHumanReadableMap2()
          : Person.getHumanReadableMap2())
      .entries
      .map(
        (e) => RadioListTile(
          value: e.key,
          groupValue: orderOptions.value.orderBy,
          title: Text(e.value),
          onChanged: (dynamic value) {
            orderOptions
                .add(OrderOptions(orderBy: value, asc: orderOptions.value.asc));
            navigator.currentState!.pop();
          },
        ),
      )
      .toList()
    ..addAll(
      [
        RadioListTile(
          value: 'true',
          groupValue: orderOptions.value.asc.toString(),
          title: const Text('تصاعدي'),
          onChanged: (value) {
            orderOptions.add(OrderOptions(
                orderBy: orderOptions.value.orderBy, asc: value == 'true'));
            navigator.currentState!.pop();
          },
        ),
        RadioListTile(
          value: 'false',
          groupValue: orderOptions.value.asc.toString(),
          title: const Text('تنازلي'),
          onChanged: (value) {
            orderOptions.add(OrderOptions(
                orderBy: orderOptions.value.orderBy, asc: value == 'true'));
            navigator.currentState!.pop();
          },
        ),
      ],
    );
}

String getPhone(String phone, [bool whatsapp = true]) {
  if (phone.startsWith('+')) return phone.replaceFirst('+', '').trim();
  if (phone.startsWith('2')) return phone.trim();
  if (phone.startsWith('0') && whatsapp) return '2' + phone.trim();
  if (phone.startsWith('1') && whatsapp) return '21' + phone.trim();
  return phone.trim();
}

void historyTap(HistoryDay? history) async {
  if (history is! ServantsHistoryDay) {
    await navigator.currentState!.pushNamed('Day', arguments: history);
  } else {
    await navigator.currentState!.pushNamed('ServantsDay', arguments: history);
  }
}

DateTime getRiseDay([int? year]) {
  year ??= DateTime.now().year;
  final int a = year % 4;
  final int b = year % 7;
  final int c = year % 19;
  final int d = (19 * c + 15) % 30;
  final int e = (2 * a + 4 * b - d + 34) % 7;

  return DateTime(year, (d + e + 114) ~/ 31, ((d + e + 114) % 31) + 14);
}

void import(BuildContext context) async {
  try {
    final picked = await FilePicker.platform.pickFiles(
        allowedExtensions: ['xlsx'], withData: true, type: FileType.custom);
    if (picked == null) return;
    final fileData = picked.files[0].bytes!;
    final decoder = SpreadsheetDecoder.decodeBytes(fileData);
    if (decoder.tables.containsKey('Classes') &&
        decoder.tables.containsKey('Persons')) {
      scaffoldMessenger.currentState!.showSnackBar(
        const SnackBar(
          content: Text('جار رفع الملف...'),
          duration: Duration(minutes: 9),
        ),
      );
      final filename = DateTime.now().toIso8601String();
      await FirebaseStorage.instance
          .ref('Imports/' + filename + '.xlsx')
          .putData(
              fileData,
              SettableMetadata(
                  customMetadata: {'createdBy': User.instance.uid!}));
      scaffoldMessenger.currentState!.hideCurrentSnackBar();
      scaffoldMessenger.currentState!.showSnackBar(
        const SnackBar(
          content: Text('جار استيراد الملف...'),
          duration: Duration(minutes: 9),
        ),
      );
      await FirebaseFunctions.instance
          .httpsCallable('importFromExcel')
          .call({'fileId': filename + '.xlsx'});
      scaffoldMessenger.currentState!.hideCurrentSnackBar();
      scaffoldMessenger.currentState!.showSnackBar(
        const SnackBar(
          content: Text('تم الاستيراد بنجاح'),
          duration: Duration(seconds: 4),
        ),
      );
    } else {
      scaffoldMessenger.currentState!.hideCurrentSnackBar();
      await showErrorDialog(context, 'ملف غير صالح');
    }
  } catch (e) {
    scaffoldMessenger.currentState!.hideCurrentSnackBar();
    await showErrorDialog(context, e.toString());
  }
}

Future<void> onBackgroundMessage(RemoteMessage message) async {
  await Hive.initFlutter();
  await Hive.openBox<Map>('Notifications');
  await storeNotification(message);
  await Hive.close();
}

void onForegroundMessage(RemoteMessage message, [BuildContext? context]) async {
  context ??= mainScfld.currentContext;
  final bool opened = Hive.isBoxOpen('Notifications');
  if (!opened) await Hive.openBox<Map>('Notifications');
  await storeNotification(message);
  scaffoldMessenger.currentState!.showSnackBar(
    SnackBar(
      content: Text(message.notification!.body!),
      action: SnackBarAction(
        label: 'فتح الاشعارات',
        onPressed: () => navigator.currentState!.pushNamed('Notifications'),
      ),
    ),
  );
}

Future<void> onNotificationClicked(String? payload) async {
  if (WidgetsBinding.instance!.renderViewElement != null) {
    await processClickedNotification(mainScfld.currentContext, payload);
  }
}

Stream<Map<JsonRef, Tuple2<Class, List<User>>>> usersByClassRef(
    List<User> users) {
  return FirebaseFirestore.instance
      .collection('StudyYears')
      .orderBy('Grade')
      .snapshots()
      .switchMap(
    (sys) {
      final Map<JsonRef, StudyYear> studyYears = {
        for (final sy in sys.docs) sy.reference: StudyYear.fromDoc(sy)
      };
      studyYears[FirebaseFirestore.instance
          .collection('StudyYears')
          .doc('Unknown')] = StudyYear('unknown', 'غير معروفة', 10000000);
      return User.instance.stream.switchMap(
        (user) => (user.superAccess
                ? FirebaseFirestore.instance
                    .collection('Classes')
                    .orderBy('StudyYear')
                    .orderBy('Gender')
                    .snapshots()
                : FirebaseFirestore.instance
                    .collection('Classes')
                    .where('Allowed',
                        arrayContains:
                            auth.FirebaseAuth.instance.currentUser!.uid)
                    .orderBy('StudyYear')
                    .orderBy('Gender')
                    .snapshots())
            .map(
          (cs) {
            final classesByRef = {
              for (final c in cs.docs.map(Class.fromDoc).toList()) c!.ref: c
            };

            final rslt = {
              for (final e in groupBy<User, Class>(
                  users,
                  (user) => user.classId == null
                      ? Class(
                          name: 'غير محدد',
                          gender: true,
                          color: Colors.redAccent)
                      : classesByRef[user.classId] ??
                          Class(
                              name: '{لا يمكن قراءة اسم الفصل}',
                              gender: true,
                              color: Colors.redAccent,
                              id: 'Unknown')).entries)
                e.key.ref: Tuple2(e.key, e.value)
            }.entries.toList();

            mergeSort<MapEntry<JsonRef?, Tuple2<Class, List<User>>>>(rslt,
                compare: (c, c2) {
              if (c.value.item1.name == 'غير محدد' ||
                  c.value.item1.name == '{لا يمكن قراءة اسم الفصل}') return 1;
              if (c2.value.item1.name == 'غير محدد' ||
                  c2.value.item1.name == '{لا يمكن قراءة اسم الفصل}') return -1;

              if (studyYears[c.value.item1.studyYear!] ==
                  studyYears[c2.value.item1.studyYear!])
                return c.value.item1.gender.compareTo(c2.value.item1.gender);
              return studyYears[c.value.item1.studyYear!]!
                  .grade!
                  .compareTo(studyYears[c2.value.item1.studyYear!]!.grade!);
            });

            return {for (final e in rslt) e.key: e.value};
          },
        ),
      );
    },
  );
}

Stream<Map<JsonRef, Tuple2<Class, List<Person>>>> personsByClassRef(
    [List<Person>? persons]) {
  return Rx.combineLatest3<Map<JsonRef, StudyYear>, List<Person>, JsonQuery,
      Map<JsonRef, Tuple2<Class, List<Person>>>>(
    FirebaseFirestore.instance
        .collection('StudyYears')
        .orderBy('Grade')
        .snapshots()
        .map(
          (sys) =>
              {for (final sy in sys.docs) sy.reference: StudyYear.fromDoc(sy)},
        ),
    persons != null ? Stream.value(persons) : Person.getAllForUser(),
    User.instance.stream.switchMap((user) => user.superAccess
        ? FirebaseFirestore.instance
            .collection('Classes')
            .orderBy('StudyYear')
            .orderBy('Gender')
            .snapshots()
        : FirebaseFirestore.instance
            .collection('Classes')
            .where('Allowed',
                arrayContains: auth.FirebaseAuth.instance.currentUser!.uid)
            .orderBy('StudyYear')
            .orderBy('Gender')
            .snapshots()),
    (studyYears, persons, cs) {
      final Map<JsonRef?, List<Person>> personsByClassRef =
          groupBy(persons, (p) => p.classId);

      final classes = cs.docs
          .map(Class.fromQueryDoc)
          .where((c) => personsByClassRef[c.ref] != null)
          .toList();

      mergeSort<Class>(classes, compare: (c, c2) {
        if (c.studyYear == c2.studyYear) return c.gender.compareTo(c2.gender);
        return studyYears[c.studyYear]!
            .grade!
            .compareTo(studyYears[c2.studyYear]!.grade!);
      });

      return {
        for (final c in classes)
          c.ref: Tuple2<Class, List<Person>>(c, personsByClassRef[c.ref]!)
      };
    },
  );
}

Stream<Map<JsonRef, Tuple2<StudyYear, List<T>>>>
    personsByStudyYearRef<T extends Person>([List<T>? persons]) {
  assert(T == Person || persons != null);

  return Rx.combineLatest2<Map<JsonRef, StudyYear>, List<T>,
      Map<JsonRef, Tuple2<StudyYear, List<T>>>>(
    FirebaseFirestore.instance
        .collection('StudyYears')
        .orderBy('Grade')
        .snapshots()
        .map(
          (sys) =>
              {for (final sy in sys.docs) sy.reference: StudyYear.fromDoc(sy)},
        ),
    (persons != null ? Stream.value(persons) : Person.getAllForUser())
        .map((p) => p.whereType<T>().toList()),
    (studyYears, persons) {
      return {
        for (final person in persons.groupListsBy((p) => p.studyYear).entries)
          if (person.key != null && studyYears[person.key] != null)
            person.key!: Tuple2(studyYears[person.key]!, person.value)
      };
    },
  );
}

void personTap(Person? person) {
  navigator.currentState!.pushNamed('PersonInfo', arguments: person);
}

Future<void> processClickedNotification(BuildContext? context,
    [String? payload]) async {
  final notificationDetails =
      await FlutterLocalNotificationsPlugin().getNotificationAppLaunchDetails();
  if (notificationDetails == null) return;

  if (notificationDetails.didNotificationLaunchApp) {
    if ((notificationDetails.payload ?? payload) == 'Birthday') {
      WidgetsBinding.instance!.addPostFrameCallback((_) async {
        await Future.delayed(const Duration(milliseconds: 900), () => null);
        await navigator.currentState!.push(
          MaterialPageRoute(
            builder: (context) {
              final now = DateTime.now().millisecondsSinceEpoch;
              return SearchQuery(query: {
                'parentIndex': '1',
                'childIndex': '2',
                'operatorIndex': '0',
                'queryText': '',
                'queryValue': 'T' +
                    (now - (now % Duration.millisecondsPerDay)).toString(),
                'birthDate': 'false',
                'descending': 'false',
                'orderBy': 'BirthDay'
              });
            },
          ),
        );
      });
    } else if ((notificationDetails.payload ?? payload) == 'Confessions') {
      WidgetsBinding.instance!.addPostFrameCallback((_) async {
        await Future.delayed(const Duration(milliseconds: 900), () => null);
        await navigator.currentState!.push(
          MaterialPageRoute(
            builder: (context) {
              final now = DateTime.now().millisecondsSinceEpoch;
              return SearchQuery(query: {
                'parentIndex': '1',
                'childIndex': '9',
                'operatorIndex': '3',
                'queryText': '',
                'queryValue': 'T' +
                    ((now - (now % Duration.millisecondsPerDay)) -
                            (Duration.millisecondsPerDay * 7))
                        .toString(),
                'birthDate': 'false',
                'descending': 'false',
                'orderBy': 'LastConfession'
              });
            },
          ),
        );
      });
    } else if ((notificationDetails.payload ?? payload) == 'Tanawol') {
      WidgetsBinding.instance!.addPostFrameCallback((_) async {
        await Future.delayed(const Duration(milliseconds: 900), () => null);
        await navigator.currentState!.push(
          MaterialPageRoute(
            builder: (context) {
              final now = DateTime.now().millisecondsSinceEpoch;
              return SearchQuery(query: {
                'parentIndex': '1',
                'childIndex': '8',
                'operatorIndex': '3',
                'queryText': '',
                'queryValue': 'T' +
                    ((now - (now % Duration.millisecondsPerDay)) -
                            (Duration.millisecondsPerDay * 7))
                        .toString(),
                'birthDate': 'false',
                'descending': 'false',
                'orderBy': 'LastTanawol'
              });
            },
          ),
        );
      });
    } else if ((notificationDetails.payload ?? payload) == 'Kodas') {
      WidgetsBinding.instance!.addPostFrameCallback((_) async {
        await Future.delayed(const Duration(milliseconds: 900), () => null);
        await navigator.currentState!.push(
          MaterialPageRoute(
            builder: (context) {
              final now = DateTime.now().millisecondsSinceEpoch;
              return SearchQuery(query: {
                'parentIndex': '1',
                'childIndex': '10',
                'operatorIndex': '3',
                'queryText': '',
                'queryValue': 'T' +
                    ((now - (now % Duration.millisecondsPerDay)) -
                            (Duration.millisecondsPerDay * 7))
                        .toString(),
                'birthDate': 'false',
                'descending': 'false',
                'orderBy': 'LastKodas'
              });
            },
          ),
        );
      });
    } else if ((notificationDetails.payload ?? payload) == 'Meeting') {
      WidgetsBinding.instance!.addPostFrameCallback((_) async {
        await Future.delayed(const Duration(milliseconds: 900), () => null);
        await navigator.currentState!.push(
          MaterialPageRoute(
            builder: (context) {
              final now = DateTime.now().millisecondsSinceEpoch;
              return SearchQuery(query: {
                'parentIndex': '1',
                'childIndex': '11',
                'operatorIndex': '3',
                'queryText': '',
                'queryValue': 'T' +
                    ((now - (now % Duration.millisecondsPerDay)) -
                            (Duration.millisecondsPerDay * 7))
                        .toString(),
                'birthDate': 'false',
                'descending': 'false',
                'orderBy': 'LastMeeting'
              });
            },
          ),
        );
      });
    }
  }
}

Future<void> processLink(Uri? deepLink) async {
  try {
    if (deepLink != null &&
        deepLink.pathSegments.isNotEmpty &&
        deepLink.queryParameters.isNotEmpty) {
      if (deepLink.pathSegments[0] == 'viewClass') {
        classTap(Class.fromDoc(await FirebaseFirestore.instance
            .doc('Classes/${deepLink.queryParameters['ClassId']}')
            .get()));
      } else if (deepLink.pathSegments[0] == 'viewPerson') {
        personTap(Person.fromDoc(await FirebaseFirestore.instance
            .doc('Persons/${deepLink.queryParameters['PersonId']}')
            .get()));
      } else if (deepLink.pathSegments[0] == 'viewQuery') {
        await navigator.currentState!.push(
          MaterialPageRoute(
            builder: (c) => SearchQuery(
              query: deepLink.queryParameters,
            ),
          ),
        );
      } else if (deepLink.pathSegments[0] == 'viewUser') {
        if (User.instance.manageUsers) {
          userTap((await User.fromUsersData(deepLink.queryParameters['UID']))!);
        } else {
          await showErrorDialog(navigator.currentContext!,
              'ليس لديك الصلاحية لرؤية محتويات الرابط!');
        }
      }
    } else {
      await showErrorDialog(navigator.currentContext!, 'رابط غير صالح!');
    }
  } catch (err) {
    if (err.toString().contains('PERMISSION_DENIED')) {
      await showErrorDialog(
          navigator.currentContext!, 'ليس لديك الصلاحية لرؤية محتويات الرابط!');
    } else {
      await showErrorDialog(
          navigator.currentContext!, 'حدث خطأ! أثناء قراءة محتويات الرابط');
    }
  }
}

Future<void> sendNotification(BuildContext context, dynamic attachement) async {
  final List<User>? users = await showDialog(
    context: context,
    builder: (context) {
      return MultiProvider(
        providers: [
          Provider<DataObjectListController<User>>(
            create: (_) => DataObjectListController<User>(
              itemBuilder: (current,
                      [void Function(User)? onLongPress,
                      void Function(User)? onTap,
                      Widget? trailing,
                      Widget? subtitle]) =>
                  DataObjectWidget(
                current,
                onTap: () => onTap!(current),
                trailing: trailing,
                showSubTitle: false,
              ),
              selectionMode: true,
              itemsStream: FirebaseFirestore.instance
                  .collection('Users')
                  .snapshots()
                  .map(
                    (s) =>
                        s.docs.map((e) => User.fromDoc(e)..uid = e.id).toList(),
                  ),
            ),
            dispose: (context, c) => c.dispose(),
          ),
        ],
        builder: (context, child) => Scaffold(
          appBar: AppBar(
            title: const Text('اختيار مستخدمين'),
            actions: [
              IconButton(
                onPressed: () {
                  navigator.currentState!.pop(context
                      .read<DataObjectListController<User>>()
                      .selectedLatest
                      ?.values
                      .toList());
                },
                icon: const Icon(Icons.done),
                tooltip: 'تم',
              ),
            ],
          ),
          body: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SearchField(
                showSuffix: false,
                searchStream:
                    context.read<DataObjectListController<User>>().searchQuery,
                textStyle: Theme.of(context).textTheme.bodyText2,
              ),
              const Expanded(
                child: UsersList(
                  autoDisposeController: false,
                ),
              ),
            ],
          ),
        ),
      );
    },
  );

  final title = TextEditingController();
  final content = TextEditingController();
  if (users != null &&
      await showDialog(
            context: context,
            builder: (context) {
              return AlertDialog(
                actions: <Widget>[
                  TextButton.icon(
                    icon: const Icon(Icons.send),
                    onPressed: () => navigator.currentState!.pop(true),
                    label: const Text('ارسال'),
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.cancel),
                    onPressed: () => navigator.currentState!.pop(false),
                    label: const Text('الغاء الأمر'),
                  ),
                ],
                title: const Text('انشاء رسالة'),
                content: SizedBox(
                  width: 280,
                  child: Column(
                    children: <Widget>[
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: TextFormField(
                          decoration: InputDecoration(
                            labelText: 'عنوان الرسالة',
                            border: OutlineInputBorder(
                              borderSide: BorderSide(
                                  color: Theme.of(context).colorScheme.primary),
                            ),
                          ),
                          controller: title,
                          textInputAction: TextInputAction.next,
                          validator: (value) {
                            if (value!.isEmpty) {
                              return 'هذا الحقل مطلوب';
                            }
                            return null;
                          },
                        ),
                      ),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: TextFormField(
                            decoration: InputDecoration(
                              labelText: 'محتوى الرسالة',
                              border: OutlineInputBorder(
                                borderSide: BorderSide(
                                    color:
                                        Theme.of(context).colorScheme.primary),
                              ),
                            ),
                            textInputAction: TextInputAction.newline,
                            maxLines: null,
                            controller: content,
                            expands: true,
                          ),
                        ),
                      ),
                      Text('سيتم ارفاق ${attachement.name} مع الرسالة')
                    ],
                  ),
                ),
              );
            },
          ) ==
          true) {
    String link = '';
    if (attachement is Class) {
      link = 'Class?ClassId=${attachement.id}';
    } else if (attachement is Person) {
      link = 'Person?PersonId=${attachement.id}';
    }
    await FirebaseFunctions.instance.httpsCallable('sendMessageToUsers').call({
      'users': users.map((e) => e.uid).toList(),
      'title': title.text,
      'body': 'أرسل إليك ${User.instance.name} رسالة',
      'content': content.text,
      'attachement': 'https://meetinghelper.page.link/view$link'
    });
  }
}

Future<void> recoverDoc(BuildContext context, String path) async {
  bool? nested = false;
  bool? keepBackup = true;
  if (await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          actions: [
            TextButton(
              onPressed: () => navigator.currentState!.pop(true),
              child: const Text('استرجاع'),
            ),
          ],
          content: StatefulBuilder(
            builder: (context, setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Checkbox(
                        value: nested,
                        onChanged: (v) => setState(() => nested = v),
                      ),
                      const Text(
                        'استرجع ايضا العناصر بداخل هذا العنصر',
                        textScaleFactor: 0.9,
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Checkbox(
                        value: keepBackup,
                        onChanged: (v) => setState(() => keepBackup = v),
                      ),
                      const Text('ابقاء البيانات المحذوفة'),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ) ==
      true) {
    try {
      await FirebaseFunctions.instance.httpsCallable('recoverDoc').call({
        'deletedPath': path,
        'keepBackup': keepBackup,
        'nested': nested,
      });
      scaffoldMessenger.currentState!
          .showSnackBar(const SnackBar(content: Text('تم الاسترجاع بنجاح')));
    } catch (err, stcTrace) {
      await FirebaseCrashlytics.instance
          .setCustomKey('LastErrorIn', 'helpers.recoverDoc');
      await FirebaseCrashlytics.instance.recordError(err, stcTrace);
    }
  }
}

Future<String> shareClass(Class _class) async => shareClassRaw(_class.id);

Future<String> shareClassRaw(String? id) async {
  return (await DynamicLinkParameters(
    uriPrefix: uriPrefix,
    link: Uri.parse('https://meetinghelper.com/viewClass?ClassId=$id'),
    androidParameters: androidParameters,
    dynamicLinkParametersOptions: dynamicLinkParametersOptions,
    iosParameters: iosParameters,
  ).buildShortLink())
      .shortUrl
      .toString();
}

Future<String> shareService(Service service) async =>
    shareServiceRaw(service.id);

Future<String> shareServiceRaw(String? id) async {
  return (await DynamicLinkParameters(
    uriPrefix: uriPrefix,
    link: Uri.parse('https://meetinghelper.com/viewService?ServiceId=$id'),
    androidParameters: androidParameters,
    dynamicLinkParametersOptions: dynamicLinkParametersOptions,
    iosParameters: iosParameters,
  ).buildShortLink())
      .shortUrl
      .toString();
}

Future<String> shareDataObject(DataObject? obj) async {
  if (obj is HistoryDay) return shareHistory(obj);
  if (obj is Class) return shareClass(obj);
  if (obj is Person) return sharePerson(obj);
  throw UnimplementedError();
}

Future<String> shareHistory(HistoryDay record) async =>
    shareHistoryRaw(record.id);

Future<String> shareHistoryRaw(String? id) async {
  return (await DynamicLinkParameters(
    uriPrefix: uriPrefix,
    link:
        Uri.parse('https://meetinghelper.com/viewHistoryRecord?HistoryId=$id'),
    androidParameters: androidParameters,
    dynamicLinkParametersOptions: dynamicLinkParametersOptions,
    iosParameters: iosParameters,
  ).buildShortLink())
      .shortUrl
      .toString();
}

Future<String> sharePerson(Person person) async {
  return sharePersonRaw(person.id);
}

Future<String> sharePersonRaw(String? id) async {
  return (await DynamicLinkParameters(
    uriPrefix: uriPrefix,
    link: Uri.parse('https://meetinghelper.com/viewPerson?PersonId=$id'),
    androidParameters: androidParameters,
    dynamicLinkParametersOptions: dynamicLinkParametersOptions,
    iosParameters: iosParameters,
  ).buildShortLink())
      .shortUrl
      .toString();
}

Future<String> shareQuery(Map<String, String?> query) async {
  return (await DynamicLinkParameters(
    uriPrefix: uriPrefix,
    link: Uri.https('meetinghelper.com', 'viewQuery', query),
    androidParameters: androidParameters,
    dynamicLinkParametersOptions: dynamicLinkParametersOptions,
    iosParameters: iosParameters,
  ).buildShortLink())
      .shortUrl
      .toString();
}

Future<String> shareUser(User user) async => shareUserRaw(user.uid);

Future<String> shareUserRaw(String? uid) async {
  return (await DynamicLinkParameters(
    uriPrefix: uriPrefix,
    link: Uri.parse('https://meetinghelper.com/viewUser?UID=$uid'),
    androidParameters: androidParameters,
    dynamicLinkParametersOptions: dynamicLinkParametersOptions,
    iosParameters: iosParameters,
  ).buildShortLink())
      .shortUrl
      .toString();
}

void showBirthDayNotification() async {
  await Firebase.initializeApp();
  if (auth.FirebaseAuth.instance.currentUser == null) return;

  await Hive.initFlutter();

  const FlutterSecureStorage secureStorage = FlutterSecureStorage();
  final containsEncryptionKey = await secureStorage.containsKey(key: 'key');
  if (!containsEncryptionKey)
    await secureStorage.write(
        key: 'key', value: base64Url.encode(Hive.generateSecureKey()));

  final encryptionKey =
      base64Url.decode((await secureStorage.read(key: 'key'))!);

  await Hive.openBox(
    'User',
    encryptionCipher: HiveAesCipher(encryptionKey),
  );

  await User.instance.initialized;
  final source = GetOptions(
      source:
          (await Connectivity().checkConnectivity()) == ConnectivityResult.none
              ? Source.cache
              : Source.serverAndCache);

  final classes = await Class.getAllForUser().first;

  await Future.delayed(const Duration(seconds: 4));

  final List<String> persons = [];

  if (User.instance.superAccess) {
    persons.addAll((await FirebaseFirestore.instance
            .collection('Persons')
            .where(
              'BirthDay',
              isGreaterThanOrEqualTo: Timestamp.fromDate(
                DateTime(1970, DateTime.now().month, DateTime.now().day),
              ),
            )
            .where(
              'BirthDay',
              isLessThan: Timestamp.fromDate(
                DateTime(1970, DateTime.now().month, DateTime.now().day + 1),
              ),
            )
            .limit(20)
            .get(source))
        .docs
        .map((e) => e.data()['Name'] as String)
        .toList());
  } else {
    //Persons from Classes
    if (classes.isNotEmpty) if (classes.length <= 10) {
      persons.addAll((await FirebaseFirestore.instance
              .collection('Persons')
              .where('ClassId', whereIn: classes.map((e) => e.ref).toList())
              .where(
                'BirthDay',
                isGreaterThanOrEqualTo: Timestamp.fromDate(
                  DateTime(1970, DateTime.now().month, DateTime.now().day),
                ),
              )
              .where(
                'BirthDay',
                isLessThan: Timestamp.fromDate(
                  DateTime(1970, DateTime.now().month, DateTime.now().day + 1),
                ),
              )
              .limit(20)
              .get(source))
          .docs
          .map((d) => d.data()['Name'] as String)
          .toList());
    } else {
      persons.addAll((await Future.wait(
              classes.split(10).map((c) => FirebaseFirestore.instance
                  .collection('Persons')
                  .where('ClassId', whereIn: c.map((e) => e.ref).toList())
                  .where(
                    'BirthDay',
                    isGreaterThanOrEqualTo: Timestamp.fromDate(
                      DateTime(1970, DateTime.now().month, DateTime.now().day),
                    ),
                  )
                  .where(
                    'BirthDay',
                    isLessThan: Timestamp.fromDate(
                      DateTime(
                          1970, DateTime.now().month, DateTime.now().day + 1),
                    ),
                  )
                  .limit(20)
                  .get(source))))
          .expand((e) => e.docs)
          .map((d) => d.data()['Name'] as String)
          .toList());
    }
    //Persons from Services
    if (User.instance.adminServices
        .isNotEmpty) if (User.instance.adminServices.length <= 10) {
      persons.addAll((await FirebaseFirestore.instance
              .collection('Persons')
              .where('Services', arrayContainsAny: User.instance.adminServices)
              .where(
                'BirthDay',
                isGreaterThanOrEqualTo: Timestamp.fromDate(
                  DateTime(1970, DateTime.now().month, DateTime.now().day),
                ),
              )
              .where(
                'BirthDay',
                isLessThan: Timestamp.fromDate(
                  DateTime(1970, DateTime.now().month, DateTime.now().day + 1),
                ),
              )
              .limit(20)
              .get(source))
          .docs
          .map((d) => d.data()['Name'] as String)
          .toList());
    } else {
      persons.addAll((await Future.wait(User.instance.adminServices
              .split(10)
              .map((c) => FirebaseFirestore.instance
                  .collection('Persons')
                  .where('Services', arrayContainsAny: c)
                  .where(
                    'BirthDay',
                    isGreaterThanOrEqualTo: Timestamp.fromDate(
                      DateTime(1970, DateTime.now().month, DateTime.now().day),
                    ),
                  )
                  .where(
                    'BirthDay',
                    isLessThan: Timestamp.fromDate(
                      DateTime(
                          1970, DateTime.now().month, DateTime.now().day + 1),
                    ),
                  )
                  .limit(20)
                  .get(source))))
          .expand((e) => e.docs)
          .map((d) => d.data()['Name'] as String)
          .toList());
    }
  }

  if (persons.isNotEmpty || !f.kReleaseMode)
    await FlutterLocalNotificationsPlugin().show(
        2,
        'أعياد الميلاد',
        persons.join(', '),
        const NotificationDetails(
          android: AndroidNotificationDetails(
              'Birthday', 'إشعارات أعياد الميلاد', 'إشعارات أعياد الميلاد',
              icon: 'birthday',
              autoCancel: false,
              visibility: NotificationVisibility.secret,
              showWhen: false),
        ),
        payload: 'Birthday');
}

Future<List<T>?> selectServices<T extends DataObject>(List<T>? selected) async {
  final _controller = ServicesListController<T>(
    itemsStream: servicesByStudyYearRef<T>(),
    selectionMode: true,
    selected: selected,
    searchQuery: Stream.value(''),
  );

  if (await navigator.currentState!.push(
        MaterialPageRoute(
          builder: (context) => Scaffold(
            appBar: AppBar(
              title: const Text('اختر الفصول'),
              actions: [
                IconButton(
                    icon: const Icon(Icons.select_all),
                    onPressed: _controller.selectAll,
                    tooltip: 'تحديد الكل'),
                IconButton(
                    icon: const Icon(Icons.check_box_outline_blank),
                    onPressed: _controller.selectNone,
                    tooltip: 'تحديد لا شئ'),
                IconButton(
                    icon: const Icon(Icons.done),
                    onPressed: () => navigator.currentState!.pop(true),
                    tooltip: 'تم'),
              ],
            ),
            body: ServicesList<T>(
                options: _controller, autoDisposeController: false),
          ),
        ),
      ) ==
      true) {
    await _controller.dispose();
    return _controller.selectedLatest!.values.whereType<T>().toList();
  }
  await _controller.dispose();
  return null;
}

void showConfessionNotification() async {
  await Firebase.initializeApp();
  if (auth.FirebaseAuth.instance.currentUser == null) return;

  await Hive.initFlutter();

  const FlutterSecureStorage secureStorage = FlutterSecureStorage();
  final containsEncryptionKey = await secureStorage.containsKey(key: 'key');
  if (!containsEncryptionKey)
    await secureStorage.write(
        key: 'key', value: base64Url.encode(Hive.generateSecureKey()));

  final encryptionKey =
      base64Url.decode((await secureStorage.read(key: 'key'))!);

  await Hive.openBox(
    'User',
    encryptionCipher: HiveAesCipher(encryptionKey),
  );

  await User.instance.initialized;
  final source = GetOptions(
      source:
          (await Connectivity().checkConnectivity()) == ConnectivityResult.none
              ? Source.cache
              : Source.serverAndCache);

  final classes = await Class.getAllForUser().first;

  await Future.delayed(const Duration(seconds: 4));

  final List<String> persons = [];

  if (User.instance.superAccess) {
    persons.addAll((await FirebaseFirestore.instance
            .collection('Persons')
            .where('LastConfession',
                isLessThan: Timestamp.fromDate(
                    DateTime.now().subtract(const Duration(days: 7))))
            .limit(20)
            .get(source))
        .docs
        .map((e) => e.data()['Name'] as String)
        .toList());
  } else {
    //Persons from Classes
    if (classes.isNotEmpty) if (classes.length <= 10) {
      persons.addAll((await FirebaseFirestore.instance
              .collection('Persons')
              .where('ClassId', whereIn: classes.map((e) => e.ref).toList())
              .where('LastConfession',
                  isLessThan: Timestamp.fromDate(
                      DateTime.now().subtract(const Duration(days: 7))))
              .limit(20)
              .get(source))
          .docs
          .map((d) => d.data()['Name'] as String)
          .toList());
    } else {
      persons.addAll((await Future.wait(classes.split(10).map((c) =>
              FirebaseFirestore.instance
                  .collection('Persons')
                  .where('ClassId', whereIn: c.map((e) => e.ref).toList())
                  .where('LastConfession',
                      isLessThan: Timestamp.fromDate(
                          DateTime.now().subtract(const Duration(days: 7))))
                  .limit(20)
                  .get(source))))
          .expand((e) => e.docs)
          .map((d) => d.data()['Name'] as String)
          .toList());
    }
    //Persons from Services
    if (User.instance.adminServices
        .isNotEmpty) if (User.instance.adminServices.length <= 10) {
      persons.addAll((await FirebaseFirestore.instance
              .collection('Persons')
              .where('Services', arrayContainsAny: User.instance.adminServices)
              .where('LastConfession',
                  isLessThan: Timestamp.fromDate(
                      DateTime.now().subtract(const Duration(days: 7))))
              .limit(20)
              .get(source))
          .docs
          .map((d) => d.data()['Name'] as String)
          .toList());
    } else {
      persons.addAll((await Future.wait(User.instance.adminServices
              .split(10)
              .map((c) => FirebaseFirestore.instance
                  .collection('Persons')
                  .where('Services', arrayContainsAny: c)
                  .where('LastConfession',
                      isLessThan: Timestamp.fromDate(
                          DateTime.now().subtract(const Duration(days: 7))))
                  .limit(20)
                  .get(source))))
          .expand((e) => e.docs)
          .map((d) => d.data()['Name'] as String)
          .toList());
    }
  }

  if (persons.isNotEmpty || !f.kReleaseMode)
    await FlutterLocalNotificationsPlugin().show(
        0,
        'انذار الاعتراف',
        persons.join(', '),
        const NotificationDetails(
          android: AndroidNotificationDetails(
              'Confessions', 'إشعارات الاعتراف', 'إشعارات الاعتراف',
              icon: 'warning',
              autoCancel: false,
              visibility: NotificationVisibility.secret,
              showWhen: false),
        ),
        payload: 'Confessions');
}

Future<void> showErrorDialog(BuildContext context, String? message,
    {String? title}) async {
  return showDialog(
    context: context,
    barrierDismissible: false, // user must tap button!
    builder: (BuildContext context) => AlertDialog(
      title: title != null ? Text(title) : null,
      content: Text(message!),
      actions: <Widget>[
        TextButton(
          onPressed: () {
            navigator.currentState!.pop();
          },
          child: const Text('حسنًا'),
        ),
      ],
    ),
  );
}

Future<void> showErrorUpdateDataDialog(
    {BuildContext? context, bool pushApp = true}) async {
  if (pushApp ||
      Hive.box('Settings').get('DialogLastShown') !=
          tranucateToDay().millisecondsSinceEpoch) {
    await showDialog(
      context: context!,
      builder: (context) => AlertDialog(
        content: const Text(
            'الخادم مثال حى للنفس التائبة ـ يمارس التوبة فى حياته الخاصة'
            ' وفى أصوامـه وصلواته ، وحب المسـيح المصلوب\n'
            'أبونا بيشوي كامل \n'
            'يرجي مراجعة حياتك الروحية والاهتمام بها'),
        actions: [
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              shape: StadiumBorder(side: BorderSide(color: primaries[13]!)),
            ),
            onPressed: () async {
              final user = User.instance;
              await navigator.currentState!
                  .pushNamed('UpdateUserDataError', arguments: user);
              if (user.lastTanawol != null &&
                  user.lastConfession != null &&
                  ((user.lastTanawol!.millisecondsSinceEpoch + 2592000000) >
                          DateTime.now().millisecondsSinceEpoch &&
                      (user.lastConfession!.millisecondsSinceEpoch +
                              5184000000) >
                          DateTime.now().millisecondsSinceEpoch)) {
                navigator.currentState!.pop();
                if (pushApp)
                  // ignore: unawaited_futures
                  navigator.currentState!.pushReplacement(
                      MaterialPageRoute(builder: (context) => const App()));
              }
            },
            icon: const Icon(Icons.update),
            label: const Text('تحديث بيانات التناول والاعتراف'),
          ),
          TextButton.icon(
            onPressed: () => navigator.currentState!.pop(),
            icon: const Icon(Icons.close),
            label: const Text('تم'),
          ),
        ],
      ),
    );
    await Hive.box('Settings')
        .put('DialogLastShown', tranucateToDay().millisecondsSinceEpoch);
  }
}

void showKodasNotification() async {
  await Firebase.initializeApp();
  if (auth.FirebaseAuth.instance.currentUser == null) return;

  await Hive.initFlutter();

  const FlutterSecureStorage secureStorage = FlutterSecureStorage();
  final containsEncryptionKey = await secureStorage.containsKey(key: 'key');
  if (!containsEncryptionKey)
    await secureStorage.write(
        key: 'key', value: base64Url.encode(Hive.generateSecureKey()));

  final encryptionKey =
      base64Url.decode((await secureStorage.read(key: 'key'))!);

  await Hive.openBox(
    'User',
    encryptionCipher: HiveAesCipher(encryptionKey),
  );

  await User.instance.initialized;
  final source = GetOptions(
      source:
          (await Connectivity().checkConnectivity()) == ConnectivityResult.none
              ? Source.cache
              : Source.serverAndCache);

  final classes = await Class.getAllForUser().first;

  await Future.delayed(const Duration(seconds: 4));

  final List<String> persons = [];

  if (User.instance.superAccess) {
    persons.addAll((await FirebaseFirestore.instance
            .collection('Persons')
            .where('LastKodas',
                isLessThan: Timestamp.fromDate(
                    DateTime.now().subtract(const Duration(days: 7))))
            .limit(20)
            .get(source))
        .docs
        .map((e) => e.data()['Name'] as String)
        .toList());
  } else {
    //Persons from Classes
    if (classes.isNotEmpty) if (classes.length <= 10) {
      persons.addAll((await FirebaseFirestore.instance
              .collection('Persons')
              .where('ClassId', whereIn: classes.map((e) => e.ref).toList())
              .where('LastKodas',
                  isLessThan: Timestamp.fromDate(
                      DateTime.now().subtract(const Duration(days: 7))))
              .limit(20)
              .get(source))
          .docs
          .map((d) => d.data()['Name'] as String)
          .toList());
    } else {
      persons.addAll((await Future.wait(classes.split(10).map((c) =>
              FirebaseFirestore.instance
                  .collection('Persons')
                  .where('ClassId', whereIn: c.map((e) => e.ref).toList())
                  .where('LastKodas',
                      isLessThan: Timestamp.fromDate(
                          DateTime.now().subtract(const Duration(days: 7))))
                  .limit(20)
                  .get(source))))
          .expand((e) => e.docs)
          .map((d) => d.data()['Name'] as String)
          .toList());
    }
    //Persons from Services
    if (User.instance.adminServices
        .isNotEmpty) if (User.instance.adminServices.length <= 10) {
      persons.addAll((await FirebaseFirestore.instance
              .collection('Persons')
              .where('Services', arrayContainsAny: User.instance.adminServices)
              .where('LastKodas',
                  isLessThan: Timestamp.fromDate(
                      DateTime.now().subtract(const Duration(days: 7))))
              .limit(20)
              .get(source))
          .docs
          .map((d) => d.data()['Name'] as String)
          .toList());
    } else {
      persons.addAll((await Future.wait(User.instance.adminServices
              .split(10)
              .map((c) => FirebaseFirestore.instance
                  .collection('Persons')
                  .where('Services', arrayContainsAny: c)
                  .where('LastKodas',
                      isLessThan: Timestamp.fromDate(
                          DateTime.now().subtract(const Duration(days: 7))))
                  .limit(20)
                  .get(source))))
          .expand((e) => e.docs)
          .map((d) => d.data()['Name'] as String)
          .toList());
    }
  }

  if (persons.isNotEmpty || !f.kReleaseMode)
    await FlutterLocalNotificationsPlugin().show(
        4,
        'انذار حضور القداس',
        persons.join(', '),
        const NotificationDetails(
          android: AndroidNotificationDetails(
              'Kodas', 'إشعارات حضور القداس', 'إشعارات حضور القداس',
              icon: 'warning',
              autoCancel: false,
              visibility: NotificationVisibility.secret,
              showWhen: false),
        ),
        payload: 'Kodas');
}

void showMeetingNotification() async {
  await Firebase.initializeApp();
  if (auth.FirebaseAuth.instance.currentUser == null) return;

  await Hive.initFlutter();

  const FlutterSecureStorage secureStorage = FlutterSecureStorage();
  final containsEncryptionKey = await secureStorage.containsKey(key: 'key');
  if (!containsEncryptionKey)
    await secureStorage.write(
        key: 'key', value: base64Url.encode(Hive.generateSecureKey()));

  final encryptionKey =
      base64Url.decode((await secureStorage.read(key: 'key'))!);

  await Hive.openBox(
    'User',
    encryptionCipher: HiveAesCipher(encryptionKey),
  );

  await User.instance.initialized;
  final source = GetOptions(
      source:
          (await Connectivity().checkConnectivity()) == ConnectivityResult.none
              ? Source.cache
              : Source.serverAndCache);

  final classes = await Class.getAllForUser().first;

  await Future.delayed(const Duration(seconds: 4));

  final List<String> persons = [];

  if (User.instance.superAccess) {
    persons.addAll((await FirebaseFirestore.instance
            .collection('Persons')
            .where('LastMeeting',
                isLessThan: Timestamp.fromDate(
                    DateTime.now().subtract(const Duration(days: 7))))
            .limit(20)
            .get(source))
        .docs
        .map((e) => e.data()['Name'] as String)
        .toList());
  } else {
    //Persons from Classes
    if (classes.isNotEmpty) if (classes.length <= 10) {
      persons.addAll((await FirebaseFirestore.instance
              .collection('Persons')
              .where('ClassId', whereIn: classes.map((e) => e.ref).toList())
              .where('LastMeeting',
                  isLessThan: Timestamp.fromDate(
                      DateTime.now().subtract(const Duration(days: 7))))
              .limit(20)
              .get(source))
          .docs
          .map((d) => d.data()['Name'] as String)
          .toList());
    } else {
      persons.addAll((await Future.wait(classes.split(10).map((c) =>
              FirebaseFirestore.instance
                  .collection('Persons')
                  .where('ClassId', whereIn: c.map((e) => e.ref).toList())
                  .where('LastMeeting',
                      isLessThan: Timestamp.fromDate(
                          DateTime.now().subtract(const Duration(days: 7))))
                  .limit(20)
                  .get(source))))
          .expand((e) => e.docs)
          .map((d) => d.data()['Name'] as String)
          .toList());
    }
    //Persons from Services
    if (User.instance.adminServices
        .isNotEmpty) if (User.instance.adminServices.length <= 10) {
      persons.addAll((await FirebaseFirestore.instance
              .collection('Persons')
              .where('Services', arrayContainsAny: User.instance.adminServices)
              .where('LastMeeting',
                  isLessThan: Timestamp.fromDate(
                      DateTime.now().subtract(const Duration(days: 7))))
              .limit(20)
              .get(source))
          .docs
          .map((d) => d.data()['Name'] as String)
          .toList());
    } else {
      persons.addAll((await Future.wait(User.instance.adminServices
              .split(10)
              .map((c) => FirebaseFirestore.instance
                  .collection('Persons')
                  .where('Services', arrayContainsAny: c)
                  .where('LastMeeting',
                      isLessThan: Timestamp.fromDate(
                          DateTime.now().subtract(const Duration(days: 7))))
                  .limit(20)
                  .get(source))))
          .expand((e) => e.docs)
          .map((d) => d.data()['Name'] as String)
          .toList());
    }
  }

  if (persons.isNotEmpty || !f.kReleaseMode)
    await FlutterLocalNotificationsPlugin().show(
        3,
        'انذار حضور الاجتماع',
        persons.join(', '),
        const NotificationDetails(
          android: AndroidNotificationDetails(
              'Meeting', 'إشعارات حضور الاجتماع', 'إشعارات حضور الاجتماع',
              icon: 'warning',
              autoCancel: false,
              visibility: NotificationVisibility.secret,
              showWhen: false),
        ),
        payload: 'Meeting');
}

Future<void> showMessage(no.Notification notification) async {
  final attachement = await getLinkObject(
    Uri.parse(notification.attachement!),
  );
  final String scndLine = await attachement.getSecondLine() ?? '';
  final user = notification.from != ''
      ? await FirebaseFirestore.instance
          .doc('Users/${notification.from}')
          .get(dataSource)
      : null;
  await showDialog(
    context: navigator.currentContext!,
    builder: (context) => AlertDialog(
      title: Text(notification.title!),
      content: SizedBox(
        width: 280,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              notification.content!,
              style: const TextStyle(fontSize: 18),
            ),
            if (user != null)
              Card(
                color: attachement.color != Colors.transparent
                    ? attachement.color
                    : null,
                child: ListTile(
                  title: Text(attachement.name),
                  subtitle: Text(
                    scndLine,
                  ),
                  leading: attachement is User
                      ? attachement.getPhoto()
                      : attachement.photo(),
                  onTap: () {
                    if (attachement is Class) {
                      classTap(attachement);
                    } else if (attachement is Person) {
                      personTap(attachement);
                    } else if (attachement is User) {
                      userTap(attachement);
                    }
                  },
                ),
              )
            else
              CachedNetworkImage(imageUrl: attachement.url),
            Text('من: ' +
                (user != null
                    ? User.fromDoc(
                        user,
                      ).name
                    : 'مسؤلو البرنامج')),
            Text(
              DateFormat('yyyy/M/d h:m a', 'ar-EG').format(
                DateTime.fromMillisecondsSinceEpoch(notification.time),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

Future<void> showPendingMessage() async {
  final pendingMessage = await FirebaseMessaging.instance.getInitialMessage();
  if (pendingMessage != null) {
    // ignore: unawaited_futures
    navigator.currentState!.pushNamed('Notifications');
    if (pendingMessage.data['type'] == 'Message')
      await showMessage(
        no.Notification.fromMessage(pendingMessage.data),
      );
    else
      await processLink(Uri.parse(pendingMessage.data['attachement']));
  }
}

void showTanawolNotification() async {
  await Firebase.initializeApp();
  if (auth.FirebaseAuth.instance.currentUser == null) return;

  await Hive.initFlutter();

  const FlutterSecureStorage secureStorage = FlutterSecureStorage();
  final containsEncryptionKey = await secureStorage.containsKey(key: 'key');
  if (!containsEncryptionKey)
    await secureStorage.write(
        key: 'key', value: base64Url.encode(Hive.generateSecureKey()));

  final encryptionKey =
      base64Url.decode((await secureStorage.read(key: 'key'))!);

  await Hive.openBox(
    'User',
    encryptionCipher: HiveAesCipher(encryptionKey),
  );

  await User.instance.initialized;
  final source = GetOptions(
      source:
          (await Connectivity().checkConnectivity()) == ConnectivityResult.none
              ? Source.cache
              : Source.serverAndCache);

  final classes = await Class.getAllForUser().first;

  await Future.delayed(const Duration(seconds: 4));

  final List<String> persons = [];

  if (User.instance.superAccess) {
    persons.addAll((await FirebaseFirestore.instance
            .collection('Persons')
            .where('LastTanawol',
                isLessThan: Timestamp.fromDate(
                    DateTime.now().subtract(const Duration(days: 7))))
            .limit(20)
            .get(source))
        .docs
        .map((e) => e.data()['Name'] as String)
        .toList());
  } else {
    //Persons from Classes
    if (classes.isNotEmpty) if (classes.length <= 10) {
      persons.addAll((await FirebaseFirestore.instance
              .collection('Persons')
              .where('ClassId', whereIn: classes.map((e) => e.ref).toList())
              .where('LastTanawol',
                  isLessThan: Timestamp.fromDate(
                      DateTime.now().subtract(const Duration(days: 7))))
              .limit(20)
              .get(source))
          .docs
          .map((d) => d.data()['Name'] as String)
          .toList());
    } else {
      persons.addAll((await Future.wait(classes.split(10).map((c) =>
              FirebaseFirestore.instance
                  .collection('Persons')
                  .where('ClassId', whereIn: c.map((e) => e.ref).toList())
                  .where('LastTanawol',
                      isLessThan: Timestamp.fromDate(
                          DateTime.now().subtract(const Duration(days: 7))))
                  .limit(20)
                  .get(source))))
          .expand((e) => e.docs)
          .map((d) => d.data()['Name'] as String)
          .toList());
    }
    //Persons from Services
    if (User.instance.adminServices
        .isNotEmpty) if (User.instance.adminServices.length <= 10) {
      persons.addAll((await FirebaseFirestore.instance
              .collection('Persons')
              .where('Services', arrayContainsAny: User.instance.adminServices)
              .where('LastTanawol',
                  isLessThan: Timestamp.fromDate(
                      DateTime.now().subtract(const Duration(days: 7))))
              .limit(20)
              .get(source))
          .docs
          .map((d) => d.data()['Name'] as String)
          .toList());
    } else {
      persons.addAll((await Future.wait(User.instance.adminServices
              .split(10)
              .map((c) => FirebaseFirestore.instance
                  .collection('Persons')
                  .where('Services', arrayContainsAny: c)
                  .where('LastTanawol',
                      isLessThan: Timestamp.fromDate(
                          DateTime.now().subtract(const Duration(days: 7))))
                  .limit(20)
                  .get(source))))
          .expand((e) => e.docs)
          .map((d) => d.data()['Name'] as String)
          .toList());
    }
  }

  if (persons.isNotEmpty || !f.kReleaseMode)
    await FlutterLocalNotificationsPlugin().show(
        1,
        'انذار التناول',
        persons.join(', '),
        const NotificationDetails(
          android: AndroidNotificationDetails(
              'Tanawol', 'إشعارات التناول', 'إشعارات التناول',
              icon: 'warning',
              autoCancel: false,
              visibility: NotificationVisibility.secret,
              showWhen: false),
        ),
        payload: 'Tanawol');
}

void showVisitNotification() async {
  await Firebase.initializeApp();
  if (auth.FirebaseAuth.instance.currentUser == null) return;

  await Hive.initFlutter();

  const FlutterSecureStorage secureStorage = FlutterSecureStorage();
  final containsEncryptionKey = await secureStorage.containsKey(key: 'key');
  if (!containsEncryptionKey)
    await secureStorage.write(
        key: 'key', value: base64Url.encode(Hive.generateSecureKey()));

  final encryptionKey =
      base64Url.decode((await secureStorage.read(key: 'key'))!);

  await Hive.openBox(
    'User',
    encryptionCipher: HiveAesCipher(encryptionKey),
  );

  await User.instance.initialized;
  final source = GetOptions(
      source:
          (await Connectivity().checkConnectivity()) == ConnectivityResult.none
              ? Source.cache
              : Source.serverAndCache);

  final classes = await Class.getAllForUser().first;

  await Future.delayed(const Duration(seconds: 4));

  final List<String> persons = [];

  if (User.instance.superAccess) {
    persons.addAll((await FirebaseFirestore.instance
            .collection('Persons')
            .where('LastVisit',
                isLessThan: Timestamp.fromDate(
                    DateTime.now().subtract(const Duration(days: 7))))
            .limit(20)
            .get(source))
        .docs
        .map((e) => e.data()['Name'] as String)
        .toList());
  } else {
    //Persons from Classes
    if (classes.isNotEmpty) if (classes.length <= 10) {
      persons.addAll((await FirebaseFirestore.instance
              .collection('Persons')
              .where('ClassId', whereIn: classes.map((e) => e.ref).toList())
              .where('LastVisit',
                  isLessThan: Timestamp.fromDate(
                      DateTime.now().subtract(const Duration(days: 7))))
              .limit(20)
              .get(source))
          .docs
          .map((d) => d.data()['Name'] as String)
          .toList());
    } else {
      persons.addAll((await Future.wait(classes.split(10).map((c) =>
              FirebaseFirestore.instance
                  .collection('Persons')
                  .where('ClassId', whereIn: c.map((e) => e.ref).toList())
                  .where('LastVisit',
                      isLessThan: Timestamp.fromDate(
                          DateTime.now().subtract(const Duration(days: 7))))
                  .limit(20)
                  .get(source))))
          .expand((e) => e.docs)
          .map((d) => d.data()['Name'] as String)
          .toList());
    }
    //Persons from Services
    if (User.instance.adminServices
        .isNotEmpty) if (User.instance.adminServices.length <= 10) {
      persons.addAll((await FirebaseFirestore.instance
              .collection('Persons')
              .where('Services', arrayContainsAny: User.instance.adminServices)
              .where('LastVisit',
                  isLessThan: Timestamp.fromDate(
                      DateTime.now().subtract(const Duration(days: 7))))
              .limit(20)
              .get(source))
          .docs
          .map((d) => d.data()['Name'] as String)
          .toList());
    } else {
      persons.addAll((await Future.wait(User.instance.adminServices
              .split(10)
              .map((c) => FirebaseFirestore.instance
                  .collection('Persons')
                  .where('Services', arrayContainsAny: c)
                  .where('LastVisit',
                      isLessThan: Timestamp.fromDate(
                          DateTime.now().subtract(const Duration(days: 7))))
                  .limit(20)
                  .get(source))))
          .expand((e) => e.docs)
          .map((d) => d.data()['Name'] as String)
          .toList());
    }
  }

  if (persons.isNotEmpty || !f.kReleaseMode)
    await FlutterLocalNotificationsPlugin().show(
        5,
        'انذار الافتقاد',
        persons.join(', '),
        const NotificationDetails(
          android: AndroidNotificationDetails(
              'Visit', 'إشعارات الافتقاد', 'إشعارات الافتقاد',
              icon: 'warning',
              autoCancel: false,
              visibility: NotificationVisibility.secret,
              showWhen: false),
        ),
        payload: 'Visit');
}

Future<int> storeNotification(RemoteMessage message) async {
  return Hive.box<Map<dynamic, dynamic>>('Notifications').add(message.data);
}

String toDurationString(Timestamp? date, {appendSince = true}) {
  if (date == null) return '';
  if (appendSince) return format(date.toDate(), locale: 'ar');
  return format(date.toDate(), locale: 'ar').replaceAll('منذ ', '');
}

Timestamp tranucateToDay({DateTime? time}) {
  time = time ?? DateTime.now();
  return Timestamp.fromDate(
      DateTime.utc(time.year, time.month, time.day).toLocal());
}

Timestamp mergeDayWithTime(DateTime day, DateTime time) {
  return Timestamp.fromDate(DateTime(day.year, day.month, day.day, time.hour,
      time.minute, time.second, time.millisecond, time.microsecond));
}

void userTap(User user) async {
  if (user.approved) {
    await navigator.currentState!.pushNamed('UserInfo', arguments: user);
  } else {
    final dynamic rslt = await showDialog(
        context: navigator.currentContext!,
        builder: (context) => AlertDialog(
              actions: <Widget>[
                TextButton.icon(
                  icon: const Icon(Icons.done),
                  label: const Text('نعم'),
                  onPressed: () => navigator.currentState!.pop(true),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.close),
                  label: const Text('لا'),
                  onPressed: () => navigator.currentState!.pop(false),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.close),
                  label: const Text('حذف المستخدم'),
                  onPressed: () => navigator.currentState!.pop('delete'),
                ),
              ],
              title: Text('${user.name} غير مُنشط هل تريد تنشيطه؟'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  user.getPhoto(false),
                  Text(
                    'البريد الاكتروني: ' + user.email,
                  ),
                ],
              ),
            ));
    if (rslt == true) {
      scaffoldMessenger.currentState!.showSnackBar(
        const SnackBar(
          content: LinearProgressIndicator(),
          duration: Duration(seconds: 15),
        ),
      );
      try {
        await FirebaseFunctions.instance
            .httpsCallable('approveUser')
            .call({'affectedUser': user.uid});
        user
          ..approved = true
          // ignore: invalid_use_of_visible_for_testing_member, invalid_use_of_protected_member
          ..notifyListeners();
        userTap(user);
        scaffoldMessenger.currentState!.hideCurrentSnackBar();
        scaffoldMessenger.currentState!.showSnackBar(
          const SnackBar(
            content: Text('تم بنجاح'),
            duration: Duration(seconds: 15),
          ),
        );
      } catch (err, stkTrace) {
        await FirebaseCrashlytics.instance
            .setCustomKey('LastErrorIn', 'Data.userTap');
        await FirebaseCrashlytics.instance.recordError(err, stkTrace);
      }
    } else if (rslt == 'delete') {
      scaffoldMessenger.currentState!.showSnackBar(
        const SnackBar(
          content: LinearProgressIndicator(),
          duration: Duration(seconds: 15),
        ),
      );
      try {
        await FirebaseFunctions.instance
            .httpsCallable('deleteUser')
            .call({'affectedUser': user.uid});
        scaffoldMessenger.currentState!.hideCurrentSnackBar();
        scaffoldMessenger.currentState!.showSnackBar(
          const SnackBar(
            content: Text('تم بنجاح'),
            duration: Duration(seconds: 15),
          ),
        );
      } catch (err, stkTrace) {
        await FirebaseCrashlytics.instance
            .setCustomKey('LastErrorIn', 'Data.userTap');
        await FirebaseCrashlytics.instance.recordError(err, stkTrace);
      }
    }
  }
}

class MessageIcon extends StatelessWidget {
  const MessageIcon(this.url, {Key? key}) : super(key: key);

  final String? url;

  Color get color => Colors.transparent;

  String get name => '';

  Widget getPhoto(BuildContext context) {
    return build(context);
  }

  Future<String> getSecondLine() async => '';

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints.expand(width: 55.2, height: 55.2),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: () => showDialog(
            context: context,
            builder: (context) => Dialog(
              child: Hero(
                tag: url!,
                child: CachedNetworkImage(
                  imageUrl: url!,
                  imageBuilder: (context, imageProvider) => PhotoView(
                    imageProvider: imageProvider,
                    tightMode: true,
                    enableRotation: true,
                  ),
                  progressIndicatorBuilder: (context, url, progress) =>
                      CircularProgressIndicator(value: progress.progress),
                ),
              ),
            ),
          ),
          child: CachedNetworkImage(
            memCacheHeight: 221,
            imageUrl: url!,
            progressIndicatorBuilder: (context, url, progress) =>
                CircularProgressIndicator(value: progress.progress),
          ),
        ),
      ),
    );
  }
}

class QueryIcon extends StatelessWidget {
  const QueryIcon({Key? key}) : super(key: key);

  Color get color => Colors.transparent;

  String get name => 'نتائج بحث';

  Widget getPhoto(BuildContext context) {
    return build(context);
  }

  Future<String> getSecondLine() async => '';

  @override
  Widget build(BuildContext context) {
    return Icon(Icons.search,
        size: MediaQuery.of(context).size.shortestSide / 7.2);
  }
}

extension BoolComparison on bool? {
  int compareTo(bool? o) {
    if (this == o) return 0;
    // ignore: use_if_null_to_convert_nulls_to_bools
    if (this == true) return -1;
    if (this == false) {
      // ignore: use_if_null_to_convert_nulls_to_bools
      if (o == true) return 1;
      return -1;
    }
    return 1;
  }
}

extension SplitList<T> on List<T> {
  List<List<T>> split(int length) {
    final List<List<T>> chunks = [];
    for (int i = 0; i < this.length; i += length) {
      chunks
          .add(sublist(i, i + length > this.length ? this.length : i + length));
    }
    return chunks;
  }
}
