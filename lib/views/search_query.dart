import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:meetinghelper/models/list_controllers.dart';
import 'package:meetinghelper/utils/typedefs.dart';
import 'package:rxdart/rxdart.dart';
import 'package:share_plus/share_plus.dart';

import '../models/mini_models.dart';
import '../models/models.dart';
import '../models/order_options.dart';
import '../models/search_filters.dart';
import '../models/user.dart';
import '../utils/globals.dart';
import '../utils/helpers.dart';
import 'list.dart';
import 'mini_lists/colors_list.dart';

class SearchQuery extends StatefulWidget {
  final Json? query;

  const SearchQuery({Key? key, this.query}) : super(key: key);

  @override
  _SearchQueryState createState() => _SearchQueryState();
}

class _SearchQueryState extends State<SearchQuery> {
  static int? parentIndex = 0;
  static int childIndex = 0;
  static int? operatorIndex = 0;

  static dynamic queryValue = '';
  static String? queryText = '';
  static bool birthDate = false;

  bool? descending = false;
  String? orderBy = 'Name';

  List<DropdownMenuItem> operatorItems = const [
    DropdownMenuItem(value: 0, child: Text('=')),
    DropdownMenuItem(value: 1, child: Text('قائمة تحتوي على')),
    DropdownMenuItem(value: 2, child: Text('أكبر من')),
    DropdownMenuItem(
      value: 3,
      child: Text('أصغر من'),
    ),
  ];

  List<List<DropdownMenuItem>> childItems = const [
    <DropdownMenuItem>[
      DropdownMenuItem(
        value: MapEntry(1, 'Name'),
        child: Text('اسم الفصل'),
      ),
      DropdownMenuItem(
        value: MapEntry(10, 'StudyYear'),
        child: Text('السنة الدراسية'),
      ),
      DropdownMenuItem(
        value: MapEntry(
          14,
          'Color',
        ),
        child: Text('اللون'),
      ),
    ],
    <DropdownMenuItem>[
      DropdownMenuItem(
        value: MapEntry(
          1,
          'Name',
        ),
        child: Text('اسم المخدوم'),
      ),
      DropdownMenuItem(
        value: MapEntry(
          1,
          'Phone',
        ),
        child: Text('رقم الهاتف'),
      ),
      DropdownMenuItem(
        value: MapEntry(
          11,
          'BirthDate',
        ),
        child: Text('تاريخ الميلاد'),
      ),
      DropdownMenuItem(
        value: MapEntry(
          6,
          'Type',
        ),
        child: Text('نوع الفرد'),
      ),
      DropdownMenuItem(
        value: MapEntry(
          7,
          'School',
        ),
        child: Text('المدرسة'),
      ),
      DropdownMenuItem(
        value: MapEntry(
          8,
          'Church',
        ),
        child: Text('الكنيسة'),
      ),
      DropdownMenuItem(
        value: MapEntry(
          1,
          'Meeting',
        ),
        child: Text('الاجتماع المشارك به'),
      ),
      DropdownMenuItem(
        value: MapEntry(
          9,
          'CFather',
        ),
        child: Text('اب الاعتراف'),
      ),
      DropdownMenuItem(
        value: MapEntry(
          0,
          'LastTanawol',
        ),
        child: Text('أخر تناول'),
      ),
      DropdownMenuItem(
        value: MapEntry(
          0,
          'LastConfession',
        ),
        child: Text('أخر اعتراف'),
      ),
      DropdownMenuItem(
        value: MapEntry(
          0,
          'LastKodas',
        ),
        child: Text('تاريخ حضور أخر قداس'),
      ),
      DropdownMenuItem(
        value: MapEntry(
          0,
          'LastMeeting',
        ),
        child: Text('تاريخ حضور أخر اجتماع'),
      ),
      DropdownMenuItem(
        value: MapEntry(
          1,
          'Notes',
        ),
        child: Text('ملاحظات'),
      ),
      DropdownMenuItem(
        value: MapEntry(
          2,
          'ClassId',
        ),
        child: Text('داخل فصل'),
      ),
      DropdownMenuItem(
        value: MapEntry(
          14,
          'Color',
        ),
        child: Text('اللون'),
      ),
    ],
  ];

  List<dynamic> defaultValues = [
    Timestamp.fromMillisecondsSinceEpoch(DateTime.now().millisecondsSinceEpoch -
        (DateTime.now().millisecondsSinceEpoch % Duration.millisecondsPerDay)),
    '',
    null,
    null,
    null,
    false,
    null,
    null,
    null,
    null,
    null,
    Timestamp.fromMillisecondsSinceEpoch(DateTime.now().millisecondsSinceEpoch -
        (DateTime.now().millisecondsSinceEpoch % Duration.millisecondsPerDay)),
    null,
    null,
    0,
    null,
  ];

