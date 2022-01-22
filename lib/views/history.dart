import 'dart:async';

import 'package:churchdata_core/churchdata_core.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:meetinghelper/models/history/history_record.dart';
import 'package:meetinghelper/models/hive_persistence_provider.dart';
import 'package:rxdart/rxdart.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

import '../utils/globals.dart';

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
  final _searchByDateRange = GlobalKey();

  // ignore: prefer_typing_uninitialized_variables
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
              key: _searchByDateRange,
              icon: !data.hasData
                  ? const Icon(Icons.calendar_today)
                  : const Icon(Icons.clear),
              tooltip: !data.hasData ? 'بحث بالتاريخ' : 'محو البحث',
              onPressed: () async {
                if (!data.hasData) {
                  final DateTimeRange? result = await showDateRangePicker(
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
                  list.add(GetIt.I<DatabaseRepository>()
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
        color: Theme.of(context).colorScheme.primary,
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
          ? DataObjectListView<void, ServantsHistoryDay>(
              autoDisposeController: true,
              controller: _listController,
            )
          : DataObjectListView<void, HistoryDay>(
              autoDisposeController: true,
              controller: _listController,
            ),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance!.addPostFrameCallback((_) {
      if ((['SearchByDateRange']
            ..removeWhere(HivePersistenceProvider.instance.hasCompletedStep))
          .isNotEmpty)
        TutorialCoachMark(
          context,
          focusAnimationDuration: const Duration(milliseconds: 200),
          targets: [
            TargetFocus(
              enableOverlayTab: true,
              contents: [
                TargetContent(
                  child: Text(
                    'يمكنك البحث عن كشف عدة أيام معينة عن طريق الضغط هنا ثم تحديد تاريخ البداية وتاريخ النهاية',
                    style: Theme.of(context).textTheme.subtitle1?.copyWith(
                        color: Theme.of(context).colorScheme.onSecondary),
                  ),
                ),
              ],
              identify: 'SearchByDateRange',
              keyTarget: _searchByDateRange,
              color: Theme.of(context).colorScheme.secondary,
            ),
          ],
          alignSkip: Alignment.bottomLeft,
          textSkip: 'تخطي',
          onClickOverlay: (t) async {
            await HivePersistenceProvider.instance.completeStep(t.identify);
          },
          onClickTarget: (t) async {
            await HivePersistenceProvider.instance.completeStep(t.identify);
          },
        ).show();
    });

    _listController = widget.iServantsHistory
        ? ListController<void, ServantsHistoryDay>(
            objectsPaginatableStream: PaginatableStream.query(
              query: GetIt.I<DatabaseRepository>()
                  .collection('ServantsHistory')
                  .orderBy('Day', descending: true),
              mapper: ServantsHistoryDay.fromQueryDoc,
            ),
          )
        : ListController<void, HistoryDay>(
            objectsPaginatableStream: PaginatableStream.query(
              query: GetIt.I<DatabaseRepository>()
                  .collection('History')
                  .orderBy('Day', descending: true),
              mapper: HistoryDay.fromQueryDoc,
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
