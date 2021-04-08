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
import '../views/users_list.dart';
import '../utils/globals.dart';

Future<void> changeTheme(
    {int primary,
    int accent,
    Brightness brightness,
    @required BuildContext context}) async {
  primary = primary ?? Hive.box('Settings').get('PrimaryColorIndex');
  bool darkTheme = Hive.box('Settings').get('DarkTheme');
  brightness = brightness ??
      (darkTheme != null
          ? (darkTheme ? Brightness.dark : Brightness.light)
          : MediaQuery.of(context).platformBrightness);
  context.read<ThemeNotifier>().setTheme(ThemeData(
        floatingActionButtonTheme: FloatingActionButtonThemeData(
            backgroundColor: Theme.of(context).primaryColor),
        visualDensity: VisualDensity.adaptivePlatformDensity,
        outlinedButtonTheme: OutlinedButtonThemeData(
            style: OutlinedButton.styleFrom(primary: primaries[primary ?? 13])),
        textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(primary: primaries[primary ?? 13])),
        elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(primary: primaries[primary ?? 13])),
        brightness: darkTheme != null
            ? (darkTheme ? Brightness.dark : Brightness.light)
            : WidgetsBinding.instance.window.platformBrightness,
        accentColor: accents[accent ?? 13],
        primaryColor: primaries[primary ?? 13],
      ));
}

Stream<Map<StudyYear, List<Class>>> classesByStudyYearRef() async* {
  await for (var sys in FirebaseFirestore.instance
      .collection('StudyYears')
      .orderBy('Grade')
      .snapshots()) {
    Map<DocumentReference, StudyYear> studyYears = {
      for (var sy in sys.docs) sy.reference: StudyYear.fromDoc(sy)
    };
    await for (var cs in (User.instance.superAccess
        ? FirebaseFirestore.instance
            .collection('Classes')
            .orderBy('StudyYear')
            .orderBy('Gender')
            .snapshots()
        : FirebaseFirestore.instance
            .collection('Classes')
            .where('Allowed',
                arrayContains: auth.FirebaseAuth.instance.currentUser.uid)
            .orderBy('StudyYear')
            .orderBy('Gender')
            .snapshots())) {
      var classes = cs.docs.map((c) => Class.fromDoc(c)).toList();
      mergeSort<Class>(classes, compare: (c, c2) {
        if (c.studyYear == c2.studyYear) return c.gender.compareTo(c2.gender);
        return studyYears[c.studyYear]
            .grade
            .compareTo(studyYears[c2.studyYear].grade);
      });
      yield groupBy<Class, StudyYear>(classes, (c) => studyYears[c.studyYear]);
    }
  }
}

Stream<Map<StudyYear, List<Class>>> classesByStudyYearRefForUser(
    String uid) async* {
  await for (var sys in FirebaseFirestore.instance
      .collection('StudyYears')
      .orderBy('Grade')
      .snapshots()) {
    Map<DocumentReference, StudyYear> studyYears = {
      for (var sy in sys.docs) sy.reference: StudyYear.fromDoc(sy)
    };
    await for (var cs in FirebaseFirestore.instance
        .collection('Classes')
        .where('Allowed', arrayContains: uid)
        .orderBy('StudyYear')
        .orderBy('Gender')
        .snapshots()) {
      var classes = cs.docs.map((c) => Class.fromDoc(c)).toList();
      mergeSort<Class>(classes, compare: (c, c2) {
        if (c.studyYear == c2.studyYear) return c.gender.compareTo(c2.gender);
        return studyYears[c.studyYear]
            .grade
            .compareTo(studyYears[c2.studyYear].grade);
      });
      yield groupBy<Class, StudyYear>(classes, (c) => studyYears[c.studyYear]);
    }
  }
}

