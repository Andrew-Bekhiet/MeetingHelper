import 'dart:async';

import 'package:churchdata_core/churchdata_core.dart';
import 'package:flutter/material.dart';
import 'package:rxdart/rxdart.dart';

class ChurchesEditList extends StatefulWidget {
  final Stream<List<Church>> list;

  final Function(Church)? tap;
  const ChurchesEditList({
    required this.list,
    super.key,
    this.tap,
  });

  @override
  _ChurchesEditListState createState() => _ChurchesEditListState();
}

class _ChurchesEditListState extends State<ChurchesEditList> {
  BehaviorSubject<String> filter = BehaviorSubject.seeded('');

  @override
  Future<void> dispose() async {
    super.dispose();
    await filter.close();
  }

  @override
  Widget build(BuildContext c) {
    return StreamBuilder<List<Church>>(
      stream: filter.switchMap(
        (value) => value.isEmpty
            ? widget.list
            : widget.list.map(
                (list) => list.where((c) => c.name.contains(value)).toList(),
              ),
      ),
      builder: (context, data) {
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
                    final Church current = data.data![i];

                    return Card(
                      child: ListTile(
                        onTap: () => widget.tap!(current),
                        title: Text(current.name),
                        subtitle: Text(current.address!),
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
