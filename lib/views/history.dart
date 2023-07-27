import 'dart:async';

import 'package:churchdata_core/churchdata_core.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:meetinghelper/models.dart';
import 'package:meetinghelper/utils/globals.dart';
import 'package:rxdart/rxdart.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

class History extends StatefulWidget {
  final bool isServantsHistory;
  const History({
    required this.isServantsHistory,
    super.key,
  });

  @override
  State<StatefulWidget> createState() => _HistoryState();
}

class _HistoryState extends State<History> {
  final BehaviorSubject<bool> _showSearch = BehaviorSubject<bool>.seeded(false);
  final FocusNode _searchFocus = FocusNode();
  final _searchByDateRange = GlobalKey();

  bool _filteredQuery = false;
  late final BehaviorSubject<QueryOfJson> query =
      BehaviorSubject.seeded(getOriginalQuery());
  late final ListController<void, HistoryDayBase> _listController =
      widget.isServantsHistory
          ? ListController<void, ServantsHistoryDay>(
              objectsPaginatableStream: PaginatableStream(
                query: query,
                mapper: ServantsHistoryDay.fromQueryDoc,
              ),
            )
          : ListController<void, HistoryDay>(
              objectsPaginatableStream: PaginatableStream(
                query: query,
                mapper: HistoryDay.fromQueryDoc,
              ),
            );

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
                        icon: Icon(
                          Icons.close,
                          color: Theme.of(context)
                              .primaryTextTheme
                              .titleLarge!
                              .color,
                        ),
                        onPressed: () => setState(
                          () {
                            _listController.searchSubject.add('');
                            _showSearch.add(false);
                          },
                        ),
                      ),
                      hintText: 'بحث ...',
                    ),
                    onChanged: _listController.searchSubject.add,
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
          StreamBuilder<QueryOfJson>(
            stream: query,
            builder: (context, data) => IconButton(
              key: _searchByDateRange,
              icon: !_filteredQuery
                  ? const Icon(Icons.calendar_today)
                  : const Icon(Icons.clear),
              tooltip: !_filteredQuery ? 'بحث بالتاريخ' : 'محو البحث',
              onPressed: () async {
                if (!_filteredQuery) {
                  final DateTimeRange? result = await showDateRangePicker(
                    builder: (context, dialog) => Theme(
                      data: Theme.of(context).copyWith(
                        textTheme: Theme.of(context).textTheme.copyWith(
                              labelSmall: const TextStyle(
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
                      start: DateTime(
                        DateTime.now().year,
                        DateTime.now().month,
                        DateTime.now().day - 7,
                      ),
                      end: DateTime.now(),
                    ),
                  );
                  if (result == null) return;

                  _filteredQuery = true;
                  query.add(
                    GetIt.I<DatabaseRepository>()
                        .collection(
                          (widget.isServantsHistory ? 'Servants' : '') +
                              'History',
                        )
                        .orderBy('Day', descending: true)
                        .where(
                          'Day',
                          isGreaterThanOrEqualTo: Timestamp.fromDate(
                            result.start.subtract(const Duration(days: 1)),
                          ),
                        )
                        .where(
                          'Day',
                          isLessThanOrEqualTo: Timestamp.fromDate(
                            result.end.add(const Duration(days: 1)),
                          ),
                        ),
                  );
                } else {
                  _filteredQuery = false;
                  query.add(getOriginalQuery());
                }
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => navigator.currentState!
            .pushNamed((widget.isServantsHistory ? 'Servants' : '') + 'Day'),
        child: const Icon(Icons.add),
      ),
      bottomNavigationBar: BottomAppBar(
        color: Theme.of(context).colorScheme.primary,
        shape: const CircularNotchedRectangle(),
        child: StreamBuilder<List>(
          stream: _listController.objectsStream,
          builder: (context, snapshot) {
            return Text(
              (snapshot.data?.length ?? 0).toString() + ' سجل',
              textAlign: TextAlign.center,
              strutStyle: StrutStyle(height: IconTheme.of(context).size! / 7.5),
              style: Theme.of(context).primaryTextTheme.bodyLarge,
            );
          },
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endDocked,
      extendBody: true,
      body: widget.isServantsHistory
          ? DataObjectListView<void, ServantsHistoryDay>(
              autoDisposeController: true,
              controller:
                  _listController as ListController<void, ServantsHistoryDay>,
            )
          : DataObjectListView<void, HistoryDay>(
              autoDisposeController: true,
              controller: _listController as ListController<void, HistoryDay>,
            ),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if ((['SearchByDateRange']
            ..removeWhere(HivePersistenceProvider.instance.hasCompletedStep))
          .isNotEmpty) {
        TutorialCoachMark(
          focusAnimationDuration: const Duration(milliseconds: 200),
          targets: [
            TargetFocus(
              enableOverlayTab: true,
              contents: [
                TargetContent(
                  child: Text(
                    'يمكنك البحث عن كشف عدة أيام معينة عن طريق الضغط هنا ثم تحديد تاريخ البداية وتاريخ النهاية',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSecondary,
                        ),
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
        ).show(context: context);
      }
    });
  }

  QueryOfJson getOriginalQuery() {
    return widget.isServantsHistory
        ? GetIt.I<DatabaseRepository>()
            .collection('ServantsHistory')
            .orderBy('Day', descending: true)
        : GetIt.I<DatabaseRepository>()
            .collection('History')
            .orderBy('Day', descending: true);
  }

  @override
  Future<void> dispose() async {
    super.dispose();
    await _showSearch.close();
    await query.close();
  }
}