void classTap(Class _class, BuildContext context) {
  Navigator.of(context).pushNamed('ClassInfo', arguments: _class);
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
      // } else if (deepLink.pathSegments[0] == 'viewStreet') {
      //   return await Street.fromId(deepLink.queryParameters['StreetId']);
      // } else if (deepLink.pathSegments[0] == 'viewFamily') {
      //   return await Family.fromId(deepLink.queryParameters['FamilyId']);
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
            Navigator.pop(context);
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
                Navigator.pop(context);
              },
            ),
            RadioListTile(
              value: 'false',
              groupValue: orderOptions.value.asc.toString(),
              title: Text('تنازلي'),
              onChanged: (value) {
                orderOptions.add(OrderOptions(
                    orderBy: orderOptions.value.orderBy, asc: value == 'true'));
                Navigator.pop(context);
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
    await Navigator.of(context).pushNamed('Day', arguments: history);
  } else if (await Connectivity().checkConnectivity() !=
      ConnectivityResult.none) {
    await Navigator.of(context).pushNamed('ServantsDay', arguments: history);
  } else {
    await showDialog(
        context: context,
        builder: (context) =>
            AlertDialog(content: Text('لا يوجد اتصال انترنت')));
  }
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
      ScaffoldMessenger.of(context).showSnackBar(
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
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('جار استيراد الملف...'),
          duration: Duration(minutes: 9),
        ),
      );
      await FirebaseFunctions.instance
          .httpsCallable('importFromExcel')
          .call({'fileId': filename + '.xlsx'});
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم الاستيراد بنجاح'),
          duration: Duration(seconds: 4),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      await showErrorDialog(context, 'ملف غير صالح');
    }
  } catch (e) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
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
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message.notification.body),
      action: SnackBarAction(
        label: 'فتح الاشعارات',
        onPressed: () => Navigator.of(context).pushNamed('Notifications'),
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
    [List<User> users]) async* {
  await for (var sys in FirebaseFirestore.instance
      .collection('StudyYears')
      .orderBy('Grade')
      .snapshots()) {
    Map<String, StudyYear> studyYears = {
      for (var sy in sys.docs) sy.reference.id: StudyYear.fromDoc(sy)
    };
    mergeSort<User>(
      users,
      compare: (u, u2) {
        if (u.servingStudyYear == null && u2.servingStudyYear == null) return 0;
        if (u.servingStudyYear == null) return 1;
        if (u2.servingStudyYear == null) return -1;
        if (u.servingStudyYear == u2.servingStudyYear) {
          if (u.servingStudyGender == u2.servingStudyGender)
            return u.name.compareTo(u2.name);
          return u.servingStudyGender?.compareTo(u.servingStudyGender) ?? 1;
        }
        return studyYears[u.servingStudyYear]
            .grade
            .compareTo(studyYears[u2.servingStudyYear].grade);
      },
    );

    Map<User, Class> usersWithClasses = {
      for (var u in users)
        u: Class(
          ref: FirebaseFirestore.instance.collection('Classes').doc(
              u.servingStudyYear != null && u.servingStudyGender != null
                  ? u.servingStudyYear + '-' + u.servingStudyGender.toString()
                  : 'unknown'),
          name: u.servingStudyYear != null && u.servingStudyGender != null
              ? studyYears[u.servingStudyYear].name +
                  ' - ' +
                  (u.servingStudyGender ? 'بنين' : 'بنات')
              : 'غير محدد',
          studyYear: studyYears[u.servingStudyYear]?.ref,
          gender: u.servingStudyGender,
        )
    };

    yield {
      for (var e
          in groupBy<User, Class>(users, (user) => usersWithClasses[user])
              .entries)
        e.key.ref: Tuple2(e.key, e.value)
    };
  }
}

