import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:collection/collection.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_dynamic_links/firebase_dynamic_links.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_storage/firebase_storage.dart' hide ListOptions;
import 'package:flutter/foundation.dart' as f;
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart'
    hide Person;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:meetinghelper/models/data_object_widget.dart';
import 'package:meetinghelper/models/list_options.dart';
import 'package:meetinghelper/models/search_filters.dart';
import 'package:meetinghelper/views/lists/lists.dart';
import 'package:meetinghelper/views/services_list.dart';
import 'package:photo_view/photo_view.dart';
import 'package:provider/provider.dart';
import 'package:rxdart/rxdart.dart';
import 'package:spreadsheet_decoder/spreadsheet_decoder.dart';
import 'package:timeago/timeago.dart';

import '../main.dart';
import '../models/history_record.dart';
import '../models/mini_models.dart';
import '../models/models.dart';
import '../models/person.dart';
import '../models/super_classes.dart';
import '../models/theme_notifier.dart';
import '../models/user.dart';
import '../views/auth_screen.dart';
import '../views/list.dart';
import '../views/notification.dart' as no;
import '../views/search_query.dart';
import '../views/lists/users_list.dart';
import '../utils/globals.dart';

void changeTheme({Brightness brightness, @required BuildContext context}) {
  bool darkTheme = Hive.box('Settings').get('DarkTheme');
  bool greatFeastTheme =
      Hive.box('Settings').get('GreatFeastTheme', defaultValue: true);
  MaterialColor color = Colors.amber;
  Color accent = Colors.amberAccent;

  final riseDay = getRiseDay();
  if (greatFeastTheme &&
      DateTime.now()
          .isAfter(riseDay.subtract(Duration(days: 7, seconds: 20))) &&
      DateTime.now().isBefore(riseDay.subtract(Duration(days: 1)))) {
    color = black;
    accent = blackAccent;
    darkTheme = true;
  } else if (greatFeastTheme &&
      DateTime.now().isBefore(riseDay.add(Duration(days: 50, seconds: 20))) &&
      DateTime.now().isAfter(riseDay.subtract(Duration(days: 1)))) {
    darkTheme = false;
  }

  brightness = brightness ??
      (darkTheme != null
          ? (darkTheme ? Brightness.dark : Brightness.light)
          : MediaQuery.of(context).platformBrightness);
  context.read<ThemeNotifier>().theme = ThemeData(
    colorScheme: ColorScheme.fromSwatch(
      primarySwatch: color,
      brightness: darkTheme != null
          ? (darkTheme ? Brightness.dark : Brightness.light)
          : WidgetsBinding.instance.window.platformBrightness,
      accentColor: accent,
    ),
    floatingActionButtonTheme:
        FloatingActionButtonThemeData(backgroundColor: color),
    visualDensity: VisualDensity.adaptivePlatformDensity,
    brightness: darkTheme != null
        ? (darkTheme ? Brightness.dark : Brightness.light)
        : WidgetsBinding.instance.window.platformBrightness,
    accentColor: accent,
    primaryColor: color,
  );
}

Stream<Map<StudyYear, List<Class>>> classesByStudyYearRef() {
  return FirebaseFirestore.instance
      .collection('StudyYears')
      .orderBy('Grade')
      .snapshots()
      .switchMap<Map<StudyYear, List<Class>>>(
    (sys) {
      Map<DocumentReference, StudyYear> studyYears = {
        for (final sy in sys.docs) sy.reference: StudyYear.fromDoc(sy)
      };
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
                            auth.FirebaseAuth.instance.currentUser.uid)
                    .orderBy('StudyYear')
                    .orderBy('Gender')
                    .snapshots())
            .map(
          (cs) {
            final classes = cs.docs.map((c) => Class.fromDoc(c)).toList();
            mergeSort<Class>(classes, compare: (c, c2) {
              if (c.studyYear == c2.studyYear)
                return c.gender.compareTo(c2.gender);
              return studyYears[c.studyYear]
                  .grade
                  .compareTo(studyYears[c2.studyYear].grade);
            });
            return groupBy<Class, StudyYear>(
                classes, (c) => studyYears[c.studyYear]);
          },
        ),
      );
    },
  );
}

Stream<Map<StudyYear, List<Class>>> classesByStudyYearRefForUser(String uid) {
  return FirebaseFirestore.instance
      .collection('StudyYears')
      .orderBy('Grade')
      .snapshots()
      .switchMap(
    (sys) {
      Map<DocumentReference, StudyYear> studyYears = {
        for (final sy in sys.docs) sy.reference: StudyYear.fromDoc(sy)
      };
      return FirebaseFirestore.instance
          .collection('Classes')
          .where('Allowed', arrayContains: uid)
          .orderBy('StudyYear')
          .orderBy('Gender')
          .snapshots()
          .map(
        (cs) {
          final classes = cs.docs.map((c) => Class.fromDoc(c)).toList();
          mergeSort<Class>(classes, compare: (c, c2) {
            if (c.studyYear == c2.studyYear)
              return c.gender.compareTo(c2.gender);
            return studyYears[c.studyYear]
                .grade
                .compareTo(studyYears[c2.studyYear].grade);
          });
          return groupBy<Class, StudyYear>(
              classes, (c) => studyYears[c.studyYear]);
        },
      );
    },
  );
}

