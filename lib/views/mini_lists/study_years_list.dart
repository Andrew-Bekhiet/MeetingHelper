import 'dart:async';

import 'package:churchdata_core/churchdata_core.dart';
import 'package:flutter/material.dart';
import 'package:rxdart/rxdart.dart';

class StudyYearsEditList extends StatefulWidget {
  final Stream<List<StudyYear>> list;

  final Function(StudyYear)? tap;
  const StudyYearsEditList({
    required this.list,
    super.key,
    this.tap,
  });

  @override
  _StudyYearsEditListState createState() => _StudyYearsEditListState();
}

class _StudyYearsEditListState extends State<StudyYearsEditList> {
  BehaviorSubject<String> filter = BehaviorSubject.seeded('');

  @override
  Widget build(BuildContext c) {
    return StreamBuilder<List<StudyYear>>(
      stream: filter.switchMap(
        (value) => value.isEmpty
            ? widget.list
            : widget.list.map(
                (list) => list.where((c) => c.name.contains(value)).toList(),
              ),
      ),
      builder: (con, data) {
        if (data.hasData) {
          return Column(
            children: <Widget>[
              TextField(
                decoration: const InputDecoration(hintText: 'بحث...'),
                onChanged: filter.add,
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: data.data!.length,
                  itemBuilder: (context, i) {
                    final StudyYear current = data.data![i];

                    return Card(
                      child: ListTile(
                        onTap: () => widget.tap!(current),
                        title: Text(current.name),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        } else {
          return const Center(child: CircularProgressIndicator());
        }
      },
    );
  }
}