Stream<Map<DocumentReference, Tuple2<Class, List<Person>>>> personsByClassRef(
    [List<Person> persons]) async* {
  await for (var sys in FirebaseFirestore.instance
      .collection('StudyYears')
      .orderBy('Grade')
      .snapshots()) {
    Map<DocumentReference, StudyYear> studyYears = {
      for (var sy in sys.docs) sy.reference: StudyYear.fromDoc(sy)
    };
    if (persons != null) {
      await for (var cs in (User.instance.superAccess
          ? FirebaseFirestore.instance
              .collection('Classes')
              .orderBy('StudyYear')
              .orderBy('Gender')
              .snapshots()
          : FirebaseFirestore.instance
              .collection('Classes')
              .where('Allowed',
                  arrayContains: auth.FirebaseAuth.instance.currentUser.uid)
              .orderBy('StudyYear')
              .orderBy('Gender')
              .snapshots())) {
        Map<DocumentReference, List<Person>> personsByClassRef =
            groupBy(persons, (p) => p.classId);
        var classes = cs.docs
            .map((c) => Class.fromDoc(c))
            .where((c) => personsByClassRef[c.ref] != null)
            .toList();
        mergeSort<Class>(classes, compare: (c, c2) {
          if (c.studyYear == c2.studyYear) return c.gender.compareTo(c2.gender);
          return studyYears[c.studyYear]
              .grade
              .compareTo(studyYears[c2.studyYear].grade);
        });
        yield {
          for (var c in classes)
            c.ref: Tuple2<Class, List<Person>>(c, personsByClassRef[c.ref])
        };
      }
    } else {
      await for (var persons in FirebaseFirestore.instance
          .collection('Persons')
          .orderBy('Name')
          .snapshots()) {
        await for (var cs in (User.instance.superAccess
            ? FirebaseFirestore.instance
                .collection('Classes')
                .orderBy('StudyYear')
                .orderBy('Gender')
                .snapshots()
            : FirebaseFirestore.instance
                .collection('Classes')
                .where('Allowed',
                    arrayContains: auth.FirebaseAuth.instance.currentUser.uid)
                .orderBy('StudyYear')
                .orderBy('Gender')
                .snapshots())) {
          Map<DocumentReference, List<Person>> personsByClassRef = groupBy(
              persons.docs.map((p) => Person.fromDoc(p)), (p) => p.classId);
          var classes = cs.docs
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
          yield {
            for (var c in classes)
              c.ref: Tuple2<Class, List<Person>>(c, personsByClassRef[c.ref])
          };
        }
      }
    }
  }
}

void personTap(Person person, BuildContext context) {
  Navigator.of(context).pushNamed('PersonInfo', arguments: person);
}

