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
import 'List.dart';

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
      stream: widget.options.documentsData ??
          classesByStudyYearRef().asBroadcastStream(),
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
        return Scaffold(
          extendBody: true,
          body: Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: GroupListView(
              cacheExtent: 200,
              sectionsCount: groupedStudyYears.length,
              countOfItemInSection: (i) =>
                  groupedStudyYears.values.elementAt(i).length,
              groupHeaderBuilder: (context, section) {
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
                    padding: EdgeInsets.only(right: 7),
                    child: ExpandablePanel(
                        controller: _controllers[
                                hashValues(index.index, index.section)] ??=
                            ExpandableController(),
                        header: Card(
                          child: ListTile(
                              onTap: () => _controllers[
                                      hashValues(index.index, index.section)]
                                  .toggle(),
                              leading: Icon(Icons.miscellaneous_services),
                              title: Text(element.name),
                              trailing: widget.options.selectionMode
                                  ? Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.arrow_drop_down),
                                        Checkbox(
                                          value: services.data[element]
                                              .map((c) => widget
                                                  .options.selected
                                                  .contains(c))
                                              .fold<bool>(
                                                  true, (o, n) => o && n),
                                          onChanged: (v) {
                                            if (v) {
                                              services.data[element].forEach(
                                                  (c) => widget.options.selected
                                                      .add(c));
                                            } else {
                                              services.data[element].forEach(
                                                  (c) => widget.options.selected
                                                      .remove(c));
                                            }
                                            setState(() {});
                                          },
                                        ),
                                      ],
                                    )
                                  : Icon(Icons.arrow_drop_down)),
                        ),
                        expanded: Padding(
                          padding: EdgeInsets.only(right: 7),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: services.data[element]
                                .map(
                                  (c) => DataObjectWidget<Class>(
                                    c,
                                    showSubTitle: false,
                                    onTap: () {
                                      if (!widget.options.selectionMode) {
                                        widget.options.tap == null
                                            ? dataObjectTap(c, context)
                                            : widget.options.tap(c, context);
                                      } else if (widget.options.selected
                                          .contains(c)) {
                                        setState(() {
                                          widget.options.selected.remove(c);
                                        });
                                      } else {
                                        setState(() {
                                          widget.options.selected.add(c);
                                        });
                                      }
                                    },
                                    trailing: widget.options.selectionMode
                                        ? Checkbox(
                                            value: widget.options.selected
                                                .contains(c),
                                            onChanged: (v) {
                                              setState(() {
                                                if (v) {
                                                  widget.options.selected
                                                      .add(c);
                                                } else {
                                                  widget.options.selected
                                                      .remove(c);
                                                }
                                              });
                                            },
                                          )
                                        : null,
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                        theme: ExpandableThemeData(
                            tapHeaderToExpand: false,
                            useInkWell: true,
                            hasIcon: false)),
                  );
                else
                  return Padding(
                    padding: EdgeInsets.only(right: 7),
                    child: DataObjectWidget<Class>(
                      services.data[element][0],
                      showSubTitle: false,
                      trailing: widget.options.selectionMode
                          ? Checkbox(
                              value: widget.options.selected
                                  .contains(services.data[element][0]),
                              onChanged: (v) {
                                setState(() {
                                  if (v) {
                                    widget.options.selected
                                        .add(services.data[element][0]);
                                  } else {
                                    widget.options.selected
                                        .remove(services.data[element][0]);
                                  }
                                });
                              },
                            )
                          : null,
                      onTap: () {
                        if (!widget.options.selectionMode) {
                          widget.options.tap == null
                              ? dataObjectTap(
                                  services.data[element][0], context)
                              : widget.options
                                  .tap(services.data[element][0], context);
                        } else if (widget.options.selected
                            .contains(services.data[element][0])) {
                          setState(() {
                            widget.options.selected
                                .remove(services.data[element][0]);
                          });
                        } else {
                          setState(() {
                            widget.options.selected
                                .add(services.data[element][0]);
                          });
                        }
                      },
                    ),
                  );
              },
            ),
          ),
          floatingActionButtonLocation: widget.options.hasNotch
              ? FloatingActionButtonLocation.endDocked
              : null,
          floatingActionButton: widget.options.floatingActionButton,
          bottomNavigationBar: BottomAppBar(
            color: Theme.of(context).primaryColor,
            shape: widget.options.hasNotch
                ? widget.options.doubleActionButton
                    ? const DoubleCircularNotchedButton()
                    : const CircularNotchedRectangle()
                : null,
            child: Text((services.data?.length ?? 0).toString() + ' خدمة',
                textAlign: TextAlign.center,
                strutStyle:
                    StrutStyle(height: IconTheme.of(context).size / 7.5),
                style: Theme.of(context).primaryTextTheme.bodyText1),
          ),
        );
      },
    );
  }
}
