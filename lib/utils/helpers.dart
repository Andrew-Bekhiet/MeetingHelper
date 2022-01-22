import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:churchdata_core/churchdata_core.dart';
import 'package:collection/collection.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:firebase_dynamic_links/firebase_dynamic_links.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_storage/firebase_storage.dart' hide ListOptions;
import 'package:flutter/foundation.dart' as f;
import 'package:flutter/material.dart' hide Notification;
import 'package:flutter_local_notifications/flutter_local_notifications.dart'
    hide Person;
import 'package:get_it/get_it.dart';
import 'package:meetinghelper/models/data/class.dart';
import 'package:meetinghelper/models/data/service.dart';
import 'package:meetinghelper/models/data_object_tap_handler.dart';
import 'package:meetinghelper/models/search/search_filters.dart';
import 'package:meetinghelper/secrets.dart';
import 'package:meetinghelper/views/services_list.dart';
import 'package:photo_view/photo_view.dart';
import 'package:provider/provider.dart';
import 'package:rxdart/rxdart.dart' hide Notification;
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:spreadsheet_decoder/spreadsheet_decoder.dart';

import '../main.dart';
import '../models/data/person.dart';
import '../models/data/user.dart';
import '../models/history/history_record.dart';
import '../utils/globals.dart';
import '../views/search_query.dart';

