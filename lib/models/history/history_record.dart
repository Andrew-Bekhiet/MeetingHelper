import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:meetinghelper/models/data/class.dart';
import 'package:meetinghelper/models/data/user.dart';
import 'package:meetinghelper/models/super_classes.dart';
import 'package:meetinghelper/utils/helpers.dart';
import 'package:meetinghelper/utils/typedefs.dart';
import 'package:rxdart/rxdart.dart';
import 'package:tuple/tuple.dart';

class HistoryDay extends DataObject with ChangeNotifier {
  Timestamp day;
  String? notes;

  late StreamSubscription<JsonDoc> _realTimeListener;
  HistoryDay()
      : day = tranucateToDay(),
        notes = '',
        super(
            FirebaseFirestore.instance
                .collection('History')
                .doc(DateTime.now().toIso8601String().split('T')[0]),
            '',
            null) {
    _initListener();
  }

  HistoryDay._createFromData(Json data, JsonRef ref)
      : day = data['Day'],
        notes = data['Notes'],
        super.createFromData(data, ref) {
    _initListener();
  }

  @override
  String get name => DateFormat('d / M   yyyy', 'ar-EG').format(day.toDate());

  @override
  int get hashCode => hashValues(id, day, notes);

  JsonCollectionRef? subcollection(String? name) =>
      name != null ? ref.collection(name) : null;

  @override
  bool operator ==(dynamic other) =>
      other is HistoryDay && other.hashCode == hashCode;

  @override
  void dispose() {
    _realTimeListener.cancel();
    super.dispose();
  }

  @override
  Json getMap() => {'Day': day, 'Notes': notes};

  void _initListener() {
    _realTimeListener = ref.snapshots().listen((event) {
      if (!event.exists || event.data() == null) return;
      notes = event.data()?['Notes'];
      notifyListeners();
    });
  }

  static HistoryDay? fromDoc(JsonDoc data) => data.exists
      ? HistoryDay._createFromData(data.data()!, data.reference)
      : null;

  static HistoryDay fromQueryDoc(JsonQueryDoc data) =>
      HistoryDay._createFromData(data.data(), data.reference);

  static Future<HistoryDay?> fromId(String id) async => HistoryDay.fromDoc(
      await FirebaseFirestore.instance.doc('History/$id').get());

  static Future<Stream<JsonQuery>> getAllForUser(
      {String orderBy = 'Day', bool descending = false}) async {
    return FirebaseFirestore.instance
        .collection('History')
        .orderBy(orderBy, descending: descending)
        .snapshots();
  }

  @override
  Json getHumanReadableMap() {
    throw UnimplementedError();
  }

  @override
  Future<String> getSecondLine() {
    return SynchronousFuture(DateTime(
                day.toDate().year, day.toDate().month, day.toDate().day) !=
            DateTime(
                DateTime.now().year, DateTime.now().month, DateTime.now().day)
        ? toDurationString(day)
        : 'اليوم');
  }

  @override
  HistoryDay copyWith() {
    return HistoryDay._createFromData(getMap(), ref);
  }
}

class ServantsHistoryDay extends HistoryDay {
  ServantsHistoryDay() {
    ref = FirebaseFirestore.instance
        .collection('ServantsHistory')
        .doc(DateTime.now().toIso8601String().split('T')[0]);
    day = tranucateToDay();
    notes = '';
    _initListener();
  }

  static ServantsHistoryDay? fromDoc(JsonDoc data) => data.exists
      ? ServantsHistoryDay._createFromData(data.data()!, data.reference)
      : null;

  static ServantsHistoryDay fromQueryDoc(JsonQueryDoc data) =>
      ServantsHistoryDay._createFromData(data.data(), data.reference);

  ServantsHistoryDay._createFromData(Json data, JsonRef ref)
      : super._createFromData(data, ref);

  static Future<Stream<JsonQuery>> getAllForUser(
      {String orderBy = 'Day', bool descending = false}) async {
    return FirebaseFirestore.instance
        .collection('ServantsHistory')
        .orderBy(orderBy, descending: descending)
        .snapshots();
  }
}

class HistoryRecord {
  final String? type;

  HistoryDay? parent;
  String id;
  Timestamp time;
  String? recordedBy;
  String? notes;
  String? serviceId;
  JsonRef? classId;
  bool isServant;

  HistoryRecord(
      {required this.type,
      this.parent,
      required this.id,
      required this.classId,
      required this.time,
      required String recordedBy,
      this.serviceId,
      this.notes,
      this.isServant = false})
      // ignore: prefer_initializing_formals
      : recordedBy = recordedBy;

  static HistoryRecord? fromDoc(HistoryDay? parent, JsonDoc doc) =>
      doc.exists ? HistoryRecord._fromDoc(parent, doc) : null;

  HistoryRecord._fromDoc(this.parent, JsonDoc doc)
      : id = doc.id,
        classId = doc.data()!['ClassId'],
        serviceId = doc.data()!['ServiceId'],
        type = doc.reference.parent.id,
        isServant = doc.data()!['IsServant'] ?? false,
        time = doc.data()!['Time'],
        recordedBy = doc.data()!['RecordedBy'],
        notes = doc.data()!['Notes'];

