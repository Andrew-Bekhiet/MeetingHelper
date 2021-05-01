import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
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

abstract class BaseListOptions<L, U> {
  final BehaviorSubject<L> _objectsData;
  BehaviorSubject<L> get objectsData => _objectsData;
  L get items => _objectsData.value;

  final BehaviorSubject<bool> _selectionMode;
  BehaviorSubject<bool> get selectionMode => _selectionMode;
  bool get selectionModeLatest => _selectionMode.value;

  final BehaviorSubject<Map<String, U>> _selected;
  BehaviorSubject<Map<String, U>> get selected => _selected;
  Map<String, U> get selectedLatest => _selected.value;

  final void Function(U) tap;
  final void Function(U) onLongPress;

  final U empty;
  final bool showNull;

  void selectAll();
  void selectNone() {
    if (!_selectionMode.value) _selectionMode.add(true);
    _selected.add({});
  }

  void toggleSelected(U item);

  void select(U item);

  void deselect(U item);

  BaseListOptions({
    this.onLongPress,
    this.tap,
    this.empty,
    this.showNull = false,
    bool selectionMode = false,
    Stream<L> itemsStream,
    L items,
    Map<String, U> selected,
  })  : assert(itemsStream != null || items != null),
        assert(showNull == false || (showNull == true && empty != null)),
        _selectionMode = BehaviorSubject<bool>.seeded(selectionMode),
        _selected = BehaviorSubject<Map<String, U>>.seeded(selected ?? {}),
        _objectsData = itemsStream != null
            ? (BehaviorSubject<L>()..addStream(itemsStream))
            : BehaviorSubject<L>.seeded(items);
}

class DataObjectListOptions<T extends DataObject>
    implements BaseListOptions<List<T>, T> {
  @override
  BehaviorSubject<List<T>> _objectsData;
  @override
  BehaviorSubject<List<T>> get objectsData => _objectsData;
  @override
  List<T> get items => objectsData.value;

  final BehaviorSubject<Map<String, T>> originalObjectsData;

  @override
  final BehaviorSubject<bool> _selectionMode;
  @override
  BehaviorSubject<bool> get selectionMode => _selectionMode;
  @override
  bool get selectionModeLatest => _selectionMode.value;

  @override
  final BehaviorSubject<Map<String, T>> _selected;
  @override
  BehaviorSubject<Map<String, T>> get selected => _selected;
  @override
  Map<String, T> get selectedLatest => _selected.value;

  final BehaviorSubject<String> _searchQuery;
  BehaviorSubject<String> get searchQuery => _searchQuery;
  String get searchQueryLatest => _searchQuery.value;

  final List<T> Function(List<T>, String) _filter;
  @override
  final void Function(T) tap;
  @override
  final void Function(T) onLongPress;

  @override
  final T empty;
  @override
  final bool showNull;

  final Widget Function(T,
      {void Function(T) onLongPress,
      void Function(T) onTap,
      Widget trailing,
      Widget subtitle}) itemBuilder;

  DataObjectListOptions({
    Widget Function(T,
            {void Function(T) onLongPress,
            void Function(T) onTap,
            Widget trailing,
            Widget subtitle})
        itemBuilder,
    this.onLongPress,
    this.tap,
    this.empty,
    this.showNull = false,
    bool selectionMode = false,
    Stream<List<T>> itemsStream,
    List<T> items,
    Map<String, T> selected,
    @required Stream<String> searchQuery,
    List<T> Function(List<T>, String) filter,
  })  : assert(itemsStream != null || items != null),
        assert(showNull == false || (showNull == true && empty != null)),
        assert(searchQuery != null),
        _filter = (filter ??
            (o, f) =>
                o.where((e) => filterString(e.name).contains(f)).toList()),
        _searchQuery = BehaviorSubject<String>()..addStream(searchQuery),
        _selected = BehaviorSubject<Map<String, T>>.seeded(selected ?? {}),
        _selectionMode = BehaviorSubject<bool>.seeded(selectionMode),
        originalObjectsData = itemsStream != null
            ? (BehaviorSubject<Map<String, T>>()
              ..addStream(itemsStream.map((l) => {for (final o in l) o.id: o})))
            : BehaviorSubject<Map<String, T>>.seeded(
                {for (final o in items) o.id: o}),
        itemBuilder = itemBuilder ??
            ((i,
                    {void Function(T) onLongPress,
                    void Function(T) onTap,
                    Widget trailing,
                    Widget subtitle}) =>
                DataObjectWidget<T>(i,
                    subtitle: subtitle,
                    onLongPress:
                        onLongPress != null ? () => onLongPress(i) : null,
                    onTap: onTap != null ? () => onTap(i) : null,
                    trailing: trailing)) {
    _objectsData = (showNull
        ? BehaviorSubject<List<T>>.seeded([empty])
        : BehaviorSubject<List<T>>())
      ..addStream(Rx.combineLatest2<String, Map<String, T>, List<T>>(
          _searchQuery,
          originalObjectsData,
          (search, items) => search.isNotEmpty
              ? _filter(items.values.toList(), search)
              : items.values.toList()));
  }

  @override
  void selectAll() {
    if (!_selectionMode.value) _selectionMode.add(true);
    _selected.add({for (var item in items ?? []) item.id: item});
  }

  @override
  void selectNone() {
    if (!_selectionMode.value) _selectionMode.add(true);
    _selected.add({});
  }

  @override
  void toggleSelected(T item) {
    if (_selected.value.containsKey(item.id)) {
      deselect(item);
    } else {
      select(item);
    }
  }

  @override
  void select(T item) {
    assert(!_selected.value.containsKey(item.id));
    _selected.add({..._selected.value, item.id: item});
  }

  @override
  void deselect(T item) {
    assert(_selected.value.containsKey(item.id));
    _selected.add(_selected.value..remove(item.id));
  }
}

