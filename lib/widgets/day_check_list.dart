import 'dart:async';

import 'package:churchdata_core/churchdata_core.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:group_list_view/group_list_view.dart';
import 'package:intl/intl.dart';
import 'package:meetinghelper/controllers/list_controllers.dart';
import 'package:meetinghelper/models.dart';
import 'package:meetinghelper/utils/globals.dart';
import 'package:meetinghelper/utils/helpers.dart';
import 'package:rxdart/rxdart.dart';

export 'package:tuple/tuple.dart';

class DayCheckList<G, T extends Person> extends StatefulWidget {
  final DayCheckListController<G, T> controller;

  ///Optional: override the default build function for items
  ///
  ///Provides the default [onTap] and [onLongPress] callbacks
  ///and default [trailing] and [subtitle] widgets
  final ItemBuilder<T>? itemBuilder;

  ///The build function for groups
  ///
  ///Provides the default [onTap] and [onLongPress] callbacks
  ///and default [trailing] and [subtitle] widgets
  final GroupBuilder<G>? groupBuilder;

  ///Optional: override the default [onTap] callback
  final void Function(T)? onTap;

  ///Optional: override the default [onLongPress] callback
  final void Function(T)? onLongPress;

  ///Wether to dispose [controller] when the widget is disposed
  final bool autoDisposeController;

  ///Optional string to show when there are no items
  final String? emptyMsg;

  const DayCheckList({
    required this.controller,
    required this.autoDisposeController,
    super.key,
    this.itemBuilder,
    this.groupBuilder,
    this.onTap,
    this.onLongPress,
    this.emptyMsg = 'لا يوجد مخدومين',
  });

  @override
  _DayCheckListState<G, T> createState() => _DayCheckListState<G, T>();
}

