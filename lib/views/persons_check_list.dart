import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:datetime_picker_formfield/datetime_picker_formfield.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:group_list_view/group_list_view.dart';
import 'package:intl/intl.dart';
import 'package:meetinghelper/models/models.dart';
import 'package:provider/provider.dart';

import '../models/data_object_widget.dart';
import '../models/list_options.dart';
import '../models/order_options.dart';
import '../models/search_string.dart';
import '../models/user.dart';
import '../utils/helpers.dart';
import 'List.dart';

export 'package:tuple/tuple.dart';

export '../models/list_options.dart' show ListOptions;
export '../models/order_options.dart';
export '../models/search_string.dart';

class PersonsCheckList extends StatefulWidget {
  final CheckListOptions<Person> options;

  PersonsCheckList({Key key, @required this.options}) : super(key: key);

  @override
  _ListState createState() => _ListState();
}

class _InnerList extends StatefulWidget {
  _InnerList({Key key}) : super(key: key);

  @override
  State<StatefulWidget> createState() => _InnerListState();
}

class _InnerListState extends State<_InnerList> {
  List<Person> _documentsData;
  String _oldFilter = '';
  HistoryDayOptions _dayOptions = HistoryDayOptions();

  @override
  Widget build(BuildContext context) {
    return Consumer3<CheckListOptions<Person>, HistoryDayOptions, SearchString>(
      builder: (context, listOptions, dayOptions, filter, child) {
        return StreamBuilder<Map<String, HistoryRecord>>(
          stream: listOptions.attended.map(
            (d) => {
              for (var e in d.docs)
                e.id: HistoryRecord.fromDoc(listOptions.day, e)
            },
          ),
          builder: (context, snapshot) {
            if (snapshot.hasError) return ErrorWidget(snapshot.error);
            if (!snapshot.hasData)
              return const Center(child: CircularProgressIndicator());
            if ((_oldFilter != '' &&
                    listOptions.items.length != _documentsData.length &&
                    !_dayOptions.showTrueOnly) ||
                _oldFilter != filter.value ||
                dayOptions != _dayOptions) _requery(snapshot.data);
            if (dayOptions.grouped) {
              return Scaffold(
                body: StreamBuilder<
                    Map<DocumentReference, Tuple2<Class, List<Person>>>>(
                  stream: personsByClassRef(_documentsData),
                  builder: (context, personsByClassRef) {
                    if (personsByClassRef.hasError)
                      return ErrorWidget(personsByClassRef.error);
                    if (!personsByClassRef.hasData)
                      return const Center(child: CircularProgressIndicator());
                    return GroupListView(
                      sectionsCount: personsByClassRef.data.length,
                      countOfItemInSection: (i) => personsByClassRef.data.values
                          .elementAt(i)
                          .item2
                          .length,
                      cacheExtent: 500,
                      groupHeaderBuilder: (context, i) =>
                          DataObjectWidget<Class>(
                              personsByClassRef.data.values.elementAt(i).item1,
                              showSubTitle: false),
                      itemBuilder: (context, i) {
                        var current = personsByClassRef.data.values
                            .elementAt(i.section)
                            .item2
                            .elementAt(i.index);
                        return DataObjectWidget<Person>(
                          current,
                          subtitle: snapshot.data[current.id] != null
                              ? Text(DateFormat(
                                      'الساعة h : m د : s ث a', 'ar-EG')
                                  .format(
                                      snapshot.data[current.id].time.toDate()))
                              : null,
                          onLongPress: () => _showRecordDialog(
                              current,
                              snapshot.data[current.id],
                              listOptions,
                              dayOptions),
                          onTap: dayOptions.enabled
                              ? () async {
                                  if (snapshot.data[current.id] != null) {
                                    await snapshot.data[current.id].ref
                                        .delete();
                                  } else {
                                    //ToDo: implement classId
                                    await HistoryRecord(
                                            classId: current.classId,
                                            id: current.id,
                                            parent: listOptions.day,
                                            type: listOptions.type,
                                            recordedBy: User.instance.uid,
                                            time: Timestamp.now())
                                        .set();
                                  }
                                }
                              : () => dataObjectTap(current, context),
                          trailing: Checkbox(
                            value: snapshot.data[current.id] != null,
                            onChanged: dayOptions.enabled
                                ? (v) async {
                                    if (v) {
                                      await HistoryRecord(
                                              classId: current.classId,
                                              id: current.id,
                                              parent: listOptions.day,
                                              type: listOptions.type,
                                              recordedBy: User.instance.uid,
                                              time: Timestamp.now())
                                          .set();
                                    } else {
                                      await snapshot.data[current.id].ref
                                          .delete();
                                    }
                                  }
                                : null,
                          ),
                        );
                      },
                    );
                  },
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
                      (snapshot?.data?.length ?? 0).toString() + ' شخص حاضر',
                      textAlign: TextAlign.center,
                      strutStyle:
                          StrutStyle(height: IconTheme.of(context).size / 7.5),
                      style: Theme.of(context).primaryTextTheme.bodyText1),
                ),
              );
            }
            return Scaffold(
              body: ListView.builder(
                padding: EdgeInsets.symmetric(horizontal: 6),
                addAutomaticKeepAlives: (_documentsData?.length ?? 0) < 500,
                cacheExtent: 200,
                itemCount: (_documentsData?.length ?? 0) + 1,
                itemBuilder: (context, i) {
                  if (i == _documentsData.length)
                    return Container(
                        height: MediaQuery.of(context).size.height / 19);
                  var current = _documentsData[i];
                  return DataObjectWidget<Person>(
                    current,
                    subtitle: snapshot.data[current.id] != null
                        ? Text(DateFormat('الساعة h : m د : s ث a', 'ar-EG')
                            .format(snapshot.data[current.id].time.toDate()))
                        : null,
                    onLongPress: () => _showRecordDialog(current,
                        snapshot.data[current.id], listOptions, dayOptions),
                    onTap: dayOptions.enabled
                        ? () async {
                            if (snapshot.data[current.id] != null) {
                              await snapshot.data[current.id].ref.delete();
                            } else {
                              await HistoryRecord(
                                      classId: current.classId,
                                      id: current.id,
                                      parent: listOptions.day,
                                      type: listOptions.type,
                                      recordedBy: User.instance.uid,
                                      time: Timestamp.now())
                                  .set();
                            }
                          }
                        : () => dataObjectTap(current, context),
                    trailing: Checkbox(
                      value: snapshot.data[current.id] != null,
                      onChanged: dayOptions.enabled
                          ? (v) async {
                              if (v) {
                                await HistoryRecord(
                                        classId: current.classId,
                                        id: current.id,
                                        parent: listOptions.day,
                                        type: listOptions.type,
                                        recordedBy: User.instance.uid,
                                        time: Timestamp.now())
                                    .set();
                              } else {
                                await snapshot.data[current.id].ref.delete();
                              }
                            }
                          : null,
                    ),
                  );
                },
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
                    (snapshot?.data?.length ?? 0).toString() + ' شخص حاضر',
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
    // _requery();
  }

  Future<void> _checkPerson(
      {HistoryRecord record,
      bool checked,
      CheckListOptions<Person> options,
      Person person,
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
              classId: person.classId,
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
        _documentsData = context
            .read<CheckListOptions<Person>>()
            .items
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
        _documentsData = context
            .read<CheckListOptions<Person>>()
            .items
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
      _documentsData = context
          .read<CheckListOptions<Person>>()
          .items
          .where((d) => attendant[d.id] != null)
          .toList();
    } else {
      _documentsData = context.read<CheckListOptions<Person>>().items;
    }
    _oldFilter = filter;
    _dayOptions = HistoryDayOptions(
        grouped: context.read<HistoryDayOptions>().grouped,
        showTrueOnly: context.read<HistoryDayOptions>().showTrueOnly,
        enabled: context.read<HistoryDayOptions>().enabled);
    // setState(() {});
  }

  void _showRecordDialog(Person current, HistoryRecord oRecord,
      CheckListOptions<Person> options, HistoryDayOptions dayOptions) async {
    var record = oRecord != null
        ? HistoryRecord(
            classId: current.classId,
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
                                      classId: current.classId,
                                      id: current.id,
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
                                      classId: current.classId,
                                      id: current.id,
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

class _ListState extends State<PersonsCheckList>
    with AutomaticKeepAliveClientMixin<PersonsCheckList> {
  @override
  bool get wantKeepAlive => _builtOnce && ModalRoute.of(context).isCurrent;

  bool _builtOnce = false;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    _builtOnce = true;
    updateKeepAlive();
    return StreamBuilder<List<Person>>(
      stream: widget.options.documentsData,
      builder: (context, stream) {
        if (stream.hasError) return ErrorWidget(stream.error);
        if (!stream.hasData)
          return const Center(child: CircularProgressIndicator());
        return ChangeNotifierProxyProvider0<CheckListOptions<Person>>(
          create: (_) => CheckListOptions<Person>(
            items: stream.data,
            day: widget.options.day,
            documentsData: widget.options.documentsData,
            type: widget.options.type,
          ),
          update: (_, old) => old..items = stream.data,
          builder: (context, _) => _InnerList(),
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    context.read<OrderOptions>().addListener(() {
      if (mounted) setState(() {});
    });
  }
}
