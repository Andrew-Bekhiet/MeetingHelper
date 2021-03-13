import 'package:async/async.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:group_list_view/group_list_view.dart';
import 'package:meetinghelper/models/data_object_widget.dart';
import 'package:meetinghelper/models/list_options.dart';
import 'package:meetinghelper/models/mini_models.dart';
import 'package:meetinghelper/models/search_string.dart';
import 'package:meetinghelper/models/user.dart';
import 'package:meetinghelper/utils/helpers.dart';
import 'package:provider/provider.dart';
import 'package:tuple/tuple.dart';

class UsersEditList extends StatefulWidget {
  @override
  _UsersEditListState createState() => _UsersEditListState();
}

class UsersList extends StatefulWidget {
  UsersList({Key key}) : super(key: key);

  @override
  _UsersListState createState() => _UsersListState();
}

class _UsersEditListState extends State<UsersEditList> {
  List<User> _searchQuery;

  AsyncCache<List<User>> dataCache =
      AsyncCache<List<User>>(Duration(minutes: 5));

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () {
        dataCache.invalidate();
        return dataCache.fetch(User.getUsersForEdit);
      },
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('StudyYears')
            .orderBy('Grade')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return ErrorWidget.builder(snapshot.error);
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());
          return FutureBuilder<List<User>>(
            future: dataCache.fetch(User.getUsersForEdit),
            builder: (context, data) {
              if (data.hasError)
                return Text((data.error as FirebaseFunctionsException).message);
              if (!data.hasData)
                return const Center(child: CircularProgressIndicator());
              Map<String, StudyYear> studyYearByDocRef = {
                for (var s in snapshot.data.docs)
                  s.reference.id: StudyYear.fromDoc(s)
              };
              return Consumer<SearchString>(
                builder: (context, filter, _) {
                  if (filter.value.isNotEmpty)
                    _searchQuery = data.data
                        .where((u) => u.name
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
                            .contains(filter.value.toLowerCase()))
                        .toList();
                  else
                    _searchQuery = null;
                  if (_searchQuery == null)
                    mergeSort<User>(data.data, compare: (u, u2) {
                      if (u.servingStudyYear == null &&
                          u2.servingStudyYear == null) return 0;
                      if (u.servingStudyYear == null) return 1;
                      if (u2.servingStudyYear == null) return -1;
                      if (u.servingStudyYear == u2.servingStudyYear) {
                        if (u.servingStudyGender == u2.servingStudyGender)
                          return u.name.compareTo(u2.name);
                        return u.servingStudyGender
                                ?.compareTo(u.servingStudyGender) ??
                            1;
                      }
                      return studyYearByDocRef[u.servingStudyYear]
                          .grade
                          .compareTo(
                              studyYearByDocRef[u2.servingStudyYear].grade);
                    });
                  var groupedUsers = groupBy<User, Tuple2<String, bool>>(
                      _searchQuery ?? data.data,
                      (user) => Tuple2<String, bool>(
                          user.servingStudyYear, user.servingStudyGender));
                  return GroupListView(
                    sectionsCount: groupedUsers.length,
                    countOfItemInSection: (i) =>
                        groupedUsers.values.elementAt(i).length,
                    cacheExtent: 200,
                    groupHeaderBuilder: (contetx, i) {
                      if (groupedUsers.keys.elementAt(i).item1 == null)
                        return ListTile(title: Text('غير محدد'));
                      return ListTile(
                          title: Text(studyYearByDocRef[
                                      groupedUsers.keys.elementAt(i).item1]
                                  .name +
                              ' - ' +
                              (groupedUsers.keys.elementAt(i).item2 == true
                                  ? 'بنين'
                                  : (groupedUsers.keys.elementAt(i).item2 ==
                                          false
                                      ? 'بنات'
                                      : 'غير محدد'))));
                    },
                    itemBuilder: (context, i) {
                      User current = groupedUsers.values
                          .elementAt(i.section)
                          .elementAt(i.index);
                      return Card(
                        child: ListTile(
                          title: Text(current.name),
                          leading: current.getPhoto(),
                          onTap: () {
                            userTap(current, context);
                          },
                          subtitle: Text(
                            current.getPermissions(),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _UsersListState extends State<UsersList> {
  @override
  Widget build(BuildContext c) {
    return Consumer2<ListOptions<User>, SearchString>(
      builder: (context, options, filter, _) => StreamBuilder<List<User>>(
        stream: options.documentsData,
        builder: (context, stream) {
          if (stream.hasError) return Center(child: ErrorWidget(stream.error));
          if (!stream.hasData)
            return Center(child: CircularProgressIndicator());
          return Builder(
            builder: (context) {
              List<User> documentData = stream.data.sublist(0);
              if (filter.value != '')
                documentData.retainWhere((element) => element.name
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
                    .contains(filter.value));
              return ListView.builder(
                padding: EdgeInsets.symmetric(horizontal: 6),
                addAutomaticKeepAlives: (documentData?.length ?? 0) < 300,
                cacheExtent: 200,
                itemCount: documentData?.length ?? 0,
                itemBuilder: (context, i) {
                  var current = documentData[i];
                  return DataObjectWidget<User>(
                    current,
                    showSubTitle: false,
                    photo: current.getPhoto(),
                    onLongPress: User.instance.manageUsers
                        ? () => userTap(current, context)
                        : null,
                    onTap: () {
                      if (options.selected.contains(current)) {
                        setState(() {
                          options.selected.remove(current);
                        });
                      } else {
                        setState(() {
                          options.selected.add(current);
                        });
                      }
                    },
                    trailing: Checkbox(
                        value: options.selected.contains(current),
                        onChanged: (v) {
                          setState(() {
                            if (v) {
                              options.selected.add(current);
                            } else {
                              options.selected.remove(current);
                            }
                          });
                        }),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