  @override
  Widget build(BuildContext context) {
    var equal = IndexedStack(
      alignment: AlignmentDirectional.center,
      index: getWidgetIndex(),
      children: <Widget>[
        GestureDetector(
          onTap: _selectDate,
          child: InputDecorator(
            decoration: InputDecoration(
                labelText: 'اختيار تاريخ',
                border: OutlineInputBorder(
                  borderSide: BorderSide(color: Theme.of(context).primaryColor),
                )),
            child: Text(DateFormat('yyyy/M/d').format(queryValue is Timestamp
                ? (queryValue as Timestamp).toDate()
                : DateTime.now())),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: TextFormField(
            autofocus: false,
            decoration: InputDecoration(
                labelText: 'قيمة',
                border: OutlineInputBorder(
                  borderSide: BorderSide(color: Theme.of(context).primaryColor),
                )),
            textInputAction: TextInputAction.done,
            initialValue: queryText is String ? queryText : '',
            onChanged: queryTextChange,
            onFieldSubmitted: (_) => execute(),
            validator: (value) {
              return null;
            },
          ),
        ),
        GestureDetector(
          onTap: _selectClass,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: InputDecorator(
              decoration: InputDecoration(
                  labelText: 'اختيار فصل',
                  border: OutlineInputBorder(
                    borderSide:
                        BorderSide(color: Theme.of(context).primaryColor),
                  )),
              child: Text(queryValue != null && queryValue is JsonRef
                  ? queryText!
                  : 'اختيار فصل'),
            ),
          ),
        ),
        Container(),
        Container(),
        Switch(
            //5
            value: queryValue == true ? true : false,
            onChanged: (v) {
              setState(() {
                queryText = v ? 'نعم' : 'لا';
                queryValue = v;
              });
            }),
        Container(),
        // GestureDetector(
        //   onTap: _selectType,
        //   child: Container(
        //     padding: const EdgeInsets.symmetric(vertical: 4.0),
        //     child: InputDecorator(
        //       decoration: InputDecoration(
        //           labelText: 'اختيار نوع الفرد',
        //           border: OutlineInputBorder(
        //             borderSide: BorderSide(color: Theme.of(context).primaryColor),
        //           )),
        //       child: Text(queryValue != null && queryValue is JsonRef
        //           ? queryText
        //           : 'اختيار نوع الفرد'),
        //     ),
        //   ),
        // ),
        FutureBuilder<JsonQuery>(
            //7
            future: School.getAllForUser(),
            builder: (context, data) {
              if (data.hasData) {
                return DropdownButtonFormField(
                  value: queryValue != null &&
                          queryValue is JsonRef &&
                          queryValue.path.startsWith('Schools/')
                      ? queryValue.path
                      : null,
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
                  onChanged: (dynamic value) async {
                    queryValue = FirebaseFirestore.instance.doc(value);
                    queryText = (await FirebaseFirestore.instance
                            .doc(value)
                            .get(dataSource))
                        .data()!['Name'];
                  },
                  decoration: const InputDecoration(labelText: 'المدرسة'),
                );
              }
              return const LinearProgressIndicator();
            }),
        FutureBuilder<JsonQuery>(
            //8
            future: Church.getAllForUser(),
            builder: (context, data) {
              if (data.hasData) {
                return DropdownButtonFormField(
                  value: queryValue != null &&
                          queryValue is JsonRef &&
                          queryValue.path.startsWith('Churches/')
                      ? queryValue.path
                      : null,
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
                  onChanged: (dynamic value) async {
                    queryValue = FirebaseFirestore.instance.doc(value);
                    queryText = (await FirebaseFirestore.instance
                            .doc(value)
                            .get(dataSource))
                        .data()!['Name'];
                  },
                  decoration: const InputDecoration(labelText: 'الكنيسة'),
                );
              }
              return const LinearProgressIndicator();
            }),
        FutureBuilder<JsonQuery>(
            //9
            future: Father.getAllForUser(),
            builder: (context, data) {
              if (data.hasData) {
                return DropdownButtonFormField(
                  value: queryValue != null &&
                          queryValue is JsonRef &&
                          queryValue.path.startsWith('Fathers/')
                      ? queryValue.path
                      : null,
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
                  onChanged: (dynamic value) async {
                    queryValue = FirebaseFirestore.instance.doc(value);
                    queryText = (await FirebaseFirestore.instance
                            .doc(value)
                            .get(dataSource))
                        .data()!['Name'];
                  },
                  decoration: const InputDecoration(labelText: 'اب الاعتراف'),
                );
              }
              return const LinearProgressIndicator();
            }),
        FutureBuilder<JsonQuery>(
            //10
            future: StudyYear.getAllForUser(),
            builder: (context, data) {
              if (data.hasData) {
                return DropdownButtonFormField(
                  value: queryValue != null &&
                          queryValue is JsonRef &&
                          queryValue.path.startsWith('StudyYears/')
                      ? queryValue.path
                      : null,
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
                  onChanged: (dynamic value) async {
                    queryValue = FirebaseFirestore.instance.doc(value);
                    queryText = (await FirebaseFirestore.instance
                            .doc(value)
                            .get(dataSource))
                        .data()!['Name'];
                  },
                  decoration: const InputDecoration(labelText: 'سنة الدراسة'),
                );
              }
              return const LinearProgressIndicator();
            }),
        Column(
          children: <Widget>[
            GestureDetector(
              //11
              onTap: _selectDate,
              child: InputDecorator(
                decoration: InputDecoration(
                    labelText: 'اختيار تاريخ',
                    border: OutlineInputBorder(
                      borderSide:
                          BorderSide(color: Theme.of(context).primaryColor),
                    )),
                child: Text(DateFormat('yyyy/M/d').format(
                    queryValue != null && queryValue is Timestamp
                        ? (queryValue as Timestamp).toDate()
                        : DateTime.now())),
              ),
            ),
            Row(
              children: <Widget>[
                const Text('بحث باليوم والشهر فقط'),
                Switch(
                  value: !(birthDate == true),
                  onChanged: (v) => setState(() {
                    birthDate = !v;
                  }),
                ),
              ],
            ),
            Row(
              children: <Widget>[
                const Text('(تاريخ فارغ)'),
                Switch(
                  value: queryValue == null,
                  onChanged: (v) => setState(() {
                    if (v) {
                      queryValue = null;
                      queryText = 'فارغ';
                    } else {
                      var now = DateTime.now().millisecondsSinceEpoch;
                      queryValue = Timestamp.fromMillisecondsSinceEpoch(
                          now - (now % 86400000));
                      queryText = '';
                    }
                  }),
                ),
              ],
            ),
          ],
        ),
        // StreamBuilder<JsonQuery>(
        //   //12
        //   stream: FirebaseFirestore.instance
        //       .collection('States')
        //       .orderBy('Name')
        //       .snapshots().map((s)=>s.docs.map(Person.fromDoc).toList()),
        //   builder: (context, data) {
        //     if (data.hasData) {
        //       return DropdownButtonFormField(
        //         value: (queryValue != null &&
        //                 queryValue is JsonRef &&
        //                 queryValue.path.startsWith('States/')
        //             ? queryValue.path
        //             : null),
        //         items: data.data.docs
        //             .map(
        //               (item) => DropdownMenuItem(
        //                   child: Row(
        //                     mainAxisSize: MainAxisSize.min,
        //                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
        //                     children: <Widget>[
        //                       Text(item.data()['Name']),
        //                       Container(
        //                         height: 50,
        //                         width: 50,
        //                         color: Color(
        //                             int.parse("0xff${item.data()['Color']}")),
        //                       )
        //                     ],
        //                   ),
        //                   value: item.reference.path),
        //             )
        //             .toList()
        //               ..insert(
        //                 0,
        //                 DropdownMenuItem(
        //                   child: Text(''),
        //                   value: null,
        //                 ),
        //               ),
        //         onChanged: (value) async {
        //           queryValue = FirebaseFirestore.instance.doc(value);
        //           queryText = (await FirebaseFirestore.instance
        //                   .doc(value)
        //                   .get(dataSource))
        //               .data()['Name'];
        //         },
        //         decoration: InputDecoration(
        //             labelText: 'الحالة',
        //             border: OutlineInputBorder(
        //               borderSide: BorderSide(color: Theme.of(context).primaryColor),
        //             )),
        //       );
        //     } else
        //       return Container(width: 1, height: 1);
        //   },
        // ),
        Container(),
        Container(),
        // StreamBuilder<JsonQuery>(
        //     //13
        //     stream: FirebaseFirestore.instance
        //         .collection('ServingTypes')
        //         .orderBy('Name')
        //         .snapshots().map((s)=>s.docs.map(Person.fromDoc).toList()),
        //     builder: (context, data) {
        //       if (data.hasData) {
        //         return DropdownButtonFormField(
        //           value: (queryValue != null &&
        //                   queryValue is JsonRef &&
        //                   queryValue.path.startsWith('ServingTypes/')
        //               ? queryValue.path
        //               : null),
        //           items: data.data.docs
        //               .map(
        //                 (item) => DropdownMenuItem(
        //                   child: Text(item.data()['Name']),
        //                   value: item.reference.path,
        //                 ),
        //               )
        //               .toList()
        //                 ..insert(
        //                   0,
        //                   DropdownMenuItem(
        //                     child: Text(''),
        //                     value: null,
        //                   ),
        //                 ),
        //           onChanged: (value) async {
        //             queryValue = FirebaseFirestore.instance.doc(value);
        //             queryText = (await FirebaseFirestore.instance
        //                     .doc(value)
        //                     .get(dataSource))
        //                 .data()['Name'];
        //           },
        //           decoration: InputDecoration(labelText: 'نوع الخدمة'),
        //         );
        //       }
        //       return const LinearProgressIndicator();
        //     }),
        ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              primary: Color(
                  queryValue is int ? queryValue : Colors.transparent.value),
            ),
            icon: const Icon(Icons.color_lens),
            label: const Text('اختيار لون'),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  actions: [
                    TextButton(
                      onPressed: () {
                        navigator.currentState!.pop();
                        setState(() {
                          queryValue = Colors.transparent.value;
                        });
                      },
                      child: const Text('بلا لون'),
                    ),
                  ],
                  content: ColorsList(
                    selectedColor: Color(queryValue is int
                        ? queryValue
                        : Colors.transparent.value),
                    onSelect: (color) {
                      navigator.currentState!.pop();
                      setState(() {
                        queryValue = color.value;
                      });
                    },
                  ),
                ),
              );
            }),
        StreamBuilder<JsonQuery>(
            //15
            stream: FirebaseFirestore.instance
                .collection('Colleges')
                .orderBy('Name')
                .snapshots(),
            builder: (context, data) {
              if (data.hasData) {
                return DropdownButtonFormField(
                  value: queryValue != null &&
                          queryValue is JsonRef &&
                          queryValue.path.startsWith('Colleges/')
                      ? queryValue.path
                      : null,
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
                  onChanged: (dynamic value) async {
                    queryValue = FirebaseFirestore.instance.doc(value);
                    queryText = (await FirebaseFirestore.instance
                            .doc(value)
                            .get(dataSource))
                        .data()!['Name'];
                  },
                  decoration: const InputDecoration(labelText: 'الكلية'),
                );
              }
              return const LinearProgressIndicator();
            }),
      ],
    );
    return Scaffold(
      appBar: AppBar(
        title: const Text('بحث مفصل'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                const Text('عرض كل: '),
                DropdownButton(
                  items: const [
                    DropdownMenuItem(value: 0, child: Text('الفصول')),
                    DropdownMenuItem(value: 1, child: Text('المخدومين')),
                  ],
                  value: parentIndex,
                  onChanged: parentChanged,
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                const Text('حيث أن: '),
                Expanded(
                  child: DropdownButton(
                      isExpanded: true,
                      items: childItems[parentIndex!],
                      onChanged: childChange,
                      value: childItems[parentIndex!][childIndex].value),
                ),
                Expanded(
                  child: DropdownButton(
                    isExpanded: true,
                    items: operatorItems,
                    onChanged: operatorChange,
                    value: operatorIndex,
                  ),
                ),
              ],
            ),
            equal,
            Row(
              children: <Widget>[
                const Text('ترتيب حسب:'),
                Expanded(
                  child: DropdownButton(
                    isExpanded: true,
                    value: orderBy,
                    items: getOrderByItems(),
                    onChanged: (dynamic value) {
                      setState(() {
                        orderBy = value;
                      });
                    },
                  ),
                ),
                Expanded(
                  child: DropdownButton(
                    isExpanded: true,
                    value: descending,
                    items: [
                      const DropdownMenuItem(
                        value: false,
                        child: Text('تصاعدي'),
                      ),
                      const DropdownMenuItem(
                        value: true,
                        child: Text('تنازلي'),
                      ),
                    ],
                    onChanged: (dynamic value) {
                      setState(() {
                        descending = value;
                      });
                    },
                  ),
                ),
              ],
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.done),
              onPressed: execute,
              label: const Text('تنفيذ'),
            )
          ],
        ),
      ),
    );
  }

  void childChange(value) {
    setState(() {
      childIndex = childItems[parentIndex!].indexOf(
        childItems[parentIndex!].firstWhere((e) => e.value == value),
      );
      queryValue = defaultValues[getWidgetIndex()!];
    });
  }

  void execute() async {
    late final DataObjectList body;
    Query<Json> classes = FirebaseFirestore.instance.collection('Classes');
    Query<Json> persons = FirebaseFirestore.instance.collection('Persons');

    bool fewClasses = true;
    if (!User.instance.superAccess) {
      final allowed =
          (await Class.getAllForUser().first).map((e) => e.ref).toList();
      classes = classes.where('Allowed', arrayContains: User.instance.uid);
      if (allowed.length <= 10) {
        persons = persons.where('ClassId', whereIn: allowed);
      } else {
        fewClasses = false;
      }
    }
    switch (operatorIndex) {
      case 0:
        if (parentIndex == 0) {
          body = DataObjectList<Class>(
            disposeController: false,
            options: DataObjectListController<Class>(
              tap: classTap,
              itemsStream: classes
                  .where(childItems[parentIndex!][childIndex].value.value,
                      isEqualTo: queryValue,
                      isNull: queryValue == null ? true : null)
                  .snapshots()
                  .map((s) => s.docs.map(Class.fromQueryDoc).toList()),
            ),
          );
          break;
        }
        if (!birthDate && childIndex == 2) {
          body = DataObjectList<Person>(
            disposeController: false,
            options: DataObjectListController<Person>(
              tap: personTap,
              itemsStream: fewClasses
                  ? persons
                      .where('BirthDay',
                          isGreaterThanOrEqualTo: queryValue != null
                              ? Timestamp.fromDate(
                                  DateTime(1970, queryValue.toDate().month,
                                      queryValue.toDate().day),
                                )
                              : null)
                      .where('BirthDay',
                          isLessThan: queryValue != null
                              ? Timestamp.fromDate(
                                  DateTime(1970, queryValue.toDate().month,
                                      queryValue.toDate().day + 1),
                                )
                              : null)
                      .snapshots()
                      .map((s) => s.docs.map(Person.fromQueryDoc).toList())
                  : Class.getAllForUser().switchMap(
                      (cs) => Rx.combineLatestList(cs.split(10).map((c) =>
                          persons
                              .where('ClassId',
                                  whereIn: c.map((c) => c.ref).toList())
                              .where('BirthDay',
                                  isGreaterThanOrEqualTo: queryValue != null
                                      ? Timestamp.fromDate(
                                          DateTime(
                                              1970,
                                              queryValue.toDate().month,
                                              queryValue.toDate().day),
                                        )
                                      : null)
                              .where('BirthDay',
                                  isLessThan: queryValue != null
                                      ? Timestamp.fromDate(
                                          DateTime(
                                              1970,
                                              queryValue.toDate().month,
                                              queryValue.toDate().day + 1),
                                        )
                                      : null)
                              .snapshots())).map(
                        (s) => s
                            .expand(
                              (e) => e.docs,
                            )
                            .map(Person.fromQueryDoc)
                            .toList(),
                      ),
                    ),
            ),
          );
          break;
        }
        body = DataObjectList<Person>(
          disposeController: false,
          options: DataObjectListController<Person>(
            tap: personTap,
            itemsStream: fewClasses
                ? persons
                    .where(childItems[parentIndex!][childIndex].value.value,
                        isEqualTo: queryValue,
                        isNull: queryValue == null ? true : null)
                    .snapshots()
                    .map((s) => s.docs.map(Person.fromQueryDoc).toList())
                : Class.getAllForUser()
                    .switchMap((cs) => Rx.combineLatestList(cs.split(10).map(
                        (c) => persons
                            .where('ClassId',
                                whereIn: c.map((c) => c.ref).toList())
                            .where(
                                childItems[parentIndex!][childIndex]
                                    .value
                                    .value,
                                isEqualTo: queryValue,
                                isNull: queryValue == null ? true : null)
                            .snapshots())))
                    .map(
                      (s) => s
                          .expand(
                            (e) => e.docs,
                          )
                          .map(Person.fromQueryDoc)
                          .toList(),
                    ),
          ),
        );
        break;
      case 1:
        if (parentIndex == 0) {
          body = DataObjectList<Class>(
            disposeController: false,
            options: DataObjectListController<Class>(
              tap: classTap,
              itemsStream: classes
                  .where(childItems[parentIndex!][childIndex].value.value,
                      arrayContains: queryValue)
                  .snapshots()
                  .map((s) => s.docs.map(Class.fromQueryDoc).toList()),
            ),
          );
          break;
        }
        if (!birthDate && childIndex == 2) {
          body = DataObjectList<Person>(
            disposeController: false,
            options: DataObjectListController<Person>(
              tap: personTap,
              itemsStream: fewClasses
                  ? persons
                      .where('BirthDay',
                          arrayContains: queryValue != null
                              ? Timestamp.fromDate(DateTime(
                                  1970,
                                  queryValue.toDate().month,
                                  queryValue.toDate().day))
                              : null)
                      .snapshots()
                      .map((s) => s.docs.map(Person.fromQueryDoc).toList())
                  : Class.getAllForUser().switchMap(
                      (cs) => Rx.combineLatestList(cs.split(10).map((c) =>
                          persons
                              .where('ClassId',
                                  whereIn: c.map((c) => c.ref).toList())
                              .where('BirthDay',
                                  arrayContains: queryValue != null
                                      ? Timestamp.fromDate(DateTime(
                                          1970,
                                          queryValue.toDate().month,
                                          queryValue.toDate().day))
                                      : null)
                              .snapshots())).map(
                        (s) => s
                            .expand(
                              (e) => e.docs,
                            )
                            .map(Person.fromQueryDoc)
                            .toList(),
                      ),
                    ),
            ),
          );
          break;
        }
        body = DataObjectList<Person>(
          disposeController: false,
          options: DataObjectListController<Person>(
            tap: personTap,
            itemsStream: fewClasses
                ? persons
                    .where(childItems[parentIndex!][childIndex].value.value,
                        arrayContains: queryValue)
                    .snapshots()
                    .map((s) => s.docs.map(Person.fromQueryDoc).toList())
                : Class.getAllForUser().switchMap(
                    (cs) => Rx.combineLatestList(cs.split(10).map((c) => persons
                        .where('ClassId', whereIn: c.map((c) => c.ref).toList())
                        .where(childItems[parentIndex!][childIndex].value.value,
                            arrayContains: queryValue)
                        .snapshots())).map(
                      (s) => s
                          .expand(
                            (e) => e.docs,
                          )
                          .map(Person.fromQueryDoc)
                          .toList(),
                    ),
                  ),
          ),
        );
        break;
      case 2:
        if (parentIndex == 0) {
          body = DataObjectList<Class>(
            disposeController: false,
            options: DataObjectListController<Class>(
                tap: classTap,
                itemsStream: classes
                    .where(childItems[parentIndex!][childIndex].value.value,
                        isGreaterThanOrEqualTo: queryValue)
                    .snapshots()
                    .map((s) => s.docs.map(Class.fromQueryDoc).toList())),
          );
          break;
        }
        if (!birthDate && childIndex == 2) {
          body = DataObjectList<Person>(
            disposeController: false,
            options: DataObjectListController<Person>(
              tap: personTap,
              itemsStream: fewClasses
                  ? persons
                      .where('BirthDay',
                          isGreaterThanOrEqualTo: queryValue != null
                              ? Timestamp.fromDate(DateTime(
                                  1970,
                                  queryValue.toDate().month,
                                  queryValue.toDate().day))
                              : null)
                      .snapshots()
                      .map((s) => s.docs.map(Person.fromQueryDoc).toList())
                  : Class.getAllForUser()
                      .switchMap((cs) => Rx.combineLatestList(cs.split(10).map(
                          (c) => persons
                              .where('ClassId',
                                  whereIn: c.map((c) => c.ref).toList())
                              .where('BirthDay',
                                  isGreaterThanOrEqualTo: queryValue != null
                                      ? Timestamp.fromDate(
                                          DateTime(1970, queryValue.toDate().month, queryValue.toDate().day))
                                      : null)
                              .snapshots())))
                      .map(
                        (s) => s
                            .expand(
                              (e) => e.docs,
                            )
                            .map(Person.fromQueryDoc)
                            .toList(),
                      ),
            ),
          );
          break;
        }
        body = DataObjectList<Person>(
          disposeController: false,
          options: DataObjectListController<Person>(
            tap: personTap,
            itemsStream: fewClasses
                ? persons
                    .where(childItems[parentIndex!][childIndex].value.value,
                        isGreaterThanOrEqualTo: queryValue)
                    .snapshots()
                    .map((s) => s.docs.map(Person.fromQueryDoc).toList())
                : Class.getAllForUser().switchMap(
                    (cs) => Rx.combineLatestList(cs.split(10).map((c) => persons
                        .where('ClassId', whereIn: c.map((c) => c.ref).toList())
                        .where(childItems[parentIndex!][childIndex].value.value,
                            isGreaterThanOrEqualTo: queryValue)
                        .snapshots())).map(
                      (s) => s
                          .expand(
                            (e) => e.docs,
                          )
                          .map(Person.fromQueryDoc)
                          .toList(),
                    ),
                  ),
          ),
        );
        break;
      case 3:
        if (parentIndex == 0) {
          body = DataObjectList<Class>(
            disposeController: false,
            options: DataObjectListController<Class>(
              tap: classTap,
              itemsStream: classes
                  .where(childItems[parentIndex!][childIndex].value.value,
                      isLessThanOrEqualTo: queryValue)
                  .snapshots()
                  .map((s) => s.docs.map(Class.fromQueryDoc).toList()),
            ),
          );
          break;
        }
        if (!birthDate && childIndex == 2) {
          body = DataObjectList<Person>(
            disposeController: false,
            options: DataObjectListController<Person>(
              tap: personTap,
              itemsStream: fewClasses
                  ? persons
                      .where('BirthDay',
                          isLessThanOrEqualTo: queryValue != null
                              ? Timestamp.fromDate(DateTime(
                                  1970,
                                  queryValue.toDate().month,
                                  queryValue.toDate().day))
                              : null)
                      .snapshots()
                      .map((s) => s.docs.map(Person.fromQueryDoc).toList())
                  : Class.getAllForUser().switchMap(
                      (cs) => Rx.combineLatestList(cs.split(10).map((c) =>
                          persons
                              .where('ClassId',
                                  whereIn: c.map((c) => c.ref).toList())
                              .where('BirthDay',
                                  isLessThanOrEqualTo: queryValue != null
                                      ? Timestamp.fromDate(DateTime(
                                          1970,
                                          queryValue.toDate().month,
                                          queryValue.toDate().day))
                                      : null)
                              .snapshots())).map(
                        (s) => s
                            .expand(
                              (e) => e.docs,
                            )
                            .map(Person.fromQueryDoc)
                            .toList(),
                      ),
                    ),
            ),
          );
          break;
        }
        body = DataObjectList<Person>(
          disposeController: false,
          options: DataObjectListController<Person>(
            tap: personTap,
            itemsStream: fewClasses
                ? persons
                    .where(childItems[parentIndex!][childIndex].value.value,
                        isLessThanOrEqualTo: queryValue)
                    .snapshots()
                    .map((s) => s.docs.map(Person.fromQueryDoc).toList())
                : Class.getAllForUser().switchMap(
                    (cs) => Rx.combineLatestList(cs.split(10).map((c) => persons
                        .where('ClassId', whereIn: c.map((c) => c.ref).toList())
                        .where(childItems[parentIndex!][childIndex].value.value,
                            isLessThanOrEqualTo: queryValue)
                        .snapshots())).map(
                      (s) => s
                          .expand(
                            (e) => e.docs,
                          )
                          .map(Person.fromQueryDoc)
                          .toList(),
                    ),
                  ),
          ),
        );
        break;
    }
    await navigator.currentState!.push(
      MaterialPageRoute(
        builder: (context) {
          return Scaffold(
            appBar: AppBar(
              actions: <Widget>[
                IconButton(
                  icon: const Icon(Icons.share),
                  onPressed: () async {
                    await Share.share(
                      await shareQuery({
                        'parentIndex': parentIndex.toString(),
                        'childIndex': childIndex.toString(),
                        'operatorIndex': operatorIndex.toString(),
                        'queryValue': queryValue is JsonRef
                            ? 'D' + (queryValue as JsonRef).path
                            : (queryValue is Timestamp
                                ? 'T' +
                                    (queryValue as Timestamp)
                                        .millisecondsSinceEpoch
                                        .toString()
                                : (queryValue is int
                                    ? 'I' + queryValue.toString()
                                    : 'S' + queryValue.toString())),
                        'queryText': queryText,
                        'birthDate': birthDate.toString(),
                        'descending': descending.toString(),
                        'orderBy': orderBy
                      }),
                    );
                  },
                  tooltip: 'مشاركة النتائج برابط',
                ),
              ],
              title: SearchFilters(
                parentIndex,
                options: body.options!,
                textStyle: Theme.of(context).textTheme.headline6!.copyWith(
                    color: Theme.of(context).primaryTextTheme.headline6!.color),
                disableOrdering: true,
              ),
            ),
            body: body,
          );
        },
      ),
    );
    await body.options!.dispose();
  }

  List<DropdownMenuItem<String>>? getOrderByItems() {
    if (parentIndex == 0) {
      return Class.getHumanReadableMap2()
          .entries
          .map((e) => DropdownMenuItem(
                value: e.key,
                child: Text(e.value),
              ))
          .toList();
    } else if (parentIndex == 1) {
      return Person.getHumanReadableMap2()
          .entries
          .map((e) => DropdownMenuItem(
                value: e.key,
                child: Text(e.value),
              ))
          .toList();
    }
    return null;
  }

  int? getWidgetIndex() {
    return childItems[parentIndex!][childIndex].value.key;
    // if (parentIndex == 0) {
    //   if (childIndex == 2) {
    //     return 0;
    //   } else {
    //     return 1;
    //   }
    // } else if (parentIndex == 1) {
    //   if (childIndex == 0 || childIndex == 3) {
    //     return 1;
    //   } else if (childIndex == 1) {
    //     return 0;
    //   } else if (childIndex == 2) {
    //     return 2;
    //   }
    // } else if (parentIndex == 2) {
    //   if (childIndex == 0 || childIndex == 1 || childIndex == 5) {
    //     return 1;
    //   } else if (childIndex == 2) {
    //     return 0;
    //   } else if (childIndex == 3) {
    //     return 3;
    //   } else if (childIndex == 4) {
    //     return 2;
    //   }
    // } else if (parentIndex == 3) {
    //   if (childIndex == 0 ||
    //       childIndex == 1 ||
    //       childIndex == 4 ||
    //       childIndex == 6 ||
    //       childIndex == 9 ||
    //       childIndex == 11) {
    //     return 1;
    //   } else if (childIndex == 2) {
    //     return 11;
    //   } else if (childIndex == 5) {
    //     return 6;
    //   } else if (childIndex == 8) {
    //     return 8;
    //   } else if (childIndex == 10) {
    //     return 9;
    //   } else if (childIndex == 7 || childIndex == 16) {
    //     return 5;
    //   } else if (childIndex == 12) {
    //     return 4;
    //   } else if (childIndex == 13) {
    //     return 3;
    //   } else if (childIndex == 14 || childIndex == 15) {
    //     return 2;
    //   } else if (childIndex == 3) {
    //     return 7;
    //   } else if (childIndex == 17) {
    //     return 10;
    //   } else if (childIndex == 18) {
    //     return 12;
    //   } else if (childIndex == 19) {
    //     return 13;
    //   }
    // }
    // return -1;
  }

  @override
  void initState() {
    super.initState();
    if (widget.query != null) {
      parentIndex = int.parse(widget.query!['parentIndex']);
      childIndex = int.parse(widget.query!['childIndex']);
      operatorIndex = int.parse(widget.query!['operatorIndex']);
      queryText = widget.query!['queryText'];
      birthDate = widget.query!['birthDate'] == 'true';
      queryValue = widget.query!['queryValue'] != null
          ? widget.query!['queryValue'].toString().startsWith('D')
              ? FirebaseFirestore.instance
                  .doc(widget.query!['queryValue'].toString().substring(1))
              : (widget.query!['queryValue'].toString().startsWith('T')
                  ? Timestamp.fromMillisecondsSinceEpoch(int.parse(
                      widget.query!['queryValue'].toString().substring(1)))
                  : (widget.query!['queryValue'].toString().startsWith('I')
                      ? int.parse(
                          widget.query!['queryValue'].toString().substring(1))
                      : widget.query!['queryValue'].toString().substring(1)))
          : null;
      WidgetsBinding.instance!.addPostFrameCallback((_) => execute());
    }
  }

  void operatorChange(value) {
    setState(() {
      operatorIndex = value;
    });
  }

  void parentChanged(value) {
    setState(() {
      orderBy = 'Name';
      childIndex = 0;
      parentIndex = value;
    });
  }

  void queryTextChange(String value) {
    queryValue = value;
    queryText = value;
  }

  void _selectClass() async {
    BehaviorSubject<OrderOptions> _orderOptions =
        BehaviorSubject<OrderOptions>.seeded(OrderOptions());
    final _listOptions = DataObjectListController<Class>(
      tap: (value) {
        navigator.currentState!.pop();
        setState(() {
          queryValue =
              FirebaseFirestore.instance.collection('Classes').doc(value.id);
          queryText = value.name;
        });
      },
      itemsStream: _orderOptions.switchMap(
        (order) => Class.getAllForUser(
            orderBy: order.orderBy ?? 'Name', descending: !order.asc!),
      ),
    );
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          content: SizedBox(
            width: 280,
            child: Column(
              children: [
                SearchFilters(0,
                    options: _listOptions,
                    orderOptions: _orderOptions,
                    textStyle: Theme.of(context).textTheme.bodyText2),
                Expanded(
                  child: DataObjectList<Class>(
                    disposeController: false,
                    options: _listOptions,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    await _listOptions.dispose();
    await _orderOptions.close();
  }

  void _selectDate() async {
    DateTime? picked = await showDatePicker(
        context: context,
        initialDate:
            queryValue is! Timestamp ? DateTime.now() : queryValue.toDate(),
        firstDate: DateTime(1500),
        lastDate: DateTime(2201));
    if (picked != null)
      setState(() {
        queryValue = Timestamp.fromDate(picked);
      });
  }

  // void _selectType() {
  //   showDialog(
  //     context: context,
  //     builder: (context) {
  //       return AlertDialog(
  //         content: TypesList(
  //           list: FirebaseFirestore.instance
  //               .collection('Types')
  //               .get(source: dataSource),
  //           tap: (type, _) {
  //             navigator.currentState.pop();
  //             setState(() {
  //               queryValue = type.ref;
  //               queryText = type.name;
  //             });
  //           },
  //           showNull: true,
  //         ),
  //       );
  //     },
  //   );
  // }
}
