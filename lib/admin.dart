import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'models/mini_models.dart';
import 'models/search_string.dart';
import 'ui/mini_lists/ChurchesList.dart';
import 'ui/mini_lists/FathersList.dart';
import 'ui/mini_lists/SchoolsList.dart';
import 'ui/mini_lists/StudyYearsList.dart';
import 'ui/users_list.dart';

class ChurchesPage extends StatefulWidget {
  ChurchesPage({Key key}) : super(key: key);
  @override
  _ChurchesPageState createState() => _ChurchesPageState();
}

class SchoolsPage extends StatefulWidget {
  SchoolsPage({Key key}) : super(key: key);
  @override
  _SchoolsPageState createState() => _SchoolsPageState();
}

class FathersPage extends StatefulWidget {
  FathersPage({Key key}) : super(key: key);
  @override
  _FathersPageState createState() => _FathersPageState();
}

// class PersonTypesPage extends StatefulWidget {
//   PersonTypesPage({Key key}) : super(key: key);
//   @override
//   _PersonTypesPageState createState() => _PersonTypesPageState();
// }

// class ServingTypesPage extends StatefulWidget {
//   ServingTypesPage({Key key}) : super(key: key);
//   @override
//   _ServingTypesPageState createState() => _ServingTypesPageState();
// }

class StudyYearsPage extends StatefulWidget {
  StudyYearsPage({Key key}) : super(key: key);
  @override
  _StudyYearsPageState createState() => _StudyYearsPageState();
}

class UsersPage extends StatefulWidget {
  UsersPage({Key key}) : super(key: key);
  @override
  _UsersPageState createState() => _UsersPageState();
}

