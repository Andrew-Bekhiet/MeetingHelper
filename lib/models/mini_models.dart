import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:meetinghelper/utils/typedefs.dart';

import 'super_classes.dart';

abstract class MiniModel extends DataObject {
  final String collectionName;
  MiniModel(this.collectionName, String id, [String name = '', Color? color])
      : super(FirebaseFirestore.instance.collection(collectionName).doc(id),
            name, color);

  MiniModel.createFromData(this.collectionName, Json data, String id)
      : super.createFromData(data,
            FirebaseFirestore.instance.collection(collectionName).doc(id));

  MiniModel.createNew(this.collectionName)
      : super(FirebaseFirestore.instance.collection(collectionName).doc(), '',
            null);

  @override
  Json formattedProps() {
    return {};
  }

  @override
  Future<String?> getSecondLine() async {
    return null;
  }

  @override
  MiniModel copyWith() {
    throw UnimplementedError();
  }
}

class Church extends MiniModel with ParentObject<Father> {
  String? address;
  Church(String id, String name, {this.address}) : super(id, name);
  Church._createFromData(Json data, String id)
      : super.createFromData('Churches', data, id) {
    address = data['Address'];
  }

  Church.createNew() : super.createNew('Churches') {
    address = '';
  }

  @override
  Json getMap() {
    return {'Name': name, 'Address': address};
  }

  Stream<JsonQuery> getMembersLive() {
    return FirebaseFirestore.instance
        .collection('Fathers')
        .where('ChurchId', isEqualTo: ref)
        .snapshots();
  }

  static Church? fromDoc(JsonDoc data) =>
      data.exists ? Church._createFromData(data.data()!, data.id) : null;

  static Church fromQueryDoc(JsonQueryDoc data) =>
      Church._createFromData(data.data(), data.id);

  static Future<JsonQuery> getAllForUser() {
    return FirebaseFirestore.instance
        .collection('Churches')
        .orderBy('Name')
        .get();
  }

  @override
  Future<List<Father>> getChildren(
      [String orderBy = 'Name', bool tranucate = false]) async {
    return (await FirebaseFirestore.instance
            .collection('Fathers')
            .where('ChurchId', isEqualTo: ref)
            .get())
        .docs
        .map(Father.fromQueryDoc)
        .toList();
  }
}

class PersonState extends MiniModel {
  PersonState(String id, String name, Color color)
      : super('States', id, name, color);
  PersonState._createFromData(Json data, String id)
      : super.createFromData('States', data, id) {
    color = Color(int.parse('0xFF' + data['Color']));
  }

  PersonState.createNew() : super.createNew('States');

  @override
  Json getMap() {
    return {'Name': name, 'Color': color};
  }

  static PersonState? fromDoc(JsonDoc data) =>
      data.exists ? PersonState._createFromData(data.data()!, data.id) : null;

  static PersonState fromQueryDoc(JsonQueryDoc data) =>
      PersonState._createFromData(data.data(), data.id);

  static Future<JsonQuery> getAllForUser() {
    return FirebaseFirestore.instance
        .collection('States')
        .orderBy('Name')
        .get();
  }
}

class College extends MiniModel {
  College(String id, String name) : super('Colleges', id, name);
  College._createFromData(Json data, id)
      : super.createFromData('Colleges', data, id);

  College.createNew() : super.createNew('Colleges');

  @override
  Json getMap() {
    return {'Name': name};
  }

  static College fromDoc(JsonQueryDoc data) =>
      College._createFromData(data.data(), data.id);

  static Future<JsonQuery> getAllForUser() {
    return FirebaseFirestore.instance
        .collection('Colleges')
        .orderBy('Name')
        .get();
  }
}

class Father extends MiniModel with ChildObject<Church> {
  JsonRef? churchId;
  Father(String id, String name, this.churchId) : super('Fathers', id, name);
  Father._createFromData(Json data, String id)
      : super.createFromData('Fathers', data, id) {
    churchId = data['ChurchId'];
  }

  Father.createNew() : super.createNew('Fathers');

  Future<String?> getChurchName() async {
    if (churchId == null) return null;
    return Church.fromDoc(
      await churchId!.get(),
    )?.name;
  }

  @override
  Json getMap() {
    return {'Name': name, 'ChurchId': churchId};
  }

  static Father? fromDoc(JsonDoc data) =>
      data.exists ? Father._createFromData(data.data()!, data.id) : null;

  static Father fromQueryDoc(JsonQueryDoc data) =>
      Father._createFromData(data.data(), data.id);

  static Future<JsonQuery> getAllForUser() {
    return FirebaseFirestore.instance
        .collection('Fathers')
        .orderBy('Name')
        .get();
  }

  @override
  Future<String?> getParentName() async {
    return (await churchId?.get())?.data()?['Name'];
  }

  @override
  JsonRef? get parentId => churchId;
}

class Job extends MiniModel {
  Job(String id, String name) : super('Jobs', id, name);
  Job._createFromData(Json data, String id)
      : super.createFromData('Jobs', data, id);

