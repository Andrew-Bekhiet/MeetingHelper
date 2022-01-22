import 'dart:async';

import 'package:churchdata_core/churchdata_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart' show DocumentReference;
import 'package:collection/collection.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:location/location.dart';
import 'package:meetinghelper/repositories/database_repository.dart';
import 'package:meetinghelper/views/map_view.dart';

part 'person.g.dart';

@immutable
@CopyWith(copyWithNull: true)
class Person extends PersonBase {
  final JsonRef? classId;

  String? get phone => super.mainPhone;
  final String? fatherPhone;
  final String? motherPhone;
  Json get phones => super.otherPhones;

  final DateTime? lastMeeting;

  final Map<String, DateTime> last;

  ///List of services this person is participant
  final UnmodifiableListView<JsonRef> services;

  Person({
    required JsonRef ref,
    this.classId,
    String name = '',
    String? phone,
    Json? phones,
    this.fatherPhone = '',
    this.motherPhone = '',
    String? address,
    GeoPoint? location,
    bool hasPhoto = false,
    DateTime? birthDate,
    DateTime? lastTanawol,
    DateTime? lastConfession,
    DateTime? lastKodas,
    this.lastMeeting,
    DateTime? lastCall,
    DateTime? lastVisit,
    LastEdit? lastEdit,
    String? notes,
    JsonRef? school,
    JsonRef? college,
    JsonRef? church,
    JsonRef? cFather,
    bool isShammas = false,
    bool gender = true,
    String? shammasLevel,
    JsonRef? studyYear,
    List<JsonRef>? services,
    Map<String, DateTime>? last,
    Color? color,
  })  : services = UnmodifiableListView(services ?? []),
        last = last ?? {},
        super(
          ref: ref,
          name: name,
          color: color,
          address: address,
          location: location,
          mainPhone: phone,
          otherPhones: phones ?? {},
          birthDate: birthDate,
          school: school,
          college: college,
          church: church,
          cFather: cFather,
          lastKodas: lastKodas,
          lastTanawol: lastTanawol,
          lastConfession: lastConfession,
          lastCall: lastCall,
          lastVisit: lastVisit,
          lastEdit: lastEdit,
          notes: notes,
          isShammas: isShammas,
          gender: gender,
          shammasLevel: shammasLevel,
          studyYear: studyYear,
          hasPhoto: hasPhoto,
        );

  Person.fromDoc(JsonDoc doc)
      : classId = doc.data()!['ClassId'],
        fatherPhone = doc.data()!['FatherPhone'],
        motherPhone = doc.data()!['MotherPhone'],
        lastMeeting = doc.data()!['LastMeeting'],
        last = (doc.data()!['Last'] as Map?)?.cast() ?? {},
        services = UnmodifiableListView(
            (doc.data()!['Services'] as List?)?.cast<JsonRef>() ?? []),
        super(
          ref: doc.reference,
          hasPhoto: doc.data()!['HasPhoto'] ?? false,
          color:
              doc.data()!['Color'] == null ? null : Color(doc.data()!['Color']),
          name: doc.data()!['Name'],
          address: doc.data()!['Address'],
          location: doc.data()!['Location'],
          mainPhone: doc.data()!['Phone'],
          otherPhones: (doc.data()!['Phones'] as Map?)?.cast() ?? {},
          birthDate: (doc.data()!['BirthDate'] as Timestamp?)?.toDate(),
          school: doc.data()!['School'],
          college: doc.data()!['College'],
          church: doc.data()!['Church'],
          cFather: doc.data()!['CFather'],
          lastKodas: (doc.data()!['LastKodas'] as Timestamp?)?.toDate(),
          lastTanawol: (doc.data()!['LastTanawol'] as Timestamp?)?.toDate(),
          lastConfession:
              (doc.data()!['LastConfession'] as Timestamp?)?.toDate(),
          lastCall: (doc.data()!['LastCall'] as Timestamp?)?.toDate(),
          lastVisit: (doc.data()!['LastVisit'] as Timestamp?)?.toDate(),
          lastEdit: doc.data()!['LastEdit'] == null
              ? null
              : LastEdit.fromJson(doc.data()!['LastEdit']),
          notes: doc.data()!['Notes'],
          isShammas: doc.data()!['IsShammas'] ?? false,
          gender: doc.data()!['Gender'] ?? true,
          shammasLevel: doc.data()!['ShammasLevel'],
          studyYear: doc.data()!['StudyYear'],
        );