class _SchoolsPageState extends State<SchoolsPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('المدارس'),
      ),
      floatingActionButton: FloatingActionButton(
          onPressed: () {
            schoolTap(School.createNew(), true);
          },
          child: Icon(Icons.add)),
      body: SchoolsEditList(
        list: School.getAllForUser(),
        tap: (_) => schoolTap(_, false),
      ),
    );
  }

  void schoolTap(School school, bool editMode) async {
    var title = TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.bold,
        color: Theme.of(context).textTheme.headline6.color,
        locale: Locale('ar', 'EG'));
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
                      .collection('Schools')
                      .doc(school.id)
                      .set(school.getMap());
                }
                Navigator.of(context).pop();
                setState(() {
                  schoolTap(school, !editMode);
                });
              },
              child: Text(editMode ? 'حفظ' : 'تعديل')),
          if (editMode)
            TextButton(
                onPressed: () async {
                  await showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                            title: Text(school.name),
                            content:
                                Text('هل أنت متأكد من حذف ${school.name}؟'),
                            actions: <Widget>[
                              TextButton(
                                  child: Text('نعم'),
                                  onPressed: () async {
                                    await FirebaseFirestore.instance
                                        .collection('Schools')
                                        .doc(school.id)
                                        .delete();
                                    Navigator.of(context).pop();
                                    Navigator.of(context).pop();
                                    setState(() {
                                      editMode = !editMode;
                                    });
                                  }),
                              TextButton(
                                  child: Text('تراجع'),
                                  onPressed: () {
                                    Navigator.of(context).pop();
                                  }),
                            ],
                          ));
                },
                child: Text('حذف'))
        ],
        title: Text(school.name),
        content: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              DefaultTextStyle(
                style: title,
                child: Text('الاسم:'),
              ),
              editMode
                  ? TextField(
                      controller: TextEditingController(text: school.name),
                      onChanged: (v) => school.name = v,
                    )
                  : Text(school.name),
              DefaultTextStyle(
                style: title,
                child: Text('العنوان:'),
              ),
              editMode
                  ? TextField(
                      controller: TextEditingController(text: school.address),
                      onChanged: (v) => school.address = v,
                    )
                  : Text(school.address),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChurchesPageState extends State<ChurchesPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('الكنائس'),
      ),
      floatingActionButton: FloatingActionButton(
          onPressed: () {
            churchTap(Church.createNew(), true);
          },
          child: Icon(Icons.add)),
      body: ChurchesEditList(
        list: Church.getAllForUser(),
        tap: (_) => churchTap(_, false),
      ),
    );
  }

  void churchTap(Church church, bool editMode) async {
    var title = TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.bold,
        color: Theme.of(context).textTheme.headline6.color,
        locale: Locale('ar', 'EG'));
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
                Navigator.of(context).pop();
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
                                  child: Text('نعم'),
                                  onPressed: () async {
                                    await FirebaseFirestore.instance
                                        .collection('Churches')
                                        .doc(church.id)
                                        .delete();
                                    Navigator.of(context).pop();
                                    Navigator.of(context).pop();
                                    setState(() {
                                      editMode = !editMode;
                                    });
                                  }),
                              TextButton(
                                  child: Text('تراجع'),
                                  onPressed: () {
                                    Navigator.of(context).pop();
                                  }),
                            ],
                          ));
                },
                child: Text('حذف'))
        ],
        title: Text(church.name),
        content: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              DefaultTextStyle(
                style: title,
                child: Text('الاسم:'),
              ),
              editMode
                  ? TextField(
                      controller: TextEditingController(text: church.name),
                      onChanged: (v) => church.name = v,
                    )
                  : Text(church.name),
              DefaultTextStyle(
                style: title,
                child: Text('العنوان:'),
              ),
              editMode
                  ? TextField(
                      controller: TextEditingController(text: church.address),
                      onChanged: (v) => church.address = v,
                    )
                  : Text(church.address),
              if (!editMode) Text('الأباء بالكنيسة:', style: title),
              if (!editMode)
                FutureBuilder(
                  future: church.getMembersLive(),
                  builder: (context, widgetListData) {
                    return widgetListData.connectionState !=
                            ConnectionState.done
                        ? Container()
                        : StreamBuilder<QuerySnapshot>(
                            stream: widgetListData.data,
                            builder: (con, data) {
                              if (data.hasData) {
                                return ListView.builder(
                                    physics: ClampingScrollPhysics(),
                                    shrinkWrap: true,
                                    itemCount: data.data.docs.length,
                                    itemBuilder: (context, i) {
                                      var current =
                                          Father.fromDoc(data.data.docs[i]);
                                      return Card(
                                        child: ListTile(
                                          onTap: () =>
                                              fatherTap(current, false),
                                          title: Text(current.name),
                                        ),
                                      );
                                    });
                              } else {
                                return const Center(
                                    child: CircularProgressIndicator());
                              }
                            },
                          );
                  },
                )
            ],
          ),
        ),
      ),
    );
  }

  void fatherTap(Father father, bool editMode) async {
    var title = TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.bold,
        color: Theme.of(context).textTheme.headline6.color,
        locale: Locale('ar', 'EG'));
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
                Navigator.of(context).pop();
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
                                  child: Text('نعم'),
                                  onPressed: () async {
                                    await FirebaseFirestore.instance
                                        .collection('Fathers')
                                        .doc(father.id)
                                        .delete();
                                    Navigator.of(context).pop();
                                    Navigator.of(context).pop();
                                    setState(() {
                                      editMode = !editMode;
                                    });
                                  }),
                              TextButton(
                                  child: Text('تراجع'),
                                  onPressed: () {
                                    Navigator.of(context).pop();
                                  }),
                            ],
                          ));
                },
                child: Text('حذف'))
        ],
        title: Text(father.name),
        content: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('الاسم:', style: title),
              editMode
                  ? TextField(
                      controller: TextEditingController(text: father.name),
                      onChanged: (v) => father.name = v,
                    )
                  : Text(father.name),
              Text('داخل كنيسة', style: title),
              editMode
                  ? FutureBuilder<QuerySnapshot>(
                      future: Church.getAllForUser(),
                      builder: (context, data) {
                        if (data.hasData) {
                          return Container(
                            padding: EdgeInsets.symmetric(vertical: 4.0),
                            child: DropdownButtonFormField(
                              value: father.churchId?.path,
                              items: data.data.docs
                                  .map(
                                    (item) => DropdownMenuItem(
                                      child: Text(item.data()['Name']),
                                      value: item.reference.path,
                                    ),
                                  )
                                  .toList()
                                    ..insert(
                                      0,
                                      DropdownMenuItem(
                                        child: Text(''),
                                        value: null,
                                      ),
                                    ),
                              onChanged: (value) {
                                father.churchId =
                                    FirebaseFirestore.instance.doc(value);
                              },
                              decoration: InputDecoration(
                                  labelText: 'الكنيسة',
                                  border: OutlineInputBorder(
                                    borderSide: BorderSide(
                                        color: Theme.of(context).primaryColor),
                                  )),
                            ),
                          );
                        } else {
                          return LinearProgressIndicator();
                        }
                      },
                    )
                  : FutureBuilder(
                      future: father.getChurchName(),
                      builder: (con, name) {
                        return name.hasData
                            ? Card(
                                child: ListTile(
                                    title: Text(name.data),
                                    onTap: () async => churchTap(
                                        Church.fromDoc(
                                            await father.churchId.get()),
                                        false)))
                            : LinearProgressIndicator();
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
        title: Text('الأباء الكهنة'),
      ),
      floatingActionButton: FloatingActionButton(
          onPressed: () {
            fatherTap(Father.createNew(), true);
          },
          child: Icon(Icons.add)),
      body: FathersEditList(
        list: Father.getAllForUser(),
        tap: (_) => fatherTap(_, false),
      ),
    );
  }

  void churchTap(Church church, bool editMode) async {
    var title = TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.bold,
        color: Theme.of(context).textTheme.headline6.color,
        locale: Locale('ar', 'EG'));
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
                Navigator.of(context).pop();
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
                                  child: Text('نعم'),
                                  onPressed: () async {
                                    await FirebaseFirestore.instance
                                        .collection('Churches')
                                        .doc(church.id)
                                        .delete();
                                    Navigator.of(context).pop();
                                    Navigator.of(context).pop();
                                    setState(() {
                                      editMode = !editMode;
                                    });
                                  }),
                              TextButton(
                                  child: Text('تراجع'),
                                  onPressed: () {
                                    Navigator.of(context).pop();
                                  }),
                            ],
                          ));
                },
                child: Text('حذف'))
        ],
        title: Text(church.name),
        content: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              DefaultTextStyle(
                style: title,
                child: Text('الاسم:'),
              ),
              editMode
                  ? TextField(
                      controller: TextEditingController(text: church.name),
                      onChanged: (v) => church.name = v,
                    )
                  : Text(church.name),
              DefaultTextStyle(
                style: title,
                child: Text('العنوان:'),
              ),
              editMode
                  ? TextField(
                      controller: TextEditingController(text: church.address),
                      onChanged: (v) => church.address = v,
                    )
                  : Text(church.address),
              if (!editMode) Text('الأباء بالكنيسة:', style: title),
              if (!editMode)
                FutureBuilder(
                  future: church.getMembersLive(),
                  builder: (context, widgetListData) {
                    return widgetListData.connectionState !=
                            ConnectionState.done
                        ? Container()
                        : StreamBuilder<QuerySnapshot>(
                            stream: widgetListData.data,
                            builder: (con, data) {
                              if (data.hasData) {
                                return ListView.builder(
                                    physics: ClampingScrollPhysics(),
                                    shrinkWrap: true,
                                    itemCount: data.data.docs.length,
                                    itemBuilder: (context, i) {
                                      var current =
                                          Father.fromDoc(data.data.docs[i]);
                                      return Card(
                                        child: ListTile(
                                          onTap: () =>
                                              fatherTap(current, false),
                                          title: Text(current.name),
                                        ),
                                      );
                                    });
                              } else {
                                return const Center(
                                    child: CircularProgressIndicator());
                              }
                            },
                          );
                  },
                )
            ],
          ),
        ),
      ),
    );
  }

  void fatherTap(Father father, bool editMode) async {
    var title = TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.bold,
        color: Theme.of(context).textTheme.headline6.color,
        locale: Locale('ar', 'EG'));
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
                Navigator.of(context).pop();
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
                                  child: Text('نعم'),
                                  onPressed: () async {
                                    await FirebaseFirestore.instance
                                        .collection('Fathers')
                                        .doc(father.id)
                                        .delete();
                                    Navigator.of(context).pop();
                                    Navigator.of(context).pop();
                                    setState(() {
                                      editMode = !editMode;
                                    });
                                  }),
                              TextButton(
                                  child: Text('تراجع'),
                                  onPressed: () {
                                    Navigator.of(context).pop();
                                  }),
                            ],
                          ));
                },
                child: Text('حذف'))
        ],
        title: Text(father.name),
        content: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('الاسم:', style: title),
              editMode
                  ? TextField(
                      controller: TextEditingController(text: father.name),
                      onChanged: (v) => father.name = v,
                    )
                  : Text(father.name),
              Text('داخل كنيسة', style: title),
              editMode
                  ? FutureBuilder<QuerySnapshot>(
                      future: Church.getAllForUser(),
                      builder: (context, data) {
                        if (data.hasData) {
                          return Container(
                            padding: EdgeInsets.symmetric(vertical: 4.0),
                            child: DropdownButtonFormField(
                              value: father.churchId?.path,
                              items: data.data.docs
                                  .map(
                                    (item) => DropdownMenuItem(
                                      child: Text(item.data()['Name']),
                                      value: item.reference.path,
                                    ),
                                  )
                                  .toList()
                                    ..insert(
                                      0,
                                      DropdownMenuItem(
                                        child: Text(''),
                                        value: null,
                                      ),
                                    ),
                              onChanged: (value) {
                                father.churchId =
                                    FirebaseFirestore.instance.doc(value);
                              },
                              decoration: InputDecoration(
                                  labelText: 'الكنيسة',
                                  border: OutlineInputBorder(
                                    borderSide: BorderSide(
                                        color: Theme.of(context).primaryColor),
                                  )),
                            ),
                          );
                        } else {
                          return LinearProgressIndicator();
                        }
                      },
                    )
                  : FutureBuilder(
                      future: father.getChurchName(),
                      builder: (con, name) {
                        return name.hasData
                            ? Card(
                                child: ListTile(
                                    title: Text(name.data),
                                    onTap: () async => churchTap(
                                        Church.fromDoc(
                                            await father.churchId.get()),
                                        false)))
                            : LinearProgressIndicator();
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
        title: Text('السنوات الدراسية'),
      ),
      floatingActionButton: FloatingActionButton(
          onPressed: () {
            studyYearTap(StudyYear.createNew(), true);
          },
          child: Icon(Icons.add)),
      body: StudyYearsEditList(
        list: StudyYear.getAllForUser(),
        tap: (_) => studyYearTap(_, false),
      ),
    );
  }

  void studyYearTap(StudyYear year, bool editMode) async {
    var title = TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.bold,
        color: Theme.of(context).textTheme.headline6.color,
        locale: Locale('ar', 'EG'));
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
                Navigator.of(context).pop();
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
                                  child: Text('نعم'),
                                  onPressed: () async {
                                    await FirebaseFirestore.instance
                                        .collection('StudyYears')
                                        .doc(year.id)
                                        .delete();
                                    Navigator.of(context).pop();
                                    Navigator.of(context).pop();
                                    setState(() {
                                      editMode = !editMode;
                                    });
                                  }),
                              TextButton(
                                  child: Text('تراجع'),
                                  onPressed: () {
                                    Navigator.of(context).pop();
                                  }),
                            ],
                          ));
                },
                child: Text('حذف'))
        ],
        title: Text(year.name),
        content: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              DefaultTextStyle(
                style: title,
                child: Text('الاسم:'),
              ),
              editMode
                  ? TextField(
                      controller: TextEditingController(text: year.name),
                      onChanged: (v) => year.name = v,
                    )
                  : Text(year.name),
              DefaultTextStyle(
                style: title,
                child: Text('ترتيب السنة:'),
              ),
              editMode
                  ? TextField(
                      keyboardType: TextInputType.number,
                      controller:
                          TextEditingController(text: year.grade.toString()),
                      onChanged: (v) => year.grade = int.parse(v),
                    )
                  : Text(year.grade.toString()),
            ],
          ),
        ),
      ),
    );
  }
}

class _UsersPageState extends State<UsersPage> {
  bool _showSearch = false;

  @override
  Widget build(BuildContext context) {
    return ListenableProvider<SearchString>(
      create: (_) => SearchString(''),
      builder: (context, child) => Scaffold(
        appBar: AppBar(
          actions: [
            if (!_showSearch)
              IconButton(
                  icon: Icon(Icons.search),
                  onPressed: () => setState(() => _showSearch = true)),
          ],
          title: _showSearch
              ? TextField(
                  decoration: InputDecoration(
                      suffixIcon: IconButton(
                        icon: Icon(Icons.close),
                        onPressed: () => setState(
                          () {
                            context.read<SearchString>().value = '';
                            _showSearch = false;
                          },
                        ),
                      ),
                      hintStyle: Theme.of(context).primaryTextTheme.headline6,
                      hintText: 'بحث ...'),
                  onChanged: (t) => context.read<SearchString>().value = t,
                )
              : Text('المستخدمون'),
        ),
        body: Builder(
          builder: (context) => Padding(
            padding: const EdgeInsets.all(8.0),
            child: UsersEditList(),
          ),
        ),
      ),
    );
  }
}
