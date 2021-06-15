import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:meetinghelper/models/invitation.dart';
import 'package:meetinghelper/utils/globals.dart';
import 'package:meetinghelper/utils/typedefs.dart';

import '../../models/mini_models.dart';
import '../../models/user.dart';

class EditInvitation extends StatefulWidget {
  final Invitation invitation;

  const EditInvitation({Key? key, required this.invitation}) : super(key: key);
  @override
  _EditInvitationState createState() => _EditInvitationState();
}

class _EditInvitationState extends State<EditInvitation> {
  List<FocusNode> foci = [
    FocusNode(),
    FocusNode(),
    FocusNode(),
    FocusNode(),
    FocusNode(),
    FocusNode(),
    FocusNode()
  ];
  late Json old;

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
                    decoration: InputDecoration(
                        labelText: 'عنوان الدعوة',
                        border: OutlineInputBorder(
                          borderSide:
                              BorderSide(color: Theme.of(context).primaryColor),
                        )),
                    focusNode: foci[0],
                    textInputAction: TextInputAction.next,
                    onFieldSubmitted: (_) => foci[1].requestFocus(),
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
                  child: Focus(
                    focusNode: foci[6],
                    child: GestureDetector(
                      onTap: () async => widget.invitation.expiryDate =
                          await _selectDateTime('تاريخ الانتهاء',
                              widget.invitation.expiryDate.toDate()),
                      child: InputDecorator(
                        decoration: InputDecoration(
                            labelText: 'تاريخ انتهاء الدعوة',
                            border: OutlineInputBorder(
                              borderSide: BorderSide(
                                  color: Theme.of(context).primaryColor),
                            )),
                        child: Text(DateFormat('h:m a yyyy/M/d', 'ar-EG')
                            .format(widget.invitation.expiryDate.toDate())),
                      ),
                    ),
                  ),
                ),
                FutureBuilder<JsonQuery>(
                  future: StudyYear.getAllForUser(),
                  builder: (conext, data) {
                    if (data.hasData) {
                      return Container(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: DropdownButtonFormField(
                          validator: (dynamic v) {
                            return null;
                          },
                          value: widget.invitation
                                      .permissions!['servingStudyYear'] !=
                                  null
                              ? 'StudyYears/' +
                                  widget.invitation
                                      .permissions!['servingStudyYear']
                              : null,
                          items: data.data!.docs
                              .map(
                                (item) => DropdownMenuItem(
                                  value: item.reference.path,
                                  child: Text(item.data()['Name']),
                                ),
                              )
                              .toList()
                                ..insert(
                                  0,
                                  const DropdownMenuItem(
                                    value: null,
                                    child: Text(''),
                                  ),
                                ),
                          onChanged: (dynamic value) {
                            setState(() {});
                            widget.invitation.permissions!['servingStudyYear'] =
                                value != null
                                    ? value.split('/')[1].toString()
                                    : null;
                            foci[2].requestFocus();
                          },
                          decoration: InputDecoration(
                              labelText: 'صف الخدمة',
                              border: OutlineInputBorder(
                                borderSide: BorderSide(
                                    color: Theme.of(context).primaryColor),
                              )),
                        ),
                      );
                    } else {
                      return Container();
                    }
                  },
                ),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: DropdownButtonFormField(
                    validator: (dynamic v) {
                      return null;
                    },
                    value: widget.invitation.permissions!['servingStudyGender'],
                    items: [true, false]
                        .map(
                          (item) => DropdownMenuItem(
                            value: item,
                            child: Text(item ? 'بنين' : 'بنات'),
                          ),
                        )
                        .toList()
                          ..insert(
                              0,
                              const DropdownMenuItem(
                                value: null,
                                child: Text(''),
                              )),
                    onChanged: (dynamic value) {
                      setState(() {});
                      widget.invitation.permissions!['servingStudyGender'] =
                          value;
                      foci[2].requestFocus();
                    },
                    decoration: InputDecoration(
                        labelText: 'نوع الخدمة',
                        border: OutlineInputBorder(
                          borderSide:
                              BorderSide(color: Theme.of(context).primaryColor),
                        )),
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
                    value: widget.invitation.permissions!['exportClasses'] ??
                        false,
                    onChanged: (v) => setState(() =>
                        widget.invitation.permissions!['exportClasses'] = v),
                  ),
                  leading: const Icon(Icons.cloud_download),
                  title: const Text('تصدير فصل لملف إكسل'),
                  onTap: () => setState(() =>
                      widget.invitation.permissions!['exportClasses'] =
                          !(widget.invitation.permissions!['exportClasses'] ??
                              false)),
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
        heroTag: 'Save',
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
          var update = widget.invitation.getMap()
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
      var time = await showTimePicker(
          context: context, initialTime: TimeOfDay.fromDateTime(initialDate));
      if (time != null)
        picked = picked.add(Duration(hours: time.hour, minutes: time.minute));
      setState(() {});
      return Timestamp.fromDate(picked);
    }
    return Timestamp.fromDate(initialDate);
  }
}
