import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:location/location.dart';
import 'package:meetinghelper/models/models.dart';
import 'package:meetinghelper/models/super_classes.dart';
import 'package:meetinghelper/views/map_view.dart';
import 'package:meetinghelper/utils/globals.dart';
import 'package:meetinghelper/utils/helpers.dart';

import 'user.dart';

class Person extends DataObject with PhotoObject, ChildObject<Class> {
  DocumentReference classId;

  String address;
  GeoPoint location;

  String phone;
  String fatherPhone;
  String motherPhone;
  Map<String, dynamic> phones;

  Timestamp birthDate;

  DocumentReference school;
  DocumentReference church;
  DocumentReference cFather;

  Timestamp lastConfession;
  Timestamp lastTanawol;
  Timestamp lastKodas;
  Timestamp lastMeeting;
  Timestamp lastCall;

  Timestamp lastVisit;
  String lastEdit;
  String notes;

  Person(
      {String id,
      DocumentReference ref,
      this.classId,
      String name = '',
      this.phone = '',
      this.phones,
      this.fatherPhone = '',
      this.motherPhone = '',
      this.address = '',
      this.location,
      bool hasPhoto = false,
      this.birthDate,
      this.lastTanawol,
      this.lastConfession,
      this.lastKodas,
      this.lastMeeting,
      this.lastCall,
      this.lastVisit,
      this.lastEdit,
      this.notes = '',
      this.school,
      this.church,
      this.cFather,
      Color color = Colors.transparent})
      : super(
            ref ??
                FirebaseFirestore.instance
                    .collection('Persons')
                    .doc(id ?? 'null'),
            name,
            color) {
    this.hasPhoto = hasPhoto;
    phones ??= {};
    defaultIcon = Icons.person;
  }

  Person._createFromData(Map<dynamic, dynamic> data, DocumentReference ref)
      : super.createFromData(data, ref) {
    classId = data['ClassId'];

    phone = data['Phone'];
    fatherPhone = data['FatherPhone'];
    motherPhone = data['MotherPhone'];
    phones = data['Phones']?.cast<String, dynamic>() ?? {};

    address = data['Address'];
    location = data['Location'];

    hasPhoto = data['HasPhoto'] ?? false;

    birthDate = data['BirthDate'];
    lastConfession = data['LastConfession'];
    lastTanawol = data['LastTanawol'];
    lastKodas = data['LastKodas'];
    lastMeeting = data['LastMeeting'];
    lastCall = data['LastCall'];

    lastVisit = data['LastVisit'];
    lastEdit = data['LastEdit'];

    notes = data['Notes'];

    school = data['School'];
    church = data['Church'];
    cFather = data['CFather'];

    defaultIcon = Icons.person;
  }

  Timestamp get birthDay => birthDate != null
      ? Timestamp.fromDate(
          DateTime(1970, birthDate.toDate().month, birthDate.toDate().day))
      : null;

  @override
  DocumentReference get parentId => classId;

  @override
  Reference get photoRef =>
      FirebaseStorage.instance.ref().child('PersonsPhotos/$id');

  Future<String> getCFatherName() async {
    var tmp = (await cFather?.get(dataSource))?.data;
    if (tmp == null) return '';
    return tmp()['Name'] ?? 'لا يوجد';
  }

  Future<String> getChurchName() async {
    var tmp = (await church?.get(dataSource))?.data;
    if (tmp == null) return '';
    return tmp()['Name'] ?? 'لا يوجد';
  }

  Future<String> getClassName() async {
    var tmp = (await classId?.get(dataSource))?.data;
    if (tmp == null) return '';
    return tmp()['Name'] ?? 'لا يوجد';
  }

