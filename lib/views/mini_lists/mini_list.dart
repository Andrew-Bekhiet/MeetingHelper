import 'package:churchdata_core/churchdata_core.dart';
import 'package:flutter/material.dart';
import 'package:meetinghelper/models/data/user.dart';
import 'package:meetinghelper/utils/globals.dart';

class MiniModelList<T extends MetaObject> extends StatelessWidget {
  final String title;
  final JsonCollectionRef collection;
  final void Function()? add;
  final void Function(T)? modify;
  final T Function(JsonQueryDoc) transformer;

  const MiniModelList(
      {Key? key,
      required this.title,
      required this.collection,
      this.add,
      this.modify,
      required this.transformer})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: DataObjectListView<void, T>(
        itemBuilder: (
          current, {
          onLongPress,
          onTap,
          trailing,
          subtitle,
        }) =>
            ListTile(
          title: Text(current.name),
          onTap: () => onTap?.call(current),
        ),
        onTap: modify ?? (item) => _defaultModify(context, item, false),
        controller: ListController(
          objectsPaginatableStream:
              PaginatableStream.query(query: collection, mapper: transformer),
        ),
        autoDisposeController: true,
      ),
      floatingActionButton: User.instance.permissions.write
          ? FloatingActionButton(
              onPressed: add ??
                  () async {
                    final name = TextEditingController();
                    await showDialog(
                      context: context,
                      builder: (context) => StatefulBuilder(
                        builder: (context, setState) {
                          return AlertDialog(
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                TextField(
                                  decoration:
                                      const InputDecoration(labelText: 'الاسم'),
                                  controller: name,
                                ),
                              ],
                            ),
                            actions: <Widget>[
                              TextButton.icon(
                                icon: const Icon(Icons.save),
                                onPressed: () async {
                                  await collection.add(
                                    {
                                      'Name': name.text,
                                    },
                                  );
                                  navigator.currentState!.pop();
                                },
                                label: const Text('حفظ'),
                              ),
                            ],
                          );
                        },
                      ),
                    );
                  },
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  void _defaultModify(BuildContext context, T item, bool editMode) async {
    final name = TextEditingController(text: item.name);
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        actions: <Widget>[
          if (User.instance.permissions.write)
            TextButton.icon(
              icon: editMode ? const Icon(Icons.save) : const Icon(Icons.edit),
              onPressed: () async {
                if (editMode) {
                  await item.ref.update({'Name': name.text});
                }
                navigator.currentState!.pop();
                if (modify == null)
                  _defaultModify(
                    context,
                    (item as dynamic).copyWith(name: name.text) as T,
                    !editMode,
                  );
              },
              label: Text(editMode ? 'حفظ' : 'تعديل'),
            ),
          if (editMode)
            TextButton.icon(
              icon: const Icon(Icons.delete),
              style: TextButton.styleFrom(primary: Colors.red),
              onPressed: () async {
                await showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text(item.name),
                    content: Text('هل أنت متأكد من حذف ${item.name}؟'),
                    actions: <Widget>[
                      TextButton.icon(
                        icon: const Icon(Icons.delete),
                        style: TextButton.styleFrom(primary: Colors.red),
                        label: const Text('نعم'),
                        onPressed: () async {
                          await item.ref.delete();
                          navigator.currentState!.pop();
                          navigator.currentState!.pop();
                        },
                      ),
                      TextButton(
                        onPressed: () {
                          navigator.currentState!.pop();
                        },
                        child: const Text('تراجع'),
                      ),
                    ],
                  ),
                );
              },
              label: const Text('حذف'),
            ),
        ],
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (editMode)
                TextField(
                  controller: name,
                )
              else
                Padding(
                  padding: const EdgeInsets.fromLTRB(24.0, 24.0, 24.0, 0.0),
                  child: DefaultTextStyle(
                    style: Theme.of(context).dialogTheme.titleTextStyle ??
                        Theme.of(context).textTheme.headline6!,
                    child: Text(item.name),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