  factory Person.empty() => Person(
        ref: GetIt.I<DatabaseRepository>().collection('Persons').doc('null'),
      );

  DateTime? get birthDay => birthDate != null
      ? DateTime(1970, birthDate!.month, birthDate!.day)
      : null;

  Future<String> getCFatherName() async {
    return (await cFather?.get())?.data()?['Name'] ?? '';
  }

  Future<String> getStudyYearName() async {
    return (await studyYear?.get())?.data()?['Name'] ?? getClassStudyYearName();
  }

  Future<String> getClassStudyYearName() async {
    return (await ((await classId?.get())?.data()?['StudyYear'] as JsonRef?)
                ?.get())
            ?.data()?['Name'] ??
        '';
  }

  Future<String> getChurchName() async {
    return (await church?.get())?.data()?['Name'] ?? '';
  }

  Future<String> getClassName() async {
    return (await classId?.get())?.data()?['Name'] ?? '';
  }

  Json formattedProps() => {
        'ClassId': getClassName(),
        'Name': name,
        'Phone': phone ?? '',
        'FatherPhone': fatherPhone ?? '',
        'MotherPhone': motherPhone ?? '',
        'Phones': null,
        'Address': address,
        'BirthDate': birthDate?.toDurationString(appendSince: false),
        'BirthDay': birthDay != null ? DateFormat('d/M').format(birthDay!) : '',
        'LastTanawol': lastTanawol?.toDurationString(),
        'LastCall': lastCall?.toDurationString(),
        'LastConfession': lastConfession?.toDurationString(),
        'LastKodas': lastKodas?.toDurationString(),
        'LastMeeting': lastMeeting?.toDurationString(),
        'LastVisit': lastVisit?.toDurationString(),
        'Last':
            last.map((key, value) => MapEntry(key, value.toDurationString())),
        'Notes': notes ?? '',
        'IsShammas': isShammas ? 'تعم' : 'لا',
        'Gender': gender ? 'ذكر' : 'أنثى',
        'ShammasLevel': shammasLevel,
        'HasPhoto': hasPhoto ? 'نعم' : 'لا',
        'Color': color != null ? '0x' + color!.value.toRadixString(16) : null,
        'LastEdit': lastEdit != null
            ? MHDatabaseRepo.instance.getUserName(lastEdit!.uid)
            : null,
        'School': getSchoolName(),
        'College': getCollegeName(),
        'Church': getChurchName(),
        'CFather': getCFatherName(),
        'Location': location == null
            ? ''
            : '${location!.latitude},${location!.longitude}',
        'StudyYear': getStudyYearName(),
        'Services': services.isEmpty
            ? 'لا يوجد خدمات'
            : Future.wait(services
                    .take(3)
                    .map((r) async => (await r.get()).data()?['Name'] ?? ''))
                .then((d) => d.join(','))
                .catchError((_) => ''),
      };

