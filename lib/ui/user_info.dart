import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:meetinghelper/models/list_options.dart';
import 'package:meetinghelper/models/search_filters.dart';
import 'package:meetinghelper/models/user.dart';
import 'package:meetinghelper/ui/list.dart';
import 'package:meetinghelper/ui/services_list.dart';
import 'package:meetinghelper/ui/users_list.dart';
import 'package:meetinghelper/utils/helpers.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import 'edit_user.dart';

class UserInfo extends StatefulWidget {
  UserInfo({Key key}) : super(key: key);

  @override
  _UserInfoState createState() => _UserInfoState();
}

class _UserInfoState extends State<UserInfo> {
  User user;

  @override
  Widget build(BuildContext context) {
    user ??= user = ModalRoute.of(context).settings.arguments;

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, _) => <Widget>[
          SliverAppBar(
            actions: <Widget>[
              IconButton(
                icon: Icon(Icons.edit),
                onPressed: () async {
                  user = await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (co) => EditUser(user: user),
                    ),
                  );
                  if (user == null) {
                    Navigator.of(context).pop();
                  } else {
                    setState(() {});
                  }
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
                  opacity:
                      constraints.biggest.height > kToolbarHeight * 1.7 ? 0 : 1,
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
              title: Text('صف الخدمة:'),
              subtitle: FutureBuilder(
                  future: user.getStudyYearName(),
                  builder: (context, data) {
                    if (data.hasData) return Text(data.data);
                    return LinearProgressIndicator();
                  }),
            ),
            ListTile(
              title: Text('نوع الخدمة:'),
              subtitle: Text(user.servingStudyGender != null
                  ? (user.servingStudyGender == true ? 'بنين' : 'بنات')
                  : ''),
            ),
            ListTile(
              title: Text('تاريخ اخر تناول:'),
              subtitle: Row(
                children: <Widget>[
                  Expanded(
                    child: user.lastTanawol != null
                        ? Text(toDurationString(
                            Timestamp.fromMillisecondsSinceEpoch(
                                user.lastTanawol)))
                        : Text('لا يمكن التحديد'),
                  ),
                  Text(
                      user.lastTanawolDate != null
                          ? DateFormat('yyyy/M/d').format(user.lastTanawolDate)
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
                        ? Text(toDurationString(
                            Timestamp.fromMillisecondsSinceEpoch(
                                user.lastConfession)))
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
              title: Text('الصلاحيات:'),
              subtitle: Column(
                children: [
                  if (user.manageUsers == true)
                    ListTile(
                      leading: Icon(
                          const IconData(0xef3d, fontFamily: 'MaterialIconsR')),
                      title: Text('إدارة المستخدمين'),
                    ),
                  if (user.manageAllowedUsers == true)
                    ListTile(
                      leading: Icon(
                          const IconData(0xef3d, fontFamily: 'MaterialIconsR')),
                      title: Text('إدارة مستخدمين محددين'),
                    ),
                  if (user.superAccess == true)
                    ListTile(
                      leading: Icon(
                          const IconData(0xef56, fontFamily: 'MaterialIconsR')),
                      title: Text('رؤية جميع البيانات'),
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
                                tap: classTap,
                                documentsData: user.superAccess
                                    ? classesByStudyYearRef()
                                    : classesByStudyYearRefForUser(user.uid))),
                      )
                    ],
                  ),
                ),
              ),
            ),
            ElevatedButton.icon(
              label: Text('المستخدمين المسموح لهم بتعديل صلاحيات ' + user.name,
                  textScaleFactor: 0.95, overflow: TextOverflow.fade),
              icon: Icon(Icons.shield),
              onPressed: () => showDialog(
                context: context,
                builder: (context) {
                  return FutureBuilder<List<User>>(
                    future: User.getUsers(user.allowedUsers),
                    builder: (c, users) => users.hasData
                        ? MultiProvider(
                            providers: [
                              ListenableProvider<SearchString>(
                                create: (_) => SearchString(''),
                              ),
                              ListenableProvider(
                                  create: (_) => ListOptions<User>(
                                      documentsData: Stream.fromFuture(
                                          User.getAllSemiManagers()),
                                      selected: users.data))
                            ],
                            builder: (context, child) => AlertDialog(
                              content: Container(
                                width: 280,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SearchField(
                                        textStyle: Theme.of(context)
                                            .textTheme
                                            .bodyText2),
                                    Expanded(
                                      child: Selector<OrderOptions,
                                          Tuple2<String, bool>>(
                                        selector: (_, o) =>
                                            Tuple2<String, bool>(
                                                o.classOrderBy, o.classASC),
                                        builder: (context, options, child) =>
                                            UsersList(),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          )
                        : Center(child: CircularProgressIndicator()),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
