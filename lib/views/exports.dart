import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';

class Exports extends StatelessWidget {
  const Exports({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('عمليات التصدير السابقة'),
      ),
      body: FutureBuilder<List<FileSystemEntity>>(future: () async {
        return dirContents(Directory(
            (await getApplicationDocumentsDirectory()).path + '/Exports'));
      }(), builder: (context, snapshot) {
        if (snapshot.hasError) return ErrorWidget(snapshot.error!);
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        return ListView.builder(
          itemCount: snapshot.data!.length,
          itemBuilder: (context, i) => Card(
            child: ListTile(
              onTap: () => OpenFile.open(snapshot.data![i].path),
              title: Text(snapshot.data![i].uri
                  .pathSegments[snapshot.data![i].uri.pathSegments.length - 1]),
            ),
          ),
        );
      }),
    );
  }

  Future<List<FileSystemEntity>> dirContents(Directory dir) {
    final files = <FileSystemEntity>[];
    final completer = Completer<List<FileSystemEntity>>();
    final lister = dir.list();
    // ignore: cascade_invocations
    lister.listen(files.add, onDone: () => completer.complete(files));
    return completer.future;
  }
}
