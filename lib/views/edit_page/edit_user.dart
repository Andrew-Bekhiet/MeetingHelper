import 'dart:async';

import 'package:async/async.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:meetinghelper/models/list_controllers.dart';
import 'package:meetinghelper/models/order_options.dart';
import 'package:meetinghelper/models/search_filters.dart';
import 'package:meetinghelper/utils/globals.dart';
import 'package:meetinghelper/utils/helpers.dart';
import 'package:meetinghelper/utils/typedefs.dart';
import 'package:meetinghelper/views/lists/users_list.dart';
import 'package:meetinghelper/views/services_list.dart';
import 'package:provider/provider.dart';
import 'package:rxdart/rxdart.dart';

import '../../models/user.dart';

class EditUser extends StatefulWidget {
  final User user;

  const EditUser({Key? key, required this.user}) : super(key: key);
  @override
  _EditUserState createState() => _EditUserState();
}

class _EditUserState extends State<EditUser> {
  List<FocusNode> foci = [
    FocusNode(),
    FocusNode(),
    FocusNode(),
    FocusNode(),
    FocusNode(),
    FocusNode(),
    FocusNode()
  ];
  AsyncCache<String?> className = AsyncCache(const Duration(minutes: 1));
  late Json old;

  GlobalKey<FormState> form = GlobalKey<FormState>();

