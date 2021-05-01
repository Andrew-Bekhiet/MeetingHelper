import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:group_list_view/group_list_view.dart';
import 'package:meetinghelper/models/class.dart';
import 'package:meetinghelper/models/data_object_widget.dart';
import 'package:meetinghelper/models/list_options.dart';
import 'package:meetinghelper/models/super_classes.dart';
import 'package:meetinghelper/models/user.dart';
import 'package:meetinghelper/utils/helpers.dart';
import 'package:provider/provider.dart';
import 'package:rxdart/rxdart.dart';
import 'package:tuple/tuple.dart';

class UsersList extends StatefulWidget {
  final DataObjectListOptions<User> listOptions;

  const UsersList({Key key, this.listOptions}) : super(key: key);

  @override
  _UsersListState createState() => _UsersListState();
}

class _UsersListState extends State<UsersList> {
  DataObjectListOptions<User> _listOptions;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _listOptions =
        widget.listOptions ?? context.read<DataObjectListOptions<User>>();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<User>>(
      stream: _listOptions.objectsData,
      builder: (context, options) {
        if (options.hasError) return Center(child: ErrorWidget(options.error));
        if (!options.hasData)
          return const Center(child: CircularProgressIndicator());

        final List<User> _data = options.data;
        if (_data.isEmpty) return const Center(child: Text('لا يوجد مستخدمين'));

        return StreamBuilder<Map<DocumentReference, Tuple2<Class, List<User>>>>(
          stream: usersByClassRef(_data),
          builder: (context, groupedData) {
            if (groupedData.hasError) return ErrorWidget(groupedData.error);
            if (!groupedData.hasData)
              return const Center(child: CircularProgressIndicator());

            return GroupListView(
              padding: EdgeInsets.symmetric(horizontal: 4),
              sectionsCount: groupedData.data.length + 1,
              countOfItemInSection: (i) {
                if (i == groupedData.data.length) return 0;

                return groupedData.data.values.elementAt(i).item2.length;
              },
              cacheExtent: 500,
              groupHeaderBuilder: (context, i) {
                if (i == groupedData.data.length)
                  return Container(
                      height: MediaQuery.of(context).size.height / 19);

                final _class = groupedData.data.values.elementAt(i).item1;

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
                    if (_class.id != 'null' && _class.id != 'unknown')
                      classTap(_class, context);
                  },
                );
              },
              itemBuilder: (context, i) {
                User current = groupedData.data.values
                    .elementAt(i.section)
                    .item2
                    .elementAt(i.index);
                return Padding(
                  padding: const EdgeInsets.fromLTRB(3, 0, 9, 0),
                  child: _listOptions.itemBuilder(
                    current,
                    onLongPress: _listOptions.onLongPress ??
                        (u) {
                          _listOptions.selectionMode
                              .add(!_listOptions.selectionModeLatest);
                          if (_listOptions.selectionModeLatest)
                            _listOptions.select(current);
                        },
                    onTap: (User current) {
                      if (!_listOptions.selectionModeLatest) {
                        _listOptions.tap == null
                            ? dataObjectTap(current, context)
                            : _listOptions.tap(current);
                      } else {
                        _listOptions.toggleSelected(current);
                      }
                    },
                    trailing: StreamBuilder<Map<String, User>>(
                      stream: Rx.combineLatest2(_listOptions.selected,
                          _listOptions.selectionMode, (a, b) => b ? a : null),
                      builder: (context, snapshot) {
                        if (snapshot.hasData) {
                          return Checkbox(
                            value: snapshot.data.containsKey(current.uid),
                            onChanged: (v) {
                              if (v) {
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
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
