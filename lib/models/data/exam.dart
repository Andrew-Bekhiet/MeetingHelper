import 'package:churchdata_core/churchdata_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart' show DocumentReference;
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

part 'exam.g.dart';

@immutable
@CopyWith(copyWithNull: true)
class Exam extends DataObject {
  final DateTime? time;
  final int max;
  final JsonRef service;

  const Exam({
    required JsonRef ref,
    required String name,
    required this.max,
    required this.service,
    this.time,
  }) : super(ref, name);

  factory Exam.empty() {
    return Exam(
      ref: GetIt.I<DatabaseRepository>().collection('Exams').doc('null'),
      name: '',
      max: 100,
      service: GetIt.I<DatabaseRepository>().collection('Services').doc('null'),
      time: DateTime.now(),
    );
  }

  static Exam? fromDoc(JsonDoc doc) =>
      doc.data() != null ? Exam.fromJson(doc.data()!, doc.reference) : null;

  factory Exam.fromQueryDoc(JsonQueryDoc doc) =>
      Exam.fromJson(doc.data(), doc.reference);

  Exam.fromJson(Json json, JsonRef ref)
      : this(
          ref: ref,
          name: json['Name'],
          time: (json['Time'] as Timestamp?)?.toDate(),
          service: json['Service'],
          max: json['Max'],
        );

  @override
  Json toJson() {
    return {
      'Name': name,
      'Time': time != null ? Timestamp.fromDate(time!) : null,
      'Service': service,
      'Max': max,
    };
  }
}
