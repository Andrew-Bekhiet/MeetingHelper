import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:meetinghelper/models/data/user.dart';
import 'package:meetinghelper/utils/helpers.dart';
import 'package:meetinghelper/utils/typedefs.dart';
import 'package:rxdart/rxdart.dart';

import '../property_metadata.dart';
import '../super_classes.dart';
import 'person.dart';

class Service extends DataObject with PhotoObject {
  StudyYearRange? studyYearRange;
  DateTimeRange? validity;
  bool showInHistory;
  String lastEdit;

  Service({
    required JsonRef ref,
    required String name,
    required this.lastEdit,
    this.studyYearRange,
    this.validity,
    this.showInHistory = true,
    Color? color,
    bool hasPhoto = false,
  }) : super(ref, name, color) {
    this.hasPhoto = hasPhoto;
    defaultIcon = Icons.miscellaneous_services;
  }

  static Service empty() {
    return Service(
      ref: FirebaseFirestore.instance.collection('Services').doc('null'),
      name: '',
      hasPhoto: false,
      lastEdit: User.instance.uid!,
    );
  }

  static Service? fromDoc(JsonDoc doc) =>
      doc.data() != null ? Service.fromJson(doc.data()!, doc.reference) : null;

  static Service fromQueryDoc(JsonQueryDoc doc) =>
      Service.fromJson(doc.data(), doc.reference);

  static Stream<List<Service>> getAllForUser(
      {String orderBy = 'Name',
      bool descending = false,
      Query<Json> Function(Query<Json>, String, bool) queryCompleter =
          kDefaultQueryCompleter}) {
    return User.instance.stream.switchMap((u) {
      if (u.superAccess) {
        return queryCompleter(FirebaseFirestore.instance.collection('Services'),
                orderBy, descending)
            .snapshots()
            .map((c) => c.docs.map(fromQueryDoc).toList());
      } else {
        return u.adminServices.isEmpty
            ? Stream.value([])
            : Rx.combineLatestList(u.adminServices.map(
                (r) => r.snapshots().map(Service.fromDoc),
              )).map((s) => s.whereType<Service>().toList());
      }
    });
  }

  static Stream<List<Service>> getAllForUserForHistory(
      {String orderBy = 'Name',
      bool descending = false,
      Query<Json> Function(Query<Json>, String, bool) queryCompleter =
          kDefaultQueryCompleter}) {
    return User.instance.stream.switchMap((u) {
      if (u.superAccess) {
        return queryCompleter(
                FirebaseFirestore.instance
                    .collection('Services')
                    .where('ShowInHistory', isEqualTo: true),
                orderBy,
                descending)
            .snapshots()
            .map(
              (c) => c.docs
                  .map(fromQueryDoc)
                  .where(
                    (service) =>
                        service.validity == null ||
                        (DateTime.now().isAfter(service.validity!.start) &&
                            DateTime.now().isBefore(service.validity!.end)),
                  )
                  .toList(),
            );
      } else {
        return u.adminServices.isEmpty
            ? Stream.value([])
            : Rx.combineLatestList(
                u.adminServices.map(
                  (r) => r.snapshots().map(fromDoc).whereType<Service>().where(
                        (service) =>
                            service.validity == null ||
                            (DateTime.now().isAfter(service.validity!.start) &&
                                DateTime.now().isBefore(service.validity!.end)),
                      ),
                ),
              );
      }
    });
  }

  Service.fromJson(Json json, JsonRef ref)
      : this(
          ref: ref,
          name: json['Name'],
          studyYearRange: json['StudyYearRange'] != null
              ? StudyYearRange(
                  from: json['StudyYearRange']['From'],
                  to: json['StudyYearRange']['To'])
              : null,
          validity: json['Validity'] != null
              ? DateTimeRange(
                  start: json['Validity']['From'].toDate(),
                  end: json['Validity']['To'].toDate())
              : null,
          showInHistory: json['ShowInHistory'],
          color: json['Color'] != null ? Color(json['Color']) : null,
          lastEdit: json['LastEdit'],
          hasPhoto: json['HasPhoto'],
        );

  Stream<List<Person>> getPersonsMembersLive(
      {bool descending = false,
      String orderBy = 'Name',
      Query<Json> Function(Query<Json>, String, bool) queryCompleter =
          kDefaultQueryCompleter}) {
    return queryCompleter(
            FirebaseFirestore.instance
                .collection('Persons')
                .where('Services', arrayContains: ref),
            orderBy,
            descending)
        .snapshots()
        .map((p) => p.docs.map(Person.fromQueryDoc).toList());
  }

