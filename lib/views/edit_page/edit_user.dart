import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:meetinghelper/models/list_options.dart';
import 'package:meetinghelper/models/search_filters.dart';
import 'package:meetinghelper/views/users_list.dart';
import 'package:provider/provider.dart';
import 'package:rxdart/rxdart.dart';

import '../../models/mini_models.dart';
import '../../models/user.dart';

class EditUser extends StatefulWidget {
  final User user;
  EditUser({Key key, @required this.user}) : super(key: key);
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
  Map<String, dynamic> old;

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
                  icon: Icon(Icons.close),
                  tooltip: 'إلغاء تنشيط الحساب',
                  onPressed: unApproveUser,
                ),
                IconButton(
                  icon: Icon(Icons.delete_forever),
                  tooltip: 'حذف الحساب',
                  onPressed: deleteUser,
                ),
              ],
              flexibleSpace: LayoutBuilder(
                builder: (context, constraints) => FlexibleSpaceBar(
                  title: AnimatedOpacity(
                    duration: Duration(milliseconds: 300),
                    opacity: constraints.biggest.height > kToolbarHeight * 1.7
                        ? 0
                        : 1,
                    child: Text(widget.user.name,
                        style: TextStyle(
                          fontSize: 16.0,
                        )),
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
            padding: EdgeInsets.all(5),
            child: ListView(
              children: <Widget>[
                Container(
                  padding: EdgeInsets.symmetric(vertical: 4.0),
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
                      if (value.isEmpty) {
                        return 'هذا الحقل مطلوب';
                      }
                      return null;
                    },
                  ),
                ),
                FutureBuilder<QuerySnapshot>(
                  future: StudyYear.getAllForUser(),
                  builder: (conext, data) {
                    if (data.hasData) {
                      return Container(
                        padding: EdgeInsets.symmetric(vertical: 4.0),
                        child: DropdownButtonFormField(
                          validator: (v) {
                            return null;
                          },
                          value: widget.user.servingStudyYearRef?.path,
                          items: data.data.docs
                              .map(
                                (item) => DropdownMenuItem(
                                  value: item.reference.path,
                                  child: Text(item.data()['Name']),
                                ),
                              )
                              .toList()
                                ..insert(
                                  0,
                                  DropdownMenuItem(
                                    value: null,
                                    child: Text(''),
                                  ),
                                ),
                          onChanged: (value) {
                            setState(() {});
                            widget.user.servingStudyYear = value != null
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
                      return Container(width: 1, height: 1);
                    }
                  },
                ),
                Container(
                  padding: EdgeInsets.symmetric(vertical: 4.0),
                  child: DropdownButtonFormField(
                    validator: (v) {
                      return null;
                    },
                    value: widget.user.servingStudyGender,
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
                              DropdownMenuItem(
                                value: null,
                                child: Text(''),
                              )),
                    onChanged: (value) {
                      setState(() {});
                      widget.user.servingStudyGender = value;
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
                Container(
                  padding: EdgeInsets.symmetric(vertical: 4.0),
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
                                widget.user.lastTanawolDate,
                              ))
                            : Text('لا يمكن التحديد'),
                      ),
                    ),
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(vertical: 4.0),
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
                                widget.user.lastConfessionDate,
                              ))
                            : Text('لا يمكن التحديد'),
                      ),
                    ),
                  ),
                ),
                if (User.instance.manageUsers)
                  ListTile(
                    trailing: Checkbox(
                      value: widget.user.manageUsers,
                      onChanged: (v) =>
                          setState(() => widget.user.manageUsers = v),
                    ),
                    leading: Icon(
                        const IconData(0xef3d, fontFamily: 'MaterialIconsR')),
                    title: Text('إدارة المستخدمين'),
                    onTap: () => setState(() =>
                        widget.user.manageUsers = !widget.user.manageUsers),
                  ),
                ListTile(
                  trailing: Checkbox(
                    value: widget.user.manageAllowedUsers,
                    onChanged: (v) =>
                        setState(() => widget.user.manageAllowedUsers = v),
                  ),
                  leading: Icon(
                      const IconData(0xef3d, fontFamily: 'MaterialIconsR')),
                  title: Text('إدارة مستخدمين محددين'),
                  onTap: () => setState(() => widget.user.manageAllowedUsers =
                      !widget.user.manageAllowedUsers),
                ),
                ListTile(
                  trailing: Checkbox(
                    value: widget.user.superAccess,
                    onChanged: (v) =>
                        setState(() => widget.user.superAccess = v),
                  ),
                  leading: Icon(
                      const IconData(0xef56, fontFamily: 'MaterialIconsR')),
                  title: Text('رؤية جميع البيانات'),
                  onTap: () => setState(
                      () => widget.user.superAccess = !widget.user.superAccess),
                ),
                ListTile(
                  trailing: Checkbox(
                    value: widget.user.secretary,
                    onChanged: (v) => setState(() => widget.user.secretary = v),
                  ),
                  leading: Icon(Icons.shield),
                  title: Text('تسجيل حضور الخدام'),
                  onTap: () => setState(
                      () => widget.user.secretary = !widget.user.secretary),
                ),
                ListTile(
                  trailing: Checkbox(
                    value: widget.user.write,
                    onChanged: (v) => setState(() => widget.user.write = v),
                  ),
                  leading: Icon(Icons.edit),
                  title: Text('تعديل البيانات'),
                  onTap: () =>
                      setState(() => widget.user.write = !widget.user.write),
                ),
                ListTile(
                  trailing: Checkbox(
                    value: widget.user.exportClasses,
                    onChanged: (v) =>
                        setState(() => widget.user.exportClasses = v),
                  ),
                  leading: Icon(Icons.cloud_download),
                  title: Text('تصدير فصل لملف إكسل'),
                  onTap: () => setState(() =>
                      widget.user.exportClasses = !widget.user.exportClasses),
                ),
                ListTile(
                  trailing: Checkbox(
                    value: widget.user.birthdayNotify,
                    onChanged: (v) =>
                        setState(() => widget.user.birthdayNotify = v),
                  ),
                  leading: Icon(
                      const IconData(0xe7e9, fontFamily: 'MaterialIconsR')),
                  title: Text('إشعار أعياد الميلاد'),
                  onTap: () => setState(() =>
                      widget.user.birthdayNotify = !widget.user.birthdayNotify),
                ),
                ListTile(
                  trailing: Checkbox(
                    value: widget.user.confessionsNotify ?? false,
                    onChanged: (v) =>
                        setState(() => widget.user.confessionsNotify = v),
                  ),
                  leading: Icon(
                      const IconData(0xe7f7, fontFamily: 'MaterialIconsR')),
                  title: Text('إشعار  الاعتراف'),
                  onTap: () => setState(() => widget.user.confessionsNotify =
                      !(widget.user.confessionsNotify ?? false)),
                ),
                ListTile(
                  trailing: Checkbox(
                    value: widget.user.tanawolNotify ?? false,
                    onChanged: (v) =>
                        setState(() => widget.user.tanawolNotify = v),
                  ),
                  leading: Icon(
                      const IconData(0xe7f7, fontFamily: 'MaterialIconsR')),
                  title: Text('إشعار التناول'),
                  onTap: () => setState(() => widget.user.tanawolNotify =
                      !(widget.user.tanawolNotify ?? false)),
                ),
                ListTile(
                  trailing: Checkbox(
                    value: widget.user.kodasNotify ?? false,
                    onChanged: (v) =>
                        setState(() => widget.user.kodasNotify = v),
                  ),
                  leading: Icon(
                      const IconData(0xe7f7, fontFamily: 'MaterialIconsR')),
                  title: Text('إشعار القداس'),
                  onTap: () => setState(() => widget.user.kodasNotify =
                      !(widget.user.kodasNotify ?? false)),
                ),
                ListTile(
                  trailing: Checkbox(
                    value: widget.user.meetingNotify ?? false,
                    onChanged: (v) =>
                        setState(() => widget.user.meetingNotify = v),
                  ),
                  leading: Icon(
                      const IconData(0xe7f7, fontFamily: 'MaterialIconsR')),
                  title: Text('إشعار حضور الاجتماع'),
                  onTap: () => setState(() => widget.user.meetingNotify =
                      !(widget.user.meetingNotify ?? false)),
                ),
                ElevatedButton.icon(
                  onPressed: editAllowedUsers,
                  icon: Icon(Icons.shield),
                  label: Text('تعديل المستخدمين المسموح لهم بتعديل المستخدم',
                      softWrap: false,
                      textScaleFactor: 0.95,
                      overflow: TextOverflow.fade),
                ),
                ElevatedButton.icon(
                  onPressed: resetPassword,
                  icon: Icon(Icons.lock_open),
                  label: Text('إعادة تعيين كلمة السر'),
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
        child: Icon(Icons.save),
      ),
    );
  }

  void editAllowedUsers() async {
    BehaviorSubject<String> searchStream = BehaviorSubject<String>.seeded('');
    widget.user.allowedUsers = await showDialog(
          context: context,
          builder: (context) {
            return FutureBuilder<List<User>>(
              future: User.getUsers(widget.user.allowedUsers),
              builder: (c, users) => users.hasData
                  ? MultiProvider(
                      providers: [
                        Provider(
                          create: (_) => DataObjectListOptions<User>(
                            searchQuery: searchStream,
                            itemsStream:
                                Stream.fromFuture(User.getAllSemiManagers()),
                            selected: {
                              for (var item in users.data) item.uid: item
                            },
                          ),
                        )
                      ],
                      builder: (context, child) => AlertDialog(
                        actions: [
                          TextButton(
                            onPressed: () {
                              Navigator.pop(
                                  context,
                                  context
                                      .read<DataObjectListOptions<User>>()
                                      .selectedLatest
                                      .values
                                      ?.map((f) => f.uid)
                                      ?.toList());
                            },
                            child: Text('تم'),
                          )
                        ],
                        content: Container(
                          width: 280,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SearchField(
                                  searchStream: searchStream,
                                  textStyle:
                                      Theme.of(context).textTheme.bodyText2),
                              Expanded(
                                child: UsersList(),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  : Center(child: CircularProgressIndicator()),
            );
          },
        ) ??
        widget.user.allowedUsers;
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
            style: Theme.of(context).textButtonTheme.style.copyWith(
                foregroundColor:
                    MaterialStateProperty.resolveWith((state) => Colors.red)),
            onPressed: () async {
              try {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: LinearProgressIndicator(),
                    duration: Duration(seconds: 15),
                  ),
                );
                Navigator.of(context).pop();
                await FirebaseFunctions.instance
                    .httpsCallable('deleteUser')
                    .call({'affectedUser': widget.user.uid});
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                Navigator.of(context).pop('deleted');
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('تم بنجاح'),
                    duration: Duration(seconds: 15),
                  ),
                );
              } catch (err, stkTrace) {
                await FirebaseCrashlytics.instance
                    .setCustomKey('LastErrorIn', 'UserPState.delete');
                await FirebaseCrashlytics.instance.recordError(err, stkTrace);
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      err.toString(),
                    ),
                    duration: Duration(seconds: 7),
                  ),
                );
              }
            },
            child: Text('حذف'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: Text('تراجع'),
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
        content: Text('إلغاء تنشيط الحساب لن يقوم بالضرورة بحذف الحساب '),
        actions: <Widget>[
          TextButton(
            onPressed: () async {
              try {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: LinearProgressIndicator(),
                  duration: Duration(seconds: 15),
                ));
                Navigator.of(navContext).pop();
                await FirebaseFunctions.instance
                    .httpsCallable('unApproveUser')
                    .call({'affectedUser': widget.user.uid});
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('تم بنجاح'),
                  duration: Duration(seconds: 15),
                ));
              } catch (err, stkTrace) {
                await FirebaseCrashlytics.instance
                    .setCustomKey('LastErrorIn', 'UserPState.delete');
                await FirebaseCrashlytics.instance.recordError(err, stkTrace);
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(err.toString()),
                  duration: Duration(seconds: 7),
                ));
              }
            },
            child: Text('متابعة'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(navContext).pop();
            },
            child: Text('تراجع'),
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
                onPressed: () => Navigator.pop(context, true),
                child: Text('نعم'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('لا'),
              ),
            ],
          ),
        ) !=
        true) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: LinearProgressIndicator(),
        duration: Duration(seconds: 15),
      ),
    );
    try {
      await FirebaseFunctions.instance
          .httpsCallable('resetPassword')
          .call({'affectedUser': widget.user.uid});
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم إعادة تعيين كلمة السر بنجاح'),
        ),
      );
    } catch (err, stkTrace) {
      await FirebaseCrashlytics.instance
          .setCustomKey('LastErrorIn', 'UserPState.resetPassword');
      await FirebaseCrashlytics.instance.recordError(err, stkTrace);
      ScaffoldMessenger.of(context).showSnackBar(
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
              AlertDialog(content: Text('لا يوجد اتصال انترنت')));
      return;
    }
    try {
      if (form.currentState.validate()) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('جار الحفظ...'),
          duration: Duration(seconds: 15),
        ));
        var update = widget.user.getUpdateMap()
          ..removeWhere((key, value) => old[key] == value);
        if (old['name'] != widget.user.name) {
          await FirebaseFunctions.instance.httpsCallable('changeUserName').call(
              {'affectedUser': widget.user.uid, 'newName': widget.user.name});
        }
        update.remove('name');
        update.remove('allowedUsers');
        if (update.isNotEmpty) {
          await FirebaseFunctions.instance
              .httpsCallable('updatePermissions')
              .call({'affectedUser': widget.user.uid, 'permissions': update});
        }
        if (old['allowedUsers'] != widget.user.allowedUsers) {
          await FirebaseFirestore.instance
              .collection('Users')
              .doc(widget.user.uid)
              .update({'allowedUsers': widget.user.allowedUsers});
        }
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        Navigator.of(context).pop(widget.user);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم الحفظ بنجاح'),
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (err, stkTrace) {
      await FirebaseCrashlytics.instance
          .setCustomKey('LastErrorIn', 'UserPState.save');
      await FirebaseCrashlytics.instance.recordError(err, stkTrace);
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(err.toString()),
        duration: Duration(seconds: 7),
      ));
    }
  }

  Future<int> _selectDate(String helpText, DateTime initialDate) async {
    DateTime picked = await showDatePicker(
      helpText: helpText,
      locale: Locale('ar', 'EG'),
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1500),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != initialDate) {
      setState(() {});
      return picked.millisecondsSinceEpoch;
    }
    return initialDate.millisecondsSinceEpoch;
  }
}
