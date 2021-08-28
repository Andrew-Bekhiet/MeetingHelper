import 'dart:async';

import 'package:datetime_picker_formfield/datetime_picker_formfield.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:group_list_view/group_list_view.dart';
import 'package:intl/intl.dart';
import 'package:meetinghelper/models/data_object_widget.dart';
import 'package:meetinghelper/models/invitation.dart';
import 'package:meetinghelper/models/list_controllers.dart';
import 'package:meetinghelper/models/models.dart';
import 'package:meetinghelper/models/super_classes.dart';
import 'package:meetinghelper/models/user.dart';
import 'package:meetinghelper/utils/globals.dart';
import 'package:meetinghelper/utils/typedefs.dart';
import 'package:meetinghelper/views/trash.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:rxdart/rxdart.dart';
import 'package:share_plus/share_plus.dart';
import 'package:tuple/tuple.dart';
import 'package:url_launcher/url_launcher.dart';

import '../utils/helpers.dart';

export 'package:meetinghelper/models/order_options.dart';
export 'package:tuple/tuple.dart';

///Constructs a [DataObject] [ListView]
///
///You must provide [ListOptions<T>] in the parameter
///or use [Provider<ListOptions<T>>] above this widget
class DataObjectList<T extends DataObject> extends StatefulWidget {
  final DataObjectListController<T>? options;
  final bool disposeController;

  const DataObjectList(
      {Key? key, this.options, required this.disposeController})
      : super(key: key);

  @override
  _ListState<T> createState() => _ListState<T>();
}

