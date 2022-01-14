import 'package:churchdata_core/churchdata_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:intl/intl.dart';
import 'package:meetinghelper/models/data/class.dart';
import 'package:meetinghelper/models/data/person.dart';
import 'package:meetinghelper/models/data/user.dart';
import 'package:meetinghelper/models/search/search_filters.dart';
import 'package:meetinghelper/utils/globals.dart';
import 'package:meetinghelper/utils/helpers.dart';
import 'package:meetinghelper/views/lists/users_list.dart';
import 'package:meetinghelper/views/services_list.dart';
import 'package:share_plus/share_plus.dart';
import 'package:tuple/tuple.dart';

import '../edit_page/edit_user.dart';

class UserInfo extends StatefulWidget {
  const UserInfo({Key? key, required this.user}) : super(key: key);

  final User user;

  @override
  _UserInfoState createState() => _UserInfoState();
}

class _UserInfoState extends State<UserInfo> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<Tuple2<User, Person?>>(
        initialData: Tuple2(widget.user, null),
        stream: widget.user.ref.snapshots().map(
              (d) => Tuple2(User.fromDoc(d), Person.fromDoc(d)),
            ),
        builder: (context, data) {
          final User user = data.data!.item1;
          final Person? person = data.data?.item2;

          return NestedScrollView(
            headerSliverBuilder: (context, _) => <Widget>[
              SliverAppBar(
                actions: <Widget>[
                  IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () async {
                      final dynamic result = await navigator.currentState!.push(
                        MaterialPageRoute(
                          builder: (co) => EditUser(user: user),
                        ),
                      );
                      if (result is JsonRef) {
                        scaffoldMessenger.currentState!.showSnackBar(
                          const SnackBar(
                            content: Text('تم الحفظ بنجاح'),
                          ),
                        );
                      } else if (result == 'deleted') {
                        scaffoldMessenger.currentState!.hideCurrentSnackBar();
                        scaffoldMessenger.currentState!.showSnackBar(
                          const SnackBar(
                            content: Text('تم الحذف بنجاح'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                        navigator.currentState!.pop();
                      }
                    },
                    tooltip: 'تعديل',
                  ),
                  IconButton(
                    icon: const Icon(Icons.share),
                    onPressed: () async {
                      await Share.share(await shareUser(user));
                    },
                    tooltip: 'مشاركة',
                  ),
                  IconButton(
                    icon: const Icon(Icons.info),
                    onPressed: () {
                      personTap(person);
                    },
                    tooltip: 'بيانات المستخدم',
                  ),
                ],
                expandedHeight: 250.0,
                pinned: true,
                flexibleSpace: LayoutBuilder(
                  builder: (context, constraints) => FlexibleSpaceBar(
                    title: AnimatedOpacity(
                      duration: const Duration(milliseconds: 300),
                      opacity: constraints.biggest.height > kToolbarHeight * 1.7
                          ? 0
                          : 1,
                      child: Text(user.name,
                          style: const TextStyle(
                            fontSize: 16.0,
                          )),
                    ),
                    background: UserPhotoWidget(
                      user,
                      circleCrop: false,
                      showActivityStatus: false,
                    ),
                  ),
                ),
              ),
            ],
            body: ListView(
              children: <Widget>[
                Text(user.name, style: Theme.of(context).textTheme.headline6),
                ListTile(
                  title: const Text('البريد الاكتروني:'),
                  subtitle: Text(user.email ?? ''),
                ),
                ListTile(
                  title: const Text('أخر ظهور على البرنامج:'),
                  subtitle: StreamBuilder<DatabaseEvent>(
                    stream: FirebaseDatabase.instance
                        .ref()
                        .child('Users/${user.uid}/lastSeen')
                        .onValue,
                    builder: (context, activity) {
                      if (activity.data?.snapshot.value == 'Active') {
                        return const Text('نشط الآن');
                      } else if (activity.data?.snapshot.value != null) {
                        return Text(
                          toDurationString(
                            Timestamp.fromMillisecondsSinceEpoch(
                                activity.data!.snapshot.value! as int),
                          ),
                        );
                      }
                      return const Text('لا يمكن التحديد');
                    },
                  ),
                ),
                ListTile(
                  title: const Text('تاريخ اخر تناول:'),
                  subtitle: Row(
                    children: <Widget>[
                      Expanded(
                        child: user.permissions.lastTanawol != null
                            ? Text(user.permissions.lastTanawol!
                                .toDurationString())
                            : const Text('لا يمكن التحديد'),
                      ),
                      Text(
                        user.permissions.lastTanawol != null
                            ? DateFormat('yyyy/M/d')
                                .format(user.permissions.lastTanawol!)
                            : '',
                        style: Theme.of(context).textTheme.overline,
                      ),
                    ],
                  ),
                ),
                ListTile(
                  title: const Text('تاريخ اخر اعتراف:'),
                  subtitle: Row(
                    children: <Widget>[
                      Expanded(
                        child: user.permissions.lastConfession != null
                            ? Text(user.permissions.lastConfession!
                                .toDurationString())
                            : const Text('لا يمكن التحديد'),
                      ),
                      Text(
                        user.permissions.lastConfession != null
                            ? DateFormat('yyyy/M/d')
                                .format(user.permissions.lastConfession!)
                            : '',
                        style: Theme.of(context).textTheme.overline,
                      ),
                    ],
                  ),
                ),
                ListTile(
                  title: const Text('داخل فصل:'),
                  subtitle:
                      user.classId != null && user.classId!.parent.id != 'null'
                          ? FutureBuilder<Class?>(
                              future: Class.fromId(user.classId!.id),
                              builder: (context, _class) => _class.hasData
                                  ? DataObjectWidget<Class>(_class.data!,
                                      isDense: true)
                                  : const LinearProgressIndicator(),
                            )
                          : const Text('غير موجود'),
                ),
                ListTile(
                  title: const Text('الصلاحيات:'),
                  subtitle: Column(
                    children: [
                      if (user.permissions.manageUsers)
                        const ListTile(
                          leading: Icon(
                              IconData(0xef3d, fontFamily: 'MaterialIconsR')),
                          title: Text('إدارة المستخدمين'),
                        ),
                      if (user.permissions.manageAllowedUsers)
                        const ListTile(
                          leading: Icon(
                              IconData(0xef3d, fontFamily: 'MaterialIconsR')),
                          title: Text('إدارة مستخدمين محددين'),
                        ),
                      if (user.permissions.superAccess)
                        const ListTile(
                          leading: Icon(
                              IconData(0xef56, fontFamily: 'MaterialIconsR')),
                          title: Text('رؤية جميع البيانات'),
                        ),
                      if (user.permissions.manageDeleted)
                        const ListTile(
                          leading: Icon(Icons.delete_outlined),
                          title: Text('استرجاع المحذوفات'),
                        ),
                      if (user.permissions.changeHistory)
                        const ListTile(
                          leading: Icon(Icons.history),
                          title: Text('تعديل الكشوفات القديمة'),
                        ),
                      if (user.permissions.secretary)
                        const ListTile(
                          leading: Icon(Icons.shield),
                          title: Text('تسجيل حضور الخدام'),
                        ),
                      if (user.permissions.write)
                        const ListTile(
                          leading: Icon(Icons.edit),
                          title: Text('تعديل البيانات'),
                        ),
                      if (user.permissions.export)
                        const ListTile(
                          leading: Icon(Icons.cloud_download),
                          title: Text('تصدير فصل لملف إكسل'),
                        ),
                      if (user.permissions.birthdayNotify)
                        const ListTile(
                          leading: Icon(Icons.cake),
                          title: Text('إشعار أعياد الميلاد'),
                        ),
                      if (user.permissions.confessionsNotify)
                        const ListTile(
                          leading: Icon(Icons.notifications_active),
                          title: Text('إشعار الاعتراف'),
                        ),
                      if (user.permissions.tanawolNotify)
                        const ListTile(
                          leading: Icon(Icons.notifications_active),
                          title: Text('إشعار التناول'),
                        ),
                      if (user.permissions.kodasNotify)
                        const ListTile(
                          leading: Icon(Icons.notifications_active),
                          title: Text('إشعار القداس'),
                        ),
                      if (user.permissions.meetingNotify)
                        const ListTile(
                          leading: Icon(Icons.notifications_active),
                          title: Text('إشعار حضور الاجتماع'),
                        ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  label: Text('رؤية البيانات كما يراها ' + user.name),
                  icon: const Icon(Icons.visibility),
                  onPressed: () => showDialog(
                    context: context,
                    builder: (context) => Dialog(
                      child: Column(
                        children: [
                          Text(
                            'يستطيع ' +
                                user.name +
                                ' رؤية ${user.permissions.write ? 'وتعديل ' : ''}الخدمات التالية:',
                            style: Theme.of(context).textTheme.headline6,
                          ),
                          Expanded(
                            child: ServicesList(
                              options: ServicesListController(
                                itemsStream: user.permissions.superAccess
                                    ? servicesByStudyYearRef()
                                    : servicesByStudyYearRefForUser(
                                        user.uid, user.adminServices),
                              ),
                              autoDisposeController: true,
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
                  icon: const Icon(Icons.shield),
                  onPressed: () => navigator.currentState!.push(
                    MaterialPageRoute(
                      builder: (context) {
                        final listOptions = ListController<void, User>(
                          objectsPaginatableStream: PaginatableStream.query(
                            query: GetIt.I<DatabaseRepository>()
                                .collection('UsersData')
                                .where('AllowedUsers', arrayContains: user.uid),
                            mapper: User.fromDoc,
                          ),
                        );
                        return Scaffold(
                          appBar: AppBar(
                            title: SearchField(
                              showSuffix: false,
                              searchStream: listOptions.searchSubject,
                              textStyle:
                                  Theme.of(context).primaryTextTheme.headline6,
                            ),
                          ),
                          body: UsersList(
                              autoDisposeController: true,
                              listOptions: listOptions),
                          bottomNavigationBar: BottomAppBar(
                            color: Theme.of(context).colorScheme.primary,
                            shape: const CircularNotchedRectangle(),
                            child: StreamBuilder<List>(
                              stream: listOptions.objectsStream,
                              builder: (context, snapshot) {
                                return Text(
                                  (snapshot.data?.length ?? 0).toString() +
                                      ' مستخدم',
                                  textAlign: TextAlign.center,
                                  strutStyle: StrutStyle(
                                      height:
                                          IconTheme.of(context).size! / 7.5),
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
