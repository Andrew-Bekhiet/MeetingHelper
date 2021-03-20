import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:flutter/material.dart';
import 'package:meetinghelper/models/data_object_widget.dart';
import 'package:meetinghelper/models/models.dart';
import 'package:meetinghelper/models/super_classes.dart';
import 'package:meetinghelper/models/user.dart';
import 'package:meetinghelper/utils/globals.dart';
import 'package:rxdart/rxdart.dart';

import 'mini_models.dart';

class CheckListOptions<T extends DataObject> extends ListOptions<T> {
  final HistoryDay day;
  final DayListType type;

  CheckListOptions(
      {this.day, List<T> items, this.type, Stream<List<T>> documentsData})
      : super(
          documentsData: documentsData,
          items: items,
          hasNotch: false,
          selectionMode: true,
        );

  Stream<QuerySnapshot> get attended async* {
    if (User.instance.superAccess ||
        (day is ServantsHistoryDay && User.instance.secretary)) {
      await for (var s in ref.snapshots()) {
        yield s;
      }
    } else {
      await for (var s in ref
          .where('ClassId',
              whereIn: (await FirebaseFirestore.instance
                      .collection('Classes')
                      .where('Allowed',
                          arrayContains:
                              auth.FirebaseAuth.instance.currentUser.uid)
                      .get(dataSource))
                  .docs
                  .map((e) => e.reference)
                  .toList())
          .snapshots()) {
        yield s;
      }
    }
  }

  CollectionReference get ref => day.collections[type];

  @override
  bool get selectionMode => true;
}

class HistoryDayOptions with ChangeNotifier {
  bool _grouped;
  bool _showTrueOnly;
  bool _enabled;

  HistoryDayOptions({bool grouped, bool showTrueOnly, bool enabled})
      : _enabled = enabled,
        _grouped = grouped,
        _showTrueOnly = showTrueOnly;

  bool get enabled => _enabled;
  set enabled(bool enabled) {
    _enabled = enabled;
    notifyListeners();
  }

  bool get grouped => _grouped;

  set grouped(bool grouped) {
    _grouped = grouped;
    notifyListeners();
  }

  bool get showTrueOnly => _showTrueOnly;

  set showTrueOnly(bool showTrueOnly) {
    _showTrueOnly = showTrueOnly;
    notifyListeners();
  }

  @override
  int get hashCode => hashValues(_showTrueOnly, _grouped, _enabled);

  @override
  bool operator ==(dynamic o) =>
      o is HistoryDayOptions && o.hashCode == hashCode;
}

class ListOptions<T extends DataObject> with ChangeNotifier {
  BehaviorSubject<List<T>> _documentsData;

  Stream<List<T>> get documentsData => _documentsData;

  set documentsData(Stream<List<T>> documentsData) {
    _documentsData = documentsData != null
        ? (BehaviorSubject<List<T>>()..addStream(documentsData))
        : null;
    _documentsData = documentsData;
  }

  List<T> _items = <T>[];
  bool _selectionMode = false;

  List<T> selected = <T>[];

  final void Function(T) tap;
  final void Function(T) onLongPress;

  final T empty;
  final bool showNull;

  Widget Function(T,
      {@required void Function() onLongPress,
      @required void Function() onTap,
      Widget trailing}) itemBuilder;
  final Widget floatingActionButton;
  final bool doubleActionButton;
  final bool hasNotch;

  ListOptions({
    this.doubleActionButton = false,
    this.hasNotch = true,
    this.floatingActionButton,
    this.itemBuilder,
    this.onLongPress,
    this.tap,
    this.empty,
    List<T> items,
    this.showNull = false,
    bool selectionMode = false,
    Stream<List<T>> documentsData,
    List<T> selected,
  })  : assert(showNull == false || (showNull == true && empty != null)),
        _items = items,
        _selectionMode = selectionMode {
    _documentsData = documentsData != null
        ? (BehaviorSubject<List<T>>()..addStream(documentsData))
        : null;
    this.selected = selected ?? [];
    itemBuilder ??= (i,
            {void Function() onLongPress,
            void Function() onTap,
            Widget trailing}) =>
        DataObjectWidget<T>(i,
            onLongPress: onLongPress, onTap: onTap, trailing: trailing);
  }

  List<T> get items => _items;
  set items(List<T> items) {
    _items = items;
    notifyListeners();
  }

  bool get selectionMode => _selectionMode;

  set selectionMode(bool selectionMode) {
    _selectionMode = selectionMode;
    notifyListeners();
  }
}

class ServicesListOptions with ChangeNotifier {
  BehaviorSubject<Map<StudyYear, List<Class>>> _documentsData;

  Stream<Map<StudyYear, List<Class>>> get documentsData => _documentsData;

  set documentsData(Stream<Map<StudyYear, List<Class>>> documentsData) {
    _documentsData = documentsData != null
        ? (BehaviorSubject<Map<StudyYear, List<Class>>>()
          ..addStream(documentsData))
        : null;
  }

  bool _selectionMode = false;

  List<Class> selected = <Class>[];

  final void Function(Class, BuildContext) tap;
  final void Function(Class, BuildContext) onLongPress;

  final Widget floatingActionButton;
  final bool doubleActionButton;
  final bool hasNotch;

  ServicesListOptions({
    this.doubleActionButton = false,
    this.hasNotch = true,
    this.floatingActionButton,
    this.onLongPress,
    this.tap,
    bool selectionMode = false,
    Stream<Map<StudyYear, List<Class>>> documentsData,
  })  : _selectionMode = selectionMode,
        _documentsData = documentsData != null
            ? (BehaviorSubject<Map<StudyYear, List<Class>>>()
              ..addStream(documentsData))
            : null;

  bool get selectionMode => _selectionMode;

  set selectionMode(bool selectionMode) {
    _selectionMode = selectionMode;
    notifyListeners();
  }
}
