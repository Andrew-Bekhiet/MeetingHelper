import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:meetinghelper/models/data/user.dart';
import 'package:meetinghelper/utils/typedefs.dart';
import 'package:rxdart/rxdart.dart';

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

  static Stream<List<Service>> getAllForUser({
    String orderBy = 'Name',
    bool descending = false,
  }) {
    return User.instance.stream.switchMap((u) {
      if (u.superAccess) {
        return FirebaseFirestore.instance
            .collection('Services')
            .orderBy(orderBy, descending: descending)
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

  static Stream<List<Service>> getAllForUserForHistory({
    String orderBy = 'Name',
    bool descending = false,
  }) {
    return User.instance.stream.switchMap((u) {
      if (u.superAccess) {
        return FirebaseFirestore.instance
            .collection('Services')
            .where('ShowInHistory', isEqualTo: true)
            .orderBy(orderBy, descending: descending)
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
      {bool descending = false, String orderBy = 'Name'}) {
    return FirebaseFirestore.instance
        .collection('Persons')
        .where('Services', arrayContains: ref)
        .orderBy(orderBy, descending: descending)
        .snapshots()
        .map((p) => p.docs.map(Person.fromQueryDoc).toList());
  }

  Stream<List<User>> getUsersMembersLive(
      {bool descending = false, String orderBy = 'Name'}) {
    return FirebaseFirestore.instance
        .collection('UsersData')
        .where('Services', arrayContains: ref)
        .orderBy(orderBy, descending: descending)
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
