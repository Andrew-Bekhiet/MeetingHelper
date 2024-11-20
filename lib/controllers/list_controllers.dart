import 'dart:async';

import 'package:churchdata_core/churchdata_core.dart';
import 'package:get_it/get_it.dart';
import 'package:meetinghelper/models.dart';
import 'package:meetinghelper/repositories.dart';
import 'package:meetinghelper/utils/helpers.dart';
import 'package:rxdart/rxdart.dart';
import 'package:tuple/tuple.dart';

class DayCheckListController<G, T extends Person> extends ListController<G, T> {
  bool _isDisposing = false;

  final HistoryDayBase day;
  final String type;
  final HistoryDayOptions dayOptions;

  late final BehaviorSubject<Map<String, HistoryRecord>> _attended;
  ValueStream<Map<String, HistoryRecord>> get attended => _attended.stream;
  Map<String, HistoryRecord>? get currentAttended => attended.valueOrNull;

  @override
  BehaviorSubject<Set<T>?> get selectionSubject {
    if (_isDisposing) return BehaviorSubject.seeded(null);
    final BehaviorSubject<Set<T>?> result = BehaviorSubject();

    _attended
        .map(
          (v) => ListControllerBase.setWrapper<T>({
            for (final i in v.keys) _objectsById.value[i]!,
          }),
        )
        .listen(result.add, onError: result.addError, onDone: result.close);

    return result;
  }

  late final StreamSubscription<Map<String, HistoryRecord>>? _attendedListener;

  JsonCollectionRef? get ref => day.subcollection(type);

  final BehaviorSubject<Map<String, T>> _objectsById;
  late final StreamSubscription<Map<String, T>> _objectsByIdSubscription;

  @override
  PaginatableStream<T> get objectsPaginatableStream =>
      super.objectsPaginatableStream as PaginatableStream<T>;