  @override
  Json toJson() => {
        ...super.toJson()
          ..remove('MainPhone')
          ..remove('OtherPhones'),
        'ClassId': classId,
        'Phone': phone,
        'FatherPhone': fatherPhone,
        'MotherPhone': motherPhone,
        'Phones': phones.map(MapEntry.new)
          ..removeWhere((k, v) => v.toString().isEmpty),
        'HasPhoto': hasPhoto,
        'LastMeeting': lastMeeting,
        'Last': last,
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

  Future<String> getSchoolName() async {
    return (await school?.get())?.data()?['Name'] ?? '';
  }

  Future<String> getCollegeName() async {
    return (await college?.get())?.data()?['Name'] ?? '';
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
    final String? key =
        GetIt.I<CacheRepository>().box('Settings').get('PersonSecondLine');

    if (key == null) return null;

    return formattedProps()[key];
  }

  static Map<String, PropertyMetadata> propsMetadata() => {
        ...PersonBase.propsMetadata
          ..remove('MainPhone')
          ..remove('OtherPhones'),
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
        'StudyYear': PropertyMetadata<JsonRef>(
          name: 'StudyYear',
          label: 'سنة الدراسة',
          defaultValue: null,
          collection: GetIt.I<DatabaseRepository>()
              .collection('StudyYears')
              .orderBy('Grade'),
        ),
        'ClassId': PropertyMetadata<JsonRef>(
          name: 'ClassId',
          label: 'داخل فصل',
          defaultValue: null,
          collection: GetIt.I<DatabaseRepository>()
              .collection('Classes')
              .orderBy('Grade'),
        ),
        'Services': const PropertyMetadata<List>(
          name: 'Services',
          label: 'الخدمات المشارك بها',
          defaultValue: [],
        ),
        'Gender': const PropertyMetadata<bool>(
          name: 'Gender',
          label: 'النوع',
          defaultValue: true,
        ),
        'IsShammas': const PropertyMetadata<bool>(
          name: 'IsShammas',
          label: 'شماس؟',
          defaultValue: false,
        ),
        'ShammasLevel': const PropertyMetadata<String>(
          name: 'ShammasLevel',
          label: 'رتبة الشموسية',
          defaultValue: '',
        ),
        'Address': const PropertyMetadata<String>(
          name: 'Address',
          label: 'العنوان',
          defaultValue: '',
        ),
        'Location': const PropertyMetadata<GeoPoint>(
          name: 'Location',
          label: 'الموقع الجغرافي',
          defaultValue: null,
        ),
        'School': PropertyMetadata<JsonRef>(
          name: 'School',
          label: 'المدرسة',
          defaultValue: null,
          collection: GetIt.I<DatabaseRepository>()
              .collection('Schools')
              .orderBy('Name'),
        ),
        'College': PropertyMetadata<JsonRef>(
          name: 'College',
          label: 'الكلية',
          defaultValue: null,
          collection: GetIt.I<DatabaseRepository>()
              .collection('Colleges')
              .orderBy('Name'),
        ),
        'Church': PropertyMetadata<JsonRef>(
          name: 'Church',
          label: 'الكنيسة',
          defaultValue: null,
          collection: GetIt.I<DatabaseRepository>()
              .collection('Churches')
              .orderBy('Name'),
        ),
        'CFather': PropertyMetadata<JsonRef>(
          name: 'CFather',
          label: 'أب الاعتراف',
          defaultValue: null,
          collection: GetIt.I<DatabaseRepository>()
              .collection('Fathers')
              .orderBy('Name'),
        ),
        'Notes': const PropertyMetadata<String>(
          name: 'Notes',
          label: 'ملاحظات',
          defaultValue: '',
        ),
        'LastMeeting': const PropertyMetadata<DateTime>(
          name: 'LastMeeting',
          label: 'تاريخ أخر حضور اجتماع',
          defaultValue: null,
        ),
        'LastKodas': const PropertyMetadata<DateTime>(
          name: 'LastKodas',
          label: 'تاريخ أخر حضور قداس',
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
        'LastVisit': const PropertyMetadata<DateTime>(
          name: 'LastVisit',
          label: 'تاريخ أخر افتقاد',
          defaultValue: null,
        ),
        'LastCall': const PropertyMetadata<DateTime>(
          name: 'LastCall',
          label: 'تاريخ أخر مكالمة',
          defaultValue: null,
        ),
        'Last': const PropertyMetadata<Json>(
          name: 'Last',
          label: 'تاريخ أخر حضور خدمة',
          defaultValue: {},
        ),
        'LastEdit': PropertyMetadata<JsonRef>(
          name: 'LastEdit',
          label: 'أخر تعديل',
          defaultValue: null,
          collection:
              GetIt.I<DatabaseRepository>().collection('Users').orderBy('Name'),
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
      };
}
