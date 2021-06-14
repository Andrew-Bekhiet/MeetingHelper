import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:meetinghelper/models/data_object_widget.dart';
import 'package:meetinghelper/models/models.dart';
import 'package:meetinghelper/models/super_classes.dart';
import 'package:meetinghelper/models/user.dart';
import 'package:meetinghelper/utils/globals.dart';
import 'package:meetinghelper/utils/helpers.dart';
import 'package:rxdart/rxdart.dart';
import 'package:tuple/tuple.dart';

import 'mini_models.dart';

abstract class BaseListController<L, U> {
  final BehaviorSubject<L> _objectsData;
  ValueStream<L> get objectsData => _objectsData.stream;
  L? get items => _objectsData.value;

  StreamSubscription<L>? _objectsDataListener;

  final BehaviorSubject<bool> _selectionMode;
  BehaviorSubject<bool> get selectionMode => _selectionMode;
  bool? get selectionModeLatest => _selectionMode.value;

  final BehaviorSubject<Map<String, U>?> _selected;
  ValueStream<Map<String, U>?> get selected => _selected.stream;
  Map<String, U>? get selectedLatest => _selected.value;

  final BehaviorSubject<String> _searchQuery;
  BehaviorSubject<String> get searchQuery => _searchQuery;
  String? get searchQueryLatest => _searchQuery.value;

  StreamSubscription<String>? _searchQueryListener;

  final void Function(U)? tap;
  final void Function(U)? onLongPress;

  final U? empty;
  final bool showNull;

  void selectAll();
  void selectNone() {
    if (!_selectionMode.requireValue) _selectionMode.add(true);
    _selected.add({});
  }

  void toggleSelected(U item);

  void select(U item);

  void deselect(U item);

  BaseListController({
    this.onLongPress,
    this.tap,
    this.empty,
    this.showNull = false,
    bool selectionMode = false,
    Stream<L>? itemsStream,
    L? items,
    Map<String, U>? selected,
    Stream<String>? searchQuery,
  })  : assert(itemsStream != null || items != null),
        assert(showNull == false || (showNull == true && empty != null)),
        _selectionMode = BehaviorSubject<bool>.seeded(selectionMode),
        _selected = BehaviorSubject<Map<String, U>>.seeded(selected ?? {}),
        _searchQuery = searchQuery == null
            ? BehaviorSubject<String>.seeded('')
            : BehaviorSubject<String>(),
        _objectsData = itemsStream != null
            ? BehaviorSubject<L>()
            : BehaviorSubject<L>.seeded(items!) {
    //
    _searchQueryListener =
        searchQuery?.listen(_searchQuery.add, onError: _searchQuery.addError);

    _objectsDataListener =
        itemsStream?.listen(_objectsData.add, onError: _objectsData.addError);
  }

  Future<void> dispose() async {
    await _objectsDataListener?.cancel();
    if (!_objectsData.isClosed) await _objectsData.close();

    if (!_selected.isClosed) await _selected.close();
    if (!_selectionMode.isClosed) await _selectionMode.close();

    await _searchQueryListener?.cancel();
    if (!_searchQuery.isClosed) await _searchQuery.close();
  }
}

