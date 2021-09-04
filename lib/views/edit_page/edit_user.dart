import 'dart:async';

import 'package:async/async.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart'
    if (dart.library.io) 'package:firebase_crashlytics/firebase_crashlytics.dart'
    if (dart.library.html) 'package:meetinghelper/crashlytics_web.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:meetinghelper/models/data/service.dart';
import 'package:meetinghelper/models/list_controllers.dart';
import 'package:meetinghelper/models/search/order_options.dart';
import 'package:meetinghelper/models/search/search_filters.dart';
import 'package:meetinghelper/utils/globals.dart';
import 'package:meetinghelper/utils/helpers.dart';
import 'package:meetinghelper/utils/typedefs.dart';
import 'package:meetinghelper/views/list.dart';
import 'package:meetinghelper/views/lists/users_list.dart';
import 'package:meetinghelper/views/services_list.dart';
import 'package:provider/provider.dart';
import 'package:rxdart/rxdart.dart';

import '../../models/data/user.dart';

class EditUser extends StatefulWidget {
  final User user;

  const EditUser({Key? key, required this.user}) : super(key: key);
  @override
  _EditUserState createState() => _EditUserState();
}

class _EditUserState extends State<EditUser> {
  AsyncCache<String?> className = AsyncCache(const Duration(minutes: 1));
  late User old;
  late User user;
  List<User>? childrenUsers;

