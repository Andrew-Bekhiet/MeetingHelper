import 'dart:async';
import 'dart:io';

import 'package:churchdata_core/churchdata_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:meetinghelper/controllers.dart';
import 'package:meetinghelper/models.dart';
import 'package:meetinghelper/repositories.dart';
import 'package:meetinghelper/utils/globals.dart';
import 'package:meetinghelper/utils/helpers.dart';
import 'package:meetinghelper/views.dart';
import 'package:meetinghelper/widgets.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:rxdart/rxdart.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:tinycolor2/tinycolor2.dart';

class EditPerson extends StatefulWidget {
  final Person? person;

  const EditPerson({super.key, this.person});

  @override
  _EditPersonState createState() => _EditPersonState();
}

class _EditPersonState extends State<EditPerson> with TickerProviderStateMixin {
  String? changedImage;
  bool deletePhoto = false;
  bool _servicesHaveRange = true;
  final GlobalKey<FormState> _form = GlobalKey<FormState>();

  late final AnimationController _addressAnimationController =
      AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
  );

  late Person person;

  void _nextFocus([_]) {
    FocusScope.of(context).nextFocus();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return <Widget>[
            SliverAppBar(
              actions: <Widget>[
                if (person.id != 'null' && (person is! User))
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
                        Icon(
                          Icons.photo_camera,
                          color: IconTheme.of(context).color,
                        ),
                      ],
                    ),
                  ),
                  onPressed: _selectImage,
                  tooltip: 'اختيار صورة',
                ),
              ],
              backgroundColor: person.color != null
                  ? (Theme.of(context).brightness == Brightness.light
                      ? person.color!.lighten()
                      : person.color!.darken())
                  : null,
              //title: Text(widget.me.name),
              expandedHeight: 250.0,
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
                      ? PhotoObjectWidget(person, circleCrop: false)
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
                      onChanged: (value) =>
                          person = person.copyWith.name(value),
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
                      onChanged: (v) => person = person.copyWith.phone(v),
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
                        onChanged: (v) =>
                            person = person.copyWith.fatherPhone(v),
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
                        onChanged: (v) =>
                            person = person.copyWith.motherPhone(v),
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
                                        hintText: 'مثال: رقم المنزل',
                                      ),
                                    ),
                                  ),
                                );
                                if (rslt == 'delete') {
                                  person = person.copyWith
                                      .phones(person.phones..remove(e.key));
                                  setState(() {});
                                } else if (rslt != null) {
                                  person = person.copyWith
                                      .phones(person.phones..remove(e.key));
                                  person = person.copyWith.phones(
                                    {...person.phones, name.text: e.value},
                                  );
                                  setState(() {});
                                }
                              },
                            ),
                          ),
                          keyboardType: TextInputType.phone,
                          autofillHints: const [AutofillHints.telephoneNumber],
                          initialValue: e.value,
                          onChanged: (s) => person = person.copyWith
                              .phones({...person.phones, e.key: s}),
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
                                ),
                              ],
                              title: const Text('اسم الهاتف'),
                              content: TextField(
                                controller: name,
                                decoration: const InputDecoration(
                                  hintText: 'مثال: رقم المنزل',
                                ),
                              ),
                            ),
                          ) !=
                          null) {
                        setState(
                          () => person = person.copyWith
                              .phones({...person.phones, name.text: ''}),
                        );
                      }
                    },
                  ),
                  TappableFormField<DateTime?>(
                    labelText: 'تاريخ الميلاد',
                    initialValue: person.birthDate,
                    onTap: (state) async {
                      person = person.copyWith.birthDate(
                        await _selectDate(
                              'تاريخ الميلاد',
                              state.value ?? DateTime.now(),
                            ) ??
                            state.value,
                      );
                      state.didChange(person.birthDate);
                    },
                    decoration: (context, state) => InputDecoration(
                      labelText: 'تاريخ الميلاد',
                      errorText: state.errorText,
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.delete),
                        tooltip: 'حذف التاريخ',
                        onPressed: () {
                          person = person.copyWith.birthDate(null);
                          state.didChange(person.birthDate);
                        },
                      ),
                    ),
                    builder: (context, state) {
                      return state.value != null
                          ? Text(DateFormat('yyyy/M/d').format(state.value!))
                          : null;
                    },
                    validator: (_) => null,
                  ),
                  if (person.classId == null)
                    FutureBuilder<List<StudyYear>>(
                      key: ValueKey((person.studyYear, person.services)),
                      future: StudyYear.getAll().first,
                      builder: (conext, data) {
                        if (data.hasData) {
                          return Container(
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            child: TappableFormField<JsonRef?>(
                              validator: (v) {
                                if (person.classId == null &&
                                    v == null &&
                                    _servicesHaveRange) {
                                  return 'هذا الحقل مطلوب';
                                } else {
                                  return null;
                                }
                              },
                              initialValue: person.studyYear,
                              builder: (context, state) => state.value != null
                                  ? FutureBuilder<String>(
                                      future: state.value?.get().then(
                                            (doc) =>
                                                StudyYear.fromDoc(doc).name,
                                          ),
                                      builder: (context, snapshot) {
                                        if (snapshot.hasData) {
                                          return Text(snapshot.data!);
                                        } else {
                                          return const Text('');
                                        }
                                      },
                                    )
                                  : null,
                              onTap: (value) async {
                                final selected =
                                    await showModalBottomSheet<StudyYear?>(
                                  context: context,
                                  builder: (context) =>
                                      MiniModelList<StudyYear>(
                                    title: 'السنة الدراسية',
                                    transformer: StudyYear.fromDoc,
                                    showSearch: true,
                                    add: (context) => studyYearTap(
                                      context,
                                      StudyYear.createNew(),
                                      true,
                                      canDelete: false,
                                    ),
                                    modify: (context, v, _) =>
                                        Navigator.of(context).pop(v),
                                    collection: GetIt.I<DatabaseRepository>()
                                        .collection('StudyYears'),
                                    completer: (q) => q.orderBy('Grade'),
                                  ),
                                );

                                if (selected == null) return;

                                person =
                                    person.copyWith.studyYear(selected.ref);

                                setState(() {});
                                FocusScope.of(context).nextFocus();
                              },
                              decoration: (context, state) => InputDecoration(
                                labelText: 'السنة الدراسية',
                                errorText: state.errorText,
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
                    child: TappableFormField<JsonRef?>(
                      initialValue: person.classId,
                      onTap: _selectClass,
                      validator: (c) => person.services.isEmpty && c == null
                          ? 'برجاء ادخال الفصل او خدمة واحدة على الأقل'
                          : null,
                      decoration: (context, state) => InputDecoration(
                        labelText: 'داخل فصل',
                        errorText: state.errorText,
                        errorMaxLines: 2,
                        suffixIcon: state.value != null
                            ? IconButton(
                                icon: const Icon(Icons.delete),
                                tooltip: 'ازالة الفصل المحدد',
                                onPressed: () {
                                  setState(
                                    () {
                                      person = person.copyWith.classId(null);
                                      state.didChange(null);
                                    },
                                  );
                                },
                              )
                            : null,
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
                  TappableFormField<List<JsonRef>>(
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
                                            await s.get(),
                                          )?.name ??
                                          '',
                                    ),
                              ),
                              builder: (context, servicesSnapshot) {
                                if (!servicesSnapshot.hasData) {
                                  return const LinearProgressIndicator();
                                }

                                if (state.value!.length > 2) {
                                  return Text(
                                    servicesSnapshot.requireData
                                            .take(2)
                                            .join(' و') +
                                        'و ' +
                                        (state.value!.length - 2).toString() +
                                        ' أخرين',
                                  );
                                }

                                return Text(
                                  servicesSnapshot.requireData.join(' و'),
                                );
                              },
                            )
                          : const Text('لا يوجد خدمات');
                    },
                  ),
                  FutureBuilder<bool>(
                    key: ValueKey(person.classId),
                    future: () async {
                      return widget.person is User ||
                          (await person.classId?.get())?.data()?['Gender'] ==
                              null;
                    }(),
                    builder: (context, showGender) {
                      if (widget.person is User || (showGender.data ?? false)) {
                        return Container(
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          child: FormField<bool>(
                            initialValue: person.gender,
                            builder: (state) => InputDecorator(
                              decoration: InputDecoration(
                                labelText: 'النوع',
                                errorText: state.errorText,
                              ),
                              child: Row(
                                children: [
                                  ...[true, false].map(
                                    (i) => Expanded(
                                      child: Row(
                                        children: [
                                          Radio<bool>(
                                            value: i,
                                            groupValue: person.gender,
                                            onChanged: (v) => setState(
                                              () => person =
                                                  person.copyWith.gender(v!),
                                            ),
                                          ),
                                          GestureDetector(
                                            onTap: () => setState(
                                              () => person =
                                                  person.copyWith.gender(i),
                                            ),
                                            child: Text(i ? 'ذكر' : 'أنثى'),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            onSaved: (value) =>
                                person = person.copyWith.gender(value!),
                            validator: (value) =>
                                person.classId == null && value == null
                                    ? 'يجب اختيار النوع'
                                    : null,
                          ),
                        );
                      }
                      return const SizedBox();
                    },
                  ),
                  if (person.gender)
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      child: FormField<bool>(
                        initialValue: person.isShammas,
                        builder: (state) => InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'شماس',
                            errorText: state.errorText,
                          ),
                          child: Row(
                            children: [
                              ...[true, false].map(
                                (i) => Expanded(
                                  child: Row(
                                    children: [
                                      Radio<bool>(
                                        value: i,
                                        groupValue: person.isShammas,
                                        onChanged: (v) => setState(
                                          () => person =
                                              person.copyWith.isShammas(v!),
                                        ),
                                      ),
                                      GestureDetector(
                                        onTap: () => setState(
                                          () => person =
                                              person.copyWith.isShammas(i),
                                        ),
                                        child: Text(i ? 'نعم' : 'لا'),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        onSaved: (value) =>
                            person = person.copyWith.isShammas(value!),
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
                          'أرشيدياكون',
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
                              child: Text(''),
                            ),
                          ),
                        onChanged: (value) {
                          person = person.copyWith.shammasLevel(value);
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
                      onChanged: (v) {
                        person = person.copyWith.address(v);

                        if (person.address != widget.person?.address) {
                          _addressAnimationController.forward();
                        } else if (person.address == widget.person?.address) {
                          _addressAnimationController.reverse();
                        }
                      },
                      onFieldSubmitted: _nextFocus,
                      validator: (value) {
                        return null;
                      },
                    ),
                  ),
                  SizeTransition(
                    sizeFactor: _addressAnimationController,
                    child: const Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.all(Radius.circular(15)),
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(12),
                        child: Row(
                          spacing: 10,
                          children: [
                            Icon(
                              Icons.warning,
                              color: Colors.orange,
                              size: 30,
                            ),
                            Expanded(
                              child: Text(
                                'برجاء تحديث الموقع على الخريطة إذا قمت بتغيير العنوان',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 20),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.map),
                    label: const Text('تعديل موقع المنزل على الخريطة'),
                    onPressed: _editLocation,
                  ),
                  FutureBuilder<bool>(
                    key: ValueKey(person.studyYear),
                    future: () async {
                      final studyYear = await (person.studyYear ??
                              (await person.classId
                                      ?.get()
                                      // ignore: invalid_return_type_for_catch_error
                                      .catchError((_) => null))
                                  ?.data()?['StudyYear'] as JsonRef?)
                          ?.get();

                      return studyYear?.data()?['IsCollegeYear']?.toString() ==
                          'true';
                    }(),
                    builder: (context, data) {
                      if (data.hasError) {
                        return ErrorWidget(data.error!);
                      } else if (data.hasData) {
                        if (data.requireData) {
                          return Container(
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            child: TappableFormField<JsonRef?>(
                              initialValue: person.college,
                              builder: (context, state) => state.value != null
                                  ? FutureBuilder<String>(
                                      future: state.value?.get().then(
                                            (doc) => College.fromDoc(doc).name,
                                          ),
                                      builder: (context, snapshot) {
                                        if (snapshot.hasData) {
                                          return Text(snapshot.data!);
                                        } else {
                                          return const Text('');
                                        }
                                      },
                                    )
                                  : null,
                              onTap: (state) async {
                                final selected =
                                    await showModalBottomSheet<College?>(
                                  context: context,
                                  builder: (context) => MiniModelList<College>(
                                    title: 'الكلية',
                                    transformer: College.fromDoc,
                                    showSearch: true,
                                    modify: (context, v, _) =>
                                        Navigator.of(context).pop(v),
                                    collection: GetIt.I<DatabaseRepository>()
                                        .collection('Colleges'),
                                  ),
                                );

                                if (selected != null) {
                                  person =
                                      person.copyWith.college(selected.ref);
                                  state.didChange(selected.ref);
                                  FocusScope.of(context).nextFocus();
                                }
                              },
                              validator: (_) => null,
                              decoration: (context, state) => InputDecoration(
                                labelText: 'الكلية',
                                errorText: state.errorText,
                              ),
                            ),
                          );
                        } else {
                          return Container(
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            child: TappableFormField<JsonRef?>(
                              initialValue: person.school,
                              builder: (context, state) => state.value != null
                                  ? FutureBuilder<String>(
                                      future: state.value?.get().then(
                                            (doc) => School.fromDoc(doc).name,
                                          ),
                                      builder: (context, snapshot) {
                                        if (snapshot.hasData) {
                                          return Text(snapshot.data!);
                                        } else {
                                          return const Text('');
                                        }
                                      },
                                    )
                                  : null,
                              onTap: (state) async {
                                final selected =
                                    await showModalBottomSheet<School?>(
                                  context: context,
                                  builder: (context) => MiniModelList<School>(
                                    title: 'المدرسة',
                                    transformer: School.fromDoc,
                                    showSearch: true,
                                    modify: (context, v, _) =>
                                        Navigator.of(context).pop(v),
                                    collection: GetIt.I<DatabaseRepository>()
                                        .collection('Schools'),
                                  ),
                                );

                                if (selected != null) {
                                  person = person.copyWith.school(selected.ref);
                                  state.didChange(selected.ref);
                                  FocusScope.of(context).nextFocus();
                                }
                              },
                              validator: (_) => null,
                              decoration: (context, state) => InputDecoration(
                                labelText: 'المدرسة',
                                errorText: state.errorText,
                              ),
                            ),
                          );
                        }
                      }
                      return const LinearProgressIndicator();
                    },
                  ),
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    child: TappableFormField<JsonRef?>(
                      initialValue: person.church,
                      builder: (context, state) => state.value != null
                          ? FutureBuilder<String>(
                              future: state.value?.get().then(
                                    (doc) => Church.fromDoc(doc).name,
                                  ),
                              builder: (context, snapshot) {
                                if (snapshot.hasData) {
                                  return Text(snapshot.data!);
                                } else {
                                  return const Text('');
                                }
                              },
                            )
                          : null,
                      onTap: (state) async {
                        final selected = await showModalBottomSheet<Church?>(
                          context: context,
                          builder: (context) => MiniModelList<Church>(
                            title: 'الكنيسة',
                            transformer: Church.fromDoc,
                            showSearch: true,
                            modify: (context, v, _) =>
                                Navigator.of(context).pop(v),
                            add: (context) => churchTap(
                              context,
                              Church.createNew(),
                              true,
                              canDelete: false,
                            ),
                            collection: GetIt.I<DatabaseRepository>()
                                .collection('Churches'),
                          ),
                        );

                        if (selected != null) {
                          person = person.copyWith.church(selected.ref);
                          state.didChange(selected.ref);
                          FocusScope.of(context).nextFocus();
                        }
                      },
                      validator: (_) => null,
                      decoration: (context, state) => InputDecoration(
                        labelText: 'الكنيسة',
                        errorText: state.errorText,
                      ),
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    child: TappableFormField<JsonRef?>(
                      initialValue: person.cFather,
                      builder: (context, state) => state.value != null
                          ? FutureBuilder<String>(
                              future: state.value?.get().then(
                                    (doc) => Father.fromDoc(doc).name,
                                  ),
                              builder: (context, snapshot) {
                                if (snapshot.hasData) {
                                  return Text(snapshot.data!);
                                } else {
                                  return const Text('');
                                }
                              },
                            )
                          : null,
                      onTap: (state) async {
                        final selected = await showModalBottomSheet<Father?>(
                          context: context,
                          builder: (context) => MiniModelList<Father>(
                            title: 'أب الاعتراف',
                            transformer: Father.fromDoc,
                            showSearch: true,
                            modify: (context, v, _) =>
                                Navigator.of(context).pop(v),
                            add: (context) => fatherTap(
                              context,
                              Father.createNew(),
                              true,
                              canDelete: false,
                            ),
                            collection: GetIt.I<DatabaseRepository>()
                                .collection('Fathers'),
                          ),
                        );

                        if (selected != null) {
                          person = person.copyWith.cFather(selected.ref);
                          state.didChange(selected.ref);
                          FocusScope.of(context).nextFocus();
                        }
                      },
                      validator: (_) => null,
                      decoration: (context, state) => InputDecoration(
                        labelText: 'أب الاعتراف',
                        errorText: state.errorText,
                      ),
                    ),
                  ),
                  TappableFormField<DateTime?>(
                    labelText: 'تاريخ أخر تناول',
                    initialValue: person.lastTanawol,
                    onTap: (state) async {
                      person = person.copyWith.lastTanawol(
                        await _selectDate(
                              'تاريخ أخر تناول',
                              state.value ?? DateTime.now(),
                            ) ??
                            state.value,
                      );
                      state.didChange(person.lastTanawol);
                    },
                    decoration: (context, state) => InputDecoration(
                      labelText: 'تاريخ أخر تناول',
                      errorText: state.errorText,
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.delete),
                        tooltip: 'حذف التاريخ',
                        onPressed: () {
                          person = person.copyWith.lastTanawol(null);
                          state.didChange(null);
                        },
                      ),
                    ),
                    builder: (context, state) {
                      return state.value != null
                          ? Text(DateFormat('yyyy/M/d').format(state.value!))
                          : null;
                    },
                    validator: (_) => null,
                  ),
                  TappableFormField<DateTime?>(
                    labelText: 'تاريخ أخر اعتراف',
                    initialValue: person.lastConfession,
                    onTap: (state) async {
                      person = person.copyWith.lastConfession(
                        await _selectDate(
                              'تاريخ أخر اعتراف',
                              state.value ?? DateTime.now(),
                            ) ??
                            state.value,
                      );
                      state.didChange(person.lastConfession);
                    },
                    decoration: (context, state) => InputDecoration(
                      labelText: 'تاريخ أخر اعتراف',
                      errorText: state.errorText,
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.delete),
                        tooltip: 'حذف التاريخ',
                        onPressed: () {
                          person = person.copyWith.lastConfession(null);
                          state.didChange(person.lastConfession);
                        },
                      ),
                    ),
                    builder: (context, state) {
                      return state.value != null
                          ? Text(DateFormat('yyyy/M/d').format(state.value!))
                          : null;
                    },
                    validator: (_) => null,
                  ),
                  TappableFormField<DateTime?>(
                    labelText: 'تاريخ حضور أخر قداس',
                    initialValue: person.lastKodas,
                    onTap: (state) async {
                      person = person.copyWith.lastKodas(
                        await _selectDate(
                              'تاريخ حضور أخر قداس',
                              state.value ?? DateTime.now(),
                            ) ??
                            state.value,
                      );
                      state.didChange(person.lastKodas);
                    },
                    decoration: (context, state) => InputDecoration(
                      labelText: 'تاريخ حضور أخر قداس',
                      errorText: state.errorText,
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.delete),
                        tooltip: 'حذف التاريخ',
                        onPressed: () {
                          person = person.copyWith.lastKodas(null);
                          state.didChange(person.lastKodas);
                        },
                      ),
                    ),
                    builder: (context, state) {
                      return state.value != null
                          ? Text(DateFormat('yyyy/M/d').format(state.value!))
                          : null;
                    },
                    validator: (_) => null,
                  ),
                  TappableFormField<DateTime?>(
                    labelText: 'تاريخ أخر افتقاد',
                    initialValue: person.lastVisit,
                    onTap: (state) async {
                      person = person.copyWith.lastVisit(
                        await _selectDate(
                              'تاريخ أخر افتقاد',
                              state.value ?? DateTime.now(),
                            ) ??
                            state.value,
                      );
                      state.didChange(person.lastVisit);
                    },
                    decoration: (context, state) => InputDecoration(
                      labelText: 'تاريخ أخر افتقاد',
                      errorText: state.errorText,
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.delete),
                        tooltip: 'حذف التاريخ',
                        onPressed: () {
                          person = person.copyWith.lastVisit(null);
                          state.didChange(person.lastVisit);
                        },
                      ),
                    ),
                    builder: (context, state) {
                      return state.value != null
                          ? Text(DateFormat('yyyy/M/d').format(state.value!))
                          : null;
                    },
                    validator: (_) => null,
                  ),
                  TappableFormField<DateTime?>(
                    labelText: 'تاريخ أخر مكالمة',
                    initialValue: person.lastCall,
                    onTap: (state) async {
                      person = person.copyWith.lastCall(
                        await _selectDate(
                              'تاريخ أخر مكالمة',
                              state.value ?? DateTime.now(),
                            ) ??
                            state.value,
                      );
                      state.didChange(person.lastCall);
                    },
                    decoration: (context, state) => InputDecoration(
                      labelText: 'تاريخ أخر مكالمة',
                      errorText: state.errorText,
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.delete),
                        tooltip: 'حذف التاريخ',
                        onPressed: () {
                          person = person.copyWith.lastCall(null);
                          state.didChange(person.lastCall);
                        },
                      ),
                    ),
                    builder: (context, state) {
                      return state.value != null
                          ? Text(DateFormat('yyyy/M/d').format(state.value!))
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
                      onChanged: (v) => person = person.copyWith.notes(v),
                      maxLines: null,
                      validator: (value) => null,
                    ),
                  ),
                  ElevatedButton.icon(
                    style: person.color != Colors.transparent
                        ? ElevatedButton.styleFrom(
                            backgroundColor:
                                Theme.of(context).brightness == Brightness.light
                                    ? person.color?.lighten()
                                    : person.color?.darken(),
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

  Future<void> _editLocation() async {
    final rslt = await navigator.currentState!.push(
      MaterialPageRoute(
        builder: (context) => LocationMapView(
          person: person,
          editable: true,
        ),
      ),
    );
    if (rslt == false) {
      person = person.copyWith.location(null);
    } else if (rslt != null) {
      person = person.copyWith.location((rslt as LatLng?)?.toGeoPoint());
    }
    unawaited(_addressAnimationController.reverse());
    _nextFocus();
  }

  @override
  void initState() {
    super.initState();
    person = (widget.person ?? Person.empty()).copyWith();

    _setServicesHaveRange();
  }

  Future<void> _setServicesHaveRange() async {
    for (final s in person.services) {
      final service = await s.get();
      final service$ = Service.fromDoc(service);

      if (service$ == null) continue;

      if (service$.studyYearRange != null) {
        _servicesHaveRange = true;
        return;
      }
    }

    _servicesHaveRange = false;
  }

  Future<void> _selectColor() async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        actions: [
          TextButton(
            onPressed: () {
              navigator.currentState!.pop();
              setState(() {
                person = person.copyWith.color(Colors.transparent);
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
              person = person.copyWith.color(color);
            });
          },
        ),
      ),
    );
    _nextFocus();
  }

  Future<void> _delete() async {
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
      if ((await Connectivity().checkConnectivity()).any(
        (c) =>
            c == ConnectivityResult.mobile ||
            c == ConnectivityResult.wifi ||
            c == ConnectivityResult.ethernet,
      )) {
        await person.ref.delete();
      } else {
        // ignore: unawaited_futures
        person.ref.delete();
      }
      navigator.currentState!.pop('deleted');
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
        final update = await person.ref
            .get()
            .then((s) => s.exists)
            .catchError((_) => false);

        if (person.id == 'null' && !update) {
          person = person.copyWith
              .ref(GetIt.I<DatabaseRepository>().collection('Persons').doc());
        }

        person = person.copyWith
            .lastEdit(LastEdit(User.instance.uid, DateTime.now()));

        if (person.classId == null &&
            person.classId != widget.person?.classId) {
          person = person.copyWith
              .isShammas(person.gender ? person.isShammas : false)
              .copyWith
              .shammasLevel(person.gender ? person.shammasLevel : null);
        } else if (widget.person is! User &&
            (person.classId != null ||
                person.classId != widget.person?.classId)) {
          final class$ = Class.fromDoc(await person.classId!.get());

          person = person.copyWith
              .gender(class$.gender ?? person.gender)
              .copyWith
              .studyYear(class$.studyYear)
              .copyWith
              .isShammas(
                (class$.gender ?? person.gender) ? person.isShammas : false,
              )
              .copyWith
              .shammasLevel(
                (class$.gender ?? person.gender) ? person.shammasLevel : null,
              );
        }

        if (widget.person is! User &&
            person.studyYear != null &&
            person.studyYear != widget.person?.studyYear) {
          final isCollegeYear = (await person.studyYear?.get())
                  ?.data()?['IsCollegeYear']
                  ?.toString() ==
              'true';
          person = person.copyWith
              .school(isCollegeYear ? null : person.school)
              .copyWith
              .college(isCollegeYear ? person.college : null);
        }

        final bool isConnected = (await Connectivity().checkConnectivity()).any(
          (c) =>
              c == ConnectivityResult.mobile ||
              c == ConnectivityResult.wifi ||
              c == ConnectivityResult.ethernet,
        );

        final Future<void> saveFuture =
            switch ((person.ref.parent.id, update)) {
          ('UsersData', true) => person.ref.update(
              {
                ...person.toJson(),
                'AllowedUsers': FieldValue.arrayUnion([User.instance.uid]),
              },
            ),
          ('UsersData', false) => person.ref.set(
              {
                ...person.toJson(),
                'AllowedUsers': [User.instance.uid],
              },
            ),
          (_, true) => person.update(old: widget.person?.toJson() ?? {}),
          (_, false) => person.set(),
        };

        if (isConnected) {
          await saveFuture;
        } else {
          unawaited(saveFuture);
        }

        if (widget.person?.ref.parent.id != 'UsersData') {
          if (changedImage != null) {
            await GetIt.I<StorageRepository>()
                .ref()
                .child('PersonsPhotos/${person.id}')
                .putFile(File(changedImage!));

            if (isConnected) {
              await person.copyWith.hasPhoto(true).update(old: person.toJson());
            } else {
              unawaited(
                person.copyWith.hasPhoto(true).update(old: person.toJson()),
              );
            }
          } else if (deletePhoto) {
            await GetIt.I<StorageRepository>()
                .ref()
                .child('PersonsPhotos/${person.id}')
                .delete();
          }
        }

        scaffoldMessenger.currentState!.hideCurrentSnackBar();
        navigator.currentState!.pop(person.ref);
      } else {
        if (person.classId != null || person.services.isNotEmpty) {
          scaffoldMessenger.currentState!.showSnackBar(
            const SnackBar(
              content: Text('يرجى التحقق من الييانات المدخلة'),
            ),
          );
        }
        await showDialog(
          context: context,
          builder: (context) => const AlertDialog(
            title: Text('بيانات غير كاملة'),
            content: Text(
              'يجب تحديد الفصل او اختيار خدمة واحدة مع تحديد السنة الدراسية على الأقل',
            ),
          ),
        );
      }
    } catch (err, stack) {
      await Sentry.captureException(
        err,
        stackTrace: stack,
        withScope: (scope) =>
            scope.setTag('LasErrorIn', '_EditPersonState._save'),
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
  }

  Future<void> _selectClass(FormFieldState<JsonRef?> state) async {
    final controller = ServicesListController<Class>(
      objectsPaginatableStream:
          PaginatableStream.loadAll(stream: MHDatabaseRepo.I.classes.getAll()),
      groupByStream: MHDatabaseRepo.I.services.groupServicesByStudyYearRef,
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
                    const OrderOptions(),
                  ),
                  textStyle: Theme.of(context).textTheme.bodyMedium,
                ),
                Expanded(
                  child: ServicesList<Class>(
                    options: controller,
                    onTap: (class$) {
                      navigator.currentState!.pop();
                      setState(() {
                        person = person.copyWith
                            .classId(class$.ref)
                            .copyWith
                            .studyYear(class$.studyYear)
                            .copyWith
                            .gender(class$.gender ?? person.gender)
                            .copyWith
                            .isShammas(
                              (class$.gender ?? person.gender)
                                  ? person.isShammas
                                  : false,
                            );
                        state.didChange(class$.ref);
                      });
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
                    (snapshot.data?.length ?? 0).toString() + ' خدمة',
                    textAlign: TextAlign.center,
                    strutStyle:
                        StrutStyle(height: IconTheme.of(context).size! / 7.5),
                    style: Theme.of(context).primaryTextTheme.bodyLarge,
                  );
                },
              ),
            ),
            floatingActionButton: User.instance.permissions.write
                ? FloatingActionButton(
                    onPressed: () async {
                      navigator.currentState!.pop();
                      person = person.copyWith.classId(
                        await navigator.currentState!
                                .pushNamed('Data/EditClass') as JsonRef? ??
                            person.classId,
                      );
                      state.didChange(person.classId);
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

  Future<DateTime?> _selectDate(String helpText, DateTime initialDate) async {
    final picked = await showDatePicker(
      helpText: helpText,
      locale: const Locale('ar', 'EG'),
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1500),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != initialDate) {
      _nextFocus();
      return picked;
    }
    return null;
  }

  Future<void> _selectServices(FormFieldState<List<JsonRef>> state) async {
    final selected = await Future.wait(
      (state.value ?? []).map(
        (e) async {
          final data = await e.get();
          if (data.exists) return Service.fromDoc(data);
        },
      ),
    );

    final newSelectedServices =
        await selectServices<Service>(selected.whereType<Service>().toList());

    _servicesHaveRange = newSelectedServices
            ?.whereType<Service>()
            .any((s) => s.studyYearRange != null) ??
        _servicesHaveRange;

    person = person.copyWith.services(
      newSelectedServices?.map((s) => s.ref).toList() ?? person.services,
    );
    state.didChange(person.services);
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
      person = person.copyWith.hasPhoto(false);
      setState(() {});
      return;
    }
    if (source as bool && !(await Permission.camera.request()).isGranted) {
      return;
    }

    final selectedImage = await ImagePicker()
        .pickImage(source: source ? ImageSource.camera : ImageSource.gallery);
    if (selectedImage == null) return;
    changedImage = (await ImageCropper().cropImage(
      sourcePath: selectedImage.path,
      uiSettings: [
        AndroidUiSettings(
          cropStyle: CropStyle.circle,
          toolbarTitle: 'قص الصورة',
          toolbarColor: Theme.of(context).colorScheme.primary,
          initAspectRatio: CropAspectRatioPreset.square,
          lockAspectRatio: false,
        ),
      ],
    ))
        ?.path;
    deletePhoto = false;
    setState(() {});
  }
}
