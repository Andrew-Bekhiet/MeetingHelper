import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:meetinghelper/models/class.dart';
import 'package:meetinghelper/models/data_object_widget.dart';
import 'package:meetinghelper/models/list_options.dart';
import 'package:meetinghelper/models/search_filters.dart';
import 'package:meetinghelper/models/user.dart';
import 'package:meetinghelper/utils/globals.dart';
import 'package:meetinghelper/views/services_list.dart';
import 'package:meetinghelper/views/lists/users_list.dart';
import 'package:meetinghelper/utils/helpers.dart';
import 'package:rxdart/rxdart.dart';
import 'package:share_plus/share_plus.dart';

import '../edit_page/edit_user.dart';

class UserInfo extends StatefulWidget {
  UserInfo({Key key}) : super(key: key);

  @override
  _UserInfoState createState() => _UserInfoState();
}

class _UserInfoState extends State<UserInfo> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<User>(
        initialData: ModalRoute.of(context).settings.arguments,
        stream: (ModalRoute.of(context).settings.arguments as User)
            .ref
            .snapshots()
            .map(User.fromDoc),
        builder: (context, data) {
          User user = data.data;
          return NestedScrollView(
            headerSliverBuilder: (context, _) => <Widget>[
              SliverAppBar(
                actions: <Widget>[
                  IconButton(
                    icon: Icon(Icons.edit),
                    onPressed: () async {
                      dynamic result = await navigator.currentState.push(
                        MaterialPageRoute(
                          builder: (co) => EditUser(user: user),
                        ),
                      );
                      if (result is DocumentReference) {
                        scaffoldMessenger.currentState.showSnackBar(
                          SnackBar(
                            content: Text('تم الحفظ بنجاح'),
                          ),
                        );
                      } else if (result == 'deleted')
                        navigator.currentState.pop();
                    },
                    tooltip: 'تعديل',
                  ),
                  IconButton(
                    icon: Icon(Icons.share),
                    onPressed: () async {
                      await Share.share(await shareUser(user));
                    },
                    tooltip: 'مشاركة',
                  ),
                ],
                expandedHeight: 250.0,
                floating: false,
                pinned: true,
                flexibleSpace: LayoutBuilder(
                  builder: (context, constraints) => FlexibleSpaceBar(
                    title: AnimatedOpacity(
                      duration: Duration(milliseconds: 300),
                      opacity: constraints.biggest.height > kToolbarHeight * 1.7
                          ? 0
                          : 1,
                      child: Text(user.name,
                          style: TextStyle(
                            fontSize: 16.0,
                          )),
                    ),
                    background: user.getPhoto(false, false),
                  ),
                ),
              ),
            ],
            body: ListView(
              children: <Widget>[
                Text(user.name, style: Theme.of(context).textTheme.headline6),
                ListTile(
                  title: Text('البريد الاكتروني:'),
                  subtitle: Text(user.email ?? ''),
                ),
                ListTile(
                  title: Text('أخر ظهور على البرنامج:'),
                  subtitle: StreamBuilder(
                    stream: FirebaseDatabase.instance
                        .reference()
                        .child('Users/${user.uid}/lastSeen')
                        .onValue,
                    builder: (context, activity) {
                      if (activity.data?.snapshot?.value == 'Active') {
                        return Text('نشط الآن');
                      } else if (activity.data?.snapshot?.value != null) {
                        return Text(toDurationString(
                            Timestamp.fromMillisecondsSinceEpoch(
                                activity.data.snapshot.value)));
                      }
                      return Text('لا يمكن التحديد');
                    },
                  ),
                ),
                ListTile(
                  title: Text('تاريخ اخر تناول:'),
                  subtitle: Row(
                    children: <Widget>[
                      Expanded(
                        child: user.lastTanawol != null
                            ? Text(toDurationString(user.lastTanawol))
                            : Text('لا يمكن التحديد'),
                      ),
                      Text(
                          user.lastTanawolDate != null
                              ? DateFormat('yyyy/M/d')
                                  .format(user.lastTanawolDate)
                              : '',
                          style: Theme.of(context).textTheme.overline),
                    ],
                  ),
                ),
                ListTile(
                  title: Text('تاريخ اخر اعتراف:'),
                  subtitle: Row(
                    children: <Widget>[
                      Expanded(
                        child: user.lastConfession != null
                            ? Text(toDurationString(user.lastConfession))
                            : Text('لا يمكن التحديد'),
                      ),
                      Text(
                          user.lastConfessionDate != null
                              ? DateFormat('yyyy/M/d')
                                  .format(user.lastConfessionDate)
                              : '',
                          style: Theme.of(context).textTheme.overline),
                    ],
                  ),
                ),
                ListTile(
                  title: Text('داخل فصل:'),
                  subtitle:
                      user.classId != null && user.classId.parent.id != 'null'
                          ? FutureBuilder<Class>(
                              future: Class.fromId(user.classId.id),
                              builder: (context, _class) => _class.hasData
                                  ? DataObjectWidget<Class>(_class.data,
                                      isDense: true)
                                  : LinearProgressIndicator(),
                            )
                          : Text('غير موجود'),
                ),
                ListTile(
                  title: Text('الصلاحيات:'),
                  subtitle: Column(
                    children: [
                      if (user.manageUsers == true)
                        ListTile(
                          leading: Icon(const IconData(0xef3d,
                              fontFamily: 'MaterialIconsR')),
                          title: Text('إدارة المستخدمين'),
                        ),
                      if (user.manageAllowedUsers == true)
                        ListTile(
                          leading: Icon(const IconData(0xef3d,
                              fontFamily: 'MaterialIconsR')),
                          title: Text('إدارة مستخدمين محددين'),
                        ),
                      if (user.superAccess == true)
                        ListTile(
                          leading: Icon(const IconData(0xef56,
                              fontFamily: 'MaterialIconsR')),
                          title: Text('رؤية جميع البيانات'),
                        ),
                      if (user.manageDeleted == true)
                        ListTile(
                          leading: Icon(Icons.delete_outlined),
                          title: Text('استرجاع المحذوفات'),
                        ),
                      if (user.secretary == true)
                        ListTile(
                          leading: Icon(Icons.shield),
                          title: Text('تسجيل حضور الخدام'),
                        ),
                      if (user.write == true)
                        ListTile(
                          leading: Icon(Icons.edit),
                          title: Text('تعديل البيانات'),
                        ),
                      if (user.exportClasses == true)
                        ListTile(
                          leading: Icon(Icons.cloud_download),
                          title: Text('تصدير فصل لملف إكسل'),
                        ),
                      if (user.birthdayNotify == true)
                        ListTile(
                          leading: Icon(Icons.cake),
                          title: Text('إشعار أعياد الميلاد'),
                        ),
                      if (user.confessionsNotify == true)
                        ListTile(
                          leading: Icon(Icons.notifications_active),
                          title: Text('إشعار الاعتراف'),
                        ),
                      if (user.tanawolNotify == true)
                        ListTile(
                          leading: Icon(Icons.notifications_active),
                          title: Text('إشعار التناول'),
                        ),
                      if (user.kodasNotify == true)
                        ListTile(
                          leading: Icon(Icons.notifications_active),
                          title: Text('إشعار القداس'),
                        ),
                      if (user.meetingNotify == true)
                        ListTile(
                          leading: Icon(Icons.notifications_active),
                          title: Text('إشعار حضور الاجتماع'),
                        ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  label: Text('رؤية البيانات كما يراها ' + user.name),
                  icon: Icon(Icons.visibility),
                  onPressed: () => showDialog(
                    context: context,
                    builder: (context) => Dialog(
                      child: Column(
                        children: [
                          Text(
                            'يستطيع ' +
                                user.name +
                                ' رؤية ${user.write ? 'وتعديل ' : ''}الفصول التالية:',
                            style: Theme.of(context).textTheme.headline6,
                          ),
                          Expanded(
                            child: ServicesList(
                              options: ServicesListOptions(
                                searchQuery: Stream.value(''),
                                tap: (c) => classTap(c, context),
                                itemsStream: user.superAccess
                                    ? classesByStudyYearRef()
                                    : classesByStudyYearRefForUser(user.uid),
                              ),
                            ),
                          )
                        ],
                      ),
                    ),
                  ),
                ),
                ElevatedButton.icon(
                  label: Text('المستخدمين المسؤول عنهم ' + user.name,
                      textScaleFactor: 0.95, overflow: TextOverflow.fade),
                  icon: Icon(Icons.shield),
                  onPressed: () => navigator.currentState.push(
                    MaterialPageRoute(
                      builder: (context) {
                        final BehaviorSubject<String> searchStream =
                            BehaviorSubject<String>.seeded('');
                        final listOptions = DataObjectListOptions<User>(
                          searchQuery: searchStream,
                          itemsStream: FirebaseFirestore.instance
                              .collection('UsersData')
                              .where('AllowedUsers', arrayContains: user.uid)
                              .snapshots()
                              .map((s) => s.docs.map(User.fromDoc).toList()),
                        );
                        return Scaffold(
                          appBar: AppBar(
                            title: SearchField(
                                searchStream: searchStream,
                                textStyle:
                                    Theme.of(context).textTheme.bodyText2),
                          ),
                          body: UsersList(listOptions: listOptions),
                          bottomNavigationBar: BottomAppBar(
                            color: Theme.of(context).primaryColor,
                            shape: CircularNotchedRectangle(),
                            child: StreamBuilder(
                              stream: listOptions.objectsData,
                              builder: (context, snapshot) {
                                return Text(
                                  (snapshot.data?.length ?? 0).toString() +
                                      ' مستخدم',
                                  textAlign: TextAlign.center,
                                  strutStyle: StrutStyle(
                                      height: IconTheme.of(context).size / 7.5),
                                  style: Theme.of(context)
                                      .primaryTextTheme
                                      .bodyText1,
                                );
                              },
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
