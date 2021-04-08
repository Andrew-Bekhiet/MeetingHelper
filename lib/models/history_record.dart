import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:meetinghelper/models/super_classes.dart';
import 'package:meetinghelper/utils/globals.dart';
import 'package:meetinghelper/utils/helpers.dart';

class HistoryDay extends DataObject with ChangeNotifier {
  Timestamp day;
  String notes;

  StreamSubscription<DocumentSnapshot> _realTimeListener;
  HistoryDay()
      : day = tranucateToDay(),
        notes = '',
        super(FirebaseFirestore.instance.collection('History').doc(), null,
            null) {
    color = Colors.transparent;
    _initListener();
  }

  HistoryDay._createFromData(Map<String, dynamic> data, DocumentReference ref)
      : day = data['Day'],
        notes = data['Notes'],
        super.createFromData(data, ref) {
    color = Colors.transparent;
    _initListener();
  }

  @override
  String get name => DateFormat('d / M   yyyy', 'ar-EG').format(day.toDate());

  @override
  int get hashCode => hashValues(id, day, notes);

  CollectionReference get kodas => ref.collection('Kodas');
  CollectionReference get meeting => ref.collection('Meeting');
  CollectionReference get tanawol => ref.collection('Tanawol');

  Map<DayListType, CollectionReference> get collections => {
        DayListType.Meeting: meeting,
        DayListType.Kodas: kodas,
        DayListType.Tanawol: tanawol
      };

  @override
  bool operator ==(Object other) =>
      (other is HistoryDay && other.hashCode == hashCode);

  @override
  void dispose() {
    _realTimeListener.cancel();
    super.dispose();
  }

  @override
  Map<String, dynamic> getMap() => {'Day': day, 'Notes': notes};

  void _initListener() {
    _realTimeListener = ref.snapshots().listen((event) {
      if (!event.exists || event.data() == null) return;
      notes = event.data()['Notes'];
      notifyListeners();
    });
  }

  static HistoryDay fromDoc(DocumentSnapshot data) =>
      HistoryDay._createFromData(data.data(), data.reference);

  static Future<HistoryDay> fromId(String id) async => HistoryDay.fromDoc(
      await FirebaseFirestore.instance.doc('History/$id').get());

  static Future<Stream<QuerySnapshot>> getAllForUser(
      {String orderBy = 'Day', bool descending = false}) async {
    return FirebaseFirestore.instance
        .collection('History')
        .orderBy(orderBy, descending: descending)
        .snapshots();
  }

  @override
  Map<String, dynamic> getHumanReadableMap() {
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
}

class ServantsHistoryDay extends HistoryDay {
  ServantsHistoryDay() {
    ref = FirebaseFirestore.instance.collection('ServantsHistory').doc();
    day = tranucateToDay();
    notes = '';
    _initListener();
  }

  static ServantsHistoryDay fromDoc(DocumentSnapshot data) =>
      ServantsHistoryDay._createFromData(data.data(), data.reference);

  ServantsHistoryDay._createFromData(
      Map<String, dynamic> data, DocumentReference ref)
      : super._createFromData(data, ref);

  static Future<Stream<QuerySnapshot>> getAllForUser(
      {String orderBy = 'Day', bool descending = false}) async {
    return FirebaseFirestore.instance
        .collection('ServantsHistory')
        .orderBy(orderBy, descending: descending)
        .snapshots();
  }
}

class HistoryRecord {
  HistoryRecord(
      {this.type,
      this.parent,
      this.id,
      this.classId,
      this.time,
      this.recordedBy,
      this.notes});

  HistoryRecord.fromDoc(this.parent, DocumentSnapshot doc)
      : id = doc.id,
        classId = doc.data()['ClassId'],
        type = doc.reference.parent.id == 'Meeting'
            ? DayListType.Meeting
            : (doc.reference.parent.id == 'Kodas'
                ? DayListType.Kodas
                : DayListType.Tanawol),
        time = doc.data()['Time'],
        recordedBy = doc.data()['RecordedBy'],
        notes = doc.data()['Notes'];

  final DayListType type;

  HistoryDay parent;
  String id;
  Timestamp time;
  String recordedBy;
  String notes;
  DocumentReference classId;

  DocumentReference get ref => parent.collections[type].doc(id);

  Future<void> set() async {
    return await ref.set(getMap());
  }

  Future<void> update() async {
    return await ref.update(getMap());
  }

  Map<String, dynamic> getMap() {
    return {
      'ID': id,
      'Time': time,
      'RecordedBy': recordedBy,
      'Notes': notes,
      'ClassId': classId
    };
  }

  @override
  int get hashCode => hashValues(id, time, recordedBy, notes);

  @override
  bool operator ==(Object other) =>
      (other is HistoryRecord && other.hashCode == hashCode) ||
      (other is DataObject && other.id == id);
}
