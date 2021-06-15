import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_storage/firebase_storage.dart' show FirebaseStorage;
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:meetinghelper/models/list_controllers.dart';
import 'package:meetinghelper/models/order_options.dart';
import 'package:meetinghelper/models/search_filters.dart';
import 'package:meetinghelper/models/user.dart';
import 'package:meetinghelper/utils/globals.dart';
import 'package:meetinghelper/utils/helpers.dart';
import 'package:meetinghelper/utils/typedefs.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:rxdart/rxdart.dart';
import 'package:tinycolor/tinycolor.dart';

import '../../models/mini_models.dart';
import '../../models/models.dart';
import '../../views/mini_lists/colors_list.dart';
import '../services_list.dart';

class EditPerson extends StatefulWidget {
  final Person? person;
  final Function(FormState, Person)? save;
  final bool showMotherAndFatherPhones;

  const EditPerson(
      {Key? key, this.person, this.save, this.showMotherAndFatherPhones = true})
      : super(key: key);

  @override
  _EditPersonState createState() => _EditPersonState();
}

class _EditPersonState extends State<EditPerson> {
  String? changedImage;
  bool deletePhoto = false;

  GlobalKey<FormState> form = GlobalKey<FormState>();

  late Person person;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
          return <Widget>[
            SliverAppBar(
              actions: <Widget>[
                IconButton(
                    icon: Builder(
                      builder: (context) => Stack(
                        children: <Widget>[
                          const Positioned(
                            left: 1.0,
                            top: 2.0,
                            child:
                                Icon(Icons.photo_camera, color: Colors.black54),
                          ),
                          Icon(Icons.photo_camera,
                              color: IconTheme.of(context).color),
                        ],
                      ),
                    ),
                    onPressed: () async {
                      var source = await showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          actions: <Widget>[
                            TextButton.icon(
                              onPressed: () =>
                                  navigator.currentState!.pop(true),
                              icon: const Icon(Icons.camera),
                              label: const Text('التقاط صورة من الكاميرا'),
                            ),
                            TextButton.icon(
                              onPressed: () =>
                                  navigator.currentState!.pop(false),
                              icon: const Icon(Icons.photo_library),
                              label: const Text('اختيار من المعرض'),
                            ),
                            TextButton.icon(
                              onPressed: () =>
                                  navigator.currentState!.pop('delete'),
                              icon: const Icon(Icons.delete),
                              label: const Text('حذف الصورة'),
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
                      var selectedImage = await ImagePicker().getImage(
                          source: source
                              ? ImageSource.camera
                              : ImageSource.gallery);
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
                    duration: const Duration(milliseconds: 300),
                    opacity: constraints.biggest.height > kToolbarHeight * 1.7
                        ? 0
                        : 1,
                    child: Text(
                      person.name,
                      style: const TextStyle(
                        fontSize: 16.0,
                      ),
                    ),
                  ),
                  background: changedImage == null
                      ? person.photo()
                      : Image.file(
                          File(changedImage!),
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
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: TextFormField(
                      decoration: InputDecoration(
                        labelText: 'الاسم',
                        border: OutlineInputBorder(
                          borderSide:
                              BorderSide(color: Theme.of(context).primaryColor),
                        ),
                      ),
                      textInputAction: TextInputAction.next,
                      initialValue: person.name,
                      onChanged: _nameChanged,
                      onFieldSubmitted: (_) =>
                          FocusScope.of(context).nextFocus(),
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
                    child: TextFormField(
                      decoration: InputDecoration(
                        labelText: 'موبايل (شخصي)',
                        border: OutlineInputBorder(
                          borderSide:
                              BorderSide(color: Theme.of(context).primaryColor),
                        ),
                      ),
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                      initialValue: person.phone,
                      onChanged: _phoneChanged,
                      onFieldSubmitted: (_) =>
                          FocusScope.of(context).nextFocus(),
                      validator: (value) {
                        return null;
                      },
                    ),
                  ),
                  if (widget.showMotherAndFatherPhones)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: TextFormField(
                        decoration: InputDecoration(
                          labelText: 'موبايل الأب',
                          border: OutlineInputBorder(
                            borderSide: BorderSide(
                                color: Theme.of(context).primaryColor),
                          ),
                        ),
                        keyboardType: TextInputType.phone,
                        textInputAction: TextInputAction.next,
                        initialValue: person.fatherPhone,
                        onChanged: _fatherPhoneChanged,
                        onFieldSubmitted: (_) =>
                            FocusScope.of(context).nextFocus(),
                        validator: (value) {
                          return null;
                        },
                      ),
                    ),
                  if (widget.showMotherAndFatherPhones)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: TextFormField(
                        decoration: InputDecoration(
                          labelText: 'موبايل الأم',
                          border: OutlineInputBorder(
                            borderSide: BorderSide(
                                color: Theme.of(context).primaryColor),
                          ),
                        ),
                        keyboardType: TextInputType.phone,
                        textInputAction: TextInputAction.next,
                        initialValue: person.motherPhone,
                        onChanged: _motherPhoneChanged,
                        onFieldSubmitted: (_) =>
                            FocusScope.of(context).nextFocus(),
                        validator: (value) {
                          return null;
                        },
                      ),
                    ),
                  if (person.phones.isNotEmpty)
                    ...person.phones.entries.map(
                      (e) => Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: TextFormField(
                          decoration: InputDecoration(
                            labelText: e.key,
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.edit),
                              tooltip: 'تعديل اسم الهاتف',
                              onPressed: () async {
                                TextEditingController name =
                                    TextEditingController(text: e.key);
                                var rslt = await showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    actions: [
                                      TextButton(
                                        onPressed: () => navigator.currentState!
                                            .pop(name.text),
                                        child: const Text('حفظ'),
                                      ),
                                      TextButton(
                                        onPressed: () => navigator.currentState!
                                            .pop('delete'),
                                        child: const Text('حذف'),
                                      ),
                                    ],
                                    title: const Text('اسم الهاتف'),
                                    content: TextField(controller: name),
                                  ),
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
                    icon: const Icon(Icons.add),
                    label: const Text('اضافة رقم هاتف أخر'),
                    onPressed: () async {
                      TextEditingController name =
                          TextEditingController(text: '');
                      if (await showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      navigator.currentState!.pop(name.text),
                                  child: const Text('حفظ'),
                                )
                              ],
                              title: const Text('اسم الهاتف'),
                              content: TextField(controller: name),
                            ),
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
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: Focus(
                            child: InkWell(
                              onTap: () async =>
                                  person.birthDate = await _selectDate(
                                'تاريخ الميلاد',
                                person.birthDate?.toDate() ?? DateTime.now(),
                              ),
                              child: InputDecorator(
                                decoration: InputDecoration(
                                  labelText: 'تاريخ الميلاد',
                                  border: OutlineInputBorder(
                                    borderSide: BorderSide(
                                        color: Theme.of(context).primaryColor),
                                  ),
                                ),
                                child: person.birthDate != null
                                    ? Text(DateFormat('yyyy/M/d')
                                        .format(person.birthDate!.toDate()))
                                    : const Text('(فارغ)'),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Flexible(
                        flex: 2,
                        child: TextButton.icon(
                          icon: const Icon(Icons.close),
                          onPressed: () => setState(() {
                            person.birthDate = null;
                          }),
                          label: const Text('حذف التاريخ'),
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: TextFormField(
                      maxLines: null,
                      decoration: InputDecoration(
                        labelText: 'العنوان',
                        border: OutlineInputBorder(
                          borderSide:
                              BorderSide(color: Theme.of(context).primaryColor),
                        ),
                      ),
                      textInputAction: TextInputAction.newline,
                      initialValue: person.address,
                      onChanged: _addressChanged,
                      onFieldSubmitted: (_) =>
                          FocusScope.of(context).nextFocus(),
                      validator: (value) {
                        return null;
                      },
                    ),
                  ),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.map),
                    label: const Text('تعديل مكان المنزل على الخريطة'),
                    onPressed: () async {
                      var oldPoint = person.location != null
                          ? GeoPoint(person.location!.latitude,
                              person.location!.longitude)
                          : null;
                      var rslt = await navigator.currentState!.push(
                        MaterialPageRoute(
                          builder: (context) => Scaffold(
                            appBar: AppBar(
                              actions: <Widget>[
                                IconButton(
                                  icon: const Icon(Icons.done),
                                  onPressed: () =>
                                      navigator.currentState!.pop(true),
                                  tooltip: 'حفظ',
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete),
                                  onPressed: () =>
                                      navigator.currentState!.pop(false),
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
                        child: FutureBuilder<JsonQuery>(
                          future: School.getAllForUser(),
                          builder: (context, data) {
                            if (data.hasData) {
                              return Container(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 4.0),
                                child: DropdownButtonFormField(
                                  value: person.school?.path,
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
                                    person.school = value != null
                                        ? FirebaseFirestore.instance.doc(value)
                                        : null;
                                    FocusScope.of(context).nextFocus();
                                  },
                                  decoration: InputDecoration(
                                    labelText: 'المدرسة',
                                    border: OutlineInputBorder(
                                      borderSide: BorderSide(
                                          color:
                                              Theme.of(context).primaryColor),
                                    ),
                                  ),
                                ),
                              );
                            }
                            return const SizedBox(width: 1, height: 1);
                          },
                        ),
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text('اضافة'),
                        onPressed: () async {
                          await navigator.currentState!
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
                        child: FutureBuilder<JsonQuery>(
                          future: Church.getAllForUser(),
                          builder: (context, data) {
                            if (data.hasData) {
                              return Container(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 4.0),
                                child: DropdownButtonFormField(
                                  value: person.church?.path,
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
                                    person.church = value != null
                                        ? FirebaseFirestore.instance.doc(value)
                                        : null;
                                    FocusScope.of(context).nextFocus();
                                  },
                                  decoration: InputDecoration(
                                    labelText: 'الكنيسة',
                                    border: OutlineInputBorder(
                                      borderSide: BorderSide(
                                          color:
                                              Theme.of(context).primaryColor),
                                    ),
                                  ),
                                ),
                              );
                            } else {
                              return const SizedBox(width: 1, height: 1);
                            }
                          },
                        ),
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text('اضافة'),
                        onPressed: () async {
                          await navigator.currentState!
                              .pushNamed('Settings/Churches');
                          setState(() {});
                        },
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: FutureBuilder<JsonQuery>(
                          future: Father.getAllForUser(),
                          builder: (context, data) {
                            if (data.hasData) {
                              return DropdownButtonFormField(
                                value: person.cFather?.path,
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
                                  person.cFather = value != null
                                      ? FirebaseFirestore.instance.doc(value)
                                      : null;
                                  FocusScope.of(context).nextFocus();
                                  _selectClass();
                                },
                                decoration: InputDecoration(
                                  labelText: 'أب الاعتراف',
                                  border: OutlineInputBorder(
                                    borderSide: BorderSide(
                                        color: Theme.of(context).primaryColor),
                                  ),
                                ),
                              );
                            } else {
                              return const SizedBox(width: 1, height: 1);
                            }
                          },
                        ),
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text('اضافة'),
                        onPressed: () async {
                          await navigator.currentState!
                              .pushNamed('Settings/Fathers');
                          setState(() {});
                        },
                      ),
                    ],
                  ),
                  Focus(
                    child: GestureDetector(
                      onTap: _selectClass,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'داخل فصل',
                            border: OutlineInputBorder(
                              borderSide: BorderSide(
                                  color: Theme.of(context).primaryColor),
                            ),
                          ),
                          child: FutureBuilder<String>(
                            future: person.classId == null
                                ? null
                                : person.getClassName(),
                            builder: (con, data) {
                              if (data.connectionState ==
                                  ConnectionState.done) {
                                return Text(data.data!);
                              } else if (data.connectionState ==
                                  ConnectionState.waiting) {
                                return const LinearProgressIndicator();
                              } else {
                                return const Text('');
                              }
                            },
                          ),
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
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: Focus(
                            child: GestureDetector(
                              onTap: () async =>
                                  person.lastTanawol = await _selectDate(
                                'تاريخ أخر تناول',
                                person.lastTanawol?.toDate() ?? DateTime.now(),
                              ),
                              child: InputDecorator(
                                decoration: InputDecoration(
                                  labelText: 'تاريخ أخر تناول',
                                  border: OutlineInputBorder(
                                    borderSide: BorderSide(
                                        color: Theme.of(context).primaryColor),
                                  ),
                                ),
                                child: person.lastTanawol != null
                                    ? Text(DateFormat('yyyy/M/d')
                                        .format(person.lastTanawol!.toDate()))
                                    : const Text('(فارغ)'),
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
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: Focus(
                            child: GestureDetector(
                              onTap: () async =>
                                  person.lastConfession = await _selectDate(
                                'تاريخ أخر اعتراف',
                                person.lastConfession?.toDate() ??
                                    DateTime.now(),
                              ),
                              child: InputDecorator(
                                decoration: InputDecoration(
                                  labelText: 'تاريخ أخر اعتراف',
                                  border: OutlineInputBorder(
                                    borderSide: BorderSide(
                                        color: Theme.of(context).primaryColor),
                                  ),
                                ),
                                child: person.lastConfession != null
                                    ? Text(DateFormat('yyyy/M/d').format(
                                        person.lastConfession!.toDate()))
                                    : const Text('(فارغ)'),
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
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: Focus(
                            child: GestureDetector(
                              onTap: () async =>
                                  person.lastKodas = await _selectDate(
                                'تاريخ حضور أخر قداس',
                                person.lastKodas?.toDate() ?? DateTime.now(),
                              ),
                              child: InputDecorator(
                                decoration: InputDecoration(
                                  labelText: 'تاريخ حضور أخر قداس',
                                  border: OutlineInputBorder(
                                    borderSide: BorderSide(
                                        color: Theme.of(context).primaryColor),
                                  ),
                                ),
                                child: person.lastKodas != null
                                    ? Text(DateFormat('yyyy/M/d')
                                        .format(person.lastKodas!.toDate()))
                                    : const Text('(فارغ)'),
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
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: Focus(
                            child: GestureDetector(
                              onTap: () async =>
                                  person.lastMeeting = await _selectDate(
                                'تاريخ حضور أخر اجتماع',
                                person.lastMeeting?.toDate() ?? DateTime.now(),
                              ),
                              child: InputDecorator(
                                decoration: InputDecoration(
                                  labelText: 'تاريخ حضور أخر اجتماع',
                                  border: OutlineInputBorder(
                                    borderSide: BorderSide(
                                        color: Theme.of(context).primaryColor),
                                  ),
                                ),
                                child: person.lastMeeting != null
                                    ? Text(DateFormat('yyyy/M/d')
                                        .format(person.lastMeeting!.toDate()))
                                    : const Text('(فارغ)'),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Focus(
                      child: GestureDetector(
                        onTap: () async => person.lastVisit = await _selectDate(
                          'تاريخ أخر زيارة',
                          person.lastVisit?.toDate() ?? DateTime.now(),
                        ),
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'تاريخ أخر زيارة',
                            border: OutlineInputBorder(
                              borderSide: BorderSide(
                                  color: Theme.of(context).primaryColor),
                            ),
                          ),
                          child: person.lastVisit != null
                              ? Text(DateFormat('yyyy/M/d')
                                  .format(person.lastVisit!.toDate()))
                              : const Text('(فارغ)'),
                        ),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Focus(
                      child: GestureDetector(
                        onTap: () async => person.lastCall = await _selectDate(
                          'تاريخ أخر مكالمة',
                          person.lastCall?.toDate() ?? DateTime.now(),
                        ),
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'تاريخ أخر مكالمة',
                            border: OutlineInputBorder(
                              borderSide: BorderSide(
                                  color: Theme.of(context).primaryColor),
                            ),
                          ),
                          child: person.lastCall != null
                              ? Text(DateFormat('yyyy/M/d')
                                  .format(person.lastCall!.toDate()))
                              : const Text('(فارغ)'),
                        ),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: TextFormField(
                      decoration: InputDecoration(
                        labelText: 'ملاحظات',
                        border: OutlineInputBorder(
                          borderSide:
                              BorderSide(color: Theme.of(context).primaryColor),
                        ),
                      ),
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
                    style: person.color != Colors.transparent
                        ? ElevatedButton.styleFrom(
                            primary:
                                Theme.of(context).brightness == Brightness.light
                                    ? TinyColor(person.color).lighten().color
                                    : TinyColor(person.color).darken().color,
                          )
                        : null,
                    onPressed: selectColor,
                    icon: const Icon(Icons.color_lens),
                    label: const Text('اللون'),
                  ),
                ].map((w) => Focus(child: w)).toList(),
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          if (person.id != 'null' &&
              (person is! User || (person as User).uid == null))
            FloatingActionButton(
              mini: true,
              tooltip: 'حذف',
              heroTag: 'Delete',
              onPressed: _delete,
              child: const Icon(Icons.delete),
            ),
          FloatingActionButton(
            tooltip: 'حفظ',
            heroTag: 'Save',
            onPressed: () {
              if (widget.save != null)
                widget.save!(form.currentState!, person);
              else
                _save();
            },
            child: const Icon(Icons.save),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    person = (widget.person ?? Person()).copyWith();
  }

  void selectColor() async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        actions: [
          TextButton(
            onPressed: () {
              navigator.currentState!.pop();
              setState(() {
                person.color = Colors.transparent;
              });
            },
            child: const Text('بلا لون'),
          ),
        ],
        content: ColorsList(
          selectedColor: person.color,
          onSelect: (color) {
            navigator.currentState!.pop();
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

  void _delete() async {
    if (await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(person.name),
            content: Text('هل أنت متأكد من حذف ${person.name}؟'),
            actions: <Widget>[
              TextButton(
                onPressed: () {
                  navigator.currentState!.pop(true);
                },
                child: const Text('نعم'),
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
      if (await Connectivity().checkConnectivity() != ConnectivityResult.none) {
        await person.ref.delete();
      } else {
        // ignore: unawaited_futures
        person.ref.delete();

        navigator.currentState!.pop('deleted');
      }
    }
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
      if (form.currentState!.validate() && person.classId != null) {
        scaffoldMessenger.currentState!.showSnackBar(
          const SnackBar(
            content: Text('جار الحفظ...'),
            duration: Duration(minutes: 1),
          ),
        );
        var update = person.id != 'null';
        if (!update) {
          person.ref = FirebaseFirestore.instance.collection('Persons').doc();
        }
        if (changedImage != null) {
          await FirebaseStorage.instance
              .ref()
              .child('PersonsPhotos/${person.id}')
              .putFile(File(changedImage!));
          person.hasPhoto = true;
        } else if (deletePhoto) {
          await FirebaseStorage.instance
              .ref()
              .child('PersonsPhotos/${person.id}')
              .delete();
        }

        person.lastEdit = auth.FirebaseAuth.instance.currentUser!.uid;

        if (update &&
            await Connectivity().checkConnectivity() !=
                ConnectivityResult.none) {
          await person.update(old: widget.person?.getMap() ?? {});
        } else if (update) {
          //Intentionally unawaited because of no internet connection
          // ignore: unawaited_futures
          person.update(old: widget.person?.getMap() ?? {});
        } else if (await Connectivity().checkConnectivity() !=
            ConnectivityResult.none) {
          await person.set();
        } else {
          //Intentionally unawaited because of no internet connection
          // ignore: unawaited_futures
          person.set();
        }
        scaffoldMessenger.currentState!.hideCurrentSnackBar();
        navigator.currentState!.pop(person.ref);
      } else {
        await showDialog(
          context: context,
          builder: (context) => const AlertDialog(
            title: Text('بيانات غير كاملة'),
            content: Text('يرجى التأكد من ملئ هذه الحقول:\nالاسم\nالفصل'),
          ),
        );
      }
    } catch (err, stkTrace) {
      await FirebaseCrashlytics.instance
          .setCustomKey('LastErrorIn', 'PersonP.save');
      await FirebaseCrashlytics.instance.recordError(err, stkTrace);
      scaffoldMessenger.currentState!.hideCurrentSnackBar();
      scaffoldMessenger.currentState!.showSnackBar(SnackBar(
        content: Text(
          err.toString(),
        ),
        duration: const Duration(seconds: 7),
      ));
    }
  }

  void _selectClass() async {
    final controller = ServicesListController(
      tap: (class$) {
        navigator.currentState!.pop();
        person.classId = class$.ref;
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
                    heroTag: null,
                    onPressed: () async {
                      navigator.currentState!.pop();
                      person.classId = await navigator.currentState!
                              .pushNamed('Data/EditClass') as JsonRef? ??
                          person.classId;
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

  Future<Timestamp> _selectDate(String helpText, DateTime initialDate) async {
    var picked = await showDatePicker(
        helpText: helpText,
        locale: const Locale('ar', 'EG'),
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
  //               navigator.currentState.pop();
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
