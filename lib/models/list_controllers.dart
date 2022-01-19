import 'dart:async';

import 'package:churchdata_core/churchdata_core.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:meetinghelper/models/data/user.dart';
import 'package:meetinghelper/utils/helpers.dart';
import 'package:rxdart/rxdart.dart';
import 'package:tuple/tuple.dart';

import 'data/class.dart';
import 'data/person.dart';
import 'history/history_record.dart';

class DayCheckListController<G, T extends Person> extends ListController<G, T> {
  final HistoryDayBase day;
  final String type;
  final HistoryDayOptions dayOptions;

  late final BehaviorSubject<Map<String, HistoryRecord>> _attended;
  ValueStream<Map<String, HistoryRecord>> get attended => _attended.stream;
  Map<String, HistoryRecord>? get attendedLatest => attended.valueOrNull;

  late final StreamSubscription<Map<String, HistoryRecord>>? _attendedListener;

  JsonCollectionRef? get ref => day.subcollection(type);

  final BehaviorSubject<Map<String, T>> _objectsById;
  late final StreamSubscription<Map<String, T>> _objectsByIdSubscription;

  DayCheckListController({
    required this.day,
    required this.type,
    required this.dayOptions,
    required PaginatableStream<T> query,
    Stream<String>? searchQuery,
    SearchFunction<T>? filter,
    GroupingFunction<G, T>? groupBy,
    GroupingStreamFunction<G, T>? groupByStream,
  })  : assert(dayOptions.grouped.value == false || groupBy != null),
        _attended = BehaviorSubject<Map<String, HistoryRecord>>(),
        _objectsById = BehaviorSubject<Map<String, T>>(),
        super(
          objectsPaginatableStream: query,
          searchStream: searchQuery,
          groupingStream: dayOptions.grouped,
          groupBy: groupBy,
          groupByStream: groupByStream,
          filter: filter ??
              (o, f) => o
                  .where((e) => filterString(e.name).contains(filterString(f)))
                  .toList(),
        ) {
    //

    _attendedListener = (ref != null
            ? Rx.combineLatest3<User?, List<G>, bool?,
                Tuple3<User?, List<G>, bool?>>(
                MHAuthRepository.I.userStream,
                notService(type)
                    ? Class.getAllForUser().map((c) => c.cast())
                    : Stream.value([]),
                dayOptions.sortByTimeASC,
                Tuple3.new,
              ).switchMap(_attendedMapping)
            : Stream.value(<String, HistoryRecord>{}))
        .listen(_attended.add, onError: _attended.addError);
  }

  ///Listens to [dayOptions.showTrueonly] then the [_searchQuery]
  ///to filter the [_objectsData] by the [attended] Persons
  @override
  StreamSubscription<List<T>> getObjectsSubscription(
      [Stream<String>? searchStream]) {
    _objectsByIdSubscription = objectsPaginatableStream.stream
        .map(
          (e) => {
            for (final i in e) i.id: i,
          },
        )
        .listen(_objectsById.add, onError: _objectsById.addError);

    return Rx.combineLatest5<bool?, bool?, String, Map<String, T>,
        Map<String, HistoryRecord>, List<T>>(
      dayOptions.showOnly,
      dayOptions.sortByTimeASC,
      searchSubject,
      _objectsById,
      _attended,
      _objectsFilteringMapping,
    ).listen(objectsSubject.add, onError: objectsSubject.addError);
  }

  List<T> _objectsFilteringMapping(
    bool? showOnly,
    bool? sortByTimeASC,
    String search,
    Map<String, T> objectsById,
    //TODO: we only need the keys
    Map<String, HistoryRecord> attended,
  ) {
    List<T> rslt = objectsById.values.toList();

    if (sortByTimeASC != null) {
      rslt = [
        for (final k in attended.keys)
          if (objectsById[k] != null) objectsById[k]!
      ];
    } else if (showOnly == null) {
      rslt = rslt.toList();
    } else if (showOnly == true) {
      rslt = objectsById.values
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
      return filter(rslt, search);
    }

    return rslt;
  }

