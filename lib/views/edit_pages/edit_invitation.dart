import 'dart:async';

import 'package:churchdata_core/churchdata_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart' show FieldValue;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:intl/intl.dart';
import 'package:meetinghelper/models.dart';
import 'package:meetinghelper/repositories.dart';
import 'package:meetinghelper/utils/globals.dart';
import 'package:meetinghelper/widgets/search_filters.dart';
import 'package:rxdart/rxdart.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

class EditInvitation extends StatefulWidget {
  final Invitation invitation;

  const EditInvitation({
    required this.invitation,
    super.key,
  });
  @override
  _EditInvitationState createState() => _EditInvitationState();
}

class _EditInvitationState extends State<EditInvitation> {
  late Invitation invitation;

  AsyncMemoizerCache<String?> personName = AsyncMemoizerCache();

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
                  icon: const Icon(Icons.delete_forever),
                  tooltip: 'حذف الدعوة',
                  onPressed: deleteInvitation,
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
                      invitation.name,
                      style: const TextStyle(
                        fontSize: 16.0,
                      ),
                    ),
                  ),
                  background: const Icon(Icons.link),
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
                      labelText: 'عنوان الدعوة',
                    ),
                    textInputAction: TextInputAction.next,
                    onFieldSubmitted: (_) => FocusScope.of(context).nextFocus(),
                    initialValue: invitation.name,
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
                  child: GestureDetector(
                    onTap: () async =>
                        invitation = invitation.copyWith.expiryDate(
                      await _selectDateTime(
                            'تاريخ الانتهاء',
                            invitation.expiryDate,
                          ) ??
                          invitation.expiryDate,
                    ),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'تاريخ انتهاء الدعوة',
                      ),
                      child: Text(
                        DateFormat('h:m a yyyy/M/d', 'ar-EG')
                            .format(invitation.expiryDate),
                      ),
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: _selectPerson,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: InputDecorator(
                      isEmpty: invitation.permissions?['personId'] == null,
                      decoration: const InputDecoration(
                        labelText: 'ربط بخادم',
                      ),
                      child: FutureBuilder<String?>(
                        future: personName.runOnce(
                          () async {
                            if (invitation.permissions?['personId'] == null) {
                              return null;
                            } else {
                              return (await GetIt.I<DatabaseRepository>()
                                      .collection('UsersData')
                                      .doc(
                                        widget.invitation
                                            .permissions!['personId'],
                                      )
                                      .get())
                                  .data()?['Name'];
                            }
                          },
                        ),
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
                if (User.instance.permissions.manageUsers)
                  ListTile(
                    trailing: Checkbox(
                      value: invitation.permissions!['manageUsers'] ?? false,
                      onChanged: (v) => setState(
                        () => invitation = invitation.copyWith.permissions(
                          {
                            ...invitation.permissions ?? {},
                            'manageUsers': v,
                          },
                        ),
                      ),
                    ),
                    leading: const Icon(
                      IconData(0xef3d, fontFamily: 'MaterialIconsR'),
                    ),
                    title: const Text('إدارة المستخدمين'),
                    onTap: () => setState(
                      () => invitation.permissions!['manageUsers'] =
                          !(invitation.permissions!['manageUsers'] ?? false),
                    ),
                  ),
                ListTile(
                  trailing: Checkbox(
                    value:
                        invitation.permissions!['manageAllowedUsers'] ?? false,
                    onChanged: (v) => setState(
                      () => invitation = invitation.copyWith.permissions(
                        {
                          ...invitation.permissions ?? {},
                          'manageAllowedUsers': v,
                        },
                      ),
                    ),
                  ),
                  leading: const Icon(
                    IconData(0xef3d, fontFamily: 'MaterialIconsR'),
                  ),
                  title: const Text('إدارة مستخدمين محددين'),
                  onTap: () => setState(
                    () => widget.invitation.permissions!['manageAllowedUsers'] =
                        !(invitation.permissions!['manageAllowedUsers'] ??
                            false),
                  ),
                ),
                ListTile(
                  trailing: Checkbox(
                    value: invitation.permissions!['superAccess'] ?? false,
                    onChanged: (v) => setState(
                      () => invitation = invitation.copyWith.permissions(
                        {
                          ...invitation.permissions ?? {},
                          'superAccess': v,
                        },
                      ),
                    ),
                  ),
                  leading: const Icon(
                    IconData(0xef56, fontFamily: 'MaterialIconsR'),
                  ),
                  title: const Text('رؤية جميع البيانات'),
                  onTap: () => setState(
                    () => invitation.permissions!['superAccess'] =
                        !(invitation.permissions!['superAccess'] ?? false),
                  ),
                ),
                ListTile(
                  trailing: Checkbox(
                    value: invitation.permissions!['manageDeleted'] ?? false,
                    onChanged: (v) => setState(
                      () => invitation = invitation.copyWith.permissions(
                        {
                          ...invitation.permissions ?? {},
                          'manageDeleted': v,
                        },
                      ),
                    ),
                  ),
                  leading: const Icon(Icons.delete_outline),
                  title: const Text('استرجاع المحذوفات'),
                  onTap: () => setState(
                    () => invitation.permissions!['manageDeleted'] =
                        !(invitation.permissions!['manageDeleted'] ?? false),
                  ),
                ),
                ListTile(
                  trailing: Checkbox(
                    value: invitation.permissions!['changeHistory'] ?? false,
                    onChanged: (v) => setState(
                      () => invitation = invitation.copyWith.permissions(
                        {
                          ...invitation.permissions ?? {},
                          'changeHistory': v,
                        },
                      ),
                    ),
                  ),
                  leading: const Icon(Icons.history),
                  title: const Text('تعديل الكشوفات القديمة'),
                  onTap: () => setState(
                    () => invitation.permissions!['changeHistory'] =
                        !(invitation.permissions!['changeHistory'] ?? false),
                  ),
                ),
                ListTile(
                  trailing: Checkbox(
                    value: invitation.permissions!['recordHistory'] ?? false,
                    onChanged: (v) => setState(
                      () => invitation = invitation.copyWith.permissions(
                        {
                          ...invitation.permissions ?? {},
                          'recordHistory': v,
                        },
                      ),
                    ),
                  ),
                  leading: const Icon(Icons.history),
                  title: const Text('تسجيل حضور المخدومين'),
                  onTap: () => setState(
                    () => widget.invitation.permissions!['recordHistory'] =
                        !(invitation.permissions!['recordHistory'] ?? false),
                  ),
                ),
                ListTile(
                  trailing: Checkbox(
                    value: invitation.permissions!['secretary'] ?? false,
                    onChanged: (v) => setState(
                      () => invitation = invitation.copyWith.permissions(
                        {
                          ...invitation.permissions ?? {},
                          'secretary': v,
                        },
                      ),
                    ),
                  ),
                  leading: const Icon(Icons.history),
                  title: const Text('تسجيل حضور الخدام'),
                  onTap: () => setState(
                    () => widget.invitation.permissions!['secretary'] =
                        !(invitation.permissions!['secretary'] ?? false),
                  ),
                ),
                ListTile(
                  trailing: Checkbox(
                    value: invitation.permissions!['write'] ?? false,
                    onChanged: (v) => setState(
                      () => invitation = invitation.copyWith.permissions(
                        {
                          ...invitation.permissions ?? {},
                          'write': v,
                        },
                      ),
                    ),
                  ),
                  leading: const Icon(Icons.edit),
                  title: const Text('تعديل البيانات'),
                  onTap: () => setState(
                    () => invitation.permissions!['write'] =
                        !(invitation.permissions!['write'] ?? false),
                  ),
                ),
                ListTile(
                  trailing: Checkbox(
                    value: invitation.permissions!['export'] ?? false,
                    onChanged: (v) => setState(
                      () => invitation = invitation.copyWith.permissions(
                        {
                          ...invitation.permissions ?? {},
                          'export': v,
                        },
                      ),
                    ),
                  ),
                  leading: const Icon(Icons.cloud_download),
                  title: const Text('تصدير فصل لملف إكسل'),
                  onTap: () => setState(
                    () => invitation.permissions!['export'] =
                        !(invitation.permissions!['export'] ?? false),
                  ),
                ),
                ListTile(
                  trailing: Checkbox(
                    value: invitation.permissions!['birthdayNotify'] ?? false,
                    onChanged: (v) => setState(
                      () => invitation = invitation.copyWith.permissions(
                        {
                          ...invitation.permissions ?? {},
                          'birthdayNotify': v,
                        },
                      ),
                    ),
                  ),
                  leading: const Icon(
                    IconData(0xe7e9, fontFamily: 'MaterialIconsR'),
                  ),
                  title: const Text('إشعار أعياد الميلاد'),
                  onTap: () => setState(
                    () => invitation.permissions!['birthdayNotify'] =
                        !(invitation.permissions!['birthdayNotify'] ?? false),
                  ),
                ),
                ListTile(
                  trailing: Checkbox(
                    value:
                        invitation.permissions!['confessionsNotify'] ?? false,
                    onChanged: (v) => setState(
                      () => invitation = invitation.copyWith.permissions(
                        {
                          ...invitation.permissions ?? {},
                          'confessionsNotify': v,
                        },
                      ),
                    ),
                  ),
                  leading: const Icon(
                    IconData(0xe7f7, fontFamily: 'MaterialIconsR'),
                  ),
                  title: const Text('إشعار  الاعتراف'),
                  onTap: () => setState(
                    () => widget.invitation.permissions!['confessionsNotify'] =
                        !(invitation.permissions!['confessionsNotify'] ??
                            false),
                  ),
                ),
                ListTile(
                  trailing: Checkbox(
                    value: invitation.permissions!['tanawolNotify'] ?? false,
                    onChanged: (v) => setState(
                      () => invitation = invitation.copyWith.permissions(
                        {
                          ...invitation.permissions ?? {},
                          'tanawolNotify': v,
                        },
                      ),
                    ),
                  ),
                  leading: const Icon(
                    IconData(0xe7f7, fontFamily: 'MaterialIconsR'),
                  ),
                  title: const Text('إشعار التناول'),
                  onTap: () => setState(
                    () => invitation.permissions!['tanawolNotify'] =
                        !(invitation.permissions!['tanawolNotify'] ?? false),
                  ),
                ),
                ListTile(
                  trailing: Checkbox(
                    value: invitation.permissions!['kodasNotify'] ?? false,
                    onChanged: (v) => setState(
                      () => invitation = invitation.copyWith.permissions(
                        {
                          ...invitation.permissions ?? {},
                          'kodasNotify': v,
                        },
                      ),
                    ),
                  ),
                  leading: const Icon(
                    IconData(0xe7f7, fontFamily: 'MaterialIconsR'),
                  ),
                  title: const Text('إشعار القداس'),
                  onTap: () => setState(
                    () => invitation.permissions!['kodasNotify'] =
                        !(invitation.permissions!['kodasNotify'] ?? false),
                  ),
                ),
                ListTile(
                  trailing: Checkbox(
                    value: invitation.permissions!['meetingNotify'] ?? false,
                    onChanged: (v) => setState(
                      () => invitation = invitation.copyWith.permissions(
                        {
                          ...invitation.permissions ?? {},
                          'meetingNotify': v,
                        },
                      ),
                    ),
                  ),
                  leading: const Icon(
                    IconData(0xe7f7, fontFamily: 'MaterialIconsR'),
                  ),
                  title: const Text('إشعار حضور الاجتماع'),
                  onTap: () => setState(
                    () => invitation.permissions!['meetingNotify'] =
                        !(invitation.permissions!['meetingNotify'] ?? false),
                  ),
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

  Future<void> deleteInvitation() async {
    if (await showDialog(
          context: context,
          builder: (innerContext) => AlertDialog(
            content: const Text('هل تريد حذف هذه الدعوة؟'),
            actions: <Widget>[
              TextButton(
                style: Theme.of(innerContext).textButtonTheme.style!.copyWith(
                      foregroundColor: MaterialStateProperty.resolveWith(
                        (state) => Colors.red,
                      ),
                    ),
                onPressed: () {
                  navigator.currentState!.pop(true);
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
        ) ==
        true) {
      scaffoldMessenger.currentState!.showSnackBar(
        const SnackBar(
          content: LinearProgressIndicator(),
          duration: Duration(seconds: 15),
        ),
      );
      if (await Connectivity().checkConnectivity() != ConnectivityResult.none) {
        await invitation.ref.delete();
      } else {
        // ignore: unawaited_futures
        invitation.ref.delete();
      }
      navigator.currentState!.pop('deleted');
      scaffoldMessenger.currentState!.hideCurrentSnackBar();
      scaffoldMessenger.currentState!.showSnackBar(
        const SnackBar(
          content: Text('تم بنجاح'),
          duration: Duration(seconds: 15),
        ),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    invitation = widget.invitation.copyWith();
  }

  void nameChanged(String value) {
    invitation = invitation.copyWith.title(value);
  }

  Future save() async {
    if (await Connectivity().checkConnectivity() == ConnectivityResult.none) {
      await showDialog(
        context: context,
        builder: (context) =>
            const AlertDialog(content: Text('لا يوجد اتصال انترنت')),
      );
      return;
    }
    try {
      if (form.currentState!.validate() &&
          invitation.expiryDate.difference(DateTime.now()) >=
              const Duration(hours: 24)) {
        scaffoldMessenger.currentState!.showSnackBar(
          const SnackBar(
            content: Text('جار الحفظ...'),
            duration: Duration(seconds: 15),
          ),
        );
        if (invitation.id == 'null') {
          invitation = invitation.copyWith.ref(
            GetIt.I<DatabaseRepository>().collection('Invitations').doc(),
          );
          invitation = invitation.copyWith.generatedBy(User.instance.uid);
          if (await Connectivity().checkConnectivity() !=
              ConnectivityResult.none) {
            await invitation.ref.set({
              ...invitation.toJson(),
              'GeneratedOn': FieldValue.serverTimestamp(),
            });
          } else {
            // ignore: unawaited_futures
            invitation.ref.set({
              ...invitation.toJson(),
              'GeneratedOn': FieldValue.serverTimestamp(),
            });
          }
        } else {
          final update = invitation.toJson()
            ..removeWhere(
              (key, value) => widget.invitation.toJson()[key] == value,
            );
          if (update.isNotEmpty) {
            if (await Connectivity().checkConnectivity() !=
                ConnectivityResult.none) {
              await invitation.update(old: update);
            } else {
              // ignore: unawaited_futures
              invitation.update(old: update);
            }
          }
        }
        scaffoldMessenger.currentState!.hideCurrentSnackBar();
        navigator.currentState!.pop(invitation.ref);
        scaffoldMessenger.currentState!.showSnackBar(
          const SnackBar(
            content: Text('تم الحفظ بنجاح'),
            duration: Duration(seconds: 1),
          ),
        );
      } else {
        await showDialog(
          context: context,
          builder: (context) => const AlertDialog(
            content: Text(
              'يرجى ملء تاريخ انتهاء الدعوة على أن يكون على الأقل بعد 24 ساعة',
            ),
          ),
        );
      }
    } catch (err, stack) {
      await Sentry.captureException(
        err,
        stackTrace: stack,
        withScope: (scope) =>
            scope.setTag('LasErrorIn', '_EditInvitationState.save'),
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

  Future<DateTime?> _selectDateTime(
    String helpText,
    DateTime initialDate,
  ) async {
    var picked = await showDatePicker(
      helpText: helpText,
      locale: const Locale('ar', 'EG'),
      context: context,
      initialDate: initialDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 14)),
    );
    if (picked != null && picked != initialDate) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(initialDate),
      );
      if (time != null) {
        picked = picked.add(Duration(hours: time.hour, minutes: time.minute));
      }
      setState(() {});
      FocusScope.of(context).nextFocus();
      return picked;
    }
    return null;
  }

  Future<void> _selectPerson() async {
    final controller = ListController<Class?, User>(
      objectsPaginatableStream: PaginatableStream.loadAll(
        stream: MHDatabaseRepo.instance.users.getAllUsers().map(
              (users) => users.where((u) => u.uid == User.emptyUID).toList(),
            ),
      ),
      groupByStream: MHDatabaseRepo.I.users.groupUsersByClass,
      groupingStream: Stream.value(true),
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
                SearchFilters(
                  Person,
                  options: controller,
                  orderOptions: BehaviorSubject<OrderOptions>.seeded(
                    const OrderOptions(),
                  ),
                  textStyle: Theme.of(context).textTheme.bodyMedium,
                ),
                Expanded(
                  child: DataObjectListView<Class?, User>(
                    controller: controller,
                    onTap: (person) {
                      navigator.currentState!.pop();

                      if (invitation.permissions == null) {
                        invitation = invitation.copyWith.permissions({});
                      }

                      invitation = invitation.copyWith.permissions(
                        {
                          ...invitation.permissions!,
                          'personId': person.ref.id,
                        },
                      );

                      personName.invalidate();
                      setState(() {});
                      FocusScope.of(context).nextFocus();
                    },
                    autoDisposeController: false,
                  ),
                ),
              ],
            ),
            bottomNavigationBar: BottomAppBar(
              color: Theme.of(context).colorScheme.primary,
              shape: const CircularNotchedRectangle(),
              child: StreamBuilder<List?>(
                stream: controller.objectsStream,
                builder: (context, snapshot) {
                  return Text(
                    (snapshot.data?.length ?? 0).toString() + ' خادم',
                    textAlign: TextAlign.center,
                    strutStyle:
                        StrutStyle(height: IconTheme.of(context).size! / 7.5),
                    style: Theme.of(context).primaryTextTheme.bodyLarge,
                  );
                },
              ),
            ),
          ),
        );
      },
    );
    await controller.dispose();
  }
}
