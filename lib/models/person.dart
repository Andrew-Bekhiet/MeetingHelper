import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:location/location.dart';
import 'package:meetinghelper/models/models.dart';
import 'package:meetinghelper/models/super_classes.dart';
import 'package:meetinghelper/utils/globals.dart';
import 'package:meetinghelper/utils/helpers.dart';
import 'package:meetinghelper/utils/typedefs.dart';
import 'package:meetinghelper/views/map_view.dart';
import 'package:rxdart/rxdart.dart';
import 'package:tuple/tuple.dart';

import 'user.dart';

class Person extends DataObject with PhotoObject, ChildObject<Class> {
  JsonRef? classId;

  String? address;
  GeoPoint? location;

  String? phone;
  String? fatherPhone;
  String? motherPhone;
  late Json phones;

  Timestamp? birthDate;

  JsonRef? school;
  JsonRef? church;
  JsonRef? cFather;

  Timestamp? lastConfession;
  Timestamp? lastTanawol;
  Timestamp? lastKodas;
  Timestamp? lastMeeting;
  Timestamp? lastCall;

  Timestamp? lastVisit;
  String? lastEdit;
  String? notes;

  Person(
      {String? id,
      JsonRef? ref,
      this.classId,
      String name = '',
      this.phone = '',
      Json? phones,
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
    this.phones = phones ?? {};
    defaultIcon = Icons.person;
  }

  Person.createFromData(Map<dynamic, dynamic> data, JsonRef ref)
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

  Timestamp? get birthDay => birthDate != null
      ? Timestamp.fromDate(
          DateTime(1970, birthDate!.toDate().month, birthDate!.toDate().day))
      : null;

  @override
  JsonRef? get parentId => classId;

  @override
  Reference get photoRef =>
      FirebaseStorage.instance.ref().child('PersonsPhotos/$id');

  Future<String> getCFatherName() async {
    return (await cFather?.get(dataSource))?.data()?['Name'] ?? '';
  }

  Future<String> getChurchName() async {
    return (await church?.get(dataSource))?.data()?['Name'] ?? '';
  }

  Future<String> getClassName() async {
    return (await classId?.get(dataSource))?.data()?['Name'] ?? '';
  }

  @override
  Json getHumanReadableMap() => {
        'Name': name,
        'Phone': phone ?? '',
        'FatherPhone': fatherPhone ?? '',
        'MotherPhone': motherPhone ?? '',
        'Address': address,
        'BirthDate': toDurationString(birthDate, appendSince: false),
        'BirthDay': birthDay != null
            ? DateFormat('d/M').format(birthDay!.toDate())
            : '',
        'LastTanawol': toDurationString(lastTanawol),
        'LastCall': toDurationString(lastCall),
        'LastConfession': toDurationString(lastConfession),
        'LastKodas': toDurationString(lastKodas),
        'LastMeeting': toDurationString(lastMeeting),
        'LastVisit': toDurationString(lastVisit),
        'Notes': notes ?? '',
      };

  @override
  Json getMap() => {
        'ClassId': classId,
        'Name': name,
        'Phone': phone,
        'FatherPhone': fatherPhone,
        'MotherPhone': motherPhone,
        'Phones': phones.map((k, v) => MapEntry(k, v))
          ..removeWhere((k, v) => v.toString().isEmpty),
        'Address': address,
        'HasPhoto': hasPhoto,
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
                  return const Center(child: CircularProgressIndicator());
                return MapView(
                    childrenDepth: 3,
                    initialLocation: LatLng(snapshot.data!.latitude ?? 34,
                        snapshot.data!.longitude ?? 50),
                    editMode: editMode,
                    person: this);
              },
            );
          }
          return MapView(
              childrenDepth: 3,
              initialLocation: const LatLng(34, 50),
              editMode: editMode,
              person: this);
        },
      );
    else if (location == null)
      return const Text(
        'لم يتم تحديد موقع للمنزل',
        style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            locale: Locale('ar', 'EG')),
      );
    return MapView(editMode: editMode, person: this, childrenDepth: 3);
  }

  String? getMembersString() => phone;

  @override
  Future<String> getParentName() {
    return getClassName();
  }

  Future<String> getSchoolName() async {
    return (await school?.get(dataSource))?.data()?['Name'] ?? '';
  }

  String getSearchString() {
    return (name +
            (phone ?? '') +
            (fatherPhone ?? '') +
            (motherPhone ?? '') +
            (address ?? '') +
            (birthDate?.toString() ?? '') +
            (notes ?? ''))
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
  Future<String?> getSecondLine() async {
    String key = Hive.box('Settings').get('PersonSecondLine', defaultValue: '');
    if (key == 'Members') {
      return getMembersString();
    } else if (key == 'ClassId') {
      return getClassName();
    } else if (key == 'School') {
      return getSchoolName();
    } else if (key == 'Church') {
      return getChurchName();
    } else if (key == 'CFather') {
      return getCFatherName();
    }
    return getHumanReadableMap()[key] ?? '';
  }

  static Person? fromDoc(JsonDoc data) =>
      data.exists ? Person.createFromData(data.data()!, data.reference) : null;

  static Person fromQueryDoc(JsonQueryDoc data) =>
      Person.createFromData(data.data(), data.reference);

  static Future<Person?> fromId(String id) async =>
      Person.fromDoc(await FirebaseFirestore.instance.doc('Persons/$id').get());

  static Stream<List<Person>> getAllForUser({
    String orderBy = 'Name',
    bool descending = false,
  }) {
    return Rx.combineLatest2<User, List<Class>, Tuple2<User, List<Class>>>(
        User.instance.stream,
        Class.getAllForUser(),
        (a, b) => Tuple2<User, List<Class>>(a, b)).switchMap(
      (u) {
        if (u.item1.superAccess) {
          return FirebaseFirestore.instance
              .collection('Persons')
              .orderBy(orderBy, descending: descending)
              .snapshots()
              .map((p) => p.docs.map(fromQueryDoc).toList());
        } else if (u.item2.length <= 10) {
          return FirebaseFirestore.instance
              .collection('Persons')
              .where('ClassId', whereIn: u.item2.map((e) => e.ref).toList())
              .orderBy(orderBy, descending: descending)
              .snapshots()
              .map((p) => p.docs.map(fromQueryDoc).toList());
        }
        return Rx.combineLatestList<JsonQuery>(u.item2.split(10).map((c) =>
                FirebaseFirestore.instance
                    .collection('Persons')
                    .where('ClassId', whereIn: c.map((e) => e.ref).toList())
                    .orderBy(orderBy, descending: descending)
                    .snapshots()))
            .map((s) => s.expand((n) => n.docs).map(fromQueryDoc).toList());
      },
    );
  }

  static Json getEmptyExportMap() => {
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

  static Json getHumanReadableMap2() => {
        'Name': 'الاسم',
        'Phone': 'موبايل (شخصي)',
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

  @override
  Person copyWith() {
    return Person.createFromData(getMap(), ref);
  }
}