  Stream<Map<String, HistoryRecord>> _attendedMapping(
      Tuple3<User?, List<G>, bool?> v) {
    //
    //<empty comment for readability>

    Map<String, HistoryRecord> _docsMapper(Iterable<JsonQueryDoc> docs) {
      final Map<String, T> tempSelected = {};

      JsonQueryDoc _select(JsonQueryDoc d) {
        if (objectsSubject.valueOrNull != null &&
            _objectsById.value[d.id] != null)
          tempSelected[d.id] = _objectsById.value[d.id]!;
        return d;
      }

      selectionSubject.add(tempSelected.values.toSet());

      return {
        for (final d in docs) _select(d).id: HistoryRecord.fromQueryDoc(d, day)
      };
    }

    final permissions = v.item1!.permissions;

    if (permissions.superAccess ||
        (day is ServantsHistoryDay && permissions.secretary) ||
        notService(type)) {
      if (v.item3 != null) {
        return ref!
            .orderBy('Time', descending: !v.item3!)
            .snapshots()
            .map<Map<String, HistoryRecord>>((s) => _docsMapper(s.docs));
      }
      return ref!
          .snapshots()
          .map<Map<String, HistoryRecord>>((s) => _docsMapper(s.docs));
    } else if (v.item2.length <= 10) {
      if (v.item3 != null) {
        return ref!
            .where('ClassId', whereIn: v.item2)
            .orderBy('Time', descending: !v.item3!)
            .snapshots()
            .map<Map<String, HistoryRecord>>((s) => _docsMapper(s.docs));
      }
      return ref!
          .where('ClassId', whereIn: v.item2)
          .snapshots()
          .map<Map<String, HistoryRecord>>((s) => _docsMapper(s.docs));
    }

    if (v.item3 != null) {
      return Rx.combineLatestList<JsonQuery>(v.item2.split(10).map((c) => ref!
          .where('ClassId', whereIn: c)
          .orderBy('Time', descending: !v.item3!)
          .snapshots())).map((s) => s.expand((n) => n.docs)).map(_docsMapper);
    }
    return Rx.combineLatestList<JsonQuery>(v.item2
            .split(10)
            .map((c) => ref!.where('ClassId', whereIn: c).snapshots()))
        .map((s) => s.expand((n) => n.docs))
        .map(_docsMapper);
  }

  @override
  Future<void> toggleSelected(T item, {String? notes, Timestamp? time}) async {
    if (selectionSubject.value?.contains(item) ?? false) {
      await deselect(item);
    } else {
      await select(item, notes: notes, time: time);
    }
  }

  @override
  Future<void> select(T object, {String? notes, Timestamp? time}) async {
    await HistoryRecord(
      type: type,
      parent: day,
      id: object.id,
      studyYear: object.studyYear,
      classId: object.classId,
      services: type == 'Meeting' || type == 'Kodas' || type == 'Confession'
          ? object.services
          : [GetIt.I<DatabaseRepository>().collection('Services').doc(type)],
      time: time ?? day.day.toDate().replaceTime(DateTime.now()).toTimestamp(),
      recordedBy: MHAuthRepository.I.currentUser!.uid,
      notes: notes,
      isServant: T == User,
    ).set();
  }

  @override
  Future<void> deselect(T object) async {
    await ref!.doc(object.id).delete();
  }

  Future<void> modifySelected(T item, {String? notes, Timestamp? time}) async {
    assert(selectionSubject.value?.contains(item) ?? false);

    await HistoryRecord(
      type: type,
      parent: day,
      id: item.id,
      studyYear: item.studyYear,
      classId: item.classId,
      services: type == 'Meeting' || type == 'Kodas' || type == 'Confession'
          ? item.services
          : [GetIt.I<DatabaseRepository>().collection('Services').doc(type)],
      time: time ?? day.day.toDate().replaceTime(DateTime.now()).toTimestamp(),
      recordedBy: MHAuthRepository.I.currentUser!.uid,
      notes: notes,
      isServant: T == User,
    ).update();
  }