class _ListState<T extends DataObject> extends State<DataObjectList<T>>
    with AutomaticKeepAliveClientMixin<DataObjectList<T>> {
  bool _builtOnce = false;
  late DataObjectListController<T> _listOptions;

  @override
  bool get wantKeepAlive => _builtOnce && ModalRoute.of(context)!.isCurrent;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    _builtOnce = true;
    updateKeepAlive();

    return StreamBuilder<List<T>>(
      stream: _listOptions.objectsData,
      builder: (context, stream) {
        if (stream.hasError) return Center(child: ErrorWidget(stream.error!));
        if (!stream.hasData)
          return const Center(child: CircularProgressIndicator());

        final List<T> _data = stream.data!;
        if (_data.isEmpty)
          return Center(child: Text('لا يوجد ${_getPluralStringType()}'));

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          addAutomaticKeepAlives: _data.length < 500,
          cacheExtent: 200,
          itemCount: _data.length + 1,
          itemBuilder: (context, i) {
            if (i == _data.length)
              return Container(height: MediaQuery.of(context).size.height / 19);

            final T current = _data[i];
            return _listOptions.buildItem(
              current,
              onLongPress: _listOptions.onLongPress ?? _defaultLongPress,
              onTap: (T current) {
                if (!_listOptions.selectionMode.value) {
                  _listOptions.tap == null
                      ? dataObjectTap(current)
                      : _listOptions.tap!(current);
                } else {
                  _listOptions.toggleSelected(current);
                }
              },
              trailing: StreamBuilder<Map<String, T>?>(
                stream: Rx.combineLatest2(
                    _listOptions.selected,
                    _listOptions.selectionMode,
                    (dynamic a, dynamic b) => b ? a : null),
                builder: (context, snapshot) {
                  if (snapshot.hasData) {
                    return Checkbox(
                      value: snapshot.data!.containsKey(current.id),
                      onChanged: (v) {
                        if (v!) {
                          _listOptions.select(current);
                        } else {
                          _listOptions.deselect(current);
                        }
                      },
                    );
                  }
                  return const SizedBox(width: 1, height: 1);
                },
              ),
            );
          },
        );
      },
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _listOptions =
        widget.options ?? context.read<DataObjectListController<T>>();
  }

  void _defaultLongPress(T current) async {
    _listOptions.selectionMode.add(!_listOptions.selectionMode.value);

    if (!_listOptions.selectionMode.value) {
      if (_listOptions.selected.value.isNotEmpty) {
        if (T == Person) {
          await showDialog(
            context: context,
            builder: (context) => AlertDialog(
              content: const Text('اختر أمرًا:'),
              actions: <Widget>[
                TextButton.icon(
                  icon: const Icon(Icons.sms),
                  onPressed: () {
                    navigator.currentState!.pop();
                    List<Person> people = _listOptions.selected.value.values
                        .cast<Person>()
                        .toList()
                        .where((p) => p.phone != null && p.phone!.isNotEmpty)
                        .toList();
                    if (people.isNotEmpty)
                      launch(
                        'sms:' +
                            people
                                .map(
                                  (f) => getPhone(f.phone!),
                                )
                                .toList()
                                .cast<String>()
                                .join(','),
                      );
                  },
                  label: const Text('ارسال رسالة جماعية'),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.share),
                  onPressed: () async {
                    navigator.currentState!.pop();
                    await Share.share(
                      (await Future.wait(
                        _listOptions.selected.value.values.cast<Person>().map(
                              (f) async => f.name + ': ' + await sharePerson(f),
                            ),
                      ))
                          .join('\n'),
                    );
                  },
                  label: const Text('مشاركة القائمة'),
                ),
                TextButton.icon(
                  icon: const ImageIcon(AssetImage('assets/whatsapp.png')),
                  onPressed: () async {
                    navigator.currentState!.pop();
                    var con = TextEditingController();
                    String? msg = await showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        actions: [
                          TextButton.icon(
                            icon: const Icon(Icons.send),
                            label: const Text('ارسال'),
                            onPressed: () {
                              navigator.currentState!.pop(con.text);
                            },
                          ),
                        ],
                        content: TextFormField(
                          controller: con,
                          maxLines: null,
                          decoration: InputDecoration(
                            labelText: 'اكتب رسالة',
                            border: OutlineInputBorder(
                              borderSide: BorderSide(
                                  color: Theme.of(context).colorScheme.primary),
                            ),
                          ),
                        ),
                      ),
                    );
                    if (msg != null) {
                      msg = Uri.encodeComponent(msg);
                      for (Person person in _listOptions.selected.value.values
                          .cast<Person>()
                          .where(
                              (p) => p.phone != null && p.phone!.isNotEmpty)) {
                        String phone = getPhone(person.phone!);
                        await launch('https://wa.me/$phone?text=$msg');
                      }
                    }
                  },
                  label: const Text('ارسال رسالة واتساب للكل'),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.person_add),
                  onPressed: () async {
                    navigator.currentState!.pop();
                    if ((await Permission.contacts.request()).isGranted) {
                      for (Person item in _listOptions.selected.value.values
                          .cast<Person>()
                          .where(
                              (p) => p.phone != null && p.phone!.isNotEmpty)) {
                        try {
                          final c = Contact(
                              photo: item.hasPhoto
                                  ? await item.photoRef
                                      .getData(100 * 1024 * 1024)
                                  : null,
                              phones: [Phone(item.phone!)])
                            ..name.first = item.name;
                          await c.insert();
                        } catch (err, stkTrace) {
                          await FirebaseCrashlytics.instance.setCustomKey(
                              'LastErrorIn',
                              'InnerPersonListState.build.addToContacts.tap');
                          await FirebaseCrashlytics.instance
                              .recordError(err, stkTrace);
                        }
                      }
                    }
                  },
                  label: const Text('اضافة إلى جهات الاتصال بالهاتف'),
                ),
              ],
            ),
          );
        } else
          await Share.share(
            (await Future.wait(_listOptions.selected.value.values
                    .map((f) async => f.name + ': ' + await shareDataObject(f))
                    .toList()))
                .join('\n'),
          );
      }
      _listOptions.selectNone(false);
    } else {
      _listOptions.select(current);
    }
  }

  String _getPluralStringType() {
    if (T == HistoryDay || T == ServantsHistoryDay) return 'سجلات';
    if (T == Class) return 'فصول';
    if (T == Person) return 'مخدومين';
    if (T == Invitation) return 'دعوات';
    if (T == TrashDay) return 'محذوفات';
    throw UnimplementedError();
  }

  @override
  Future<void> dispose() async {
    super.dispose();
    if (widget.disposeController) await _listOptions.dispose();
  }
}