Stream<Map<PreferredStudyYear?, List<T>>>
    servicesByStudyYearRef<T extends DataObject>([List<T>? services]) {
  assert(isSubtype<Class, T>() ||
      isSubtype<Service, T>() ||
      (T == DataObject && services == null));

  return Rx.combineLatest3<Map<JsonRef, StudyYear>, List<Class>, List<Service>,
          Map<PreferredStudyYear?, List<T>>>(
      GetIt.I<DatabaseRepository>()
          .collection('StudyYears')
          .orderBy('Grade')
          .snapshots()
          .map<Map<JsonRef, StudyYear>>(
            (sys) => {
              for (final sy in sys.docs) sy.reference: StudyYear.fromDoc(sy)
            },
          ),
      T == Class
          ? services != null
              ? Stream.value(services as List<Class>)
              : MHAuthRepository.I.userStream.switchMap(
                  (user) => (user!.permissions.superAccess
                          ? GetIt.I<DatabaseRepository>()
                              .collection('Classes')
                              .orderBy('StudyYear')
                              .orderBy('Gender')
                              .snapshots()
                          : GetIt.I<DatabaseRepository>()
                              .collection('Classes')
                              .where('Allowed', arrayContains: user.uid)
                              .orderBy('StudyYear')
                              .orderBy('Gender')
                              .snapshots())
                      .map(
                    (cs) => cs.docs.map(Class.fromDoc).toList(),
                  ),
                )
          : Stream.value([]),
      T == Service
          ? services != null
              ? Stream.value(services as List<Service>)
              : Service.getAllForUser()
          : Stream.value([]),
      //

      (studyYears, classes, services) {
    final combined = [...classes, ...services];

    mergeSort<T>(combined.cast<T>(), compare: (c, c2) {
      if (c is Class && c2 is Class) {
        if (c.studyYear == c2.studyYear) return c.gender.compareTo(c2.gender);
        return studyYears[c.studyYear]!
            .grade
            .compareTo(studyYears[c2.studyYear]!.grade);
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
  assert(T == Class || T == Service || T == DataObject);

  return Rx.combineLatest3<Map<JsonRef, StudyYear>, List<Class>, List<Service>,
          Map<PreferredStudyYear?, List<T>>>(
      GetIt.I<DatabaseRepository>()
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
          : GetIt.I<DatabaseRepository>()
              .collection('Classes')
              .where('Allowed', arrayContains: uid)
              .orderBy('StudyYear')
              .orderBy('Gender')
              .snapshots()
              .map((cs) => cs.docs.map(Class.fromDoc).toList()),
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
            .grade
            .compareTo(studyYears[c2.studyYear]!.grade);
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
      return await MHAuthRepository.userFromUID(
          deepLink.queryParameters['UID'] ?? 'null');
    } else if (deepLink.pathSegments[0] == 'viewQuery') {
      return const QueryIcon();
    }
    // ignore: empty_catches
  } catch (err) {}
  return null;
}

List<RadioListTile> getOrderingOptions(
    BehaviorSubject<OrderOptions> orderOptions, Type type) {
  return (type == Class
          ? Class.propsMetadata()
          : type == Service
              ? Service.propsMetadata()
              : Person.propsMetadata())
      .entries
      .map(
        (e) => RadioListTile<String>(
          value: e.key,
          groupValue: orderOptions.value.orderBy,
          title: Text(e.value.label),
          onChanged: (value) {
            orderOptions.add(
                OrderOptions(orderBy: value!, asc: orderOptions.value.asc));
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

bool notService(String subcollection) =>
    subcollection == 'Meeting' ||
    subcollection == 'Kodas' ||
    subcollection == 'Confession';

void historyTap(HistoryDayBase? history) async {
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
              customMetadata: {
                'createdBy': MHAuthRepository.I.currentUser!.uid,
              },
            ),
          );

      scaffoldMessenger.currentState!.hideCurrentSnackBar();
      scaffoldMessenger.currentState!.showSnackBar(
        const SnackBar(
          content: Text('جار استيراد الملف...'),
          duration: Duration(minutes: 9),
        ),
      );
      await GetIt.I<FunctionsService>()
          .httpsCallable('importFromExcel')
          .call({'fileId': filename + '.xlsx'});
      scaffoldMessenger.currentState!.hideCurrentSnackBar();
      scaffoldMessenger.currentState!.showSnackBar(
        const SnackBar(
          content: Text('تم الاستيراد بنجاح'),
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
  await NotificationsService.storeNotification(message);
}

void onForegroundMessage(RemoteMessage message, [BuildContext? context]) async {
  context ??= mainScfld.currentContext;
  await NotificationsService.storeNotification(message);
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

Stream<Map<Class?, List<User>>> usersByClass(List<User> users) {
  // return users.groupListsBy((user) => user.classId);

  return Rx.combineLatest2<JsonQuery, JsonQuery, Map<Class?, List<User>>>(
    GetIt.I<DatabaseRepository>()
        .collection('StudyYears')
        .orderBy('Grade')
        .snapshots(),
    MHAuthRepository.I.userStream.whereType<User>().switchMap((user) =>
        user.permissions.superAccess
            ? GetIt.I<DatabaseRepository>()
                .collection('Classes')
                .orderBy('StudyYear')
                .orderBy('Gender')
                .snapshots()
            : GetIt.I<DatabaseRepository>()
                .collection('Classes')
                .where('Allowed', arrayContains: user.uid)
                .orderBy('StudyYear')
                .orderBy('Gender')
                .snapshots()),
    (sys, cs) {
      final Map<JsonRef, StudyYear> studyYears = {
        for (final sy in sys.docs) sy.reference: StudyYear.fromDoc(sy)
      };
      final unknownStudyYearRef =
          GetIt.I<DatabaseRepository>().collection('StudyYears').doc('Unknown');

      studyYears[unknownStudyYearRef] = StudyYear(
        ref: unknownStudyYearRef,
        name: 'غير معروفة',
        grade: 10000000,
      );

      final classesByRef = {
        for (final c in cs.docs.map(Class.fromDoc).toList()) c.ref: c
      };

      final rslt = groupBy<User, Class?>(
        users,
        (user) => user.classId == null
            ? null
            : classesByRef[user.classId] ??
                Class(
                  name: '{لا يمكن قراءة اسم الفصل}',
                  color: Colors.redAccent,
                  ref: GetIt.I<DatabaseRepository>()
                      .collection('Classes')
                      .doc('Unknown'),
                ),
      ).entries;

      mergeSort<MapEntry<Class?, List<User>>>(rslt.toList(), compare: (c, c2) {
        if (c.key == null || c.key!.name == '{لا يمكن قراءة اسم الفصل}')
          return 1;

        if (c2.key == null || c2.key!.name == '{لا يمكن قراءة اسم الفصل}')
          return -1;

        if (studyYears[c.key!.studyYear!] == studyYears[c2.key!.studyYear!])
          return c.key!.gender.compareTo(c2.key!.gender);

        return studyYears[c.key!.studyYear]!
            .grade
            .compareTo(studyYears[c2.key!.studyYear]!.grade);
      });

      return {for (final e in rslt) e.key: e.value};
    },
  );
}

Stream<Map<Class?, List<Person>>> personsByClassRef([List<Person>? persons]) {
  // return persons.groupListsBy((user) => user.classId);

  return Rx.combineLatest3<Map<JsonRef, StudyYear>, List<Person>, JsonQuery,
      Map<Class, List<Person>>>(
    GetIt.I<DatabaseRepository>()
        .collection('StudyYears')
        .orderBy('Grade')
        .snapshots()
        .map(
          (sys) =>
              {for (final sy in sys.docs) sy.reference: StudyYear.fromDoc(sy)},
        ),
    persons != null ? Stream.value(persons) : Person.getAllForUser(),
    MHAuthRepository.I.userStream.whereType().switchMap((user) =>
        user.superAccess
            ? GetIt.I<DatabaseRepository>()
                .collection('Classes')
                .orderBy('StudyYear')
                .orderBy('Gender')
                .snapshots()
            : GetIt.I<DatabaseRepository>()
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
          .map(Class.fromDoc)
          .where((c) => personsByClassRef[c.ref] != null)
          .toList();

      mergeSort<Class>(classes, compare: (c, c2) {
        if (c.studyYear == c2.studyYear) return c.gender.compareTo(c2.gender);
        return studyYears[c.studyYear]!
            .grade
            .compareTo(studyYears[c2.studyYear]!.grade);
      });

      return {for (final c in classes) c: personsByClassRef[c.ref]!};
    },
  );
}

Stream<Map<StudyYear?, List<T>>> personsByStudyYearRef<T extends Person>(
    [List<T>? persons]) {
  // return persons.groupListsBy((p) => p.studyYear);

  return Rx.combineLatest2<Map<JsonRef, StudyYear>, List<T>,
      Map<StudyYear?, List<T>>>(
    GetIt.I<DatabaseRepository>()
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
            studyYears[person.key]: person.value
      };
    },
  );
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
                'collection': 'Persons',
                'fieldPath': 'BirthDay',
                'operator': '=',
                'queryValue': 'T' +
                    (now - (now % Duration.millisecondsPerDay)).toString(),
                'order': 'false',
                'orderBy': 'BirthDay',
                'descending': 'false',
              });
            },
          ),
        );
      });
    } else if (['Confession', 'Meeting', 'Kodas', 'Tanawol', 'Visit']
        .contains(notificationDetails.payload ?? payload)) {
      WidgetsBinding.instance!.addPostFrameCallback((_) async {
        await Future.delayed(const Duration(milliseconds: 900), () => null);
        await navigator.currentState!.push(
          MaterialPageRoute(
            builder: (context) {
              final now = DateTime.now().millisecondsSinceEpoch;
              return SearchQuery(query: {
                'collection': 'Persons',
                'fieldPath': 'Last' + (notificationDetails.payload ?? payload)!,
                'operator': '<',
                'queryValue': 'T' +
                    ((now - (now % Duration.millisecondsPerDay)) -
                            (Duration.millisecondsPerDay * 7))
                        .toString(),
                'order': 'true',
                'orderBy': 'Last' + (notificationDetails.payload ?? payload)!,
                'descending': 'false',
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
        GetIt.I<MHDataObjectTapHandler>().classTap(
          Class.fromDoc(await GetIt.I<DatabaseRepository>()
              .doc('Classes/${deepLink.queryParameters['ClassId']}')
              .get()),
        );
      } else if (deepLink.pathSegments[0] == 'viewPerson') {
        GetIt.I<MHDataObjectTapHandler>().personTap(
          Person.fromDoc(await GetIt.I<DatabaseRepository>()
              .doc('Persons/${deepLink.queryParameters['PersonId']}')
              .get()),
        );
      } else if (deepLink.pathSegments[0] == 'viewQuery') {
        await navigator.currentState!.push(
          MaterialPageRoute(
            builder: (c) => SearchQuery(
              query: deepLink.queryParameters,
            ),
          ),
        );
      } else if (deepLink.pathSegments[0] == 'viewUser') {
        if (MHAuthRepository.I.currentUser!.permissions.manageUsers) {
          GetIt.I<MHDataObjectTapHandler>().userTap(
            (await MHAuthRepository.userFromUID(
                deepLink.queryParameters['UID']))!,
          );
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
          Provider<ListController<Class?, User>>(
            create: (_) => ListController<Class?, User>(
              objectsPaginatableStream: PaginatableStream.loadAll(
                stream: GetIt.I<DatabaseRepository>()
                    .collection('Users')
                    .snapshots()
                    .map(
                      (s) => s.docs.map(User.fromDoc).toList(),
                    ),
              ),
              groupingStream: Stream.value(true),
              groupByStream: usersByClass,
            )..enterSelectionMode(),
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
                      .read<ListController<Class?, User>>()
                      .currentSelection
                      ?.toList());
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
                    context.read<ListController<Class?, User>>().searchSubject,
                textStyle: Theme.of(context).textTheme.bodyText2,
              ),
              Expanded(
                child: DataObjectListView<Class?, User>(
                  itemBuilder: (
                    current, {
                    onLongPress,
                    onTap,
                    trailing,
                    subtitle,
                  }) =>
                      DataObjectWidget(
                    current,
                    onTap: () => onTap!(current),
                    trailing: trailing,
                    showSubtitle: false,
                  ),
                  controller: context.read<ListController<Class?, User>>(),
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
                          decoration: const InputDecoration(
                            labelText: 'عنوان الرسالة',
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
                            decoration: const InputDecoration(
                              labelText: 'محتوى الرسالة',
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
    if (attachement is Service) {
      link = 'Service?ServiceId=${attachement.id}';
    } else if (attachement is Class) {
      link = 'Class?ClassId=${attachement.id}';
    } else if (attachement is Person) {
      link = 'Person?PersonId=${attachement.id}';
    }
    await GetIt.I<FunctionsService>().httpsCallable('sendMessageToUsers').call({
      'users': users.map((e) => e.uid).toList(),
      'title': title.text,
      'body': 'أرسل إليك ${MHAuthRepository.I.currentUser!.name} رسالة',
      'content': content.text,
      'attachement': uriPrefix + '/view$link'
    });
  }
}

Future<void> recoverDoc(BuildContext context, String path) async {
  bool? nested = path.startsWith(
      RegExp('Deleted/\\d{4}-\\d{2}-\\d{2}/((Classes)|(Services))'));
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
      await GetIt.I<FunctionsService>().httpsCallable('recoverDoc').call({
        'deletedPath': path,
        'keepBackup': keepBackup,
        'nested': nested,
      });
      scaffoldMessenger.currentState!
          .showSnackBar(const SnackBar(content: Text('تم الاسترجاع بنجاح')));
    } catch (err, stack) {
      await Sentry.captureException(err,
          stackTrace: stack,
          withScope: (scope) =>
              scope.setTag('LasErrorIn', 'helpers.recoverDoc'));
    }
  }
}

Future<String> shareClass(Class _class) async => shareClassRaw(_class.id);

Future<String> shareClassRaw(String? id) async {
  return (await FirebaseDynamicLinks.instance.buildShortLink(
    DynamicLinkParameters(
      uriPrefix: uriPrefix,
      link: Uri.parse('https://meetinghelper.com/viewClass?ClassId=$id'),
      androidParameters: androidParameters,
      iosParameters: iosParameters,
    ),
    shortLinkType: ShortDynamicLinkType.unguessable,
  ))
      .shortUrl
      .toString();
}

Future<String> shareService(Service service) async =>
    shareServiceRaw(service.id);

Future<String> shareServiceRaw(String? id) async {
  return (await FirebaseDynamicLinks.instance.buildShortLink(
    DynamicLinkParameters(
      uriPrefix: uriPrefix,
      link: Uri.parse('https://meetinghelper.com/viewService?ServiceId=$id'),
      androidParameters: androidParameters,
      iosParameters: iosParameters,
    ),
    shortLinkType: ShortDynamicLinkType.unguessable,
  ))
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
  return (await FirebaseDynamicLinks.instance.buildShortLink(
    DynamicLinkParameters(
      uriPrefix: uriPrefix,
      link: Uri.parse(
          'https://meetinghelper.com/viewHistoryRecord?HistoryId=$id'),
      androidParameters: androidParameters,
      iosParameters: iosParameters,
    ),
    shortLinkType: ShortDynamicLinkType.unguessable,
  ))
      .shortUrl
      .toString();
}

Future<String> sharePerson(Person person) async {
  return sharePersonRaw(person.id);
}

Future<String> sharePersonRaw(String? id) async {
  return (await FirebaseDynamicLinks.instance.buildShortLink(
    DynamicLinkParameters(
      uriPrefix: uriPrefix,
      link: Uri.parse('https://meetinghelper.com/viewPerson?PersonId=$id'),
      androidParameters: androidParameters,
      iosParameters: iosParameters,
    ),
    shortLinkType: ShortDynamicLinkType.unguessable,
  ))
      .shortUrl
      .toString();
}

Future<String> shareQuery(Map<String, Object?> query) async {
  return (await FirebaseDynamicLinks.instance.buildShortLink(
    DynamicLinkParameters(
      uriPrefix: uriPrefix,
      link: Uri.https('meetinghelper.com', 'viewQuery', query),
      androidParameters: androidParameters,
      iosParameters: iosParameters,
    ),
    shortLinkType: ShortDynamicLinkType.unguessable,
  ))
      .shortUrl
      .toString();
}

Future<String> shareUser(User user) async => shareUserRaw(user.uid);

Future<String> shareUserRaw(String? uid) async {
  return (await FirebaseDynamicLinks.instance.buildShortLink(
    DynamicLinkParameters(
      uriPrefix: uriPrefix,
      link: Uri.parse('https://meetinghelper.com/viewUser?UID=$uid'),
      androidParameters: androidParameters,
      iosParameters: iosParameters,
    ),
    shortLinkType: ShortDynamicLinkType.unguessable,
  ))
      .shortUrl
      .toString();
}

void showBirthDayNotification() async {
  await initConfigs();

  await init(
    sentryDSN: sentryDSN,
    overrides: {
      AuthRepository: () {
        final instance = MHAuthRepository();

        GetIt.I.registerSingleton<MHAuthRepository>(instance);

        return instance;
      },
    },
  );

  if (MHAuthRepository.I.currentUser == null) return;

  final persons = await Person.getAllForUser(
      queryCompleter: (q, _, __) => q
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
          .limit(20)).first;

  if (persons.isNotEmpty || !f.kReleaseMode)
    await FlutterLocalNotificationsPlugin().show(
      2,
      'أعياد الميلاد',
      persons.map((p) => p.name).join(', '),
      NotificationDetails(
        android: AndroidNotificationDetails(
          'Birthday',
          'إشعارات أعياد الميلاد',
          channelDescription: 'إشعارات أعياد الميلاد',
          icon: 'birthday',
          autoCancel: false,
          visibility: NotificationVisibility.secret,
          showWhen: false,
          styleInformation: BigTextStyleInformation(
            persons.map((p) => p.name).join(', '),
          ),
        ),
      ),
      payload: 'Birthday',
    );
}

Future<List<T>?> selectServices<T extends DataObject>(List<T>? selected) async {
  final _controller = ServicesListController<T>(
    objectsPaginatableStream:
        PaginatableStream.loadAll(stream: Stream.value([])),
    groupByStream: (_) => servicesByStudyYearRef<T>(),
  )..selectAll(selected);

  if (await navigator.currentState!.push(
        MaterialPageRoute(
          builder: (context) => Scaffold(
            appBar: AppBar(
              title: const Text('اختر الفصول'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.select_all),
                  onPressed: _controller.selectAll,
                  tooltip: 'تحديد الكل',
                ),
                IconButton(
                  icon: const Icon(Icons.check_box_outline_blank),
                  onPressed: _controller.deselectAll,
                  tooltip: 'تحديد لا شئ',
                ),
                IconButton(
                  icon: const Icon(Icons.done),
                  onPressed: () => navigator.currentState!.pop(true),
                  tooltip: 'تم',
                ),
              ],
            ),
            body: ServicesList<T>(
              options: _controller,
              autoDisposeController: false,
            ),
          ),
        ),
      ) ==
      true) {
    unawaited(_controller.dispose());
    return _controller.currentSelection?.whereType<T>().toList();
  }
  await _controller.dispose();
  return null;
}

void showConfessionNotification() async {
  await initConfigs();

  await init(
    sentryDSN: sentryDSN,
    overrides: {
      AuthRepository: () {
        final instance = MHAuthRepository();

        GetIt.I.registerSingleton<MHAuthRepository>(instance);

        return instance;
      },
    },
  );

  if (MHAuthRepository.I.currentUser == null) return;

  final persons = await Person.getAllForUser(
    queryCompleter: (q, _, __) => q
        .where(
          'LastConfession',
          isLessThan: Timestamp.fromDate(
              DateTime.now().subtract(const Duration(days: 7))),
        )
        .limit(20),
  ).first;

  if (persons.isNotEmpty || !f.kReleaseMode)
    await FlutterLocalNotificationsPlugin().show(
      0,
      'انذار الاعتراف',
      persons.map((p) => p.name).join(', '),
      NotificationDetails(
        android: AndroidNotificationDetails(
          'Confession',
          'إشعارات الاعتراف',
          channelDescription: 'إشعارات الاعتراف',
          icon: 'warning',
          autoCancel: false,
          visibility: NotificationVisibility.secret,
          showWhen: false,
          styleInformation: BigTextStyleInformation(
            persons.map((p) => p.name).join(', '),
          ),
        ),
      ),
      payload: 'Confession',
    );
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
      GetIt.I<CacheRepository>().box('Settings').get('DialogLastShown') !=
          DateTime.now().truncateToDay().millisecondsSinceEpoch) {
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
              final user = MHAuthRepository.I.currentUser!;
              await navigator.currentState!
                  .pushNamed('UpdateUserDataError', arguments: user);
              if (user.permissions.lastTanawol != null &&
                  user.permissions.lastConfession != null &&
                  ((user.permissions.lastTanawol!.millisecondsSinceEpoch +
                              2592000000) >
                          DateTime.now().millisecondsSinceEpoch &&
                      (user.permissions.lastConfession!.millisecondsSinceEpoch +
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
    await GetIt.I<CacheRepository>().box('Settings').put('DialogLastShown',
        DateTime.now().truncateToDay().millisecondsSinceEpoch);
  }
}

void showKodasNotification() async {
  await initConfigs();

  await init(
    sentryDSN: sentryDSN,
    overrides: {
      AuthRepository: () {
        final instance = MHAuthRepository();

        GetIt.I.registerSingleton<MHAuthRepository>(instance);

        return instance;
      },
    },
  );

  if (MHAuthRepository.I.currentUser == null) return;

  final persons = await Person.getAllForUser(
    queryCompleter: (q, _, __) => q
        .where(
          'LastKodas',
          isLessThan: Timestamp.fromDate(
              DateTime.now().subtract(const Duration(days: 7))),
        )
        .limit(20),
  ).first;

  if (persons.isNotEmpty || !f.kReleaseMode)
    await FlutterLocalNotificationsPlugin().show(
      4,
      'انذار حضور القداس',
      persons.map((p) => p.name).join(', '),
      NotificationDetails(
        android: AndroidNotificationDetails(
          'Kodas',
          'إشعارات حضور القداس',
          channelDescription: 'إشعارات حضور القداس',
          icon: 'warning',
          autoCancel: false,
          visibility: NotificationVisibility.secret,
          showWhen: false,
          styleInformation: BigTextStyleInformation(
            persons.map((p) => p.name).join(', '),
          ),
        ),
      ),
      payload: 'Kodas',
    );
}

void showMeetingNotification() async {
  await initConfigs();

  await init(
    sentryDSN: sentryDSN,
    overrides: {
      AuthRepository: () {
        final instance = MHAuthRepository();

        GetIt.I.registerSingleton<MHAuthRepository>(instance);

        return instance;
      },
    },
  );

  if (MHAuthRepository.I.currentUser == null) return;

  final persons = await Person.getAllForUser(
    queryCompleter: (q, _, __) => q
        .where(
          'LastMeeting',
          isLessThan: Timestamp.fromDate(
              DateTime.now().subtract(const Duration(days: 7))),
        )
        .limit(20),
  ).first;

  if (persons.isNotEmpty || !f.kReleaseMode)
    await FlutterLocalNotificationsPlugin().show(
      3,
      'انذار حضور الاجتماع',
      persons.map((p) => p.name).join(', '),
      NotificationDetails(
        android: AndroidNotificationDetails(
          'Meeting',
          'إشعارات حضور الاجتماع',
          channelDescription: 'إشعارات حضور الاجتماع',
          icon: 'warning',
          autoCancel: false,
          visibility: NotificationVisibility.secret,
          showWhen: false,
          styleInformation: BigTextStyleInformation(
            persons.map((p) => p.name).join(', '),
          ),
        ),
      ),
      payload: 'Meeting',
    );
}

void showTanawolNotification() async {
  await initConfigs();

  await init(
    sentryDSN: sentryDSN,
    overrides: {
      AuthRepository: () {
        final instance = MHAuthRepository();

        GetIt.I.registerSingleton<MHAuthRepository>(instance);

        return instance;
      },
    },
  );

  if (MHAuthRepository.I.currentUser == null) return;

  final persons = await Person.getAllForUser(
    queryCompleter: (q, _, __) => q
        .where(
          'LastTanawol',
          isLessThan: Timestamp.fromDate(
              DateTime.now().subtract(const Duration(days: 7))),
        )
        .limit(20),
  ).first;

  if (persons.isNotEmpty || !f.kReleaseMode)
    await FlutterLocalNotificationsPlugin().show(
      1,
      'انذار التناول',
      persons.map((p) => p.name).join(', '),
      NotificationDetails(
        android: AndroidNotificationDetails(
          'Tanawol',
          'إشعارات التناول',
          channelDescription: 'إشعارات التناول',
          icon: 'warning',
          autoCancel: false,
          visibility: NotificationVisibility.secret,
          showWhen: false,
          styleInformation: BigTextStyleInformation(
            persons.map((p) => p.name).join(', '),
          ),
        ),
      ),
      payload: 'Tanawol',
    );
}

void showVisitNotification() async {
  await initConfigs();

  await init(
    sentryDSN: sentryDSN,
    overrides: {
      AuthRepository: () {
        final instance = MHAuthRepository();

        GetIt.I.registerSingleton<MHAuthRepository>(instance);

        return instance;
      },
    },
  );

  if (MHAuthRepository.I.currentUser == null) return;

  final persons = await Person.getAllForUser(
    queryCompleter: (q, _, __) => q
        .where(
          'LastVisit',
          isLessThan: Timestamp.fromDate(
              DateTime.now().subtract(const Duration(days: 20))),
        )
        .limit(20),
  ).first;

  if (persons.isNotEmpty || !f.kReleaseMode)
    await FlutterLocalNotificationsPlugin().show(
      5,
      'انذار الافتقاد',
      persons.map((p) => p.name).join(', '),
      NotificationDetails(
        android: AndroidNotificationDetails(
          'Visit',
          'إشعارات الافتقاد',
          channelDescription: 'إشعارات الافتقاد',
          icon: 'warning',
          autoCancel: false,
          visibility: NotificationVisibility.secret,
          showWhen: false,
          styleInformation: BigTextStyleInformation(
            persons.map((p) => p.name).join(', '),
          ),
        ),
      ),
      payload: 'Visit',
    );
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
                  useOldImageOnUrlChange: true,
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
            useOldImageOnUrlChange: true,
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

T dump<T>(T obj, [String? label]) {
  // ignore: avoid_print
  if (f.kDebugMode) print((label ?? '') + obj.toString() + '\x1B[0m');
  return obj;
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
