import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:meetinghelper/utils/globals.dart';
import 'package:meetinghelper/views/form_widgets/tapable_form_field.dart';

import '../models/user.dart';
import '../utils/helpers.dart';

class UpdateUserDataErrorPage extends StatefulWidget {
  const UpdateUserDataErrorPage({Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() => _UpdateUserDataErrorState();
}

class _UpdateUserDataErrorState extends State<UpdateUserDataErrorPage> {
  final user = User.instance;
  final GlobalKey<FormState> _form = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تحديث بيانات المستخدم')),
      body: Form(
        key: _form,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              TapableFormField<Timestamp?>(
                autovalidateMode: AutovalidateMode.onUserInteraction,
                decoration: (context, state) => InputDecoration(
                  errorText: state.errorText,
                  labelText: 'تاريخ أخر تناول',
                  suffixIcon: state.isValid
                      ? const Icon(Icons.done, color: Colors.green)
                      : const Icon(Icons.close, color: Colors.red),
                  border: OutlineInputBorder(
                    borderSide:
                        BorderSide(color: Theme.of(context).primaryColor),
                  ),
                ),
                initialValue: user.lastTanawol,
                onTap: (state) async {
                  state.didChange(await _selectDate(
                          'تاريخ أخر تناول', state.value ?? Timestamp.now()) ??
                      user.lastTanawol);
                },
                builder: (context, state) {
                  return state.value != null
                      ? Text(
                          DateFormat('yyyy/M/d').format(state.value!.toDate()))
                      : null;
                },
                onSaved: (v) => user.lastTanawol = v!,
                validator: (value) => value == null
                    ? 'برجاء اختيار تاريخ أخر تناول'
                    : value.toDate().isBefore(
                            DateTime.now().subtract(const Duration(days: 60)))
                        ? 'يجب أن يكون التاريخ منذ شهرين على الأكثر'
                        : null,
              ),
              TapableFormField<Timestamp?>(
                autovalidateMode: AutovalidateMode.onUserInteraction,
                decoration: (context, state) => InputDecoration(
                  errorText: state.errorText,
                  labelText: 'تاريخ أخر اعتراف',
                  suffixIcon: state.isValid
                      ? const Icon(Icons.done, color: Colors.green)
                      : const Icon(Icons.close, color: Colors.red),
                  border: OutlineInputBorder(
                    borderSide:
                        BorderSide(color: Theme.of(context).primaryColor),
                  ),
                ),
                initialValue: user.lastConfession,
                onTap: (state) async {
                  state.didChange(await _selectDate(
                          'تاريخ أخر اعتراف', state.value ?? Timestamp.now()) ??
                      user.lastConfession);
                },
                builder: (context, state) {
                  return state.value != null
                      ? Text(
                          DateFormat('yyyy/M/d').format(state.value!.toDate()))
                      : null;
                },
                onSaved: (v) => user.lastConfession = v!,
                validator: (value) => value == null
                    ? 'برجاء اختيار تاريخ أخر اعتراف'
                    : value.toDate().isBefore(
                            DateTime.now().subtract(const Duration(days: 60)))
                        ? 'يجب أن يكون التاريخ منذ شهرين على الأكثر'
                        : null,
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: save,
        tooltip: 'حفظ',
        child: const Icon(Icons.save),
      ),
    );
  }

  Future save() async {
    try {
      if (user.lastConfession == null || user.lastTanawol == null) {
        scaffoldMessenger.currentState!.showSnackBar(const SnackBar(
            content: Text('برجاء ادخال تاريخ أخر الاعتراف والتناول')));
        return;
      }
      if (!_form.currentState!.validate()) return;
      _form.currentState!.save();
      scaffoldMessenger.currentState!
          .showSnackBar(const SnackBar(content: Text('جار الحفظ')));
      await FirebaseFunctions.instance
          .httpsCallable('updateUserSpiritData')
          .call({
        'lastConfession': user.lastConfession!.millisecondsSinceEpoch,
        'lastTanawol': user.lastTanawol!.millisecondsSinceEpoch
      });
      navigator.currentState!.pop();
    } catch (err, stkTrace) {
      await showErrorDialog(context, err.toString());
      await FirebaseCrashlytics.instance
          .setCustomKey('LastErrorIn', 'UpdateUserDataError.save');
      await FirebaseCrashlytics.instance.setCustomKey('User', user.uid!);
      await FirebaseCrashlytics.instance.recordError(err, stkTrace);
    }
  }

  Future<Timestamp?> _selectDate(String helpText, Timestamp initialDate) async {
    var picked = await showDatePicker(
        helpText: helpText,
        locale: const Locale('ar', 'EG'),
        context: context,
        initialDate: initialDate.toDate(),
        firstDate: DateTime(1900),
        lastDate: DateTime.now());
    if (picked != null && picked != initialDate.toDate()) {
      return Timestamp.fromDate(picked);
    }
    return null;
  }
}
