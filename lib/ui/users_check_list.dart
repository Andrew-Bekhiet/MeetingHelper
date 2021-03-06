import 'dart:async';

import 'package:async/async.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:collection/collection.dart';
import 'package:datetime_picker_formfield/datetime_picker_formfield.dart';
import 'package:flutter/material.dart';
import 'package:group_list_view/group_list_view.dart';
import 'package:intl/intl.dart';
import 'package:meetinghelper/models/list_options.dart';
import 'package:meetinghelper/models/mini_models.dart';
import 'package:meetinghelper/models/models.dart';
import 'package:meetinghelper/models/search_string.dart';
import 'package:meetinghelper/models/super_classes.dart';
import 'package:meetinghelper/models/user.dart';
import 'package:meetinghelper/utils/helpers.dart';
import 'package:provider/provider.dart';

import 'List.dart';

export 'package:meetinghelper/models/list_options.dart' show ListOptions;
export 'package:meetinghelper/models/order_options.dart';
export 'package:meetinghelper/models/search_string.dart';
export 'package:tuple/tuple.dart';

class UsersCheckList extends StatefulWidget {
  final CheckListOptions<User> options;

  UsersCheckList({Key key, @required this.options}) : super(key: key);

  @override
  _ListState createState() => _ListState();
}

class _ListState extends State<UsersCheckList>
    with AutomaticKeepAliveClientMixin<UsersCheckList> {
  List<User> _documentsData;
  String _oldFilter = '';
  HistoryDayOptions _dayOptions = HistoryDayOptions();

  bool _builtOnce = false;

  AsyncCache<List<User>> dataCache =
      AsyncCache<List<User>>(Duration(minutes: 5));

  @override
  bool get wantKeepAlive => _builtOnce && ModalRoute.of(context).isCurrent;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    _builtOnce = true;
    updateKeepAlive();
    return Consumer2<HistoryDayOptions, SearchString>(
      builder: (context, dayOptions, filter, child) {
        /* _requery(false); */
        var listOptions = widget.options;
        return StreamBuilder<Map<String, HistoryRecord>>(
          stream: listOptions.attended.map(
            (d) => {
              for (var e in d.docs)
                e.id: HistoryRecord.fromDoc(listOptions.day, e)
            },
          ),
          builder: (context, snapshot2) {
            if (snapshot2.hasError) return ErrorWidget(snapshot2.error);
            if (!snapshot2.hasData)
              return const Center(child: CircularProgressIndicator());
            return Scaffold(
              body: RefreshIndicator(
                onRefresh: () {
                  dataCache.invalidate();
                  return dataCache.fetch(User.getUsersForEdit);
                },
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('StudyYears')
                      .orderBy('Grade')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError)
                      return ErrorWidget.builder(snapshot.error);
                    if (!snapshot.hasData)
                      return const Center(child: CircularProgressIndicator());
                    return FutureBuilder<List<User>>(
                      future: dataCache.fetch(User.getUsersForEdit),
                      builder: (context, data) {
                        Map<String, StudyYear> studyYearByDocRef = {
                          for (var s in snapshot.data.docs)
                            s.reference.id: StudyYear.fromDoc(s)
                        };
                        return Consumer<SearchString>(
                          builder: (context, filter, _) {
                            if (data.hasError)
                              return Text(
                                  (data.error as FirebaseFunctionsException)
                                      .message);
                            if (!data.hasData)
                              return const Center(
                                  child: CircularProgressIndicator());
                            if (_oldFilter != filter.value ||
                                dayOptions != _dayOptions)
                              WidgetsBinding.instance.addPostFrameCallback(
                                  (_) async => await Future.delayed(
                                      Duration(milliseconds: 200),
                                      () => _requery(snapshot2.data)));
                            if (dayOptions.grouped) {
                              mergeSort<User>(_documentsData, compare: (u, u2) {
                                if (u.servingStudyYear == null &&
                                    u2.servingStudyYear == null) return 0;
                                if (u.servingStudyYear == null) return 1;
                                if (u2.servingStudyYear == null) return -1;
                                if (u.servingStudyYear == u2.servingStudyYear) {
                                  if (u.servingStudyGender ==
                                      u2.servingStudyGender)
                                    return u.name.compareTo(u2.name);
                                  return u.servingStudyGender
                                          ?.compareTo(u.servingStudyGender) ??
                                      1;
                                }
                                return studyYearByDocRef[u.servingStudyYear]
                                    .grade
                                    .compareTo(
                                        studyYearByDocRef[u2.servingStudyYear]
                                            .grade);
                              });
                              var groupedUsers =
                                  groupBy<User, Tuple2<String, bool>>(
                                      _documentsData,
                                      (user) => Tuple2<String, bool>(
                                          user.servingStudyYear,
                                          user.servingStudyGender));
                              return GroupListView(
                                sectionsCount: groupedUsers.length,
                                countOfItemInSection: (i) =>
                                    groupedUsers.values.elementAt(i).length,
                                physics: AlwaysScrollableScrollPhysics(),
                                cacheExtent: 200,
                                groupHeaderBuilder: (contetx, i) {
                                  if (groupedUsers.keys.elementAt(i).item1 ==
                                      null)
                                    return ListTile(title: Text('غير محدد'));
                                  return ListTile(
                                      title: Text(studyYearByDocRef[groupedUsers
                                                  .keys
                                                  .elementAt(i)
                                                  .item1]
                                              .name +
                                          ' - ' +
                                          (groupedUsers.keys
                                                      .elementAt(i)
                                                      .item2 ==
                                                  true
                                              ? 'بنين'
                                              : (groupedUsers.keys
                                                          .elementAt(i)
                                                          .item2 ==
                                                      false
                                                  ? 'بنات'
                                                  : 'غير محدد'))));
                                },
                                itemBuilder: (context, i) {
                                  User current = groupedUsers.values
                                      .elementAt(i.section)
                                      .elementAt(i.index);
                                  return Card(
                                    child: ListTile(
                                      title: Text(current.name),
                                      leading: current.getPhoto(),
                                      trailing: Checkbox(
                                        value:
                                            snapshot2.data[current.uid] != null,
                                        onChanged: dayOptions.enabled
                                            ? (v) async {
                                                if (v) {
                                                  await HistoryRecord(
                                                          id: current.uid,
                                                          parent:
                                                              listOptions.day,
                                                          type:
                                                              listOptions.type,
                                                          recordedBy:
                                                              User.instance.uid,
                                                          time: Timestamp.now())
                                                      .set();
                                                } else {
                                                  await snapshot2
                                                      .data[current.uid].ref
                                                      .delete();
                                                }
                                              }
                                            : null,
                                      ),
                                      onTap: dayOptions.enabled
                                          ? () async {
                                              if (snapshot2.data[current.uid] !=
                                                  null) {
                                                await snapshot2
                                                    .data[current.uid].ref
                                                    .delete();
                                              } else {
                                                await HistoryRecord(
                                                        id: current.uid,
                                                        parent: listOptions.day,
                                                        type: listOptions.type,
                                                        recordedBy:
                                                            User.instance.uid,
                                                        time: Timestamp.now())
                                                    .set();
                                              }
                                            }
                                          : () =>
                                              dataObjectTap(current, context),
                                      onLongPress: () => _showRecordDialog(
                                          current,
                                          snapshot2.data[current.uid],
                                          listOptions,
                                          dayOptions),
                                      subtitle:
                                          snapshot2.data[current.uid] != null
                                              ? Text(DateFormat(
                                                      'الساعة h : m د : s ث a',
                                                      'ar-EG')
                                                  .format(snapshot2
                                                      .data[current.uid].time
                                                      .toDate()))
                                              : null,
                                    ),
                                  );
                                },
                              );
                            }
                            mergeSort<User>(_documentsData, compare: (u, u2) {
                              return u.name.compareTo(u2.name);
                            });
                            return ListView.builder(
                              itemCount: _documentsData.length,
                              physics: AlwaysScrollableScrollPhysics(),
                              itemBuilder: (context, i) {
                                var current = _documentsData[i];
                                return Card(
                                  child: ListTile(
                                    title: Text(current.name),
                                    leading: current.getPhoto(),
                                    trailing: Checkbox(
                                      value:
                                          snapshot2.data[current.uid] != null,
                                      onChanged: dayOptions.enabled
                                          ? (v) async {
                                              if (v) {
                                                await HistoryRecord(
                                                        id: current.uid,
                                                        parent: listOptions.day,
                                                        type: listOptions.type,
                                                        recordedBy:
                                                            User.instance.uid,
                                                        time: Timestamp.now())
                                                    .set();
                                              } else {
                                                await snapshot2
                                                    .data[current.uid].ref
                                                    .delete();
                                              }
                                            }
                                          : null,
                                    ),
                                    onTap: dayOptions.enabled
                                        ? () async {
                                            if (snapshot2.data[current.uid] !=
                                                null) {
                                              await snapshot2
                                                  .data[current.uid].ref
                                                  .delete();
                                            } else {
                                              await HistoryRecord(
                                                      id: current.uid,
                                                      parent: listOptions.day,
                                                      type: listOptions.type,
                                                      recordedBy:
                                                          User.instance.uid,
                                                      time: Timestamp.now())
                                                  .set();
                                            }
                                          }
                                        : () => dataObjectTap(current, context),
                                    onLongPress: () => _showRecordDialog(
                                        current,
                                        snapshot2.data[current.uid],
                                        listOptions,
                                        dayOptions),
                                    subtitle:
                                        snapshot2.data[current.uid] != null
                                            ? Text(DateFormat(
                                                    'الساعة h : m د : s ث a',
                                                    'ar-EG')
                                                .format(snapshot2
                                                    .data[current.uid].time
                                                    .toDate()))
                                            : null,
                                  ),
                                );
                              },
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
              extendBody: true,
              floatingActionButtonLocation: listOptions.hasNotch
                  ? FloatingActionButtonLocation.endDocked
                  : null,
              floatingActionButton: listOptions.floatingActionButton,
              bottomNavigationBar: BottomAppBar(
                color: Theme.of(context).primaryColor,
                shape: listOptions.hasNotch
                    ? listOptions.doubleActionButton
                        ? const DoubleCircularNotchedButton()
                        : const CircularNotchedRectangle()
                    : null,
                child: Text(
                    (snapshot2?.data?.length ?? 0).toString() + ' شخص حاضر',
                    textAlign: TextAlign.center,
                    strutStyle:
                        StrutStyle(height: IconTheme.of(context).size / 7.5),
                    style: Theme.of(context).primaryTextTheme.bodyText1),
              ),
            );
          },
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    /* context.read<SearchString>().addListener(_requery);
    context.read<HistoryDayOptions>().addListener(_requery); */
    _requery();
  }

  Future<void> _checkPerson(
      {HistoryRecord record,
      bool checked,
      CheckListOptions<User> options,
      DataObject person,
      String notes,
      DateTime time,
      DocumentReference ref}) async {
    if (record != null) {
      if (checked) {
        if (notes != null && record.notes != notes) record.notes = notes;
        if (time != null && record.time != Timestamp.fromDate(time))
          record.time = Timestamp.fromDate(time);
        record.recordedBy = User.instance.uid;
        await record.update();
      } else
        await record.ref.delete();
    } else if (checked) {
      await HistoryRecord(
              id: person.id,
              notes: notes,
              parent: options.day,
              type: options.type,
              recordedBy: User.instance.uid,
              time: Timestamp.fromDate(time) ?? Timestamp.now())
          .set();
    } else {
      await ref.delete();
    }
  }

  void _requery([Map<String, HistoryRecord> attendant = const {}]) async {
    if (!mounted) return;
    String filter = context.read<SearchString>().value;
    bool _showTrueOnly = context.read<HistoryDayOptions>().showTrueOnly;
    if (filter.isNotEmpty) {
      if (_showTrueOnly &&
          _oldFilter.length < filter.length &&
          filter.startsWith(_oldFilter) &&
          _documentsData != null) {
        _documentsData = _documentsData
            .where((d) =>
                attendant[d.id] != null &&
                d.name
                    .toLowerCase()
                    .replaceAll(
                        RegExp(
                          r'[أإآ]',
                        ),
                        'ا')
                    .replaceAll(
                        RegExp(
                          r'[ى]',
                        ),
                        'ي')
                    .contains(filter))
            .toList();
      } else if (_oldFilter.length < filter.length &&
          filter.startsWith(_oldFilter) &&
          _documentsData != null) {
        _documentsData = _documentsData
            .where((d) => d.name
                .toLowerCase()
                .replaceAll(
                    RegExp(
                      r'[أإآ]',
                    ),
                    'ا')
                .replaceAll(
                    RegExp(
                      r'[ى]',
                    ),
                    'ي')
                .contains(filter))
            .toList();
      } else if (_showTrueOnly) {
        _documentsData = (await dataCache.fetch(User.getUsersForEdit))
            .where((d) =>
                attendant[d.id] != null &&
                d.name
                    .toLowerCase()
                    .replaceAll(
                        RegExp(
                          r'[أإآ]',
                        ),
                        'ا')
                    .replaceAll(
                        RegExp(
                          r'[ى]',
                        ),
                        'ي')
                    .contains(filter))
            .toList();
      } else {
        _documentsData = (await dataCache.fetch(User.getUsersForEdit))
            .where((d) => d.name
                .toLowerCase()
                .replaceAll(
                    RegExp(
                      r'[أإآ]',
                    ),
                    'ا')
                .replaceAll(
                    RegExp(
                      r'[ى]',
                    ),
                    'ي')
                .contains(filter))
            .toList();
      }
    } else if (_showTrueOnly) {
      _documentsData = (await dataCache.fetch(User.getUsersForEdit))
          .where((d) => attendant[d.id] != null)
          .toList();
    } else {
      _documentsData = await dataCache.fetch(User.getUsersForEdit);
    }
    _oldFilter = filter;
    _dayOptions = HistoryDayOptions(
        grouped: context.read<HistoryDayOptions>().grouped,
        showTrueOnly: context.read<HistoryDayOptions>().showTrueOnly,
        enabled: context.read<HistoryDayOptions>().enabled);
    setState(() {});
  }

  void _showRecordDialog(User current, HistoryRecord oRecord,
      CheckListOptions<User> options, HistoryDayOptions dayOptions) async {
    var record = oRecord != null
        ? HistoryRecord(
            id: oRecord.id,
            notes: oRecord.notes,
            parent: oRecord.parent,
            recordedBy: oRecord.recordedBy,
            time: oRecord.time,
            type: oRecord.type)
        : null;
    if (await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(current.name),
            content: StatefulBuilder(
              builder: (context, setState) => Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: <Widget>[
                      Checkbox(
                        value: record != null,
                        onChanged: dayOptions.enabled
                            ? (v) {
                                if (v) {
                                  record = HistoryRecord(
                                      id: current.uid,
                                      parent: options.day,
                                      type: options.type,
                                      recordedBy: User.instance.uid,
                                      time: Timestamp.now());
                                } else
                                  record = null;
                                setState(() {});
                              }
                            : null,
                      ),
                      GestureDetector(
                        onTap: dayOptions.enabled
                            ? () {
                                if (record == null) {
                                  record = HistoryRecord(
                                      id: current.uid,
                                      parent: options.day,
                                      type: options.type,
                                      recordedBy: User.instance.uid,
                                      time: Timestamp.now());
                                } else
                                  record = null;
                                setState(() {});
                              }
                            : null,
                        child: Text('وقت الحضور: '),
                      ),
                      Expanded(
                        child: DateTimeField(
                          format: DateFormat('الساعة h : m د : s ث a', 'ar-EG'),
                          initialValue:
                              record?.time?.toDate() ?? DateTime.now(),
                          resetIcon: null,
                          enabled: record != null && dayOptions.enabled,
                          onShowPicker: (context, initialValue) async {
                            var selected = await showTimePicker(
                              initialTime: TimeOfDay.fromDateTime(initialValue),
                              context: context,
                            );
                            return DateTime(
                                DateTime.now().year,
                                DateTime.now().month,
                                DateTime.now().day,
                                selected?.hour ?? initialValue.hour,
                                selected?.minute ?? initialValue.minute);
                          },
                          onChanged: (t) async {
                            record.time = Timestamp.fromDate(DateTime(
                                DateTime.now().year,
                                DateTime.now().month,
                                DateTime.now().day,
                                t.hour,
                                t.minute));
                            setState(() {});
                          },
                        ),
                      ),
                    ],
                  ),
                  TextFormField(
                    decoration: InputDecoration(
                      labelText: 'ملاحظات',
                      border: OutlineInputBorder(
                        borderSide:
                            BorderSide(color: Theme.of(context).primaryColor),
                      ),
                    ),
                    textInputAction: TextInputAction.done,
                    initialValue: record?.notes ?? '',
                    enabled: record != null && dayOptions.enabled,
                    onChanged: (n) => setState(() => record.notes = n),
                    maxLines: null,
                    validator: (value) {
                      return null;
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  dataObjectTap(current, context);
                },
                child: Text('عرض بيانات ' + current.name),
              ),
              if (dayOptions.enabled)
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text('حفظ'),
                ),
            ],
          ),
        ) ==
        true) {
      await _checkPerson(
          checked: record != null,
          notes: record?.notes,
          options: options,
          person: current,
          record: record,
          time: record?.time?.toDate(),
          ref: oRecord?.ref);
    }
  }
}
