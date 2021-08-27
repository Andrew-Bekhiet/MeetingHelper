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
import 'package:meetinghelper/views/form_widgets/decorated_text_form_field.dart';
import 'package:meetinghelper/views/form_widgets/tapable_form_field.dart';
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

  final GlobalKey<FormState> _form = GlobalKey<FormState>();

  late Person person;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
          return <Widget>[
            SliverAppBar(
              actions: <Widget>[
                if (person.id != 'null' &&
                    (person is! User || (person as User).uid == null))
                  IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: _delete,
                    tooltip: 'حذف',
                  ),
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
                  onPressed: _selectImage,
                  tooltip: 'اختيار صورة',
                )
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
                      ? person.photo(cropToCircle: false)
                      : Image.file(
                          File(changedImage!),
                        ),
                ),
              ),
            ),
          ];
        },
        body: Form(
          key: _form,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  DecoratedTextFormField(
                    labelText: 'الاسم',
                    initialValue: person.name,
                    keyboardType: TextInputType.name,
                    autoFillHints: [AutofillHints.name],
                    onChanged: (value) => person.name = value,
                  ),
                  DecoratedTextFormField(
                    labelText: 'موبايل (شخصي)',
                    keyboardType: TextInputType.phone,
                    autoFillHints: [AutofillHints.telephoneNumber],
                    initialValue: person.phone,
                    onChanged: (v) => person.phone = v,
                    validator: (value) {
                      return null;
                    },
                  ),
                  if (widget.showMotherAndFatherPhones)
                    DecoratedTextFormField(
                      labelText: 'موبايل الأب',
                      keyboardType: TextInputType.phone,
                      autoFillHints: [AutofillHints.telephoneNumber],
                      initialValue: person.fatherPhone,
                      onChanged: (v) => person.fatherPhone = v,
                      validator: (value) {
                        return null;
                      },
                    ),
                  if (widget.showMotherAndFatherPhones)
                    DecoratedTextFormField(
                      labelText: 'موبايل الأم',
                      keyboardType: TextInputType.phone,
                      autoFillHints: [AutofillHints.telephoneNumber],
                      initialValue: person.motherPhone,
                      onChanged: (v) => person.motherPhone = v,
                      validator: (value) {
                        return null;
                      },
                    ),
                  if (person.phones.isNotEmpty)
                    ...person.phones.entries.map(
                      (e) => Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: DecoratedTextFormField(
                          decoration: InputDecoration(
                            labelText: e.key,
                            hintText: 'مثال: 01234...',
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
                                    content: TextField(
                                      controller: name,
                                      decoration: const InputDecoration(
                                          hintText: 'مثال: رقم المنزل'),
                                    ),
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
                                  color: Theme.of(context).colorScheme.primary),
                            ),
                          ),
                          keyboardType: TextInputType.phone,
                          autoFillHints: [AutofillHints.telephoneNumber],
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
                              content: TextField(
                                controller: name,
                                decoration: const InputDecoration(
                                    hintText: 'مثال: رقم المنزل'),
                              ),
                            ),
                          ) !=
                          null) setState(() => person.phones[name.text] = '');
                    },
                  ),
                  TapableFormField<Timestamp?>(
                    labelText: 'تاريخ الميلاد',
                    initialValue: person.birthDate,
                    onTap: (state) async {
                      state.didChange(
                        person.birthDate = await _selectDate(
                              'تاريخ الميلاد',
                              state.value?.toDate() ?? DateTime.now(),
                            ) ??
                            state.value,
                      );
                    },
                    decoration: (context, state) => InputDecoration(
                      labelText: 'تاريخ الميلاد',
                      errorText: state.errorText,
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.delete),
                        tooltip: 'حذف التاريخ',
                        onPressed: () {
                          state.didChange(person.birthDate = null);
                        },
                      ),
                      border: OutlineInputBorder(
                        borderSide: BorderSide(
                            color: Theme.of(context).colorScheme.primary),
                      ),
                    ),
                    builder: (context, state) {
                      return state.value != null
                          ? Text(DateFormat('yyyy/M/d')
                              .format(state.value!.toDate()))
                          : null;
                    },
                    validator: (_) => null,
                  ),
                  DecoratedTextFormField(
                    labelText: 'العنوان',
                    keyboardType: TextInputType.streetAddress,
                    autoFillHints: [AutofillHints.fullStreetAddress],
                    initialValue: person.address,
                    textInputAction: TextInputAction.newline,
                    maxLines: null,
                    onChanged: (v) => person.address = v,
                    validator: (value) {
                      return null;
                    },
                  ),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.map),
                    label: const Text('تعديل مكان المنزل على الخريطة'),
                    onPressed: _editLocation,
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisSize: MainAxisSize.max,
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
                                  isExpanded: true,
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
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary),
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
                                  isExpanded: true,
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
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary),
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
                                isExpanded: true,
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
                                },
                                decoration: InputDecoration(
                                  labelText: 'أب الاعتراف',
                                  border: OutlineInputBorder(
                                    borderSide: BorderSide(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary),
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
                  TapableFormField<DocumentReference?>(
                    labelText: 'داخل فصل',
                    initialValue: person.classId,
                    onTap: _selectClass,
                    builder: (context, state) {
                      return state.value == null
                          ? null
                          : FutureBuilder<String>(
                              future: person.classId == null
                                  ? null
                                  : person.getClassName(),
                              builder: (con, data) {
                                if (data.hasData) {
                                  return Text(data.data!);
                                } else if (data.connectionState ==
                                    ConnectionState.waiting) {
                                  return const LinearProgressIndicator();
                                } else {
                                  return const Text('');
                                }
                              },
                            );
                    },
                  ),
                  TapableFormField<Timestamp?>(
                    labelText: 'تاريخ أخر تناول',
                    initialValue: person.lastTanawol,
                    onTap: (state) async {
                      state.didChange(
                        person.lastTanawol = await _selectDate(
                              'تاريخ أخر تناول',
                              state.value?.toDate() ?? DateTime.now(),
                            ) ??
                            state.value,
                      );
                    },
                    decoration: (context, state) => InputDecoration(
                      labelText: 'تاريخ أخر تناول',
                      errorText: state.errorText,
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.delete),
                        tooltip: 'حذف التاريخ',
                        onPressed: () {
                          state.didChange(person.lastTanawol = null);
                        },
                      ),
                      border: OutlineInputBorder(
                        borderSide: BorderSide(
                            color: Theme.of(context).colorScheme.primary),
                      ),
                    ),
                    builder: (context, state) {
                      return state.value != null
                          ? Text(DateFormat('yyyy/M/d')
                              .format(state.value!.toDate()))
                          : null;
                    },
                    validator: (_) => null,
                  ),
                  TapableFormField<Timestamp?>(
                    labelText: 'تاريخ أخر اعتراف',
                    initialValue: person.lastConfession,
                    onTap: (state) async {
                      state.didChange(
                        person.lastConfession = await _selectDate(
                              'تاريخ أخر اعتراف',
                              state.value?.toDate() ?? DateTime.now(),
                            ) ??
                            state.value,
                      );
                    },
                    decoration: (context, state) => InputDecoration(
                      labelText: 'تاريخ أخر اعتراف',
                      errorText: state.errorText,
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.delete),
                        tooltip: 'حذف التاريخ',
                        onPressed: () {
                          state.didChange(person.lastConfession = null);
                        },
                      ),
                      border: OutlineInputBorder(
                        borderSide: BorderSide(
                            color: Theme.of(context).colorScheme.primary),
                      ),
                    ),
                    builder: (context, state) {
                      return state.value != null
                          ? Text(DateFormat('yyyy/M/d')
                              .format(state.value!.toDate()))
                          : null;
                    },
                    validator: (_) => null,
                  ),
                  TapableFormField<Timestamp?>(
                    labelText: 'تاريخ حضور أخر قداس',
                    initialValue: person.lastKodas,
                    onTap: (state) async {
                      state.didChange(
                        person.lastKodas = await _selectDate(
                              'تاريخ حضور أخر قداس',
                              state.value?.toDate() ?? DateTime.now(),
                            ) ??
                            state.value,
                      );
                    },
                    decoration: (context, state) => InputDecoration(
                      labelText: 'تاريخ حضور أخر قداس',
                      errorText: state.errorText,
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.delete),
                        tooltip: 'حذف التاريخ',
                        onPressed: () {
                          state.didChange(person.lastKodas = null);
                        },
                      ),
                      border: OutlineInputBorder(
                        borderSide: BorderSide(
                            color: Theme.of(context).colorScheme.primary),
                      ),
                    ),
                    builder: (context, state) {
                      return state.value != null
                          ? Text(DateFormat('yyyy/M/d')
                              .format(state.value!.toDate()))
                          : null;
                    },
                    validator: (_) => null,
                  ),
                  TapableFormField<Timestamp?>(
                    labelText: 'تاريخ أخر زيارة',
                    initialValue: person.lastVisit,
                    onTap: (state) async {
                      state.didChange(
                        person.lastVisit = await _selectDate(
                              'تاريخ أخر زيارة',
                              state.value?.toDate() ?? DateTime.now(),
                            ) ??
                            state.value,
                      );
                    },
                    decoration: (context, state) => InputDecoration(
                      labelText: 'تاريخ أخر زيارة',
                      errorText: state.errorText,
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.delete),
                        tooltip: 'حذف التاريخ',
                        onPressed: () {
                          state.didChange(person.lastVisit = null);
                        },
                      ),
                      border: OutlineInputBorder(
                        borderSide: BorderSide(
                            color: Theme.of(context).colorScheme.primary),
                      ),
                    ),
                    builder: (context, state) {
                      return state.value != null
                          ? Text(DateFormat('yyyy/M/d')
                              .format(state.value!.toDate()))
                          : null;
                    },
                    validator: (_) => null,
                  ),
                  TapableFormField<Timestamp?>(
                    labelText: 'تاريخ أخر مكالمة',
                    initialValue: person.lastCall,
                    onTap: (state) async {
                      state.didChange(
                        person.lastCall = await _selectDate(
                              'تاريخ أخر مكالمة',
                              state.value?.toDate() ?? DateTime.now(),
                            ) ??
                            state.value,
                      );
                    },
                    decoration: (context, state) => InputDecoration(
                      labelText: 'تاريخ أخر مكالمة',
                      errorText: state.errorText,
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.delete),
                        tooltip: 'حذف التاريخ',
                        onPressed: () {
                          state.didChange(person.lastCall = null);
                        },
                      ),
                      border: OutlineInputBorder(
                        borderSide: BorderSide(
                            color: Theme.of(context).colorScheme.primary),
                      ),
                    ),
                    builder: (context, state) {
                      return state.value != null
                          ? Text(DateFormat('yyyy/M/d')
                              .format(state.value!.toDate()))
                          : null;
                    },
                    validator: (_) => null,
                  ),
                  DecoratedTextFormField(
                    labelText: 'ملاحظات',
                    textInputAction: TextInputAction.newline,
                    initialValue: person.notes,
                    onChanged: (v) => person.notes = v,
                    maxLines: null,
                    validator: (value) => null,
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
                    onPressed: _selectColor,
                    icon: const Icon(Icons.color_lens),
                    label: const Text('اللون'),
                  ),
                ].map((w) => Focus(child: w)).toList(),
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'حفظ',
        onPressed: () {
          if (widget.save != null)
            widget.save!(_form.currentState!, person);
          else
            _save();
        },
        child: const Icon(Icons.save),
      ),
    );
  }

  void _editLocation() async {
    var oldPoint = person.location != null
        ? GeoPoint(person.location!.latitude, person.location!.longitude)
        : null;
    var rslt = await navigator.currentState!.push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            actions: <Widget>[
              IconButton(
                icon: const Icon(Icons.done),
                onPressed: () => navigator.currentState!.pop(true),
                tooltip: 'حفظ',
              ),
              IconButton(
                icon: const Icon(Icons.delete),
                onPressed: () => navigator.currentState!.pop(false),
                tooltip: 'حذف التحديد',
              )
            ],
            title: Text('تعديل مكان ${person.name} على الخريطة'),
          ),
          body: person.getMapView(editMode: true, useGPSIfNull: true),
        ),
      ),
    );
    if (rslt == null) {
      person.location = oldPoint;
    } else if (rslt == false) {
      person.location = null;
    }
  }

  @override
  void initState() {
    super.initState();
    person = (widget.person ?? Person()).copyWith();
  }

  void _selectColor() async {
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

  Future _save() async {
    try {
      if (_form.currentState!.validate() && person.classId != null) {
        _form.currentState!.save();
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
        scaffoldMessenger.currentState!.showSnackBar(
          const SnackBar(
            content: Text('يرجى التحقق من الييانات المدخلة'),
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

  void _selectClass(FormFieldState<DocumentReference?> state) async {
    final controller = ServicesListController(
      tap: (class$) {
        navigator.currentState!.pop();
        state.didChange(person.classId = class$.ref);
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
                      state.didChange(person.classId = await navigator
                              .currentState!
                              .pushNamed('Data/EditClass') as JsonRef? ??
                          person.classId);
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

  Future<Timestamp?> _selectDate(String helpText, DateTime initialDate) async {
    var picked = await showDatePicker(
        helpText: helpText,
        locale: const Locale('ar', 'EG'),
        context: context,
        initialDate: initialDate,
        firstDate: DateTime(1500),
        lastDate: DateTime.now());
    if (picked != null && picked != initialDate) {
      return Timestamp.fromDate(picked);
    }
    return null;
  }

  Future<void> _selectImage() async {
    var source = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        actions: <Widget>[
          TextButton.icon(
            onPressed: () => navigator.currentState!.pop(true),
            icon: const Icon(Icons.camera),
            label: const Text('التقاط صورة من الكاميرا'),
          ),
          TextButton.icon(
            onPressed: () => navigator.currentState!.pop(false),
            icon: const Icon(Icons.photo_library),
            label: const Text('اختيار من المعرض'),
          ),
          if (changedImage != null || person.hasPhoto)
            TextButton.icon(
              onPressed: () => navigator.currentState!.pop('delete'),
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
    if (source as bool && !(await Permission.camera.request()).isGranted)
      return;

    var selectedImage = await ImagePicker()
        .getImage(source: source ? ImageSource.camera : ImageSource.gallery);
    if (selectedImage == null) return;
    changedImage = (await ImageCropper.cropImage(
      sourcePath: selectedImage.path,
      cropStyle: CropStyle.circle,
      androidUiSettings: AndroidUiSettings(
          toolbarTitle: 'قص الصورة',
          toolbarColor: Theme.of(context).colorScheme.primary,
          initAspectRatio: CropAspectRatioPreset.square,
          lockAspectRatio: false),
    ))
        ?.path;
    deletePhoto = false;
    setState(() {});
  }
}
