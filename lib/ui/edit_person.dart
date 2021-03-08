import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_storage/firebase_storage.dart' show FirebaseStorage;
import 'package:flutter/material.dart';
import 'package:icon_shadow/icon_shadow.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:meetinghelper/models/user.dart';
import 'package:meetinghelper/ui/list.dart';
import 'package:meetinghelper/models/list_options.dart';
import 'package:meetinghelper/models/order_options.dart';
import 'package:meetinghelper/models/search_filters.dart';
import 'package:meetinghelper/models/search_string.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:tinycolor/tinycolor.dart';

import '../ui/mini_lists/ColorsList.dart';
import '../models/mini_models.dart';
import '../models/models.dart';
import 'services_list.dart';

class EditPerson extends StatefulWidget {
  final Person person;
  EditPerson({Key key, @required this.person}) : super(key: key);
  @override
  _EditPersonState createState() => _EditPersonState();
}

class _EditPersonState extends State<EditPerson> {
  List<FocusNode> foci = [
    FocusNode(),
    FocusNode(),
    FocusNode(),
    FocusNode(),
    FocusNode(),
    FocusNode(),
    FocusNode(),
    FocusNode(),
    FocusNode(),
    FocusNode(),
    FocusNode(),
    FocusNode(),
    FocusNode(),
    FocusNode(),
    FocusNode(),
    FocusNode(),
    FocusNode(),
    FocusNode(),
    FocusNode(),
    FocusNode(),
    FocusNode(),
  ];

  Map<String, dynamic> old;
  String changedImage;
  bool deletePhoto = false;
  GlobalKey<FormState> form = GlobalKey<FormState>();

