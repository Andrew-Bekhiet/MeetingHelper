import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:meetinghelper/utils/typedefs.dart';

import '../super_classes.dart';

class Service extends DataObject {
  StudyYearRange? studyYearRange;
  DateTimeRange? validity;
  bool showInHistory;

  Service(
      {required JsonRef ref,
      required String name,
      this.studyYearRange,
      this.validity,
      this.showInHistory = true})
      : super(ref, name, null);

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
    };
  }
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
