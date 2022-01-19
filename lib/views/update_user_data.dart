import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:meetinghelper/utils/globals.dart';
import 'package:meetinghelper/views/form_widgets/tapable_form_field.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../models/data/user.dart';
import '../utils/helpers.dart';

class UpdateUserDataErrorPage extends StatefulWidget {
  const UpdateUserDataErrorPage({Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() => _UpdateUserDataErrorState();
}

class _UpdateUserDataErrorState extends State<UpdateUserDataErrorPage> {
  User user = MHAuthRepository.I.currentUser!.copyWith();
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
              TapableFormField<DateTime?>(
                autovalidateMode: AutovalidateMode.onUserInteraction,
                decoration: (context, state) => InputDecoration(
                  errorText: state.errorText,
                  labelText: 'تاريخ أخر تناول',
                  suffixIcon: state.isValid
                      ? const Icon(Icons.done, color: Colors.green)
                      : const Icon(Icons.close, color: Colors.red),
                ),
                initialValue: user.permissions.lastTanawol,
                onTap: (state) async {
                  state.didChange(
                    await _selectDate(
                            'تاريخ أخر تناول', state.value ?? DateTime.now()) ??
                        user.permissions.lastTanawol,
                  );
                },
                builder: (context, state) {
                  return state.value != null
                      ? Text(DateFormat('yyyy/M/d').format(state.value!))
                      : null;
                },
                onSaved: (v) => user = user.copyWith.permissions(
                  user.permissions.copyWith.lastTanawol(v),
                ),
                validator: (value) => value == null
                    ? 'برجاء اختيار تاريخ أخر تناول'
                    : value.isBefore(
                            DateTime.now().subtract(const Duration(days: 60)))
                        ? 'يجب أن يكون التاريخ منذ شهرين على الأكثر'
                        : null,
              ),
              TapableFormField<DateTime?>(
                autovalidateMode: AutovalidateMode.onUserInteraction,
                decoration: (context, state) => InputDecoration(
                  errorText: state.errorText,
                  labelText: 'تاريخ أخر اعتراف',
                  suffixIcon: state.isValid
                      ? const Icon(Icons.done, color: Colors.green)
                      : const Icon(Icons.close, color: Colors.red),
                ),
                initialValue: user.permissions.lastConfession,
                onTap: (state) async {
                  state.didChange(
                    await _selectDate('تاريخ أخر اعتراف',
                            state.value ?? DateTime.now()) ??
                        user.permissions.lastConfession,
                  );
                },
                builder: (context, state) {
                  return state.value != null
                      ? Text(DateFormat('yyyy/M/d').format(state.value!))
                      : null;
                },
                onSaved: (v) => user = user.copyWith.permissions(
                  user.permissions.copyWith.lastConfession(v),
                ),
                validator: (value) => value == null
                    ? 'برجاء اختيار تاريخ أخر اعتراف'
                    : value.isBefore(
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
      if (user.permissions.lastConfession == null ||
          user.permissions.lastTanawol == null) {
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
        'lastConfession':
            user.permissions.lastConfession!.millisecondsSinceEpoch,
        'lastTanawol': user.permissions.lastTanawol!.millisecondsSinceEpoch
      });
      navigator.currentState!.pop();
    } catch (err, stack) {
      await showErrorDialog(context, err.toString());
      await Sentry.captureException(err,
          stackTrace: stack,
          withScope: (scope) => scope
            ..setTag('LasErrorIn', '_UpdateUserDataErrorState.save')
            ..setExtra('User', {'UID': user.uid, ...user.getUpdateMap()}));
    }
  }

  Future<DateTime?> _selectDate(String helpText, DateTime initialDate) async {
    final picked = await showDatePicker(
        helpText: helpText,
        locale: const Locale('ar', 'EG'),
        context: context,
        initialDate: initialDate,
        firstDate: DateTime(1900),
        lastDate: DateTime.now());
    if (picked != null && picked != initialDate) {
      return picked;
    }
    return null;
  }
}
