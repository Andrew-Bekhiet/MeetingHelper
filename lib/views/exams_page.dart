import 'package:churchdata_core/churchdata_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:meetinghelper/models.dart';
import 'package:meetinghelper/repositories/database_repository.dart';
import 'package:meetinghelper/utils/helpers.dart';

class ExamsPage extends StatelessWidget {
  final Service service;

  const ExamsPage({required this.service, super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('الامتحانات ل' + service.name)),
      body: StreamBuilder<List<Exam>>(
        stream: MHDatabaseRepo.I.exams.getAll(
          queryCompleter: (q, order, desc) => q
              .where('Service', isEqualTo: service.ref)
              .orderBy(order, descending: desc),
        ),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text(snapshot.error.toString()));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final exams = snapshot.data!;

          if (exams.isEmpty) {
            return const Center(child: Text('لا يوجد امتحانات لهذه الخدمة'));
          }

          return ListView.builder(
            itemCount: exams.length,
            itemBuilder: (context, index) {
              final exam = exams[index];

              return Card(
                child: ListTile(
                  onTap: () => Navigator.of(context).pushNamed(
                    'ExamInfo',
                    arguments: {
                      'Exam': exam,
                      'Service': service,
                    },
                  ),
                  onLongPress: () => User.instance.permissions.write
                      ? _editExam(context, exam)
                      : null,
                  title: Text(exam.name),
                  subtitle: Text(DateFormat('yyyy/M/d').format(exam.time!)),
                  trailing: Text(exam.max.toString()),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: User.instance.permissions.write
          ? FloatingActionButton(
              child: const Icon(Icons.add),
              onPressed: () => _editExam(
                context,
                Exam.empty().copyWith(service: service.ref),
              ),
            )
          : null,
    );
  }

  void _editExam(BuildContext context, Exam exam) {
    showDialog(
      context: context,
      builder: (context) => _NewExamDialog(exam: exam),
    );
  }
}

class _NewExamDialog extends StatefulWidget {
  final Exam exam;

  const _NewExamDialog({required this.exam});

  @override
  State<_NewExamDialog> createState() => _NewExamDialogState();
}

class _NewExamDialogState extends State<_NewExamDialog> {
  final _formKey = GlobalKey<FormState>();

  late Exam resultExam = widget.exam.copyWith();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: widget.exam.id == 'null'
          ? const Text('امتحان جديد')
          : Text('تعديل ' + widget.exam.name),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: TextFormField(
                decoration: const InputDecoration(labelText: 'الاسم'),
                initialValue: resultExam.name,
                onChanged: (value) =>
                    resultExam = resultExam.copyWith(name: value.trim()),
                validator: (value) =>
                    value == null || value.isEmpty ? 'برجاء إدخال الاسم' : null,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: TextFormField(
                decoration: const InputDecoration(labelText: 'الدرجة العظمى'),
                initialValue: resultExam.max.toString(),
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                keyboardType: TextInputType.number,
                onChanged: (value) =>
                    resultExam = resultExam.copyWith(max: int.parse(value)),
                validator: (value) {
                  if (value == null) {
                    return 'برجاء إدخال الدرجة العظمى';
                  } else if (int.tryParse(value) == null) {
                    return 'برجاء إدخال رقم صحيح';
                  }
                  return null;
                },
              ),
            ),
            TappableFormField<DateTime?>(
              labelText: 'تاريخ الامتحان',
              initialValue: resultExam.time,
              onTap: (state) async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: state.value ?? DateTime.now(),
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
                );

                if (date != null) {
                  resultExam = resultExam.copyWith(time: date);
                  state.didChange(date);
                }
              },
              decoration: (context, state) => InputDecoration(
                labelText: 'تاريخ الامتحان',
                errorText: state.errorText,
              ),
              builder: (context, state) {
                return state.value != null
                    ? Text(DateFormat('yyyy/M/d').format(state.value!))
                    : null;
              },
              validator: (value) =>
                  value == null ? 'برجاء إدخال تاريخ الامتحان' : null,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _save, child: const Text('حفظ')),
        if (widget.exam.id != 'null')
          TextButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              try {
                await widget.exam.ref.delete();
                navigator.pop();
              } on Exception catch (e) {
                await showErrorDialog(navigator.context, e.toString());
              }
            },
            child: const Text('حذف'),
          ),
        TextButton(
          onPressed: Navigator.of(context).pop,
          child: const Text('إلغاء'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    final navigator = Navigator.of(context);
    try {
      if (_formKey.currentState!.validate()) {
        _formKey.currentState!.save();

        final isUpdate = resultExam.ref.id != 'null';

        final examWithUpdatedRef = resultExam.copyWith(
          ref: isUpdate
              ? resultExam.ref
              : MHDatabaseRepo.I.collection('Exams').doc(),
        );

        await examWithUpdatedRef.ref.set(examWithUpdatedRef.toJson());

        navigator.pop(resultExam);
      }
    } on Exception catch (e) {
      await showErrorDialog(navigator.context, e.toString());
    }
  }
}