  Job.createNew() : super.createNew('Jobs');

  @override
  Json getMap() {
    return {'Name': name};
  }

  static Job? fromDoc(JsonDoc data) =>
      data.exists ? Job._createFromData(data.data()!, data.id) : null;

  static Job fromQueryDoc(JsonQueryDoc data) =>
      Job._createFromData(data.data(), data.id);

  static Future<JsonQuery> getAllForUser() {
    return FirebaseFirestore.instance.collection('Jobs').orderBy('Name').get();
  }
}

class PersonType extends MiniModel {
  PersonType(String id, String name) : super('Types', id, name);
  PersonType._createFromData(Json data, String id)
      : super.createFromData('Types', data, id);

  PersonType.createNew() : super.createNew('Types');

  @override
  Json getMap() {
    return {'Name': name};
  }

  static PersonType? fromDoc(JsonDoc data) =>
      data.exists ? PersonType._createFromData(data.data()!, data.id) : null;

  static PersonType fromQueryDoc(JsonQueryDoc data) =>
      PersonType._createFromData(data.data(), data.id);

  static Future<JsonQuery> getAllForUser() {
    return FirebaseFirestore.instance.collection('Types').orderBy('Name').get();
  }
}

class ServingType extends MiniModel {
  ServingType(String id, String name) : super('ServingTypes', id, name);
  ServingType._createFromData(Json data, String id)
      : super.createFromData('ServingTypes', data, id);

  ServingType.createNew() : super.createNew('ServingTypes');

  @override
  Json getMap() {
    return {'Name': name};
  }

  static ServingType? fromDoc(JsonDoc data) =>
      data.exists ? ServingType._createFromData(data.data()!, data.id) : null;

  static ServingType fromQueryDoc(JsonQueryDoc data) =>
      ServingType._createFromData(data.data(), data.id);

  static Future<JsonQuery> getAllForUser() {
    return FirebaseFirestore.instance
        .collection('ServingTypes')
        .orderBy('Name')
        .get();
  }
}

class StudyYear extends MiniModel {
  bool? isCollegeYear;
  int? grade;

  StudyYear(String id, String name, this.grade, {this.isCollegeYear})
      : super('StudyYears', id, name);
  StudyYear._createFromData(Json data, String id)
      : grade = data['Grade'],
        isCollegeYear = data['IsCollegeYear'],
        super.createFromData('StudyYears', data, id);

  StudyYear.createNew() : super.createNew('StudyYears') {
    grade = 0;
    isCollegeYear = false;
  }

  @override
  int get hashCode => hashValues(id, name, grade);

  @override
  bool operator ==(dynamic other) {
    return other is StudyYear && hashCode == other.hashCode;
  }

  @override
  Json getMap() {
    return {'Name': name, 'IsCollegeYear': isCollegeYear, 'Grade': grade};
  }

  static StudyYear fromDoc(JsonDoc data) =>
      StudyYear._createFromData(data.data()!, data.id);

  static Future<JsonQuery> getAllForUser() {
    return FirebaseFirestore.instance
        .collection('StudyYears')
        .orderBy('Grade')
        .get();
  }
}

class PreferredStudyYear extends StudyYear {
  double? preferredGroup;

  PreferredStudyYear.fromStudyYear(StudyYear sy, [this.preferredGroup])
      : super(sy.id, sy.name, sy.grade, isCollegeYear: sy.isCollegeYear);

  @override
  int get hashCode => hashValues(id, name, grade, preferredGroup);

  @override
  bool operator ==(dynamic other) {
    return other is PreferredStudyYear && hashCode == other.hashCode;
  }
}

class School extends MiniModel {
  String? address;
  School(String id, String name, {this.address}) : super('Schools', id, name);
  School._createFromData(Json data, String id)
      : super.createFromData('Schools', data, id) {
    address = data['Address'];
  }

  School.createNew() : super.createNew('Schools') {
    address = '';
  }

  @override
  Json getMap() {
    return {'Name': name, 'Address': address};
  }

  Future<Stream<JsonQuery>> getMembersLive() async {
    return FirebaseFirestore.instance
        .collection('Persons')
        .where('School', isEqualTo: ref)
        .snapshots();
  }

  static School fromDoc(JsonDoc data) =>
      School._createFromData(data.data()!, data.id);

  static Future<JsonQuery> getAllForUser() {
    return FirebaseFirestore.instance
        .collection('Schools')
        .orderBy('Name')
        .get();
  }
}

class History {
  static Future<List<History>> getAllFromRef(JsonCollectionRef ref) async {
    return (await ref.orderBy('Time', descending: true).limit(1000).get())
        .docs
        .map(fromDoc)
        .toList();
  }

  static History fromDoc(JsonDoc doc) {
    return History(
        doc.id, doc.data()!['By'], doc.data()!['Time'], doc.reference);
  }

  String id;
  String? byUser;
  Timestamp? time;

  JsonRef ref;

  History(this.id, this.byUser, this.time, this.ref);
}
