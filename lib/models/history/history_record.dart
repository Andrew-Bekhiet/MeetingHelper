import 'dart:async';

import 'package:churchdata_core/churchdata_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart' show DocumentReference;
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:intl/intl.dart';
import 'package:meetinghelper/models.dart';
import 'package:meetinghelper/repositories.dart';
import 'package:rxdart/rxdart.dart';
import 'package:tuple/tuple.dart';

part 'history_record.g.dart';

abstract class HistoryDayBase extends DataObjectWithPhoto {
  final Timestamp day;
  final String? notes;

  HistoryDayBase({required JsonRef ref})
      : day = DateTime.now().truncateToUTCDay().toTimestamp(),
        notes = '',
        super(ref, '');

  HistoryDayBase._createFromData(super.data, super.ref)
      : day = data['Day'],
        notes = data['Notes'],
        super.fromJson();

  @override
  String get name =>
      DateFormat('EEEE\t\tyyyy/M/d', 'ar-EG').format(day.toDate());

  @override
  int get hashCode => Object.hash(id, day, notes);

  @override
  bool get hasPhoto => false;

  @override
  IconData get defaultIcon => Icons.event;

  @override
  Reference? get photoRef => null;

  JsonCollectionRef? subcollection(String? name) =>
      name != null ? ref.collection(name) : null;

  @override
  bool operator ==(Object other) =>
      other is HistoryDayBase && other.hashCode == hashCode;

  @override
  Json toJson() => {'Day': day, 'Notes': notes};

  @override
  Future<String> getSecondLine() {
    return SynchronousFuture(
      DateTime(day.toDate().year, day.toDate().month, day.toDate().day) !=
              DateTime(
                DateTime.now().year,
                DateTime.now().month,
                DateTime.now().day,
              )
          ? day.toDate().toDurationString()
          : 'اليوم',
    );
  }

  HistoryDayBase copyWith();
}

class HistoryDay extends HistoryDayBase {
  HistoryDay()
      : super(
          ref: GetIt.I<DatabaseRepository>()
              .collection('History')
              .doc(DateTime.now().toIso8601String().split('T')[0]),
        );

  HistoryDay._createFromData(super.data, super.ref) : super._createFromData();

  static HistoryDay? fromDoc(JsonDoc data) => data.exists
      ? HistoryDay._createFromData(data.data()!, data.reference)
      : null;

  factory HistoryDay.fromQueryDoc(JsonQueryDoc data) =>
      HistoryDay._createFromData(data.data(), data.reference);

  static Future<HistoryDay?> fromId(String id) async => HistoryDay.fromDoc(
        await GetIt.I<DatabaseRepository>().doc('History/$id').get(),
      );

  static Future<Stream<JsonQuery>> getAllForUser({
    String orderBy = 'Day',
    bool descending = false,
  }) async {
    return GetIt.I<DatabaseRepository>()
        .collection('History')
        .orderBy(orderBy, descending: descending)
        .snapshots();
  }

  @override
  HistoryDay copyWith() {
    return HistoryDay._createFromData(toJson(), ref);
  }
}

class ServantsHistoryDay extends HistoryDayBase {
  ServantsHistoryDay()
      : super(
          ref: GetIt.I<DatabaseRepository>()
              .collection('ServantsHistory')
              .doc(DateTime.now().toIso8601String().split('T')[0]),
        );

  static ServantsHistoryDay? fromDoc(JsonDoc data) => data.exists
      ? ServantsHistoryDay._createFromData(data.data()!, data.reference)
      : null;

  factory ServantsHistoryDay.fromQueryDoc(JsonQueryDoc data) =>
      ServantsHistoryDay._createFromData(data.data(), data.reference);

  ServantsHistoryDay._createFromData(super.data, super.ref)
      : super._createFromData();

  static Future<ServantsHistoryDay?> fromId(String id) async =>
      ServantsHistoryDay.fromDoc(
        await GetIt.I<DatabaseRepository>().doc('ServantsHistory/$id').get(),
      );

  static Future<Stream<JsonQuery>> getAllForUser({
    String orderBy = 'Day',
    bool descending = false,
  }) async {
    return GetIt.I<DatabaseRepository>()
        .collection('ServantsHistory')
        .orderBy(orderBy, descending: descending)
        .snapshots();
  }

  @override
  ServantsHistoryDay copyWith() {
    return ServantsHistoryDay._createFromData(toJson(), ref);
  }
}