  static HistoryRecord fromQueryDoc(JsonQueryDoc doc, [HistoryDay? parent]) {
    return HistoryRecord.fromDoc(parent, doc)!;
  }

  JsonRef? get ref =>
      type != null ? parent?.subcollection(type)?.doc(id) : null;

  Future<void> set() async {
    return await ref?.set(getMap());
  }

  Future<void> update() async {
    return await ref?.update(getMap());
  }

  Json getMap() {
    return {
      'ID': id,
      'Time': time,
      'RecordedBy': recordedBy,
      'Notes': notes,
      'ClassId': classId,
      'ServiceId': serviceId,
      'IsServant': isServant,
    };
  }

  @override
  int get hashCode => hashValues(id, time, recordedBy, notes);

  @override
  bool operator ==(Object other) =>
      (other is HistoryRecord && other.hashCode == hashCode) ||
      (other is DataObject && other.id == id);
}

/// Used in EditHistory, CallHistory, etc...
class MinimalHistoryRecord {
  MinimalHistoryRecord(
      {required this.ref,
      this.classId,
      this.personId,
      required this.time,
      required this.by});

  static MinimalHistoryRecord? fromDoc(JsonDoc doc) {
    if (!doc.exists) return null;
    return MinimalHistoryRecord(
      ref: doc.reference,
      classId: doc.data()!['ClassId'],
      personId: doc.data()!['PersonId'],
      time: doc.data()!['Time'],
      by: doc.data()!['By'],
    );
  }

  static MinimalHistoryRecord fromQueryDoc(JsonQueryDoc doc) {
    return MinimalHistoryRecord(
      ref: doc.reference,
      classId: doc.data()['ClassId'],
      personId: doc.data()['PersonId'],
      time: doc.data()['Time'],
      by: doc.data()['By'],
    );
  }

  static Stream<List<JsonQueryDoc>> getAllForUser(
      {required String collectionGroup,
      DateTimeRange? range,
      List<Class>? classes}) {
    return Rx.combineLatest2<User, List<Class>, Tuple2<User, List<Class>>>(
        User.instance.stream,
        Class.getAllForUser(),
        (a, b) => Tuple2<User, List<Class>>(a, b)).switchMap((value) {
      if (range != null && classes != null) {
        return Rx.combineLatestList<JsonQuery>(classes
                .map((a) => FirebaseFirestore.instance
                    .collectionGroup(collectionGroup)
                    .where('ClassId', isEqualTo: a.ref)
                    .where(
                      'Time',
                      isLessThanOrEqualTo: Timestamp.fromDate(
                          range.end.add(const Duration(days: 1))),
                    )
                    .where('Time',
                        isGreaterThanOrEqualTo: Timestamp.fromDate(
                            range.start.subtract(const Duration(days: 1))))
                    .orderBy('Time', descending: true)
                    .snapshots())
                .toList())
            .map((s) => s.expand((n) => n.docs).toList());
      } else if (range != null) {
        if (value.item1.superAccess) {
          return FirebaseFirestore.instance
              .collectionGroup(collectionGroup)
              .where(
                'Time',
                isLessThanOrEqualTo:
                    Timestamp.fromDate(range.end.add(const Duration(days: 1))),
              )
              .where('Time',
                  isGreaterThanOrEqualTo: Timestamp.fromDate(
                      range.start.subtract(const Duration(days: 1))))
              .orderBy('Time', descending: true)
              .snapshots()
              .map((s) => s.docs);
        } else {
          return Rx.combineLatestList<JsonQuery>(value.item2
                  .split(10)
                  .map((a) => FirebaseFirestore.instance
                      .collectionGroup(collectionGroup)
                      .where('ClassId', whereIn: a.map((c) => c.ref).toList())
                      .where(
                        'Time',
                        isLessThanOrEqualTo: Timestamp.fromDate(
                            range.end.add(const Duration(days: 1))),
                      )
                      .where('Time',
                          isGreaterThanOrEqualTo: Timestamp.fromDate(
                              range.start.subtract(const Duration(days: 1))))
                      .orderBy('Time', descending: true)
                      .snapshots())
                  .toList())
              .map((s) => s.expand((n) => n.docs).toList());
        }
      } else if (classes != null) {
        return Rx.combineLatestList<JsonQuery>(classes
                .split(10)
                .map((a) => FirebaseFirestore.instance
                    .collectionGroup(collectionGroup)
                    .where('ClassId', whereIn: a.map((c) => c.ref).toList())
                    .orderBy('Time', descending: true)
                    .snapshots())
                .toList())
            .map((s) => s.expand((n) => n.docs).toList());
      }
      return FirebaseFirestore.instance
          .collectionGroup(collectionGroup)
          .orderBy('Time', descending: true)
          .snapshots()
          .map((s) => s.docs.toList());
    });
  }

  String get id => ref.id;

  Timestamp time;
  String by;

  JsonRef? classId;
  JsonRef? personId;
  JsonRef ref;

  Json getMap() {
    return {
      'ID': id,
      'Time': time,
      'RecordedBy': by,
      'ClassId': classId,
      'PersonId': personId
    };
  }

  @override
  int get hashCode => hashValues(id, time, by, classId, personId);

  @override
  bool operator ==(Object other) =>
      (other is MinimalHistoryRecord && other.hashCode == hashCode) ||
      (other is DataObject && other.id == id);
}
