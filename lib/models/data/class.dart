import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:meetinghelper/models/super_classes.dart';
import 'package:meetinghelper/utils/globals.dart';
import 'package:meetinghelper/utils/typedefs.dart';
import 'package:rxdart/rxdart.dart';

import 'person.dart';
import 'user.dart';

class Class extends DataObject with PhotoObject, ParentObject<Person> {
  JsonRef? studyYear;
  bool gender;

  late List<String> allowedUsers;
  String? lastEdit;

  Class(
      {JsonRef? ref,
      String? id,
      required String name,
      List<String>? allowedUsers,
      this.studyYear,
      this.gender = true,
      bool hasPhoto = false,
      Color? color,
      this.lastEdit})
      : super(
            ref ??
                FirebaseFirestore.instance
                    .collection('Classes')
                    .doc(id ?? 'null'),
            name,
            color) {
    this.allowedUsers = allowedUsers ?? [];
    this.hasPhoto = hasPhoto;
    lastEdit ??= auth.FirebaseAuth.instance.currentUser!.uid;
    defaultIcon = const IconData(0xf233, fontFamily: 'MaterialIconsR');
  }

  Class.createFromData(Map<dynamic, dynamic> data, JsonRef ref)
      : gender = data['Gender'] ?? true,
        super.createFromData(data, ref) {
    studyYear = data['StudyYear'];
    hasPhoto = data['HasPhoto'] ?? false;

    allowedUsers = data['Allowed']?.cast<String>() ?? [];

    lastEdit = data['LastEdit'];

    defaultIcon = const IconData(0xf233, fontFamily: 'MaterialIconsR');
  }

  @override
  Reference get photoRef =>
      FirebaseStorage.instance.ref().child('ClassesPhotos/$id');

  @override
  Future<List<Person>> getChildren(
      [String orderBy = 'Name', bool tranucate = false]) async {
    return getPersonMembersList(orderBy, tranucate);
  }

  String getGenderName() {
    return gender ? 'بنين' : 'بنات';
  }

  @override
  Json getHumanReadableMap() => {
        'Name': name,
        'StudyYear': studyYear ?? '',
        'Gender': gender,
      };

  @override
  Json getMap() => {
        'Name': name,
        'StudyYear': studyYear,
        'Gender': gender,
        'HasPhoto': hasPhoto,
        'Color': color.value,
        'LastEdit': lastEdit,
        'Allowed': allowedUsers
      };

  Future<List<Person>> getMembersList(
      [String orderBy = 'Name', bool tranucate = false]) async {
    if (tranucate) {
      return (await FirebaseFirestore.instance
              .collection('Persons')
              .where('ClassId', isEqualTo: ref)
              .orderBy(orderBy)
              .limit(5)
              .get(dataSource))
          .docs
          .map(Person.fromQueryDoc)
          .toList();
    }
    return (await FirebaseFirestore.instance
            .collection('Persons')
            .where('ClassId', isEqualTo: ref)
            .orderBy(orderBy)
            .get(dataSource))
        .docs
        .map(Person.fromQueryDoc)
        .toList();
  }

  Stream<List<Person>> getMembersLive(
      {bool descending = false, String orderBy = 'Name'}) {
    return getClassMembersLive(ref, orderBy, descending)
        .map((l) => l.map((e) => e!).toList());
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
      return (await FirebaseFirestore.instance
              .collection('Persons')
              .where('ClassId',
                  isEqualTo:
                      FirebaseFirestore.instance.collection('Classes').doc(id))
              .limit(5)
              .orderBy(orderBy)
              .get(dataSource))
          .docs
          .map(Person.fromQueryDoc)
          .toList();
    }
    return (await FirebaseFirestore.instance
            .collection('Persons')
            .where('ClassId',
                isEqualTo:
                    FirebaseFirestore.instance.collection('Classes').doc(id))
            .orderBy(orderBy)
            .get(dataSource))
        .docs
        .map(Person.fromQueryDoc)
        .toList();
  }

  @override
  Future<String?> getSecondLine() async {
    final String key =
        Hive.box('Settings').get('ClassSecondLine', defaultValue: '');
    if (key == 'Members') {
      return getMembersString();
    } else if (key == 'StudyYear') {
      return getStudyYearName();
    } else if (key == 'Gender') {
      return getGenderName();
    } else if (key == 'Allowed') {
      final rslt = <String>[];
      for (final item in allowedUsers.take(3)) {
        rslt.add((await FirebaseFirestore.instance
                .doc('Users/$item')
                .get(dataSource))
            .data()!['Name']);
      }
      return rslt.join(',');
    }
    return getHumanReadableMap()[key];
  }

  Future<String> getStudyYearName() async {
    return (await studyYear?.get(dataSource))?.data()?['Name'] ?? '';
  }

  static Class empty() {
    return Class(
        name: '',
        allowedUsers: [auth.FirebaseAuth.instance.currentUser!.uid],
        gender: false,
        hasPhoto: false);
  }

  static Class? fromDoc(JsonDoc data) =>
      data.exists ? Class.createFromData(data.data()!, data.reference) : null;

  static Class fromQueryDoc(JsonQueryDoc data) =>
      Class.createFromData(data.data(), data.reference);

  static Future<Class?> fromId(String id) async =>
      Class.fromDoc(await FirebaseFirestore.instance.doc('Classes/$id').get());

  static Stream<List<Class>> getAllForUser({
    String orderBy = 'Name',
    bool descending = false,
  }) {
    return User.instance.stream.switchMap((u) {
      if (u.superAccess) {
        return FirebaseFirestore.instance
            .collection('Classes')
            .orderBy(orderBy, descending: descending)
            .snapshots()
            .map((c) => c.docs.map(fromQueryDoc).toList());
      } else {
        return FirebaseFirestore.instance
            .collection('Classes')
            .where('Allowed', arrayContains: u.uid)
            .orderBy(orderBy, descending: descending)
            .snapshots()
            .map((c) => c.docs.map(fromQueryDoc).toList());
      }
    });
  }

  static Stream<List<Person?>> getClassMembersLive(JsonRef id,
      [String orderBy = 'Name', bool descending = false]) {
    return FirebaseFirestore.instance
        .collection('Persons')
        .where('ClassId', isEqualTo: id)
        .orderBy(orderBy, descending: descending)
        .snapshots()
        .map((p) => p.docs.map(Person.fromDoc).toList());
  }

  static Json getEmptyExportMap() => {
        'ID': 'id',
        'Name': 'name',
        'StudyYear': 'studyYear',
        'Gender': 'gender',
        'HasPhoto': 'hasPhoto',
        'Color': 'color.value',
        'Allowed': 'allowedUsers'
      };

  static Json getHumanReadableMap2() => {
        'Name': 'الاسم',
        'StudyYear': 'سنة الدراسة',
        'Gender': 'نوع الفصل',
        'Color': 'اللون',
        'Allowed': 'المخدومين المسموح لهم بالرؤية والتعديل'
      };

  @override
  Class copyWith() {
    return Class.createFromData(getMap(), ref);
  }
}
