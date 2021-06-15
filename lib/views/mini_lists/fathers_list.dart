import 'dart:async';

import 'package:meetinghelper/utils/typedefs.dart';
import 'package:flutter/material.dart';
import 'package:meetinghelper/models/mini_models.dart';

class FathersEditList extends StatefulWidget {
  final Future<JsonQuery> list;

  final Function(Father)? tap;
  const FathersEditList({Key? key, required this.list, this.tap})
      : super(key: key);

  @override
  _FathersEditListState createState() => _FathersEditListState();
}

class FathersList extends StatefulWidget {
  final Future<Stream<JsonQuery>>? list;

  final Function(List<Father>?)? finished;
  final Stream<Father>? original;
  const FathersList({Key? key, this.list, this.finished, this.original})
      : super(key: key);

  @override
  _FathersListState createState() => _FathersListState();
}

class InnerListState extends State<_InnerFathersList> {
  String filter = '';
  @override
  Widget build(BuildContext context) {
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
          onRefresh: () async {
            setState(() {});
          },
          child: StreamBuilder<JsonQuery>(
            stream: widget.data,
            builder: (context, fathers) {
              if (!fathers.hasData) return const CircularProgressIndicator();
              return ListView.builder(
                  itemCount: fathers.data!.docs.length,
                  itemBuilder: (context, i) {
                    Father current = Father.fromDoc(fathers.data!.docs[i]);
                    return current.name!.contains(filter)
                        ? Card(
                            child: ListTile(
                              onTap: () {
                                widget.result
                                        .map((f) => f.id)
                                        .contains(current.id)
                                    ? widget.result
                                        .removeWhere((x) => x.id == current.id)
                                    : widget.result.add(current);
                                setState(() {});
                              },
                              title: Text(current.name!),
                              subtitle: FutureBuilder<String?>(
                                  future: current.getChurchName(),
                                  builder: (con, name) {
                                    return name.hasData
                                        ? Text(name.data!)
                                        : const LinearProgressIndicator();
                                  }),
                              leading: Checkbox(
                                value: widget.result
                                    .map((f) => f.id)
                                    .contains(current.id),
                                onChanged: (x) {
                                  !x!
                                      ? widget.result.removeWhere(
                                          (x) => x.id == current.id)
                                      : widget.result.add(current);
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
            child: const Text('تم'),
          ),
          TextButton(
            onPressed: () => widget.finished!(null),
            child: const Text('إلغاء الأمر'),
          ),
        ],
      )
    ]);
  }
}

class _FathersEditListState extends State<FathersEditList> {
  String filter = '';
  @override
  Widget build(BuildContext c) {
    return FutureBuilder<JsonQuery>(
      future: widget.list,
      builder: (con, data) {
        if (data.hasData) {
          return Column(
            children: <Widget>[
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
                      Father current = Father.fromDoc(data.data!.docs[i]);
                      return current.name!.contains(filter)
                          ? Card(
                              child: ListTile(
                                onTap: () => widget.tap!(current),
                                title: Text(current.name!),
                                subtitle: FutureBuilder<String?>(
                                    future: current.getChurchName(),
                                    builder: (con, name) {
                                      return name.hasData
                                          ? Text(name.data!)
                                          : const LinearProgressIndicator();
                                    }),
                              ),
                            )
                          : Container();
                    },
                  ),
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

class _FathersListState extends State<FathersList> {
  List<Father>? result;

  @override
  Widget build(BuildContext c) {
    return FutureBuilder<Stream<JsonQuery>>(
        future: widget.list,
        builder: (c, o) {
          if (o.hasData) {
            return StreamBuilder<Father>(
                stream: widget.original,
                builder: (con, data) {
                  if (result == null && data.hasData) {
                    result = [data.data!];
                  } else if (data.hasData) {
                    result!.add(data.data!);
                  } else {
                    result = [];
                  }
                  return _InnerFathersList(
                      o.data, result ?? [], widget.list, widget.finished);
                });
          } else {
            return Container();
          }
        });
  }
}

class _InnerFathersList extends StatefulWidget {
  final Stream<JsonQuery>? data;
  final List<Father> result;
  final Function(List<Father>?)? finished;
  final Future<Stream<JsonQuery>>? list;
  _InnerFathersList(this.data, this.result, this.list, this.finished);
  @override
  State<StatefulWidget> createState() => InnerListState();
}
