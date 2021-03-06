import 'dart:async';

import 'package:flutter/material.dart';
import 'package:meetinghelper/models/mini_models.dart';
import 'package:meetinghelper/utils/typedefs.dart';

class ChurchesEditList extends StatefulWidget {
  final Future<JsonQuery> list;

  final Function(Church)? tap;
  const ChurchesEditList({Key? key, required this.list, this.tap})
      : super(key: key);

  @override
  _ChurchesEditListState createState() => _ChurchesEditListState();
}

class ChurchesList extends StatefulWidget {
  final Future<Stream<JsonQuery>> list;

  final Function(List<Church>?)? finished;
  final Stream<Church>? original;
  const ChurchesList(
      {Key? key, required this.list, this.finished, this.original})
      : super(key: key);

  @override
  _ChurchesListState createState() => _ChurchesListState();
}

class InnerListState extends State<_InnerChurchsList> {
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
        },
      ),
      Expanded(
        child: RefreshIndicator(
          onRefresh: () async {
            setState(() {});
          },
          child: StreamBuilder<JsonQuery>(
            stream: widget.data,
            builder: (context, churchs) {
              if (!churchs.hasData) return const CircularProgressIndicator();
              return ListView.builder(
                itemCount: churchs.data!.docs.length,
                itemBuilder: (context, i) {
                  Church current = Church.fromDoc(churchs.data!.docs[i]);
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
                            leading: Checkbox(
                              value: widget.result
                                  .map((f) => f.id)
                                  .contains(current.id),
                              onChanged: (x) {
                                !x!
                                    ? widget.result
                                        .removeWhere((x) => x.id == current.id)
                                    : widget.result.add(current);
                                setState(() {});
                              },
                            ),
                          ),
                        )
                      : Container();
                },
              );
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

class _ChurchesEditListState extends State<ChurchesEditList> {
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
                },
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () {
                    setState(() {});
                    return widget.list.then((value) => value);
                  },
                  child: ListView.builder(
                      itemCount: data.data!.docs.length,
                      itemBuilder: (context, i) {
                        Church current = Church.fromDoc(data.data!.docs[i]);
                        return current.name!.contains(filter)
                            ? Card(
                                child: ListTile(
                                  onTap: () => widget.tap!(current),
                                  title: Text(current.name!),
                                  subtitle: Text(current.address!),
                                ),
                              )
                            : Container();
                      }),
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

class _ChurchesListState extends State<ChurchesList> {
  List<Church>? result;

  @override
  Widget build(BuildContext c) {
    return FutureBuilder<Stream<JsonQuery>>(
        future: widget.list,
        builder: (c, o) {
          if (o.hasData) {
            return StreamBuilder<Church>(
                stream: widget.original,
                builder: (con, data) {
                  if (result == null && data.hasData) {
                    result = [data.data!];
                  } else if (data.hasData) {
                    result!.add(data.data!);
                  } else {
                    result = [];
                  }
                  return _InnerChurchsList(
                      o.data, result ?? [], widget.list, widget.finished);
                });
          } else {
            return Container();
          }
        });
  }
}

class _InnerChurchsList extends StatefulWidget {
  final Stream<JsonQuery>? data;
  final List<Church> result;
  final Function(List<Church>?)? finished;
  final Future<Stream<JsonQuery>>? list;
  _InnerChurchsList(this.data, this.result, this.list, this.finished);
  @override
  State<StatefulWidget> createState() => InnerListState();
}