  @override
  Map<String, dynamic> getHumanReadableMap() => {
        'Name': name ?? '',
        'Phone': phone ?? '',
        'FatherPhone': fatherPhone ?? '',
        'MotherPhone': motherPhone ?? '',
        'Address': address,
        'BirthDate': toDurationString(birthDate, appendSince: false),
        'BirthDay':
            birthDay != null ? DateFormat('d/M').format(birthDay.toDate()) : '',
        'LastTanawol': toDurationString(lastTanawol),
        'LastCall': toDurationString(lastCall),
        'LastConfession': toDurationString(lastConfession),
        'LastKodas': toDurationString(lastKodas),
        'LastMeeting': toDurationString(lastMeeting),
        'LastVisit': toDurationString(lastVisit),
        'Notes': notes ?? '',
      };

  @override
  Map<String, dynamic> getMap() => {
        'ClassId': classId,
        'Name': name,
        'Phone': phone,
        'FatherPhone': fatherPhone,
        'MotherPhone': motherPhone,
        'Phones': (phones?.map((k, v) => MapEntry(k, v)) ?? {})
          ..removeWhere((k, v) => v.toString().isEmpty),
        'Address': address,
        'HasPhoto': hasPhoto ?? false,
        'Color': color.value,
        'BirthDate': birthDate,
        'BirthDay': birthDay,
        'LastTanawol': lastTanawol,
        'LastConfession': lastConfession,
        'LastKodas': lastKodas,
        'LastMeeting': lastMeeting,
        'LastCall': lastCall,
        'LastVisit': lastVisit,
        'LastEdit': lastEdit,
        'Notes': notes,
        'School': school,
        'Church': church,
        'CFather': cFather,
        'Location': location
      };