class CheckListOptions<T extends Person> implements DataObjectListOptions<T> {
  final HistoryDay day;
  final DayListType type;
  final HistoryDayOptions dayOptions;

  @override
  BehaviorSubject<List<T>> _objectsData;
  @override
  BehaviorSubject<List<T>> get objectsData => _objectsData;
  @override
  List<T> get items => objectsData.value;

  @override
  final BehaviorSubject<Map<String, T>> originalObjectsData;

  @override
  final BehaviorSubject<bool> _selectionMode;
  @override
  BehaviorSubject<bool> get selectionMode => _selectionMode;

  @override
  final BehaviorSubject<Map<String, T>> _selected;
  @override
  BehaviorSubject<Map<String, T>> get selected => _selected;
  @override
  Map<String, T> get selectedLatest => _selected.value;

  @override
  final BehaviorSubject<String> _searchQuery;
  @override
  BehaviorSubject<String> get searchQuery => _searchQuery;
  @override
  String get searchQueryLatest => _searchQuery.value;

  @override
  final List<T> Function(List<T>, String) _filter;
  @override
  final void Function(T) tap;
  @override
  final void Function(T) onLongPress;

  @override
  T get empty => null;
  @override
  bool get showNull => false;

  @override
  final Widget Function(T,
      {void Function(T) onLongPress,
      void Function(T) onTap,
      Widget trailing,
      Widget subtitle}) itemBuilder;

