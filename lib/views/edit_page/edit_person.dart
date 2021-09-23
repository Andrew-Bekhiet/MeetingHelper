import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:firebase_storage/firebase_storage.dart' show FirebaseStorage;
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:meetinghelper/models/data/class.dart';
import 'package:meetinghelper/models/data/person.dart';
import 'package:meetinghelper/models/data/service.dart';
import 'package:meetinghelper/models/data/user.dart';
import 'package:meetinghelper/models/list_controllers.dart';
import 'package:meetinghelper/models/search/order_options.dart';
import 'package:meetinghelper/models/search/search_filters.dart';
import 'package:meetinghelper/utils/globals.dart';
import 'package:meetinghelper/utils/helpers.dart';
import 'package:meetinghelper/utils/typedefs.dart';
import 'package:meetinghelper/views/form_widgets/tapable_form_field.dart';
import 'package:meetinghelper/views/list.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:rxdart/rxdart.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:tinycolor2/tinycolor2.dart';

import '../../models/mini_models.dart';
import '../../views/mini_lists/colors_list.dart';
import '../services_list.dart';

class EditPerson extends StatefulWidget {
  final Person? person;

  const EditPerson({Key? key, this.person}) : super(key: key);

  @override
  _EditPersonState createState() => _EditPersonState();
}

class _EditPersonState extends State<EditPerson> {
  String? changedImage;
  bool deletePhoto = false;

  final GlobalKey<FormState> _form = GlobalKey<FormState>();

  late Person person;

