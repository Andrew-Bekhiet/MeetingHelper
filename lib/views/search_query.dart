import 'package:churchdata_core/churchdata_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart' show FieldPath;
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:intl/intl.dart';
import 'package:meetinghelper/controllers.dart';
import 'package:meetinghelper/models.dart';
import 'package:meetinghelper/repositories.dart';
import 'package:meetinghelper/services.dart';
import 'package:meetinghelper/utils/globals.dart';
import 'package:meetinghelper/views.dart';
import 'package:meetinghelper/widgets.dart';
import 'package:rxdart/rxdart.dart';

class SearchQuery extends StatefulWidget {
  final QueryInfo? query;

  const SearchQuery({super.key, this.query});

  @override
  _SearchQueryState createState() => _SearchQueryState();
}

class _SearchQueryState extends State<SearchQuery> {
  late QueryInfo query;

  JsonCollectionRef get collection => query.collection;

  String get fieldPath => query.fieldPath;

  String get operator => query.operator;

  dynamic get queryValue => query.queryValue;

  bool get order => query.order;

  String? get orderBy => query.orderBy;
  bool? get descending => query.descending;

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
    GetIt.I<DatabaseRepository>().collection('Services'):
        Service.propsMetadata()
          ..remove('StudyYearRange')
          ..remove('Validity'),
    GetIt.I<DatabaseRepository>().collection('Classes'): Class.propsMetadata(),
    GetIt.I<DatabaseRepository>().collection('Persons'): Person.propsMetadata()
      ..remove('Phones'),
  };

  late final Map<Type, PropertyQuery> valueWidget = {
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
                      DateFormat('yyyy/M/d').format(
                        queryValue is DateTime ? queryValue : DateTime.now(),
                      ),
                    )
                  : const Text('(فارغ)'),
            ),
          ),
          OutlinedButton(
            onPressed: () => setState(() {
              query = query.copyWith.queryValue(null);
            }),
            child: const Text('بحث عن تاريخ فارغ'),
          ),
        ],
      ),
      queryCompleter: (q, value) {
        if (value == null) {
          return q.where(
            fieldPath,
            isNull: operator == '=',
          );
        } else {
          final effectiveValue = fieldPath == 'BirthDay'
              ? Timestamp.fromDate(DateTime(1970, value.month, value.day))
              : Timestamp.fromDate(value);

          if (operator == '>') {
            return q.where(fieldPath, isGreaterThanOrEqualTo: effectiveValue);
          } else if (operator == '<') {
            return q.where(fieldPath, isLessThanOrEqualTo: effectiveValue);
          }

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
                    effectiveValue.toDate().day + 1,
                  ),
                ),
              );
        }
      },
    ),
    String: PropertyQuery<String>(
      builder: (context) {
        if (fieldPath == 'ShammasLevel') {
          return DropdownButtonFormField<String>(
            key: const ValueKey('SelectShammasLevel'),
            value: [
              'ابصالتس',
              'اغأناغنوستيس',
              'أيبودياكون',
              'دياكون',
              'أرشيدياكون',
            ].contains(queryValue)
                ? queryValue
                : null,
            isExpanded: true,
            items: [
              'ابصالتس',
              'اغأناغنوستيس',
              'أيبودياكون',
              'دياكون',
              'أرشيدياكون',
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
                  child: Text(''),
                ),
              ),
            onChanged: (value) {
              setState(() {
                query = query.copyWith.queryValue(value);
              });
            },
            decoration: const InputDecoration(
              labelText: 'رتبة الشموسية',
            ),
          );
        }

        return Container(
          key: const ValueKey('EnterString'),
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: TextFormField(
            decoration: InputDecoration(
              labelText:
                  properties[collection]?[fieldPath]?.label ?? 'قيمة البحث',
            ),
            textInputAction: TextInputAction.done,
            initialValue: queryValue is String ? queryValue : '',
            onChanged: (v) => query = query.copyWith.queryValue(v),
            onFieldSubmitted: (_) => execute(),
            validator: (value) {
              return null;
            },
          ),
        );
      },
      queryCompleter: (q, value) {
        if (value == null) {
          return q.where(
            fieldPath.contains('.')
                ? FieldPath.fromString(fieldPath)
                : fieldPath,
            isNull: operator == '=',
          );
        } else if (operator == '>') {
          return q.where(
            fieldPath.contains('.')
                ? FieldPath.fromString(fieldPath)
                : fieldPath,
            isGreaterThanOrEqualTo: value,
          );
        } else if (operator == '<') {
          return q.where(
            fieldPath.contains('.')
                ? FieldPath.fromString(fieldPath)
                : fieldPath,
            isLessThanOrEqualTo: value,
          );
        } else if (operator == '!=') {
          return q.where(
            fieldPath.contains('.')
                ? FieldPath.fromString(fieldPath)
                : fieldPath,
            isNotEqualTo: value,
          );
        }

        return q.where(
          fieldPath.contains('.') ? FieldPath.fromString(fieldPath) : fieldPath,
          isEqualTo: value,
        );
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
                        child: Text(
                          item == null
                              ? 'غير محدد'
                              : item
                                  ? 'بنين'
                                  : 'بنات',
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (v) {
                  setState(() {
                    query = query.copyWith.queryValue(v);
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
                  query = query.copyWith.queryValue(v);
                });
              },
            ),
      queryCompleter: (q, value) {
        if (value == null) {
          return q.where(
            fieldPath,
            isNull: operator == '=',
          );
        } else if (operator == '>') {
          return q.where(fieldPath, isGreaterThanOrEqualTo: value);
        } else if (operator == '<') {
          return q.where(fieldPath, isLessThanOrEqualTo: value);
        } else if (operator == '!=') {
          return q.where(fieldPath, isNotEqualTo: value);
        }

        return q.where(fieldPath, isEqualTo: value);
      },
    ),
    Color: PropertyQuery<int>(
      builder: (context) => ColoredBox(
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
                        query =
                            query.copyWith.queryValue(Colors.transparent.value);
                      });
                    },
                    child: const Text('بلا لون'),
                  ),
                ],
                content: ColorsList(
                  selectedColor: Color(
                    queryValue is int ? queryValue : Colors.transparent.value,
                  ),
                  onSelect: (color) {
                    navigator.currentState!.pop();
                    setState(() {
                      query = query.copyWith.queryValue(color.value);
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
        if (value == null) {
          return q.where(
            fieldPath,
            isNull: operator == '=',
          );
        } else if (operator == '>') {
          return q.where(fieldPath, isGreaterThanOrEqualTo: value);
        } else if (operator == '<') {
          return q.where(fieldPath, isLessThanOrEqualTo: value);
        } else if (operator == '!=') {
          return q.where(fieldPath, isNotEqualTo: value);
        }

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
                      future: Future(
                        () async =>
                            Class.fromDoc(await (queryValue as JsonRef).get()),
                      ),
                      builder: (context, classData) {
                        if (!classData.hasData) {
                          return const LinearProgressIndicator();
                        }

                        return IgnorePointer(
                          child: ViewableObjectWidget<Class>(
                            classData.data!,
                            isDense: true,
                          ),
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
                  ? FutureBuilder<User?>(
                      future:
                          MHDatabaseRepo.instance.users.getUserName(queryValue),
                      builder: (context, userData) {
                        if (!userData.hasData) {
                          return const LinearProgressIndicator();
                        }

                        return IgnorePointer(
                          child: ViewableObjectWidget<User>(
                            userData.data!,
                            isDense: true,
                          ),
                        );
                      },
                    )
                  : const Text('(فارغ)'),
            ),
          );
        }

        return FutureBuilder<JsonQuery>(
          key: ValueKey('Select' + fieldPath),
          future: properties[collection]![fieldPath]!.query!.get(),
          builder: (context, data) {
            if (data.hasData) {
              return DropdownButtonFormField<JsonRef?>(
                value: queryValue != null &&
                        queryValue is JsonRef &&
                        (queryValue as JsonRef).parent.id.startsWith(
                              properties[collection]![fieldPath]!
                                  .collectionName!,
                            )
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
                      child: Text('(فارغ)'),
                    ),
                  ),
                onChanged: (value) async {
                  query = query.copyWith.queryValue(value);
                },
                decoration: InputDecoration(
                  labelText: properties[collection]![fieldPath]!.label,
                ),
              );
            }
            return const LinearProgressIndicator();
          },
        );
      },
      queryCompleter: (q, value) {
        if (value == null) {
          return q.where(
            fieldPath,
            isNull: operator == '=',
          );
        } else if (operator == '>') {
          return q.where(fieldPath, isGreaterThanOrEqualTo: value);
        } else if (operator == '<') {
          return q.where(fieldPath, isLessThanOrEqualTo: value);
        } else if (operator == '!=') {
          return q.where(fieldPath, isNotEqualTo: value);
        }

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
                      future: Future(
                        () async => Service.fromDoc(
                          await (queryValue as JsonRef).get(),
                        )!,
                      ),
                      builder: (context, serviceData) {
                        if (!serviceData.hasData) {
                          return const LinearProgressIndicator();
                        }

                        return IgnorePointer(
                          child: ViewableObjectWidget<Service>(
                            serviceData.data!,
                            isDense: true,
                          ),
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
                  ? FutureBuilder<User?>(
                      future:
                          MHDatabaseRepo.instance.users.getUserName(queryValue),
                      builder: (context, userData) {
                        if (!userData.hasData) {
                          return const LinearProgressIndicator();
                        }

                        return IgnorePointer(
                          child: ViewableObjectWidget<User>(
                            userData.data!,
                            isDense: true,
                          ),
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
        if (value == null) {
          return q.where(
            fieldPath,
            isNull: operator == '=',
          );
        } else if (operator == '>') {
          return q.where(fieldPath, isGreaterThanOrEqualTo: value);
        } else if (operator == '<') {
          return q.where(fieldPath, isLessThanOrEqualTo: value);
        } else if (operator == '!=') {
          return q.where(fieldPath, isNotEqualTo: value);
        }

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
                  child: queryValue != null && fieldPath.split('.').length == 2
                      ? FutureBuilder<Service>(
                          key: ValueKey(fieldPath),
                          future: Future(
                            () async => Service.fromDoc(
                              await GetIt.I<DatabaseRepository>()
                                  .collection('Services')
                                  .doc(fieldPath.split('.')[1])
                                  .get(),
                            )!,
                          ),
                          builder: (context, serviceData) {
                            if (!serviceData.hasData) {
                              return const LinearProgressIndicator();
                            }

                            return IgnorePointer(
                              child: ViewableObjectWidget<Service>(
                                serviceData.data!,
                                isDense: true,
                              ),
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
        if (value == null) {
          return q.where(
            fieldPath,
            isNull: operator == '=',
          );
        } else if (operator == '>') {
          return q.where(fieldPath, isGreaterThanOrEqualTo: value);
        } else if (operator == '<') {
          return q.where(fieldPath, isLessThanOrEqualTo: value);
        } else if (operator == '!=') {
          return q.where(fieldPath, isNotEqualTo: value);
        }

        return q.where(fieldPath, isEqualTo: value);
      },
    ),
  };

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
              children: <Widget>[
                const Text('عرض كل: '),
                Expanded(
                  child: DropdownButtonFormField<JsonCollectionRef>(
                    itemHeight: 60,
                    isExpanded: true,
                    key: const ValueKey('CollectionKey'),
                    value: collection,
                    items: [
                      DropdownMenuItem(
                        value: GetIt.I<DatabaseRepository>()
                            .collection('Services'),
                        child: const Text('الخدمات'),
                      ),
                      DropdownMenuItem(
                        value:
                            GetIt.I<DatabaseRepository>().collection('Classes'),
                        child: const Text('الفصول'),
                      ),
                      DropdownMenuItem(
                        value:
                            GetIt.I<DatabaseRepository>().collection('Persons'),
                        child: const Text('المخدومين'),
                      ),
                    ],
                    onChanged: (v) => setState(() {
                      query = query.copyWith(
                        collection: v,
                        fieldPath: 'Name',
                        queryValue:
                            properties[collection]?['Name']?.defaultValue,
                      );
                    }),
                  ),
                ),
              ],
            ),
            Row(
              children: <Widget>[
                const Text('بشرط: '),
                Expanded(
                  flex: 25,
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
                    onChanged: (p) => setState(
                      () {
                        query = query
                            .copyWith(
                              queryValue:
                                  properties[collection]?[p!]?.defaultValue,
                              fieldPath: p,
                            )
                            .copyWithNull(
                              queryValue:
                                  properties[collection]?[p!]?.defaultValue ==
                                      null,
                            );
                      },
                    ),
                    value: fieldPath.split('.')[0],
                  ),
                ),
                const SizedBox(width: 5),
                Expanded(
                  flex: 10,
                  key: const ValueKey('OperatorsKey'),
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    items: operatorItems,
                    onChanged: (o) =>
                        setState(() => query = query.copyWith.operator(o!)),
                    value: operator,
                  ),
                ),
              ],
            ),
            Builder(
              key: ValueKey(query),
              builder: valueWidget[properties[collection]![fieldPath]!.type]!
                  .builder,
            ),
            CheckboxListTile(
              value: order,
              onChanged: (v) =>
                  setState(() => query = query.copyWith.order(v!)),
              title: const Text(
                'ترتيب النتائج (قد يستغرق وقت مع النتائج الكبيرة)',
              ),
            ),
            if (order)
              Row(
                key: ValueKey(order),
                children: <Widget>[
                  const Text('ترتيب حسب:'),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      key: ValueKey(
                        valueWidget[properties[collection]![fieldPath]!.type]!,
                      ),
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
                          query = query.copyWith.orderBy(value);
                        });
                      },
                    ),
                  ),
                  Expanded(
                    child: DropdownButtonFormField<bool>(
                      key: ValueKey(
                        valueWidget[properties[collection]![fieldPath]!.type]!,
                      ),
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
                          query = query.copyWith.descending(value);
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
            ),
          ],
        ),
      ),
    );
  }

  Future<void> execute() async {
    QueryOfJson _mainQueryCompleter(QueryOfJson q, _, __) =>
        valueWidget[properties[collection]![fieldPath]!.type]!
            .completeQuery(q, queryValue);

    final listController = ListController(
      objectsPaginatableStream: PaginatableStream.loadAll(
        stream: (collection.id == 'Services'
                ? MHDatabaseRepo.I.services.getAll(
                    queryCompleter: _mainQueryCompleter,
                  )
                : collection.id == 'Classes'
                    ? MHDatabaseRepo.I.classes.getAll(
                        queryCompleter: _mainQueryCompleter,
                      )
                    : MHDatabaseRepo.I.persons.getAll(
                        queryCompleter: _mainQueryCompleter,
                      ))
            .map(
          (rslt) {
            if (!order) return rslt;

            final sorted = rslt.cast<DataObject>().sublist(0);
            mergeSort(
              sorted,
              compare: (previous, next) {
                final p = previous;
                final n = next;

                if (p.toJson()[orderBy] is Comparable &&
                    n.toJson()[orderBy] is Comparable) {
                  return descending!
                      ? -(p.toJson()[orderBy] ?? '')
                          .compareTo(n.toJson()[orderBy] ?? '')
                      : (p.toJson()[orderBy] ?? '')
                          .compareTo(n.toJson()[orderBy] ?? '');
                }
                return 0;
              },
            );
            return sorted;
          },
        ),
      ),
    );
    final DataObjectListView body = DataObjectListView(
      autoDisposeController: false,
      controller: listController,
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
                    await MHShareService.I.shareText(
                      (await MHShareService.I.shareQuery(
                        QueryInfo.fromJson(
                          {
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
                          },
                        ),
                      ))
                          .toString(),
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
                options: listController,
                textStyle: Theme.of(context).textTheme.titleLarge!.copyWith(
                      color:
                          Theme.of(context).primaryTextTheme.titleLarge!.color,
                    ),
                disableOrdering: true,
              ),
            ),
            body: body,
            bottomNavigationBar: BottomAppBar(
              color: Theme.of(context).colorScheme.primary,
              shape: const CircularNotchedRectangle(),
              child: StreamBuilder<dynamic>(
                stream: body.controller.objectsStream,
                builder: (context, snapshot) {
                  return Text(
                    (snapshot.data?.length ?? 0).toString() + ' عنصر',
                    textAlign: TextAlign.center,
                    strutStyle:
                        StrutStyle(height: IconTheme.of(context).size! / 7.5),
                    style: Theme.of(context).primaryTextTheme.bodyLarge,
                  );
                },
              ),
            ),
          );
        },
      ),
    );
    await body.controller.dispose();
  }

  @override
  void initState() {
    super.initState();

    if (widget.query != null) {
      query = widget.query!;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() {});
        execute();
      });
    } else {
      query = QueryInfo(
        collection: GetIt.I<DatabaseRepository>().collection('Persons'),
        fieldPath: 'Name',
        operator: '=',
        queryValue: '',
        order: false,
        orderBy: 'Name',
        descending: false,
      );
    }
  }

  Future<void> _selectClass() async {
    final BehaviorSubject<OrderOptions> _orderOptions =
        BehaviorSubject<OrderOptions>.seeded(const OrderOptions());

    final _listOptions = ServicesListController<Class>(
      objectsPaginatableStream: PaginatableStream.loadAll(
        stream: MHDatabaseRepo.I.classes.getAll(),
      ),
      groupByStream:
          MHDatabaseRepo.I.services.groupServicesByStudyYearRef<Class>,
    );

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          content: SizedBox(
            width: 280,
            child: Column(
              children: [
                SearchFilters(
                  Class,
                  options: _listOptions,
                  orderOptions: _orderOptions,
                  textStyle: Theme.of(context).textTheme.bodyMedium,
                ),
                Expanded(
                  child: ServicesList<Class>(
                    onTap: (value) {
                      navigator.currentState!.pop();
                      setState(() {
                        query = query.copyWith.queryValue(value.ref);
                      });
                    },
                    options: _listOptions,
                    autoDisposeController: false,
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

  Future<void> _selectService([bool forFieldPath = false]) async {
    final BehaviorSubject<OrderOptions> _orderOptions =
        BehaviorSubject<OrderOptions>.seeded(const OrderOptions());

    final _listOptions = ServicesListController<Service>(
      objectsPaginatableStream: PaginatableStream.loadAll(
        stream: MHDatabaseRepo.I.services.getAll(),
      ),
      groupByStream:
          MHDatabaseRepo.I.services.groupServicesByStudyYearRef<Service>,
    );

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          content: SizedBox(
            width: 280,
            child: Column(
              children: [
                SearchFilters(
                  Service,
                  options: _listOptions,
                  orderOptions: _orderOptions,
                  textStyle: Theme.of(context).textTheme.bodyMedium,
                ),
                Expanded(
                  child: ServicesList<Service>(
                    onTap: (value) {
                      navigator.currentState!.pop();
                      setState(() {
                        if (forFieldPath) {
                          query = query.copyWith.fieldPath(
                            fieldPath.contains('.')
                                ? fieldPath.replaceAll(
                                    RegExp(r'\.[^.]+$'),
                                    '.' + value.id,
                                  )
                                : fieldPath + '.' + value.id,
                          );
                        } else {
                          query = query.copyWith.queryValue(value.ref);
                        }
                      });
                    },
                    options: _listOptions,
                    autoDisposeController: false,
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

  Future<void> _selectUser([bool onlyUID = false]) async {
    final BehaviorSubject<OrderOptions> _orderOptions =
        BehaviorSubject<OrderOptions>.seeded(const OrderOptions());

    final _listOptions = ListController<void, User>(
      objectsPaginatableStream: PaginatableStream.loadAll(
        stream: _orderOptions.switchMap(
          (order) => MHDatabaseRepo.instance.users.getAllUsers(),
        ),
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
                SearchFilters(
                  Person,
                  options: _listOptions,
                  orderOptions: _orderOptions,
                  textStyle: Theme.of(context).textTheme.bodyMedium,
                ),
                Expanded(
                  child: DataObjectListView<void, User>(
                    onTap: (value) {
                      navigator.currentState!.pop();
                      setState(() {
                        query = query.copyWith
                            .queryValue(onlyUID ? value.uid : value.ref);
                      });
                    },
                    autoDisposeController: false,
                    controller: _listOptions,
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

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: queryValue is! DateTime ? DateTime.now() : queryValue,
      firstDate: DateTime(1500),
      lastDate: DateTime(2201),
    );
    if (picked != null) {
      setState(() {
        query = query.copyWith.queryValue(picked);
      });
    }
  }
}

@immutable
class PropertyQuery<T> {
  final Widget Function(BuildContext) builder;
  final QueryOfJson Function(QueryOfJson query, T? value) queryCompleter;

  const PropertyQuery({required this.builder, required this.queryCompleter});

  QueryOfJson completeQuery(QueryOfJson q, dynamic v) {
    if (v is T?) return queryCompleter(q, v);
    throw TypeError();
  }
}
