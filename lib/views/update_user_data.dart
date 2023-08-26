import 'package:churchdata_core/churchdata_core.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:intl/intl.dart';
import 'package:meetinghelper/models.dart';
import 'package:meetinghelper/utils/globals.dart';
import 'package:meetinghelper/utils/helpers.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

class UpdateUserDataErrorPage extends StatefulWidget {
  const UpdateUserDataErrorPage({super.key});

  @override
  State<StatefulWidget> createState() => _UpdateUserDataErrorState();
}

class _UpdateUserDataErrorState extends State<UpdateUserDataErrorPage> {
  User user = User.instance.copyWith();
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
              TappableFormField<DateTime?>(
                autovalidateMode: AutovalidateMode.onUserInteraction,
                decoration: (context, state) => InputDecoration(
                  errorText: state.errorText,
                  labelText: 'تاريخ أخر تناول',
                  suffixIcon: state.isValid
                      ? const Icon(Icons.done, color: Colors.green)
                      : const Icon(Icons.close, color: Colors.red),
                ),
                initialValue: user.lastTanawol,
                onTap: (state) async {
                  state.didChange(
                    await _selectDate(
                          'تاريخ أخر تناول',
                          state.value ?? DateTime.now(),
                        ) ??
                        user.lastTanawol,
                  );
                },
                builder: (context, state) {
                  return state.value != null
                      ? Text(DateFormat('yyyy/M/d').format(state.value!))
                      : null;
                },
                onSaved: (v) => user = user.copyWith.lastTanawol(v),
                validator: (value) => value == null
                    ? 'برجاء اختيار تاريخ أخر تناول'
                    : value.isBefore(
                        DateTime.now().subtract(const Duration(days: 60)),
                      )
                        ? 'يجب أن يكون التاريخ منذ شهرين على الأكثر'
                        : null,
              ),
              TappableFormField<DateTime?>(
                autovalidateMode: AutovalidateMode.onUserInteraction,
                decoration: (context, state) => InputDecoration(
                  errorText: state.errorText,
                  labelText: 'تاريخ أخر اعتراف',
                  suffixIcon: state.isValid
                      ? const Icon(Icons.done, color: Colors.green)
                      : const Icon(Icons.close, color: Colors.red),
                ),
                initialValue: user.lastConfession,
                onTap: (state) async {
                  state.didChange(
                    await _selectDate(
                          'تاريخ أخر اعتراف',
                          state.value ?? DateTime.now(),
                        ) ??
                        user.lastConfession,
                  );
                },
                builder: (context, state) {
                  return state.value != null
                      ? Text(DateFormat('yyyy/M/d').format(state.value!))
                      : null;
                },
                onSaved: (v) => user = user.copyWith.lastConfession(v),
                validator: (value) => value == null
                    ? 'برجاء اختيار تاريخ أخر اعتراف'
                    : value.isBefore(
                        DateTime.now().subtract(const Duration(days: 60)),
                      )
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
      if (!_form.currentState!.validate()) return;
      _form.currentState!.save();
      scaffoldMessenger.currentState!
          .showSnackBar(const SnackBar(content: Text('جار الحفظ')));
      await GetIt.I<FunctionsService>()
          .httpsCallable('updateUserSpiritData')
          .call({
        'lastConfession': user.lastConfession!.millisecondsSinceEpoch,
        'lastTanawol': user.lastTanawol!.millisecondsSinceEpoch,
      });
      navigator.currentState!.pop();
    } catch (err, stack) {
      await showErrorDialog(context, err.toString());
      await Sentry.captureException(
        err,
        stackTrace: stack,
        withScope: (scope) => scope
          ..setTag('LasErrorIn', '_UpdateUserDataErrorState.save')
          ..setExtra('User', {'UID': user.uid, ...user.toJson()}),
      );
    }
  }

  Future<DateTime?> _selectDate(String helpText, DateTime initialDate) async {
    final picked = await showDatePicker(
      helpText: helpText,
      locale: const Locale('ar', 'EG'),
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != initialDate) {
      return picked;
    }
    return null;
  }
}