class DataObjectCheckList<T extends Person> extends StatefulWidget {
  final CheckListController<T>? options;
  final bool autoDisposeController;

  const DataObjectCheckList(
      {Key? key, this.options, required this.autoDisposeController})
      : super(key: key);

  @override
  _CheckListState<T> createState() => _CheckListState<T>();
}

class _CheckListState<T extends Person> extends State<DataObjectCheckList<T>>
    with AutomaticKeepAliveClientMixin<DataObjectCheckList<T>> {
  bool _builtOnce = false;
  late CheckListController<T> _listOptions;

  @override
  bool get wantKeepAlive => _builtOnce && ModalRoute.of(context)!.isCurrent;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    _builtOnce = true;
    updateKeepAlive();

    return StreamBuilder<bool>(
      stream: _listOptions.dayOptions.grouped,
      builder: (context, grouped) {
        if (grouped.hasError) return Center(child: ErrorWidget(grouped.error!));
        if (!grouped.hasData)
          return const Center(child: CircularProgressIndicator());

        if (grouped.data!) {
          return buildGroupedListView();
        } else {
          return buildListView();
        }
      },
    );
  }

  Widget buildGroupedListView() {
    return StreamBuilder<Map<JsonRef, Tuple2<Class, List<T>>>>(
      stream: _listOptions.groupedData,
      builder: (context, groupedData) {
        if (groupedData.hasError) return ErrorWidget(groupedData.error!);
        if (!groupedData.hasData)
          return const Center(child: CircularProgressIndicator());

        if (groupedData.data!.isEmpty)
          return Center(child: Text('لا يوجد ${_getPluralStringType()}'));

        return GroupListView(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          sectionsCount: groupedData.data!.length + 1,
          countOfItemInSection: (i) {
            if (i == groupedData.data!.length) return 0;

            return groupedData.data!.values.elementAt(i).item2.length;
          },
          cacheExtent: 500,
          groupHeaderBuilder: (context, i) {
            if (i == groupedData.data!.length)
              return Container(height: MediaQuery.of(context).size.height / 15);

            return StreamBuilder<bool?>(
              stream: _listOptions.dayOptions.showSubtitlesInGroups,
              builder: (context, showSubtitle) {
                return Container(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: DataObjectWidget<Class>(
                    groupedData.data!.values.elementAt(i).item1,
                    wrapInCard: false,
                    showSubTitle: showSubtitle.data == true,
                    subtitle: showSubtitle.data == true
                        ? Text('يتم عرض ' +
                            groupedData.data!.values
                                .elementAt(i)
                                .item2
                                .length
                                .toString() +
                            ' مخدوم داخل الفصل')
                        : null,
                    onTap: () {
                      _listOptions.openedNodes.add({
                        ..._listOptions.openedNodes.value,
                        groupedData.data!.keys.elementAt(i): !(_listOptions
                                .openedNodes
                                .value[groupedData.data!.keys.elementAt(i)] ??
                            false)
                      });
                    },
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          onPressed: () {
                            _listOptions.openedNodes.add({
                              ..._listOptions.openedNodes.value,
                              groupedData.data!.keys.elementAt(i):
                                  !(_listOptions.openedNodes.value[groupedData
                                          .data!.keys
                                          .elementAt(i)] ??
                                      false)
                            });
                          },
                          icon: Icon(
                            _listOptions.openedNodes.value[
                                        groupedData.data!.keys.elementAt(i)] ??
                                    false
                                ? Icons.arrow_drop_up
                                : Icons.arrow_drop_down,
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            classTap(
                                groupedData.data!.values.elementAt(i).item1);
                          },
                          icon: const Icon(Icons.info_outlined),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
          itemBuilder: (context, i) {
            T current = groupedData.data!.values
                .elementAt(i.section)
                .item2
                .elementAt(i.index);
            return Padding(
              padding: const EdgeInsets.fromLTRB(3, 0, 9, 0),
              child: _buildItem(current),
            );
          },
        );
      },
    );
  }

  Widget buildListView() {
    return StreamBuilder<List<T>>(
        stream: _listOptions.objectsData,
        builder: (context, data) {
          if (data.hasError) return Center(child: ErrorWidget(data.error!));
          if (!data.hasData)
            return const Center(child: CircularProgressIndicator());

          final List<T> _data = data.data!;
          if (_data.isEmpty)
            return Center(child: Text('لا يوجد ${_getPluralStringType()}'));

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            addAutomaticKeepAlives: _data.length < 500,
            cacheExtent: 200,
            itemCount: _data.length + 1,
            itemBuilder: (context, i) {
              if (i == _data.length)
                return Container(
                    height: MediaQuery.of(context).size.height / 19);

              final T current = _data[i];
              return _buildItem(current);
            },
          );
        });
  }

  Widget _buildItem(T current) {
    return StreamBuilder<Map<String, HistoryRecord>>(
      stream: _listOptions.attended,
      builder: (context, attended) => _listOptions.buildItem(
        current,
        onLongPress: _listOptions.onLongPress ??
            ((o) =>
                _showRecordDialog(o, _listOptions.attended.value[current.id])),
        onTap: (T current) async {
          if (!_listOptions.dayOptions.enabled.value) {
            _listOptions.tap == null
                ? dataObjectTap(current)
                : _listOptions.tap!(current);
          } else {
            if (!_listOptions.dayOptions.lockUnchecks.value) {
              await _listOptions.toggleSelected(current);
            } else if (!_listOptions.selected.value.containsKey(current.id) ||
                _listOptions.dayOptions.lockUnchecks.value &&
                    await showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            content: Text(
                                'هل تريد إلغاء حضور ' + current.name + '؟'),
                            actions: [
                              TextButton(
                                onPressed: () =>
                                    navigator.currentState!.pop(true),
                                child: const Text('تأكيد'),
                              ),
                              TextButton(
                                onPressed: () =>
                                    navigator.currentState!.pop(false),
                                child: const Text('تراجع'),
                              ),
                            ],
                          ),
                        ) ==
                        true) {
              await _listOptions.toggleSelected(current);
            }
          }
        },
        subtitle: attended.hasData && attended.data!.containsKey(current.id)
            ? Text(DateFormat('الساعة h : m د : s ث a', 'ar-EG')
                .format(attended.data![current.id]!.time.toDate()))
            : null,
        trailing: attended.hasData
            ? Checkbox(
                value: attended.data!.containsKey(current.id),
                onChanged: _listOptions.dayOptions.enabled.value
                    ? (v) {
                        if (v!) {
                          _listOptions.select(current);
                        } else {
                          _listOptions.deselect(current);
                        }
                      }
                    : null,
              )
            : const Checkbox(value: false, onChanged: null),
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _listOptions = widget.options ?? context.read<CheckListController<T>>();
  }

  void _showRecordDialog(T current, HistoryRecord? oRecord) async {
    var record = oRecord != null
        ? HistoryRecord(
            classId: current.classId!,
            id: oRecord.id,
            notes: oRecord.notes,
            parent: oRecord.parent,
            recordedBy: oRecord.recordedBy,
            time: oRecord.time,
            type: oRecord.type,
            isServant: T == User)
        : null;
    if (await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(current.name),
            content: StreamBuilder<bool>(
              initialData: _listOptions.dayOptions.enabled.value,
              stream: _listOptions.dayOptions.enabled,
              builder: (context, enabled) {
                return StatefulBuilder(
                  builder: (context, setState) => Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: <Widget>[
                          Checkbox(
                            value: record != null,
                            onChanged: enabled.data ?? false
                                ? (v) {
                                    if (v!) {
                                      record = HistoryRecord(
                                          classId: current.classId!,
                                          id: current.id,
                                          parent: _listOptions.day,
                                          type: _listOptions.type,
                                          recordedBy: User.instance.uid!,
                                          time: mergeDayWithTime(
                                            _listOptions.day.day.toDate(),
                                            DateTime.now(),
                                          ),
                                          isServant: T == User);
                                    } else
                                      record = null;
                                    setState(() {});
                                  }
                                : null,
                          ),
                          Expanded(
                            child: DateTimeField(
                              decoration: InputDecoration(
                                labelText: 'وقت الحضور',
                                border: OutlineInputBorder(
                                  borderSide: BorderSide(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary),
                                ),
                              ),
                              format:
                                  DateFormat('الساعة h : m د : s ث a', 'ar-EG'),
                              initialValue:
                                  record?.time.toDate() ?? DateTime.now(),
                              resetIcon: null,
                              enabled:
                                  record != null && (enabled.data ?? false),
                              onShowPicker: (context, initialValue) async {
                                var selected = await showTimePicker(
                                  initialTime:
                                      TimeOfDay.fromDateTime(initialValue!),
                                  context: context,
                                );
                                return DateTime(
                                    _listOptions.day.day.toDate().year,
                                    _listOptions.day.day.toDate().month,
                                    _listOptions.day.day.toDate().day,
                                    selected?.hour ?? initialValue.hour,
                                    selected?.minute ?? initialValue.minute);
                              },
                              onChanged: (t) async {
                                record!.time = mergeDayWithTime(
                                    _listOptions.day.day.toDate(), t!);
                                setState(() {});
                              },
                            ),
                          ),
                        ],
                      ),
                      Container(height: 10),
                      TextFormField(
                        decoration: InputDecoration(
                          labelText: 'ملاحظات',
                          border: OutlineInputBorder(
                            borderSide: BorderSide(
                                color: Theme.of(context).colorScheme.primary),
                          ),
                        ),
                        textInputAction: TextInputAction.done,
                        initialValue: record?.notes ?? '',
                        enabled: record != null && (enabled.data ?? false),
                        onChanged: (n) => setState(() => record!.notes = n),
                        maxLines: null,
                        validator: (value) {
                          return null;
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
            actions: [
              TextButton(
                onPressed: () {
                  navigator.currentState!.pop();
                  dataObjectTap(current);
                },
                child: Text('عرض بيانات ' + current.name),
              ),
              if (_listOptions.dayOptions.enabled.value)
                TextButton(
                  onPressed: () => navigator.currentState!.pop(true),
                  child: const Text('حفظ'),
                ),
            ],
          ),
        ) ==
        true) {
      if (_listOptions.selected.value.containsKey(current.id) &&
          record != null) {
        await _listOptions.modifySelected(current,
            notes: record!.notes, time: record!.time);
      } else if (record != null) {
        await _listOptions.select(current,
            notes: record?.notes, time: record?.time);
      } else if (_listOptions.selected.value.containsKey(current.id)) {
        await _listOptions.deselect(current);
      }
    }
  }

  String _getPluralStringType() {
    if (T == HistoryDay || T == ServantsHistoryDay) return 'سجلات';
    if (T == Class) return 'فصول';
    if (T == User) return 'مستخدمين';
    if (T == Person) return 'مخدومين';
    if (T == Invitation) return 'دعوات';
    throw UnimplementedError();
  }

  @override
  Future<void> dispose() async {
    super.dispose();
    if (widget.autoDisposeController) await _listOptions.dispose();
  }
}
