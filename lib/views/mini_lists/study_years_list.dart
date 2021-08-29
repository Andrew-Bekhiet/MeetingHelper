import 'dart:async';

import 'package:flutter/material.dart';
import 'package:meetinghelper/models/mini_models.dart';
import 'package:meetinghelper/utils/typedefs.dart';

class StudyYearsEditList extends StatefulWidget {
  final Future<JsonQuery> list;

  final Function(StudyYear)? tap;
  const StudyYearsEditList({Key? key, required this.list, this.tap})
      : super(key: key);

  @override
  _StudyYearsEditListState createState() => _StudyYearsEditListState();
}

class _StudyYearsEditListState extends State<StudyYearsEditList> {
  String filter = '';
  @override
  Widget build(BuildContext c) {
    return FutureBuilder<JsonQuery>(
      future: widget.list,
      builder: (con, data) {
        if (data.hasData) {
          return Column(children: <Widget>[
            TextField(
                decoration: const InputDecoration(hintText: 'بحث...'),
                onChanged: (text) {
                  setState(() {
                    filter = text;
                  });
                }),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () {
                  setState(() {});
                  return widget.list.then((value) => value);
                },
                child: ListView.builder(
                  itemCount: data.data!.docs.length,
                  itemBuilder: (context, i) {
                    final StudyYear current =
                        StudyYear.fromDoc(data.data!.docs[i]);
                    return current.name.contains(filter)
                        ? Card(
                            child: ListTile(
                              onTap: () => widget.tap!(current),
                              title: Text(current.name),
                            ),
                          )
                        : Container();
                  },
                ),
              ),
            ),
          ]);
        } else {
          return const Center(child: CircularProgressIndicator());
        }
      },
    );
  }
}