  Stream<List<User>> getUsersMembersLive(
      {bool descending = false,
      String orderBy = 'Name',
      Query<Json> Function(Query<Json>, String, bool) queryCompleter =
          kDefaultQueryCompleter}) {
    return queryCompleter(
            FirebaseFirestore.instance
                .collection('UsersData')
                .where('Services', arrayContains: ref),
            orderBy,
            descending)
        .snapshots()
        .map((p) => p.docs.map(User.fromDoc).toList());
  }

  @override
  Service copyWith({
    JsonRef? ref,
    String? name,
    StudyYearRange? studyYearRange,
    DateTimeRange? validity,
    bool? showInHistory,
    Color? color,
    String? lastEdit,
  }) {
    return Service(
      ref: ref ?? this.ref,
      name: name ?? this.name,
      studyYearRange: studyYearRange ?? this.studyYearRange,
      validity: validity ?? this.validity,
      showInHistory: showInHistory ?? this.showInHistory,
      color: color ?? this.color,
      lastEdit: lastEdit ?? this.lastEdit,
    );
  }

  @override
  Json formattedProps() => {
        'Name': name,
        'StudyYearRange': Future(
          () async {
            if (studyYearRange?.from == studyYearRange?.to)
              return (await studyYearRange!.from?.get())?.data()?['Name']
                      as String? ??
                  'غير موجودة';

            final from = (await studyYearRange!.from?.get())?.data()?['Name'] ??
                'غير موجودة';
            final to = (await studyYearRange!.to?.get())?.data()?['Name'] ??
                'غير موجودة';

            return 'من $from الى $to';
          },
        ),
        'Validity': () {
          final from = DateFormat('yyyy/M/d', 'ar-EG').format(
            validity!.start,
          );
          final to = DateFormat('yyyy/M/d', 'ar-EG').format(
            validity!.end,
          );

          return 'من $from الى $to';
        }(),
        'ShowInHistory': showInHistory ? 'نعم' : 'لا',
        'LastEdit': User.onlyName(lastEdit),
        'HasPhoto': hasPhoto ? 'نعم' : 'لا',
        'Color': '0x' + color.value.toRadixString(16),
      };

  @override
  FutureOr<String?> getSecondLine() async {
    final String? key = Hive.box('Settings').get('ServiceSecondLine');

    if (key == null) return null;

    return formattedProps()[key];
  }

  @override
  Json getMap() {
    return {
      'Name': name,
      'StudyYearRange': studyYearRange?.toJson(),
      'Validity': validity?.toJson(),
      'ShowInHistory': showInHistory,
      'LastEdit': lastEdit,
      'HasPhoto': hasPhoto,
      'Color': color.value,
    };
  }

  @override
  Reference get photoRef =>
      FirebaseStorage.instance.ref().child('ServicesPhotos/$id');

  static Map<String, PropertyMetadata> propsMetadata() => {
        'Name': const PropertyMetadata<String>(
          name: 'Name',
          label: 'الاسم',
          defaultValue: '',
        ),
        'StudyYearRange': const PropertyMetadata<StudyYearRange>(
          name: 'StudyYearRange',
          label: 'المرحلة الدراسية',
          defaultValue: null,
        ),
        'Color': const PropertyMetadata<Color>(
          name: 'Color',
          label: 'اللون',
          defaultValue: Colors.transparent,
        ),
        'Validity': const PropertyMetadata<DateTimeRange>(
          name: 'Validity',
          label: 'الصلاحية',
          defaultValue: null,
        ),
        'ShowInHistory': const PropertyMetadata<bool>(
          name: 'ShowInHistory',
          label: 'اظهار كبند في السجل',
          defaultValue: false,
        ),
        'LastEdit': PropertyMetadata<JsonRef>(
          name: 'LastEdit',
          label: 'أخر تعديل',
          defaultValue: null,
          collection:
              FirebaseFirestore.instance.collection('Users').orderBy('Name'),
        ),
        'HasPhoto': const PropertyMetadata<bool>(
          name: 'HasPhoto',
          label: 'لديه صورة',
          defaultValue: false,
        ),
      };
}

class StudyYearRange {
  JsonRef? from;
  JsonRef? to;

  StudyYearRange({required this.from, required this.to});

  Json toJson() => {'From': from, 'To': to};
}

extension DateTimeRangeX on DateTimeRange {
  Json toJson() {
    return {
      'From': Timestamp.fromDate(start),
      'To': Timestamp.fromDate(end),
    };
  }
}
