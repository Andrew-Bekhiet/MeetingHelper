import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:meetinghelper/models/super_classes.dart';
import 'package:meetinghelper/utils/globals.dart';

import 'models.dart';
import 'user.dart';

class Class extends DataObject with PhotoObject, ParentObject<Person> {
  DocumentReference studyYear;
  bool gender;

  List<String> allowedUsers;
  String lastEdit;

  Class(String id, String name, this.allowedUsers, this.studyYear, this.gender,
      bool hasPhoto,
      {color = Colors.transparent, this.lastEdit})
      : super(id, name, color) {
    this.hasPhoto = hasPhoto;
    lastEdit ??= auth.FirebaseAuth.instance.currentUser.uid;
    defaultIcon = const IconData(0xf233, fontFamily: 'MaterialIconsR');
  }

  Class.createFromData(Map<dynamic, dynamic> data, String id)
      : super.createFromData(data, id) {
    studyYear = data['StudyYear'];
    gender = data['Gender'];

    hasPhoto = data['HasPhoto'] ?? false;

    allowedUsers = data['Allowed'].cast<String>();

    lastEdit = data['LastEdit'];

    defaultIcon = const IconData(0xf233, fontFamily: 'MaterialIconsR');
  }

  @override
  Reference get photoRef =>
      FirebaseStorage.instance.ref().child('ClassesPhotos/$id');

  @override
  DocumentReference get ref => FirebaseFirestore.instance.doc('Classes/$id');

  @override
  Future<List<Person>> getChildren(
      [String orderBy = 'Name', bool tranucate = false]) async {
    return await getPersonMembersList(orderBy, tranucate);
  }

  String getGenderName() {
    return gender ? 'بنين' : 'بنات';
  }

  @override
  Map<String, dynamic> getHumanReadableMap() => {
        'Name': name ?? '',
        'StudyYear': studyYear ?? '',
        'Gender': gender ?? '',
      };

  @override
  Map<String, dynamic> getMap() => {
        'Name': name,
        'StudyYear': studyYear,
        'Gender': gender,
        'HasPhoto': hasPhoto ?? false,
        'Color': color.value,
        'LastEdit': lastEdit,
        'Allowed': allowedUsers
      };

  Future<List<Person>> getMembersList(
      [String orderBy = 'Name', bool tranucate = false]) async {
    if (tranucate) {
      return Person.getAll((await FirebaseFirestore.instance
              .collection('Persons')
              .where('ClassId', isEqualTo: ref)
              .orderBy(orderBy)
              .limit(5)
              .get(dataSource))
          .docs);
    }
    return Person.getAll((await FirebaseFirestore.instance
            .collection('Persons')
            .where('ClassId', isEqualTo: ref)
            .orderBy(orderBy)
            .get(dataSource))
        .docs);
  }

  Stream<QuerySnapshot> getMembersLive(
      {bool descending = false, String orderBy = 'Name'}) {
    return getClassMembersLive(ref, orderBy, descending);
    // return FirebaseFirestore.instance
    //     .collection('Streets')
    //     .where('ClassId',
    //         isEqualTo: FirebaseFirestore.instance.collection('Classes').doc(id))
    //     .snapshots();
  }

  @override
  Future<String> getMembersString() async {
    return (await getMembersList('Name', true))
        .map((f) => f.name)
        .toList()
        .join(',');
  }

  Future<List<Person>> getPersonMembersList(
      [String orderBy = 'Name', bool tranucate = false]) async {
    if (tranucate) {
      return Person.getAll((await FirebaseFirestore.instance
              .collection('Persons')
              .where('ClassId',
                  isEqualTo:
                      FirebaseFirestore.instance.collection('Classes').doc(id))
              .limit(5)
              .orderBy(orderBy)
              .get(dataSource))
          .docs);
    }
    return Person.getAll((await FirebaseFirestore.instance
            .collection('Persons')
            .where('ClassId',
                isEqualTo:
                    FirebaseFirestore.instance.collection('Classes').doc(id))
            .orderBy(orderBy)
            .get(dataSource))
        .docs);
  }

  @override
  Future<String> getSecondLine() async {
    String key = Hive.box('Settings').get('ClassSecondLine', defaultValue: '');
    if (key == 'Members') {
      return await getMembersString();
    } else if (key == 'StudyYear') {
      return await getStudyYearName();
    } else if (key == 'Gender') {
      return getGenderName();
    } else if (key == 'Allowed') {
      var rslt = <String>[];
      for (var item in allowedUsers.take(3)) {
        rslt.add((await FirebaseFirestore.instance
                .doc('Users/$item')
                .get(dataSource))
            .data()['Name']);
      }
      return rslt.join(',');
    }
    return getHumanReadableMap()[key] ?? '';
  }

  Future<String> getStudyYearName() async {
    var tmp = (await studyYear?.get(dataSource))?.data();
    if (tmp == null) return '';
    return tmp['Name'] ?? 'لا يوجد';
  }

  static Class empty() {
    return Class('', '', [auth.FirebaseAuth.instance.currentUser.uid], null,
        false, false);
  }

  static Class fromDoc(DocumentSnapshot data) =>
      data.exists ? Class.createFromData(data.data(), data.id) : null;

  static Future<Class> fromId(String id) async =>
      Class.fromDoc(await FirebaseFirestore.instance.doc('Classes/$id').get());

  static List<Class> getAll(List<DocumentSnapshot> classes) {
    var rslt = <Class>[];
    for (DocumentSnapshot item in classes) {
      rslt.add(Class.fromDoc(item));
    }
    return rslt;
  }

  static Stream<QuerySnapshot> getAllForUser({
    String orderBy = 'Name',
    bool descending = false,
  }) async* {
    await for (var u in User.instance.stream) {
      if (u.superAccess) {
        await for (var s in FirebaseFirestore.instance
            .collection('Classes')
            .orderBy(orderBy, descending: descending)
            .snapshots()) yield s;
      } else {
        await for (var s in FirebaseFirestore.instance
            .collection('Classes')
            .where('Allowed', arrayContains: u.uid)
            .orderBy(orderBy, descending: descending)
            .snapshots()) yield s;
      }
    }
  }

  static Stream<QuerySnapshot> getClassMembersLive(DocumentReference id,
      [String orderBy = 'Name', bool descending = false]) {
    return FirebaseFirestore.instance
        .collection('Persons')
        .where('ClassId', isEqualTo: id)
        .orderBy(orderBy, descending: descending)
        .snapshots();
  }

  static Map<String, dynamic> getEmptyExportMap() => {
        'ID': 'id',
        'Name': 'name',
        'StudyYear': 'studyYear',
        'Gender': 'gender',
        'HasPhoto': 'hasPhoto',
        'Color': 'color.value',
        'Allowed': 'allowedUsers'
      };

  static Map<String, dynamic> getHumanReadableMap2() => {
        'Name': 'الاسم',
        'StudyYear': 'سنة الدراسة',
        'Gender': 'نوع الفصل',
        'Color': 'اللون',
        'Allowed': 'الأشخاص المسموح لهم بالرؤية والتعديل'
      };
}
