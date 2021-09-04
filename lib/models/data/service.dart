import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:meetinghelper/utils/typedefs.dart';

import '../super_classes.dart';

class Service extends DataObject with PhotoObject {
  StudyYearRange? studyYearRange;
  DateTimeRange? validity;
  bool showInHistory;

  Service({
    required JsonRef ref,
    required String name,
    this.studyYearRange,
    this.validity,
    this.showInHistory = true,
    bool hasPhoto = false,
  }) : super(ref, name, null) {
    hasPhoto = hasPhoto;
    defaultIcon = Icons.miscellaneous_services;
  }

  static Service fromDoc(JsonDoc doc) =>
      Service.fromJson(doc.data()!, doc.reference);

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
          hasPhoto: json['HasPhoto'],
        );

  @override
  Service copyWith(
      {JsonRef? ref,
      String? name,
      StudyYearRange? studyYearRange,
      DateTimeRange? validity,
      bool? showInHistory}) {
    return Service(
      ref: ref ?? this.ref,
      name: name ?? this.name,
      studyYearRange: studyYearRange ?? this.studyYearRange,
      validity: validity ?? this.validity,
      showInHistory: showInHistory ?? this.showInHistory,
    );
  }

  @override
  Json getMap() {
    return {
      'Name': name,
      'StudyYearRange': studyYearRange?.toJson(),
      'Validity': validity?.toJson(),
      'ShowInHistory': showInHistory,
      'HasPhoto': hasPhoto,
    };
  }

  @override
  Reference get photoRef =>
      FirebaseStorage.instance.ref().child('ServicesPhotos/$id');
}

class StudyYearRange {
  JsonRef from;
  JsonRef to;

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