class DataObjectListController<T extends DataObject>
    implements BaseListController<List<T>, T> {
  @override
  late final BehaviorSubject<List<T>> _objectsData;
  @override
  ValueStream<List<T>> get objectsData => _objectsData.stream;
  @override
  List<T>? get items => objectsData.value;

  @override
  StreamSubscription<List<T>>? _objectsDataListener;

  final BehaviorSubject<Map<String, T>> _originalObjectsData;
  ValueStream<Map<String, T>> get originalObjectsData =>
      _originalObjectsData.stream;
  Map<String, T>? get originalObjectsDataLatest => originalObjectsData.value;

  StreamSubscription<Object>? _originalObjectsDataListener;

  @override
  final BehaviorSubject<bool> _selectionMode;
  @override
  BehaviorSubject<bool> get selectionMode => _selectionMode;
  @override
  bool? get selectionModeLatest => _selectionMode.value;

  @override
  final BehaviorSubject<Map<String, T>> _selected;
  @override
  ValueStream<Map<String, T>> get selected => _selected.stream;
  @override
  Map<String, T>? get selectedLatest => _selected.value;

  @override
  final BehaviorSubject<String> _searchQuery;
  @override
  BehaviorSubject<String> get searchQuery => _searchQuery;
  @override
  String? get searchQueryLatest => _searchQuery.value;

  @override
  StreamSubscription<String>? _searchQueryListener;

  final List<T> Function(List<T>, String) _filter;
  @override
  final void Function(T)? tap;
  @override
  final void Function(T)? onLongPress;

  @override
  final T? empty;
  @override
  final bool showNull;

  final Widget Function(T, void Function(T)? onLongPress,
      void Function(T)? onTap, Widget? trailing, Widget? subtitle) itemBuilder;

  late final Widget Function(T,
      {void Function(T)? onLongPress,
      void Function(T)? onTap,
      Widget? trailing,
      Widget? subtitle}) buildItem;

  DataObjectListController({
    Widget Function(T, void Function(T)? onLongPress, void Function(T)? onTap,
            Widget? trailing, Widget? subtitle)?
        itemBuilder,
    this.onLongPress,
    this.tap,
    this.empty,
    this.showNull = false,
    bool selectionMode = false,
    Stream<List<T>>? itemsStream,
    List<T>? items,
    Map<String, T>? selected,
    List<T> Function(List<T>, String)? filter,
    Stream<String>? searchQuery,
  })  : assert(itemsStream != null || items != null),
        assert(showNull == false || (showNull == true && empty != null)),
        _filter = (filter ??
            ((o, f) =>
                o.where((e) => filterString(e.name).contains(f)).toList())),
        _searchQuery = searchQuery == null
            ? BehaviorSubject<String>.seeded('')
            : BehaviorSubject<String>(),
        _selected = BehaviorSubject<Map<String, T>>.seeded(selected ?? {}),
        _selectionMode = BehaviorSubject<bool>.seeded(selectionMode),
        _originalObjectsData = itemsStream != null
            ? BehaviorSubject<Map<String, T>>()
            : BehaviorSubject<Map<String, T>>.seeded(
                {for (final o in items!) o.id: o}),
        _objectsData = showNull
            ? BehaviorSubject<List<T>>.seeded([empty!])
            : BehaviorSubject<List<T>>(),
        itemBuilder = (itemBuilder ??
            (i, void Function(T)? onLongPress, void Function(T)? onTap,
                    Widget? trailing, Widget? subtitle) =>
                DataObjectWidget<T>(i,
                    subtitle: subtitle,
                    onLongPress:
                        onLongPress != null ? () => onLongPress(i) : null,
                    onTap: onTap != null ? () => onTap(i) : null,
                    trailing: trailing)) {
    //
    _searchQueryListener =
        searchQuery?.listen(_searchQuery.add, onError: _searchQuery.addError);

    buildItem = (i, {onLongPress, onTap, trailing, subtitle}) {
      return this.itemBuilder(i, onLongPress, onTap, trailing, subtitle);
    };

    _originalObjectsDataListener = itemsStream
        ?.listen((l) => _originalObjectsData.add({for (final o in l) o.id: o}));

    _objectsDataListener = Rx.combineLatest2<String, Map<String, T>, List<T>>(
      _searchQuery,
      _originalObjectsData,
      (search, items) => search.isNotEmpty
          ? _filter(items.values.toList(), search)
          : items.values.toList(),
    ).listen(_objectsData.add, onError: _objectsData.addError);
  }

  @override
  void selectAll() {
    if (!_selectionMode.requireValue) _selectionMode.add(true);
    _selected.add({for (var item in _objectsData.requireValue) item.id: item});
  }

  @override
  void selectNone([bool enterSelectionMode = true]) {
    if (enterSelectionMode && !_selectionMode.requireValue)
      _selectionMode.add(true);
    _selected.add({});
  }

  @override
  void toggleSelected(T item) {
    if (_selected.requireValue.containsKey(item.id)) {
      deselect(item);
    } else {
      select(item);
    }
  }

  @override
  void select(T item) {
    assert(!_selected.requireValue.containsKey(item.id));
    _selected.add({..._selected.requireValue, item.id: item});
  }

  @override
  void deselect(T item) {
    assert(_selected.requireValue.containsKey(item.id));
    _selected.add(_selected.requireValue..remove(item.id));
  }

  @override
  Future<void> dispose() async {
    await _objectsDataListener?.cancel();
    if (!_objectsData.isClosed) await _objectsData.close();

    await _originalObjectsDataListener?.cancel();
    if (!_originalObjectsData.isClosed) await _originalObjectsData.close();

    if (!_selected.isClosed) await _selected.close();
    if (!_selectionMode.isClosed) await _selectionMode.close();

    await _searchQueryListener?.cancel();
    if (!_searchQuery.isClosed) await _searchQuery.close();
  }
}

