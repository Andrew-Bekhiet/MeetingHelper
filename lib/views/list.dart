import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:datetime_picker_formfield/datetime_picker_formfield.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:group_list_view/group_list_view.dart';
import 'package:meetinghelper/models/data_object_widget.dart';
import 'package:meetinghelper/models/invitation.dart';
import 'package:meetinghelper/models/list_options.dart';
import 'package:meetinghelper/models/models.dart';
import 'package:meetinghelper/models/super_classes.dart';
import 'package:meetinghelper/models/user.dart';
import 'package:meetinghelper/utils/globals.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:rxdart/rxdart.dart';
import 'package:intl/intl.dart';
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
  final DataObjectListOptions<T>? options;

  DataObjectList({Key? key, this.options}) : super(key: key);

  @override
  _ListState<T> createState() => _ListState<T>();
}

class _ListState<T extends DataObject> extends State<DataObjectList<T>>
    with AutomaticKeepAliveClientMixin<DataObjectList<T>> {
  bool _builtOnce = false;
  late DataObjectListOptions<T> _listOptions;

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
          padding: EdgeInsets.symmetric(horizontal: 6),
          addAutomaticKeepAlives: _data.length < 500,
          cacheExtent: 200,
          itemCount: _data.length + 1,
          itemBuilder: (context, i) {
            if (i == _data.length)
              return Container(height: MediaQuery.of(context).size.height / 19);

            final T current = _data[i];
            return _listOptions.itemBuilder(
              current,
              _listOptions.onLongPress ?? _defaultLongPress,
              (T current) {
                if (!_listOptions.selectionModeLatest) {
                  _listOptions.tap == null
                      ? dataObjectTap(current, context)
                      : _listOptions.tap!(current);
                } else {
                  _listOptions.toggleSelected(current);
                }
              },
              StreamBuilder<Map<String, T>?>(
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
                  return Container(width: 1, height: 1);
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
    _listOptions = widget.options ?? context.read<DataObjectListOptions<T>>();
  }

  void _defaultLongPress(T current) async {
    _listOptions.selectionMode.add(!_listOptions.selectionModeLatest);

    if (!_listOptions.selectionModeLatest) {
      if (_listOptions.selectedLatest.isNotEmpty) {
        if (T == Person) {
          await showDialog(
            context: context,
            builder: (context) => AlertDialog(
              content: Text('اختر أمرًا:'),
              actions: <Widget>[
                TextButton.icon(
                  icon: Icon(Icons.sms),
                  onPressed: () {
                    navigator.currentState!.pop();
                    List<Person> people = _listOptions.selectedLatest.values
                        .cast<Person>()
                        .toList()
                          ..removeWhere((p) =>
                              p.phone == '' ||
                              p.phone == 'null' ||
                              p.phone == null);
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
                  label: Text('ارسال رسالة جماعية'),
                ),
                TextButton.icon(
                  icon: Icon(Icons.share),
                  onPressed: () async {
                    navigator.currentState!.pop();
                    await Share.share(
                      (await Future.wait(
                        _listOptions.selectedLatest.values.cast<Person>().map(
                              (f) async => f.name + ': ' + await sharePerson(f),
                            ),
                      ))
                          .join('\n'),
                    );
                  },
                  label: Text('مشاركة القائمة'),
                ),
                TextButton.icon(
                  icon: ImageIcon(AssetImage('assets/whatsapp.png')),
                  onPressed: () async {
                    navigator.currentState!.pop();
                    var con = TextEditingController();
                    String msg = await (showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        actions: [
                          TextButton.icon(
                            icon: Icon(Icons.send),
                            label: Text('ارسال'),
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
                                  color: Theme.of(context).primaryColor),
                            ),
                          ),
                        ),
                      ),
                    ) as FutureOr<String>);
                    msg = Uri.encodeComponent(msg);
                    for (Person person
                        in _listOptions.selectedLatest.values.cast<Person>()) {
                      String phone = getPhone(person.phone!);
                      await launch('https://wa.me/$phone?text=$msg');
                    }
                  },
                  label: Text('ارسال رسالة واتساب للكل'),
                ),
                TextButton.icon(
                  icon: Icon(Icons.person_add),
                  onPressed: () async {
                    navigator.currentState!.pop();
                    if ((await Permission.contacts.request()).isGranted) {
                      for (Person item in _listOptions.selectedLatest.values
                          .cast<Person>()) {
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
                  label: Text('اضافة إلى جهات الاتصال بالهاتف'),
                ),
              ],
            ),
          );
        } else
          await Share.share(
            (await Future.wait(_listOptions.selectedLatest.values
                    .map((f) async => f.name + ': ' + await shareDataObject(f))
                    .toList()))
                .join('\n'),
          );
      }
      _listOptions.selected.add({});
    } else {
      _listOptions.select(current);
    }
  }

  String _getPluralStringType() {
    if (T == HistoryDay || T == ServantsHistoryDay) return 'سجلات';
    if (T == Class) return 'فصول';
    if (T == Person) return 'مخدومين';
    if (T == Invitation) return 'دعوات';
    throw UnimplementedError();
  }
}

class DataObjectCheckList<T extends Person> extends StatefulWidget {
  final CheckListOptions<T>? options;

  DataObjectCheckList({Key? key, this.options}) : super(key: key);

  @override
  _CheckListState<T> createState() => _CheckListState<T>();
}

class _CheckListState<T extends Person> extends State<DataObjectCheckList<T>>
    with AutomaticKeepAliveClientMixin<DataObjectCheckList<T>> {
  bool _builtOnce = false;
  late CheckListOptions<T> _listOptions;

  @override
  bool get wantKeepAlive => _builtOnce && ModalRoute.of(context)!.isCurrent;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    _builtOnce = true;
    updateKeepAlive();

    return StreamBuilder<Tuple2<List<T>, bool?>>(
      stream: Rx.combineLatest2<List<T>, bool?, Tuple2<List<T>, bool?>>(
        _listOptions.objectsData,
        _listOptions.dayOptions.grouped,
        (a, b) => Tuple2<List<T>, bool?>(a, b),
      ),
      builder: (context, options) {
        if (options.hasError) return Center(child: ErrorWidget(options.error!));
        if (!options.hasData)
          return const Center(child: CircularProgressIndicator());

        final List<T> _data = options.data!.item1;
        if (_data.isEmpty)
          return Center(child: Text('لا يوجد ${_getPluralStringType()}'));

        if (options.data!.item2!) {
          return buildGroupedListView(_data);
        } else {
          return buildListView(_data);
        }
      },
    );
  }

  Widget buildGroupedListView(List<T> _data) {
    return StreamBuilder<Map<DocumentReference, Tuple2<Class, List<T>>>>(
      stream: _listOptions.getGroupedData!(_data),
      builder: (context, groupedData) {
        if (groupedData.hasError) return ErrorWidget(groupedData.error!);
        if (!groupedData.hasData)
          return const Center(child: CircularProgressIndicator());

        return GroupListView(
          padding: EdgeInsets.symmetric(horizontal: 4),
          sectionsCount: groupedData.data!.length + 1,
          countOfItemInSection: (i) {
            if (i == groupedData.data!.length) return 0;

            return groupedData.data!.values.elementAt(i).item2.length;
          },
          cacheExtent: 500,
          groupHeaderBuilder: (context, i) {
            if (i == groupedData.data!.length)
              return Container(height: MediaQuery.of(context).size.height / 19);

            return StreamBuilder<bool?>(
              stream: _listOptions.dayOptions.showSubtitlesInGroups,
              builder: (context, showSubtitle) {
                return DataObjectWidget<Class>(
                  groupedData.data!.values.elementAt(i).item1,
                  showSubTitle: showSubtitle.data == true,
                  subtitle: Text('يتم عرض ' +
                      groupedData.data!.values
                          .elementAt(i)
                          .item2
                          .length
                          .toString() +
                      ' مخدوم داخل الفصل'),
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

  Widget buildListView(List<T> _data) {
    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: 6),
      addAutomaticKeepAlives: _data.length < 500,
      cacheExtent: 200,
      itemCount: _data.length + 1,
      itemBuilder: (context, i) {
        if (i == _data.length)
          return Container(height: MediaQuery.of(context).size.height / 19);

        final T current = _data[i];
        return _buildItem(current);
      },
    );
  }

  Widget _buildItem(T current) {
    return StreamBuilder<Map<String, HistoryRecord>>(
      stream: _listOptions.attended,
      builder: (context, attended) => _listOptions.itemBuilder(
        current,
        _listOptions.onLongPress ??
            ((o) =>
                _showRecordDialog(o, _listOptions.attended.value![current.id])),
        (T current) async {
          if (!_listOptions.dayOptions.enabled.value!) {
            _listOptions.tap == null
                ? dataObjectTap(current, context)
                : _listOptions.tap!(current);
          } else {
            if (!_listOptions.dayOptions.lockUnchecks.requireValue) {
              await _listOptions.toggleSelected(current);
            } else if (!_listOptions.selectedLatest.containsKey(current.id) ||
                _listOptions.dayOptions.lockUnchecks.requireValue &&
                    await showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            content: Text(
                                'هل تريد إلغاء حضور ' + current.name + '؟'),
                            actions: [
                              TextButton(
                                onPressed: () =>
                                    navigator.currentState!.pop(true),
                                child: Text('تأكيد'),
                              ),
                              TextButton(
                                onPressed: () =>
                                    navigator.currentState!.pop(false),
                                child: Text('تراجع'),
                              ),
                            ],
                          ),
                        ) ==
                        true) {
              await _listOptions.toggleSelected(current);
            }
          }
        },
        attended.hasData && attended.data!.containsKey(current.id)
            ? Text(DateFormat('الساعة h : m د : s ث a', 'ar-EG')
                .format(attended.data![current.id]!.time.toDate()))
            : Container(),
        attended.hasData
            ? Checkbox(
                value: attended.data!.containsKey(current.id),
                onChanged: _listOptions.dayOptions.enabled.value!
                    ? (v) {
                        if (v!) {
                          _listOptions.select(current);
                        } else {
                          _listOptions.deselect(current);
                        }
                      }
                    : null,
              )
            : Checkbox(value: false, onChanged: null),
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _listOptions = widget.options ?? context.read<CheckListOptions<T>>();
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
                                          time: Timestamp.now(),
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
                                      color: Theme.of(context).primaryColor),
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
                                    DateTime.now().year,
                                    DateTime.now().month,
                                    DateTime.now().day,
                                    selected?.hour ?? initialValue.hour,
                                    selected?.minute ?? initialValue.minute);
                              },
                              onChanged: (t) async {
                                record!.time = Timestamp.fromDate(DateTime(
                                    DateTime.now().year,
                                    DateTime.now().month,
                                    DateTime.now().day,
                                    t!.hour,
                                    t.minute));
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
                                color: Theme.of(context).primaryColor),
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
                  dataObjectTap(current, context);
                },
                child: Text('عرض بيانات ' + current.name),
              ),
              if (_listOptions.dayOptions.enabled.value!)
                TextButton(
                  onPressed: () => navigator.currentState!.pop(true),
                  child: Text('حفظ'),
                ),
            ],
          ),
        ) ==
        true) {
      if (_listOptions.selectedLatest.containsKey(current.id) &&
          record != null) {
        await _listOptions.modifySelected(current,
            notes: record!.notes, time: record!.time);
      } else if (record != null) {
        await _listOptions.select(current,
            notes: record?.notes, time: record?.time);
      } else if (_listOptions.selectedLatest.containsKey(current.id) &&
          record == null) {
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
}
