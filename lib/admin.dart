import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:meetinghelper/utils/globals.dart';
import 'package:meetinghelper/utils/typedefs.dart';

import 'models/mini_models.dart';
import 'views/mini_lists/churches_list.dart';
import 'views/mini_lists/fathers_list.dart';
import 'views/mini_lists/study_years_list.dart';

class ChurchesPage extends StatefulWidget {
  const ChurchesPage({Key? key}) : super(key: key);

  @override
  _ChurchesPageState createState() => _ChurchesPageState();
}

class FathersPage extends StatefulWidget {
  const FathersPage({Key? key}) : super(key: key);

  @override
  _FathersPageState createState() => _FathersPageState();
}

class StudyYearsPage extends StatefulWidget {
  const StudyYearsPage({Key? key}) : super(key: key);

  @override
  _StudyYearsPageState createState() => _StudyYearsPageState();
}

class _ChurchesPageState extends State<ChurchesPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الكنائس'),
      ),
      floatingActionButton: FloatingActionButton(
          onPressed: () {
            churchTap(Church.createNew(), true);
          },
          child: const Icon(Icons.add)),
      body: ChurchesEditList(
        list: Church.getAllForUser(),
        tap: (_) => churchTap(_, false),
      ),
    );
  }

  void churchTap(Church church, bool editMode) async {
    final title = TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.bold,
        color: Theme.of(context).textTheme.headline6!.color,
        locale: const Locale('ar', 'EG'));
    // TextStyle subTitle = TextStyle(
    //     fontSize: 18,
    //     color: Theme.of(context).textTheme.subtitle2.color,
    //     locale: Locale('ar', 'EG'));
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        actions: <Widget>[
          TextButton(
              onPressed: () async {
                if (editMode) {
                  await FirebaseFirestore.instance
                      .collection('Churches')
                      .doc(church.id)
                      .set(church.getMap());
                }
                navigator.currentState!.pop();
                setState(() {
                  churchTap(church, !editMode);
                });
              },
              child: Text(editMode ? 'حفظ' : 'تعديل')),
          if (editMode)
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
                            await FirebaseFirestore.instance
                                .collection('Churches')
                                .doc(church.id)
                                .delete();
                            navigator.currentState!.pop();
                            navigator.currentState!.pop();
                            setState(() {
                              editMode = !editMode;
                            });
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
                child: const Text('حذف'))
        ],
        title: Text(church.name),
        scrollable: true,
        content: SizedBox(
          width: 300,
          height: 700,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              DefaultTextStyle(
                style: title,
                child: const Text('الاسم:'),
              ),
              if (editMode)
                TextField(
                  controller: TextEditingController(text: church.name),
                  onChanged: (v) => church.name = v,
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
                  onChanged: (v) => church.address = v,
                )
              else
                Text(church.address!),
              if (!editMode) Text('الأباء بالكنيسة:', style: title),
              if (!editMode)
                StreamBuilder<JsonQuery>(
                  stream: church.getMembersLive(),
                  builder: (con, data) {
                    if (data.hasData) {
                      return Expanded(
                        child: ListView.builder(
                          itemCount: data.data!.docs.length,
                          itemBuilder: (context, i) {
                            final current =
                                Father.fromQueryDoc(data.data!.docs[i]);
                            return Card(
                              child: ListTile(
                                onTap: () => fatherTap(current, false),
                                title: Text(current.name),
                              ),
                            );
                          },
                        ),
                      );
                    } else {
                      return const Center(child: CircularProgressIndicator());
                    }
                  },
                )
            ],
          ),
        ),
      ),
    );
  }

  void fatherTap(Father father, bool editMode) async {
    final title = TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.bold,
        color: Theme.of(context).textTheme.headline6!.color,
        locale: const Locale('ar', 'EG'));
    // TextStyle subTitle = TextStyle(
    //     fontSize: 18,
    //     color: Theme.of(context).textTheme.subtitle2.color,
    //     locale: Locale('ar', 'EG'));
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        actions: <Widget>[
          TextButton(
              onPressed: () async {
                if (editMode) {
                  await FirebaseFirestore.instance
                      .collection('Fathers')
                      .doc(father.id)
                      .set(father.getMap());
                }
                navigator.currentState!.pop();
                setState(() {
                  fatherTap(father, !editMode);
                });
              },
              child: Text(editMode ? 'حفظ' : 'تعديل')),
          if (editMode)
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
                            await FirebaseFirestore.instance
                                .collection('Fathers')
                                .doc(father.id)
                                .delete();
                            navigator.currentState!.pop();
                            navigator.currentState!.pop();
                            setState(() {
                              editMode = !editMode;
                            });
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
                child: const Text('حذف'))
        ],
        title: Text(father.name),
        content: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('الاسم:', style: title),
              if (editMode)
                TextField(
                  controller: TextEditingController(text: father.name),
                  onChanged: (v) => father.name = v,
                )
              else
                Text(father.name),
              Text('داخل كنيسة', style: title),
              if (editMode)
                FutureBuilder<JsonQuery>(
                  future: Church.getAllForUser(),
                  builder: (context, data) {
                    if (data.hasData) {
                      return Container(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: DropdownButtonFormField(
                          value: father.churchId?.path,
                          items: data.data!.docs
                              .map(
                                (item) => DropdownMenuItem(
                                  value: item.reference.path,
                                  child: Text(item.data()['Name']),
                                ),
                              )
                              .toList()
                            ..insert(
                              0,
                              const DropdownMenuItem(
                                value: null,
                                child: Text(''),
                              ),
                            ),
                          onChanged: (dynamic value) {
                            father.churchId =
                                FirebaseFirestore.instance.doc(value);
                          },
                          decoration: InputDecoration(
                            labelText: 'الكنيسة',
                            border: OutlineInputBorder(
                              borderSide: BorderSide(
                                  color: Theme.of(context).colorScheme.primary),
                            ),
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
                                  Church.fromDoc(await father.churchId!.get())!,
                                  false,
                                ),
                              ),
                            )
                          : const LinearProgressIndicator();
                    }),
            ],
          ),
        ),
      ),
    );
  }
}

