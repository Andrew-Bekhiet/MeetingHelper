import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:feature_discovery/feature_discovery.dart';
import 'package:flutter/material.dart';
import 'package:rxdart/rxdart.dart';
import 'package:provider/provider.dart';

import '../models/list_controllers.dart';
import '../models/models.dart';
import '../utils/globals.dart';
import '../utils/helpers.dart';
import 'list.dart';

class History extends StatefulWidget {
  const History({Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() => _HistoryState();
}

class ServantsHistory extends StatefulWidget {
  const ServantsHistory({Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() => _ServantsHistoryState();
}

class _HistoryState extends State<History> {
  Stream<QuerySnapshot>? list;
  final BehaviorSubject<bool> _showSearch = BehaviorSubject<bool>.seeded(false);
  final BehaviorSubject<String> _search = BehaviorSubject<String>.seeded('');
  final FocusNode _searchFocus = FocusNode();

  @override
  Widget build(BuildContext context) {
    return Provider<DataObjectListController<HistoryDay>>(
      create: (_) => DataObjectListController<HistoryDay>(
        searchQuery: _search,
        tap: (h) => historyTap(h, context),
        itemsStream: (list ??
                FirebaseFirestore.instance
                    .collection('History')
                    .orderBy('Day', descending: true)
                    .snapshots())
            .map((s) => s.docs.map(HistoryDay.fromQueryDoc).toList()),
      ),
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: StreamBuilder<bool>(
              initialData: _showSearch.value,
              stream: _showSearch,
              builder: (context, snapshot) {
                return snapshot.data!
                    ? TextField(
                        focusNode: _searchFocus,
                        decoration: InputDecoration(
                            suffixIcon: IconButton(
                              icon: Icon(Icons.close,
                                  color: Theme.of(context)
                                      .primaryTextTheme
                                      .headline6!
                                      .color),
                              onPressed: () => setState(
                                () {
                                  _search.add('');
                                  _showSearch.add(false);
                                },
                              ),
                            ),
                            hintText: 'بحث ...'),
                        onChanged: _search.add,
                      )
                    : const Text('السجلات');
              },
            ),
            actions: [
              StreamBuilder<bool>(
                initialData: _showSearch.value,
                stream: _showSearch,
                builder: (context, snapshot) {
                  return snapshot.data!
                      ? IconButton(
                          icon: const Icon(Icons.search),
                          onPressed: () => setState(() {
                            _searchFocus.requestFocus();
                            _showSearch.add(true);
                          }),
                        )
                      : Container();
                },
              ),
              IconButton(
                icon: DescribedFeatureOverlay(
                  barrierDismissible: false,
                  featureId: 'SearchByDateRange',
                  tapTarget: const Icon(Icons.calendar_today),
                  title: const Text('بحث بالتاريخ'),
                  description: Column(
                    children: <Widget>[
                      const Text(
                          'يمكنك البحث عن كشف عدة أيام معينة عن طريق الضغط هنا ثم تحديد تاريخ البداية وتاريخ النهاية'),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.forward),
                        label: Text(
                          'التالي',
                          style: TextStyle(
                            color: Theme.of(context).textTheme.bodyText2!.color,
                          ),
                        ),
                        onPressed: () =>
                            FeatureDiscovery.completeCurrentStep(context),
                      ),
                      OutlinedButton(
                        onPressed: () => FeatureDiscovery.dismissAll(context),
                        child: Text(
                          'تخطي',
                          style: TextStyle(
                            color: Theme.of(context).textTheme.bodyText2!.color,
                          ),
                        ),
                      ),
                    ],
                  ),
                  backgroundColor: Theme.of(context).accentColor,
                  targetColor: Theme.of(context).primaryColor,
                  textColor:
                      Theme.of(context).primaryTextTheme.bodyText1!.color!,
                  child: list == null
                      ? const Icon(Icons.calendar_today)
                      : const Icon(Icons.clear),
                ),
                tooltip: list == null ? 'بحث بالتاريخ' : 'محو البحث',
                onPressed: () async {
                  if (list == null) {
                    DateTimeRange? result = await showDateRangePicker(
                      context: context,
                      firstDate: DateTime(2020, 1, 1),
                      lastDate: DateTime.now(),
                      initialDateRange: DateTimeRange(
                        start: DateTime(DateTime.now().year,
                            DateTime.now().month, DateTime.now().day - 7),
                        end: DateTime.now(),
                      ),
                    );
                    list = result != null
                        ? FirebaseFirestore.instance
                            .collection('History')
                            .orderBy('Day', descending: true)
                            .where(
                              'Day',
                              isLessThanOrEqualTo: Timestamp.fromDate(
                                  result.end.add(const Duration(days: 1))),
                            )
                            .where('Day',
                                isGreaterThanOrEqualTo: Timestamp.fromDate(
                                    result.start
                                        .subtract(const Duration(days: 1))))
                            .snapshots()
                        : null;
                    setState(() {});
                  } else {
                    list = null;
                    setState(() {});
                  }
                },
              )
            ],
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () async {
              var today = (await FirebaseFirestore.instance
                      .collection('History')
                      .where('Day',
                          isEqualTo: Timestamp.fromMillisecondsSinceEpoch(
                            DateTime.now().millisecondsSinceEpoch -
                                (DateTime.now().millisecondsSinceEpoch %
                                    86400000),
                          ))
                      .limit(1)
                      .get(dataSource))
                  .docs;
              mainScfld.currentState!.openEndDrawer();
              if (today.isNotEmpty) {
                await navigator.currentState!
                    .pushNamed('Day', arguments: HistoryDay.fromDoc(today[0]));
              } else if (await Connectivity().checkConnectivity() !=
                  ConnectivityResult.none) {
                await navigator.currentState!.pushNamed('Day');
              } else {
                await showDialog(
                    context: context,
                    builder: (context) => const AlertDialog(
                        content: Text('لا يوجد اتصال انترنت')));
              }
            },
            child: const Icon(Icons.add),
          ),
          bottomNavigationBar: Builder(
            builder: (context) => BottomAppBar(
              color: Theme.of(context).primaryColor,
              shape: const CircularNotchedRectangle(),
              child: StreamBuilder<List>(
                stream: context
                    .read<DataObjectListController<HistoryDay>>()
                    .objectsData,
                builder: (context, snapshot) {
                  return Text(
                    (snapshot.data?.length ?? 0).toString() + ' سجل',
                    textAlign: TextAlign.center,
                    strutStyle:
                        StrutStyle(height: IconTheme.of(context).size! / 7.5),
                    style: Theme.of(context).primaryTextTheme.bodyText1,
                  );
                },
              ),
            ),
          ),
          floatingActionButtonLocation: FloatingActionButtonLocation.endDocked,
          extendBody: true,
          body: const DataObjectList<HistoryDay>(),
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance!.addPostFrameCallback((_) =>
        FeatureDiscovery.discoverFeatures(context, ['SearchByDateRange']));
  }
}

class _ServantsHistoryState extends State<ServantsHistory> {
  Stream<QuerySnapshot>? list;
  final BehaviorSubject<bool> _showSearch = BehaviorSubject<bool>.seeded(false);
  final BehaviorSubject<String> _search = BehaviorSubject<String>.seeded('');
  final FocusNode _searchFocus = FocusNode();

  @override
  Widget build(BuildContext context) {
    return Provider<DataObjectListController<ServantsHistoryDay>>(
      create: (_) => DataObjectListController<ServantsHistoryDay>(
        searchQuery: _search,
        tap: (h) => historyTap(h, context),
        itemsStream: (list ??
                FirebaseFirestore.instance
                    .collection('ServantsHistory')
                    .orderBy('Day', descending: true)
                    .snapshots())
            .map((s) => s.docs.map(ServantsHistoryDay.fromQueryDoc).toList()),
      ),
      builder: (context, _) => Scaffold(
        appBar: AppBar(
          title: StreamBuilder<bool>(
            initialData: _showSearch.value,
            stream: _showSearch,
            builder: (context, snapshot) {
              return snapshot.data!
                  ? TextField(
                      focusNode: _searchFocus,
                      decoration: InputDecoration(
                          suffixIcon: IconButton(
                            icon: Icon(Icons.close,
                                color: Theme.of(context)
                                    .primaryTextTheme
                                    .headline6!
                                    .color),
                            onPressed: () => setState(
                              () {
                                _search.add('');
                                _showSearch.add(false);
                              },
                            ),
                          ),
                          hintText: 'بحث ...'),
                      onChanged: _search.add,
                    )
                  : const Text('السجلات');
            },
          ),
          actions: [
            StreamBuilder<bool>(
              initialData: _showSearch.value,
              stream: _showSearch,
              builder: (context, snapshot) {
                return snapshot.data!
                    ? IconButton(
                        icon: const Icon(Icons.search),
                        onPressed: () => setState(() {
                          _searchFocus.requestFocus();
                          _showSearch.add(true);
                        }),
                      )
                    : Container();
              },
            ),
            IconButton(
              icon: list == null
                  ? const Icon(Icons.calendar_today)
                  : const Icon(Icons.clear),
              tooltip: list == null ? 'بحث بالتاريخ' : 'محو البحث',
              onPressed: () async {
                if (list == null) {
                  DateTimeRange? result = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(2020, 1, 1),
                    lastDate: DateTime.now(),
                    initialDateRange: DateTimeRange(
                      start: DateTime(DateTime.now().year, DateTime.now().month,
                          DateTime.now().day - 7),
                      end: DateTime.now(),
                    ),
                  );
                  list = result != null
                      ? FirebaseFirestore.instance
                          .collection('ServantsHistory')
                          .orderBy('Day', descending: true)
                          .where(
                            'Day',
                            isLessThanOrEqualTo: Timestamp.fromDate(
                                result.end.add(const Duration(days: 1))),
                          )
                          .where('Day',
                              isGreaterThanOrEqualTo: Timestamp.fromDate(result
                                  .start
                                  .subtract(const Duration(days: 1))))
                          .snapshots()
                      : null;
                  setState(() {});
                } else {
                  list = null;
                  setState(() {});
                }
              },
            )
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () async {
            if (await Connectivity().checkConnectivity() !=
                ConnectivityResult.none) {
              var today = (await FirebaseFirestore.instance
                      .collection('ServantsHistory')
                      .where('Day',
                          isEqualTo: Timestamp.fromMillisecondsSinceEpoch(
                            DateTime.now().millisecondsSinceEpoch -
                                (DateTime.now().millisecondsSinceEpoch %
                                    86400000),
                          ))
                      .get(dataSource))
                  .docs;
              mainScfld.currentState!.openEndDrawer();
              if (today.isNotEmpty) {
                await navigator.currentState!.pushNamed('ServantsDay',
                    arguments: ServantsHistoryDay.fromDoc(today[0]));
              } else {
                await navigator.currentState!.pushNamed('ServantsDay');
              }
            } else {
              await showDialog(
                  context: context,
                  builder: (context) =>
                      const AlertDialog(content: Text('لا يوجد اتصال انترنت')));
            }
          },
          child: const Icon(Icons.add),
        ),
        bottomNavigationBar: Builder(
          builder: (context) => BottomAppBar(
            color: Theme.of(context).primaryColor,
            shape: const CircularNotchedRectangle(),
            child: StreamBuilder<List>(
              stream: context
                  .read<DataObjectListController<ServantsHistoryDay>>()
                  .objectsData,
              builder: (context, snapshot) {
                return Text(
                  (snapshot.data?.length ?? 0).toString() + ' سجل',
                  textAlign: TextAlign.center,
                  strutStyle:
                      StrutStyle(height: IconTheme.of(context).size! / 7.5),
                  style: Theme.of(context).primaryTextTheme.bodyText1,
                );
              },
            ),
          ),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.endDocked,
        extendBody: true,
        body: const DataObjectList<ServantsHistoryDay>(),
      ),
    );
  }
}