  Person person;
  @override
  Widget build(BuildContext context) {
    if (ModalRoute.of(context).settings.arguments != null &&
        person.classId == null) {
      person.classId = ModalRoute.of(context).settings.arguments;
    }
    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
          return <Widget>[
            SliverAppBar(
              actions: <Widget>[
                IconButton(
                    icon: Builder(
                      builder: (context) => IconShadowWidget(
                        Icon(
                          Icons.photo_camera,
                          color: Theme.of(context).iconTheme.color,
                        ),
                      ),
                    ),
                    onPressed: () async {
                      var source = await showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          actions: <Widget>[
                            TextButton.icon(
                              onPressed: () => Navigator.of(context).pop(true),
                              icon: Icon(Icons.camera),
                              label: Text('التقاط صورة من الكاميرا'),
                            ),
                            TextButton.icon(
                              onPressed: () => Navigator.of(context).pop(false),
                              icon: Icon(Icons.photo_library),
                              label: Text('اختيار من المعرض'),
                            ),
                            TextButton.icon(
                              onPressed: () =>
                                  Navigator.of(context).pop('delete'),
                              icon: Icon(Icons.delete),
                              label: Text('حذف الصورة'),
                            ),
                          ],
                        ),
                      );
                      if (source == null) return;
                      if (source == 'delete') {
                        changedImage = null;
                        deletePhoto = true;
                        person.hasPhoto = false;
                        setState(() {});
                        return;
                      }
                      if ((source &&
                              !(await Permission.storage.request())
                                  .isGranted) ||
                          !(await Permission.camera.request()).isGranted) {
                        return;
                      }
                      var selectedImage = (await ImagePicker().getImage(
                          source: source
                              ? ImageSource.camera
                              : ImageSource.gallery));
                      if (selectedImage == null) return;
                      changedImage = (await ImageCropper.cropImage(
                              sourcePath: selectedImage.path,
                              cropStyle: CropStyle.circle,
                              androidUiSettings: AndroidUiSettings(
                                  toolbarTitle: 'قص الصورة',
                                  toolbarColor: Theme.of(context).primaryColor,
                                  initAspectRatio: CropAspectRatioPreset.square,
                                  lockAspectRatio: false)))
                          ?.path;
                      deletePhoto = false;
                      setState(() {});
                    })
              ],
              backgroundColor: person.color != Colors.transparent
                  ? (Theme.of(context).brightness == Brightness.light
                      ? TinyColor(person.color).lighten().color
                      : TinyColor(person.color).darken().color)
                  : null,
              //title: Text(widget.me.name),
              expandedHeight: 250.0,
              floating: false,
              pinned: true,
              flexibleSpace: LayoutBuilder(
                builder: (context, constraints) => FlexibleSpaceBar(
                  title: AnimatedOpacity(
                    duration: Duration(milliseconds: 300),
                    opacity: constraints.biggest.height > kToolbarHeight * 1.7
                        ? 0
                        : 1,
                    child: Text(person.name,
                        style: TextStyle(
                          fontSize: 16.0,
                        )),
                  ),
                  background: changedImage == null
                      ? person.photo()
                      : Image.file(File(changedImage)),
                ),
              ),
            ),
          ];
        },
        body: Form(
          key: form,
          child: Padding(
            padding: EdgeInsets.all(5),
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Container(
                    padding: EdgeInsets.symmetric(vertical: 4.0),
                    child: TextFormField(
                      decoration: InputDecoration(
                          labelText: 'الاسم',
                          border: OutlineInputBorder(
                            borderSide: BorderSide(
                                color: Theme.of(context).primaryColor),
                          )),
                      focusNode: foci[0],
                      textInputAction: TextInputAction.next,
                      initialValue: person.name,
                      onChanged: _nameChanged,
                      onFieldSubmitted: (_) => foci[1].requestFocus(),
                      validator: (value) {
                        if (value.isEmpty) {
                          return 'هذا الحقل مطلوب';
                        }
                        return null;
                      },
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(vertical: 4.0),
                    child: TextFormField(
                      decoration: InputDecoration(
                          labelText: 'موبايل (شخصي)',
                          border: OutlineInputBorder(
                            borderSide: BorderSide(
                                color: Theme.of(context).primaryColor),
                          )),
                      focusNode: foci[1],
                      textInputAction: TextInputAction.next,
                      initialValue: person.phone,
                      onChanged: _phoneChanged,
                      onFieldSubmitted: (_) {
                        foci[2].requestFocus();
                      },
                      validator: (value) {
                        return null;
                      },
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(vertical: 4.0),
                    child: TextFormField(
                      decoration: InputDecoration(
                          labelText: 'موبايل الأب',
                          border: OutlineInputBorder(
                            borderSide: BorderSide(
                                color: Theme.of(context).primaryColor),
                          )),
                      focusNode: foci[2],
                      textInputAction: TextInputAction.next,
                      initialValue: person.fatherPhone,
                      onChanged: _fatherPhoneChanged,
                      onFieldSubmitted: (_) {
                        foci[3].requestFocus();
                      },
                      validator: (value) {
                        return null;
                      },
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(vertical: 4.0),
                    child: TextFormField(
                      decoration: InputDecoration(
                          labelText: 'موبايل الأم',
                          border: OutlineInputBorder(
                            borderSide: BorderSide(
                                color: Theme.of(context).primaryColor),
                          )),
                      focusNode: foci[3],
                      textInputAction: TextInputAction.next,
                      initialValue: person.motherPhone,
                      onChanged: _motherPhoneChanged,
                      onFieldSubmitted: (_) {
                        foci[4].requestFocus();
                      },
                      validator: (value) {
                        return null;
                      },
                    ),
                  ),
                  if (person.phones.isNotEmpty)
                    ...person.phones.entries.map(
                      (e) => Container(
                        padding: EdgeInsets.symmetric(vertical: 10),
                        child: TextFormField(
                          decoration: InputDecoration(
                            labelText: e.key,
                            suffixIcon: IconButton(
                              icon: Icon(Icons.edit),
                              tooltip: 'تعديل اسم الهاتف',
                              onPressed: () async {
                                TextEditingController name =
                                    TextEditingController(text: e.key);
                                var rslt = await showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context, name.text),
                                          child: Text('حفظ'),
                                        ),
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context, 'delete'),
                                          child: Text('حذف'),
                                        ),
                                      ],
                                      title: Text('اسم الهاتف'),
                                      content: TextField(controller: name)),
                                );
                                if (rslt == 'delete') {
                                  person.phones.remove(e.key);
                                  setState(() {});
                                } else if (rslt != null) {
                                  person.phones.remove(e.key);
                                  person.phones[name.text] = e.value;
                                  setState(() {});
                                }
                              },
                            ),
                            border: OutlineInputBorder(
                              borderSide: BorderSide(
                                  color: Theme.of(context).primaryColor),
                            ),
                          ),
                          keyboardType: TextInputType.phone,
                          textInputAction: TextInputAction.next,
                          initialValue: e.value,
                          onChanged: (s) => person.phones[e.key] = s,
                          validator: (value) {
                            return null;
                          },
                        ),
                      ),
                    ),
                  ElevatedButton.icon(
                    icon: Icon(Icons.add),
                    label: Text('اضافة رقم هاتف أخر'),
                    onPressed: () async {
                      TextEditingController name =
                          TextEditingController(text: '');
                      if (await showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, name.text),
                                    child: Text('حفظ'),
                                  )
                                ],
                                title: Text('اسم الهاتف'),
                                content: TextField(controller: name)),
                          ) !=
                          null) setState(() => person.phones[name.text] = '');
                    },
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisSize: MainAxisSize.max,
                    children: <Widget>[
                      Flexible(
                        flex: 3,
                        child: Container(
                          padding: EdgeInsets.symmetric(vertical: 4.0),
                          child: Focus(
                            focusNode: foci[4],
                            child: GestureDetector(
                              onTap: () async => person.birthDate =
                                  await _selectDate(
                                      'تاريخ الميلاد',
                                      person.birthDate?.toDate() ??
                                          DateTime.now()),
                              child: InputDecorator(
                                decoration: InputDecoration(
                                    labelText: 'تاريخ الميلاد',
                                    border: OutlineInputBorder(
                                      borderSide: BorderSide(
                                          color:
                                              Theme.of(context).primaryColor),
                                    )),
                                child: person.birthDate != null
                                    ? Text(DateFormat('yyyy/M/d')
                                        .format(person.birthDate.toDate()))
                                    : Text('(فارغ)'),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Flexible(
                        flex: 2,
                        child: TextButton.icon(
                            icon: Icon(Icons.close),
                            onPressed: () => setState(() {
                                  person.birthDate = null;
                                }),
                            label: Text('حذف التاريخ')),
                      ),
                    ],
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(vertical: 4.0),
                    child: TextFormField(
                      maxLines: null,
                      decoration: InputDecoration(
                          labelText: 'العنوان',
                          border: OutlineInputBorder(
                            borderSide: BorderSide(
                                color: Theme.of(context).primaryColor),
                          )),
                      focusNode: foci[5],
                      textInputAction: TextInputAction.newline,
                      initialValue: person.address,
                      onChanged: _addressChanged,
                      onFieldSubmitted: (_) {
                        foci[6].requestFocus();
                      },
                      validator: (value) {
                        return null;
                      },
                    ),
                  ),
                  ElevatedButton.icon(
                    icon: Icon(Icons.map),
                    label: Text('تعديل مكان المنزل على الخريطة'),
                    onPressed: () async {
                      var oldPoint = person.location != null
                          ? GeoPoint(person.location.latitude,
                              person.location.longitude)
                          : null;
                      var rslt = await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => Scaffold(
                            appBar: AppBar(
                              actions: <Widget>[
                                IconButton(
                                  icon: Icon(Icons.done),
                                  onPressed: () => Navigator.pop(context, true),
                                  tooltip: 'حفظ',
                                ),
                                IconButton(
                                  icon: Icon(Icons.delete),
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  tooltip: 'حذف التحديد',
                                )
                              ],
                              title:
                                  Text('تعديل مكان ${person.name} على الخريطة'),
                            ),
                            body: person.getMapView(
                                editMode: true, useGPSIfNull: true),
                          ),
                        ),
                      );
                      if (rslt == null) {
                        person.location = oldPoint;
                      } else if (rslt == false) {
                        person.location = null;
                      }
                    },
                  ),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Focus(
                          focusNode: foci[6],
                          child: FutureBuilder<QuerySnapshot>(
                            future: School.getAllForUser(),
                            builder: (context, data) {
                              if (data.hasData) {
                                return Container(
                                  padding: EdgeInsets.symmetric(vertical: 4.0),
                                  child: DropdownButtonFormField(
                                    value: person.school?.path,
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
                                      person.school = value != null
                                          ? FirebaseFirestore.instance
                                              .doc(value)
                                          : null;
                                      foci[7].requestFocus();
                                    },
                                    decoration: InputDecoration(
                                        labelText: 'المدرسة',
                                        border: OutlineInputBorder(
                                          borderSide: BorderSide(
                                              color: Theme.of(context)
                                                  .primaryColor),
                                        )),
                                  ),
                                );
                              } else {
                                return Container();
                              }
                            },
                          ),
                        ),
                      ),
                      TextButton.icon(
                        icon: Icon(Icons.add),
                        label: Text('اضافة'),
                        onPressed: () async {
                          await Navigator.of(context)
                              .pushNamed('Settings/Schools');
                          setState(() {});
                        },
                      ),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisSize: MainAxisSize.max,
                    children: <Widget>[
                      Expanded(
                        child: Focus(
                          focusNode: foci[7],
                          child: FutureBuilder<QuerySnapshot>(
                            future: Church.getAllForUser(),
                            builder: (context, data) {
                              if (data.hasData) {
                                return Container(
                                  padding: EdgeInsets.symmetric(vertical: 4.0),
                                  child: DropdownButtonFormField(
                                    value: person.church?.path,
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
                                      person.church = value != null
                                          ? FirebaseFirestore.instance
                                              .doc(value)
                                          : null;
                                      foci[8].requestFocus();
                                    },
                                    decoration: InputDecoration(
                                        labelText: 'الكنيسة',
                                        border: OutlineInputBorder(
                                          borderSide: BorderSide(
                                              color: Theme.of(context)
                                                  .primaryColor),
                                        )),
                                  ),
                                );
                              } else {
                                return Container();
                              }
                            },
                          ),
                        ),
                      ),
                      TextButton.icon(
                        icon: Icon(Icons.add),
                        label: Text('اضافة'),
                        onPressed: () async {
                          await Navigator.of(context)
                              .pushNamed('Settings/Churches');
                          setState(() {});
                        },
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: Focus(
                          focusNode: foci[10],
                          child: FutureBuilder<QuerySnapshot>(
                            future: Father.getAllForUser(),
                            builder: (context, data) {
                              if (data.hasData) {
                                return DropdownButtonFormField(
                                  value: person.cFather?.path,
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
                                    person.cFather = value != null
                                        ? FirebaseFirestore.instance.doc(value)
                                        : null;
                                    foci[11].requestFocus();
                                    _selectClass();
                                  },
                                  decoration: InputDecoration(
                                      labelText: 'أب الاعتراف',
                                      border: OutlineInputBorder(
                                        borderSide: BorderSide(
                                            color:
                                                Theme.of(context).primaryColor),
                                      )),
                                );
                              } else {
                                return Container();
                              }
                            },
                          ),
                        ),
                      ),
                      TextButton.icon(
                        icon: Icon(Icons.add),
                        label: Text('اضافة'),
                        onPressed: () async {
                          await Navigator.of(context)
                              .pushNamed('Settings/Fathers');
                          setState(() {});
                        },
                      ),
                    ],
                  ),
                  Focus(
                    focusNode: foci[11],
                    child: GestureDetector(
                      onTap: _selectClass,
                      child: Container(
                        padding: EdgeInsets.symmetric(vertical: 4.0),
                        child: InputDecorator(
                          decoration: InputDecoration(
                              labelText: 'داخل فصل',
                              border: OutlineInputBorder(
                                borderSide: BorderSide(
                                    color: Theme.of(context).primaryColor),
                              )),
                          child: FutureBuilder(
                              future: person.classId == null
                                  ? null
                                  : person.getClassName(),
                              builder: (con, data) {
                                if (data.connectionState ==
                                    ConnectionState.done) {
                                  return Text(data.data);
                                } else if (data.connectionState ==
                                    ConnectionState.waiting) {
                                  return LinearProgressIndicator();
                                } else {
                                  return Text('');
                                }
                              }),
                        ),
                      ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisSize: MainAxisSize.max,
                    children: <Widget>[
                      Flexible(
                        flex: 3,
                        child: Container(
                          padding: EdgeInsets.symmetric(vertical: 4.0),
                          child: Focus(
                            focusNode: foci[12],
                            child: GestureDetector(
                              onTap: () async => person.lastTanawol =
                                  await _selectDate(
                                      'تاريخ أخر تناول',
                                      person.lastTanawol?.toDate() ??
                                          DateTime.now()),
                              child: InputDecorator(
                                decoration: InputDecoration(
                                    labelText: 'تاريخ أخر تناول',
                                    border: OutlineInputBorder(
                                      borderSide: BorderSide(
                                          color:
                                              Theme.of(context).primaryColor),
                                    )),
                                child: person.lastTanawol != null
                                    ? Text(DateFormat('yyyy/M/d')
                                        .format(person.lastTanawol.toDate()))
                                    : Text('(فارغ)'),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisSize: MainAxisSize.max,
                    children: <Widget>[
                      Flexible(
                        flex: 3,
                        child: Container(
                          padding: EdgeInsets.symmetric(vertical: 4.0),
                          child: Focus(
                            focusNode: foci[13],
                            child: GestureDetector(
                              onTap: () async => person.lastConfession =
                                  await _selectDate(
                                      'تاريخ أخر اعتراف',
                                      person.lastConfession?.toDate() ??
                                          DateTime.now()),
                              child: InputDecorator(
                                decoration: InputDecoration(
                                    labelText: 'تاريخ أخر اعتراف',
                                    border: OutlineInputBorder(
                                      borderSide: BorderSide(
                                          color:
                                              Theme.of(context).primaryColor),
                                    )),
                                child: person.lastConfession != null
                                    ? Text(DateFormat('yyyy/M/d')
                                        .format(person.lastConfession.toDate()))
                                    : Text('(فارغ)'),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisSize: MainAxisSize.max,
                    children: <Widget>[
                      Flexible(
                        flex: 3,
                        child: Container(
                          padding: EdgeInsets.symmetric(vertical: 4.0),
                          child: Focus(
                            focusNode: foci[14],
                            child: GestureDetector(
                              onTap: () async => person.lastKodas =
                                  await _selectDate(
                                      'تاريخ حضور أخر قداس',
                                      person.lastKodas?.toDate() ??
                                          DateTime.now()),
                              child: InputDecorator(
                                decoration: InputDecoration(
                                    labelText: 'تاريخ حضور أخر قداس',
                                    border: OutlineInputBorder(
                                      borderSide: BorderSide(
                                          color:
                                              Theme.of(context).primaryColor),
                                    )),
                                child: person.lastKodas != null
                                    ? Text(DateFormat('yyyy/M/d')
                                        .format(person.lastKodas.toDate()))
                                    : Text('(فارغ)'),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisSize: MainAxisSize.max,
                    children: <Widget>[
                      Flexible(
                        flex: 3,
                        child: Container(
                          padding: EdgeInsets.symmetric(vertical: 4.0),
                          child: Focus(
                            focusNode: foci[15],
                            child: GestureDetector(
                              onTap: () async => person.lastMeeting =
                                  await _selectDate(
                                      'تاريخ حضور أخر اجتماع',
                                      person.lastMeeting?.toDate() ??
                                          DateTime.now()),
                              child: InputDecorator(
                                decoration: InputDecoration(
                                    labelText: 'تاريخ حضور أخر اجتماع',
                                    border: OutlineInputBorder(
                                      borderSide: BorderSide(
                                          color:
                                              Theme.of(context).primaryColor),
                                    )),
                                child: person.lastMeeting != null
                                    ? Text(DateFormat('yyyy/M/d')
                                        .format(person.lastMeeting.toDate()))
                                    : Text('(فارغ)'),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(vertical: 4.0),
                    child: Focus(
                      focusNode: foci[16],
                      child: GestureDetector(
                        onTap: () async => person.lastVisit = await _selectDate(
                            'تاريخ أخر زيارة',
                            person.lastVisit?.toDate() ?? DateTime.now()),
                        child: InputDecorator(
                          decoration: InputDecoration(
                              labelText: 'تاريخ أخر زيارة',
                              border: OutlineInputBorder(
                                borderSide: BorderSide(
                                    color: Theme.of(context).primaryColor),
                              )),
                          child: person.lastVisit != null
                              ? Text(DateFormat('yyyy/M/d')
                                  .format(person.lastVisit.toDate()))
                              : Text('(فارغ)'),
                        ),
                      ),
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(vertical: 4.0),
                    child: TextFormField(
                      decoration: InputDecoration(
                          labelText: 'ملاحظات',
                          border: OutlineInputBorder(
                            borderSide: BorderSide(
                                color: Theme.of(context).primaryColor),
                          )),
                      focusNode: foci[17],
                      textInputAction: TextInputAction.newline,
                      initialValue: person.notes,
                      onChanged: _notesChanged,
                      maxLines: null,
                      validator: (value) {
                        return null;
                      },
                    ),
                  ),
                  ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        primary:
                            Theme.of(context).brightness == Brightness.light
                                ? TinyColor(person.color).lighten().color
                                : TinyColor(person.color).darken().color,
                      ),
                      onPressed: selectColor,
                      icon: Icon(Icons.color_lens),
                      label: Text('اللون')),
                ],
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          if (person.id.isNotEmpty)
            FloatingActionButton(
              mini: true,
              tooltip: 'حذف',
              heroTag: 'Delete',
              onPressed: _delete,
              child: Icon(Icons.delete),
            ),
          FloatingActionButton(
            tooltip: 'حفظ',
            heroTag: 'Save',
            onPressed: _save,
            child: Icon(Icons.save),
          ),
        ],
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    person = widget.person ?? Person();
    old = person.getMap();
  }

  void selectColor() async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              setState(() {
                person.color = Colors.transparent;
              });
            },
            child: Text('بلا لون'),
          ),
        ],
        content: ColorsList(
          selectedColor: person.color,
          onSelect: (color) {
            Navigator.of(context).pop();
            setState(() {
              person.color = color;
            });
          },
        ),
      ),
    );
  }

  void _addressChanged(String value) {
    person.address = value;
  }

  void _delete() {
    showDialog(
        context: context,
        builder: (context) => AlertDialog(
              title: Text(person.name),
              content: Text('هل أنت متأكد من حذف ${person.name}؟'),
              actions: <Widget>[
                TextButton(
                  onPressed: () async {
                    if (person.hasPhoto) {
                      await FirebaseStorage.instance
                          .ref()
                          .child('PersonsPhotos/${person.id}')
                          .delete();
                    }
                    await FirebaseFirestore.instance
                        .collection('Persons')
                        .doc(person.id)
                        .delete();
                    Navigator.of(context).pop();
                    Navigator.of(context).pop('deleted');
                  },
                  child: Text('نعم'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: Text('تراجع'),
                ),
              ],
            ));
  }

  void _fatherPhoneChanged(String value) {
    person.fatherPhone = value;
  }

  void _motherPhoneChanged(String value) {
    person.motherPhone = value;
  }

  void _nameChanged(String value) {
    person.name = value;
  }

  void _notesChanged(String value) {
    person.notes = value;
  }

  void _phoneChanged(String value) {
    person.phone = value;
  }

  Future _save() async {
    try {
      if (form.currentState.validate() && person.classId != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('جار الحفظ...'),
            duration: Duration(minutes: 1),
          ),
        );
        var update = person.id != '';
        if (person.id == '') {
          person.id = FirebaseFirestore.instance.collection('Persons').doc().id;
        }
        if (changedImage != null) {
          await FirebaseStorage.instance
              .ref()
              .child('PersonsPhotos/${person.id}')
              .putFile(File(changedImage));
          person.hasPhoto = true;
        } else if (deletePhoto) {
          await FirebaseStorage.instance
              .ref()
              .child('PersonsPhotos/${person.id}')
              .delete();
        }

        person.lastEdit = auth.FirebaseAuth.instance.currentUser.uid;

        if (update) {
          await FirebaseFirestore.instance
              .collection('Persons')
              .doc(person.id)
              .update(person.getMap()
                ..removeWhere((key, value) => old[key] == value));
        } else {
          await FirebaseFirestore.instance
              .collection('Persons')
              .doc(person.id)
              .set(person.getMap());
        }
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        Navigator.of(context).pop(person.ref);
      } else {
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('بيانات غير كاملة'),
            content:
                Text('يرجى التأكد من ملئ هذه الحقول:\nالاسم\nالفصل\nنوع الفرد'),
          ),
        );
      }
    } catch (err, stkTrace) {
      await FirebaseCrashlytics.instance
          .setCustomKey('LastErrorIn', 'PersonP.save');
      await FirebaseCrashlytics.instance.recordError(err, stkTrace);
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(err.toString()),
        duration: Duration(seconds: 7),
      ));
    }
  }

  void _selectClass() {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          child: ListenableProvider<SearchString>(
            create: (_) => SearchString(''),
            builder: (context, child) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SearchFilters(0,
                    textStyle: Theme.of(context).textTheme.bodyText2),
                Expanded(
                  child:
                      Selector2<OrderOptions, User, Tuple3<String, bool, User>>(
                    selector: (_, o, u) => Tuple3<String, bool, User>(
                        o.personOrderBy, o.personASC, u),
                    builder: (context, options, child) => ServicesList(
                      options: ServicesListOptions(
                        tap: (class$, context) {
                          Navigator.pop(context);
                          person.classId = class$.ref;
                          setState(() {});
                          foci[13].requestFocus();
                        },
                        floatingActionButton: options.item3.write
                            ? FloatingActionButton(
                                heroTag: null,
                                onPressed: () async {
                                  Navigator.of(context).pop();
                                  person.classId = (await Navigator.of(context)
                                              .pushNamed('Data/EditClass'))
                                          as DocumentReference ??
                                      person.classId;
                                  setState(() {});
                                },
                                child: Icon(Icons.group_add),
                              )
                            : null,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<Timestamp> _selectDate(String helpText, DateTime initialDate) async {
    var picked = await showDatePicker(
        helpText: helpText,
        locale: Locale('ar', 'EG'),
        context: context,
        initialDate: initialDate,
        firstDate: DateTime(1500),
        lastDate: DateTime.now());
    if (picked != null && picked != initialDate) {
      setState(() {});
      return Timestamp.fromDate(picked);
    }
    return Timestamp.fromDate(initialDate);
  }

  // void _selectType() {
  //   showDialog(
  //       context: context,
  //       builder: (context) {
  //         return AlertDialog(
  //           content: TypesList(
  //             list: FirebaseFirestore.instance
  //                 .collection('Types')
  //                 .get(source: dataSource),
  //             tap: (type, _) {
  //               Navigator.of(context).pop();
  //               setState(() {
  //                 widget.me.type = type.ref;
  //               });
  //               focuses[7].requestFocus();
  //             },
  //           ),
  //         );
  //       });
  // }
}
