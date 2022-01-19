import 'dart:async';

import 'package:churchdata_core/churchdata_core.dart';
import 'package:flutter/material.dart';
import 'package:rxdart/rxdart.dart';

class FathersEditList extends StatefulWidget {
  final Stream<List<Father>> list;

  final Function(Father)? tap;
  const FathersEditList({Key? key, required this.list, this.tap})
      : super(key: key);

  @override
  _FathersEditListState createState() => _FathersEditListState();
}

class _FathersEditListState extends State<FathersEditList> {
  BehaviorSubject<String> filter = BehaviorSubject.seeded('');

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Father>>(
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
                    final Father current = data.data![i];

                    return Card(
                      child: ListTile(
                        onTap: () => widget.tap!(current),
                        title: Text(current.name),
                        subtitle: FutureBuilder<String?>(
                          future: current.getChurchName(),
                          builder: (con, name) {
                            return name.hasData
                                ? Text(name.data!)
                                : name.connectionState ==
                                        ConnectionState.waiting
                                    ? const LinearProgressIndicator()
                                    : const Text('');
                          },
                        ),
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