  List<User>? childrenUsers;

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
                      widget.user.name,
                      style: const TextStyle(
                        fontSize: 16.0,
                      ),
                    ),
                  ),
                  background: widget.user.getPhoto(false, false),
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
                    decoration: InputDecoration(
                        labelText: 'الاسم',
                        border: OutlineInputBorder(
                          borderSide:
                              BorderSide(color: Theme.of(context).primaryColor),
                        )),
                    focusNode: foci[0],
                    textInputAction: TextInputAction.next,
                    onFieldSubmitted: (_) => foci[1].requestFocus(),
                    initialValue: widget.user.name,
                    onChanged: nameChanged,
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
                  child: Focus(
                    focusNode: foci[2],
                    child: InkWell(
                      onTap: () async =>
                          widget.user.lastTanawol = await _selectDate(
                        'تاريخ أخر تناول',
                        widget.user.lastTanawolDate ?? DateTime.now(),
                      ),
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'تاريخ أخر تناول',
                          border: OutlineInputBorder(
                            borderSide: BorderSide(
                                color: Theme.of(context).primaryColor),
                          ),
                        ),
                        child: widget.user.lastTanawolDate != null
                            ? Text(DateFormat('yyyy/M/d').format(
                                widget.user.lastTanawolDate!,
                              ))
                            : const Text('لا يمكن التحديد'),
                      ),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Focus(
                    focusNode: foci[3],
                    child: InkWell(
                      onTap: () async =>
                          widget.user.lastConfession = await _selectDate(
                        'تاريخ أخر اعتراف',
                        widget.user.lastConfessionDate ?? DateTime.now(),
                      ),
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'تاريخ أخر اعتراف',
                          border: OutlineInputBorder(
                            borderSide: BorderSide(
                                color: Theme.of(context).primaryColor),
                          ),
                        ),
                        child: widget.user.lastConfessionDate != null
                            ? Text(DateFormat('yyyy/M/d').format(
                                widget.user.lastConfessionDate!,
                              ))
                            : const Text('لا يمكن التحديد'),
                      ),
                    ),
                  ),
                ),
                Focus(
                  child: GestureDetector(
                    onTap: _selectClass,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: InputDecorator(
                        isEmpty: widget.user.classId == null,
                        decoration: InputDecoration(
                          labelText: 'داخل فصل',
                          border: OutlineInputBorder(
                            borderSide: BorderSide(
                                color: Theme.of(context).primaryColor),
                          ),
                        ),
                        child: FutureBuilder<String?>(
                          future: className.fetch(() =>
                              widget.user.classId == null
                                  ? Future<String?>(() => null)
                                  : widget.user.getClassName()),
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
                ),
                if (User.instance.manageUsers)
                  ListTile(
                    trailing: Checkbox(
                      value: widget.user.manageUsers,
                      onChanged: (v) =>
                          setState(() => widget.user.manageUsers = v!),
                    ),
                    leading: const Icon(
                        IconData(0xef3d, fontFamily: 'MaterialIconsR')),
                    title: const Text('إدارة المستخدمين'),
                    onTap: () => setState(() =>
                        widget.user.manageUsers = !widget.user.manageUsers),
                  ),
                ListTile(
                  trailing: Checkbox(
                    value: widget.user.manageAllowedUsers,
                    onChanged: (v) =>
                        setState(() => widget.user.manageAllowedUsers = v!),
                  ),
                  leading: const Icon(
                      IconData(0xef3d, fontFamily: 'MaterialIconsR')),
                  title: const Text('إدارة مستخدمين محددين'),
                  onTap: () => setState(() => widget.user.manageAllowedUsers =
                      !widget.user.manageAllowedUsers),
                ),
                ListTile(
                  trailing: Checkbox(
                    value: widget.user.superAccess,
                    onChanged: (v) =>
                        setState(() => widget.user.superAccess = v!),
                  ),
                  leading: const Icon(
                      IconData(0xef56, fontFamily: 'MaterialIconsR')),
                  title: const Text('رؤية جميع البيانات'),
                  onTap: () => setState(
                      () => widget.user.superAccess = !widget.user.superAccess),
                ),
                ListTile(
                  trailing: Checkbox(
                    value: widget.user.manageDeleted,
                    onChanged: (v) =>
                        setState(() => widget.user.manageDeleted = v!),
                  ),
                  leading: const Icon(Icons.delete_outlined),
                  title: const Text('استرجاع المحذوفات'),
                  onTap: () => setState(() =>
                      widget.user.manageDeleted = !widget.user.manageDeleted),
                ),
                ListTile(
                  trailing: Checkbox(
                    value: widget.user.secretary,
                    onChanged: (v) =>
                        setState(() => widget.user.secretary = v!),
                  ),
                  leading: const Icon(Icons.shield),
                  title: const Text('تسجيل حضور الخدام'),
                  onTap: () => setState(
                      () => widget.user.secretary = !widget.user.secretary),
                ),
                ListTile(
                  trailing: Checkbox(
                    value: widget.user.write,
                    onChanged: (v) => setState(() => widget.user.write = v!),
                  ),
                  leading: const Icon(Icons.edit),
                  title: const Text('تعديل البيانات'),
                  onTap: () =>
                      setState(() => widget.user.write = !widget.user.write),
                ),
                ListTile(
                  trailing: Checkbox(
                    value: widget.user.exportClasses,
                    onChanged: (v) =>
                        setState(() => widget.user.exportClasses = v!),
                  ),
                  leading: const Icon(Icons.cloud_download),
                  title: const Text('تصدير فصل لملف إكسل'),
                  onTap: () => setState(() =>
                      widget.user.exportClasses = !widget.user.exportClasses),
                ),
                ListTile(
                  trailing: Checkbox(
                    value: widget.user.birthdayNotify,
                    onChanged: (v) =>
                        setState(() => widget.user.birthdayNotify = v!),
                  ),
                  leading: const Icon(
                      IconData(0xe7e9, fontFamily: 'MaterialIconsR')),
                  title: const Text('إشعار أعياد الميلاد'),
                  onTap: () => setState(() =>
                      widget.user.birthdayNotify = !widget.user.birthdayNotify),
                ),
                ListTile(
                  trailing: Checkbox(
                    value: widget.user.confessionsNotify,
                    onChanged: (v) =>
                        setState(() => widget.user.confessionsNotify = v!),
                  ),
                  leading: const Icon(
                      IconData(0xe7f7, fontFamily: 'MaterialIconsR')),
                  title: const Text('إشعار  الاعتراف'),
                  onTap: () => setState(() => widget.user.confessionsNotify =
                      !widget.user.confessionsNotify),
                ),
                ListTile(
                  trailing: Checkbox(
                    value: widget.user.tanawolNotify,
                    onChanged: (v) =>
                        setState(() => widget.user.tanawolNotify = v!),
                  ),
                  leading: const Icon(
                      IconData(0xe7f7, fontFamily: 'MaterialIconsR')),
                  title: const Text('إشعار التناول'),
                  onTap: () => setState(() =>
                      widget.user.tanawolNotify = !widget.user.tanawolNotify),
                ),
                ListTile(
                  trailing: Checkbox(
                    value: widget.user.kodasNotify,
                    onChanged: (v) =>
                        setState(() => widget.user.kodasNotify = v!),
                  ),
                  leading: const Icon(
                      IconData(0xe7f7, fontFamily: 'MaterialIconsR')),
                  title: const Text('إشعار القداس'),
                  onTap: () => setState(
                      () => widget.user.kodasNotify = !widget.user.kodasNotify),
                ),
                ListTile(
                  trailing: Checkbox(
                    value: widget.user.meetingNotify,
                    onChanged: (v) =>
                        setState(() => widget.user.meetingNotify = v!),
                  ),
                  leading: const Icon(
                      IconData(0xe7f7, fontFamily: 'MaterialIconsR')),
                  title: const Text('إشعار حضور الاجتماع'),
                  onTap: () => setState(() =>
                      widget.user.meetingNotify = !widget.user.meetingNotify),
                ),
                ElevatedButton.icon(
                  onPressed: editChildrenUsers,
                  icon: const Icon(Icons.shield),
                  label: Text(
                      'تعديل المستخدمين المسؤول عنهم ' + widget.user.name,
                      softWrap: false,
                      textScaleFactor: 0.95,
                      overflow: TextOverflow.fade),
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
            stream: FirebaseFirestore.instance
                .collection('UsersData')
                .where('AllowedUsers', arrayContains: widget.user.uid)
                .snapshots()
                .map((value) => value.docs.map(User.fromDoc).toList()),
            builder: (c, users) => users.hasData
                ? MultiProvider(
                    providers: [
                      Provider<DataObjectListController<User>>(
                        create: (_) => DataObjectListController<User>(
                          selectionMode: true,
                          itemsStream: User.getAllForUser(),
                          selected: {
                            for (var item in users.data!) item.id: item
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
                  )
                : const Center(child: CircularProgressIndicator()),
          );
        },
      ),
    );
  }

  void deleteUser() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('حذف حساب ${widget.user.name}'),
        content:
            Text('هل أنت متأكد من حذف حساب ' + widget.user.name + ' نهائيًا؟'),
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
                    .call({'affectedUser': widget.user.uid});
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
        title: Text('إلغاء تنشيط حساب ${widget.user.name}'),
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
                    .call({'affectedUser': widget.user.uid});
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
    old = widget.user.getUpdateMap();
    super.initState();
  }

  void nameChanged(String value) {
    widget.user.name = value;
  }

  Future resetPassword() async {
    if (await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('هل أنت متأكد من إعادة تعيين كلمة السر ل' +
                widget.user.name +
                '؟'),
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
          .call({'affectedUser': widget.user.uid});
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
        var update = widget.user.getUpdateMap()
          ..removeWhere((key, value) => old[key] == value);
        if (old['name'] != widget.user.name) {
          await FirebaseFunctions.instance.httpsCallable('changeUserName').call(
              {'affectedUser': widget.user.uid, 'newName': widget.user.name});
        }
        update..remove('name')..remove('classId');

        if (update.isNotEmpty) {
          await FirebaseFunctions.instance
              .httpsCallable('updatePermissions')
              .call({'affectedUser': widget.user.uid, 'permissions': update});
        }
        if (childrenUsers != null) {
          final batch = FirebaseFirestore.instance.batch();
          final oldChildren = (await FirebaseFirestore.instance
                  .collection('UsersData')
                  .where('AllowedUsers', arrayContains: widget.user.uid)
                  .get())
              .docs
              .map(User.fromDoc)
              .toList();
          for (final item in oldChildren) {
            if (!childrenUsers!.contains(item)) {
              batch.update(item.ref, {
                'AllowedUsers': FieldValue.arrayRemove([widget.user.uid])
              });
            }
          }
          for (final item in childrenUsers!) {
            if (!oldChildren.contains(item)) {
              batch.update(item.ref, {
                'AllowedUsers': FieldValue.arrayUnion([widget.user.uid])
              });
            }
          }
          await batch.commit();
        }
        if (old['classId'] != widget.user.classId?.path) {
          await FirebaseFirestore.instance
              .collection('UsersData')
              .doc(widget.user.refId)
              .update({'ClassId': widget.user.classId});
        }
        scaffoldMessenger.currentState!.hideCurrentSnackBar();
        navigator.currentState!.pop(widget.user);
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
    DateTime? picked = await showDatePicker(
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
        widget.user.classId = class$.ref;
        setState(() {});
        FocusScope.of(context).nextFocus();
      },
      itemsStream: classesByStudyYearRef(),
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
                      OrderOptions(),
                    ),
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
              color: Theme.of(context).primaryColor,
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
                      widget.user.classId = await navigator.currentState!
                              .pushNamed('Data/EditClass') as JsonRef? ??
                          widget.user.classId;
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