@immutable
@CopyWith(copyWithNull: true)
class HistoryRecord {
  final String? type;

  final HistoryDayBase? parent;
  final String id;
  final Timestamp time;
  final String? recordedBy;
  final String? notes;
  final List<JsonRef> services;
  final JsonRef? studyYear;
  final JsonRef? classId;
  final bool isServant;

  HistoryRecord({
    required this.id,
    required this.type,
    required this.classId,
    required this.time,
    required this.recordedBy,
    this.parent,
    List<JsonRef>? services,
    this.studyYear,
    this.notes,
    this.isServant = false,
  }) : services = services ?? [];

  static HistoryRecord? fromDoc(HistoryDayBase? parent, JsonDoc doc) =>
      doc.exists ? HistoryRecord._fromDoc(parent, doc) : null;

  HistoryRecord._fromDoc(this.parent, JsonDoc doc)
      : id = doc.id,
        classId = doc.data()!['ClassId'],
        services = (doc.data()!['Services'] as List?)?.cast() ?? [],
        studyYear = doc.data()!['StudyYear'],
        type = doc.reference.parent.id,
        isServant = doc.data()!['IsServant'] ?? false,
        time = doc.data()!['Time'],
        recordedBy = doc.data()!['RecordedBy'],
        notes = doc.data()!['Notes'];

  static HistoryRecord fromQueryDoc(
    JsonQueryDoc doc, [
    HistoryDayBase? parent,
  ]) {
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
      'Services': services,
      'StudyYear': studyYear,
      'IsServant': isServant,
    };
  }

  @override
  int get hashCode => Object.hash(id, time, recordedBy, notes);

  @override
  bool operator ==(Object other) =>
      (other is HistoryRecord && other.hashCode == hashCode) ||
      (other is DataObject && other.id == id);
}

/// Used in EditHistory, CallHistory, etc...
class MinimalHistoryRecord {
  MinimalHistoryRecord({
    required this.ref,
    required this.time,
    required this.by,
    this.classId,
    this.personId,
    this.services,
  });

  static MinimalHistoryRecord? fromDoc(JsonDoc doc) {
    if (!doc.exists) return null;
    return MinimalHistoryRecord(
      ref: doc.reference,
      classId: doc.data()!['ClassId'],
      personId: doc.data()!['PersonId'],
      services: (doc.data()!['Services'] as List?)?.cast(),
      time: doc.data()!['Time'],
      by: doc.data()!['By'],
    );
  }

  factory MinimalHistoryRecord.fromQueryDoc(JsonQueryDoc doc) {
    return MinimalHistoryRecord(
      ref: doc.reference,
      classId: doc.data()['ClassId'],
      personId: doc.data()['PersonId'],
      services: (doc.data()['Services'] as List?)?.cast(),
      time: doc.data()['Time'],
      by: doc.data()['By'],
    );
  }

