import 'package:collection/collection.dart';
import 'package:expandable/expandable.dart';
import 'package:flutter/material.dart';
import 'package:group_list_view/group_list_view.dart';
import 'package:meetinghelper/models/data_object_widget.dart';
import 'package:meetinghelper/models/list_options.dart';
export 'package:meetinghelper/models/list_options.dart'
    show ServicesListOptions;

import '../models/mini_models.dart';
import '../models/models.dart';
import '../utils/helpers.dart';

class ServicesList extends StatefulWidget {
  final ServicesListOptions options;
  ServicesList({Key key, this.options}) : super(key: key);
  @override
  _ServicesListState createState() => _ServicesListState();
}

class _ServicesListState extends State<ServicesList>
    with AutomaticKeepAliveClientMixin<ServicesList> {
  final Map<int, ExpandableController> _controllers = {};
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return StreamBuilder<Map<StudyYear, List<Class>>>(
      stream: widget.options.objectsData,
      builder: (context, services) {
        if (services.hasError) return ErrorWidget(services.error);
        if (!services.hasData)
          return const Center(child: CircularProgressIndicator());
        var groupedStudyYears = groupBy(services.data.keys, (s) {
          switch (s.grade) {
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
              return -1;
          }
        });
        return GroupListView(
          padding: EdgeInsets.symmetric(horizontal: 6),
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
            switch (groupedStudyYears.keys.elementAt(section)) {
              case 0:
                return ListTile(title: Text('KG'));
              case 1:
                return ListTile(title: Text('ابتدائي'));
              case 2:
                return ListTile(title: Text('اعدادي'));
              case 3:
                return ListTile(title: Text('ثانوي'));
              case 4:
                return ListTile(title: Text('جامعة'));
              default:
                return ListTile(title: Text('أخرى'));
            }
          },
          itemBuilder: (context, index) {
            var element = groupedStudyYears.values
                .elementAt(index.section)
                .elementAt(index.index);
            if (services.data[element].length > 1)
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
                          _controllers[hashValues(index.index, index.section)]
                              .toggle(),
                      leading: Icon(Icons.miscellaneous_services),
                      title: Text(element.name),
                      trailing: StreamBuilder<Map<String, Class>>(
                        stream: widget.options.selected,
                        builder: (context, snapshot) {
                          if (snapshot.hasData &&
                              widget.options.selectionModeLatest) {
                            return Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.arrow_drop_down),
                                Checkbox(
                                  value: services.data[element]
                                      .map((c) =>
                                          snapshot.data.containsKey(c.id))
                                      .fold<bool>(true, (o, n) => o && n),
                                  onChanged: (v) {
                                    if (v) {
                                      services.data[element].forEach(
                                        (c) => widget.options.select(c),
                                      );
                                    } else {
                                      services.data[element].forEach(
                                        (c) => widget.options.deselect(c),
                                      );
                                    }
                                  },
                                ),
                              ],
                            );
                          }
                          return Icon(Icons.arrow_drop_down);
                        },
                      ),
                    ),
                  ),
                  expanded: Padding(
                    padding: const EdgeInsets.fromLTRB(3, 0, 9, 0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: services.data[element]
                          .map(
                            (c) => DataObjectWidget<Class>(
                              c,
                              showSubTitle: false,
                              onTap: () {
                                if (!widget.options.selectionModeLatest) {
                                  widget.options.tap == null
                                      ? dataObjectTap(c, context)
                                      : widget.options.tap(c);
                                } else {
                                  widget.options.toggleSelected(c);
                                }
                              },
                              trailing: StreamBuilder<Map<String, Class>>(
                                stream: widget.options.selected,
                                builder: (context, snapshot) {
                                  if (snapshot.hasData &&
                                      widget.options.selectionModeLatest) {
                                    return Checkbox(
                                      value: snapshot.data.containsKey(c.id),
                                      onChanged: (v) {
                                        if (v) {
                                          widget.options.select(c);
                                        } else {
                                          widget.options.deselect(c);
                                        }
                                      },
                                    );
                                  }
                                  return Container(width: 1, height: 1);
                                },
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  theme: ExpandableThemeData(
                      tapHeaderToExpand: false,
                      useInkWell: true,
                      hasIcon: false),
                ),
              );
            else
              return Padding(
                padding: const EdgeInsets.fromLTRB(3, 0, 9, 0),
                child: DataObjectWidget<Class>(
                  services.data[element][0],
                  showSubTitle: false,
                  trailing: StreamBuilder<Map<String, Class>>(
                    stream: widget.options.selected,
                    builder: (context, snapshot) {
                      if (snapshot.hasData &&
                          widget.options.selectionModeLatest) {
                        return Checkbox(
                          value: snapshot.data
                              .containsKey(services.data[element][0].id),
                          onChanged: (v) {
                            if (v) {
                              widget.options.select(services.data[element][0]);
                            } else {
                              widget.options
                                  .deselect(services.data[element][0]);
                            }
                          },
                        );
                      }
                      return Container(width: 1, height: 1);
                    },
                  ),
                  onTap: () {
                    if (!widget.options.selectionModeLatest) {
                      widget.options.tap == null
                          ? dataObjectTap(services.data[element][0], context)
                          : widget.options.tap(services.data[element][0]);
                    } else {
                      widget.options.toggleSelected(services.data[element][0]);
                    }
                  },
                ),
              );
          },
        );
      },
    );
  }
}
