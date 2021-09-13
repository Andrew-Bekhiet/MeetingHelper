import 'package:collection/collection.dart';
import 'package:expandable/expandable.dart';
import 'package:flutter/material.dart';
import 'package:group_list_view/group_list_view.dart';
import 'package:meetinghelper/models/data_object_widget.dart';
import 'package:meetinghelper/models/list_controllers.dart';
import 'package:meetinghelper/models/super_classes.dart';

import '../models/mini_models.dart';
import '../utils/helpers.dart';

export 'package:meetinghelper/models/list_controllers.dart'
    show ServicesListController;

class ServicesList<T extends DataObject> extends StatefulWidget {
  final ServicesListController<T> options;
  final bool autoDisposeController;

  const ServicesList(
      {Key? key, required this.options, required this.autoDisposeController})
      : super(key: key);
  @override
  _ServicesListState<T> createState() => _ServicesListState<T>();
}

class _ServicesListState<T extends DataObject> extends State<ServicesList<T>>
    with AutomaticKeepAliveClientMixin<ServicesList<T>> {
  final Map<int, ExpandableController> _controllers = {};

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return StreamBuilder<Map<PreferredStudyYear?, List<T>>?>(
      stream: widget.options.objectsData,
      builder: (context, services) {
        if (services.hasError) return ErrorWidget(services.error!);
        if (!services.hasData)
          return const Center(child: CircularProgressIndicator());

        final groupedStudyYears = {
          for (final entry in groupBy<PreferredStudyYear?, double>(
                  services.data!.keys, (PreferredStudyYear? s) {
            if (s?.preferredGroup != null) return s!.preferredGroup!;

            switch (s?.grade) {
              case -1:
              case 0:
                return 0;
              case 1:
              case 2:
              case 3:
              case 4:
              case 5:
              case 6:
                return 1;
              case 7:
              case 8:
              case 9:
                return 2;
              case 10:
              case 11:
              case 12:
                return 3;
              case 13:
              case 14:
              case 15:
              case 16:
              case 17:
              case 18:
                return 4;
              default:
                return 5;
            }
          })
              .entries
              .sortedByCompare<double>((e) => e.key, (o, n) => o.compareTo(n)))
            entry.key: entry.value
        };
        return GroupListView(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          cacheExtent: 200,
          sectionsCount: groupedStudyYears.length + 1,
          countOfItemInSection: (i) => groupedStudyYears.values.length > i
              ? groupedStudyYears.values.elementAt(i).length
              : 0,
          groupHeaderBuilder: (context, section) {
            if (groupedStudyYears.keys.length == section)
              return Container(
                height: 50,
              );

            final service =
                groupedStudyYears.keys.elementAt(section).truncate() !=
                        groupedStudyYears.keys.elementAt(section)
                    ? 'خدمات '
                    : '';

            if (groupedStudyYears.keys.elementAt(section).truncate() < 1)
              return ListTile(title: Text(service + 'KG'));
            else if (groupedStudyYears.keys.elementAt(section).truncate() < 2)
              return ListTile(title: Text(service + 'ابتدائي'));
            else if (groupedStudyYears.keys.elementAt(section).truncate() < 3)
              return ListTile(title: Text(service + 'اعدادي'));
            else if (groupedStudyYears.keys.elementAt(section).truncate() < 4)
              return ListTile(title: Text(service + 'ثانوي'));
            else if (groupedStudyYears.keys.elementAt(section).truncate() < 5)
              return ListTile(title: Text(service + 'جامعة'));
            else
              return const ListTile(title: Text('خدمات أخرى'));
          },
          itemBuilder: (context, index) {
            final studyYear = groupedStudyYears.values
                .elementAt(index.section)
                .elementAt(index.index);

            if (studyYear == null)
              return Padding(
                padding: const EdgeInsets.fromLTRB(3, 0, 9, 0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: services.data![studyYear]!.map(
                    (c) {
                      return DataObjectWidget(
                        c,
                        showSubTitle: false,
                        onTap: () {
                          if (!widget.options.selectionModeLatest) {
                            widget.options.tap == null
                                ? dataObjectTap(c)
                                : widget.options.tap!(c);
                          } else {
                            widget.options.toggleSelected(c);
                          }
                        },
                        trailing: StreamBuilder<Map<String, DataObject>>(
                          stream: widget.options.selected,
                          builder: (context, snapshot) {
                            if (snapshot.hasData &&
                                widget.options.selectionModeLatest) {
                              return Checkbox(
                                value: snapshot.data!.containsKey(c.id),
                                onChanged: (v) {
                                  if (v!) {
                                    widget.options.select(c);
                                  } else {
                                    widget.options.deselect(c);
                                  }
                                },
                              );
                            }
                            return const SizedBox(width: 1, height: 1);
                          },
                        ),
                      );
                    },
                  ).toList(),
                ),
              );

            if (services.data![studyYear]!.length > 1)
              return Padding(
                padding: const EdgeInsets.fromLTRB(3, 0, 9, 0),
                child: ExpandablePanel(
                  collapsed: Container(),
                  controller:
                      _controllers[hashValues(index.index, index.section)] ??=
                          ExpandableController(),
                  header: Card(
                    child: ListTile(
                      onTap: () =>
                          _controllers[hashValues(index.index, index.section)]!
                              .toggle(),
                      leading: const Icon(Icons.miscellaneous_services),
                      title: Text(studyYear.name),
                      trailing: StreamBuilder<Map<String, DataObject>>(
                        stream: widget.options.selected,
                        builder: (context, snapshot) {
                          if (snapshot.hasData &&
                              widget.options.selectionModeLatest) {
                            return Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.arrow_drop_down),
                                Checkbox(
                                  tristate: true,
                                  value: services.data![studyYear]!
                                          .map((c) =>
                                              snapshot.data!.containsKey(c.id))
                                          .every((e) => e)
                                      ? true
                                      : services.data![studyYear]!
                                              .map((c) => snapshot.data!
                                                  .containsKey(c.id))
                                              .every((e) => !e)
                                          ? false
                                          : null,
                                  onChanged: (v) {
                                    if (v ?? false) {
                                      for (final c
                                          in services.data![studyYear]!) {
                                        widget.options.select(c);
                                      }
                                    } else {
                                      for (final c
                                          in services.data![studyYear]!) {
                                        widget.options.deselect(c);
                                      }
                                    }
                                  },
                                ),
                              ],
                            );
                          }
                          return const Icon(Icons.arrow_drop_down);
                        },
                      ),
                    ),
                  ),
                  expanded: Padding(
                    padding: const EdgeInsets.fromLTRB(3, 0, 9, 0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: services.data![studyYear]!.map(
                        (c) {
                          return DataObjectWidget(
                            c,
                            showSubTitle: false,
                            onTap: () {
                              if (!widget.options.selectionModeLatest) {
                                widget.options.tap == null
                                    ? dataObjectTap(c)
                                    : widget.options.tap!(c);
                              } else {
                                widget.options.toggleSelected(c);
                              }
                            },
                            trailing: StreamBuilder<Map<String, DataObject>>(
                              stream: widget.options.selected,
                              builder: (context, snapshot) {
                                if (snapshot.hasData &&
                                    widget.options.selectionModeLatest) {
                                  return Checkbox(
                                    value: snapshot.data!.containsKey(c.id),
                                    onChanged: (v) {
                                      if (v!) {
                                        widget.options.select(c);
                                      } else {
                                        widget.options.deselect(c);
                                      }
                                    },
                                  );
                                }
                                return const SizedBox(width: 1, height: 1);
                              },
                            ),
                          );
                        },
                      ).toList(),
                    ),
                  ),
                  theme: const ExpandableThemeData(
                      tapHeaderToExpand: false,
                      useInkWell: true,
                      hasIcon: false),
                ),
              );
            else
              return Padding(
                padding: const EdgeInsets.fromLTRB(3, 0, 9, 0),
                child: DataObjectWidget(
                  services.data![studyYear]![0],
                  showSubTitle: false,
                  trailing: StreamBuilder<Map<String, DataObject>>(
                    stream: widget.options.selected,
                    builder: (context, snapshot) {
                      if (snapshot.hasData &&
                          widget.options.selectionModeLatest) {
                        return Checkbox(
                          value: snapshot.data!
                              .containsKey(services.data![studyYear]![0].id),
                          onChanged: (v) {
                            if (v!) {
                              widget.options
                                  .select(services.data![studyYear]![0]);
                            } else {
                              widget.options
                                  .deselect(services.data![studyYear]![0]);
                            }
                          },
                        );
                      }
                      return const SizedBox(width: 1, height: 1);
                    },
                  ),
                  onTap: () {
                    if (!widget.options.selectionModeLatest) {
                      widget.options.tap == null
                          ? dataObjectTap(services.data![studyYear]![0])
                          : widget.options.tap!(services.data![studyYear]![0]);
                    } else {
                      widget.options
                          .toggleSelected(services.data![studyYear]![0]);
                    }
                  },
                ),
              );
          },
        );
      },
    );
  }

  @override
  Future<void> dispose() async {
    super.dispose();
    if (widget.autoDisposeController) await widget.options.dispose();
  }
}