Future<void> processClickedNotification(BuildContext context,
    [String payload]) async {
  var notificationDetails =
      await FlutterLocalNotificationsPlugin().getNotificationAppLaunchDetails();

  if (notificationDetails.didNotificationLaunchApp) {
    if ((notificationDetails.payload ?? payload) == 'Birthday') {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await Future.delayed(Duration(milliseconds: 900), () => null);
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) {
              var now = DateTime.now().millisecondsSinceEpoch;
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
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) {
              var now = DateTime.now().millisecondsSinceEpoch;
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
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) {
              var now = DateTime.now().millisecondsSinceEpoch;
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
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) {
              var now = DateTime.now().millisecondsSinceEpoch;
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
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) {
              var now = DateTime.now().millisecondsSinceEpoch;
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
        await Navigator.of(context).push(
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
                itemsStream: Stream.fromFuture(User.getAllUsersLive())
                    .map((s) => s.docs.map(User.fromDoc).toList())),
          ),
        ],
        builder: (context, child) => Scaffold(
          appBar: AppBar(
            title: Text('اختيار مستخدمين'),
            actions: [
              IconButton(
                onPressed: () {
                  Navigator.pop(
                      context,
                      context
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
  var title = TextEditingController();
  var content = TextEditingController();
  if (users != null &&
      await showDialog(
            context: context,
            builder: (context) {
              return AlertDialog(
                actions: <Widget>[
                  TextButton.icon(
                    icon: Icon(Icons.send),
                    onPressed: () => Navigator.of(context).pop(true),
                    label: Text('ارسال'),
                  ),
                  TextButton.icon(
                    icon: Icon(Icons.cancel),
                    onPressed: () => Navigator.of(context).pop(false),
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
              onPressed: () => Navigator.pop(context, true),
              child: Text('استرجاع'),
            ),
          ],
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Checkbox(
                    value: nested,
                    onChanged: (v) => nested = v,
                  ),
                  Text('استرجع ايضا العناصر بداخل هذا العنصر'),
                ],
              ),
              Row(
                children: [
                  Checkbox(
                    value: keepBackup,
                    onChanged: (v) => keepBackup = v,
                  ),
                  Text('ابقاء البيانات المحذوفة'),
                ],
              ),
            ],
          ),
        ),
      ) ==
      true) {
    await FirebaseFunctions.instance.httpsCallable('recoverDoc').call({
      'deletedPath': path,
      'keepBackup': keepBackup,
      'nested': nested,
    });
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
  var user = User.instance;
  var source = GetOptions(
      source:
          (await Connectivity().checkConnectivity()) == ConnectivityResult.none
              ? Source.cache
              : Source.serverAndCache);
  QuerySnapshot docs;
  if (user.superAccess) {
    docs = (await FirebaseFirestore.instance
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
        .get(source));
  } else {
    docs = (await FirebaseFirestore.instance
        .collection('Persons')
        .where('AreaId',
            whereIn: (await FirebaseFirestore.instance
                    .collection('Areas')
                    .where('Allowed',
                        arrayContains:
                            auth.FirebaseAuth.instance.currentUser.uid)
                    .get(source))
                .docs
                .map((e) => e.reference)
                .toList())
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
        .get(source));
  }
  if (docs.docs.isNotEmpty || !f.kReleaseMode)
    await FlutterLocalNotificationsPlugin().show(
        2,
        'أعياد الميلاد',
        docs.docs.map((e) => e.data()['Name']).join(', '),
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
  var _options = ServicesListOptions(
      itemsStream: classesByStudyYearRef(),
      selectionMode: true,
      selected: classes,
      searchQuery: Stream.value(''));
  if (await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => Scaffold(
            appBar: AppBar(
              title: Text('اختر الفصول'),
              actions: [
                IconButton(
                    icon: Icon(Icons.done),
                    onPressed: () => Navigator.pop(context, true),
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
  var user = User.instance;
  var source = GetOptions(
      source:
          (await Connectivity().checkConnectivity()) == ConnectivityResult.none
              ? Source.cache
              : Source.serverAndCache);
  QuerySnapshot docs;
  if (user.superAccess) {
    docs = (await FirebaseFirestore.instance
        .collection('Persons')
        .where('LastConfession', isLessThan: Timestamp.now())
        .limit(20)
        .get(source));
  } else {
    docs = (await FirebaseFirestore.instance
        .collection('Persons')
        .where('AreaId',
            whereIn: (await FirebaseFirestore.instance
                    .collection('Areas')
                    .where('Allowed',
                        arrayContains:
                            auth.FirebaseAuth.instance.currentUser.uid)
                    .get(source))
                .docs
                .map((e) => e.reference)
                .toList())
        .where('LastConfession', isLessThan: Timestamp.now())
        .limit(20)
        .get(source));
  }
  if (docs.docs.isNotEmpty || !f.kReleaseMode)
    await FlutterLocalNotificationsPlugin().show(
        0,
        'انذار الاعتراف',
        docs.docs.map((e) => e.data()['Name']).join(', '),
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
            Navigator.of(context).pop();
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
              var user = User.instance;
              await Navigator.of(context)
                  .pushNamed('UpdateUserDataError', arguments: user);
              if (user.lastTanawol != null &&
                  user.lastConfession != null &&
                  ((user.lastTanawol + 2592000000) >
                          DateTime.now().millisecondsSinceEpoch &&
                      (user.lastConfession + 5184000000) >
                          DateTime.now().millisecondsSinceEpoch)) {
                Navigator.pop(context);
                if (pushApp)
                  // ignore: unawaited_futures
                  Navigator.pushReplacement(
                      context, MaterialPageRoute(builder: (context) => App()));
              }
            },
            icon: Icon(Icons.update),
            label: Text('تحديث بيانات التناول والاعتراف'),
          ),
          TextButton.icon(
            onPressed: () => Navigator.pop(context),
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
  var user = User.instance;
  var source = GetOptions(
      source:
          (await Connectivity().checkConnectivity()) == ConnectivityResult.none
              ? Source.cache
              : Source.serverAndCache);
  QuerySnapshot docs;
  if (user.superAccess) {
    docs = (await FirebaseFirestore.instance
        .collection('Persons')
        .where('LastKodas', isLessThan: Timestamp.now())
        .limit(20)
        .get(source));
  } else {
    docs = (await FirebaseFirestore.instance
        .collection('Persons')
        .where('AreaId',
            whereIn: (await FirebaseFirestore.instance
                    .collection('Areas')
                    .where('Allowed',
                        arrayContains:
                            auth.FirebaseAuth.instance.currentUser.uid)
                    .get(source))
                .docs
                .map((e) => e.reference)
                .toList())
        .where('LastKodas', isLessThan: Timestamp.now())
        .limit(20)
        .get(source));
  }
  if (docs.docs.isNotEmpty || !f.kReleaseMode)
    await FlutterLocalNotificationsPlugin().show(
        4,
        'انذار حضور القداس',
        docs.docs.map((e) => e.data()['Name']).join(', '),
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
  var user = User.instance;
  var source = GetOptions(
      source:
          (await Connectivity().checkConnectivity()) == ConnectivityResult.none
              ? Source.cache
              : Source.serverAndCache);
  QuerySnapshot docs;
  if (user.superAccess) {
    docs = (await FirebaseFirestore.instance
        .collection('Persons')
        .where('LastMeeting', isLessThan: Timestamp.now())
        .limit(20)
        .get(source));
  } else {
    docs = (await FirebaseFirestore.instance
        .collection('Persons')
        .where('AreaId',
            whereIn: (await FirebaseFirestore.instance
                    .collection('Areas')
                    .where('Allowed',
                        arrayContains:
                            auth.FirebaseAuth.instance.currentUser.uid)
                    .get(source))
                .docs
                .map((e) => e.reference)
                .toList())
        .where('LastMeeting', isLessThan: Timestamp.now())
        .limit(20)
        .get(source));
  }
  if (docs.docs.isNotEmpty || !f.kReleaseMode)
    await FlutterLocalNotificationsPlugin().show(
        3,
        'انذار حضور الاجتماع',
        docs.docs.map((e) => e.data()['Name']).join(', '),
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
  var attachement = await getLinkObject(
    Uri.parse(notification.attachement),
  );
  String scndLine = await attachement.getSecondLine() ?? '';
  var user = notification.from != ''
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
  var pendingMessage = await FirebaseMessaging.instance.getInitialMessage();
  if (pendingMessage != null) {
    // ignore: unawaited_futures
    Navigator.of(context).pushNamed('Notifications');
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
  var user = User.instance;
  var source = GetOptions(
      source:
          (await Connectivity().checkConnectivity()) == ConnectivityResult.none
              ? Source.cache
              : Source.serverAndCache);
  QuerySnapshot docs;
  if (user.superAccess) {
    docs = (await FirebaseFirestore.instance
        .collection('Persons')
        .where('LastTanawol', isLessThan: Timestamp.now())
        .limit(20)
        .get(source));
  } else {
    docs = (await FirebaseFirestore.instance
        .collection('Persons')
        .where('AreaId',
            whereIn: (await FirebaseFirestore.instance
                    .collection('Areas')
                    .where('Allowed',
                        arrayContains:
                            auth.FirebaseAuth.instance.currentUser.uid)
                    .get(source))
                .docs
                .map((e) => e.reference)
                .toList())
        .where('LastTanawol', isLessThan: Timestamp.now())
        .limit(20)
        .get(source));
  }
  if (docs.docs.isNotEmpty || !f.kReleaseMode)
    await FlutterLocalNotificationsPlugin().show(
        1,
        'انذار التناول',
        docs.docs.map((e) => e.data()['Name']).join(', '),
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
    await Navigator.of(context).pushNamed('UserInfo', arguments: user);
  } else {
    dynamic rslt = await showDialog(
        context: context,
        builder: (context) => AlertDialog(
              actions: <Widget>[
                TextButton.icon(
                  icon: Icon(Icons.done),
                  label: Text('نعم'),
                  onPressed: () => Navigator.of(context).pop(true),
                ),
                TextButton.icon(
                  icon: Icon(Icons.close),
                  label: Text('لا'),
                  onPressed: () => Navigator.of(context).pop(false),
                ),
                TextButton.icon(
                  icon: Icon(Icons.close),
                  label: Text('حذف المستخدم'),
                  onPressed: () => Navigator.of(context).pop('delete'),
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
      ScaffoldMessenger.of(context).showSnackBar(
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
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: LinearProgressIndicator(),
          duration: Duration(seconds: 15),
        ),
      );
      try {
        await FirebaseFunctions.instance
            .httpsCallable('deleteUser')
            .call({'affectedUser': user.uid});
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
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
