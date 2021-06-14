import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:meetinghelper/utils/globals.dart';

class Church {
  String? id;
  String? name;
  String? address;
  Church(this.id, this.name, {this.address});
  Church._createFromData(Map<String, dynamic> data, this.id) {
    name = data['Name'];
    address = data['Address'];
  }

  Church.createNew() {
    id = FirebaseFirestore.instance.collection('Churches').doc().id;
    name = '';
    address = '';
  }

  DocumentReference get ref =>
      FirebaseFirestore.instance.collection('Churches').doc(id);

  @override
  bool operator ==(dynamic other) {
    return id == other.id;
  }

  Map<String, dynamic> getMap() {
    return {'Name': name, 'Address': address};
  }

  Stream<QuerySnapshot> getMembersLive() {
    return FirebaseFirestore.instance
        .collection('Fathers')
        .where('ChurchId', isEqualTo: ref)
        .snapshots();
  }

  static Church fromDoc(DocumentSnapshot data) =>
      Church._createFromData(data.data()!, data.id);

  static Future<QuerySnapshot> getAllForUser() {
    return FirebaseFirestore.instance
        .collection('Churches')
        .orderBy('Name')
        .get(dataSource);
  }
}

class School {
  String? id;
  String? name;
  String? address;
  School(this.id, this.name, {this.address});
  School._createFromData(Map<String, dynamic> data, this.id) {
    name = data['Name'];
    address = data['Address'];
  }

  School.createNew() {
    id = FirebaseFirestore.instance.collection('Schools').doc().id;
    name = '';
    address = '';
  }

  DocumentReference get ref =>
      FirebaseFirestore.instance.collection('Schools').doc(id);

  @override
  bool operator ==(dynamic other) {
    return id == other.id;
  }

  Map<String, dynamic> getMap() {
    return {'Name': name, 'Address': address};
  }

  Future<Stream<QuerySnapshot>> getMembersLive() async {
    return FirebaseFirestore.instance
        .collection('Persons')
        .where('School', isEqualTo: ref)
        .snapshots();
  }

  static School fromDoc(DocumentSnapshot data) =>
      School._createFromData(data.data()!, data.id);

  static Future<QuerySnapshot> getAllForUser() {
    return FirebaseFirestore.instance
        .collection('Schools')
        .orderBy('Name')
        .get(dataSource);
  }
}

class Father {
  String? id;
  String? name;
  DocumentReference? churchId;
  Father(this.id, this.name, this.churchId);
  Father._createFromData(Map<String, dynamic> data, this.id) {
    name = data['Name'];
    churchId = data['ChurchId'];
  }

  Father.createNew() {
    id = FirebaseFirestore.instance.collection('Fathers').doc().id;
    name = '';
  }

  DocumentReference get ref =>
      FirebaseFirestore.instance.collection('Fathers').doc(id);

  @override
  bool operator ==(dynamic other) {
    return id == other.id;
  }

  Future<String?> getChurchName() async {
    if (churchId == null) return '';
    return Church.fromDoc(await churchId!.get()).name;
  }

  Map<String, dynamic> getMap() {
    return {'Name': name, 'ChurchId': churchId};
  }

  static Father fromDoc(DocumentSnapshot data) =>
      Father._createFromData(data.data()!, data.id);

  static Future<QuerySnapshot> getAllForUser() {
    return FirebaseFirestore.instance
        .collection('Fathers')
        .orderBy('Name')
        .get(dataSource);
  }
}

class StudyYear {
  String? id;
  String? name;
  bool? isCollegeYear;
  int? grade;

  StudyYear(this.id, this.name, this.grade);
  StudyYear._createFromData(Map<String, dynamic> data, this.id) {
    name = data['Name'];
    grade = data['Grade'];
    isCollegeYear = data['IsCollegeYear'];
  }

  StudyYear.createNew() {
    id = FirebaseFirestore.instance.collection('StudyYears').doc().id;
    name = '';
    grade = 0;
    isCollegeYear = false;
  }

  @override
  int get hashCode => hashValues(id, name, grade);

  DocumentReference get ref =>
      FirebaseFirestore.instance.collection('StudyYears').doc(id);

  @override
  bool operator ==(dynamic other) {
    return other is StudyYear && hashCode == other.hashCode;
  }

  Map<String, dynamic> getMap() {
    return {'Name': name, 'IsCollegeYear': isCollegeYear, 'Grade': grade};
  }

  static StudyYear fromDoc(DocumentSnapshot data) =>
      StudyYear._createFromData(data.data()!, data.id);

  static Future<QuerySnapshot> getAllForUser() {
    return FirebaseFirestore.instance
        .collection('StudyYears')
        .orderBy('Grade')
        .get(dataSource);
  }
}

class History {
  static Future<List<History>> getAllFromRef(CollectionReference ref) async {
    return (await ref
            .orderBy('Time', descending: true)
            .limit(1000)
            .get(dataSource))
        .docs
        .map(fromDoc)
        .toList();
  }

  static History fromDoc(DocumentSnapshot doc) {
    return History(
        doc.id, doc.data()!['By'], doc.data()!['Time'], doc.reference);
  }

  String id;
  String? byUser;
  Timestamp? time;

  DocumentReference ref;

  History(this.id, this.byUser, this.time, this.ref);
}