  GlobalKey<FormState> form = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
          return <Widget>[
            SliverAppBar(
              expandedHeight: 250.0,
              floating: false,
              pinned: true,
              actions: [
                IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: 'إلغاء تنشيط الحساب',
                  onPressed: unApproveUser,
                ),
                IconButton(
                  icon: const Icon(Icons.delete_forever),
                  tooltip: 'حذف الحساب',
                  onPressed: deleteUser,
                ),
              ],
              flexibleSpace: LayoutBuilder(
                builder: (context, constraints) => FlexibleSpaceBar(
                  title: AnimatedOpacity(
                    duration: const Duration(milliseconds: 300),
                    opacity: constraints.biggest.height > kToolbarHeight * 1.7
                        ? 0
                        : 1,
                    child: Text(
                      user.name,
                      style: const TextStyle(
                        fontSize: 16.0,
                      ),
                    ),
                  ),
                  background: user.getPhoto(false, false),
                ),
              ),
            ),
          ];
        },
        body: Form(
          key: form,
          child: Padding(
            padding: const EdgeInsets.all(5),
            child: ListView(
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'الاسم',
                    ),
                    textInputAction: TextInputAction.next,
                    initialValue: user.name,
                    onChanged: (v) => user.name = v,
                    validator: (value) {
                      if (value!.isEmpty) {
                        return 'هذا الحقل مطلوب';
                      }
                      return null;
                    },
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: InkWell(
                    onTap: () async => user.lastTanawol = await _selectDate(
                      'تاريخ أخر تناول',
                      user.lastTanawolDate ?? DateTime.now(),
                    ),
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'تاريخ أخر تناول',
                        border: OutlineInputBorder(
                          borderSide: BorderSide(
                              color: Theme.of(context).colorScheme.primary),
                        ),
                      ),
                      child: user.lastTanawolDate != null
                          ? Text(DateFormat('yyyy/M/d').format(
                              user.lastTanawolDate!,
                            ))
                          : const Text('لا يمكن التحديد'),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: InkWell(
                    onTap: () async => user.lastConfession = await _selectDate(
                      'تاريخ أخر اعتراف',
                      user.lastConfessionDate ?? DateTime.now(),
                    ),
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'تاريخ أخر اعتراف',
                        border: OutlineInputBorder(
                          borderSide: BorderSide(
                              color: Theme.of(context).colorScheme.primary),
                        ),
                      ),
                      child: user.lastConfessionDate != null
                          ? Text(DateFormat('yyyy/M/d').format(
                              user.lastConfessionDate!,
                            ))
                          : const Text('لا يمكن التحديد'),
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: _selectClass,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: InputDecorator(
                      isEmpty: user.classId == null,
                      decoration: InputDecoration(
                        labelText: 'داخل فصل',
                        border: OutlineInputBorder(
                          borderSide: BorderSide(
                              color: Theme.of(context).colorScheme.primary),
                        ),
                      ),
                      child: FutureBuilder<String?>(
                        future: className.fetch(() => user.classId == null
                            ? Future<String?>(() => null)
                            : user.getClassName()),
                        builder: (con, data) {
                          if (data.hasData) {
                            return Text(data.data!);
                          } else if (data.connectionState ==
                              ConnectionState.waiting) {
                            return const LinearProgressIndicator();
                          } else {
                            return Container();
                          }
                        },
                      ),
                    ),
                  ),
                ),
                if (User.instance.manageUsers)
                  ListTile(
                    trailing: Checkbox(
                      value: user.manageUsers,
                      onChanged: (v) => setState(() => user.manageUsers = v!),
                    ),
                    leading: const Icon(
                        IconData(0xef3d, fontFamily: 'MaterialIconsR')),
                    title: const Text('إدارة المستخدمين'),
                    onTap: () =>
                        setState(() => user.manageUsers = !user.manageUsers),
                  ),
                ListTile(
                  trailing: Checkbox(
                    value: user.manageAllowedUsers,
                    onChanged: (v) =>
                        setState(() => user.manageAllowedUsers = v!),
                  ),
                  leading: const Icon(
                      IconData(0xef3d, fontFamily: 'MaterialIconsR')),
                  title: const Text('إدارة مستخدمين محددين'),
                  onTap: () => setState(
                      () => user.manageAllowedUsers = !user.manageAllowedUsers),
                ),
                ListTile(
                  trailing: Checkbox(
                    value: user.superAccess,
                    onChanged: (v) => setState(() => user.superAccess = v!),
                  ),
                  leading: const Icon(
                      IconData(0xef56, fontFamily: 'MaterialIconsR')),
                  title: const Text('رؤية جميع البيانات'),
                  onTap: () =>
                      setState(() => user.superAccess = !user.superAccess),
                ),
                ListTile(
                  trailing: Checkbox(
                    value: user.manageDeleted,
                    onChanged: (v) => setState(() => user.manageDeleted = v!),
                  ),
                  leading: const Icon(Icons.delete_outlined),
                  title: const Text('استرجاع المحذوفات'),
                  onTap: () =>
                      setState(() => user.manageDeleted = !user.manageDeleted),
                ),
                ListTile(
                  trailing: Checkbox(
                    value: user.changeHistory,
                    onChanged: (v) => setState(() => user.changeHistory = v!),
                  ),
                  leading: const Icon(Icons.history),
                  title: const Text('تعديل الكشوفات القديمة'),
                  onTap: () =>
                      setState(() => user.changeHistory = !user.changeHistory),
                ),
                ListTile(
                  trailing: Checkbox(
                    value: user.secretary,
                    onChanged: (v) => setState(() => user.secretary = v!),
                  ),
                  leading: const Icon(Icons.shield),
                  title: const Text('تسجيل حضور الخدام'),
                  onTap: () => setState(() => user.secretary = !user.secretary),
                ),
                ListTile(
                  trailing: Checkbox(
                    value: user.write,
                    onChanged: (v) => setState(() => user.write = v!),
                  ),
                  leading: const Icon(Icons.edit),
                  title: const Text('تعديل البيانات'),
                  onTap: () => setState(() => user.write = !user.write),
                ),
                ListTile(
                  trailing: Checkbox(
                    value: user.exportClasses,
                    onChanged: (v) => setState(() => user.exportClasses = v!),
                  ),
                  leading: const Icon(Icons.cloud_download),
                  title: const Text('تصدير فصل لملف إكسل'),
                  onTap: () =>
                      setState(() => user.exportClasses = !user.exportClasses),
                ),
                ListTile(
                  trailing: Checkbox(
                    value: user.birthdayNotify,
                    onChanged: (v) => setState(() => user.birthdayNotify = v!),
                  ),
                  leading: const Icon(
                      IconData(0xe7e9, fontFamily: 'MaterialIconsR')),
                  title: const Text('إشعار أعياد الميلاد'),
                  onTap: () => setState(
                      () => user.birthdayNotify = !user.birthdayNotify),
                ),
                ListTile(
                  trailing: Checkbox(
                    value: user.confessionsNotify,
                    onChanged: (v) =>
                        setState(() => user.confessionsNotify = v!),
                  ),
                  leading: const Icon(
                      IconData(0xe7f7, fontFamily: 'MaterialIconsR')),
                  title: const Text('إشعار  الاعتراف'),
                  onTap: () => setState(
                      () => user.confessionsNotify = !user.confessionsNotify),
                ),
                ListTile(
                  trailing: Checkbox(
                    value: user.tanawolNotify,
                    onChanged: (v) => setState(() => user.tanawolNotify = v!),
                  ),
                  leading: const Icon(
                      IconData(0xe7f7, fontFamily: 'MaterialIconsR')),
                  title: const Text('إشعار التناول'),
                  onTap: () =>
                      setState(() => user.tanawolNotify = !user.tanawolNotify),
                ),
                ListTile(
                  trailing: Checkbox(
                    value: user.kodasNotify,
                    onChanged: (v) => setState(() => user.kodasNotify = v!),
                  ),
                  leading: const Icon(
                      IconData(0xe7f7, fontFamily: 'MaterialIconsR')),
                  title: const Text('إشعار القداس'),
                  onTap: () =>
                      setState(() => user.kodasNotify = !user.kodasNotify),
                ),
                ListTile(
                  trailing: Checkbox(
                    value: user.meetingNotify,
                    onChanged: (v) => setState(() => user.meetingNotify = v!),
                  ),
                  leading: const Icon(
                      IconData(0xe7f7, fontFamily: 'MaterialIconsR')),
                  title: const Text('إشعار حضور الاجتماع'),
                  onTap: () =>
                      setState(() => user.meetingNotify = !user.meetingNotify),
                ),
                ElevatedButton.icon(
                  onPressed: editAdminServices,
                  icon: const Icon(Icons.miscellaneous_services),
                  label: Text(
                    'تعديل الخدمات المسؤول عنها ' + user.name,
                    softWrap: false,
                    textScaleFactor: 0.95,
                    overflow: TextOverflow.fade,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: editChildrenUsers,
                  icon: const Icon(Icons.shield),
                  label: Text(
                    'تعديل المستخدمين المسؤول عنهم ' + user.name,
                    softWrap: false,
                    textScaleFactor: 0.95,
                    overflow: TextOverflow.fade,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: resetPassword,
                  icon: const Icon(Icons.lock_open),
                  label: const Text('إعادة تعيين كلمة السر'),
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'حفظ',
        onPressed: save,
        child: const Icon(Icons.save),
      ),
    );
  }

  void editChildrenUsers() async {
    childrenUsers = await navigator.currentState!.push(
          MaterialPageRoute(
            builder: (context) {
              return StreamBuilder<List<User>>(
                stream: childrenUsers != null
                    ? Stream.value(childrenUsers!)
                    : FirebaseFirestore.instance
                        .collection('UsersData')
                        .where('AllowedUsers', arrayContains: user.uid)
                        .snapshots()
                        .map((value) => value.docs.map(User.fromDoc).toList()),
                builder: (c, users) {
                  if (!users.hasData)
                    return const Center(child: CircularProgressIndicator());
                  return MultiProvider(
                    providers: [
                      Provider<DataObjectListController<User>>(
                        create: (_) => DataObjectListController<User>(
                          selectionMode: true,
                          itemsStream: User.getAllForUser(),
                          selected: {
                            for (final item in users.data!) item.id: item
                          },
                        ),
                        dispose: (context, c) => c.dispose(),
                      )
                    ],
                    builder: (context, child) => Scaffold(
                      persistentFooterButtons: [
                        TextButton(
                          onPressed: () {
                            navigator.currentState!.pop(context
                                .read<DataObjectListController<User>>()
                                .selectedLatest
                                ?.values
                                .toList());
                          },
                          child: const Text('تم'),
                        )
                      ],
                      appBar: AppBar(
                        title: SearchField(
                            showSuffix: false,
                            searchStream: context
                                .read<DataObjectListController<User>>()
                                .searchQuery,
                            textStyle: Theme.of(context).textTheme.bodyText2),
                      ),
                      body: const UsersList(
                        autoDisposeController: false,
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ) ??
        childrenUsers;
  }

  void editAdminServices() async {
    user.adminServices = await navigator.currentState!.push(
          MaterialPageRoute(
            builder: (context) {
              return FutureBuilder<Map<String, Service>>(future: () async {
                return {
                  for (final s in await Future.wait(
                    user.adminServices.map(
                      (e) async => Service.fromDoc(await e.get(dataSource)),
                    ),
                  ))
                    s.id: s
                };
              }(), builder: (context, snapshot) {
                if (!snapshot.hasData)
                  return const Center(child: CircularProgressIndicator());

                return MultiProvider(
                  providers: [
                    Provider<DataObjectListController<Service>>(
                      create: (_) => DataObjectListController<Service>(
                        selectionMode: true,
                        itemsStream: FirebaseFirestore.instance
                            .collection('Services')
                            .orderBy('Name')
                            .snapshots()
                            .map(
                              (value) =>
                                  value.docs.map(Service.fromDoc).toList(),
                            ),
                        selected: snapshot.requireData,
                      ),
                      dispose: (context, c) => c.dispose(),
                    )
                  ],
                  builder: (context, child) {
                    return Scaffold(
                      persistentFooterButtons: [
                        TextButton(
                          onPressed: () {
                            navigator.currentState!.pop(context
                                .read<DataObjectListController<Service>>()
                                .selectedLatest
                                ?.values
                                .map((s) => s.ref)
                                .toList());
                          },
                          child: const Text('تم'),
                        )
                      ],
                      appBar: AppBar(
                        title: SearchField(
                            showSuffix: false,
                            searchStream: context
                                .read<DataObjectListController<Service>>()
                                .searchQuery,
                            textStyle: Theme.of(context).textTheme.bodyText2),
                      ),
                      body: const DataObjectList<Service>(
                        disposeController: false,
                      ),
                    );
                  },
                );
              });
            },
          ),
        ) ??
        user.adminServices;
  }

  void deleteUser() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('حذف حساب ${user.name}'),
        content: Text('هل أنت متأكد من حذف حساب ' + user.name + ' نهائيًا؟'),
        actions: <Widget>[
          TextButton(
            style: Theme.of(context).textButtonTheme.style!.copyWith(
                foregroundColor:
                    MaterialStateProperty.resolveWith((state) => Colors.red)),
            onPressed: () async {
              try {
                scaffoldMessenger.currentState!.showSnackBar(
                  const SnackBar(
                    content: LinearProgressIndicator(),
                    duration: Duration(seconds: 15),
                  ),
                );
                navigator.currentState!.pop();
                await FirebaseFunctions.instance
                    .httpsCallable('deleteUser')
                    .call({'affectedUser': user.uid});
                scaffoldMessenger.currentState!.hideCurrentSnackBar();
                navigator.currentState!.pop('deleted');
                scaffoldMessenger.currentState!.showSnackBar(
                  const SnackBar(
                    content: Text('تم بنجاح'),
                    duration: Duration(seconds: 15),
                  ),
                );
              } catch (err, stkTrace) {
                await FirebaseCrashlytics.instance
                    .setCustomKey('LastErrorIn', 'UserPState.delete');
                await FirebaseCrashlytics.instance.recordError(err, stkTrace);
                scaffoldMessenger.currentState!.hideCurrentSnackBar();
                scaffoldMessenger.currentState!.showSnackBar(
                  SnackBar(
                    content: Text(
                      err.toString(),
                    ),
                    duration: const Duration(seconds: 7),
                  ),
                );
              }
            },
            child: const Text('حذف'),
          ),
          TextButton(
            onPressed: () {
              navigator.currentState!.pop();
            },
            child: const Text('تراجع'),
          ),
        ],
      ),
    );
  }

  void unApproveUser() {
    showDialog(
      context: context,
      builder: (navContext) => AlertDialog(
        title: Text('إلغاء تنشيط حساب ${user.name}'),
        content: const Text('إلغاء تنشيط الحساب لن يقوم بالضرورة بحذف الحساب '),
        actions: <Widget>[
          TextButton(
            onPressed: () async {
              try {
                scaffoldMessenger.currentState!.showSnackBar(const SnackBar(
                  content: LinearProgressIndicator(),
                  duration: Duration(seconds: 15),
                ));
                navigator.currentState!.pop();
                await FirebaseFunctions.instance
                    .httpsCallable('unApproveUser')
                    .call({'affectedUser': user.uid});
                navigator.currentState!.pop('deleted');
                scaffoldMessenger.currentState!.hideCurrentSnackBar();
                scaffoldMessenger.currentState!.showSnackBar(const SnackBar(
                  content: Text('تم بنجاح'),
                  duration: Duration(seconds: 15),
                ));
              } catch (err, stkTrace) {
                await FirebaseCrashlytics.instance
                    .setCustomKey('LastErrorIn', 'UserPState.delete');
                await FirebaseCrashlytics.instance.recordError(err, stkTrace);
                scaffoldMessenger.currentState!.hideCurrentSnackBar();
                scaffoldMessenger.currentState!.showSnackBar(SnackBar(
                  content: Text(err.toString()),
                  duration: const Duration(seconds: 7),
                ));
              }
            },
            child: const Text('متابعة'),
          ),
          TextButton(
            onPressed: () {
              navigator.currentState!.pop();
            },
            child: const Text('تراجع'),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    old = widget.user.copyWith();
    user = widget.user.copyWith();
  }

  void nameChanged(String value) {
    user.name = value;
  }

  Future resetPassword() async {
    if (await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(
                'هل أنت متأكد من إعادة تعيين كلمة السر ل' + user.name + '؟'),
            actions: [
              TextButton(
                onPressed: () => navigator.currentState!.pop(true),
                child: const Text('نعم'),
              ),
              TextButton(
                onPressed: () => navigator.currentState!.pop(false),
                child: const Text('لا'),
              ),
            ],
          ),
        ) !=
        true) return;
    scaffoldMessenger.currentState!.showSnackBar(
      const SnackBar(
        content: LinearProgressIndicator(),
        duration: Duration(seconds: 15),
      ),
    );
    try {
      await FirebaseFunctions.instance
          .httpsCallable('resetPassword')
          .call({'affectedUser': user.uid});
      scaffoldMessenger.currentState!.hideCurrentSnackBar();
      scaffoldMessenger.currentState!.showSnackBar(
        const SnackBar(
          content: Text('تم إعادة تعيين كلمة السر بنجاح'),
        ),
      );
    } catch (err, stkTrace) {
      await FirebaseCrashlytics.instance
          .setCustomKey('LastErrorIn', 'UserPState.resetPassword');
      await FirebaseCrashlytics.instance.recordError(err, stkTrace);
      scaffoldMessenger.currentState!.showSnackBar(
        SnackBar(
          content: Text(err.toString()),
        ),
      );
    }
  }

  Future save() async {
    if (await Connectivity().checkConnectivity() == ConnectivityResult.none) {
      await showDialog(
          context: context,
          builder: (context) =>
              const AlertDialog(content: Text('لا يوجد اتصال انترنت')));
      return;
    }
    try {
      if (form.currentState!.validate()) {
        scaffoldMessenger.currentState!.showSnackBar(const SnackBar(
          content: Text('جار الحفظ...'),
          duration: Duration(seconds: 15),
        ));
        final update = user.getUpdateMap()
          ..removeWhere((key, value) => old.getUpdateMap()[key] == value);
        if (old.name != user.name) {
          await FirebaseFunctions.instance
              .httpsCallable('changeUserName')
              .call({'affectedUser': user.uid, 'newName': user.name});
        }
        update
          ..remove('name')
          ..remove('classId');

        if (update.isNotEmpty) {
          await FirebaseFunctions.instance
              .httpsCallable('updatePermissions')
              .call({'affectedUser': user.uid, 'permissions': update});
        }
        if (childrenUsers != null) {
          final batch = FirebaseFirestore.instance.batch();
          final oldChildren = (await FirebaseFirestore.instance
                  .collection('UsersData')
                  .where('AllowedUsers', arrayContains: user.uid)
                  .get())
              .docs
              .map(User.fromDoc)
              .toList();
          for (final item in oldChildren) {
            if (!childrenUsers!.contains(item)) {
              batch.update(item.ref, {
                'AllowedUsers': FieldValue.arrayRemove([user.uid])
              });
            }
          }
          for (final item in childrenUsers!) {
            if (!oldChildren.contains(item)) {
              batch.update(item.ref, {
                'AllowedUsers': FieldValue.arrayUnion([user.uid])
              });
            }
          }
          await batch.commit();
        }
        if (old.classId != user.classId) {
          await FirebaseFirestore.instance
              .collection('UsersData')
              .doc(user.refId)
              .update({'ClassId': user.classId});
        }
        scaffoldMessenger.currentState!.hideCurrentSnackBar();
        navigator.currentState!.pop(user);
        scaffoldMessenger.currentState!.showSnackBar(
          const SnackBar(
            content: Text('تم الحفظ بنجاح'),
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (err, stkTrace) {
      await FirebaseCrashlytics.instance
          .setCustomKey('LastErrorIn', 'UserPState.save');
      await FirebaseCrashlytics.instance.recordError(err, stkTrace);
      scaffoldMessenger.currentState!.hideCurrentSnackBar();
      scaffoldMessenger.currentState!.showSnackBar(SnackBar(
        content: Text(err.toString()),
        duration: const Duration(seconds: 7),
      ));
    }
  }

  Future<Timestamp> _selectDate(String helpText, DateTime initialDate) async {
    final DateTime? picked = await showDatePicker(
      helpText: helpText,
      locale: const Locale('ar', 'EG'),
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1500),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != initialDate) {
      setState(() {});
      return Timestamp.fromDate(picked);
    }
    return Timestamp.fromDate(initialDate);
  }

  void _selectClass() async {
    final controller = ServicesListController(
      tap: (class$) {
        navigator.currentState!.pop();
        user.classId = class$.ref;
        setState(() {});
        FocusScope.of(context).nextFocus();
      },
      itemsStream: servicesByStudyYearRef(),
    );
    await showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          child: Scaffold(
            extendBody: true,
            floatingActionButtonLocation:
                FloatingActionButtonLocation.endDocked,
            body: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SearchFilters(0,
                    options: controller,
                    orderOptions: BehaviorSubject<OrderOptions>.seeded(
                        const OrderOptions()),
                    textStyle: Theme.of(context).textTheme.bodyText2),
                Expanded(
                  child: ServicesList(
                    options: controller,
                    autoDisposeController: false,
                  ),
                ),
              ],
            ),
            bottomNavigationBar: BottomAppBar(
              color: Theme.of(context).colorScheme.primary,
              shape: const CircularNotchedRectangle(),
              child: StreamBuilder<Map?>(
                stream: controller.objectsData,
                builder: (context, snapshot) {
                  return Text((snapshot.data?.length ?? 0).toString() + ' خدمة',
                      textAlign: TextAlign.center,
                      strutStyle:
                          StrutStyle(height: IconTheme.of(context).size! / 7.5),
                      style: Theme.of(context).primaryTextTheme.bodyText1);
                },
              ),
            ),
            floatingActionButton: User.instance.write
                ? FloatingActionButton(
                    onPressed: () async {
                      navigator.currentState!.pop();
                      user.classId = await navigator.currentState!
                              .pushNamed('Data/EditClass') as JsonRef? ??
                          user.classId;
                      setState(() {});
                    },
                    child: const Icon(Icons.group_add),
                  )
                : null,
          ),
        );
      },
    );
    await controller.dispose();
  }
}