  DayCheckListController<G, T> copyWith({
    Stream<Map<JsonRef, Tuple2<G, List<T>>>> Function(List<T?> data)? groupBy,
    HistoryDay? day,
    String? type,
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
    //TODO: implement copyWith
    throw UnimplementedError();
    /* return HistoryDayCheckList<T, P>(
      groupBy: groupBy ?? _groupBy,
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
    ); */
  }

  @override
  Future<void> dispose() async {
    await super.dispose();

    await _attendedListener?.cancel();
    if (!_attended.isClosed) await _attended.close();

    await _objectsByIdSubscription.cancel();
    if (!_objectsById.isClosed) await _objectsById.close();
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
  bool operator ==(dynamic other) =>
      other is HistoryDayOptions && other.hashCode == hashCode;
}

/// BaseListController<Map<PreferredStudyYear?, List<Class | Service>>, Class | Service>
class ServicesListController<T extends DataObject>
    extends ListController<PreferredStudyYear?, T> {
  Map<PreferredStudyYear?, List<T>> _filterWithGroups(
      Map<PreferredStudyYear?, List<T>> o, String filter) {
    return Map.fromEntries(
      o.entries.where(
        (e) =>
            filterString(e.key?.name ?? '').contains(filterString(filter)) ||
            e.value.any(
              (c) => filterString(c.name).contains(
                filterString(filter),
              ),
            ),
      ),
    );
  }

  ServicesListController({
    required PaginatableStream<T> objectsPaginatableStream,
    GroupingFunction<PreferredStudyYear?, T>? groupBy,
    GroupingStreamFunction<PreferredStudyYear?, T>? groupByStream,
    BehaviorSubject<String>? searchQuery,
  })  : assert(
            isSubtype<Class, T>() || isSubtype<Class, T>() || T == DataObject),
        super(
          objectsPaginatableStream: objectsPaginatableStream,
          searchStream: searchQuery,
          groupBy: groupBy,
          groupByStream: groupByStream,
          groupingStream: Stream.value(true),
        );

  @override
  StreamSubscription<List<T>> getObjectsSubscription(
      [Stream<String>? searchStream]) {
    return Rx.combineLatest2<String, List<T>, List<T>>(
      searchSubject,
      objectsPaginatableStream.stream,
      (search, items) =>
          search.isNotEmpty ? defaultSearch<T>(items, search) : items,
    ).listen(objectsSubject.add, onError: objectsSubject.addError);
  }

  @override
  StreamSubscription<Map<PreferredStudyYear?, List<T>>>
      getGroupedObjectsSubscription() {
    if (groupByStream != null)
      return groupingSubject
          .switchMap(
            (g) => g
                ? Rx.combineLatest3<
                    String,
                    Set<PreferredStudyYear?>,
                    Map<PreferredStudyYear?, List<T>>,
                    Map<PreferredStudyYear?, List<T>>>(
                    searchSubject,
                    openedGroupsSubject!,
                    objectsPaginatableStream.stream.switchMap(groupByStream!),
                    (search, groups, objects) => search.isNotEmpty
                        ? _filterWithGroups(
                            objects.map(
                              (k, v) => MapEntry(
                                k,
                                groups.contains(k) ? v : [],
                              ),
                            ),
                            search,
                          )
                        : objects.map(
                            (k, v) => MapEntry(
                              k,
                              groups.contains(k) ? v : [],
                            ),
                          ),
                  )
                : Stream.value(<PreferredStudyYear?, List<T>>{}),
          )
          .listen(groupedObjectsSubject.add,
              onError: groupedObjectsSubject.addError);

    return Rx.combineLatest4<bool, String, List<T>, Set<PreferredStudyYear?>,
        Map<PreferredStudyYear?, List<T>>>(
      groupingSubject,
      searchSubject,
      objectsPaginatableStream.stream,
      openedGroupsSubject!,
      (grouping, search, objects, groups) => grouping
          ? groupBy!(objects).map(
              (k, v) => MapEntry(
                k,
                groups.contains(k) ? v : [],
              ),
            )
          : {},
    ).listen(groupedObjectsSubject.add,
        onError: groupedObjectsSubject.addError);
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