  static Stream<List<JsonQueryDoc>> getAllForUser({
    required String collectionGroup,
    DateTimeRange? range,
    List<Class>? classes,
    List<Service>? services,
  }) {
    QueryOfJson _timeRangeFilter(QueryOfJson q, DateTimeRange range) {
      return q
          .where(
            'Time',
            isLessThanOrEqualTo:
                Timestamp.fromDate(range.end.add(const Duration(days: 1))),
          )
          .where(
            'Time',
            isGreaterThanOrEqualTo: Timestamp.fromDate(
              range.start.subtract(const Duration(days: 1)),
            ),
          );
    }

    QueryOfJson _timeOrder(QueryOfJson q) {
      return q.orderBy('Time', descending: true);
    }

    QueryOfJson _classesFilter(QueryOfJson q, List<Class> classes) {
      assert(classes.length <= 30);
      return q.where('ClassId', whereIn: classes.map((c) => c.ref).toList());
    }

    QueryOfJson _servicesFilter(QueryOfJson q, List<Service> services) {
      assert(services.length <= 30);
      return q.where(
        'Services',
        arrayContainsAny: services.map((c) => c.ref).toList(),
      );
    }

    return Rx.combineLatest3<User?, List<Class>, List<Service>,
        Tuple3<User?, List<Class>, List<Service>>>(
      User.loggedInStream,
      classes == null ? MHDatabaseRepo.I.classes.getAll() : Stream.value([]),
      services == null ? MHDatabaseRepo.I.services.getAll() : Stream.value([]),
      Tuple3.new,
    ).switchMap((value) {
      if (range != null && classes != null && services != null) {
        return Rx.combineLatestList<JsonQuery>([
          ...classes.split(30).map(
                (a) => _timeOrder(
                  _timeRangeFilter(
                    _classesFilter(
                      GetIt.I<DatabaseRepository>()
                          .collectionGroup(collectionGroup),
                      a,
                    ),
                    range,
                  ),
                ).snapshots(),
              ),
          ...services.split(30).map(
                (a) => _timeOrder(
                  _timeRangeFilter(
                    _servicesFilter(
                      GetIt.I<DatabaseRepository>()
                          .collectionGroup(collectionGroup),
                      a,
                    ),
                    range,
                  ),
                ).snapshots(),
              ),
        ]).map((s) => s.expand((n) => n.docs).toList());
      } else if (range != null && classes != null) {
        return Rx.combineLatestList<JsonQuery>(
          classes
              .split(30)
              .map(
                (a) => _timeOrder(
                  _timeRangeFilter(
                    _classesFilter(
                      GetIt.I<DatabaseRepository>()
                          .collectionGroup(collectionGroup),
                      a,
                    ),
                    range,
                  ),
                ).snapshots(),
              )
              .toList(),
        ).map((s) => s.expand((n) => n.docs).toList());
      } else if (range != null && services != null) {
        return Rx.combineLatestList<JsonQuery>(
          services
              .split(30)
              .map(
                (a) => _timeOrder(
                  _timeRangeFilter(
                    _servicesFilter(
                      GetIt.I<DatabaseRepository>()
                          .collectionGroup(collectionGroup),
                      a,
                    ),
                    range,
                  ),
                ).snapshots(),
              )
              .toList(),
        ).map((s) => s.expand((n) => n.docs).toList());
      } else if (range != null) {
        if (value.item1 == null) return Stream.value([]);
        if (value.item1!.permissions.superAccess) {
          return _timeOrder(
            _timeRangeFilter(
              GetIt.I<DatabaseRepository>().collectionGroup(collectionGroup),
              range,
            ),
          ).snapshots().map((s) => s.docs);
        } else {
          return Rx.combineLatestList<JsonQuery>([
            ...value.item2.split(30).map(
                  (a) => _timeOrder(
                    _timeRangeFilter(
                      _classesFilter(
                        GetIt.I<DatabaseRepository>()
                            .collectionGroup(collectionGroup),
                        a,
                      ),
                      range,
                    ),
                  ).snapshots(),
                ),
            ...value.item3.split(30).map(
                  (a) => _timeOrder(
                    _timeRangeFilter(
                      _servicesFilter(
                        GetIt.I<DatabaseRepository>()
                            .collectionGroup(collectionGroup),
                        a,
                      ),
                      range,
                    ),
                  ).snapshots(),
                ),
          ]).map((s) => s.expand((n) => n.docs).toList());
        }
      } else if (classes != null) {
        return Rx.combineLatestList<JsonQuery>(
          classes
              .split(30)
              .map(
                (a) => _timeOrder(
                  _classesFilter(
                    GetIt.I<DatabaseRepository>()
                        .collectionGroup(collectionGroup),
                    a,
                  ),
                ).snapshots(),
              )
              .toList(),
        ).map((s) => s.expand((n) => n.docs).toList());
      } else if (services != null) {
        return Rx.combineLatestList<JsonQuery>(
          services
              .split(30)
              .map(
                (a) => _timeOrder(
                  _servicesFilter(
                    GetIt.I<DatabaseRepository>()
                        .collectionGroup(collectionGroup),
                    a,
                  ),
                ).snapshots(),
              )
              .toList(),
        ).map((s) => s.expand((n) => n.docs).toList());
      }
      return _timeOrder(
        GetIt.I<DatabaseRepository>().collectionGroup(collectionGroup),
      ).snapshots().map((s) => s.docs.toList());
    });
  }

  String get id => ref.id;

  Timestamp time;
  String? by;

  JsonRef? classId;
  JsonRef? personId;
  List<JsonRef>? services;
  JsonRef ref;

  Json getMap() {
    return {
      'ID': id,
      'Time': time,
      'RecordedBy': by,
      'ClassId': classId,
      'Services': services,
      'PersonId': personId,
    };
  }

  @override
  int get hashCode => Object.hash(id, time, by, classId, personId, services);

  @override
  bool operator ==(Object other) =>
      (other is MinimalHistoryRecord && other.hashCode == hashCode) ||
      (other is DataObject && other.id == id);
}