  void _nextFocus([_]) {
    FocusScope.of(context).nextFocus();
  }

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
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    child: TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'الاسم',
                      ),
                      initialValue: person.name,
                      keyboardType: TextInputType.name,
                      autofillHints: const [AutofillHints.name],
                      onChanged: (value) => person.name = value,
                      textInputAction: TextInputAction.next,
                      textCapitalization: TextCapitalization.words,
                      onFieldSubmitted: _nextFocus,
                      validator: (value) {
                        if (value?.isEmpty ?? true) {
                          return 'يجب ملئ اسم الفصل';
                        }
                        return null;
                      },
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    child: TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'موبايل (شخصي)',
                      ),
                      keyboardType: TextInputType.phone,
                      autofillHints: const [AutofillHints.telephoneNumber],
                      initialValue: person.phone,
                      onChanged: (v) => person.phone = v,
                      onFieldSubmitted: _nextFocus,
                      validator: (value) {
                        return null;
                      },
                      textInputAction: TextInputAction.next,
                    ),
                  ),
                  if (widget.person is! User)
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      child: TextFormField(
                        decoration: const InputDecoration(
                          labelText: 'موبايل الأب',
                        ),
                        keyboardType: TextInputType.phone,
                        autofillHints: const [AutofillHints.telephoneNumber],
                        initialValue: person.fatherPhone,
                        onChanged: (v) => person.fatherPhone = v,
                        onFieldSubmitted: _nextFocus,
                        validator: (value) {
                          return null;
                        },
                        textInputAction: TextInputAction.next,
                      ),
                    ),
                  if (widget.person is! User)
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      child: TextFormField(
                        decoration: const InputDecoration(
                          labelText: 'موبايل الأم',
                        ),
                        keyboardType: TextInputType.phone,
                        autofillHints: const [AutofillHints.telephoneNumber],
                        initialValue: person.motherPhone,
                        onChanged: (v) => person.motherPhone = v,
                        onFieldSubmitted: _nextFocus,
                        validator: (value) {
                          return null;
                        },
                        textInputAction: TextInputAction.next,
                      ),
                    ),
                  if (person.phones.isNotEmpty)
                    ...person.phones.entries.map(
                      (e) => Container(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        child: TextFormField(
                          decoration: InputDecoration(
                            labelText: e.key,
                            hintText: 'مثال: 01234...',
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.edit),
                              tooltip: 'تعديل اسم الهاتف',
                              onPressed: () async {
                                final TextEditingController name =
                                    TextEditingController(text: e.key);
                                final rslt = await showDialog(
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
                          ),
                          keyboardType: TextInputType.phone,
                          autofillHints: const [AutofillHints.telephoneNumber],
                          initialValue: e.value,
                          onChanged: (s) => person.phones[e.key] = s,
                          onFieldSubmitted: _nextFocus,
                          validator: (value) {
                            return null;
                          },
                          textInputAction: TextInputAction.next,
                        ),
                      ),
                    ),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('اضافة رقم هاتف أخر'),
                    onPressed: () async {
                      final TextEditingController name =
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
                    ),
                    builder: (context, state) {
                      return state.value != null
                          ? Text(DateFormat('yyyy/M/d')
                              .format(state.value!.toDate()))
                          : null;
                    },
                    validator: (_) => null,
                  ),
                  if (person.classId == null)
                    FutureBuilder<JsonQuery>(
                      key: ValueKey(person.studyYear),
                      future: StudyYear.getAllForUser(),
                      builder: (conext, data) {
                        if (data.hasData) {
                          return Container(
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            child: DropdownButtonFormField<JsonRef?>(
                              validator: (v) {
                                if (person.classId == null && v == null) {
                                  return 'هذا الحقل مطلوب';
                                } else {
                                  return null;
                                }
                              },
                              value: person.studyYear,
                              items: data.data!.docs
                                  .map(
                                    (item) => DropdownMenuItem(
                                      value: item.reference,
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
                              onChanged: (value) {
                                setState(() {});
                                person.studyYear = value;
                                FocusScope.of(context).nextFocus();
                              },
                              decoration: const InputDecoration(
                                labelText: 'السنة الدراسية',
                              ),
                            ),
                          );
                        } else {
                          return const SizedBox(width: 1, height: 1);
                        }
                      },
                    ),
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    child: TapableFormField<JsonRef?>(
                      initialValue: person.classId,
                      onTap: _selectClass,
                      validator: (c) => person.services.isEmpty && c == null
                          ? 'برجاء ادخال الفصل او خدمة واحدة على الأقل'
                          : null,
                      decoration: (context, state) => InputDecoration(
                        labelText: 'داخل فصل',
                        errorText: state.errorText,
                        errorMaxLines: 2,
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.delete),
                          tooltip: 'ازالة الفصل المحدد',
                          onPressed: () {
                            setState(() => person.classId = null);
                          },
                        ),
                      ),
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
                  ),
                  TapableFormField<List<JsonRef>>(
                    labelText: 'الخدمات المشارك بها',
                    initialValue: person.services,
                    onTap: _selectServices,
                    validator: (s) =>
                        (s?.isEmpty ?? true) && person.classId == null
                            ? 'برجاء ادخال الفصل او خدمة واحدة على الأقل'
                            : null,
                    builder: (context, state) {
                      return state.value != null && state.value!.isNotEmpty
                          ? FutureBuilder<List<String>>(
                              future: Future.wait(
                                state.value!.take(2).map(
                                      (s) async =>
                                          Service.fromDoc(
                                            await s.get(dataSource),
                                          )?.name ??
                                          '',
                                    ),
                              ),
                              builder: (context, servicesSnapshot) {
                                if (!servicesSnapshot.hasData)
                                  return const LinearProgressIndicator();

                                if (state.value!.length > 2)
                                  return Text(
                                    servicesSnapshot.requireData
                                            .take(2)
                                            .join(' و') +
                                        'و ' +
                                        (state.value!.length - 2).toString() +
                                        ' أخرين',
                                  );

                                return Text(
                                    servicesSnapshot.requireData.join(' و'));
                              },
                            )
                          : const Text('لا يوجد خدمات');
                    },
                  ),
                  if (person.classId == null || widget.person is User)
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      child: FormField<bool>(
                        initialValue: person.gender,
                        builder: (state) => InputDecorator(
                          decoration: InputDecoration(
                              labelText: 'النوع', errorText: state.errorText),
                          child: Row(
                            children: [
                              ...[true, false]
                                  .map(
                                    (i) => Expanded(
                                      child: Row(
                                        children: [
                                          Radio<bool>(
                                            value: i,
                                            groupValue: person.gender,
                                            onChanged: (v) => setState(
                                                () => person.gender = v!),
                                          ),
                                          GestureDetector(
                                            onTap: () => setState(
                                                () => person.gender = i),
                                            child: Text(i ? 'ذكر' : 'أنثى'),
                                          )
                                        ],
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ],
                          ),
                        ),
                        onSaved: (value) => person.gender = value!,
                        validator: (value) =>
                            person.classId == null && value == null
                                ? 'يجب اختيار النوع'
                                : null,
                      ),
                    ),
                  if (person.gender)
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      child: FormField<bool>(
                        initialValue: person.isShammas,
                        builder: (state) => InputDecorator(
                          decoration: InputDecoration(
                              labelText: 'شماس', errorText: state.errorText),
                          child: Row(
                            children: [
                              ...[true, false]
                                  .map(
                                    (i) => Expanded(
                                      child: Row(
                                        children: [
                                          Radio<bool>(
                                            value: i,
                                            groupValue: person.isShammas,
                                            onChanged: (v) => setState(
                                                () => person.isShammas = v!),
                                          ),
                                          GestureDetector(
                                            onTap: () => setState(
                                                () => person.isShammas = i),
                                            child: Text(i ? 'نعم' : 'لا'),
                                          )
                                        ],
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ],
                          ),
                        ),
                        onSaved: (value) => person.isShammas = value!,
                      ),
                    ),
                  if (person.gender && person.isShammas)
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      child: DropdownButtonFormField<String>(
                        value: person.shammasLevel,
                        isExpanded: true,
                        items: [
                          'ابصالتس',
                          'اغأناغنوستيس',
                          'أيبودياكون',
                          'دياكون',
                          'أرشيدياكون'
                        ]
                            .map(
                              (item) => DropdownMenuItem(
                                value: item,
                                child: Text(item),
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
                        onChanged: (value) {
                          person.shammasLevel = value;
                          FocusScope.of(context).nextFocus();
                        },
                        decoration: const InputDecoration(
                          labelText: 'رتبة الشموسية',
                        ),
                      ),
                    ),
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    child: TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'العنوان',
                      ),
                      keyboardType: TextInputType.streetAddress,
                      autofillHints: const [AutofillHints.fullStreetAddress],
                      initialValue: person.address,
                      textInputAction: TextInputAction.newline,
                      maxLines: null,
                      onChanged: (v) => person.address = v,
                      onFieldSubmitted: _nextFocus,
                      validator: (value) {
                        return null;
                      },
                    ),
                  ),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.map),
                    label: const Text('تعديل مكان المنزل على الخريطة'),
                    onPressed: _editLocation,
                  ),
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisSize: MainAxisSize.max,
                      children: <Widget>[
                        Expanded(
                          child: FutureBuilder<JsonQuery>(
                            key: ValueKey(person.school),
                            future: School.getAllForUser(),
                            builder: (context, data) {
                              if (data.hasData) {
                                return Container(
                                  margin:
                                      const EdgeInsets.symmetric(vertical: 8),
                                  child: DropdownButtonFormField<JsonRef?>(
                                    isExpanded: true,
                                    value: person.school,
                                    items: data.data!.docs
                                        .map(
                                          (item) => DropdownMenuItem(
                                            value: item.reference,
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
                                    onChanged: (value) {
                                      person.school = value;
                                      FocusScope.of(context).nextFocus();
                                    },
                                    decoration: const InputDecoration(
                                      labelText: 'المدرسة',
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
                  ),
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisSize: MainAxisSize.max,
                      children: <Widget>[
                        Expanded(
                          child: FutureBuilder<JsonQuery>(
                            key: ValueKey(person.church),
                            future: Church.getAllForUser(),
                            builder: (context, data) {
                              if (data.hasData) {
                                return Container(
                                  margin:
                                      const EdgeInsets.symmetric(vertical: 8),
                                  child: DropdownButtonFormField<JsonRef?>(
                                    value: person.church,
                                    isExpanded: true,
                                    items: data.data!.docs
                                        .map(
                                          (item) => DropdownMenuItem(
                                            value: item.reference,
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
                                    onChanged: (value) {
                                      person.church = value;
                                      FocusScope.of(context).nextFocus();
                                    },
                                    decoration: const InputDecoration(
                                      labelText: 'الكنيسة',
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
                  ),
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: FutureBuilder<JsonQuery>(
                            key: ValueKey(person.cFather),
                            future: Father.getAllForUser(),
                            builder: (context, data) {
                              if (data.hasData) {
                                return DropdownButtonFormField<JsonRef?>(
                                  value: person.cFather,
                                  isExpanded: true,
                                  items: data.data!.docs
                                      .map(
                                        (item) => DropdownMenuItem(
                                          value: item.reference,
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
                                  onChanged: (value) {
                                    person.cFather = value;
                                    FocusScope.of(context).nextFocus();
                                  },
                                  decoration: const InputDecoration(
                                    labelText: 'أب الاعتراف',
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
                    labelText: 'تاريخ أخر افتقاد',
                    initialValue: person.lastVisit,
                    onTap: (state) async {
                      state.didChange(
                        person.lastVisit = await _selectDate(
                              'تاريخ أخر افتقاد',
                              state.value?.toDate() ?? DateTime.now(),
                            ) ??
                            state.value,
                      );
                    },
                    decoration: (context, state) => InputDecoration(
                      labelText: 'تاريخ أخر افتقاد',
                      errorText: state.errorText,
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.delete),
                        tooltip: 'حذف التاريخ',
                        onPressed: () {
                          state.didChange(person.lastVisit = null);
                        },
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
                    ),
                    builder: (context, state) {
                      return state.value != null
                          ? Text(DateFormat('yyyy/M/d')
                              .format(state.value!.toDate()))
                          : null;
                    },
                    validator: (_) => null,
                  ),
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    child: TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'ملاحظات',
                      ),
                      textInputAction: TextInputAction.newline,
                      initialValue: person.notes,
                      onChanged: (v) => person.notes = v,
                      maxLines: null,
                      validator: (value) => null,
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
        onPressed: _save,
        child: const Icon(Icons.save),
      ),
    );
  }

  void _editLocation() async {
    final oldPoint = person.location != null
        ? GeoPoint(person.location!.latitude, person.location!.longitude)
        : null;
    final rslt = await navigator.currentState!.push(
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
    _nextFocus();
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
    _nextFocus();
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
      if (_form.currentState!.validate() &&
          (person.classId != null || person.services.isNotEmpty)) {
        _form.currentState!.save();
        scaffoldMessenger.currentState!.showSnackBar(
          const SnackBar(
            content: Text('جار الحفظ...'),
            duration: Duration(minutes: 1),
          ),
        );
        final update = person.id != 'null' || widget.person is User;

        if (!update) {
          person.ref = FirebaseFirestore.instance.collection('Persons').doc();
        }

        if (widget.person is! User) {
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
        }

        person.lastEdit = auth.FirebaseAuth.instance.currentUser!.uid;

        if (person.classId == null &&
            person.classId != widget.person?.classId) {
          person
            ..isShammas = person.gender ? person.isShammas : false
            ..shammasLevel = person.gender ? person.shammasLevel : null;
        } else if (widget.person is! User &&
            (person.classId != null ||
                person.classId != widget.person?.classId)) {
          final class$ = Class.fromDoc(await person.classId!.get(dataSource))!;
          person
            ..gender = class$.gender
            ..studyYear = class$.studyYear
            ..isShammas = class$.gender ? person.isShammas : false
            ..shammasLevel = class$.gender ? person.shammasLevel : null;
        }

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
        if (person.classId != null || person.services.isNotEmpty)
          scaffoldMessenger.currentState!.showSnackBar(
            const SnackBar(
              content: Text('يرجى التحقق من الييانات المدخلة'),
            ),
          );
        await showDialog(
          context: context,
          builder: (context) => const AlertDialog(
            title: Text('بيانات غير كاملة'),
            content: Text(
                'يجب تحديد الفصل او اختيار خدمة واحدة مع تحديد السنة الدراسية على الأقل'),
          ),
        );
      }
    } catch (err, stack) {
      await Sentry.captureException(err,
          stackTrace: stack,
          withScope: (scope) =>
              scope.setTag('LasErrorIn', '_EditPersonState._save'));
      scaffoldMessenger.currentState!.hideCurrentSnackBar();
      scaffoldMessenger.currentState!.showSnackBar(SnackBar(
        content: Text(
          err.toString(),
        ),
        duration: const Duration(seconds: 7),
      ));
    }
  }

  void _selectClass(FormFieldState<JsonRef?> state) async {
    final controller = ServicesListController<Class>(
      tap: (class$) {
        navigator.currentState!.pop();
        setState(() {
          person
            ..classId = class$.ref
            ..gender = class$.gender
            ..isShammas = class$.gender ? person.isShammas : false;
        });
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
                SearchFilters(
                  Class,
                  options: controller,
                  orderOptions: BehaviorSubject<OrderOptions>.seeded(
                      const OrderOptions()),
                  textStyle: Theme.of(context).textTheme.bodyText2,
                ),
                Expanded(
                  child: ServicesList<Class>(
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
    _nextFocus();
  }

  Future<Timestamp?> _selectDate(String helpText, DateTime initialDate) async {
    final picked = await showDatePicker(
        helpText: helpText,
        locale: const Locale('ar', 'EG'),
        context: context,
        initialDate: initialDate,
        firstDate: DateTime(1500),
        lastDate: DateTime.now());
    if (picked != null && picked != initialDate) {
      _nextFocus();
      return Timestamp.fromDate(picked);
    }
    return null;
  }

  Future<void> _selectServices(FormFieldState<List<JsonRef>> state) async {
    state.didChange(
      person.services = await navigator.currentState!.push(
            MaterialPageRoute(
              builder: (context) {
                return FutureBuilder<Map<String, Service>>(
                  future: () async {
                    return {
                      for (final s in await Future.wait(
                        person.services.map(
                          (e) async => Service.fromDoc(await e.get(dataSource)),
                        ),
                      ))
                        if (s != null) s.id: s
                    };
                  }(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData)
                      return const Center(child: CircularProgressIndicator());

                    return Provider<DataObjectListController<Service>>(
                      create: (_) => DataObjectListController<Service>(
                        selectionMode: true,
                        itemsStream: FirebaseFirestore.instance
                            .collection('Services')
                            .orderBy('Name')
                            .snapshots()
                            .map(
                              (value) =>
                                  value.docs.map(Service.fromQueryDoc).toList(),
                            ),
                        selected: snapshot.requireData,
                      ),
                      dispose: (context, c) => c.dispose(),
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
                                textStyle:
                                    Theme.of(context).textTheme.bodyText2),
                          ),
                          body: const DataObjectList<Service>(
                            disposeController: false,
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ) ??
          person.services,
    );
    _nextFocus();
  }

  Future<void> _selectImage() async {
    final source = await showDialog(
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

    final selectedImage = await ImagePicker()
        .pickImage(source: source ? ImageSource.camera : ImageSource.gallery);
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
