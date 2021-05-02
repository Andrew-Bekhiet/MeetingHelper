import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:meetinghelper/models/mini_models.dart';

class InnerListState extends State<_InnerSchoolsList> {
  String filter = '';
  @override
  Widget build(BuildContext context) {
    return Column(children: <Widget>[
      TextField(
          decoration: InputDecoration(hintText: 'بحث...'),
          onChanged: (text) {
            setState(() {
              filter = text;
            });
          }),
      Expanded(
        child: RefreshIndicator(
          onRefresh: () {
            setState(() {});
            return null;
          } as Future<void> Function(),
          child: StreamBuilder<QuerySnapshot>(
            stream: widget.data,
            builder: (context, schools) {
              if (!schools.hasData) return CircularProgressIndicator();
              return ListView.builder(
                  itemCount: schools.data!.docs.length,
                  itemBuilder: (context, i) {
                    School current = School.fromDoc(schools.data!.docs[i]);
                    return current.name!.contains(filter)
                        ? Card(
                            child: ListTile(
                              onTap: () {
                                widget.result!
                                        .map((f) => f.id)
                                        .contains(current.id)
                                    ? widget.result!
                                        .removeWhere((x) => x.id == current.id)
                                    : widget.result!.add(current);
                                setState(() {});
                              },
                              title: Text(current.name!),
                              leading: Checkbox(
                                value: widget.result!
                                    .map((f) => f.id)
                                    .contains(current.id),
                                onChanged: (x) {
                                  !x!
                                      ? widget.result!.removeWhere(
                                          (x) => x.id == current.id)
                                      : widget.result!.add(current);
                                  setState(() {});
                                },
                              ),
                            ),
                          )
                        : Container();
                  });
            },
          ),
        ),
      ),
      Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          TextButton(
            onPressed: () => widget.finished!(widget.result),
            child: Text('تم'),
          ),
          TextButton(
            onPressed: () => widget.finished!(null),
            child: Text('إلغاء الأمر'),
          ),
        ],
      )
    ]);
  }
}

class SchoolsEditList extends StatefulWidget {
  final Future<QuerySnapshot> list;

  final Function(School)? tap;
  SchoolsEditList({required this.list, this.tap});

  @override
  _SchoolsEditListState createState() => _SchoolsEditListState();
}

class SchoolsList extends StatefulWidget {
  final Future<Stream<QuerySnapshot>>? list;

  final Function(List<School>?)? finished;
  final Stream<School>? original;
  SchoolsList({this.list, this.finished, this.original});

  @override
  _SchoolsListState createState() => _SchoolsListState();
}

class _InnerSchoolsList extends StatefulWidget {
  final Stream<QuerySnapshot>? data;
  final List<School>? result;
  final Function(List<School>?)? finished;
  final Future<Stream<QuerySnapshot>>? list;
  _InnerSchoolsList(this.data, this.result, this.list, this.finished);
  @override
  State<StatefulWidget> createState() => InnerListState();
}

class _SchoolsEditListState extends State<SchoolsEditList> {
  String filter = '';
  @override
  Widget build(BuildContext c) {
    return FutureBuilder<QuerySnapshot>(
      future: widget.list,
      builder: (con, data) {
        if (data.hasData) {
          return Column(children: <Widget>[
            TextField(
                decoration: InputDecoration(hintText: 'بحث...'),
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
                    School current = School.fromDoc(data.data!.docs[i]);
                    return current.name!.contains(filter)
                        ? Card(
                            child: ListTile(
                              onTap: () => widget.tap!(current),
                              title: Text(current.name!),
                              subtitle: Text(current.address!),
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

class _SchoolsListState extends State<SchoolsList> {
  List<School>? result;

  @override
  Widget build(BuildContext c) {
    return FutureBuilder<Stream<QuerySnapshot>>(
        future: widget.list,
        builder: (c, o) {
          if (o.hasData) {
            return StreamBuilder<School>(
                stream: widget.original,
                builder: (con, data) {
                  if (result == null && data.hasData) {
                    result = [data.data!];
                  } else if (data.hasData) {
                    result!.add(data.data!);
                  } else {
                    result = [];
                  }
                  return _InnerSchoolsList(
                      o.data, result ?? [], widget.list, widget.finished);
                });
          } else {
            return Container();
          }
        });
  }
}