void classTap(Class _class, BuildContext context) {
  navigator.currentState.pushNamed('ClassInfo', arguments: _class);
}

void dataObjectTap(DataObject obj, BuildContext context) {
  if (obj is Class)
    classTap(obj, context);
  else if (obj is Person)
    personTap(obj, context);
  else if (obj is User)
    userTap(obj, context);
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
      return await Class.fromId(deepLink.queryParameters['ClassId']);
    } else if (deepLink.pathSegments[0] == 'viewPerson') {
      return await Person.fromId(deepLink.queryParameters['PersonId']);
    } else if (deepLink.pathSegments[0] == 'viewUser') {
      return await User.fromID(deepLink.queryParameters['UID']);
    } else if (deepLink.pathSegments[0] == 'viewQuery') {
      return QueryIcon();
    }
    // ignore: empty_catches
  } catch (err) {}
  return null;
}

List<RadioListTile> getOrderingOptions(BuildContext context,
    BehaviorSubject<OrderOptions> orderOptions, int index) {
  return (index == 0
          ? Class.getHumanReadableMap2()
          : Person.getHumanReadableMap2())
      .entries
      .map(
        (e) => RadioListTile(
          value: e.key,
          groupValue: orderOptions.value.orderBy,
          title: Text(e.value),
          onChanged: (value) {
            orderOptions
                .add(OrderOptions(orderBy: value, asc: orderOptions.value.asc));
            navigator.currentState.pop();
          },
        ),
      )
      .toList()
        ..addAll(
          [
            RadioListTile(
              value: 'true',
              groupValue: orderOptions.value.asc.toString(),
              title: Text('تصاعدي'),
              onChanged: (value) {
                orderOptions.add(OrderOptions(
                    orderBy: orderOptions.value.orderBy, asc: value == 'true'));
                navigator.currentState.pop();
              },
            ),
            RadioListTile(
              value: 'false',
              groupValue: orderOptions.value.asc.toString(),
              title: Text('تنازلي'),
              onChanged: (value) {
                orderOptions.add(OrderOptions(
                    orderBy: orderOptions.value.orderBy, asc: value == 'true'));
                navigator.currentState.pop();
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

void historyTap(HistoryDay history, BuildContext context) async {
  if (history is! ServantsHistoryDay) {
    await navigator.currentState.pushNamed('Day', arguments: history);
  } else {
    await navigator.currentState.pushNamed('ServantsDay', arguments: history);
  }
}

DateTime getRiseDay([int year]) {
  year ??= DateTime.now().year;
  int a = year % 4;
  int b = year % 7;
  int c = year % 19;
  int d = (19 * c + 15) % 30;
  int e = (2 * a + 4 * b - d + 34) % 7;

  return DateTime(year, (d + e + 114) ~/ 31, ((d + e + 114) % 31) + 14);
}

void import(BuildContext context) async {
  try {
    final picked = await FilePicker.platform.pickFiles(
        allowedExtensions: ['xlsx'], withData: true, type: FileType.custom);
    if (picked == null) return;
    final fileData = picked.files[0].bytes;
    final decoder = SpreadsheetDecoder.decodeBytes(fileData);
    if (decoder.tables.containsKey('Classes') &&
        decoder.tables.containsKey('Persons')) {
      scaffoldMessenger.currentState.showSnackBar(
        SnackBar(
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
                  customMetadata: {'createdBy': User.instance.uid}));
      scaffoldMessenger.currentState.hideCurrentSnackBar();
      scaffoldMessenger.currentState.showSnackBar(
        SnackBar(
          content: Text('جار استيراد الملف...'),
          duration: Duration(minutes: 9),
        ),
      );
      await FirebaseFunctions.instance
          .httpsCallable('importFromExcel')
          .call({'fileId': filename + '.xlsx'});
      scaffoldMessenger.currentState.hideCurrentSnackBar();
      scaffoldMessenger.currentState.showSnackBar(
        SnackBar(
          content: Text('تم الاستيراد بنجاح'),
          duration: Duration(seconds: 4),
        ),
      );
    } else {
      scaffoldMessenger.currentState.hideCurrentSnackBar();
      await showErrorDialog(context, 'ملف غير صالح');
    }
  } catch (e) {
    scaffoldMessenger.currentState.hideCurrentSnackBar();
    await showErrorDialog(context, e.toString());
  }
}

Future<void> onBackgroundMessage(RemoteMessage message) async {
  await Hive.initFlutter();
  await Hive.openBox<Map>('Notifications');
  await storeNotification(message);
  await Hive.close();
}

void onForegroundMessage(RemoteMessage message, [BuildContext context]) async {
  context ??= mainScfld.currentContext;
  bool opened = Hive.isBoxOpen('Notifications');
  if (!opened) await Hive.openBox<Map>('Notifications');
  await storeNotification(message);
  scaffoldMessenger.currentState.showSnackBar(
    SnackBar(
      content: Text(message.notification.body),
      action: SnackBarAction(
        label: 'فتح الاشعارات',
        onPressed: () => navigator.currentState.pushNamed('Notifications'),
      ),
    ),
  );
}

Future onNotificationClicked(String payload) {
  if (WidgetsBinding.instance.renderViewElement != null) {
    processClickedNotification(mainScfld.currentContext, payload);
  }
  return null;
}

Stream<Map<DocumentReference, Tuple2<Class, List<User>>>> usersByClassRef(
    List<User> users) {
  return FirebaseFirestore.instance
      .collection('StudyYears')
      .orderBy('Grade')
      .snapshots()
      .switchMap(
    (sys) {
      Map<DocumentReference, StudyYear> studyYears = {
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
                            auth.FirebaseAuth.instance.currentUser.uid)
                    .orderBy('StudyYear')
                    .orderBy('Gender')
                    .snapshots())
            .map(
          (cs) {
            final classesByRef = {
              for (final c in cs.docs.map((c) => Class.fromDoc(c)).toList())
                c.ref: c
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

            mergeSort<MapEntry<DocumentReference, Tuple2<Class, List<User>>>>(
                rslt, compare: (c, c2) {
              if (c.value.item1.name == 'غير محدد' ||
                  c.value.item1.name == '{لا يمكن قراءة اسم الفصل}') return 1;
              if (c2.value.item1.name == 'غير محدد' ||
                  c2.value.item1.name == '{لا يمكن قراءة اسم الفصل}') return -1;

              if (studyYears[c.value.item1.studyYear] ==
                  studyYears[c2.value.item1.studyYear])
                return c.value.item1.gender.compareTo(c2.value.item1.gender);
              return studyYears[c.value.item1.studyYear]
                  .grade
                  .compareTo(studyYears[c2.value.item1.studyYear].grade);
            });

            return {for (final e in rslt) e.key: e.value};
          },
        ),
      );
    },
  );
}

Stream<Map<DocumentReference, Tuple2<Class, List<Person>>>> personsByClassRef(
    [List<Person> persons]) {
  return FirebaseFirestore.instance
      .collection('StudyYears')
      .orderBy('Grade')
      .snapshots()
      .switchMap((sys) {
    Map<DocumentReference, StudyYear> studyYears = {
      for (final sy in sys.docs) sy.reference: StudyYear.fromDoc(sy)
    };
    if (persons != null) {
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
                            auth.FirebaseAuth.instance.currentUser.uid)
                    .orderBy('StudyYear')
                    .orderBy('Gender')
                    .snapshots())
            .map(
          (cs) {
            Map<DocumentReference, List<Person>> personsByClassRef =
                groupBy(persons, (p) => p.classId);
            final classes = cs.docs
                .map((c) => Class.fromDoc(c))
                .where((c) => personsByClassRef[c.ref] != null)
                .toList();
            mergeSort<Class>(classes, compare: (c, c2) {
              if (c.studyYear == c2.studyYear)
                return c.gender.compareTo(c2.gender);
              return studyYears[c.studyYear]
                  .grade
                  .compareTo(studyYears[c2.studyYear].grade);
            });
            return {
              for (final c in classes)
                c.ref: Tuple2<Class, List<Person>>(c, personsByClassRef[c.ref])
            };
          },
        ),
      );
    } else {
      return Person.getAllForUser().switchMap(
        (persons) {
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
                                auth.FirebaseAuth.instance.currentUser.uid)
                        .orderBy('StudyYear')
                        .orderBy('Gender')
                        .snapshots())
                .map(
              (cs) {
                Map<DocumentReference, List<Person>> personsByClassRef =
                    groupBy(persons, (p) => p.classId);
                final classes = cs.docs
                    .map((c) => Class.fromDoc(c))
                    .where((c) => personsByClassRef[c.ref] != null)
                    .toList();
                mergeSort<Class>(classes, compare: (c, c2) {
                  if (c.studyYear == c2.studyYear)
                    return c.gender.compareTo(c2.gender);
                  return studyYears[c.studyYear]
                      .grade
                      .compareTo(studyYears[c2.studyYear].grade);
                });
                return {
                  for (final c in classes)
                    c.ref:
                        Tuple2<Class, List<Person>>(c, personsByClassRef[c.ref])
                };
              },
            ),
          );
        },
      );
    }
  });
}

