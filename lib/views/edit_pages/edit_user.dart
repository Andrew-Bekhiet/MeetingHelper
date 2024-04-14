import 'dart:async';

import 'package:churchdata_core/churchdata_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:intl/intl.dart';
import 'package:meetinghelper/controllers.dart';
import 'package:meetinghelper/models.dart';
import 'package:meetinghelper/repositories.dart';
import 'package:meetinghelper/services.dart';
import 'package:meetinghelper/utils/globals.dart';
import 'package:meetinghelper/utils/helpers.dart';
import 'package:meetinghelper/widgets.dart';
import 'package:provider/provider.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

class EditUser extends StatefulWidget {
  final UserWithPerson user;

  const EditUser({
    required this.user,
    super.key,
  });
  @override
  _EditUserState createState() => _EditUserState();
}

class _EditUserState extends State<EditUser> {
  late UserWithPerson user;
  List<User>? childrenUsers;
  List<Class>? adminOnClasses;

  GlobalKey<FormState> form = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return <Widget>[
            SliverAppBar(
              expandedHeight: 250.0,
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
                  background: UserPhotoWidget(
                    user,
                    circleCrop: false,
                    showActivityStatus: false,
                  ),
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
                    onChanged: (v) => user = user.copyWith.name(v),
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
                    onTap: () async => user = user.copyWith.lastTanawol(
                      await _selectDate(
                        'تاريخ أخر تناول',
                        user.lastTanawol ?? DateTime.now(),
                      ),
                    ),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'تاريخ أخر تناول',
                      ),
                      child: user.lastTanawol != null
                          ? Text(
                              DateFormat('yyyy/M/d').format(
                                user.lastTanawol!,
                              ),
                            )
                          : const Text('لا يمكن التحديد'),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: InkWell(
                    onTap: () async => user = user.copyWith.lastConfession(
                      await _selectDate(
                        'تاريخ أخر اعتراف',
                        user.lastConfession ?? DateTime.now(),
                      ),
                    ),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'تاريخ أخر اعتراف',
                      ),
                      child: user.lastConfession != null
                          ? Text(
                              DateFormat('yyyy/M/d').format(
                                user.lastConfession!,
                              ),
                            )
                          : const Text('لا يمكن التحديد'),
                    ),
                  ),
                ),
                if (User.instance.permissions.manageUsers)
                  ListTile(
                    trailing: Checkbox(
                      value: user.permissions.manageUsers,
                      onChanged: (v) => setState(
                        () => user = user.copyWith.permissions(
                          user.permissions.copyWith.manageUsers(v!),
                        ),
                      ),
                    ),
                    leading: const Icon(
                      IconData(0xef3d, fontFamily: 'MaterialIconsR'),
                    ),
                    title: const Text('إدارة المستخدمين'),
                    onTap: () => setState(
                      () => user = user.copyWith.permissions(
                        user.permissions.copyWith
                            .manageUsers(!user.permissions.manageUsers),
                      ),
                    ),
                  ),
                ListTile(
                  trailing: Checkbox(
                    value: user.permissions.manageAllowedUsers,
                    onChanged: (v) => setState(
                      () => user = user.copyWith.permissions(
                        user.permissions.copyWith.manageAllowedUsers(v!),
                      ),
                    ),
                  ),
                  leading: const Icon(
                    IconData(0xef3d, fontFamily: 'MaterialIconsR'),
                  ),
                  title: const Text('إدارة مستخدمين محددين'),
                  onTap: () => setState(
                    () => user = user.copyWith.permissions(
                      user.permissions.copyWith.manageAllowedUsers(
                        !user.permissions.manageAllowedUsers,
                      ),
                    ),
                  ),
                ),
                ListTile(
                  trailing: Checkbox(
                    value: user.permissions.superAccess,
                    onChanged: (v) => setState(
                      () => user = user.copyWith.permissions(
                        user.permissions.copyWith.superAccess(v!),
                      ),
                    ),
                  ),
                  leading: const Icon(
                    IconData(0xef56, fontFamily: 'MaterialIconsR'),
                  ),
                  title: const Text('رؤية جميع البيانات'),
                  onTap: () => setState(
                    () => user = user.copyWith.permissions(
                      user.permissions.copyWith
                          .superAccess(!user.permissions.superAccess),
                    ),
                  ),
                ),
                ListTile(
                  trailing: Checkbox(
                    value: user.permissions.manageDeleted,
                    onChanged: (v) => setState(
                      () => user = user.copyWith.permissions(
                        user.permissions.copyWith.manageDeleted(v!),
                      ),
                    ),
                  ),
                  leading: const Icon(Icons.delete_outlined),
                  title: const Text('استرجاع المحذوفات'),
                  onTap: () => setState(
                    () => user = user.copyWith.permissions(
                      user.permissions.copyWith
                          .manageDeleted(!user.permissions.manageDeleted),
                    ),
                  ),
                ),
                ListTile(
                  trailing: Checkbox(
                    value: user.permissions.changeHistory,
                    onChanged: (v) => setState(
                      () => user = user.copyWith.permissions(
                        user.permissions.copyWith.changeHistory(v!),
                      ),
                    ),
                  ),
                  leading: const Icon(Icons.history),
                  title: const Text('تعديل الكشوفات القديمة'),
                  onTap: () => setState(
                    () => user = user.copyWith.permissions(
                      user.permissions.copyWith
                          .changeHistory(!user.permissions.changeHistory),
                    ),
                  ),
                ),
                ListTile(
                  trailing: Checkbox(
                    value: user.permissions.recordHistory,
                    onChanged: (v) => setState(
                      () => user = user.copyWith.permissions(
                        user.permissions.copyWith.recordHistory(v!),
                      ),
                    ),
                  ),
                  leading: const Icon(Icons.history),
                  title: const Text('تسجيل حضور المخدومين'),
                  onTap: () => setState(
                    () => user = user.copyWith.permissions(
                      user.permissions.copyWith.recordHistory(
                        !user.permissions.recordHistory,
                      ),
                    ),
                  ),
                ),
                ListTile(
                  trailing: Checkbox(
                    value: user.permissions.secretary,
                    onChanged: (v) => setState(
                      () => user = user.copyWith.permissions(
                        user.permissions.copyWith.secretary(v!),
                      ),
                    ),
                  ),
                  leading: const Icon(Icons.history),
                  title: const Text('تسجيل حضور الخدام'),
                  onTap: () => setState(
                    () => user = user.copyWith.permissions(
                      user.permissions.copyWith.secretary(
                        !user.permissions.secretary,
                      ),
                    ),
                  ),
                ),
                ListTile(
                  trailing: Checkbox(
                    value: user.permissions.write,
                    onChanged: (v) => setState(
                      () => user = user.copyWith.permissions(
                        user.permissions.copyWith.write(v!),
                      ),
                    ),
                  ),
                  leading: const Icon(Icons.edit),
                  title: const Text('تعديل البيانات'),
                  onTap: () => setState(
                    () => user = user.copyWith.permissions(
                      user.permissions.copyWith.write(
                        !user.permissions.write,
                      ),
                    ),
                  ),
                ),
                ListTile(
                  trailing: Checkbox(
                    value: user.permissions.export,
                    onChanged: (v) => setState(
                      () => user = user.copyWith.permissions(
                        user.permissions.copyWith.export(v!),
                      ),
                    ),
                  ),
                  leading: const Icon(Icons.cloud_download),
                  title: const Text('تصدير فصل لملف إكسل'),
                  onTap: () => setState(
                    () => user = user.copyWith.permissions(
                      user.permissions.copyWith.export(
                        !user.permissions.export,
                      ),
                    ),
                  ),
                ),
                ListTile(
                  trailing: Checkbox(
                    value: user.permissions.birthdayNotify,
                    onChanged: (v) => setState(
                      () => user = user.copyWith.permissions(
                        user.permissions.copyWith.birthdayNotify(v!),
                      ),
                    ),
                  ),
                  leading: const Icon(
                    IconData(0xe7e9, fontFamily: 'MaterialIconsR'),
                  ),
                  title: const Text('إشعار أعياد الميلاد'),
                  onTap: () => setState(
                    () => user = user.copyWith.permissions(
                      user.permissions.copyWith
                          .birthdayNotify(!user.permissions.birthdayNotify),
                    ),
                  ),
                ),
                ListTile(
                  trailing: Checkbox(
                    value: user.permissions.confessionsNotify,
                    onChanged: (v) => setState(
                      () => user = user.copyWith.permissions(
                        user.permissions.copyWith.confessionsNotify(v!),
                      ),
                    ),
                  ),
                  leading: const Icon(
                    IconData(0xe7f7, fontFamily: 'MaterialIconsR'),
                  ),
                  title: const Text('إشعار  الاعتراف'),
                  onTap: () => setState(
                    () => user = user.copyWith.permissions(
                      user.permissions.copyWith.confessionsNotify(
                        !user.permissions.confessionsNotify,
                      ),
                    ),
                  ),
                ),
                ListTile(
                  trailing: Checkbox(
                    value: user.permissions.tanawolNotify,
                    onChanged: (v) => setState(
                      () => user = user.copyWith.permissions(
                        user.permissions.copyWith.tanawolNotify(v!),
                      ),
                    ),
                  ),
                  leading: const Icon(
                    IconData(0xe7f7, fontFamily: 'MaterialIconsR'),
                  ),
                  title: const Text('إشعار التناول'),
                  onTap: () => setState(
                    () => user = user.copyWith.permissions(
                      user.permissions.copyWith
                          .tanawolNotify(!user.permissions.tanawolNotify),
                    ),
                  ),
                ),
                ListTile(
                  trailing: Checkbox(
                    value: user.permissions.kodasNotify,
                    onChanged: (v) => setState(
                      () => user = user.copyWith.permissions(
                        user.permissions.copyWith.kodasNotify(v!),
                      ),
                    ),
                  ),
                  leading: const Icon(
                    IconData(0xe7f7, fontFamily: 'MaterialIconsR'),
                  ),
                  title: const Text('إشعار القداس'),
                  onTap: () => setState(
                    () => user = user.copyWith.permissions(
                      user.permissions.copyWith
                          .kodasNotify(!user.permissions.kodasNotify),
                    ),
                  ),
                ),
                ListTile(
                  trailing: Checkbox(
                    value: user.permissions.meetingNotify,
                    onChanged: (v) => setState(
                      () => user = user.copyWith.permissions(
                        user.permissions.copyWith.meetingNotify(v!),
                      ),
                    ),
                  ),
                  leading: const Icon(
                    IconData(0xe7f7, fontFamily: 'MaterialIconsR'),
                  ),
                  title: const Text('إشعار حضور الاجتماع'),
                  onTap: () => setState(
                    () => user = user.copyWith.permissions(
                      user.permissions.copyWith
                          .meetingNotify(!user.permissions.meetingNotify),
                    ),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: editAdminServices,
                  icon: const Icon(Icons.miscellaneous_services),
                  label: Text(
                    'تعديل الخدمات المسؤول عنها ' + user.name,
                    softWrap: false,
                    textScaler: const TextScaler.linear(0.95),
                    overflow: TextOverflow.fade,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: editAdminOnClasses,
                  icon: const Icon(Icons.groups),
                  label: Text(
                    'تعديل الفصول المسؤول عنهم ' + user.name,
                    softWrap: false,
                    textScaler: const TextScaler.linear(0.95),
                    overflow: TextOverflow.fade,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: editChildrenUsers,
                  icon: const Icon(Icons.shield),
                  label: Text(
                    'تعديل المستخدمين المسؤول عنهم ' + user.name,
                    softWrap: false,
                    textScaler: const TextScaler.linear(0.95),
                    overflow: TextOverflow.fade,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: resetPassword,
                  icon: const Icon(Icons.lock_open),
                  label: const Text('إعادة تعيين كلمة السر'),
                ),
                const SizedBox(height: 60),
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

  Future<void> editChildrenUsers() async {
    childrenUsers = await navigator.currentState!.push(
          MaterialPageRoute(
            builder: (context) {
              return StreamBuilder<List<User>>(
                stream: childrenUsers != null
                    ? Stream.value(childrenUsers!)
                    : GetIt.I<DatabaseRepository>()
                        .collection('UsersData')
                        .where('AllowedUsers', arrayContains: user.uid)
                        .snapshots()
                        .map(
                          (value) =>
                              value.docs.map(UserWithPerson.fromDoc).toList(),
                        ),
                builder: (c, users) {
                  if (!users.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  return MultiProvider(
                    providers: [
                      Provider<ListController<Class?, User>>(
                        create: (_) => ListController<Class?, User>(
                          groupByStream:
                              MHDatabaseRepo.I.users.groupUsersByClass,
                          objectsPaginatableStream: PaginatableStream.loadAll(
                            stream: MHDatabaseRepo.instance.users.getAllUsers(),
                          ),
                        )..selectAll(users.data),
                        dispose: (context, c) => c.dispose(),
                      ),
                    ],
                    builder: (context, child) => Scaffold(
                      persistentFooterButtons: [
                        TextButton(
                          onPressed: () {
                            navigator.currentState!.pop(
                              context
                                  .read<ListController<Class?, User>>()
                                  .currentSelection
                                  ?.toList(),
                            );
                          },
                          child: const Text('تم'),
                        ),
                      ],
                      appBar: AppBar(
                        title: SearchField(
                          showSuffix: false,
                          searchStream: context
                              .read<ListController<Class?, User>>()
                              .searchSubject,
                          textStyle: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                      body: DataObjectListView(
                        controller:
                            context.read<ListController<Class?, User>>(),
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

  Future<void> editAdminOnClasses() async {
    adminOnClasses = await navigator.currentState!.push(
          MaterialPageRoute(
            builder: (context) {
              return StreamBuilder<List<Class>>(
                stream: adminOnClasses != null
                    ? Stream.value(adminOnClasses!)
                    : GetIt.I<MHDatabaseRepo>().classes.getAll(
                          queryCompleter: (q, order, desc) => q
                              .where('Allowed', arrayContains: user.uid)
                              .orderBy(order, descending: desc),
                        ),
                builder: (c, classes) {
                  if (!classes.hasData) {
                    return const Scaffold(
                      body: Center(child: CircularProgressIndicator()),
                    );
                  }

                  return MultiProvider(
                    providers: [
                      Provider<ServicesListController>(
                        create: (_) => ServicesListController<Class>(
                          objectsPaginatableStream: PaginatableStream.loadAll(
                            stream: Stream.value([]),
                          ),
                          groupByStream: (_) => MHDatabaseRepo.I.services
                              .groupServicesByStudyYearRef<Class>(),
                        )..selectAll(classes.data),
                        dispose: (context, c) => c.dispose(),
                      ),
                    ],
                    builder: (context, child) => Scaffold(
                      persistentFooterButtons: [
                        TextButton(
                          onPressed: () {
                            navigator.currentState!.pop(
                              context
                                  .read<ServicesListController>()
                                  .currentSelection
                                  ?.toList()
                                  .cast<Class>(),
                            );
                          },
                          child: const Text('تم'),
                        ),
                      ],
                      appBar: AppBar(
                        title: SearchField(
                          showSuffix: false,
                          searchStream: context
                              .read<ServicesListController>()
                              .searchSubject,
                          textStyle: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                      body: ServicesList(
                        options: context.read<ServicesListController>(),
                        autoDisposeController: false,
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ) ??
        adminOnClasses;
  }

  Future<void> editAdminServices() async {
    final selected = await Future.wait(
      user.adminServices.map(
        (e) async {
          final data = await e.get();
          if (data.exists) return Service.fromDoc(data);
        },
      ),
    );

    user = user.copyWith.adminServices(
      (await selectServices<Service>(selected.whereType<Service>().toList()))
              ?.map((s) => s.ref)
              .toList() ??
          user.adminServices,
    );
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
                      MaterialStateProperty.resolveWith((state) => Colors.red),
                ),
            onPressed: () async {
              try {
                scaffoldMessenger.currentState!.showSnackBar(
                  const SnackBar(
                    content: LinearProgressIndicator(),
                    duration: Duration(seconds: 15),
                  ),
                );
                navigator.currentState!.pop();
                await GetIt.I<FunctionsService>()
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
              } catch (err, stack) {
                await Sentry.captureException(
                  err,
                  stackTrace: stack,
                  withScope: (scope) => scope.setTag(
                    'LasErrorIn',
                    '_EditUserState.deleteUser',
                  ),
                );
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
                scaffoldMessenger.currentState!.showSnackBar(
                  const SnackBar(
                    content: LinearProgressIndicator(),
                    duration: Duration(seconds: 15),
                  ),
                );
                navigator.currentState!.pop();
                await GetIt.I<FunctionsService>()
                    .httpsCallable('unApproveUser')
                    .call({'affectedUser': user.uid});
                navigator.currentState!.pop('deleted');
                scaffoldMessenger.currentState!.hideCurrentSnackBar();
                scaffoldMessenger.currentState!.showSnackBar(
                  const SnackBar(
                    content: Text('تم بنجاح'),
                    duration: Duration(seconds: 15),
                  ),
                );
              } catch (err, stack) {
                await Sentry.captureException(
                  err,
                  stackTrace: stack,
                  withScope: (scope) => scope.setTag(
                    'LasErrorIn',
                    '_EditUserState.unApproveUser',
                  ),
                );
                scaffoldMessenger.currentState!.hideCurrentSnackBar();
                scaffoldMessenger.currentState!.showSnackBar(
                  SnackBar(
                    content: Text(err.toString()),
                    duration: const Duration(seconds: 7),
                  ),
                );
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
    user = widget.user.copyWith();
  }

  void nameChanged(String value) {
    user = user.copyWith.name(value);
  }

  Future resetPassword() async {
    if (await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(
              'هل أنت متأكد من إعادة تعيين كلمة السر ل' + user.name + '؟',
            ),
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
      await GetIt.I<FunctionsService>()
          .httpsCallable('resetPassword')
          .call({'affectedUser': user.uid});
      scaffoldMessenger.currentState!.hideCurrentSnackBar();
      scaffoldMessenger.currentState!.showSnackBar(
        const SnackBar(
          content: Text('تم إعادة تعيين كلمة السر بنجاح'),
        ),
      );
    } catch (err, stack) {
      await Sentry.captureException(
        err,
        stackTrace: stack,
        withScope: (scope) =>
            scope.setTag('LasErrorIn', '_EditUserState.resetPassword'),
      );
      scaffoldMessenger.currentState!.showSnackBar(
        SnackBar(
          content: Text(err.toString()),
        ),
      );
    }
  }

  Future save() async {
    if ((await Connectivity().checkConnectivity()).any(
      (c) =>
          c == ConnectivityResult.mobile ||
          c == ConnectivityResult.wifi ||
          c == ConnectivityResult.ethernet,
    )) {
      await showDialog(
        context: context,
        builder: (context) =>
            const AlertDialog(content: Text('لا يوجد اتصال انترنت')),
      );
      return;
    }
    try {
      if (form.currentState!.validate()) {
        scaffoldMessenger.currentState!.showSnackBar(
          const SnackBar(
            content: Text('جار الحفظ...'),
            duration: Duration(seconds: 15),
          ),
        );

        await GetIt.I<MHFunctionsService>().updateUser(
          old: widget.user,
          new$: user,
          childrenUsers: childrenUsers,
        );

        if (adminOnClasses != null) {
          await _updateUserAdminOnClasses(adminOnClasses!);
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
    } catch (err, stack) {
      await Sentry.captureException(
        err,
        stackTrace: stack,
        withScope: (scope) => scope.setTag('LasErrorIn', '_EditUserState.save'),
      );
      scaffoldMessenger.currentState!.hideCurrentSnackBar();
      scaffoldMessenger.currentState!.showSnackBar(
        SnackBar(
          content: Text(err.toString()),
          duration: const Duration(seconds: 7),
        ),
      );
    }
  }

  Future<DateTime?> _selectDate(String helpText, DateTime initialDate) async {
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
      return picked;
    }
    return null;
  }

  Future<void> _updateUserAdminOnClasses(List<Class> newClassesList) async {
    final EqualityBy<Class, String> equalityById =
        EqualityBy<Class, String>((c) => c.id);

    final Set<Class> newClasses = EqualitySet.from(
      equalityById,
      newClassesList,
    );

    final Set<Class> oldClasses = EqualitySet.from(
      equalityById,
      (await MHDatabaseRepo.I.classes.getAll().first)
          .where((c) => c.allowedUsers.contains(user.uid)),
    );
    final toRemove = oldClasses.difference(newClasses).toList();
    final toAdd = newClasses.difference(oldClasses).toList();

    await MHDatabaseRepo.I.runTransaction(
      (tr) async {
        for (final c in toRemove) {
          tr.update(c.ref, {
            'Allowed': FieldValue.arrayRemove([user.uid]),
          });
        }

        for (final c in toAdd) {
          tr.update(c.ref, {
            'Allowed': FieldValue.arrayUnion([user.uid]),
          });
        }
      },
    );
  }
}
