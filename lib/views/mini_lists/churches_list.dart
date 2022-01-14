import 'dart:async';

import 'package:churchdata_core/churchdata_core.dart';
import 'package:flutter/material.dart';

class ChurchesEditList extends StatefulWidget {
  final Stream<List<Church>> list;

  final Function(Church)? tap;
  const ChurchesEditList({Key? key, required this.list, this.tap})
      : super(key: key);

  @override
  _ChurchesEditListState createState() => _ChurchesEditListState();
}

class ChurchesList extends StatefulWidget {
  final Stream<List<Church>> list;

  final Function(List<Church>?)? finished;
  final Stream<Church>? original;
  const ChurchesList(
      {Key? key, required this.list, this.finished, this.original})
      : super(key: key);

  @override
  _ChurchesListState createState() => _ChurchesListState();
}

class _ChurchesEditListState extends State<ChurchesEditList> {
  String filter = '';

  @override
  Widget build(BuildContext c) {
    return StreamBuilder<List<Church>>(
      stream: widget.list,
      builder: (context, data) {
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
                child: ListView.builder(
                  itemCount: data.data!.length,
                  itemBuilder: (context, i) {
                    final Church current = data.data![i];
                    return current.name.contains(filter)
                        ? Card(
                            child: ListTile(
                              onTap: () => widget.tap!(current),
                              title: Text(current.name),
                              subtitle: Text(current.address!),
                            ),
                          )
                        : Container();
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

class _ChurchesListState extends State<ChurchesList> {
  List<Church>? result;
  final String filter = '';

  @override
  Widget build(BuildContext c) {
    return StreamBuilder<List<Church>>(
      stream: widget.list,
      builder: (context, o) {
        if (o.hasData) {
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
                  onRefresh: () async {
                    setState(() {});
                  },
                  child: StreamBuilder<JsonQuery>(
                    stream: widget.data,
                    builder: (context, churchs) {
                      if (!churchs.hasData)
                        return const CircularProgressIndicator();
                      return ListView.builder(
                        itemCount: churchs.data!.docs.length,
                        itemBuilder: (context, i) {
                          final Church current =
                              Church.fromDoc(churchs.data!.docs[i]);
                          return current.name.contains(filter)
                              ? Card(
                                  child: ListTile(
                                    onTap: () {
                                      widget.result
                                              .map((f) => f.id)
                                              .contains(current.id)
                                          ? widget.result.removeWhere(
                                              (x) => x.id == current.id)
                                          : widget.result.add(current);
                                      setState(() {});
                                    },
                                    title: Text(current.name),
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
                        },
                      );
                    },
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
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
            ],
          );
        } else {
          return Container();
        }
      },
    );
  }
}
