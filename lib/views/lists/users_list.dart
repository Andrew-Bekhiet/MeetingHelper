import 'package:flutter/material.dart';
import 'package:group_list_view/group_list_view.dart';
import 'package:meetinghelper/models/data/class.dart';
import 'package:meetinghelper/models/data/user.dart';
import 'package:meetinghelper/models/data_object_widget.dart';
import 'package:meetinghelper/models/list_controllers.dart';
import 'package:meetinghelper/models/super_classes.dart';
import 'package:meetinghelper/utils/helpers.dart';
import 'package:meetinghelper/utils/typedefs.dart';
import 'package:provider/provider.dart';
import 'package:rxdart/rxdart.dart';
import 'package:tuple/tuple.dart';

class UsersList extends StatefulWidget {
  final DataObjectListController<User>? listOptions;
  final bool autoDisposeController;

  const UsersList(
      {Key? key, this.listOptions, required this.autoDisposeController})
      : super(key: key);

  @override
  _UsersListState createState() => _UsersListState();
}

class _UsersListState extends State<UsersList> {
  late DataObjectListController<User> _listOptions;
  final BehaviorSubject<Map<JsonRef, bool?>> _openedNodes =
      BehaviorSubject.seeded({});

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _listOptions =
        widget.listOptions ?? context.read<DataObjectListController<User>>();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<JsonRef, Tuple2<Class, List<User>>>>(
      stream: Rx.combineLatest2<Map<JsonRef, Tuple2<Class, List<User>>>,
          Map<JsonRef, bool?>, Map<JsonRef, Tuple2<Class, List<User>>>>(
        _listOptions.objectsData.switchMap(usersByClassRef),
        _openedNodes,
        (g, n) => g.map(
          (k, v) => MapEntry(
            k,
            (n[k] ?? false) ? v : Tuple2<Class, List<User>>(v.item1, []),
          ),
        ),
      ),
      builder: (context, groupedData) {
        if (groupedData.hasError) return ErrorWidget(groupedData.error!);
        if (!groupedData.hasData)
          return const Center(child: CircularProgressIndicator());

        if (groupedData.data!.isEmpty)
          return const Center(child: Text('لا يوجد مستخدمين'));

        return GroupListView(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          sectionsCount: groupedData.data!.length + 1,
          countOfItemInSection: (i) {
            if (i == groupedData.data!.length) return 0;

            return groupedData.data!.values.elementAt(i).item2.length;
          },
          cacheExtent: 500,
          groupHeaderBuilder: (context, i) {
            if (i == groupedData.data!.length)
              return Container(height: MediaQuery.of(context).size.height / 19);

            final _class = groupedData.data!.values.elementAt(i).item1;

            return DataObjectWidget<Class>(
              _class,
              showSubTitle: false,
              wrapInCard: false,
              photo: DataObjectPhoto(
                _class,
                heroTag: _class.name + _class.id,
                wrapPhotoInCircle: false,
              ),
              onTap: () {
                _openedNodes.add({
                  ..._openedNodes.value,
                  groupedData.data!.keys.elementAt(i): !(_openedNodes
                          .value[groupedData.data!.keys.elementAt(i)] ??
                      false)
                });
              },
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: () {
                      _openedNodes.add({
                        ..._openedNodes.value,
                        groupedData.data!.keys.elementAt(i): !(_openedNodes
                                .value[groupedData.data!.keys.elementAt(i)] ??
                            false)
                      });
                    },
                    icon: Icon(
                      _openedNodes.value[groupedData.data!.keys.elementAt(i)] ??
                              false
                          ? Icons.arrow_drop_up
                          : Icons.arrow_drop_down,
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      if (_class.id != 'null' && _class.id != 'unknown')
                        classTap(_class);
                    },
                    icon: const Icon(Icons.info_outlined),
                  ),
                ],
              ),
            );
          },
          itemBuilder: (context, i) {
            final User current = groupedData.data!.values
                .elementAt(i.section)
                .item2
                .elementAt(i.index);
            return Padding(
              padding: const EdgeInsets.fromLTRB(3, 0, 9, 0),
              child: _listOptions.buildItem(
                current,
                onLongPress: _listOptions.onLongPress ??
                    (u) {
                      _listOptions.selectionMode
                          .add(!_listOptions.selectionMode.value);
                      if (_listOptions.selectionMode.value)
                        _listOptions.select(current);
                    },
                onTap: (User current) {
                  if (!_listOptions.selectionMode.value) {
                    _listOptions.tap == null
                        ? dataObjectTap(current)
                        : _listOptions.tap!(current);
                  } else {
                    _listOptions.toggleSelected(current);
                  }
                },
                trailing: StreamBuilder<Map<String, User>?>(
                  stream: Rx.combineLatest2<Map<String, User>, bool,
                          Map<String, User>?>(
                      _listOptions.selected,
                      _listOptions.selectionMode,
                      (Map<String, User> a, bool b) => b ? a : null),
                  builder: (context, snapshot) {
                    if (snapshot.hasData) {
                      return Checkbox(
                        value: snapshot.data!.containsKey(current.uid),
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
    if (widget.autoDisposeController) await _listOptions.dispose();
    await _openedNodes.close();
  }
}