class _DayCheckListState<G, T extends Person> extends State<DayCheckList<G, T>>
    with AutomaticKeepAliveClientMixin<DayCheckList<G, T>> {
  bool _builtOnce = false;

  DayCheckListController<G, T> get _listController => widget.controller;

  ItemBuilder<T> get _buildItem => widget.itemBuilder ?? defaultItemBuilder<T>;
  GroupBuilder<G> get _buildGroup =>
      widget.groupBuilder ??
      (
        o, {
        onLongPress,
        onTap,
        onTapOnNull,
        showSubtitle,
        trailing,
        subtitle,
      }) =>
          defaultGroupBuilder<DataObject>(
            o as DataObject?,
            onLongPress:
                onLongPress != null ? (o) => onLongPress(o as G) : null,
            onTap: onTap != null ? (o) => onTap(o as G) : null,
            onTapOnNull: onTapOnNull,
            showSubtitle: showSubtitle,
            trailing: trailing,
            subtitle: subtitle,
          );

  @override
  bool get wantKeepAlive => _builtOnce && ModalRoute.of(context)!.isCurrent;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    _builtOnce = true;
    updateKeepAlive();

    return StreamBuilder<bool>(
      stream: _listController.dayOptions.grouped,
      builder: (context, grouped) {
        if (grouped.hasError) return Center(child: ErrorWidget(grouped.error!));
        if (!grouped.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        if (grouped.data!) {
          return buildGroupedListView();
        } else {
          return buildListView();
        }
      },
    );
  }

  Widget buildGroupedListView() {
    return StreamBuilder<Map<G, List<T>>>(
      stream: _listController.groupedObjectsStream,
      builder: (context, groupedData) {
        if (groupedData.hasError) return ErrorWidget(groupedData.error!);

        if (!groupedData.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        if (groupedData.data!.isEmpty) {
          return Center(child: Text(widget.emptyMsg ?? 'لا يوجد عناصر'));
        }

        return GroupListView(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          sectionsCount: groupedData.data!.length + 1,
          countOfItemInSection: (i) {
            if (i == groupedData.data!.length) return 0;

            return groupedData.data!.values.elementAt(i).length;
          },
          cacheExtent: 500,
          groupHeaderBuilder: (context, i) {
            if (i == groupedData.data!.length) {
              return Container(height: MediaQuery.of(context).size.height / 15);
            }

            return StreamBuilder<bool?>(
              stream: _listController.dayOptions.showSubtitlesInGroups,
              builder: (context, showSubtitle) {
                return Container(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: _buildGroup(
                    groupedData.data!.keys.elementAt(i),
                    showSubtitle: showSubtitle.data ?? false,
                    subtitle: showSubtitle.data ?? false
                        ? Text(
                            'يتم عرض ' +
                                groupedData.data!.values
                                    .elementAt(i)
                                    .length
                                    .toString() +
                                ' مخدوم داخل الفصل',
                          )
                        : null,
                    onTap: _listController.toggleGroup,
                    trailing: IconButton(
                      onPressed: () {
                        _listController.toggleGroup(
                          groupedData.data!.keys.elementAt(i),
                        );
                      },
                      icon: Icon(
                        _listController.currentOpenedGroups!
                                .contains(groupedData.data!.keys.elementAt(i))
                            ? Icons.arrow_drop_up
                            : Icons.arrow_drop_down,
                      ),
                    ),
                  ),
                );
              },
            );
          },
          itemBuilder: (context, i) {
            final T current =
                groupedData.data!.values.elementAt(i.section)[i.index];
            return Padding(
              padding: const EdgeInsets.fromLTRB(3, 0, 9, 0),
              child: buildItemWrapper(current),
            );
          },
        );
      },
    );
  }

  Widget buildListView() {
    return StreamBuilder<List<T>>(
      stream: _listController.objectsStream,
      builder: (context, data) {
        if (data.hasError) return Center(child: ErrorWidget(data.error!));
        if (!data.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final List<T> _data = data.data!;
        if (_data.isEmpty) {
          return Center(child: Text(widget.emptyMsg ?? 'لا يوجد عناصر'));
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          addAutomaticKeepAlives: _data.length < 500,
          cacheExtent: 200,
          itemCount: _data.length + 1,
          itemBuilder: (context, i) {
            if (i == _data.length) {
              return Container(height: MediaQuery.of(context).size.height / 19);
            }

            final T current = _data[i];
            return buildItemWrapper(current);
          },
        );
      },
    );
  }

  Widget buildItemWrapper(T current) {
    return StreamBuilder<Map<String, HistoryRecord>>(
      stream: _listController.dayOptions.enabled
          .switchMap((_) => _listController.attended),
      builder: (context, attended) => _buildItem(
        current,
        onLongPress: widget.onLongPress ??
            ((o) => _showRecordDialog(
                  o,
                  _listController.attended.value[current.id],
                )),
        onTap: (current) async {
          if (!_listController.dayOptions.enabled.value) {
            widget.onTap == null
                ? GetIt.I<MHViewableObjectService>().onTap(current)
                : widget.onTap!(current);
          } else {
            if (!_listController.dayOptions.lockUnchecks.value) {
              await _listController.toggleSelected(current);
            } else if (!attended.data!.containsKey(current.id) ||
                _listController.dayOptions.lockUnchecks.value &&
                    await showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            content: Text(
                              'هل تريد إلغاء حضور ' + current.name + '؟',
                            ),
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
              await _listController.toggleSelected(current);
            }
          }
        },
        subtitle: attended.hasData && attended.data!.containsKey(current.id)
            ? Text(
                DateFormat('الساعة h : m د : s ث a', 'ar-EG')
                    .format(attended.data![current.id]!.time.toDate()),
              )
            : null,
        trailing: attended.hasData
            ? Checkbox(
                value: attended.data!.containsKey(current.id),
                onChanged: _listController.dayOptions.enabled.value
                    ? (v) {
                        if (v!) {
                          _listController.select(current);
                        } else {
                          _listController.deselect(current);
                        }
                      }
                    : null,
              )
            : const Checkbox(value: false, onChanged: null),
      ),
    );
  }

  Future<void> _showRecordDialog(T current, HistoryRecord? oRecord) async {
    var record = oRecord != null
        ? HistoryRecord(
            classId: current.classId,
            id: oRecord.id,
            notes: oRecord.notes,
            parent: oRecord.parent,
            // ignore: unnecessary_null_checks
            recordedBy: oRecord.recordedBy!,
            time: oRecord.time,
            type: oRecord.type,
            studyYear: oRecord.studyYear,
            services: notService(oRecord.type ?? '')
                ? current.services
                : [
                    GetIt.I<DatabaseRepository>()
                        .collection('Services')
                        .doc(oRecord.type),
                  ],
            isServant: T == User,
          )
        : null;
    if (await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(current.name),
            content: StreamBuilder<bool>(
              initialData: _listController.dayOptions.enabled.value,
              stream: _listController.dayOptions.enabled,
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
                                        classId: current.classId,
                                        id: current.id,
                                        parent: _listController.day,
                                        type: _listController.type,
                                        recordedBy: User.instance.uid,
                                        services: _listController.type ==
                                                    'Meeting' ||
                                                _listController.type ==
                                                    'Kodas' ||
                                                _listController.type ==
                                                    'Confession'
                                            ? current.services
                                            : [
                                                GetIt.I<DatabaseRepository>()
                                                    .collection('Services')
                                                    .doc(_listController.type),
                                              ],
                                        studyYear: current.studyYear,
                                        time: _listController.day.day
                                            .toDate()
                                            .replaceTime(
                                              DateTime.now(),
                                            )
                                            .toTimestamp(),
                                        isServant: T == User,
                                      );
                                    } else {
                                      record = null;
                                    }
                                    setState(() {});
                                  }
                                : null,
                          ),
                          Expanded(
                            child: TappableFormField<TimeOfDay?>(
                              autovalidateMode:
                                  AutovalidateMode.onUserInteraction,
                              decoration: (context, state) => InputDecoration(
                                enabled:
                                    record != null && (enabled.data ?? false),
                                labelText: 'وقت الحضور',
                              ),
                              initialValue: record?.time != null
                                  ? TimeOfDay.fromDateTime(
                                      record!.time.toDate(),
                                    )
                                  : TimeOfDay.now(),
                              onTap: (state) async {
                                if (record == null ||
                                    !(enabled.data ?? false)) {
                                  return;
                                }

                                final selected = await showTimePicker(
                                  initialTime: state.value!,
                                  context: context,
                                );

                                if (selected != null &&
                                    selected != state.value!) {
                                  record = record!.copyWith.time(
                                    _listController.day.day
                                        .toDate()
                                        .replaceTimeOfDay(selected)
                                        .toTimestamp(),
                                  );

                                  state.didChange(selected);
                                  setState(() {});
                                }
                              },
                              builder: (context, state) {
                                return state.value != null
                                    ? Text(
                                        DateFormat(
                                          'الساعة h : m د : s ث a',
                                          'ar-EG',
                                        ).format(
                                          DateTime(
                                            2023,
                                            1,
                                            1,
                                            state.value!.hour,
                                            state.value!.minute,
                                          ),
                                        ),
                                      )
                                    : null;
                              },
                            ),
                          ),
                        ],
                      ),
                      Container(height: 10),
                      TextFormField(
                        decoration: const InputDecoration(
                          labelText: 'ملاحظات',
                        ),
                        textInputAction: TextInputAction.done,
                        initialValue: record?.notes ?? '',
                        enabled: record != null && (enabled.data ?? false),
                        onChanged: (n) => setState(
                          () => record = record!.copyWith.notes(n),
                        ),
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
                  GetIt.I<MHViewableObjectService>().onTap(current);
                },
                child: Text('عرض بيانات ' + current.name),
              ),
              if (_listController.dayOptions.enabled.value)
                TextButton(
                  onPressed: () => navigator.currentState!.pop(true),
                  child: const Text('حفظ'),
                ),
            ],
          ),
        ) ==
        true) {
      if ((_listController.currentAttended?.containsKey(current.id) ?? false) &&
          record != null) {
        await _listController.modifySelected(
          current,
          notes: record!.notes,
          time: record!.time,
        );
      } else if (record != null) {
        await _listController.select(
          current,
          notes: record?.notes,
          time: record?.time,
        );
      } else if (_listController.currentAttended?.containsKey(current.id) ??
          false) {
        await _listController.deselect(current);
      }
    }
  }

  @override
  Future<void> dispose() async {
    super.dispose();
    if (widget.autoDisposeController) await _listController.dispose();
  }
}
