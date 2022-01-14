import 'package:churchdata_core/churchdata_core.dart';
import 'package:flutter/material.dart';
import 'package:group_list_view/group_list_view.dart';
import 'package:meetinghelper/models/data/class.dart';
import 'package:meetinghelper/models/data/user.dart';
import 'package:meetinghelper/utils/helpers.dart';
import 'package:provider/provider.dart';
import 'package:rxdart/rxdart.dart';
import 'package:tuple/tuple.dart';

class UsersList extends StatefulWidget {
  final ListController<void, User>? listOptions;
  final bool autoDisposeController;

  final ItemBuilder<User>? itemBuilder;
  // final GroupBuilder<G> groupBuilder;
  final void Function(User)? onTap;
  final void Function(User)? onLongPress;

  const UsersList({
    Key? key,
    this.listOptions,
    required this.autoDisposeController,
    this.itemBuilder,
    //this.groupBuilder,
    this.onTap,
    this.onLongPress,
  }) : super(key: key);

  @override
  _UsersListState createState() => _UsersListState();
}

class _UsersListState extends State<UsersList> {
  late ListController<void, User> _listOptions;
  final BehaviorSubject<Map<JsonRef, bool?>> _openedNodes =
      BehaviorSubject.seeded({});

  ItemBuilder<User> get buildItem =>
      widget.itemBuilder ?? defaultItemBuilder<User>;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _listOptions =
        widget.listOptions ?? context.read<ListController<void, User>>();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<JsonRef, Tuple2<Class, List<User>>>>(
      stream: Rx.combineLatest2<Map<JsonRef, Tuple2<Class, List<User>>>,
          Map<JsonRef, bool?>, Map<JsonRef, Tuple2<Class, List<User>>>>(
        _listOptions.objectsStream.switchMap(usersByClassRef),
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
              showSubtitle: false,
              wrapInCard: false,
              photo: PhotoObjectWidget(
                _class,
                heroTag: _class.name + _class.id,
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
              child: buildItem(
                current,
                onLongPress: widget.onLongPress ??
                    (u) {
                      _listOptions.select(u);
                    },
                onTap: (User current) {
                  if (_listOptions.currentSelection == null) {
                    widget.onTap == null
                        ? dataObjectTap(current)
                        : widget.onTap!(current);
                  } else {
                    _listOptions.toggleSelected(current);
                  }
                },
                trailing: StreamBuilder<Set<User>?>(
                  stream: _listOptions.selectionStream,
                  builder: (context, snapshot) {
                    if (snapshot.hasData) {
                      return Checkbox(
                        value: snapshot.data!.contains(current),
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