void personTap(Person person, BuildContext context) {
  navigator.currentState.pushNamed('PersonInfo', arguments: person);
}

Future<void> processClickedNotification(BuildContext context,
    [String payload]) async {
  final notificationDetails =
      await FlutterLocalNotificationsPlugin().getNotificationAppLaunchDetails();

  if (notificationDetails.didNotificationLaunchApp) {
    if ((notificationDetails.payload ?? payload) == 'Birthday') {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await Future.delayed(Duration(milliseconds: 900), () => null);
        await navigator.currentState.push(
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
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await Future.delayed(Duration(milliseconds: 900), () => null);
        await navigator.currentState.push(
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
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await Future.delayed(Duration(milliseconds: 900), () => null);
        await navigator.currentState.push(
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
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await Future.delayed(Duration(milliseconds: 900), () => null);
        await navigator.currentState.push(
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
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await Future.delayed(Duration(milliseconds: 900), () => null);
        await navigator.currentState.push(
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

Future<void> processLink(Uri deepLink, BuildContext context) async {
  try {
    if (deepLink != null &&
        deepLink.pathSegments.isNotEmpty &&
        deepLink.queryParameters.isNotEmpty) {
      if (deepLink.pathSegments[0] == 'viewClass') {
        classTap(
            Class.fromDoc(await FirebaseFirestore.instance
                .doc('Classes/${deepLink.queryParameters['ClassId']}')
                .get()),
            context);
      } else if (deepLink.pathSegments[0] == 'viewPerson') {
        personTap(
            Person.fromDoc(await FirebaseFirestore.instance
                .doc('Persons/${deepLink.queryParameters['PersonId']}')
                .get()),
            context);
      } else if (deepLink.pathSegments[0] == 'viewQuery') {
        await navigator.currentState.push(
          MaterialPageRoute(
            builder: (c) => SearchQuery(
              query: deepLink.queryParameters,
            ),
          ),
        );
      } else if (deepLink.pathSegments[0] == 'viewUser') {
        if (User.instance.manageUsers) {
          userTap(await User.fromID(deepLink.queryParameters['UID']), context);
        } else {
          await showErrorDialog(
              context, 'ليس لديك الصلاحية لرؤية محتويات الرابط!');
        }
      }
    } else {
      await showErrorDialog(context, 'رابط غير صالح!');
    }
  } catch (err) {
    if (err.toString().contains('PERMISSION_DENIED')) {
      await showErrorDialog(context, 'ليس لديك الصلاحية لرؤية محتويات الرابط!');
    } else {
      await showErrorDialog(context, 'حدث خطأ! أثناء قراءة محتويات الرابط');
    }
  }
}

Future<void> sendNotification(BuildContext context, dynamic attachement) async {
  BehaviorSubject<String> search = BehaviorSubject<String>.seeded('');
  List<User> users = await showDialog(
    context: context,
    builder: (context) {
      return MultiProvider(
        providers: [
          Provider(
            create: (_) => DataObjectListOptions<User>(
              itemBuilder: (current,
                      {onLongPress, onTap, subtitle, trailing}) =>
                  DataObjectWidget(
                current,
                onTap: () => onTap(current),
                trailing: trailing,
                showSubTitle: false,
              ),
              selectionMode: true,
              searchQuery: search,
              itemsStream: FirebaseFirestore.instance
                  .collection('Users')
                  .snapshots()
                  .map(
                    (s) =>
                        s.docs.map((e) => User.fromDoc(e)..uid = e.id).toList(),
                  ),
            ),
          ),
        ],
        builder: (context, child) => Scaffold(
          appBar: AppBar(
            title: Text('اختيار مستخدمين'),
            actions: [
              IconButton(
                onPressed: () {
                  navigator.currentState.pop(context
                      .read<DataObjectListOptions<User>>()
                      .selectedLatest
                      .values
                      .toList());
                },
                icon: Icon(Icons.done),
                tooltip: 'تم',
              ),
            ],
          ),
          body: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SearchField(
                  searchStream: search,
                  textStyle: Theme.of(context).textTheme.bodyText2),
              Expanded(
                child: UsersList(),
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
                    icon: Icon(Icons.send),
                    onPressed: () => navigator.currentState.pop(true),
                    label: Text('ارسال'),
                  ),
                  TextButton.icon(
                    icon: Icon(Icons.cancel),
                    onPressed: () => navigator.currentState.pop(false),
                    label: Text('الغاء الأمر'),
                  ),
                ],
                title: Text('انشاء رسالة'),
                content: Container(
                  width: 280,
                  child: Column(
                    children: <Widget>[
                      Container(
                        padding: EdgeInsets.symmetric(vertical: 4.0),
                        child: TextFormField(
                          decoration: InputDecoration(
                            labelText: 'عنوان الرسالة',
                            border: OutlineInputBorder(
                              borderSide: BorderSide(
                                  color: Theme.of(context).primaryColor),
                            ),
                          ),
                          controller: title,
                          textInputAction: TextInputAction.next,
                          validator: (value) {
                            if (value.isEmpty) {
                              return 'هذا الحقل مطلوب';
                            }
                            return null;
                          },
                        ),
                      ),
                      Expanded(
                        child: Container(
                          padding: EdgeInsets.symmetric(vertical: 4.0),
                          child: TextFormField(
                            decoration: InputDecoration(
                              labelText: 'محتوى الرسالة',
                              border: OutlineInputBorder(
                                borderSide: BorderSide(
                                    color: Theme.of(context).primaryColor),
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
  bool nested = false;
  bool keepBackup = true;
  if (await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          actions: [
            TextButton(
              onPressed: () => navigator.currentState.pop(true),
              child: Text('استرجاع'),
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
                      Text(
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
                      Text('ابقاء البيانات المحذوفة'),
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
      scaffoldMessenger.currentState
          .showSnackBar(SnackBar(content: Text('تم الاسترجاع بنجاح')));
    } catch (err, stcTrace) {
      await FirebaseCrashlytics.instance
          .setCustomKey('LastErrorIn', 'helpers.recoverDoc');
      await FirebaseCrashlytics.instance.recordError(err, stcTrace);
    }
  }
}

Future<String> shareClass(Class _class) async => await shareClassRaw(_class.id);

Future<String> shareClassRaw(String id) async {
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

Future<String> shareDataObject(DataObject obj) async {
  if (obj is HistoryDay) return await shareHistory(obj);
  if (obj is Class) return await shareClass(obj);
  if (obj is Person) return await sharePerson(obj);
  throw UnimplementedError();
}

Future<String> shareHistory(HistoryDay record) async =>
    await shareHistoryRaw(record.id);

Future<String> shareHistoryRaw(String id) async {
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
  return await sharePersonRaw(person.id);
}

Future<String> sharePersonRaw(String id) async {
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

Future<String> shareQuery(Map<String, String> query) async {
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

Future<String> shareUser(User user) async => await shareUserRaw(user.uid);

Future<String> shareUserRaw(String uid) async {
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
  await User.instance.initialized;
  final user = User.instance;
  final source = GetOptions(
      source:
          (await Connectivity().checkConnectivity()) == ConnectivityResult.none
              ? Source.cache
              : Source.serverAndCache);
  final classes = await Class.getAllForUser().first;
  await Future.delayed(Duration(milliseconds: 1));
  List<String> persons;
  if (user.superAccess) {
    persons = (await FirebaseFirestore.instance
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
        .toList();
  } else if (classes.length <= 10) {
    persons = (await FirebaseFirestore.instance
            .collection('Persons')
            .where('ClassId', whereIn: classes.map((c) => c.ref).toList())
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
        .toList();
  } else {
    persons = (await Future.wait(
            classes.split(10).map((cs) => FirebaseFirestore.instance
                .collection('Persons')
                .where('ClassId', whereIn: cs.map((c) => c.ref).toList())
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
        .map((e) => e.docs.map((e) => e.data()['Name'] as String))
        .expand((e) => e);
  }
  if (persons.isNotEmpty || !f.kReleaseMode)
    await FlutterLocalNotificationsPlugin().show(
        2,
        'أعياد الميلاد',
        persons.join(', '),
        NotificationDetails(
          android: AndroidNotificationDetails(
              'Birthday', 'إشعارات أعياد الميلاد', 'إشعارات أعياد الميلاد',
              icon: 'birthday',
              autoCancel: false,
              visibility: NotificationVisibility.secret,
              showWhen: false),
        ),
        payload: 'Birthday');
}

Future<List<Class>> selectClasses(
    BuildContext context, List<Class> classes) async {
  final _options = ServicesListOptions(
      itemsStream: classesByStudyYearRef(),
      selectionMode: true,
      selected: classes,
      searchQuery: Stream.value(''));
  if (await navigator.currentState.push(
        MaterialPageRoute(
          builder: (context) => Scaffold(
            appBar: AppBar(
              title: Text('اختر الفصول'),
              actions: [
                IconButton(
                    icon: Icon(Icons.done),
                    onPressed: () => navigator.currentState.pop(true),
                    tooltip: 'تم')
              ],
            ),
            body: ServicesList(options: _options),
          ),
        ),
      ) ==
      true) {
    return _options.selectedLatest.values.toList();
  }
  return null;
}

void showConfessionNotification() async {
  await Firebase.initializeApp();
  if (auth.FirebaseAuth.instance.currentUser == null) return;
  await User.instance.initialized;
  final user = User.instance;
  final source = GetOptions(
      source:
          (await Connectivity().checkConnectivity()) == ConnectivityResult.none
              ? Source.cache
              : Source.serverAndCache);
  final classes = await Class.getAllForUser().first;
  await Future.delayed(Duration(seconds: 2));
  List<String> persons;
  if (user.superAccess) {
    persons = (await FirebaseFirestore.instance
            .collection('Persons')
            .where('LastConfession',
                isLessThan: Timestamp.fromDate(
                    DateTime.now().subtract(Duration(days: 7))))
            .limit(20)
            .get(source))
        .docs
        .map((e) => e.data()['Name'] as String)
        .toList();
  } else if (classes.length <= 10) {
    persons = (await FirebaseFirestore.instance
            .collection('Persons')
            .where('ClassId', whereIn: classes.map((c) => c.ref).toList())
            .where('LastConfession',
                isLessThan: Timestamp.fromDate(
                    DateTime.now().subtract(Duration(days: 7))))
            .limit(20)
            .get(source))
        .docs
        .map((e) => e.data()['Name'] as String)
        .toList();
  } else {
    persons = (await Future.wait(classes.split(10).map((cs) => FirebaseFirestore
            .instance
            .collection('Persons')
            .where('ClassId', whereIn: cs.map((c) => c.ref).toList())
            .where('LastConfession',
                isLessThan: Timestamp.fromDate(
                    DateTime.now().subtract(Duration(days: 7))))
            .limit(20)
            .get(source))))
        .map((e) => e.docs.map((e) => e.data()['Name'] as String))
        .expand((e) => e);
  }
  if (persons.isNotEmpty || !f.kReleaseMode)
    await FlutterLocalNotificationsPlugin().show(
        0,
        'انذار الاعتراف',
        persons.join(', '),
        NotificationDetails(
          android: AndroidNotificationDetails(
              'Confessions', 'إشعارات الاعتراف', 'إشعارات الاعتراف',
              icon: 'warning',
              autoCancel: false,
              visibility: NotificationVisibility.secret,
              showWhen: false),
        ),
        payload: 'Confessions');
}

Future<void> showErrorDialog(BuildContext context, String message,
    {String title}) async {
  return await showDialog(
    context: context,
    barrierDismissible: false, // user must tap button!
    builder: (BuildContext context) => AlertDialog(
      title: title != null ? Text(title) : null,
      content: Text(message),
      actions: <Widget>[
        TextButton(
          onPressed: () {
            navigator.currentState.pop();
          },
          child: Text('حسنًا'),
        ),
      ],
    ),
  );
}

Future<void> showErrorUpdateDataDialog(
    {BuildContext context, bool pushApp = true}) async {
  if (pushApp ||
      Hive.box('Settings').get('DialogLastShown') !=
          tranucateToDay().millisecondsSinceEpoch) {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        content:
            Text('الخادم مثال حى للنفس التائبة ـ يمارس التوبة فى حياته الخاصة'
                ' وفى أصوامـه وصلواته ، وحب المسـيح المصلوب\n'
                'أبونا بيشوي كامل \n'
                'يرجي مراجعة حياتك الروحية والاهتمام بها'),
        actions: [
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              shape: StadiumBorder(side: BorderSide(color: primaries[13])),
            ),
            onPressed: () async {
              final user = User.instance;
              await navigator.currentState
                  .pushNamed('UpdateUserDataError', arguments: user);
              if (user.lastTanawol != null &&
                  user.lastConfession != null &&
                  ((user.lastTanawol.millisecondsSinceEpoch + 2592000000) >
                          DateTime.now().millisecondsSinceEpoch &&
                      (user.lastConfession.millisecondsSinceEpoch +
                              5184000000) >
                          DateTime.now().millisecondsSinceEpoch)) {
                navigator.currentState.pop();
                if (pushApp)
                  // ignore: unawaited_futures
                  navigator.currentState.pushReplacement(
                      MaterialPageRoute(builder: (context) => App()));
              }
            },
            icon: Icon(Icons.update),
            label: Text('تحديث بيانات التناول والاعتراف'),
          ),
          TextButton.icon(
            onPressed: () => navigator.currentState.pop(),
            icon: Icon(Icons.close),
            label: Text('تم'),
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
  await User.instance.initialized;
  final user = User.instance;
  final source = GetOptions(
      source:
          (await Connectivity().checkConnectivity()) == ConnectivityResult.none
              ? Source.cache
              : Source.serverAndCache);
  final classes = await Class.getAllForUser().first;
  await Future.delayed(Duration(seconds: 3));
  List<String> persons;
  if (user.superAccess) {
    persons = (await FirebaseFirestore.instance
            .collection('Persons')
            .where('LastKodas',
                isLessThan: Timestamp.fromDate(
                    DateTime.now().subtract(Duration(days: 7))))
            .limit(20)
            .get(source))
        .docs
        .map((e) => e.data()['Name'] as String)
        .toList();
  } else if (classes.length <= 10) {
    persons = (await FirebaseFirestore.instance
            .collection('Persons')
            .where('ClassId', whereIn: classes.map((c) => c.ref).toList())
            .where('LastKodas',
                isLessThan: Timestamp.fromDate(
                    DateTime.now().subtract(Duration(days: 7))))
            .limit(20)
            .get(source))
        .docs
        .map((e) => e.data()['Name'] as String)
        .toList();
  } else {
    persons = (await Future.wait(classes.split(10).map((cs) => FirebaseFirestore
            .instance
            .collection('Persons')
            .where('ClassId', whereIn: cs.map((c) => c.ref).toList())
            .where('LastKodas',
                isLessThan: Timestamp.fromDate(
                    DateTime.now().subtract(Duration(days: 7))))
            .limit(20)
            .get(source))))
        .map((e) => e.docs.map((e) => e.data()['Name'] as String))
        .expand((e) => e);
  }
  if (persons.isNotEmpty || !f.kReleaseMode)
    await FlutterLocalNotificationsPlugin().show(
        4,
        'انذار حضور القداس',
        persons.join(', '),
        NotificationDetails(
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
  await User.instance.initialized;
  final user = User.instance;
  final source = GetOptions(
      source:
          (await Connectivity().checkConnectivity()) == ConnectivityResult.none
              ? Source.cache
              : Source.serverAndCache);
  final classes = await Class.getAllForUser().first;
  await Future.delayed(Duration(seconds: 4));
  List<String> persons;
  if (user.superAccess) {
    persons = (await FirebaseFirestore.instance
            .collection('Persons')
            .where('LastMeeting',
                isLessThan: Timestamp.fromDate(
                    DateTime.now().subtract(Duration(days: 7))))
            .limit(20)
            .get(source))
        .docs
        .map((e) => e.data()['Name'] as String)
        .toList();
  } else if (classes.length <= 10) {
    persons = (await FirebaseFirestore.instance
            .collection('Persons')
            .where('ClassId', whereIn: classes.map((c) => c.ref).toList())
            .where('LastMeeting',
                isLessThan: Timestamp.fromDate(
                    DateTime.now().subtract(Duration(days: 7))))
            .limit(20)
            .get(source))
        .docs
        .map((e) => e.data()['Name'] as String)
        .toList();
  } else {
    persons = (await Future.wait(classes.split(10).map((cs) => FirebaseFirestore
            .instance
            .collection('Persons')
            .where('ClassId', whereIn: cs.map((c) => c.ref).toList())
            .where('LastMeeting',
                isLessThan: Timestamp.fromDate(
                    DateTime.now().subtract(Duration(days: 7))))
            .limit(20)
            .get(source))))
        .map((e) => e.docs.map((e) => e.data()['Name'] as String))
        .expand((e) => e);
  }
  if (persons.isNotEmpty || !f.kReleaseMode)
    await FlutterLocalNotificationsPlugin().show(
        3,
        'انذار حضور الاجتماع',
        persons.join(', '),
        NotificationDetails(
          android: AndroidNotificationDetails(
              'Meeting', 'إشعارات حضور الاجتماع', 'إشعارات حضور الاجتماع',
              icon: 'warning',
              autoCancel: false,
              visibility: NotificationVisibility.secret,
              showWhen: false),
        ),
        payload: 'Meeting');
}

Future<void> showMessage(
    BuildContext context, no.Notification notification) async {
  final attachement = await getLinkObject(
    Uri.parse(notification.attachement),
  );
  String scndLine = await attachement.getSecondLine() ?? '';
  final user = notification.from != ''
      ? await FirebaseFirestore.instance
          .doc('Users/${notification.from}')
          .get(dataSource)
      : null;
  await showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(notification.title),
      content: Container(
        width: 280,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              notification.content,
              style: TextStyle(fontSize: 18),
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
                      classTap(attachement, context);
                    } else if (attachement is Person) {
                      personTap(attachement, context);
                    } else if (attachement is User) {
                      userTap(attachement, context);
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

Future<void> showPendingMessage([BuildContext context]) async {
  context ??= mainScfld.currentContext;
  final pendingMessage = await FirebaseMessaging.instance.getInitialMessage();
  if (pendingMessage != null) {
    // ignore: unawaited_futures
    navigator.currentState.pushNamed('Notifications');
    if (pendingMessage.data['type'] == 'Message')
      await showMessage(
        context,
        no.Notification.fromMessage(pendingMessage.data),
      );
    else
      await processLink(Uri.parse(pendingMessage.data['attachement']), context);
  }
}

void showTanawolNotification() async {
  await Firebase.initializeApp();
  if (auth.FirebaseAuth.instance.currentUser == null) return;
  await User.instance.initialized;
  final user = User.instance;
  final source = GetOptions(
      source:
          (await Connectivity().checkConnectivity()) == ConnectivityResult.none
              ? Source.cache
              : Source.serverAndCache);
  final classes = await Class.getAllForUser().first;
  await Future.delayed(Duration(seconds: 5));
  List<String> persons;
  if (user.superAccess) {
    persons = (await FirebaseFirestore.instance
            .collection('Persons')
            .where('LastTanawol',
                isLessThan: Timestamp.fromDate(
                    DateTime.now().subtract(Duration(days: 7))))
            .limit(20)
            .get(source))
        .docs
        .map((e) => e.data()['Name'] as String)
        .toList();
  } else if (classes.length <= 10) {
    persons = (await FirebaseFirestore.instance
            .collection('Persons')
            .where('ClassId', whereIn: classes.map((c) => c.ref).toList())
            .where('LastTanawol',
                isLessThan: Timestamp.fromDate(
                    DateTime.now().subtract(Duration(days: 7))))
            .limit(20)
            .get(source))
        .docs
        .map((e) => e.data()['Name'] as String)
        .toList();
  } else {
    persons = (await Future.wait(classes.split(10).map((cs) => FirebaseFirestore
            .instance
            .collection('Persons')
            .where('ClassId', whereIn: cs.map((c) => c.ref).toList())
            .where('LastTanawol',
                isLessThan: Timestamp.fromDate(
                    DateTime.now().subtract(Duration(days: 7))))
            .limit(20)
            .get(source))))
        .map((e) => e.docs.map((e) => e.data()['Name'] as String))
        .expand((e) => e);
  }
  if (persons.isNotEmpty || !f.kReleaseMode)
    await FlutterLocalNotificationsPlugin().show(
        1,
        'انذار التناول',
        persons.join(', '),
        NotificationDetails(
          android: AndroidNotificationDetails(
              'Tanawol', 'إشعارات التناول', 'إشعارات التناول',
              icon: 'warning',
              autoCancel: false,
              visibility: NotificationVisibility.secret,
              showWhen: false),
        ),
        payload: 'Tanawol');
}

Future<int> storeNotification(RemoteMessage message) async {
  return await Hive.box<Map<dynamic, dynamic>>('Notifications')
      .add(message.data);
}

String toDurationString(Timestamp date, {appendSince = true}) {
  if (date == null) return '';
  if (appendSince) return format(date.toDate(), locale: 'ar');
  return format(date.toDate(), locale: 'ar').replaceAll('منذ ', '');
}

Timestamp tranucateToDay({DateTime time}) {
  time = time ?? DateTime.now();
  return Timestamp.fromMillisecondsSinceEpoch(
    time.millisecondsSinceEpoch -
        time.millisecondsSinceEpoch.remainder(Duration.millisecondsPerDay),
  );
}

void userTap(User user, BuildContext context) async {
  if (user.approved) {
    await navigator.currentState.pushNamed('UserInfo', arguments: user);
  } else {
    dynamic rslt = await showDialog(
        context: context,
        builder: (context) => AlertDialog(
              actions: <Widget>[
                TextButton.icon(
                  icon: Icon(Icons.done),
                  label: Text('نعم'),
                  onPressed: () => navigator.currentState.pop(true),
                ),
                TextButton.icon(
                  icon: Icon(Icons.close),
                  label: Text('لا'),
                  onPressed: () => navigator.currentState.pop(false),
                ),
                TextButton.icon(
                  icon: Icon(Icons.close),
                  label: Text('حذف المستخدم'),
                  onPressed: () => navigator.currentState.pop('deleted'),
                ),
              ],
              title: Text('${user.name} غير مُنشط هل تريد تنشيطه؟'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  user.getPhoto(false),
                  Text(
                    'البريد الاكتروني: ' + (user.email ?? ''),
                  ),
                ],
              ),
            ));
    if (rslt == true) {
      scaffoldMessenger.currentState.showSnackBar(
        SnackBar(
          content: LinearProgressIndicator(),
          duration: Duration(seconds: 15),
        ),
      );
      try {
        await FirebaseFunctions.instance
            .httpsCallable('approveUser')
            .call({'affectedUser': user.uid});
        user.approved = true;
        // ignore: invalid_use_of_visible_for_testing_member, invalid_use_of_protected_member
        user.notifyListeners();
        userTap(user, context);
        scaffoldMessenger.currentState.hideCurrentSnackBar();
        scaffoldMessenger.currentState.showSnackBar(
          SnackBar(
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
      scaffoldMessenger.currentState.showSnackBar(
        SnackBar(
          content: LinearProgressIndicator(),
          duration: Duration(seconds: 15),
        ),
      );
      try {
        await FirebaseFunctions.instance
            .httpsCallable('deleteUser')
            .call({'affectedUser': user.uid});
        scaffoldMessenger.currentState.hideCurrentSnackBar();
        scaffoldMessenger.currentState.showSnackBar(
          SnackBar(
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
  final String url;
  MessageIcon(this.url, {Key key}) : super(key: key);

  Color get color => Colors.transparent;
  String get name => '';
  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints.expand(width: 55.2, height: 55.2),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: () => showDialog(
            context: context,
            builder: (context) => Dialog(
              child: Hero(
                tag: url,
                child: CachedNetworkImage(
                  imageUrl: url,
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
            imageUrl: url,
            progressIndicatorBuilder: (context, url, progress) =>
                CircularProgressIndicator(value: progress.progress),
          ),
        ),
      ),
    );
  }

  Widget getPhoto(BuildContext context) {
    return build(context);
  }

  Future<String> getSecondLine() async => '';
}

class QueryIcon extends StatelessWidget {
  Color get color => Colors.transparent;
  String get name => 'نتائج بحث';

  @override
  Widget build(BuildContext context) {
    return Icon(Icons.search,
        size: MediaQuery.of(context).size.shortestSide / 7.2);
  }

  Widget getPhoto(BuildContext context) {
    return build(context);
  }

  Future<String> getSecondLine() async => '';
}

extension BoolComparison on bool {
  int compareTo(bool o) {
    if (this == o) return 0;
    if (this == true) return -1;
    if (this == false) {
      if (o == true) return 1;
      return -1;
    }
    return 1;
  }
}

extension SplitList<T> on List<T> {
  List<List<T>> split(int length) {
    List<List<T>> chunks = [];
    for (int i = 0; i < this.length; i += length) {
      chunks
          .add(sublist(i, i + length > this.length ? this.length : i + length));
    }
    return chunks;
  }
}
