import 'package:churchdata_core/churchdata_core.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:meetinghelper/models.dart';
import 'package:meetinghelper/utils/globals.dart';
import 'package:rxdart/rxdart.dart';

class MiniModelList<T extends MetaObject> extends StatefulWidget {
  final String title;
  final JsonCollectionRef collection;
  final void Function(BuildContext)? add;
  final void Function(BuildContext, T, bool)? modify;
  final T Function(JsonQueryDoc) transformer;
  final bool showSearch;

  late final QueryOfJson Function(QueryOfJson) completer;

  MiniModelList({
    required this.title,
    required this.collection,
    required this.transformer,
    this.showSearch = false,
    this.add,
    this.modify,
    QueryOfJson Function(QueryOfJson)? completer,
    super.key,
  }) {
    this.completer = completer ?? (q) => q.orderBy('Name');
  }

  @override
  State<MiniModelList<T>> createState() => _MiniModelListState<T>();
}

class _MiniModelListState<T extends MetaObject>
    extends State<MiniModelList<T>> {
  late final BehaviorSubject<String?> _searchQuery =
      BehaviorSubject<String?>.seeded(widget.showSearch ? '' : null);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => _searchQuery.add(''),
          ),
        ],
        title: StreamBuilder<bool>(
          initialData: _searchQuery.valueOrNull != null,
          stream: _searchQuery.map((v) => v != null),
          builder: (context, data) => data.data!
              ? TextField(
                  autofocus: true,
                  style: Theme.of(context).textTheme.titleLarge!.copyWith(
                    color: Theme.of(context).primaryTextTheme.titleLarge!.color,
                  ),
                  decoration: InputDecoration(
                    suffixIcon: IconButton(
                      icon: Icon(
                        Icons.close,
                        color: Theme.of(
                          context,
                        ).primaryTextTheme.titleLarge!.color,
                      ),
                      onPressed: () => _searchQuery.add(null),
                    ),
                    hintStyle: Theme.of(context).textTheme.titleLarge!.copyWith(
                      color: Theme.of(
                        context,
                      ).primaryTextTheme.titleLarge!.color,
                    ),
                    icon: Icon(
                      Icons.search,
                      color: Theme.of(
                        context,
                      ).primaryTextTheme.titleLarge!.color,
                    ),
                    hintText: 'بحث ...',
                  ),
                  onChanged: _searchQuery.add,
                )
              : Text(widget.title),
        ),
      ),
      body: DataObjectListView<void, T>(
        itemBuilder: (current, {onLongPress, onTap, trailing, subtitle}) =>
            ListTile(
              title: Text(current.name),
              onTap: () => onTap?.call(current),
            ),
        onTap: (item) {
          if (widget.modify != null) {
            widget.modify!(context, item, false);
          } else {
            _defaultModify(context, item, false);
          }
        },
        controller: ListController(
          searchStream: _searchQuery.map((v) => v ?? ''),
          objectsPaginatableStream: PaginatableStream.query(
            query: widget.completer(widget.collection),
            mapper: widget.transformer,
          ),
        ),
        autoDisposeController: true,
      ),
      floatingActionButton: User.instance.permissions.write
          ? FloatingActionButton(
              onPressed: () async {
                if (widget.add != null) {
                  widget.add!(context);
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
                              decoration: const InputDecoration(
                                labelText: 'الاسم',
                              ),
                              controller: name,
                            ),
                          ],
                        ),
                        actions: <Widget>[
                          TextButton.icon(
                            icon: const Icon(Icons.save),
                            onPressed: () {
                              widget.collection.add({'Name': name.text});
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
              onPressed: () {
                if (editMode) {
                  item.ref.update({'Name': name.text});
                }
                navigator.currentState!.pop();
                if (widget.modify == null) {
                  _defaultModify(
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
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
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
                TextField(controller: name)
              else
                Padding(
                  padding: const EdgeInsets.fromLTRB(24.0, 24.0, 24.0, 0.0),
                  child: DefaultTextStyle(
                    style:
                        Theme.of(context).dialogTheme.titleTextStyle ??
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
          onPressed: () {
            if (editMode) {
              GetIt.I<DatabaseRepository>()
                  .collection('Churches')
                  .doc(church.id)
                  .set(church.toJson());
            }
            navigator.currentState!.pop();
            churchTap(context, church, !editMode);
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
            DefaultTextStyle(style: title, child: const Text('الاسم:')),
            if (editMode)
              TextField(
                controller: TextEditingController(text: church.name),
                onChanged: (v) => church = church.copyWith.name(v),
              )
            else
              Text(church.name),
            DefaultTextStyle(style: title, child: const Text('العنوان:')),
            if (editMode)
              TextField(
                controller: TextEditingController(text: church.address),
                onChanged: (v) => church = church.copyWith.address(v),
              )
            else
              Text(church.address ?? ''),
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
          onPressed: () {
            if (editMode) {
              GetIt.I<DatabaseRepository>()
                  .collection('Fathers')
                  .doc(father.id)
                  .set(father.toJson());
            }
            navigator.currentState!.pop();
            fatherTap(context, father, !editMode);
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
                        initialValue: father.churchId,
                        items:
                            data.data!
                                .map(
                                  (item) => DropdownMenuItem(
                                    value: item.ref,
                                    child: Text(item.name),
                                  ),
                                )
                                .toList()
                              ..insert(
                                0,
                                const DropdownMenuItem(child: Text('')),
                              ),
                        onChanged: (value) {
                          father = father.copyWith.churchId(value);
                        },
                        decoration: const InputDecoration(labelText: 'الكنيسة'),
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
          onPressed: () {
            if (editMode) {
              GetIt.I<DatabaseRepository>()
                  .collection('StudyYears')
                  .doc(year.id)
                  .set(year.toJson());
            }
            navigator.currentState!.pop();
            studyYearTap(context, year, !editMode);
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
            DefaultTextStyle(style: title, child: const Text('الاسم:')),
            if (editMode)
              TextField(
                controller: TextEditingController(text: year.name),
                onChanged: (v) => year = year.copyWith.name(v),
              )
            else
              Text(year.name),
            DefaultTextStyle(style: title, child: const Text('ترتيب السنة:')),
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
