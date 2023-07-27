import 'package:churchdata_core/churchdata_core.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:meetinghelper/models.dart';
import 'package:meetinghelper/utils/globals.dart';

class MiniModelList<T extends MetaObject> extends StatelessWidget {
  final String title;
  final JsonCollectionRef collection;
  late final QueryOfJson Function(QueryOfJson) completer;
  final void Function(BuildContext)? add;
  final void Function(BuildContext, T, bool)? modify;
  final T Function(JsonQueryDoc) transformer;

  MiniModelList({
    required this.title,
    required this.collection,
    required this.transformer,
    super.key,
    this.add,
    this.modify,
    QueryOfJson Function(QueryOfJson)? completer,
  }) {
    this.completer = completer ?? (q) => q.orderBy('Name');
  }

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
        onTap: (item) {
          if (modify != null) {
            modify!(context, item, false);
          } else {
            _defaultModify(context, item, false);
          }
        },
        controller: ListController(
          objectsPaginatableStream: PaginatableStream.query(
            query: completer(collection),
            mapper: transformer,
          ),
        ),
        autoDisposeController: true,
      ),
      floatingActionButton: User.instance.permissions.write
          ? FloatingActionButton(
              onPressed: () async {
                if (add != null) {
                  add!(context);
                  return;
                }
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

  Future<void> _defaultModify(
    BuildContext context,
    T item,
    bool editMode,
  ) async {
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
                if (modify == null) {
                  await _defaultModify(
                    context,
                    item.copyWithName(name: name.text) as T,
                    !editMode,
                  );
                }
              },
              label: Text(editMode ? 'حفظ' : 'تعديل'),
            ),
          if (editMode)
            TextButton.icon(
              icon: const Icon(Icons.delete),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              onPressed: () async {
                await showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text(item.name),
                    content: Text('هل أنت متأكد من حذف ${item.name}؟'),
                    actions: <Widget>[
                      TextButton.icon(
                        icon: const Icon(Icons.delete),
                        style:
                            TextButton.styleFrom(foregroundColor: Colors.red),
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
            mainAxisSize: MainAxisSize.min,
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
                        Theme.of(context).textTheme.titleLarge!,
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

Future<void> churchTap(
  BuildContext context,
  Church _church,
  bool editMode, {
  bool canDelete = true,
}) async {
  Church church = _church;
  final title = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.bold,
    color: Theme.of(context).textTheme.titleLarge!.color,
    locale: const Locale('ar', 'EG'),
  );

  await showDialog(
    context: context,
    builder: (context) => AlertDialog(
      actions: <Widget>[
        TextButton(
          onPressed: () async {
            if (editMode) {
              await GetIt.I<DatabaseRepository>()
                  .collection('Churches')
                  .doc(church.id)
                  .set(church.toJson());
            }
            navigator.currentState!.pop();
            await churchTap(context, church, !editMode);
          },
          child: Text(editMode ? 'حفظ' : 'تعديل'),
        ),
        if (editMode && canDelete)
          TextButton(
            onPressed: () async {
              await showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text(church.name),
                  content: Text('هل أنت متأكد من حذف ${church.name}؟'),
                  actions: <Widget>[
                    TextButton(
                      onPressed: () async {
                        await GetIt.I<DatabaseRepository>()
                            .collection('Churches')
                            .doc(church.id)
                            .delete();
                        navigator.currentState!.pop();
                        navigator.currentState!.pop();
                      },
                      child: const Text('نعم'),
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
            child: const Text('حذف'),
          ),
      ],
      title: Text(church.name),
      content: SizedBox(
        width: 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            DefaultTextStyle(
              style: title,
              child: const Text('الاسم:'),
            ),
            if (editMode)
              TextField(
                controller: TextEditingController(text: church.name),
                onChanged: (v) => church = church.copyWith.name(v),
              )
            else
              Text(church.name),
            DefaultTextStyle(
              style: title,
              child: const Text('العنوان:'),
            ),
            if (editMode)
              TextField(
                controller: TextEditingController(text: church.address),
                onChanged: (v) => church = church.copyWith.address(v),
              )
            else
              Text(church.address!),
            if (!editMode) Text('الأباء بالكنيسة:', style: title),
            if (!editMode)
              StreamBuilder<List<Father>>(
                stream: church.getChildren(),
                builder: (con, data) {
                  if (data.hasData) {
                    return ListView.builder(
                      shrinkWrap: true,
                      itemCount: data.data!.length,
                      itemBuilder: (context, i) {
                        final current = data.data![i];
                        return Card(
                          child: ListTile(
                            onTap: () => fatherTap(context, current, false),
                            title: Text(current.name),
                          ),
                        );
                      },
                    );
                  } else {
                    return const Center(child: CircularProgressIndicator());
                  }
                },
              ),
          ],
        ),
      ),
    ),
  );
}

Future<void> fatherTap(
  BuildContext context,
  Father _father,
  bool editMode, {
  bool canDelete = true,
}) async {
  Father father = _father;
  final title = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.bold,
    color: Theme.of(context).textTheme.titleLarge!.color,
    locale: const Locale('ar', 'EG'),
  );

  await showDialog(
    context: context,
    builder: (context) => AlertDialog(
      actions: <Widget>[
        TextButton(
          onPressed: () async {
            if (editMode) {
              await GetIt.I<DatabaseRepository>()
                  .collection('Fathers')
                  .doc(father.id)
                  .set(father.toJson());
            }
            navigator.currentState!.pop();
            await fatherTap(context, father, !editMode);
          },
          child: Text(editMode ? 'حفظ' : 'تعديل'),
        ),
        if (editMode && canDelete)
          TextButton(
            onPressed: () async {
              await showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text(father.name),
                  content: Text('هل أنت متأكد من حذف ${father.name}؟'),
                  actions: <Widget>[
                    TextButton(
                      onPressed: () async {
                        await GetIt.I<DatabaseRepository>()
                            .collection('Fathers')
                            .doc(father.id)
                            .delete();
                        navigator.currentState!.pop();
                        navigator.currentState!.pop();
                      },
                      child: const Text('نعم'),
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
            child: const Text('حذف'),
          ),
      ],
      title: Text(father.name),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('الاسم:', style: title),
            if (editMode)
              TextField(
                controller: TextEditingController(text: father.name),
                onChanged: (v) => father = father.copyWith.name(v),
              )
            else
              Text(father.name),
            Text('داخل كنيسة', style: title),
            if (editMode)
              FutureBuilder<List<Church>>(
                future: Church.getAll().first,
                builder: (context, data) {
                  if (data.hasData) {
                    return Container(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: DropdownButtonFormField<JsonRef?>(
                        value: father.churchId,
                        items: data.data!
                            .map(
                              (item) => DropdownMenuItem(
                                value: item.ref,
                                child: Text(item.name),
                              ),
                            )
                            .toList()
                          ..insert(
                            0,
                            const DropdownMenuItem(
                              child: Text(''),
                            ),
                          ),
                        onChanged: (value) {
                          father = father.copyWith.churchId(value);
                        },
                        decoration: const InputDecoration(
                          labelText: 'الكنيسة',
                        ),
                      ),
                    );
                  } else {
                    return const LinearProgressIndicator();
                  }
                },
              )
            else
              FutureBuilder<String?>(
                future: father.getChurchName(),
                builder: (con, name) {
                  return name.hasData
                      ? Card(
                          child: ListTile(
                            title: Text(name.data!),
                            onTap: () async => churchTap(
                              context,
                              Church.fromDoc(await father.churchId!.get()),
                              false,
                            ),
                          ),
                        )
                      : const LinearProgressIndicator();
                },
              ),
          ],
        ),
      ),
    ),
  );
}

Future<void> studyYearTap(
  BuildContext context,
  StudyYear _year,
  bool editMode, {
  bool canDelete = true,
}) async {
  StudyYear year = _year;
  final title = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.bold,
    color: Theme.of(context).textTheme.titleLarge!.color,
    locale: const Locale('ar', 'EG'),
  );

  await showDialog(
    context: context,
    builder: (context) => AlertDialog(
      actions: <Widget>[
        TextButton(
          onPressed: () async {
            if (editMode) {
              await GetIt.I<DatabaseRepository>()
                  .collection('StudyYears')
                  .doc(year.id)
                  .set(year.toJson());
            }
            navigator.currentState!.pop();
            await studyYearTap(context, year, !editMode);
          },
          child: Text(editMode ? 'حفظ' : 'تعديل'),
        ),
        if (editMode && canDelete)
          TextButton(
            onPressed: () async {
              await showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text(year.name),
                  content: Text('هل أنت متأكد من حذف ${year.name}؟'),
                  actions: <Widget>[
                    TextButton(
                      onPressed: () async {
                        await GetIt.I<DatabaseRepository>()
                            .collection('StudyYears')
                            .doc(year.id)
                            .delete();
                        navigator.currentState!.pop();
                        navigator.currentState!.pop();
                      },
                      child: const Text('نعم'),
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
            child: const Text('حذف'),
          ),
      ],
      title: Text(year.name),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            DefaultTextStyle(
              style: title,
              child: const Text('الاسم:'),
            ),
            if (editMode)
              TextField(
                controller: TextEditingController(text: year.name),
                onChanged: (v) => year = year.copyWith.name(v),
              )
            else
              Text(year.name),
            DefaultTextStyle(
              style: title,
              child: const Text('ترتيب السنة:'),
            ),
            if (editMode)
              ListTile(
                onTap: () =>
                    year = year.copyWith.isCollegeYear(!year.isCollegeYear),
                title: const Text('سنة جامعية؟'),
                trailing: Checkbox(
                  value: year.isCollegeYear,
                  onChanged: (v) => year = year.copyWith.isCollegeYear(v!),
                ),
              )
            else
              ListTile(
                title: const Text('سنة جامعية؟'),
                subtitle: Text(year.isCollegeYear ? 'نعم' : 'لا'),
              ),
            if (editMode)
              TextField(
                keyboardType: TextInputType.number,
                controller: TextEditingController(text: year.grade.toString()),
                onChanged: (v) => year = year.copyWith.grade(int.parse(v)),
              )
            else
              Text(year.grade.toString()),
          ],
        ),
      ),
    ),
  );
}
