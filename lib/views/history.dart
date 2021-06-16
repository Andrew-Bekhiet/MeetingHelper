import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:feature_discovery/feature_discovery.dart';
import 'package:flutter/material.dart';
import 'package:meetinghelper/utils/typedefs.dart';
import 'package:rxdart/rxdart.dart';

import '../models/list_controllers.dart';
import '../models/models.dart';
import '../utils/globals.dart';
import '../utils/helpers.dart';
import 'list.dart';

class History extends StatefulWidget {
  final bool iServantsHistory;
  const History({Key? key, required this.iServantsHistory}) : super(key: key);

  @override
  State<StatefulWidget> createState() => _HistoryState();
}

class _HistoryState extends State<History> {
  final BehaviorSubject<Stream<JsonQuery>?> list = BehaviorSubject.seeded(null);
  final BehaviorSubject<bool> _showSearch = BehaviorSubject<bool>.seeded(false);
  final FocusNode _searchFocus = FocusNode();

  late final _listController;

  @override
  Widget build(BuildContext context) {
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
                              _listController.searchQuery.add('');
                              _showSearch.add(false);
                            },
                          ),
                        ),
                        hintText: 'بحث ...'),
                    onChanged: _listController.searchQuery.add,
                  )
                : const Text('السجلات');
          },
        ),
        actions: [
          StreamBuilder<bool>(
            initialData: _showSearch.value,
            stream: _showSearch,
            builder: (context, snapshot) {
              return !snapshot.data!
                  ? IconButton(
                      icon: const Icon(Icons.search),
                      onPressed: () => setState(
                        () {
                          _searchFocus.requestFocus();
                          _showSearch.add(true);
                        },
                      ),
                    )
                  : Container();
            },
          ),
          StreamBuilder<Stream?>(
            stream: list,
            builder: (context, data) => IconButton(
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
                textColor: Theme.of(context).primaryTextTheme.bodyText1!.color!,
                child: !data.hasData
                    ? const Icon(Icons.calendar_today)
                    : const Icon(Icons.clear),
              ),
              tooltip: !data.hasData ? 'بحث بالتاريخ' : 'محو البحث',
              onPressed: () async {
                if (!data.hasData) {
                  DateTimeRange? result = await showDateRangePicker(
                    builder: (context, dialog) => Theme(
                      data: Theme.of(context).copyWith(
                        textTheme: Theme.of(context).textTheme.copyWith(
                              overline: const TextStyle(
                                fontSize: 0,
                              ),
                            ),
                      ),
                      child: dialog!,
                    ),
                    helpText: null,
                    context: context,
                    confirmText: 'بحث',
                    saveText: 'بحث',
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                    initialDateRange: DateTimeRange(
                      start: DateTime(DateTime.now().year, DateTime.now().month,
                          DateTime.now().day - 7),
                      end: DateTime.now(),
                    ),
                  );
                  if (result == null) return;
                  list.add(FirebaseFirestore.instance
                      .collection((widget.iServantsHistory ? 'Servants' : '') +
                          'History')
                      .orderBy('Day', descending: true)
                      .where('Day',
                          isGreaterThanOrEqualTo: Timestamp.fromDate(
                              result.start.subtract(const Duration(days: 1))))
                      .where(
                        'Day',
                        isLessThanOrEqualTo: Timestamp.fromDate(
                            result.end.add(const Duration(days: 1))),
                      )
                      .snapshots());
                } else {
                  list.add(null);
                }
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => navigator.currentState!.pushNamed('Day'),
        child: const Icon(Icons.add),
      ),
      bottomNavigationBar: BottomAppBar(
        color: Theme.of(context).primaryColor,
        shape: const CircularNotchedRectangle(),
        child: StreamBuilder<List>(
          stream: _listController.objectsData,
          builder: (context, snapshot) {
            return Text(
              (snapshot.data?.length ?? 0).toString() + ' سجل',
              textAlign: TextAlign.center,
              strutStyle: StrutStyle(height: IconTheme.of(context).size! / 7.5),
              style: Theme.of(context).primaryTextTheme.bodyText1,
            );
          },
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endDocked,
      extendBody: true,
      body: widget.iServantsHistory
          ? DataObjectList<ServantsHistoryDay>(
              disposeController: true,
              options: _listController,
            )
          : DataObjectList<HistoryDay>(
              disposeController: true,
              options: _listController,
            ),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance!.addPostFrameCallback((_) =>
        FeatureDiscovery.discoverFeatures(context, ['SearchByDateRange']));

    _listController = widget.iServantsHistory
        ? DataObjectListController<ServantsHistoryDay>(
            tap: historyTap,
            itemsStream: list
                .switchMap(
                  (q) =>
                      q ??
                      FirebaseFirestore.instance
                          .collection('ServantsHistory')
                          .orderBy('Day', descending: true)
                          .snapshots(),
                )
                .map(
                  (s) => s.docs.map(ServantsHistoryDay.fromQueryDoc).toList(),
                ),
          )
        : DataObjectListController<HistoryDay>(
            tap: historyTap,
            itemsStream: list
                .switchMap(
                  (q) =>
                      q ??
                      FirebaseFirestore.instance
                          .collection('History')
                          .orderBy('Day', descending: true)
                          .snapshots(),
                )
                .map(
                  (s) => s.docs.map(HistoryDay.fromQueryDoc).toList(),
                ),
          );
  }

  @override
  Future<void> dispose() async {
    super.dispose();
    await _showSearch.close();
    await list.close();
  }
}
