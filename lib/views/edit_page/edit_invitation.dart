import 'dart:async';

import 'package:async/async.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:meetinghelper/models/data/invitation.dart';
import 'package:meetinghelper/models/list_controllers.dart';
import 'package:meetinghelper/models/search/order_options.dart';
import 'package:meetinghelper/models/search/search_filters.dart';
import 'package:meetinghelper/utils/globals.dart';
import 'package:meetinghelper/utils/typedefs.dart';
import 'package:meetinghelper/views/list.dart';
import 'package:rxdart/rxdart.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../../models/data/user.dart';

class EditInvitation extends StatefulWidget {
  final Invitation invitation;

  const EditInvitation({Key? key, required this.invitation}) : super(key: key);
  @override
  _EditInvitationState createState() => _EditInvitationState();
}

class _EditInvitationState extends State<EditInvitation> {
  late Json old;

  AsyncCache<String?> personName = AsyncCache(const Duration(minutes: 1));

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
                    child: Text(widget.invitation.name,
                        style: const TextStyle(
                          fontSize: 16.0,
                        )),
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
                    initialValue: widget.invitation.name,
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
                    onTap: () async => widget.invitation.expiryDate =
                        await _selectDateTime('تاريخ الانتهاء',
                            widget.invitation.expiryDate.toDate()),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'تاريخ انتهاء الدعوة',
                      ),
                      child: Text(DateFormat('h:m a yyyy/M/d', 'ar-EG')
                          .format(widget.invitation.expiryDate.toDate())),
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: _selectPerson,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: InputDecorator(
                      isEmpty:
                          widget.invitation.permissions?['personId'] == null,
                      decoration: const InputDecoration(
                        labelText: 'ربط بخادم',
                      ),
                      child: FutureBuilder<String?>(
                        future: personName.fetch(
                          () async {
                            if (widget.invitation.permissions?['personId'] ==
                                null) {
                              return null;
                            } else {
                              return (await FirebaseFirestore.instance
                                      .collection('UsersData')
                                      .doc(widget
                                          .invitation.permissions!['personId'])
                                      .get(dataSource))
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
                if (User.instance.manageUsers)
                  ListTile(
                    trailing: Checkbox(
                      value: widget.invitation.permissions!['manageUsers'] ??
                          false,
                      onChanged: (v) => setState(() =>
                          widget.invitation.permissions!['manageUsers'] = v),
                    ),
                    leading: const Icon(
                        IconData(0xef3d, fontFamily: 'MaterialIconsR')),
                    title: const Text('إدارة المستخدمين'),
                    onTap: () => setState(() =>
                        widget.invitation.permissions!['manageUsers'] =
                            !(widget.invitation.permissions!['manageUsers'] ??
                                false)),
                  ),
                ListTile(
                  trailing: Checkbox(
                    value:
                        widget.invitation.permissions!['manageAllowedUsers'] ??
                            false,
                    onChanged: (v) => setState(() => widget
                        .invitation.permissions!['manageAllowedUsers'] = v),
                  ),
                  leading: const Icon(
                      IconData(0xef3d, fontFamily: 'MaterialIconsR')),
                  title: const Text('إدارة مستخدمين محددين'),
                  onTap: () => setState(() => widget
                          .invitation.permissions!['manageAllowedUsers'] =
                      !(widget.invitation.permissions!['manageAllowedUsers'] ??
                          false)),
                ),
                ListTile(
                  trailing: Checkbox(
                    value:
                        widget.invitation.permissions!['superAccess'] ?? false,
                    onChanged: (v) => setState(() =>
                        widget.invitation.permissions!['superAccess'] = v),
                  ),
                  leading: const Icon(
                      IconData(0xef56, fontFamily: 'MaterialIconsR')),
                  title: const Text('رؤية جميع البيانات'),
                  onTap: () => setState(() =>
                      widget.invitation.permissions!['superAccess'] =
                          !(widget.invitation.permissions!['superAccess'] ??
                              false)),
                ),
                ListTile(
                  trailing: Checkbox(
                    value: widget.invitation.permissions!['manageDeleted'] ??
                        false,
                    onChanged: (v) => setState(() =>
                        widget.invitation.permissions!['manageDeleted'] = v),
                  ),
                  leading: const Icon(Icons.delete_outline),
                  title: const Text('استرجاع المحذوفات'),
                  onTap: () => setState(() =>
                      widget.invitation.permissions!['manageDeleted'] =
                          !(widget.invitation.permissions!['manageDeleted'] ??
                              false)),
                ),
                ListTile(
                  trailing: Checkbox(
                    value: widget.invitation.permissions!['changeHistory'] ??
                        false,
                    onChanged: (v) => setState(() =>
                        widget.invitation.permissions!['changeHistory'] = v),
                  ),
                  leading: const Icon(Icons.history),
                  title: const Text('تعديل الكشوفات القديمة'),
                  onTap: () => setState(() =>
                      widget.invitation.permissions!['changeHistory'] =
                          !(widget.invitation.permissions!['changeHistory'] ??
                              false)),
                ),
                ListTile(
                  trailing: Checkbox(
                    value: widget.invitation.permissions!['secretary'] ?? false,
                    onChanged: (v) => setState(
                        () => widget.invitation.permissions!['secretary'] = v),
                  ),
                  leading: const Icon(Icons.shield),
                  title: const Text('تسجيل حضور الخدام'),
                  onTap: () => setState(() => widget
                          .invitation.permissions!['secretary'] =
                      !(widget.invitation.permissions!['secretary'] ?? false)),
                ),
                ListTile(
                  trailing: Checkbox(
                    value: widget.invitation.permissions!['write'] ?? false,
                    onChanged: (v) => setState(
                        () => widget.invitation.permissions!['write'] = v),
                  ),
                  leading: const Icon(Icons.edit),
                  title: const Text('تعديل البيانات'),
                  onTap: () => setState(() =>
                      widget.invitation.permissions!['write'] =
                          !(widget.invitation.permissions!['write'] ?? false)),
                ),
                ListTile(
                  trailing: Checkbox(
                    value: widget.invitation.permissions!['export'] ?? false,
                    onChanged: (v) => setState(
                        () => widget.invitation.permissions!['export'] = v),
                  ),
                  leading: const Icon(Icons.cloud_download),
                  title: const Text('تصدير فصل لملف إكسل'),
                  onTap: () => setState(() =>
                      widget.invitation.permissions!['export'] =
                          !(widget.invitation.permissions!['export'] ?? false)),
                ),
                ListTile(
                  trailing: Checkbox(
                    value: widget.invitation.permissions!['birthdayNotify'] ??
                        false,
                    onChanged: (v) => setState(() =>
                        widget.invitation.permissions!['birthdayNotify'] = v),
                  ),
                  leading: const Icon(
                      IconData(0xe7e9, fontFamily: 'MaterialIconsR')),
                  title: const Text('إشعار أعياد الميلاد'),
                  onTap: () => setState(() =>
                      widget.invitation.permissions!['birthdayNotify'] =
                          !(widget.invitation.permissions!['birthdayNotify'] ??
                              false)),
                ),
                ListTile(
                  trailing: Checkbox(
                    value:
                        widget.invitation.permissions!['confessionsNotify'] ??
                            false,
                    onChanged: (v) => setState(() => widget
                        .invitation.permissions!['confessionsNotify'] = v),
                  ),
                  leading: const Icon(
                      IconData(0xe7f7, fontFamily: 'MaterialIconsR')),
                  title: const Text('إشعار  الاعتراف'),
                  onTap: () => setState(() => widget
                          .invitation.permissions!['confessionsNotify'] =
                      !(widget.invitation.permissions!['confessionsNotify'] ??
                          false)),
                ),
                ListTile(
                  trailing: Checkbox(
                    value: widget.invitation.permissions!['tanawolNotify'] ??
                        false,
                    onChanged: (v) => setState(() =>
                        widget.invitation.permissions!['tanawolNotify'] = v),
                  ),
                  leading: const Icon(
                      IconData(0xe7f7, fontFamily: 'MaterialIconsR')),
                  title: const Text('إشعار التناول'),
                  onTap: () => setState(() =>
                      widget.invitation.permissions!['tanawolNotify'] =
                          !(widget.invitation.permissions!['tanawolNotify'] ??
                              false)),
                ),
                ListTile(
                  trailing: Checkbox(
                    value:
                        widget.invitation.permissions!['kodasNotify'] ?? false,
                    onChanged: (v) => setState(() =>
                        widget.invitation.permissions!['kodasNotify'] = v),
                  ),
                  leading: const Icon(
                      IconData(0xe7f7, fontFamily: 'MaterialIconsR')),
                  title: const Text('إشعار القداس'),
                  onTap: () => setState(() =>
                      widget.invitation.permissions!['kodasNotify'] =
                          !(widget.invitation.permissions!['kodasNotify'] ??
                              false)),
                ),
                ListTile(
                  trailing: Checkbox(
                    value: widget.invitation.permissions!['meetingNotify'] ??
                        false,
                    onChanged: (v) => setState(() =>
                        widget.invitation.permissions!['meetingNotify'] = v),
                  ),
                  leading: const Icon(
                      IconData(0xe7f7, fontFamily: 'MaterialIconsR')),
                  title: const Text('إشعار حضور الاجتماع'),
                  onTap: () => setState(() =>
                      widget.invitation.permissions!['meetingNotify'] =
                          !(widget.invitation.permissions!['meetingNotify'] ??
                              false)),
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

  void deleteInvitation() async {
    if (await showDialog(
          context: context,
          builder: (innerContext) => AlertDialog(
            content: const Text('هل تريد حذف هذه الدعوة؟'),
            actions: <Widget>[
              TextButton(
                style: Theme.of(innerContext).textButtonTheme.style!.copyWith(
                    foregroundColor: MaterialStateProperty.resolveWith(
                        (state) => Colors.red)),
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
        await widget.invitation.ref.delete();
      } else {
        // ignore: unawaited_futures
        widget.invitation.ref.delete();
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
    old = widget.invitation.getMap();
  }

  void nameChanged(String value) {
    widget.invitation.name = value;
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
      if (form.currentState!.validate() &&
          widget.invitation.expiryDate.toDate().difference(DateTime.now()) >=
              const Duration(hours: 24)) {
        scaffoldMessenger.currentState!.showSnackBar(const SnackBar(
          content: Text('جار الحفظ...'),
          duration: Duration(seconds: 15),
        ));
        if (widget.invitation.id == 'null') {
          widget.invitation.ref =
              FirebaseFirestore.instance.collection('Invitations').doc();
          widget.invitation.generatedBy = User.instance.uid!;
          if (await Connectivity().checkConnectivity() !=
              ConnectivityResult.none) {
            await widget.invitation.ref.set({
              ...widget.invitation.getMap(),
              'GeneratedOn': FieldValue.serverTimestamp()
            });
          } else {
            // ignore: unawaited_futures
            widget.invitation.ref.set({
              ...widget.invitation.getMap(),
              'GeneratedOn': FieldValue.serverTimestamp()
            });
          }
        } else {
          final update = widget.invitation.getMap()
            ..removeWhere((key, value) => old[key] == value);
          if (update.isNotEmpty) {
            if (await Connectivity().checkConnectivity() !=
                ConnectivityResult.none) {
              await widget.invitation.update(old: update);
            } else {
              // ignore: unawaited_futures
              widget.invitation.update(old: update);
            }
          }
        }
        scaffoldMessenger.currentState!.hideCurrentSnackBar();
        navigator.currentState!.pop(widget.invitation.ref);
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
                'يرجى ملء تاريخ انتهاء الدعوة على أن يكون على الأقل بعد 24 ساعة'),
          ),
        );
      }
    } catch (err, stack) {
      await Sentry.captureException(err,
          stackTrace: stack,
          withScope: (scope) =>
              scope.setTag('LasErrorIn', '_EditInvitationState.save'));
      scaffoldMessenger.currentState!.hideCurrentSnackBar();
      scaffoldMessenger.currentState!.showSnackBar(SnackBar(
        content: Text(err.toString()),
        duration: const Duration(seconds: 7),
      ));
    }
  }

  Future<Timestamp> _selectDateTime(
      String helpText, DateTime initialDate) async {
    var picked = await showDatePicker(
        helpText: helpText,
        locale: const Locale('ar', 'EG'),
        context: context,
        initialDate: initialDate,
        firstDate: DateTime.now(),
        lastDate: DateTime.now().add(const Duration(days: 14)));
    if (picked != null && picked != initialDate) {
      final time = await showTimePicker(
          context: context, initialTime: TimeOfDay.fromDateTime(initialDate));
      if (time != null)
        picked = picked.add(Duration(hours: time.hour, minutes: time.minute));
      setState(() {});
      FocusScope.of(context).nextFocus();
      return Timestamp.fromDate(picked);
    }
    return Timestamp.fromDate(initialDate);
  }

  void _selectPerson() async {
    final controller = DataObjectListController<User>(
      tap: (person) {
        navigator.currentState!.pop();
        widget.invitation.permissions ??= {};
        widget.invitation.permissions!['personId'] = person.ref.id;
        personName.invalidate();
        setState(() {});
        FocusScope.of(context).nextFocus();
      },
      itemsStream: User.getAllForUserForEdit()
          .map((users) => users.where((u) => u.uid == null).toList()),
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
                  child: DataObjectList<User>(
                    options: controller,
                    disposeController: false,
                  ),
                ),
              ],
            ),
            bottomNavigationBar: BottomAppBar(
              color: Theme.of(context).colorScheme.primary,
              shape: const CircularNotchedRectangle(),
              child: StreamBuilder<List?>(
                stream: controller.objectsData,
                builder: (context, snapshot) {
                  return Text((snapshot.data?.length ?? 0).toString() + ' خادم',
                      textAlign: TextAlign.center,
                      strutStyle:
                          StrutStyle(height: IconTheme.of(context).size! / 7.5),
                      style: Theme.of(context).primaryTextTheme.bodyText1);
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
