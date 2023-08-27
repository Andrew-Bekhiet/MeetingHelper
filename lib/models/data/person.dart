import 'dart:async';

import 'package:churchdata_core/churchdata_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart'
    show DocumentReference, FieldPath;
import 'package:collection/collection.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:intl/intl.dart';
import 'package:meetinghelper/repositories/database_repository.dart';

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

  final UnmodifiableMapView<String, DateTime> last;
  final UnmodifiableMapView<String, int> examScores;

  ///List of services this person is participant
  final UnmodifiableListView<JsonRef> services;

  Person({
    required super.ref,
    this.classId,
    super.name = '',
    String? phone,
    Json? phones,
    this.fatherPhone,
    this.motherPhone,
    super.address,
    super.location,
    super.hasPhoto,
    super.birthDate,
    super.lastTanawol,
    super.lastConfession,
    super.lastKodas,
    this.lastMeeting,
    super.lastCall,
    super.lastVisit,
    super.lastEdit,
    super.notes,
    super.school,
    super.college,
    super.church,
    super.cFather,
    super.isShammas,
    super.gender,
    super.shammasLevel,
    super.studyYear,
    List<JsonRef>? services,
    Map<String, DateTime>? last,
    Map<String, int>? examScores,
    super.color,
  })  : services = UnmodifiableListView(services ?? []),
        last = UnmodifiableMapView(last ?? {}),
        examScores = UnmodifiableMapView(examScores ?? {}),
        super(
          mainPhone: phone,
          otherPhones: phones ?? {},
        );

  Person.fromDoc(JsonDoc doc) : this.fromJson(doc.data()!, doc.reference);
  Person.fromJson(Json json, JsonRef ref)
      : classId = json['ClassId'],
        fatherPhone = json['FatherPhone'],
        motherPhone = json['MotherPhone'],
        lastMeeting = (json['LastMeeting'] as Timestamp?)?.toDate(),
        last = UnmodifiableMapView(
          {
            for (final o in (json['Last'] as Map? ?? {}).entries)
              if (o.value != null) o.key: (o.value as Timestamp).toDate(),
          },
        ),
        examScores = UnmodifiableMapView(
          {
            for (final o in (json['ExamScores'] as Map? ?? {}).entries)
              if (o.value != null) o.key: o.value as int,
          },
        ),
        services = UnmodifiableListView(
          (json['Services'] as List?)?.cast<JsonRef>() ?? [],
        ),
        super(
          ref: ref,
          hasPhoto: json['HasPhoto'] ?? false,
          color: json['Color'] == null || json['Color'] == 0
              ? null
              : Color(json['Color']),
          name: json['Name'],
          address: json['Address'],
          location: json['Location'],
          mainPhone: json['Phone'],
          otherPhones: (json['Phones'] as Map?)?.cast() ?? {},
          birthDate: (json['BirthDate'] as Timestamp?)?.toDate(),
          school: json['School'],
          college: json['College'],
          church: json['Church'],
          cFather: json['CFather'],
          lastKodas: (json['LastKodas'] as Timestamp?)?.toDate(),
          lastTanawol: (json['LastTanawol'] as Timestamp?)?.toDate(),
          lastConfession: (json['LastConfession'] as Timestamp?)?.toDate(),
          lastCall: (json['LastCall'] as Timestamp?)?.toDate(),
          lastVisit: (json['LastVisit'] as Timestamp?)?.toDate(),
          lastEdit: json['LastEdit'] == null
              ? null
              : LastEdit(
                  json['LastEdit'],
                  json['LastEditTime']?.toDate() ?? DateTime.now(),
                ),
          notes: json['Notes'],
          isShammas: json['IsShammas'] ?? false,
          gender: json['Gender'] ?? true,
          shammasLevel: json['ShammasLevel'],
          studyYear: json['StudyYear'],
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
        'ExamScores': examScores.map(MapEntry.new),
        'Notes': notes ?? '',
        'IsShammas': isShammas ? 'تعم' : 'لا',
        'Gender': gender ? 'ذكر' : 'أنثى',
        'ShammasLevel': shammasLevel,
        'HasPhoto': hasPhoto ? 'نعم' : 'لا',
        'Color': color != null ? '0x' + color!.value.toRadixString(16) : null,
        'LastEdit': lastEdit != null
            ? MHDatabaseRepo.instance.users.getUserName(lastEdit!.uid)
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
            : Future.wait(
                services
                    .take(3)
                    .map((r) async => (await r.get()).data()?['Name'] ?? ''),
              ).then((d) => d.join(',')).catchError((_) => ''),
      };

  @override
  Json toJson() => {
        ...super.toJson()
          ..remove('MainPhone')
          ..remove('OtherPhones')
          ..remove('LastEdit'),
        'ClassId': classId,
        'Phone': phone,
        'FatherPhone': fatherPhone,
        'MotherPhone': motherPhone,
        'Phones': phones.map(MapEntry.new)
          ..removeWhere((k, v) => v.toString().isEmpty),
        'HasPhoto': hasPhoto,
        'LastMeeting': lastMeeting,
        'Last': last,
        'ExamScores': examScores,
        'LastEdit': lastEdit?.uid,
        'LastEditTime': lastEdit?.time,
        'Services': services,
      };

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
          'ا',
        )
        .replaceAll(
          RegExp(
            r'[ى]',
          ),
          'ي',
        );
  }

  @override
  Future<String?> getSecondLine() async {
    final String? key =
        GetIt.I<CacheRepository>().box('Settings').get('PersonSecondLine');

    if (key == null) return null;

    return formattedProps()[key];
  }

  static Map<String, PropertyMetadata> propsMetadata() => EqualityMap.from(
        EqualityBy((o) => o.split('.')[0]),
        {
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
          'BirthDay': PropertyMetadata<DateTime>(
            name: 'BirthDay',
            label: 'يوم الميلاد',
            defaultValue: DateTime.now(),
          ),
          'StudyYear': PropertyMetadata<JsonRef>(
            name: 'StudyYear',
            label: 'سنة الدراسة',
            defaultValue: null,
            query: GetIt.I<DatabaseRepository>()
                .collection('StudyYears')
                .orderBy('Grade'),
            collectionName: 'StudyYears',
          ),
          'ClassId': PropertyMetadata<JsonRef>(
            name: 'ClassId',
            label: 'داخل فصل',
            defaultValue: null,
            query: GetIt.I<DatabaseRepository>()
                .collection('Classes')
                .orderBy('Grade'),
            collectionName: 'Classes',
          ),
          'Services': PropertyMetadata<JsonRef>(
            name: 'Services',
            label: 'الخدمات المشارك بها',
            defaultValue: null,
            query: GetIt.I<DatabaseRepository>()
                .collection('Services')
                .orderBy(FieldPath.fromString('StudyYearRange.From')),
            collectionName: 'Services',
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
            query: GetIt.I<DatabaseRepository>()
                .collection('Schools')
                .orderBy('Name'),
            collectionName: 'Schools',
          ),
          'College': PropertyMetadata<JsonRef>(
            name: 'College',
            label: 'الكلية',
            defaultValue: null,
            query: GetIt.I<DatabaseRepository>()
                .collection('Colleges')
                .orderBy('Name'),
            collectionName: 'Colleges',
          ),
          'Church': PropertyMetadata<JsonRef>(
            name: 'Church',
            label: 'الكنيسة',
            defaultValue: null,
            query: GetIt.I<DatabaseRepository>()
                .collection('Churches')
                .orderBy('Name'),
            collectionName: 'Churches',
          ),
          'CFather': PropertyMetadata<JsonRef>(
            name: 'CFather',
            label: 'أب الاعتراف',
            defaultValue: null,
            query: GetIt.I<DatabaseRepository>()
                .collection('Fathers')
                .orderBy('Name'),
            collectionName: 'Fathers',
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
            defaultValue: null,
          ),
          'LastEdit': PropertyMetadata<JsonRef>(
            name: 'LastEdit',
            label: 'أخر تعديل',
            defaultValue: null,
            query: GetIt.I<DatabaseRepository>()
                .collection('Users')
                .orderBy('Name'),
            collectionName: 'Users',
          ),
          'LastEditTime': const PropertyMetadata<DateTime>(
            name: 'LastEditTime',
            label: 'وقت أخر تعديل',
            defaultValue: null,
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
        },
      );
}