  CheckListOptions({
    this.getGroupedData,
    this.day,
    this.type,
    this.dayOptions,
    Widget Function(T,
            {void Function(T) onLongPress,
            void Function(T) onTap,
            Widget trailing,
            Widget subtitle})
        itemBuilder,
    this.tap,
    this.onLongPress,
    List<T> Function(List<T>, String) filter,
    Stream<List<T>> itemsStream,
    Stream<Map<String, T>> itemsMapStream,
    List<T> items,
    Map<String, T> selected,
    @required Stream<String> searchQuery,
  })  : assert(dayOptions.grouped.value == false || getGroupedData != null),
        assert(itemsMapStream != null || itemsStream != null || items != null),
        assert(searchQuery != null),
        _filter = (filter ??
            (o, f) =>
                o.where((e) => filterString(e.name).contains(f)).toList()),
        _searchQuery = BehaviorSubject<String>()..addStream(searchQuery),
        _selected = BehaviorSubject<Map<String, T>>.seeded(selected ?? {}),
        _selectionMode = BehaviorSubject<bool>.seeded(true),
        originalObjectsData = itemsMapStream ??
            (itemsStream != null
                ? (BehaviorSubject<Map<String, T>>()
                  ..addStream(
                      itemsStream.map((l) => {for (final o in l) o.id: o})))
                : BehaviorSubject<Map<String, T>>.seeded(
                    {for (final o in items) o.id: o})),
        itemBuilder = itemBuilder ??
            ((i,
                    {void Function(T) onLongPress,
                    void Function(T) onTap,
                    Widget trailing,
                    Widget subtitle}) =>
                DataObjectWidget<T>(i,
                    subtitle: subtitle,
                    onLongPress:
                        onLongPress != null ? () => onLongPress(i) : null,
                    onTap: onTap != null ? () => onTap(i) : null,
                    trailing: trailing)) {
    attended = BehaviorSubject<Map<String, HistoryRecord>>()
      ..addStream(ref != null
          ? Rx.combineLatest2(User.instance.stream, Class.getAllForUser(),
              (a, b) => Tuple2<User, List<Class>>(a, b)).switchMap((v) {
              if (v.item1.superAccess ||
                  (day is ServantsHistoryDay && v.item1.secretary)) {
                return ref
                    .orderBy('Time')
                    .snapshots()
                    .map<Map<String, HistoryRecord>>((s) {
                  Map<String, T> tempSelected = {};
                  Map<String, HistoryRecord> snapshotMap =
                      Map<String, HistoryRecord>.fromIterable(
                    s.docs,
                    key: (d) {
                      if (originalObjectsData.value != null)
                        tempSelected[d.id] = originalObjectsData.value[d.id];
                      return d.id;
                    },
                    value: (d) => HistoryRecord.fromDoc(day, d),
                  );
                  _selected.add(tempSelected);
                  return snapshotMap;
                });
              } else if (v.item2.length <= 10) {
                return ref
                    .where('ClassId',
                        whereIn: v.item2.map((e) => e.ref).toList())
                    .orderBy('Time')
                    .snapshots()
                    .map((s) {
                  Map<String, T> tempSelected = {};
                  Map<String, HistoryRecord> snapshotMap =
                      Map<String, HistoryRecord>.fromIterable(
                    s.docs,
                    key: (d) {
                      if (originalObjectsData.value != null)
                        tempSelected[d.id] = originalObjectsData.value[d.id];
                      return d.id;
                    },
                    value: (d) => HistoryRecord.fromDoc(day, d),
                  );
                  _selected.add(tempSelected);
                  return snapshotMap;
                });
              }
              return Rx.combineLatestList<QuerySnapshot>(v.item2.split(10).map(
                  (c) => ref
                      .where('ClassId', whereIn: c.map((e) => e.ref).toList())
                      .orderBy('Time')
                      .snapshots())).map((s) => s.expand((n) => n.docs)).map(
                  (s) {
                Map<String, T> tempSelected = {};
                Map<String, HistoryRecord> snapshotMap =
                    Map<String, HistoryRecord>.fromIterable(
                  s,
                  key: (d) {
                    if (originalObjectsData.value != null)
                      tempSelected[d.id] = originalObjectsData.value[d.id];
                    return d.id;
                  },
                  value: (d) => HistoryRecord.fromDoc(day, d),
                );
                _selected.add(tempSelected);
                return snapshotMap;
              });
            })
          : Stream.value({}));

    ///Listens to [dayOptions.showTrueonly] then the [_searchQuery]
    ///to filter the [_objectsData] by the [attended] Persons
    _objectsData = BehaviorSubject<List<T>>()
      ..addStream(
        Rx.combineLatest5<bool, bool, String, Map<String, T>,
            Map<String, HistoryRecord>, List<T>>(
          dayOptions.showOnly,
          dayOptions.sortByTimeASC,
          _searchQuery,
          originalObjectsData,
          attended,
          (showOnly, sortByTimeASC, search, objects, attended) {
            List<T> rslt = objects.values.toList();

            if (sortByTimeASC == true) {
              rslt = attended
                  .map((k, v) => MapEntry(k, objects[k]))
                  .values
                  .toList();
            } else if (sortByTimeASC == false) {
              rslt = attended
                  .map((k, v) => MapEntry(k, objects[k]))
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
          },
        ),
      );
  }

  BehaviorSubject<Map<String, HistoryRecord>> attended;

  CollectionReference get ref => day.collections[type];

  @override
  bool get selectionModeLatest => true;

  @override
  void selectAll() {
    throw UnimplementedError();
  }

  @override
  void selectNone() {
    throw UnimplementedError();
  }

  @override
  Future<void> toggleSelected(T item, {String notes, Timestamp time}) async {
    if (_selected.value.containsKey(item.id)) {
      await deselect(item);
    } else {
      await select(item, notes: notes, time: time);
    }
  }

  @override
  Future<void> select(T item, {String notes, Timestamp time}) async {
    await HistoryRecord(
            type: type,
            parent: day,
            id: item.id,
            classId: item.classId,
            time: time ?? Timestamp.now(),
            recordedBy: User.instance.uid,
            notes: notes,
            isServant: T == User)
        .set();
  }

  @override
  Future<void> deselect(T item) async {
    await ref.doc(item.id).delete();
  }

  Future<void> modifySelected(T item, {String notes, Timestamp time}) async {
    assert(_selected.value.containsKey(item.id));
    await HistoryRecord(
            type: type,
            parent: day,
            id: item.id,
            classId: item.classId,
            time: time ?? Timestamp.now(),
            recordedBy: User.instance.uid,
            notes: notes,
            isServant: T == User)
        .update();
  }

  CheckListOptions<T> copyWith({
    Stream<Map<DocumentReference, Tuple2<Class, List<T>>>> Function(
            List<T> data)
        getGroupedData,
    HistoryDay day,
    DayListType type,
    HistoryDayOptions dayOptions,
    Widget Function(T,
            {void Function(T) onLongPress,
            void Function(T) onTap,
            Widget trailing,
            Widget subtitle})
        itemBuilder,
    void Function(T) onLongPress,
    void Function(T) tap,
    Stream<List<T>> itemsStream,
    List<T> items,
    Map<String, T> selected,
    Stream<String> searchQuery,
  }) {
    return CheckListOptions<T>(
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

  final Stream<Map<DocumentReference, Tuple2<Class, List<T>>>> Function(
      List<T> data) getGroupedData;
}

class HistoryDayOptions {
  final BehaviorSubject<bool> grouped;
  //show Only absent (false) or present (true) Persons
  final BehaviorSubject<bool> showOnly;
  final BehaviorSubject<bool> sortByTimeASC;
  //true -> ASC, false -> DESC, null -> sort by name
  final BehaviorSubject<bool> enabled;
  final BehaviorSubject<bool> showSubtitlesInGroups;

  HistoryDayOptions(
      {bool grouped,
      bool showOnly,
      bool sortByTimeDESC,
      bool enabled,
      bool showSubtitlesInGroups})
      : enabled = BehaviorSubject<bool>.seeded(enabled ?? false),
        grouped = BehaviorSubject<bool>.seeded(grouped ?? false),
        showSubtitlesInGroups =
            BehaviorSubject<bool>.seeded(showSubtitlesInGroups ?? false),
        sortByTimeASC = BehaviorSubject<bool>.seeded(sortByTimeDESC),
        showOnly = BehaviorSubject<bool>.seeded(showOnly);

  @override
  int get hashCode => hashValues(showOnly.value, grouped.value, enabled.value);

  @override
  bool operator ==(dynamic o) =>
      o is HistoryDayOptions && o.hashCode == hashCode;
}

class ServicesListOptions
    implements BaseListOptions<Map<StudyYear, List<Class>>, Class> {
  @override
  BehaviorSubject<Map<StudyYear, List<Class>>> _objectsData;
  @override
  BehaviorSubject<Map<StudyYear, List<Class>>> get objectsData => _objectsData;
  @override
  Map<StudyYear, List<Class>> get items => _objectsData.value;

  final BehaviorSubject<String> _searchQuery;
  BehaviorSubject<String> get searchQuery => _searchQuery;
  String get searchQueryLatest => _searchQuery.value;

  @override
  final BehaviorSubject<bool> _selectionMode;
  @override
  bool get selectionModeLatest => _selectionMode.value;
  @override
  BehaviorSubject<bool> get selectionMode => _selectionMode;

  @override
  final BehaviorSubject<Map<String, Class>> _selected;
  @override
  BehaviorSubject<Map<String, Class>> get selected => _selected;
  @override
  Map<String, Class> get selectedLatest => _selected.value;

  final Map<StudyYear, List<Class>> Function(
      Map<StudyYear, List<Class>>, String) _filter = (o, filter) {
    return {
      for (var it in o.entries.where(
        (e) =>
            filterString(e.key.name).contains(filterString(filter)) ||
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
  final void Function(Class) tap;
  @override
  final void Function(Class) onLongPress;

  @override
  Class get empty => null;

  @override
  bool get showNull => false;

  ServicesListOptions({
    this.onLongPress,
    this.tap,
    List<Class> selected,
    bool selectionMode = false,
    Stream<Map<StudyYear, List<Class>>> itemsStream,
    Map<StudyYear, List<Class>> items,
    @required Stream<String> searchQuery,
  })  : assert(itemsStream != null || items != null),
        assert(searchQuery != null),
        _searchQuery = BehaviorSubject<String>()..addStream(searchQuery),
        _selectionMode = BehaviorSubject<bool>.seeded(selectionMode),
        _selected = BehaviorSubject<Map<String, Class>>.seeded(
            {for (var item in selected ?? []) item.id: item}) {
    _objectsData = BehaviorSubject()
      ..addStream(Rx.combineLatest2<String, Map<StudyYear, List<Class>>,
              Map<StudyYear, List<Class>>>(
          _searchQuery,
          itemsStream != null
              ? (BehaviorSubject<Map<StudyYear, List<Class>>>()
                ..addStream(itemsStream))
              : BehaviorSubject<Map<StudyYear, List<Class>>>.seeded(items),
          (search, items) =>
              search.isNotEmpty ? _filter(items, search) : items));
  }

  @override
  void selectAll() {
    if (!_selectionMode.value) _selectionMode.add(true);
    _selected.add({
      for (var item in items.values.expand((i) => i).toList()) item.id: item
    });
  }

  @override
  void selectNone() {
    if (!_selectionMode.value) _selectionMode.add(true);
    _selected.add({});
  }

  @override
  void toggleSelected(Class item) {
    if (_selected.value.containsKey(item.id)) {
      deselect(item);
    } else {
      select(item);
    }
  }

  @override
  void select(Class item) {
    _selected.add({..._selected.value, item.id: item});
  }

  @override
  void deselect(Class item) {
    _selected.add(_selected.value..remove(item.id));
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
