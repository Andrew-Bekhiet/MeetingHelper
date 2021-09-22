import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:meetinghelper/models/data/class.dart';
import 'package:meetinghelper/models/data/person.dart';
import 'package:meetinghelper/models/data/service.dart';
import 'package:meetinghelper/models/data_object_widget.dart';
import 'package:meetinghelper/models/list_controllers.dart';
import 'package:meetinghelper/models/property_metadata.dart';
import 'package:meetinghelper/models/super_classes.dart';
import 'package:meetinghelper/utils/typedefs.dart';
import 'package:meetinghelper/views/services_list.dart';
import 'package:rxdart/rxdart.dart';
import 'package:share_plus/share_plus.dart';

import '../models/data/user.dart';
import '../models/search/order_options.dart';
import '../models/search/search_filters.dart';
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
  JsonCollectionRef collection =
      FirebaseFirestore.instance.collection('Persons');

  String fieldPath = 'Name';

  String operator = '=';

  dynamic queryValue = '';

  bool order = false;
  String orderBy = 'Name';
  bool descending = false;

  final List<DropdownMenuItem<String>> operatorItems = const [
    DropdownMenuItem(value: '=', child: Text('=')),
    DropdownMenuItem(value: '!=', child: Text('لا يساوي')),
    DropdownMenuItem(value: 'contains', child: Text('قائمة تحتوي على')),
    DropdownMenuItem(value: '>', child: Text('أكبر من')),
    DropdownMenuItem(
      value: '<',
      child: Text('أصغر من'),
    ),
  ];

  final Map<JsonCollectionRef, Map<String, PropertyMetadata>> properties = {
    FirebaseFirestore.instance.collection('Services'): Service.propsMetadata()
      ..remove('StudyYearRange')
      ..remove('Validity'),
    FirebaseFirestore.instance.collection('Classes'): Class.propsMetadata(),
    FirebaseFirestore.instance.collection('Persons'): Person.propsMetadata()
      ..remove('Phones'),
  };

  late final Map<Type, PropertyQuery> valueWidget;

  @override
  Widget build(BuildContext context) {
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
                DropdownButtonFormField<JsonCollectionRef>(
                  key: const ValueKey('CollectionKey'),
                  value: collection,
                  items: [
                    DropdownMenuItem(
                      value: FirebaseFirestore.instance.collection('Services'),
                      child: const Text('الخدمات'),
                    ),
                    DropdownMenuItem(
                      value: FirebaseFirestore.instance.collection('Classes'),
                      child: const Text('الفصول'),
                    ),
                    DropdownMenuItem(
                      value: FirebaseFirestore.instance.collection('Persons'),
                      child: const Text('المخدومين'),
                    ),
                  ],
                  onChanged: (v) => setState(() {
                    collection = v!;
                    fieldPath = 'Name';
                    queryValue = properties[collection]?['Name']?.defaultValue;
                  }),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                const Text('بشرط: '),
                Expanded(
                  key: ValueKey(collection),
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    items: properties[collection]!
                        .values
                        .map(
                          (p) => DropdownMenuItem(
                            value: p.name,
                            child: Text(p.label),
                          ),
                        )
                        .toList(),
                    onChanged: (p) => setState(() {
                      fieldPath = p!;
                      queryValue = properties[collection]
                              ?[fieldPath.split('.')[0]]
                          ?.defaultValue;
                    }),
                    value: fieldPath.split('.')[0],
                  ),
                ),
                Expanded(
                  key: const ValueKey('OperatorsKey'),
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    items: operatorItems,
                    onChanged: (o) => setState(() => operator = o!),
                    value: operator,
                  ),
                ),
              ],
            ),
            Builder(
              key: ValueKey(valueWidget[
                  properties[collection]![fieldPath.split('.')[0]]!.type]!),
              builder: valueWidget[
                      properties[collection]![fieldPath.split('.')[0]]!.type]!
                  .builder,
            ),
            CheckboxListTile(
              value: order,
              onChanged: (v) => setState(() => order = v!),
              title: const Text(
                  'ترتيب النتائج (قد يستغرق وقت مع النتائج الكبيرة)'),
            ),
            if (order)
              Row(
                key: ValueKey(order),
                children: <Widget>[
                  const Text('ترتيب حسب:'),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      key: ValueKey(valueWidget[
                          properties[collection]![fieldPath.split('.')[0]]!
                              .type]!),
                      isExpanded: true,
                      value: orderBy,
                      items: properties[collection]!
                          .values
                          .map(
                            (p) => DropdownMenuItem(
                              value: p.name,
                              child: Text(p.label),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        setState(() {
                          orderBy = value!;
                        });
                      },
                    ),
                  ),
                  Expanded(
                    child: DropdownButtonFormField<bool>(
                      key: ValueKey(valueWidget[
                          properties[collection]![fieldPath.split('.')[0]]!
                              .type]!),
                      isExpanded: true,
                      value: descending,
                      items: const [
                        DropdownMenuItem(
                          value: false,
                          child: Text('تصاعدي'),
                        ),
                        DropdownMenuItem(
                          value: true,
                          child: Text('تنازلي'),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          descending = value!;
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

  void execute() async {
    Query<Json> _mainQueryCompleter(Query<Json> q, _, __) =>
        valueWidget[properties[collection]![fieldPath.split('.')[0]]!.type]!
            .completeQuery(q, queryValue);

    final DataObjectList body = DataObjectList(
      disposeController: false,
      options: DataObjectListController(
        itemsStream: (collection.id == 'Services'
                ? Service.getAllForUser(
                    queryCompleter: _mainQueryCompleter,
                  )
                : collection.id == 'Classes'
                    ? Class.getAllForUser(
                        queryCompleter: _mainQueryCompleter,
                      )
                    : Person.getAllForUser(
                        queryCompleter: _mainQueryCompleter,
                      ) as Stream<List<DataObject>>)
            .map(
          (rslt) {
            if (!order) return rslt;

            final sorted = rslt.cast<DataObject>().sublist(0);
            mergeSort(sorted, compare: (previous, next) {
              if (previous == null || next == null) {
                if (previous == null) return -1;
                if (next == null) return 1;
                return 0;
              }

              final p = previous as DataObject;
              final n = next as DataObject;

              if (p.getMap()[orderBy] is Comparable &&
                  n.getMap()[orderBy] is Comparable) {
                return descending
                    ? -(p.getMap()[orderBy] ?? '')
                        .compareTo(n.getMap()[orderBy] ?? '')
                    : (p.getMap()[orderBy] ?? '')
                        .compareTo(n.getMap()[orderBy] ?? '');
              }
              return 0;
            });
            return sorted;
          },
        ),
      ),
    );

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
                        'collection': collection.id,
                        'fieldPath': fieldPath,
                        'operator': operator,
                        'queryValue': queryValue == null
                            ? null
                            : queryValue is bool
                                ? 'B' + queryValue
                                : queryValue is JsonRef
                                    ? 'D' + (queryValue as JsonRef).path
                                    : (queryValue is DateTime
                                        ? 'T' +
                                            (queryValue as DateTime)
                                                .millisecondsSinceEpoch
                                                .toString()
                                        : (queryValue is int
                                            ? 'I' + queryValue.toString()
                                            : 'S' + queryValue.toString())),
                        'order': order.toString(),
                        'orderBy': orderBy,
                        'descending': descending.toString(),
                      }),
                    );
                  },
                  tooltip: 'مشاركة النتائج برابط',
                ),
              ],
              title: SearchFilters(
                collection.id == 'Services'
                    ? Service
                    : collection.id == 'Classes'
                        ? Class
                        : Person,
                options: body.options!,
                textStyle: Theme.of(context).textTheme.headline6!.copyWith(
                    color: Theme.of(context).primaryTextTheme.headline6!.color),
                disableOrdering: true,
              ),
            ),
            body: body,
            bottomNavigationBar: BottomAppBar(
              color: Theme.of(context).colorScheme.primary,
              shape: const CircularNotchedRectangle(),
              child: StreamBuilder<dynamic>(
                stream: body.options!.objectsData,
                builder: (context, snapshot) {
                  return Text(
                    (snapshot.data?.length ?? 0).toString() + ' عنصر',
                    textAlign: TextAlign.center,
                    strutStyle:
                        StrutStyle(height: IconTheme.of(context).size! / 7.5),
                    style: Theme.of(context).primaryTextTheme.bodyText1,
                  );
                },
              ),
            ),
          );
        },
      ),
    );
    await body.options!.dispose();
  }

  @override
  void initState() {
    super.initState();

    valueWidget = {
      DateTime: PropertyQuery<DateTime>(
        builder: (context) => Column(
          key: const ValueKey('SelectDateTime'),
          children: <Widget>[
            InkWell(
              onTap: _selectDate,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'اختيار تاريخ',
                ),
                child: queryValue != null
                    ? Text(
                        DateFormat('yyyy/M/d').format(queryValue is DateTime
                            ? queryValue
                            : DateTime.now()),
                      )
                    : const Text('(فارغ)'),
              ),
            ),
            OutlinedButton(
              onPressed: () => setState(() {
                queryValue = null;
              }),
              child: const Text('بحث عن تاريخ فارغ'),
            ),
          ],
        ),
        queryCompleter: (q, value) {
          if (value == null)
            return q.where(fieldPath, isNull: operator == '=');
          else {
            final effectiveValue = fieldPath == 'BirthDay'
                ? Timestamp.fromDate(DateTime(1970, value.month, value.day))
                : Timestamp.fromDate(value);

            if (operator == '>')
              return q.where(fieldPath, isGreaterThanOrEqualTo: effectiveValue);
            else if (operator == '<')
              return q.where(fieldPath, isLessThanOrEqualTo: effectiveValue);

            return q
                .where(
                  fieldPath,
                  isGreaterThanOrEqualTo: effectiveValue,
                )
                .where(
                  fieldPath,
                  isLessThan: Timestamp.fromDate(
                    DateTime(
                        effectiveValue.toDate().year,
                        effectiveValue.toDate().month,
                        effectiveValue.toDate().day + 1),
                  ),
                );
          }
        },
      ),
      String: PropertyQuery<String>(
        builder: (context) {
          if (fieldPath == 'ShammasLevel')
            return DropdownButtonFormField<String>(
              key: const ValueKey('SelectShammasLevel'),
              value: [
                'ابصالتس',
                'اغأناغنوستيس',
                'أيبودياكون',
                'دياكون',
                'أرشيدياكون'
              ].contains(queryValue)
                  ? queryValue
                  : null,
              isExpanded: true,
              items: [
                'ابصالتس',
                'اغأناغنوستيس',
                'أيبودياكون',
                'دياكون',
                'أرشيدياكون'
              ]
                  .map(
                    (item) => DropdownMenuItem(
                      value: item,
                      child: Text(item),
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
              onChanged: (value) {
                setState(() {
                  queryValue = value;
                });
              },
              decoration: const InputDecoration(
                labelText: 'رتبة الشموسية',
              ),
            );

          return Container(
            key: const ValueKey('EnterString'),
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: TextFormField(
              autofocus: false,
              decoration: InputDecoration(
                labelText:
                    properties[collection]?[fieldPath]?.label ?? 'قيمة البحث',
              ),
              textInputAction: TextInputAction.done,
              initialValue: queryValue is String ? queryValue : '',
              onChanged: (v) => queryValue = v,
              onFieldSubmitted: (_) => execute(),
              validator: (value) {
                return null;
              },
            ),
          );
        },
        queryCompleter: (q, value) {
          if (value == null) return q.where(fieldPath, isNull: true);
          if (operator == '>')
            return q.where(fieldPath, isGreaterThanOrEqualTo: value);
          else if (operator == '<')
            return q.where(fieldPath, isLessThanOrEqualTo: value);
          else if (operator == '!=')
            return q.where(fieldPath, isNotEqualTo: value);
          return q.where(fieldPath, isEqualTo: value);
        },
      ),
      bool: PropertyQuery<bool>(
        builder: (context) => fieldPath == 'Gender'
            ? Container(
                key: const ValueKey('SelectGender'),
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: DropdownButtonFormField<bool?>(
                  decoration: const InputDecoration(labelText: 'اختيار النوع'),
                  value: queryValue,
                  items: [null, true, false]
                      .map(
                        (item) => DropdownMenuItem(
                          value: item,
                          child: Text(item == null
                              ? 'غير محدد'
                              : item
                                  ? 'بنين'
                                  : 'بنات'),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    setState(() {
                      queryValue = v;
                    });
                  },
                ),
              )
            : CheckboxListTile(
                key: const ValueKey('SelectBool'),
                title: const Text('قيمة البحث'),
                subtitle: Text(queryValue == true ? 'نعم' : 'لا'),
                value: queryValue,
                onChanged: (v) {
                  setState(() {
                    queryValue = v;
                  });
                },
              ),
        queryCompleter: (q, value) {
          if (value == null) return q.where(fieldPath, isNull: true);
          if (operator == '>')
            return q.where(fieldPath, isGreaterThanOrEqualTo: value);
          else if (operator == '<')
            return q.where(fieldPath, isLessThanOrEqualTo: value);
          else if (operator == '!=')
            return q.where(fieldPath, isNotEqualTo: value);

          return q.where(fieldPath, isEqualTo: value);
        },
      ),
      Color: PropertyQuery<int>(
        builder: (context) => Container(
          color: queryValue is int ? Color(queryValue) : Colors.transparent,
          child: InkWell(
            key: const ValueKey('SelectColor'),
            onTap: () {
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
            },
            child: const InputDecorator(
              decoration: InputDecoration(),
              child: Center(
                child: Text('اختيار لون'),
              ),
            ),
          ),
        ),
        queryCompleter: (q, value) {
          if (operator == '>')
            return q.where(fieldPath, isGreaterThanOrEqualTo: value);
          else if (operator == '<')
            return q.where(fieldPath, isLessThanOrEqualTo: value);
          else if (operator == '!=')
            return q.where(fieldPath, isNotEqualTo: value);
          return q.where(fieldPath, isEqualTo: value);
        },
      ),
      JsonRef: PropertyQuery<dynamic>(
        builder: (context) {
          if (fieldPath == 'ClassId') {
            return InkWell(
              key: const ValueKey('SelectClass'),
              onTap: _selectClass,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'اختيار فصل',
                ),
                child: queryValue != null && queryValue is JsonRef
                    ? FutureBuilder<Class>(
                        future: Future(() async => Class.fromDoc(
                            await (queryValue as JsonRef).get(dataSource))!),
                        builder: (context, classData) {
                          if (!classData.hasData)
                            return const LinearProgressIndicator();

                          return IgnorePointer(
                            ignoringSemantics: false,
                            child: DataObjectWidget<Class>(classData.data!,
                                isDense: true),
                          );
                        },
                      )
                    : const Text('(فارغ)'),
              ),
            );
          } else if (fieldPath == 'LastEdit') {
            return InkWell(
              key: const ValueKey('SelectUserUID'),
              onTap: () => _selectUser(true),
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'اختيار خادم',
                ),
                child: queryValue != null && queryValue is String
                    ? FutureBuilder<User>(
                        future: User.fromID(queryValue),
                        builder: (context, userData) {
                          if (!userData.hasData)
                            return const LinearProgressIndicator();

                          return IgnorePointer(
                            ignoringSemantics: false,
                            child: DataObjectWidget<User>(userData.data!,
                                isDense: true),
                          );
                        },
                      )
                    : const Text('(فارغ)'),
              ),
            );
          }

          return FutureBuilder<JsonQuery>(
            key: ValueKey('Select' + fieldPath),
            future: properties[collection]![fieldPath.split('.')[0]]!
                .collection!
                .get(dataSource),
            builder: (context, data) {
              if (data.hasData) {
                return DropdownButtonFormField<JsonRef?>(
                  value: queryValue != null &&
                          queryValue is JsonRef &&
                          queryValue.path.startsWith('Schools/')
                      ? queryValue
                      : null,
                  items: data.data!.docs
                      .map(
                        (item) => DropdownMenuItem(
                          value: item.reference,
                          child: Text(item.data()['Name']),
                        ),
                      )
                      .toList()
                    ..insert(
                      0,
                      const DropdownMenuItem(
                        value: null,
                        child: Text('(فارغ)'),
                      ),
                    ),
                  onChanged: (value) async {
                    queryValue = value;
                  },
                  decoration: InputDecoration(
                      labelText:
                          properties[collection]![fieldPath.split('.')[0]]!
                              .label),
                );
              }
              return const LinearProgressIndicator();
            },
          );
        },
        queryCompleter: (q, value) {
          if (operator == '>')
            return q.where(fieldPath, isGreaterThanOrEqualTo: value);
          else if (operator == '<')
            return q.where(fieldPath, isLessThanOrEqualTo: value);
          else if (operator == '!=')
            return q.where(fieldPath, isNotEqualTo: value);
          return q.where(fieldPath, isEqualTo: value);
        },
      ),
      List: PropertyQuery<JsonRef>(
        builder: (context) {
          if (fieldPath == 'Services') {
            return InkWell(
              key: const ValueKey('SelectServices'),
              onTap: _selectService,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'اختيار خدمة',
                ),
                child: queryValue != null && queryValue is JsonRef
                    ? FutureBuilder<Service>(
                        future: Future(() async => Service.fromDoc(
                            await (queryValue as JsonRef).get(dataSource))!),
                        builder: (context, serviceData) {
                          if (!serviceData.hasData)
                            return const LinearProgressIndicator();

                          return IgnorePointer(
                            ignoringSemantics: false,
                            child: DataObjectWidget<Service>(serviceData.data!,
                                isDense: true),
                          );
                        },
                      )
                    : const Text('(فارغ)'),
              ),
            );
          } else if (fieldPath == 'Allowed') {
            return InkWell(
              key: const ValueKey('SelectAllowed'),
              onTap: () => _selectUser(true),
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'اختيار خادم',
                ),
                child: queryValue != null && queryValue is String
                    ? FutureBuilder<User>(
                        future: User.fromID(queryValue),
                        builder: (context, userData) {
                          if (!userData.hasData)
                            return const LinearProgressIndicator();

                          return IgnorePointer(
                            ignoringSemantics: false,
                            child: DataObjectWidget<User>(userData.data!,
                                isDense: true),
                          );
                        },
                      )
                    : const Text('(فارغ)'),
              ),
            );
          }

          return Container();
        },
        queryCompleter: (q, value) {
          if (operator == '>')
            return q.where(fieldPath, isGreaterThanOrEqualTo: value);
          else if (operator == '<')
            return q.where(fieldPath, isLessThanOrEqualTo: value);
          else if (operator == '!=')
            return q.where(fieldPath, isNotEqualTo: value);

          return q.where(fieldPath, arrayContains: value);
        },
      ),
      Json: PropertyQuery<DateTime>(
        builder: (context) {
          if (fieldPath.split('.')[0] == 'Last') {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  key: const ValueKey('SelectServices2'),
                  onTap: () => _selectService(true),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'اختيار الخدمة',
                    ),
                    child:
                        queryValue != null && fieldPath.split('.').length == 2
                            ? FutureBuilder<Service>(
                                key: ValueKey(fieldPath),
                                future: Future(() async => Service.fromDoc(
                                    await FirebaseFirestore.instance
                                        .collection('Services')
                                        .doc(fieldPath.split('.')[1])
                                        .get(dataSource))!),
                                builder: (context, serviceData) {
                                  if (!serviceData.hasData)
                                    return const LinearProgressIndicator();

                                  return IgnorePointer(
                                    ignoringSemantics: false,
                                    child: DataObjectWidget<Service>(
                                        serviceData.data!,
                                        isDense: true),
                                  );
                                },
                              )
                            : const Text('(فارغ)'),
                  ),
                ),
                const SizedBox(height: 40),
                Builder(
                  builder: valueWidget[DateTime]!.builder,
                ),
              ],
            );
          }
          return const SizedBox();
        },
        queryCompleter: (q, value) {
          if (operator == '>')
            return q.where(fieldPath, isGreaterThanOrEqualTo: value);
          else if (operator == '<')
            return q.where(fieldPath, isLessThanOrEqualTo: value);
          else if (operator == '!=')
            return q.where(fieldPath, isNotEqualTo: value);

          return q.where(fieldPath, isEqualTo: value);
        },
      ),
    };

    if (widget.query != null) {
      collection = widget.query!['collection'] == 'Services'
          ? FirebaseFirestore.instance.collection('Services')
          : widget.query!['collection'] == 'Classes'
              ? FirebaseFirestore.instance.collection('Classes')
              : FirebaseFirestore.instance.collection('Persons');

      fieldPath = widget.query!['fieldPath'] ?? 'Name';

      operator = widget.query!['operator'] ?? '=';

      queryValue = widget.query!['queryValue'] != null
          ? widget.query!['queryValue'].toString().startsWith('B')
              ? widget.query!['queryValue'].toString().substring(1) == 'true'
              : widget.query!['queryValue'].toString().startsWith('D')
                  ? FirebaseFirestore.instance
                      .doc(widget.query!['queryValue'].toString().substring(1))
                  : (widget.query!['queryValue'].toString().startsWith('T')
                      ? DateTime.fromMillisecondsSinceEpoch(int.parse(
                          widget.query!['queryValue'].toString().substring(1)))
                      : (widget.query!['queryValue'].toString().startsWith('I')
                          ? int.parse(widget.query!['queryValue']
                              .toString()
                              .substring(1))
                          : widget.query!['queryValue']
                              .toString()
                              .substring(1)))
          : null;

      order = widget.query!['order'] == 'true';
      orderBy = widget.query!['orderBy'] ?? 'Name';
      descending = widget.query!['descending'] == 'true';

      WidgetsBinding.instance!.addPostFrameCallback((_) => execute());
    }
  }

  void _selectClass() async {
    final BehaviorSubject<OrderOptions> _orderOptions =
        BehaviorSubject<OrderOptions>.seeded(const OrderOptions());

    final _listOptions = ServicesListController<Class>(
        tap: (value) {
          navigator.currentState!.pop();
          setState(() {
            queryValue = value.ref;
          });
        },
        itemsStream: servicesByStudyYearRef<Class>());

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          content: SizedBox(
            width: 280,
            child: Column(
              children: [
                SearchFilters(Class,
                    options: _listOptions,
                    orderOptions: _orderOptions,
                    textStyle: Theme.of(context).textTheme.bodyText2),
                Expanded(
                  child: ServicesList<Class>(
                      options: _listOptions, autoDisposeController: false),
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

  void _selectService([bool forFieldPath = false]) async {
    final BehaviorSubject<OrderOptions> _orderOptions =
        BehaviorSubject<OrderOptions>.seeded(const OrderOptions());

    final _listOptions = ServicesListController<Service>(
        tap: (value) {
          navigator.currentState!.pop();
          setState(() {
            if (forFieldPath)
              fieldPath = fieldPath.contains('.')
                  ? fieldPath.replaceAll(RegExp(r'\.[^.]+$'), '.' + value.id)
                  : fieldPath + '.' + value.id;
            else
              queryValue = value.ref;
          });
        },
        itemsStream: servicesByStudyYearRef<Service>());

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          content: SizedBox(
            width: 280,
            child: Column(
              children: [
                SearchFilters(Service,
                    options: _listOptions,
                    orderOptions: _orderOptions,
                    textStyle: Theme.of(context).textTheme.bodyText2),
                Expanded(
                  child: ServicesList<Service>(
                      options: _listOptions, autoDisposeController: false),
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

  void _selectUser([bool onlyUID = false]) async {
    final BehaviorSubject<OrderOptions> _orderOptions =
        BehaviorSubject<OrderOptions>.seeded(const OrderOptions());

    final _listOptions = DataObjectListController<User>(
      tap: (value) {
        navigator.currentState!.pop();
        setState(() {
          queryValue = onlyUID ? value.uid : value.ref;
        });
      },
      itemsStream: _orderOptions.switchMap(
        (order) => User.getAllForUser(),
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
                SearchFilters(Person,
                    options: _listOptions,
                    orderOptions: _orderOptions,
                    textStyle: Theme.of(context).textTheme.bodyText2),
                Expanded(
                  child: DataObjectList<User>(
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
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: queryValue is! DateTime ? DateTime.now() : queryValue,
      firstDate: DateTime(1500),
      lastDate: DateTime(2201),
    );
    if (picked != null)
      setState(() {
        queryValue = picked;
      });
  }
}

@immutable
class PropertyQuery<T> {
  final Widget Function(BuildContext) builder;
  final Query<Json> Function(Query<Json> query, T? value) queryCompleter;

  const PropertyQuery({required this.builder, required this.queryCompleter});

  Query<Json> completeQuery(Query<Json> q, dynamic v) {
    if (v is T?) return queryCompleter(q, v);
    throw TypeError();
  }
}