  DayCheckListController({
    required this.day,
    required this.type,
    required this.dayOptions,
    required PaginatableStream<T> query,
    Stream<String>? searchQuery,
    super.filter,
    super.groupBy,
    super.groupByStream,
  })  : assert(
          !dayOptions.grouped.value || groupBy != null || groupByStream != null,
        ),
        _attended = BehaviorSubject<Map<String, HistoryRecord>>(),
        _objectsById = BehaviorSubject<Map<String, T>>(),
        super(
          objectsPaginatableStream: query,
          searchStream: searchQuery,
          groupingStream: dayOptions.grouped,
        ) {
    //

    _attendedListener = (ref != null
            ? Rx.combineLatest3<User, List<G>, bool?,
                Tuple3<User, List<G>, bool?>>(
                User.loggedInStream,
                notService(type)
                    ? MHDatabaseRepo.I.classes.getAll().map((c) => c.cast<G>())
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
  StreamSubscription<List<T>> getObjectsSubscription([
    Stream<String>? searchStream,
  ]) {
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
    Map<String, HistoryRecord> attended,
  ) {
    List<T> rslt = objectsById.values.toList();

    if (sortByTimeASC != null) {
      rslt = [
        for (final k in attended.keys)
          if (objectsById[k] != null) objectsById[k]!,
      ];
    } else if (showOnly == null) {
      rslt = rslt.toList();
    } else if (showOnly) {
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
    Tuple3<User, List<G>, bool?> v,
  ) {
    //
    //<empty comment for readability>

    Map<String, HistoryRecord> _docsMapper(Iterable<JsonQueryDoc> docs) {
      final Map<String, T> tempSelected = {};
      final Map<String, HistoryRecord> tempResult = {};

      for (final d in docs) {
        if (_objectsById.valueOrNull != null &&
            _objectsById.value[d.id] != null) {
          tempSelected[d.id] = _objectsById.value[d.id]!;
        }
        tempResult[d.id] = HistoryRecord.fromQueryDoc(d, day);
      }

      return tempResult;
    }

    final permissions = v.item1.permissions;

    if (permissions.superAccess ||
        (day is ServantsHistoryDay && permissions.secretary) ||
        !notService(type)) {
      if (v.item3 != null) {
        return ref!
            .orderBy('Time', descending: !v.item3!)
            .snapshots()
            .map((s) => _docsMapper(s.docs));
      }
      return ref!.snapshots().map((s) => _docsMapper(s.docs));
    } else if (v.item2.length <= 30) {
      if (v.item3 != null && v.item2.isEmpty) {
        return ref!
            .orderBy('Time', descending: !v.item3!)
            .snapshots()
            .map((s) => _docsMapper(s.docs));
      } else if (v.item3 != null) {
        return ref!
            .where(
              'ClassId',
              whereIn: v.item2
                  .whereType<DocumentObject>()
                  .map((e) => e.ref)
                  .toList(),
            )
            .orderBy('Time', descending: !v.item3!)
            .snapshots()
            .map((s) => _docsMapper(s.docs));
      } else if (v.item2.isEmpty) {
        return ref!.snapshots().map((s) => _docsMapper(s.docs));
      } else {
        return ref!
            .where(
              'ClassId',
              whereIn: v.item2
                  .whereType<DocumentObject>()
                  .map((e) => e.ref)
                  .toList(),
            )
            .snapshots()
            .map((s) => _docsMapper(s.docs));
      }
    }

    if (v.item3 != null) {
      return Rx.combineLatestList<JsonQuery>(
        v.item2.split(30).map(
              (c) => ref!
                  .where(
                    'ClassId',
                    whereIn: c
                        .whereType<DocumentObject>()
                        .map((e) => e.ref)
                        .toList(),
                  )
                  .orderBy('Time', descending: !v.item3!)
                  .snapshots(),
            ),
      ).map((s) => s.expand((n) => n.docs)).map(_docsMapper);
    }
    return Rx.combineLatestList<JsonQuery>(
      v.item2.split(30).map(
            (c) => ref!
                .where(
                  'ClassId',
                  whereIn:
                      c.whereType<DocumentObject>().map((e) => e.ref).toList(),
                )
                .snapshots(),
          ),
    ).map((s) => s.expand((n) => n.docs)).map(_docsMapper);
  }

  @override
  Future<void> toggleSelected(T item, {String? notes, Timestamp? time}) async {
    if (_attended.value.containsKey(item.id)) {
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
      services: notService(type)
          ? object.services
          : [GetIt.I<DatabaseRepository>().collection('Services').doc(type)],
      time: time ?? day.day.toDate().replaceTime(DateTime.now()).toTimestamp(),
      recordedBy: User.instance.uid,
      notes: notes,
      isServant: T == User,
    ).set();
  }

  @override
  Future<void> deselect(T object) async {
    await ref!.doc(object.id).delete();
  }

  Future<void> modifySelected(T item, {String? notes, Timestamp? time}) async {
    assert(_attended.value.containsKey(item.id));

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
      recordedBy: User.instance.uid,
      notes: notes,
      isServant: T == User,
    ).update();
  }

  @override
  void selectAll([List<T>? objects]) {
    throw UnsupportedError('Cannot select all');
  }

  @override
  void deselectAll([List<T>? objects]) {
    throw UnsupportedError('Cannot deselect all');
  }

  @override
  void exitSelectionMode() {
    throw UnsupportedError('Cannot exit selection mode');
  }

  @override
  void enterSelectionMode() {
    throw UnsupportedError('Cannot enter selection mode');
  }

  DayCheckListController<G, T> copyWith({
    PaginatableStream<T>? objectsPaginatableStream,
    Stream<String>? searchStream,
    SearchFunction<T>? filter,
    GroupingFunction<G, T>? groupBy,
    HistoryDayBase? day,
    String? type,
    HistoryDayOptions? dayOptions,
    Stream<String>? searchQuery,
    GroupingStreamFunction<G, T>? groupByStream,
  }) {
    return DayCheckListController<G, T>(
      day: day ?? this.day,
      dayOptions: dayOptions ?? this.dayOptions,
      query: objectsPaginatableStream ?? this.objectsPaginatableStream,
      type: type ?? this.type,
      filter: filter ?? this.filter,
      groupBy: groupBy ?? this.groupBy,
      groupByStream: groupByStream ?? this.groupByStream,
      searchQuery: searchQuery ?? searchSubject,
    );
  }

  @override
  DayCheckListController<NewG, T> copyWithNewG<NewG>({
    covariant PaginatableStream<T>? objectsPaginatableStream,
    Stream<String>? searchStream,
    SearchFunction<T>? filter,
    GroupingFunction<NewG, T>? groupBy,
    HistoryDayBase? day,
    String? type,
    HistoryDayOptions? dayOptions,
    Stream<String>? searchQuery,
    GroupingStreamFunction<NewG, T>? groupByStream,
  }) {
    if (this.groupBy != null && groupBy == null) {
      throw UnsupportedError(
        '`groupBy` must be provided if this.groupBy != null',
      );
    }
    if (this.groupByStream != null && groupByStream == null) {
      throw UnsupportedError(
        '`groupByStream` must be provided if this.groupByStream != null',
      );
    }

    return DayCheckListController<NewG, T>(
      day: day ?? this.day,
      dayOptions: dayOptions ?? this.dayOptions,
      query: objectsPaginatableStream ?? this.objectsPaginatableStream,
      type: type ?? this.type,
      filter: filter ?? this.filter,
      groupBy: groupBy,
      groupByStream: groupByStream,
      searchQuery: searchQuery ?? searchSubject,
    );
  }

  DayCheckListController<NewG, NewT>
      copyWithNewTypes<NewG, NewT extends Person>({
    required PaginatableStream<NewT> objectsPaginatableStream,
    HistoryDayBase? day,
    String? type,
    HistoryDayOptions? dayOptions,
    Stream<String>? searchQuery,
    SearchFunction<NewT>? filter,
    GroupingFunction<NewG, NewT>? groupBy,
    GroupingStreamFunction<NewG, NewT>? groupByStream,
  }) {
    return DayCheckListController<NewG, NewT>(
      day: day ?? this.day,
      dayOptions: dayOptions ?? this.dayOptions,
      query: objectsPaginatableStream,
      type: type ?? this.type,
      filter: filter,
      groupBy: groupBy,
      groupByStream: groupByStream,
      searchQuery: searchQuery ?? searchSubject,
    );
  }

  @override
  Future<void> dispose() async {
    _isDisposing = true;
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
  //true -> ASC, false -> DESC, null -> sort by name
  final BehaviorSubject<bool?> sortByTimeASC;
  final BehaviorSubject<bool> enabled;
  final BehaviorSubject<bool> showSubtitlesInGroups;
  final BehaviorSubject<bool> lockUnchecks;

  HistoryDayOptions({
    bool grouped = false,
    bool? showOnly,
    bool? sortByTimeASC,
    bool enabled = false,
    bool lockUnchecks = true,
    bool showSubtitlesInGroups = false,
  })  : enabled = BehaviorSubject<bool>.seeded(enabled),
        grouped = BehaviorSubject<bool>.seeded(grouped),
        showSubtitlesInGroups =
            BehaviorSubject<bool>.seeded(showSubtitlesInGroups),
        sortByTimeASC = BehaviorSubject<bool?>.seeded(sortByTimeASC),
        lockUnchecks = BehaviorSubject<bool>.seeded(lockUnchecks),
        showOnly = BehaviorSubject<bool?>.seeded(showOnly);

  @override
  int get hashCode => Object.hash(showOnly.value, grouped.value, enabled.value);

  @override
  bool operator ==(Object other) =>
      other is HistoryDayOptions && other.hashCode == hashCode;
}

/// BaseListController<Map<PreferredStudyYear?, List<Class | Service>>, Class | Service>
class ServicesListController<T extends DataObject>
    extends ListController<PreferredStudyYear?, T> {
  Map<PreferredStudyYear?, List<T>> _filterWithGroups(
    Map<PreferredStudyYear?, List<T>> o,
    String filter,
  ) {
    return Map.fromEntries(
      o.entries.where(
        (e) =>
            (e.key?.name ?? '')
                .normalizeForSearch()
                .contains(filter.normalizeForSearch()) ||
            e.value.any(
              (c) => c.name
                  .normalizeForSearch()
                  .contains(filter.normalizeForSearch()),
            ),
      ),
    );
  }

  ServicesListController({
    required super.objectsPaginatableStream,
    super.groupBy,
    super.groupByStream,
    BehaviorSubject<String>? searchQuery,
  })  : assert(
          isSubtype<T, Class>() || isSubtype<T, Service>() || T == DataObject,
        ),
        super(
          searchStream: searchQuery,
          groupingStream: Stream.value(true),
        );

  @override
  StreamSubscription<List<T>> getObjectsSubscription([
    Stream<String>? searchStream,
  ]) {
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
    if (groupByStream != null) {
      return groupingSubject
          .switchMap(
            (g) => g
                ? Rx.combineLatest2<String, Map<PreferredStudyYear?, List<T>>,
                    Map<PreferredStudyYear?, List<T>>>(
                    searchSubject,
                    objectsPaginatableStream.stream.switchMap(groupByStream!),
                    (search, objects) => search.isNotEmpty
                        ? _filterWithGroups(
                            objects,
                            search,
                          )
                        : objects,
                  )
                : Stream.value(<PreferredStudyYear?, List<T>>{}),
          )
          .listen(
            groupedObjectsSubject.add,
            onError: groupedObjectsSubject.addError,
          );
    }

    return Rx.combineLatest3<bool, String, List<T>,
        Map<PreferredStudyYear?, List<T>>>(
      groupingSubject,
      searchSubject,
      objectsPaginatableStream.stream,
      (grouping, search, objects) => grouping ? groupBy!(objects) : {},
    ).listen(
      groupedObjectsSubject.add,
      onError: groupedObjectsSubject.addError,
    );
  }
}
