import 'dart:async';

import 'package:flutter/material.dart';
import 'package:meetinghelper/models/models.dart';
import 'package:meetinghelper/models/super_classes.dart';

class OrderOptions extends ChangeNotifier {
  String classOrderBy = 'Name';
  String personOrderBy = 'Name';
  bool personASC = true;
  bool classASC = true;

  StreamController<bool> personSelectAll = StreamController.broadcast();
  StreamController<bool> classSelectAll = StreamController.broadcast();

  OrderOptions({
    this.classASC,
    this.personASC,
    this.classOrderBy,
    this.personOrderBy,
  });

  void setClassOrderBy(String orderBy) {
    classOrderBy = orderBy;
    notifyListeners();
  }

  void setPersonOrderBy(String orderBy) {
    personOrderBy = orderBy;
    notifyListeners();
  }

  void setPersonASC(bool asc) {
    personASC = asc;
    notifyListeners();
  }

  void setClassASC(bool asc) {
    classASC = asc;
    notifyListeners();
  }

  StreamController<bool> selectAllOf<T extends DataObject>() {
    if (T == Class) return classSelectAll;
    if (T == Person) return personSelectAll;
    throw UnimplementedError();
  }

  @override
  void dispose() {
    personSelectAll.close();
    classSelectAll.close();
    super.dispose();
  }
}