class _FathersPageState extends State<FathersPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الأباء الكهنة'),
      ),
      floatingActionButton: FloatingActionButton(
          onPressed: () {
            fatherTap(Father.createNew(), true);
          },
          child: const Icon(Icons.add)),
      body: FathersEditList(
        list: Father.getAllForUser(),
        tap: (_) => fatherTap(_, false),
      ),
    );
  }

  void churchTap(Church church, bool editMode) async {
    final title = TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.bold,
        color: Theme.of(context).textTheme.headline6!.color,
        locale: const Locale('ar', 'EG'));
    // TextStyle subTitle = TextStyle(
    //     fontSize: 18,
    //     color: Theme.of(context).textTheme.subtitle2.color,
    //     locale: Locale('ar', 'EG'));
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        actions: <Widget>[
          TextButton(
              onPressed: () async {
                if (editMode) {
                  await FirebaseFirestore.instance
                      .collection('Churches')
                      .doc(church.id)
                      .set(church.getMap());
                }
                navigator.currentState!.pop();
                setState(() {
                  churchTap(church, !editMode);
                });
              },
              child: Text(editMode ? 'حفظ' : 'تعديل')),
          if (editMode)
            TextButton(
                onPressed: () async {
                  await showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                            title: Text(church.name),
                            content:
                                Text('هل أنت متأكد من حذف ${church.name}؟'),
                            actions: <Widget>[
                              TextButton(
                                onPressed: () async {
                                  await FirebaseFirestore.instance
                                      .collection('Churches')
                                      .doc(church.id)
                                      .delete();
                                  navigator.currentState!.pop();
                                  navigator.currentState!.pop();
                                  setState(() {
                                    editMode = !editMode;
                                  });
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
                          ));
                },
                child: const Text('حذف'))
        ],
        title: Text(church.name),
        scrollable: true,
        content: SizedBox(
          width: 300,
          height: 700,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              DefaultTextStyle(
                style: title,
                child: const Text('الاسم:'),
              ),
              if (editMode)
                TextField(
                  controller: TextEditingController(text: church.name),
                  onChanged: (v) => church.name = v,
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
                  onChanged: (v) => church.address = v,
                )
              else
                Text(church.address!),
              if (!editMode) Text('الأباء بالكنيسة:', style: title),
              if (!editMode)
                Expanded(
                  child: StreamBuilder<JsonQuery>(
                    stream: church.getMembersLive(),
                    builder: (con, data) {
                      if (data.hasData) {
                        return ListView.builder(
                            itemCount: data.data!.docs.length,
                            itemBuilder: (context, i) {
                              final current =
                                  Father.fromQueryDoc(data.data!.docs[i]);
                              return Card(
                                child: ListTile(
                                  onTap: () => fatherTap(current, false),
                                  title: Text(current.name),
                                ),
                              );
                            });
                      } else {
                        return const Center(child: CircularProgressIndicator());
                      }
                    },
                  ),
                )
            ],
          ),
        ),
      ),
    );
  }

  void fatherTap(Father father, bool editMode) async {
    final title = TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.bold,
        color: Theme.of(context).textTheme.headline6!.color,
        locale: const Locale('ar', 'EG'));
    // TextStyle subTitle = TextStyle(
    //     fontSize: 18,
    //     color: Theme.of(context).textTheme.subtitle2.color,
    //     locale: Locale('ar', 'EG'));
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        actions: <Widget>[
          TextButton(
              onPressed: () async {
                if (editMode) {
                  await FirebaseFirestore.instance
                      .collection('Fathers')
                      .doc(father.id)
                      .set(father.getMap());
                }
                navigator.currentState!.pop();
                setState(() {
                  fatherTap(father, !editMode);
                });
              },
              child: Text(editMode ? 'حفظ' : 'تعديل')),
          if (editMode)
            TextButton(
                onPressed: () async {
                  await showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                            title: Text(father.name),
                            content:
                                Text('هل أنت متأكد من حذف ${father.name}؟'),
                            actions: <Widget>[
                              TextButton(
                                onPressed: () async {
                                  await FirebaseFirestore.instance
                                      .collection('Fathers')
                                      .doc(father.id)
                                      .delete();
                                  navigator.currentState!.pop();
                                  navigator.currentState!.pop();
                                  setState(() {
                                    editMode = !editMode;
                                  });
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
                          ));
                },
                child: const Text('حذف'))
        ],
        title: Text(father.name),
        content: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('الاسم:', style: title),
              if (editMode)
                TextField(
                  controller: TextEditingController(text: father.name),
                  onChanged: (v) => father.name = v,
                )
              else
                Text(father.name),
              Text('داخل كنيسة', style: title),
              if (editMode)
                FutureBuilder<JsonQuery>(
                  future: Church.getAllForUser(),
                  builder: (context, data) {
                    if (data.hasData) {
                      return Container(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: DropdownButtonFormField(
                          value: father.churchId?.path,
                          items: data.data!.docs
                              .map(
                                (item) => DropdownMenuItem(
                                  value: item.reference.path,
                                  child: Text(item.data()['Name']),
                                ),
                              )
                              .toList()
                            ..insert(
                              0,
                              const DropdownMenuItem(
                                value: null,
                                child: Text(''),
                              ),
                            ),
                          onChanged: (dynamic value) {
                            father.churchId =
                                FirebaseFirestore.instance.doc(value);
                          },
                          decoration: InputDecoration(
                              labelText: 'الكنيسة',
                              border: OutlineInputBorder(
                                borderSide: BorderSide(
                                    color:
                                        Theme.of(context).colorScheme.primary),
                              )),
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
                                Church.fromDoc(await father.churchId!.get())!,
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
}

class _StudyYearsPageState extends State<StudyYearsPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('السنوات الدراسية'),
      ),
      floatingActionButton: FloatingActionButton(
          onPressed: () {
            studyYearTap(StudyYear.createNew(), true);
          },
          child: const Icon(Icons.add)),
      body: StudyYearsEditList(
        list: StudyYear.getAllForUser(),
        tap: (_) => studyYearTap(_, false),
      ),
    );
  }

  void studyYearTap(StudyYear year, bool editMode) async {
    final title = TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.bold,
        color: Theme.of(context).textTheme.headline6!.color,
        locale: const Locale('ar', 'EG'));
    // TextStyle subTitle = TextStyle(
    //     fontSize: 18,
    //     color: Theme.of(context).textTheme.subtitle2.color,
    //     locale: Locale('ar', 'EG'));
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        actions: <Widget>[
          TextButton(
              onPressed: () async {
                if (editMode) {
                  await FirebaseFirestore.instance
                      .collection('StudyYears')
                      .doc(year.id)
                      .set(year.getMap());
                }
                navigator.currentState!.pop();
                setState(() {
                  studyYearTap(year, !editMode);
                });
              },
              child: Text(editMode ? 'حفظ' : 'تعديل')),
          if (editMode)
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
                                  await FirebaseFirestore.instance
                                      .collection('StudyYears')
                                      .doc(year.id)
                                      .delete();
                                  navigator.currentState!.pop();
                                  navigator.currentState!.pop();
                                  setState(() {
                                    editMode = !editMode;
                                  });
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
                          ));
                },
                child: const Text('حذف'))
        ],
        title: Text(year.name),
        content: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              DefaultTextStyle(
                style: title,
                child: const Text('الاسم:'),
              ),
              if (editMode)
                TextField(
                  controller: TextEditingController(text: year.name),
                  onChanged: (v) => year.name = v,
                )
              else
                Text(year.name),
              DefaultTextStyle(
                style: title,
                child: const Text('ترتيب السنة:'),
              ),
              if (editMode)
                TextField(
                  keyboardType: TextInputType.number,
                  controller:
                      TextEditingController(text: year.grade.toString()),
                  onChanged: (v) => year.grade = int.parse(v),
                )
              else
                Text(year.grade.toString()),
            ],
          ),
        ),
      ),
    );
  }
}
