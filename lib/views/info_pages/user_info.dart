import 'package:churchdata_core/churchdata_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:intl/intl.dart';
import 'package:meetinghelper/controllers.dart';
import 'package:meetinghelper/models.dart';
import 'package:meetinghelper/repositories.dart';
import 'package:meetinghelper/services.dart';
import 'package:meetinghelper/utils/globals.dart';
import 'package:meetinghelper/views.dart';
import 'package:meetinghelper/widgets.dart';

class UserInfo extends StatefulWidget {
  const UserInfo({
    required this.user,
    super.key,
  });

  final UserWithPerson user;

  @override
  _UserInfoState createState() => _UserInfoState();
}

class _UserInfoState extends State<UserInfo> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<UserWithPerson>(
        initialData: widget.user,
        stream: widget.user.ref.snapshots().map(UserWithPerson.fromDoc),
        builder: (context, data) {
          final UserWithPerson user = data.data!;

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
                      if (result == 'deleted') {
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
                      await MHShareService.I.shareText(
                        (await MHShareService.I.shareUser(user)).toString(),
                      );
                    },
                    tooltip: 'مشاركة',
                  ),
                  IconButton(
                    icon: const Icon(Icons.info),
                    onPressed: () {
                      GetIt.I<MHViewableObjectService>().personTap(user);
                    },
                    tooltip: 'بيانات المستخدم',
                  ),
                ],
                expandedHeight: 280,
                pinned: true,
                flexibleSpace: SafeArea(
                  child: LayoutBuilder(
                    builder: (context, constraints) => FlexibleSpaceBar(
                      title: AnimatedOpacity(
                        duration: const Duration(milliseconds: 300),
                        opacity:
                            constraints.biggest.height > kToolbarHeight * 1.7
                                ? 0
                                : 1,
                        child: Text(
                          user.name,
                          style: const TextStyle(
                            fontSize: 16.0,
                          ),
                        ),
                      ),
                      background: Theme(
                        data: Theme.of(context).copyWith(
                          progressIndicatorTheme: ProgressIndicatorThemeData(
                            color: Theme.of(context).colorScheme.secondary,
                          ),
                        ),
                        child: UserPhotoWidget(
                          user,
                          circleCrop: false,
                          showActivityStatus: false,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
            body: ListView(
              children: <Widget>[
                Text(user.name, style: Theme.of(context).textTheme.titleLarge),
                ListTile(
                  title: const Text('البريد الاكتروني:'),
                  subtitle: Text(user.email ?? ''),
                ),
                ListTile(
                  title: const Text('أخر ظهور على البرنامج:'),
                  subtitle: StreamBuilder<DatabaseEvent>(
                    stream: GetIt.I<FirebaseDatabase>()
                        .ref()
                        .child('Users/${user.uid}/lastSeen')
                        .onValue,
                    builder: (context, activity) {
                      if (activity.data?.snapshot.value == 'Active') {
                        return const Text('نشط الآن');
                      } else if (activity.data?.snapshot.value != null) {
                        return Text(
                          DateTime.fromMillisecondsSinceEpoch(
                            activity.data!.snapshot.value! as int,
                          ).toDurationString(),
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
                        child: user.lastTanawol != null
                            ? Text(user.lastTanawol!.toDurationString())
                            : const Text('لا يمكن التحديد'),
                      ),
                      Text(
                        user.lastTanawol != null
                            ? DateFormat('yyyy/M/d').format(user.lastTanawol!)
                            : '',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ],
                  ),
                ),
                ListTile(
                  title: const Text('تاريخ اخر اعتراف:'),
                  subtitle: Row(
                    children: <Widget>[
                      Expanded(
                        child: user.lastConfession != null
                            ? Text(user.lastConfession!.toDurationString())
                            : const Text('لا يمكن التحديد'),
                      ),
                      Text(
                        user.lastConfession != null
                            ? DateFormat('yyyy/M/d')
                                .format(user.lastConfession!)
                            : '',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ],
                  ),
                ),
                ListTile(
                  title: const Text('داخل فصل:'),
                  subtitle:
                      user.classId != null && user.classId!.parent.id != 'null'
                          ? FutureBuilder<Class?>(
                              future: MHDatabaseRepo.I.classes
                                  .getById(user.classId!.id),
                              builder: (context, _class) => _class.hasData
                                  ? ViewableObjectWidget<Class>(
                                      _class.data!,
                                      isDense: true,
                                    )
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
                            IconData(0xef3d, fontFamily: 'MaterialIconsR'),
                          ),
                          title: Text('إدارة المستخدمين'),
                        ),
                      if (user.permissions.manageAllowedUsers)
                        const ListTile(
                          leading: Icon(
                            IconData(0xef3d, fontFamily: 'MaterialIconsR'),
                          ),
                          title: Text('إدارة مستخدمين محددين'),
                        ),
                      if (user.permissions.superAccess)
                        const ListTile(
                          leading: Icon(
                            IconData(0xef56, fontFamily: 'MaterialIconsR'),
                          ),
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
                      if (user.permissions.recordHistory)
                        const ListTile(
                          leading: Icon(Icons.history),
                          title: Text('تسجيل حضور المخدومين'),
                        ),
                      if (user.permissions.secretary)
                        const ListTile(
                          leading: Icon(Icons.history),
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
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          Expanded(
                            child: ServicesList<DataObject>(
                              options: ServicesListController(
                                objectsPaginatableStream:
                                    PaginatableStream.loadAll(
                                  stream: Stream.value(
                                    [],
                                  ),
                                ),
                                groupByStream: (_) =>
                                    user.permissions.superAccess
                                        ? MHDatabaseRepo.I.services
                                            .groupServicesByStudyYearRef()
                                        : MHDatabaseRepo.I.services
                                            .groupServicesByStudyYearRefForUser(
                                            user.uid,
                                            user.adminServices,
                                          ),
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
                  label: Text(
                    'المستخدمين المسؤول عنهم ' + user.name,
                    textScaleFactor: 0.95,
                    overflow: TextOverflow.fade,
                  ),
                  icon: const Icon(Icons.shield),
                  onPressed: () => navigator.currentState!.push(
                    MaterialPageRoute(
                      builder: (context) {
                        final listOptions = ListController<Class?, User>(
                          objectsPaginatableStream: PaginatableStream.query(
                            query: GetIt.I<DatabaseRepository>()
                                .collection('UsersData')
                                .where('AllowedUsers', arrayContains: user.uid),
                            mapper: UserWithPerson.fromDoc,
                          ),
                          groupByStream:
                              MHDatabaseRepo.I.users.groupUsersByClass,
                          groupingStream: Stream.value(true),
                        );
                        return Scaffold(
                          appBar: AppBar(
                            title: SearchField(
                              showSuffix: false,
                              searchStream: listOptions.searchSubject,
                              textStyle:
                                  Theme.of(context).primaryTextTheme.titleLarge,
                            ),
                          ),
                          body: DataObjectListView(
                            autoDisposeController: true,
                            controller: listOptions,
                          ),
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
                                    height: IconTheme.of(context).size! / 7.5,
                                  ),
                                  style: Theme.of(context)
                                      .primaryTextTheme
                                      .bodyLarge,
                                );
                              },
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 60),
              ],
            ),
          );
        },
      ),
    );
  }
}