class CheckListController<T extends Person>
    implements DataObjectListController<T> {
  final HistoryDay day;
  final DayListType type;
  final HistoryDayOptions dayOptions;

  @override
  late final BehaviorSubject<List<T>> _objectsData;
  @override
  ValueStream<List<T>> get objectsData => _objectsData.stream;
  @override
  List<T>? get items => objectsData.value;

  @override
  StreamSubscription<List<T>>? _objectsDataListener;

  @override
  final BehaviorSubject<Map<String, T>> _originalObjectsData;
  @override
  ValueStream<Map<String, T>> get originalObjectsData =>
      _originalObjectsData.stream;
  @override
  Map<String, T>? get originalObjectsDataLatest => originalObjectsData.value;

  @override
  StreamSubscription<Object>? _originalObjectsDataListener;

  @override
  final BehaviorSubject<bool> _selectionMode;
  @override
  BehaviorSubject<bool> get selectionMode => _selectionMode;

  @override
  final BehaviorSubject<Map<String, T>> _selected;
  @override
  ValueStream<Map<String, T>> get selected => _selected;
  @override
  Map<String, T>? get selectedLatest => _selected.value;

  @override
  final BehaviorSubject<String> _searchQuery;
  @override
  BehaviorSubject<String> get searchQuery => _searchQuery;
  @override
  String? get searchQueryLatest => _searchQuery.value;

  @override
  StreamSubscription<String>? _searchQueryListener;

  late final BehaviorSubject<Map<String, HistoryRecord>> _attended;
  ValueStream<Map<String, HistoryRecord>> get attended => _attended.stream;
  Map<String, HistoryRecord>? get attendedLatest => attended.value;

  StreamSubscription<Map<String, HistoryRecord>>? _attendedListener;

  final Stream<Map<DocumentReference, Tuple2<Class, List<T>>>> Function(
      List<T> data)? getGroupedData;

  CollectionReference? get ref => day.collections[type];

  @override
  bool get selectionModeLatest => true;

  @override
  final List<T> Function(List<T>, String) _filter;
  @override
  final void Function(T)? tap;
  @override
  final void Function(T)? onLongPress;

  @override
  T? get empty => null;
  @override
  bool get showNull => false;

  @override
  final Widget Function(T, void Function(T)? onLongPress,
      void Function(T)? onTap, Widget? trailing, Widget? subtitle) itemBuilder;

  @override
  late final Widget Function(T,
      {void Function(T)? onLongPress,
      void Function(T)? onTap,
      Widget? trailing,
      Widget? subtitle}) buildItem;

  CheckListController({
    this.getGroupedData,
    required this.day,
    required this.type,
    required this.dayOptions,
    Widget Function(T, void Function(T)? onLongPress, void Function(T)? onTap,
            Widget? trailing, Widget? subtitle)?
        itemBuilder,
    this.tap,
    this.onLongPress,
    List<T> Function(List<T>, String)? filter,
    Stream<List<T>>? itemsStream,
    Stream<Map<String, T>>? itemsMapStream,
    List<T>? items,
    Map<String, T>? selected,
    Stream<String>? searchQuery,
  })  : assert(dayOptions.grouped.value == false || getGroupedData != null),
        assert(itemsMapStream != null || itemsStream != null || items != null),
        _filter = (filter ??
            ((o, f) =>
                o.where((e) => filterString(e.name).contains(f)).toList())),
        _searchQuery = searchQuery != null
            ? BehaviorSubject<String>()
            : BehaviorSubject<String>.seeded(''),
        _selected = BehaviorSubject<Map<String, T>>.seeded(selected ?? {}),
        _selectionMode = BehaviorSubject<bool>.seeded(true),
        _originalObjectsData = BehaviorSubject<Map<String, T>>(),
        _objectsData = BehaviorSubject<List<T>>(),
        _attended = BehaviorSubject<Map<String, HistoryRecord>>(),
        itemBuilder = (itemBuilder ??
            (i, void Function(T)? onLongPress, void Function(T)? onTap,
                    Widget? trailing, Widget? subtitle) =>
                DataObjectWidget<T>(i,
                    subtitle: subtitle,
                    onLongPress:
                        onLongPress != null ? () => onLongPress(i) : null,
                    onTap: onTap != null ? () => onTap(i) : null,
                    trailing: trailing)) {
    //
    _searchQueryListener =
        searchQuery?.listen(_searchQuery.add, onError: _searchQuery.addError);

    _originalObjectsDataListener = (itemsMapStream ??
            (itemsStream != null
                ? itemsStream.map((l) => {for (final o in l) o.id: o})
                : Stream.value({for (final o in items!) o.id: o})))
        .listen(_originalObjectsData.add,
            onError: _originalObjectsData.addError);

    buildItem = (i, {onLongPress, onTap, trailing, subtitle}) {
      return this.itemBuilder(i, onLongPress, onTap, trailing, subtitle);
    };

    _attendedListener = (ref != null
            ? Rx.combineLatest2<User, List<Class>, Tuple2<User, List<Class>>>(
                    User.instance.stream,
                    Class.getAllForUser(),
                    (User a, List<Class> b) => Tuple2<User, List<Class>>(a, b))
                .switchMap(_attendedMapping)
            : Stream<Map<String, HistoryRecord>>.value({}))
        .listen(_attended.add, onError: _attended.addError);

    ///Listens to [dayOptions.showTrueonly] then the [_searchQuery]
    ///to filter the [_objectsData] by the [attended] Persons
    _objectsDataListener = Rx.combineLatest5<bool?, bool?, String,
        Map<String, T>, Map<String, HistoryRecord>, List<T>>(
      dayOptions.showOnly,
      dayOptions.sortByTimeASC,
      _searchQuery,
      _originalObjectsData,
      _attended,
      _objectsFilteringMapping,
    ).listen(_objectsData.add, onError: _objectsData.addError);
  }

  List<T> _objectsFilteringMapping(
      bool? showOnly,
      bool? sortByTimeASC,
      String search,
      Map<String, T> objects,
      Map<String, HistoryRecord> attended) {
    List<T> rslt = objects.values.toList();

    if (sortByTimeASC == true) {
      rslt = attended.map((k, v) => MapEntry(k, objects[k]!)).values.toList();
    } else if (sortByTimeASC == false) {
      rslt = attended
          .map((k, v) => MapEntry(k, objects[k]!))
          .values
          .toList()
          .reversed
          .toList();
    } else if (showOnly == null) {
      rslt = rslt.toList();
    } else if (showOnly == true) {
      rslt = objects.values
          .where(
            (i) => attended.containsKey(i.id),
          )
          .toList();
    } else {
      rslt = rslt
          .where(
            (i) => !attended.containsKey(i.id),
          )
          .toList();
    }

    if (search.isNotEmpty) {
      return _filter(rslt, search);
    }

    return rslt;
  }

  Stream<Map<String, HistoryRecord>> _attendedMapping(
      Tuple2<User, List<Class>> v) {
    if (v.item1.superAccess ||
        (day is ServantsHistoryDay && v.item1.secretary)) {
      return ref!.snapshots().map<Map<String, HistoryRecord>>((s) {
        Map<String, T> tempSelected = {};
        Map<String, HistoryRecord> snapshotMap =
            Map<String, HistoryRecord>.fromIterable(
          s.docs,
          key: (d) {
            if (originalObjectsData.value != null)
              tempSelected[d.id] = originalObjectsData.requireValue[d.id]!;
            return d.id;
          },
          value: (d) => HistoryRecord.fromQueryDoc(d, day),
        );
        _selected.add(tempSelected);
        return snapshotMap;
      });
    } else if (v.item2.length <= 10) {
      return ref!
          .where('ClassId', whereIn: v.item2.map((e) => e.ref).toList())
          .orderBy('Time')
          .snapshots()
          .map((s) {
        Map<String, T> tempSelected = {};
        Map<String, HistoryRecord> snapshotMap =
            Map<String, HistoryRecord>.fromIterable(
          s.docs,
          key: (d) {
            if (originalObjectsData.value != null)
              tempSelected[d.id] = originalObjectsData.requireValue[d.id]!;
            return d.id;
          },
          value: (d) => HistoryRecord.fromQueryDoc(d, day),
        );
        _selected.add(tempSelected);
        return snapshotMap;
      });
    }
    return Rx.combineLatestList<QuerySnapshot>(v.item2.split(10).map((c) => ref!
        .where('ClassId', whereIn: c.map((e) => e.ref).toList())
        .orderBy('Time')
        .snapshots())).map((s) => s.expand((n) => n.docs)).map((s) {
      Map<String, T> tempSelected = {};
      Map<String, HistoryRecord> snapshotMap =
          Map<String, HistoryRecord>.fromIterable(
        s,
        key: (d) {
          if (originalObjectsData.value != null)
            tempSelected[d.id] = originalObjectsData.requireValue[d.id]!;
          return d.id;
        },
        value: (d) => HistoryRecord.fromQueryDoc(d, day),
      );
      _selected.add(tempSelected);
      return snapshotMap;
    });
  }

  @override
  void selectAll() {
    throw UnimplementedError();
  }

  @override
  void selectNone([_ = true]) {
    throw UnimplementedError();
  }

  @override
  Future<void> toggleSelected(T item, {String? notes, Timestamp? time}) async {
    if (_selected.requireValue.containsKey(item.id)) {
      await deselect(item);
    } else {
      await select(item, notes: notes, time: time);
    }
  }

  @override
  Future<void> select(T item, {String? notes, Timestamp? time}) async {
    await HistoryRecord(
            type: type,
            parent: day,
            id: item.id,
            classId: item.classId!,
            time: time ?? Timestamp.now(),
            recordedBy: User.instance.uid!,
            notes: notes,
            isServant: T == User)
        .set();
  }

  @override
  Future<void> deselect(T item) async {
    await ref!.doc(item.id).delete();
  }

  Future<void> modifySelected(T item, {String? notes, Timestamp? time}) async {
    assert(_selected.requireValue.containsKey(item.id));
    await HistoryRecord(
            type: type,
            parent: day,
            id: item.id,
            classId: item.classId!,
            time: time ?? Timestamp.now(),
            recordedBy: User.instance.uid!,
            notes: notes,
            isServant: T == User)
        .update();
  }

  CheckListController<T> copyWith({
    Stream<Map<DocumentReference, Tuple2<Class, List<T>>>> Function(
            List<T?> data)?
        getGroupedData,
    HistoryDay? day,
    DayListType? type,
    HistoryDayOptions? dayOptions,
    Widget Function(T?, void Function(T)? onLongPress, void Function(T)? onTap,
            Widget? trailing, Widget? subtitle)?
        itemBuilder,
    void Function(T?)? onLongPress,
    void Function(T?)? tap,
    Stream<List<T>>? itemsStream,
    List<T>? items,
    Map<String, T>? selected,
    Stream<String>? searchQuery,
  }) {
    return CheckListController<T>(
      getGroupedData: getGroupedData ?? this.getGroupedData,
      day: day ?? this.day,
      type: type ?? this.type,
      dayOptions: dayOptions ?? this.dayOptions,
      itemBuilder: itemBuilder ?? this.itemBuilder,
      onLongPress: onLongPress ?? this.onLongPress,
      tap: tap ?? this.tap,
      itemsStream: itemsStream,
      itemsMapStream: originalObjectsData,
      items: items ?? this.items,
      selected: selected ?? this.selected.value,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }

  @override
  Future<void> dispose() async {
    await _objectsDataListener?.cancel();
    if (!_objectsData.isClosed) await _objectsData.close();

    await _originalObjectsDataListener?.cancel();
    if (!_originalObjectsData.isClosed) await _originalObjectsData.close();

    await _attendedListener?.cancel();
    if (!_attended.isClosed) await _attended.close();

    if (!_selected.isClosed) await _selected.close();
    if (!_selectionMode.isClosed) await _selectionMode.close();

    await _searchQueryListener?.cancel();
    if (!_searchQuery.isClosed) await _searchQuery.close();
  }
}

class HistoryDayOptions {
  final BehaviorSubject<bool> grouped;
  //show Only absent (false) or present (true) Persons
  final BehaviorSubject<bool?> showOnly;
  final BehaviorSubject<bool?> sortByTimeASC;
  //true -> ASC, false -> DESC, null -> sort by name
  final BehaviorSubject<bool> enabled;
  final BehaviorSubject<bool> showSubtitlesInGroups;
  final BehaviorSubject<bool> lockUnchecks;

  HistoryDayOptions(
      {bool grouped = false,
      bool? showOnly,
      bool? sortByTimeASC,
      bool enabled = false,
      bool lockUnchecks = true,
      bool showSubtitlesInGroups = false})
      : enabled = BehaviorSubject<bool>.seeded(enabled),
        grouped = BehaviorSubject<bool>.seeded(grouped),
        showSubtitlesInGroups =
            BehaviorSubject<bool>.seeded(showSubtitlesInGroups),
        sortByTimeASC = BehaviorSubject<bool?>.seeded(sortByTimeASC),
        lockUnchecks = BehaviorSubject<bool>.seeded(lockUnchecks),
        showOnly = BehaviorSubject<bool?>.seeded(showOnly);

  @override
  int get hashCode => hashValues(showOnly.value, grouped.value, enabled.value);

  @override
  bool operator ==(dynamic o) =>
      o is HistoryDayOptions && o.hashCode == hashCode;
}

class ServicesListController
    implements BaseListController<Map<StudyYear?, List<Class>>, Class> {
  @override
  final BehaviorSubject<Map<StudyYear?, List<Class>>> _objectsData =
      BehaviorSubject();
  @override
  ValueStream<Map<StudyYear?, List<Class>>> get objectsData =>
      _objectsData.stream;
  @override
  Map<StudyYear?, List<Class>> get items => _objectsData.requireValue;

  @override
  StreamSubscription<Map<StudyYear?, List<Class>>>? _objectsDataListener;

  @override
  final BehaviorSubject<String> _searchQuery;
  @override
  BehaviorSubject<String> get searchQuery => _searchQuery;
  @override
  String? get searchQueryLatest => _searchQuery.value;

  @override
  StreamSubscription<String>? _searchQueryListener;

  @override
  final BehaviorSubject<bool> _selectionMode;
  @override
  bool get selectionModeLatest => _selectionMode.requireValue;
  @override
  BehaviorSubject<bool> get selectionMode => _selectionMode;

  @override
  final BehaviorSubject<Map<String, Class>> _selected;
  @override
  ValueStream<Map<String, Class>> get selected => _selected;
  @override
  Map<String, Class>? get selectedLatest => _selected.value;

  final Map<StudyYear?, List<Class>> Function(
      Map<StudyYear?, List<Class>>, String) _filter = (o, filter) {
    return {
      for (var it in o.entries.where(
        (e) =>
            filterString(e.key?.name ?? '').contains(filterString(filter)) ||
            e.value.any(
              (c) => filterString(c.name).contains(
                filterString(filter),
              ),
            ),
      ))
        it.key: it.value
    };
  };
  @override
  final void Function(Class)? tap;
  @override
  final void Function(Class)? onLongPress;

  @override
  Class? get empty => null;

  @override
  bool get showNull => false;

  ServicesListController({
    this.onLongPress,
    this.tap,
    List<Class>? selected,
    bool selectionMode = false,
    Stream<Map<StudyYear?, List<Class>>>? itemsStream,
    Map<StudyYear, List<Class>>? items,
    Stream<String>? searchQuery,
  })  : assert(itemsStream != null || items != null),
        _searchQuery = searchQuery != null
            ? BehaviorSubject<String>()
            : BehaviorSubject<String>.seeded(''),
        _selectionMode = BehaviorSubject<bool>.seeded(selectionMode),
        _selected = BehaviorSubject<Map<String, Class>>.seeded(
            {for (var item in selected ?? []) item.id: item}) {
//
    _searchQueryListener =
        searchQuery?.listen(_searchQuery.add, onError: _searchQuery.addError);

    _objectsDataListener = Rx.combineLatest2<String,
                Map<StudyYear?, List<Class>>, Map<StudyYear?, List<Class>>>(
            _searchQuery,
            itemsStream ?? BehaviorSubject.seeded(items!),
            (search, items) =>
                search.isNotEmpty ? _filter(items, search) : items)
        .listen(_objectsData.add, onError: _objectsData.addError);
  }

  @override
  void selectAll() {
    if (!_selectionMode.requireValue) _selectionMode.add(true);
    _selected.add({
      for (var item in items.values.expand((i) => i).toList()) item.id: item
    });
  }

  @override
  void selectNone() {
    if (!_selectionMode.requireValue) _selectionMode.add(true);
    _selected.add({});
  }

  @override
  void toggleSelected(Class item) {
    if (_selected.requireValue.containsKey(item.id)) {
      deselect(item);
    } else {
      select(item);
    }
  }

  @override
  void select(Class item) {
    _selected.add({..._selected.requireValue, item.id: item});
  }

  @override
  void deselect(Class item) {
    _selected.add(_selected.requireValue..remove(item.id));
  }

  @override
  Future<void> dispose() async {
    await _objectsDataListener?.cancel();
    if (!_objectsData.isClosed) await _objectsData.close();

    await _searchQueryListener?.cancel();
    if (!_searchQuery.isClosed) await _searchQuery.close();

    if (!_selected.isClosed) await _selected.close();
    if (!_selectionMode.isClosed) await _selectionMode.close();
  }
}

String filterString(String s) => s
    .toLowerCase()
    .replaceAll(
        RegExp(
          r'[أإآ]',
        ),
        'ا')
    .replaceAll('ى', 'ي');
