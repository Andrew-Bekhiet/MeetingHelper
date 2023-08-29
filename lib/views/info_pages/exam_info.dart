import 'package:churchdata_core/churchdata_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:meetinghelper/models.dart';

class ExamInfo extends StatefulWidget {
  final Exam exam;
  final Service service;

  const ExamInfo({required this.exam, required this.service, super.key});

  @override
  State<ExamInfo> createState() => _ExamInfoState();
}

class _ExamInfoState extends State<ExamInfo> {
  late final ListController<void, Person> _controller =
      ListController<void, Person>(
    objectsPaginatableStream: PaginatableStream.loadAll(
      stream: widget.service.getPersonsMembers(),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.exam.name)),
      body: DataObjectListView<void, Person>(
        controller: _controller,
        autoDisposeController: true,
        emptyMsg: 'لا يوجد مخدومين',
        itemBuilder: (person, {onLongPress, onTap, subtitle, trailing}) {
          final personScore = person.examScores[widget.exam.id] ?? 0;

          return ViewableObjectWidget(
            person,
            subtitle: subtitle,
            onLongPress: onTap != null ? () => onTap(person) : null,
            onTap: () => User.instance.permissions.write
                ? _editPersonScore(person)
                : null,
            trailing: SizedBox(
              width: 40,
              child: Text(
                personScore.toString() +
                    '/' +
                    widget.exam.max.toString() +
                    '\n' +
                    (100 * personScore ~/ widget.exam.max).toString() +
                    '%',
                textAlign: TextAlign.center,
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _save(Person person, int newScore) async {
    await person.ref.update({
      FieldPath(['ExamScores', widget.exam.id]): newScore,
    });

    Navigator.of(context).pop();
  }

  void _editPersonScore(Person person) {
    final score = person.examScores[widget.exam.id] ?? 0;
    final controller = TextEditingController(text: score.toString());
    controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: controller.text.length,
    );

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('تعديل درجة ${person.name}'),
          content: TextField(
            textAlign: TextAlign.center,
            controller: controller,
            autofocus: true,
            onSubmitted: (_) => _save(person, int.parse(controller.text)),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          ),
          actions: [
            TextButton(
              onPressed: Navigator.of(context).pop,
              child: const Text('إلغاء'),
            ),
            TextButton(
              onPressed: () => _save(person, int.parse(controller.text)),
              child: const Text('حفظ'),
            ),
          ],
        );
      },
    );
  }
}
