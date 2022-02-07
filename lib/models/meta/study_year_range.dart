import 'package:churchdata_core/churchdata_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart' show DocumentReference;
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:flutter/material.dart';

part 'study_year_range.g.dart';

@immutable
@CopyWith(copyWithNull: true)
class StudyYearRange {
  final JsonRef? from;
  final JsonRef? to;

  const StudyYearRange({required this.from, required this.to});

  Json toJson() => {'From': from, 'To': to};
}
