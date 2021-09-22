import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:location/location.dart';
import 'package:meetinghelper/models/super_classes.dart';
import 'package:meetinghelper/utils/globals.dart';
import 'package:meetinghelper/utils/helpers.dart';
import 'package:meetinghelper/utils/typedefs.dart';
import 'package:meetinghelper/views/map_view.dart';
import 'package:rxdart/rxdart.dart';
import 'package:tuple/tuple.dart';

import '../property_metadata.dart';
import 'class.dart';
import 'user.dart';

class Person extends DataObject with PhotoObject, ChildObject<Class> {
  JsonRef? classId;

  String? address;
  GeoPoint? location;

  String? phone;
  String? fatherPhone;
  String? motherPhone;
  Json phones;

  Timestamp? birthDate;

  JsonRef? school;
  JsonRef? church;
  JsonRef? cFather;

  Timestamp? lastMeeting;
  Timestamp? lastKodas;

  Timestamp? lastTanawol;
  Timestamp? lastConfession;
  Timestamp? lastCall;

  Map<String, Timestamp> last;

  Timestamp? lastVisit;
  String? lastEdit;
  String? notes;

  bool isShammas;

  /// IsMale?
  bool gender;
  String? shammasLevel;
  JsonRef? studyYear;

  ///List of services this person is participant
  List<JsonRef> services;

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
      this.isShammas = false,
      this.gender = true,
      this.shammasLevel,
      this.studyYear,
      List<JsonRef>? services,
      Map<String, Timestamp>? last,
      Color color = Colors.transparent})
      : services = services ?? [],
        phones = phones ?? {},
        last = last ?? {},
        super(
            ref ??
                FirebaseFirestore.instance
                    .collection('Persons')
                    .doc(id ?? 'null'),
            name,
            color) {
    this.hasPhoto = hasPhoto;
    defaultIcon = Icons.person;
  }

  Person.createFromData(Map<dynamic, dynamic> data, JsonRef ref)
      : classId = data['ClassId'],
        phone = data['Phone'],
        fatherPhone = data['FatherPhone'],
        motherPhone = data['MotherPhone'],
        phones = (data['Phones'] as Map?)?.cast() ?? {},
        address = data['Address'],
        location = data['Location'],
        birthDate = data['BirthDate'],
        lastConfession = data['LastConfession'],
        lastTanawol = data['LastTanawol'],
        lastKodas = data['LastKodas'],
        lastMeeting = data['LastMeeting'],
        lastCall = data['LastCall'],
        lastVisit = data['LastVisit'],
        lastEdit = data['LastEdit'],
        last = (data['Last'] as Map?)?.cast() ?? {},
        notes = data['Notes'],
        school = data['School'],
        church = data['Church'],
        cFather = data['CFather'],
        isShammas = data['IsShammas'] ?? false,
        gender = data['Gender'] ?? true,
        shammasLevel = data['ShammasLevel'],
        studyYear = data['StudyYear'],
        services = (data['Services'] as List?)?.cast<JsonRef>() ?? [],
        super.createFromData(data, ref) {
    hasPhoto = data['HasPhoto'] ?? false;
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

  Future<String> getStudyYearName() async {
    return (await studyYear?.get(dataSource))?.data()?['Name'] ??
        getClassStudyYearName();
  }

  Future<String> getClassStudyYearName() async {
    return (await ((await classId?.get(dataSource))?.data()?['StudyYear']
                    as JsonRef?)
                ?.get(dataSource))
            ?.data()?['Name'] ??
        '';
  }

  Future<String> getChurchName() async {
    return (await church?.get(dataSource))?.data()?['Name'] ?? '';
  }

  Future<String> getClassName() async {
    return (await classId?.get(dataSource))?.data()?['Name'] ?? '';
  }

  @override
  Json formattedProps() => {
        'ClassId': getClassName(),
        'Name': name,
        'Phone': phone ?? '',
        'FatherPhone': fatherPhone ?? '',
        'MotherPhone': motherPhone ?? '',
        'Phones': null,
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
        'Last':
            last.map((key, value) => MapEntry(key, toDurationString(value))),
        'Notes': notes ?? '',
        'IsShammas': isShammas ? 'تعم' : 'لا',
        'Gender': gender ? 'ذكر' : 'أنثى',
        'ShammasLevel': shammasLevel,
        'HasPhoto': hasPhoto ? 'نعم' : 'لا',
        'Color': '0x' + color.value.toRadixString(16),
        'LastEdit': User.onlyName(lastEdit),
        'School': getSchoolName(),
        'Church': getChurchName(),
        'CFather': getCFatherName(),
        'Location': location == null
            ? ''
            : '${location!.latitude},${location!.longitude}',
        'StudyYear': getStudyYearName(),
        'Services': services.isEmpty
            ? 'لا يوجد خدمات'
            : Future.wait(services.take(3).map((r) async =>
                    (await r.get(dataSource)).data()?['Name'] ?? ''))
                .then((d) => d.join(','))
                .catchError((_) => ''),
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
        'Last': last,
        'Notes': notes,
        'School': school,
        'Church': church,
        'CFather': cFather,
        'Location': location,
        'IsShammas': isShammas,
        'Gender': gender,
        'ShammasLevel': shammasLevel,
        'StudyYear': studyYear,
        'Services': services,
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
  FutureOr<String?> getSecondLine() async {
    final String? key = Hive.box('Settings').get('PersonSecondLine');

    if (key == null) return null;

    return formattedProps()[key];
  }

  static Person? fromDoc(JsonDoc data) =>
      data.exists ? Person.createFromData(data.data()!, data.reference) : null;

  static Person fromQueryDoc(JsonQueryDoc data) =>
      Person.createFromData(data.data(), data.reference);

  static Future<Person?> fromId(String id) async =>
      Person.fromDoc(await FirebaseFirestore.instance.doc('Persons/$id').get());

  static Stream<List<Person>> getAllForUser(
      {String orderBy = 'Name',
      bool descending = false,
      Query<Json> Function(Query<Json>, String, bool) queryCompleter =
          kDefaultQueryCompleter}) {
    return Rx.combineLatest2<User, List<Class>, Tuple2<User, List<Class>>>(
        User.instance.stream,
        Class.getAllForUser(),
        (a, b) => Tuple2<User, List<Class>>(a, b)).switchMap(
      (u) {
        if (u.item1.superAccess) {
          return queryCompleter(
                  FirebaseFirestore.instance.collection('Persons'),
                  orderBy,
                  descending)
              .snapshots()
              .map((p) => p.docs.map(fromQueryDoc).toList());
        }

        return Rx.combineLatest2<List<Person>, List<Person>, List<Person>>(
          //Persons from Classes
          u.item2.isNotEmpty
              ? u.item2.length <= 10
                  ? queryCompleter(
                          FirebaseFirestore.instance.collection('Persons').where('ClassId',
                              whereIn: u.item2.map((e) => e.ref).toList()),
                          orderBy,
                          descending)
                      .snapshots()
                      .map((p) => p.docs.map(fromQueryDoc).toList())
                  : Rx.combineLatestList<JsonQuery>(u.item2.split(10).map((c) => queryCompleter(
                          FirebaseFirestore.instance
                              .collection('Persons')
                              .where('ClassId', whereIn: c.map((e) => e.ref).toList()),
                          orderBy,
                          descending)
                      .snapshots())).map((s) => s.expand((n) => n.docs).map(fromQueryDoc).toList())
              : Stream.value([]),
          //Persons from Services
          u.item1.adminServices.isNotEmpty
              ? u.item1.adminServices.length <= 10
                  ? queryCompleter(
                          FirebaseFirestore.instance
                              .collection('Persons')
                              .where('Services',
                                  arrayContainsAny: u.item1.adminServices),
                          orderBy,
                          descending)
                      .snapshots()
                      .map((p) => p.docs.map(fromQueryDoc).toList())
                  : Rx.combineLatestList<JsonQuery>(u.item1.adminServices
                      .split(10)
                      .map((c) =>
                          queryCompleter(FirebaseFirestore.instance.collection('Persons').where('Services', arrayContainsAny: c), orderBy, descending)
                              .snapshots())).map(
                      (s) => s.expand((n) => n.docs).map(fromQueryDoc).toList())
              : Stream.value([]),
          (a, b) => {...a, ...b}.sortedByCompare(
            (p) => p.getMap()[orderBy],
            (o, n) {
              if (o is String && n is String)
                return descending ? -o.compareTo(n) : o.compareTo(n);
              if (o is int && n is int)
                return descending ? -o.compareTo(n) : o.compareTo(n);
              if (o is Timestamp && n is Timestamp)
                return descending ? -o.compareTo(n) : o.compareTo(n);
              if (o is Timestamp && n is Timestamp)
                return descending ? -o.compareTo(n) : o.compareTo(n);
              return 0;
            },
          ),
        );
      },
    );
  }

  static Map<String, PropertyMetadata> propsMetadata() => {
        'ClassId': PropertyMetadata<JsonRef>(
          name: 'ClassId',
          label: 'داخل فصل',
          defaultValue: null,
          collection:
              FirebaseFirestore.instance.collection('Classes').orderBy('Grade'),
        ),
        'Name': const PropertyMetadata<String>(
          name: 'Name',
          label: 'الاسم',
          defaultValue: '',
        ),
        'Phone': const PropertyMetadata<String>(
          name: 'Phone',
          label: 'موبايل (شخصي)',
          defaultValue: '',
        ),
        'FatherPhone': const PropertyMetadata<String>(
          name: 'FatherPhone',
          label: 'موبايل الأب',
          defaultValue: '',
        ),
        'MotherPhone': const PropertyMetadata<String>(
          name: 'MotherPhone',
          label: 'موبايل الأم',
          defaultValue: '',
        ),
        'Phones': const PropertyMetadata<Json>(
          name: 'Phones',
          label: 'الأرقام الأخرى',
          defaultValue: {},
        ),
        'Address': const PropertyMetadata<String>(
          name: 'Address',
          label: 'العنوان',
          defaultValue: '',
        ),
        'HasPhoto': const PropertyMetadata<bool>(
          name: 'HasPhoto',
          label: 'لديه صورة',
          defaultValue: false,
        ),
        'Color': const PropertyMetadata<Color>(
          name: 'Color',
          label: 'اللون',
          defaultValue: Colors.transparent,
        ),
        'BirthDate': const PropertyMetadata<DateTime>(
          name: 'BirthDate',
          label: 'تاريخ الميلاد',
          defaultValue: null,
        ),
        'BirthDay': const PropertyMetadata<DateTime>(
          name: 'BirthDay',
          label: 'يوم الميلاد',
          defaultValue: null,
        ),
        'LastTanawol': const PropertyMetadata<DateTime>(
          name: 'LastTanawol',
          label: 'تاريخ أخر تناول',
          defaultValue: null,
        ),
        'LastConfession': const PropertyMetadata<DateTime>(
          name: 'LastConfession',
          label: 'تاريخ أخر اعتراف',
          defaultValue: null,
        ),
        'LastKodas': const PropertyMetadata<DateTime>(
          name: 'LastKodas',
          label: 'تاريخ أخر حضور قداس',
          defaultValue: null,
        ),
        'LastMeeting': const PropertyMetadata<DateTime>(
          name: 'LastMeeting',
          label: 'تاريخ أخر حضور قداس',
          defaultValue: null,
        ),
        'LastCall': const PropertyMetadata<DateTime>(
          name: 'LastCall',
          label: 'تاريخ أخر مكالمة',
          defaultValue: null,
        ),
        'LastVisit': const PropertyMetadata<DateTime>(
          name: 'LastVisit',
          label: 'تاريخ أخر افتقاد',
          defaultValue: null,
        ),
        'LastEdit': PropertyMetadata<JsonRef>(
          name: 'LastEdit',
          label: 'أخر تعديل',
          defaultValue: null,
          collection:
              FirebaseFirestore.instance.collection('Users').orderBy('Name'),
        ),
        'Last': const PropertyMetadata<Json>(
          name: 'Last',
          label: 'تاريخ أخر حضور خدمة',
          defaultValue: {},
        ),
        'Notes': const PropertyMetadata<String>(
          name: 'Notes',
          label: 'ملاحظات',
          defaultValue: '',
        ),
        'School': PropertyMetadata<JsonRef>(
          name: 'School',
          label: 'المدرسة',
          defaultValue: null,
          collection:
              FirebaseFirestore.instance.collection('Schools').orderBy('Name'),
        ),
        'Church': PropertyMetadata<JsonRef>(
          name: 'Church',
          label: 'الكنيسة',
          defaultValue: null,
          collection:
              FirebaseFirestore.instance.collection('Churches').orderBy('Name'),
        ),
        'CFather': PropertyMetadata<JsonRef>(
          name: 'CFather',
          label: 'أب الاعتراف',
          defaultValue: null,
          collection:
              FirebaseFirestore.instance.collection('Fathers').orderBy('Name'),
        ),
        'Location': const PropertyMetadata<GeoPoint>(
          name: 'Location',
          label: 'الموقع الجغرافي',
          defaultValue: null,
        ),
        'IsShammas': const PropertyMetadata<bool>(
          name: 'IsShammas',
          label: 'شماس؟',
          defaultValue: false,
        ),
        'Gender': const PropertyMetadata<bool>(
          name: 'Gender',
          label: 'النوع',
          defaultValue: true,
        ),
        'ShammasLevel': const PropertyMetadata<String>(
          name: 'ShammasLevel',
          label: 'رتبة الشموسية',
          defaultValue: '',
        ),
        'StudyYear': PropertyMetadata<JsonRef>(
          name: 'StudyYear',
          label: 'سنة الدراسة',
          defaultValue: null,
          collection: FirebaseFirestore.instance
              .collection('StudyYears')
              .orderBy('Grade'),
        ),
        'Services': const PropertyMetadata<List>(
          name: 'Services',
          label: 'الخدمات المشارك بها',
          defaultValue: [],
        ),
      };

  @override
  Person copyWith() {
    return Person.createFromData(getMap(), ref);
  }
}