  Widget getMapView({bool useGPSIfNull = false, bool editMode = false}) {
    if (location == null && useGPSIfNull)
      return FutureBuilder<PermissionStatus>(
        future: Location.instance.requestPermission(),
        builder: (context, data) {
          if (data.hasData && data.data == PermissionStatus.granted) {
            return FutureBuilder<LocationData>(
              future: Location.instance.getLocation(),
              builder: (context, snapshot) {
                if (!snapshot.hasData)
                  return Center(child: CircularProgressIndicator());
                return MapView(
                    childrenDepth: 3,
                    initialLocation:
                        LatLng(snapshot.data.latitude, snapshot.data.longitude),
                    editMode: editMode,
                    person: this);
              },
            );
          }
          return MapView(
              childrenDepth: 3,
              initialLocation: LatLng(34, 50),
              editMode: editMode,
              person: this);
        },
      );
    else if (location == null)
      return Text(
        'لم يتم تحديد موقع للمنزل',
        style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            locale: Locale('ar', 'EG')),
      );
    return MapView(editMode: editMode, person: this, childrenDepth: 3);
  }

  Future<String> getMembersString() {
    return Future(() => phone);
  }

  @override
  Future<String> getParentName() async {
    return await getClassName();
  }

  Future<String> getSchoolName() async {
    var tmp = (await school?.get(dataSource))?.data;
    if (tmp == null) return '';
    return tmp()['Name'] ?? 'لا يوجد';
  }

  // Future<String> getStringType() async {
  //   var tmp = (await type?.get(source: dataSource))?.data;
  //   if (tmp == null) return '';
  //   return tmp['Name'] ?? 'لا يوجد';
  // }

  String getSearchString() {
    return ((name ?? '') +
            (phone ?? '') +
            (fatherPhone ?? '') +
            (motherPhone ?? '') +
            (address ?? '') +
            (birthDate?.toString() ?? '') +
            (notes ?? ''))
        // (type ?? ''))
        .toLowerCase()
        .replaceAll(
            RegExp(
              r'[أإآ]',
            ),
            'ا')
        .replaceAll(
            RegExp(
              r'[ى]',
            ),
            'ي');
  }

  @override
  Future<String> getSecondLine() async {
    String key = Hive.box('Settings').get('PersonSecondLine', defaultValue: '');
    if (key == 'Members') {
      return await getMembersString();
    } else if (key == 'ClassId') {
      return await getClassName();
    } else if (key == 'School') {
      return await getSchoolName();
    } else if (key == 'Church') {
      return await getChurchName();
    } else if (key == 'CFather') {
      return await getCFatherName();
    }
    return getHumanReadableMap()[key] ?? '';
  }

  static Person fromDoc(DocumentSnapshot data) =>
      data.exists ? Person._createFromData(data.data(), data.reference) : null;

  static Future<Person> fromId(String id) async =>
      Person.fromDoc(await FirebaseFirestore.instance.doc('Persons/$id').get());

  static List<Person> getAll(List<DocumentSnapshot> persons) {
    var rslt = <Person>[];
    for (DocumentSnapshot item in persons) {
      rslt.add(Person.fromDoc(item));
    }
    return rslt;
  }

  static Stream<QuerySnapshot> getAllForUser({
    String orderBy = 'Name',
    bool descending = false,
  }) async* {
    await for (var u in User.instance.stream) {
      if (u.superAccess) {
        await for (var s in FirebaseFirestore.instance
            .collection('Persons')
            .orderBy(orderBy, descending: descending)
            .snapshots()) {
          yield s;
        }
      } else {
        await for (var s in FirebaseFirestore.instance
            .collection('Persons')
            .where('ClassId',
                whereIn: (await FirebaseFirestore.instance
                        .collection('Classes')
                        .where('Allowed', arrayContains: u.uid)
                        .get(dataSource))
                    .docs
                    .map((e) => e.reference)
                    .toList())
            .orderBy(orderBy, descending: descending)
            .snapshots()) {
          yield s;
        }
      }
    }
  }

  static Future<List<Person>> getAllPersonsForUser({
    String orderBy = 'Name',
    bool descending = false,
  }) async {
    if (User.instance.superAccess) {
      return (await FirebaseFirestore.instance
              .collection('Persons')
              .orderBy(orderBy, descending: descending)
              .get(dataSource))
          .docs
          .map((e) => Person.fromDoc(e))
          .toList();
    }
    return (await FirebaseFirestore.instance
            .collection('Persons')
            .where('ClassId',
                whereIn: (await FirebaseFirestore.instance
                        .collection('Classes')
                        .where('Allowed',
                            arrayContains:
                                auth.FirebaseAuth.instance.currentUser.uid)
                        .get(dataSource))
                    .docs
                    .map((e) => e.reference)
                    .toList())
            .orderBy(orderBy, descending: descending)
            .get(dataSource))
        .docs
        .map((e) => Person.fromDoc(e))
        .toList();
  }

  static Map<String, dynamic> getEmptyExportMap() => {
        'ID': 'id',
        'ClassId': 'classId',
        'Name': 'name',
        'Phone': 'phone',
        'FatherPhone': 'fatherPhone',
        'MotherPhone': 'motherPhone',
        'Address': 'address',
        'HasPhoto': 'hasPhoto',
        'Color': 'color',
        'BirthDate': 'birthDate',
        'BirthDay': 'birthDay',
        'LastTanawol': 'lastTanawol',
        'LastConfession': 'lastConfession',
        'LastKodas': 'lastKodas',
        'LastMeeting': 'lastMeeting',
        'LastVisit': 'lastVisit',
        // 'Type': 'type',
        'Notes': 'notes',
        'School': 'School',
        'Church': 'church',
        'Meeting': 'meeting',
        'CFather': 'cFather',
        'Location': 'location',
      };

  static Map<String, dynamic> getHumanReadableMap2() => {
        'Name': 'الاسم',
        'Phone': 'موبايل (مخدومي)',
        'FatherPhone': 'موبايل الأب',
        'MotherPhone': 'موبايل الأم',
        'Address': 'العنوان',
        'Color': 'اللون',
        'BirthDate': 'تاريخ الميلاد',
        'BirthDay': 'يوم الميلاد',
        'LastConfession': 'تاريخ أخر اعتراف',
        'LastKodas': 'تاريخ أخر قداس',
        'LastTanawol': 'تاريخ أخر تناول',
        'LastMeeting': 'تاريخ أخر اجتماع',
        'LastVisit': 'تاريخ أخر افتقاد',
        'LastCall': 'تاريخ أخر مكالمة',
        'Notes': 'ملاحظات',
        'Location': 'الموقع',
      };
}
