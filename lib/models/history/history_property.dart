import 'package:churchdata_core/churchdata_core.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:intl/intl.dart';
import 'package:meetinghelper/models/data/class.dart';
import 'package:meetinghelper/models/data/service.dart';
import 'package:meetinghelper/models/data/user.dart';
import 'package:meetinghelper/models/data_object_tap_handler.dart';
import 'package:meetinghelper/models/history/history_record.dart';
import 'package:meetinghelper/repositories/database_repository.dart';
import 'package:rxdart/rxdart.dart';

import '../mini_models.dart.bak';

class HistoryProperty extends StatelessWidget {
  const HistoryProperty(this.name, this.value, this.historyRef,
      {Key? key, this.showTime = true})
      : super(key: key);

  final String name;
  final DateTime? value;
  final bool showTime;
  final JsonCollectionRef historyRef;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(name),
      subtitle: Row(
        children: <Widget>[
          Expanded(
            child: Text(value != null ? value!.toDurationString() : ''),
          ),
          Text(
              value != null
                  ? DateFormat(
                          showTime ? 'yyyy/M/d   h:m a' : 'yyyy/M/d', 'ar-EG')
                      .format(
                      value!,
                    )
                  : '',
              style: Theme.of(context).textTheme.overline),
        ],
      ),
      trailing: IconButton(
        tooltip: 'السجل',
        icon: const Icon(Icons.history),
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) => Dialog(
              child: FutureBuilder<List<History>>(
                future: History.getAllFromRef(historyRef),
                builder: (context, history) {
                  if (!history.hasData)
                    return const Center(child: CircularProgressIndicator());
                  if (history.hasError) return ErrorWidget(history.error!);
                  if (history.data!.isEmpty)
                    return const Center(child: Text('لا يوجد سجل'));
                  return ListView.builder(
                    itemCount: history.data!.length,
                    itemBuilder: (context, i) => FutureBuilder<JsonDoc>(
                      future: history.data![i].byUser != null
                          ? GetIt.I<DatabaseRepository>()
                              .doc('Users/' + history.data![i].byUser!)
                              .get()
                          : null,
                      builder: (context, user) {
                        return ListTile(
                          leading: history.data![i].byUser != null
                              ? IgnorePointer(
                                  child: User.photoFromUID(
                                      history.data![i].byUser!),
                                )
                              : null,
                          title: history.data![i].byUser != null
                              ? user.hasData
                                  ? Text(user.data!.data()!['Name'])
                                  : const LinearProgressIndicator()
                              : const Text('غير معروف'),
                          subtitle: Text(DateFormat(
                                  showTime ? 'yyyy/M/d h:m a' : 'yyyy/M/d',
                                  'ar-EG')
                              .format(history.data![i].time!.toDate())),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}

class EditHistoryProperty extends StatelessWidget {
  const EditHistoryProperty(this.name, this.lastEdit, this.historyRef,
      {Key? key, this.showTime = true})
      : super(key: key);

  final String name;
  final LastEdit? lastEdit;
  final bool showTime;
  final JsonCollectionRef historyRef;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<User?>(
      future: lastEdit?.uid != null
          ? MHDatabaseRepo.instance.getUserName(lastEdit!.uid)
          : null,
      builder: (context, user) {
        return ListTile(
          title: Text(name),
          subtitle: FutureBuilder<JsonQuery>(
            future: historyRef.orderBy('Time', descending: true).limit(1).get(),
            builder: (context, future) {
              if (future.hasData) {
                return ListTile(
                  leading: lastEdit != null
                      ? IgnorePointer(
                          child: User.photoFromUID(lastEdit!.uid),
                        )
                      : null,
                  title: lastEdit != null
                      ? user.hasData
                          ? Text(user.data!.name)
                          : const Text('')
                      : future.data!.docs.isNotEmpty
                          ? Text(
                              DateFormat(
                                      showTime
                                          ? 'yyyy/M/d   h:m a'
                                          : 'yyyy/M/d',
                                      'ar-EG')
                                  .format(
                                future.data!.docs[0].data()['Time'].toDate(),
                              ),
                            )
                          : const Text(''),
                  subtitle: future.data!.docs.isNotEmpty && lastEdit != null
                      ? Text(
                          DateFormat(showTime ? 'yyyy/M/d   h:m a' : 'yyyy/M/d',
                                  'ar-EG')
                              .format(
                            future.data!.docs[0].data()['Time'].toDate(),
                          ),
                        )
                      : null,
                );
              } else {
                return const LinearProgressIndicator();
              }
            },
          ),
          trailing: IconButton(
            tooltip: 'السجل',
            icon: const Icon(Icons.history),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => Dialog(
                  child: FutureBuilder<List<History>>(
                    future: History.getAllFromRef(historyRef),
                    builder: (context, history) {
                      if (!history.hasData)
                        return const Center(child: CircularProgressIndicator());
                      if (history.hasError) return ErrorWidget(history.error!);
                      if (history.data!.isEmpty)
                        return const Center(child: Text('لا يوجد سجل'));
                      return ListView.builder(
                        itemCount: history.data!.length,
                        itemBuilder: (context, i) => FutureBuilder<User?>(
                          future: MHDatabaseRepo.instance
                              .getUserName(history.data![i].byUser ?? ''),
                          builder: (context, user) {
                            return ListTile(
                              leading: user.hasData
                                  ? IgnorePointer(
                                      child: User.photoFromUID(
                                          history.data![i].byUser!),
                                    )
                                  : const CircularProgressIndicator(),
                              title: user.hasData
                                  ? Text(user.data!.name)
                                  : const Text(''),
                              subtitle: Text(DateFormat(
                                      showTime ? 'yyyy/M/d h:m a' : 'yyyy/M/d',
                                      'ar-EG')
                                  .format(history.data![i].time!.toDate())),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class TimeHistoryProperty extends StatelessWidget {
  const TimeHistoryProperty(this.name, this.value, this.historyRef,
      {Key? key, this.showTime = true})
      : super(key: key);

  final String name;
  final DateTime? value;
  final bool showTime;
  final JsonCollectionRef historyRef;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(name),
      subtitle: Row(
        children: <Widget>[
          Expanded(
            child: Text(value != null ? value!.toDurationString() : ''),
          ),
          Text(
              value != null
                  ? DateFormat(
                          showTime ? 'yyyy/M/d   h:m a' : 'yyyy/M/d', 'ar-EG')
                      .format(
                      value!,
                    )
                  : '',
              style: Theme.of(context).textTheme.overline),
        ],
      ),
      trailing: IconButton(
        tooltip: 'السجل',
        icon: const Icon(Icons.history),
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) => Dialog(
              child: FutureBuilder<List<History>>(
                future: History.getAllFromRef(historyRef),
                builder: (context, history) {
                  if (!history.hasData)
                    return const Center(child: CircularProgressIndicator());
                  if (history.hasError) return ErrorWidget(history.error!);
                  if (history.data!.isEmpty)
                    return const Center(child: Text('لا يوجد سجل'));
                  return ListView.builder(
                    itemCount: history.data!.length,
                    itemBuilder: (context, i) => ListTile(
                      title: Text(DateFormat(
                              showTime ? 'yyyy/M/d h:m a' : 'yyyy/M/d', 'ar-EG')
                          .format(history.data![i].time!.toDate())),
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}

class DayHistoryProperty extends StatelessWidget {
  const DayHistoryProperty(this.name, this.value, this.id, this.collection,
      {Key? key})
      : super(key: key);

  final String name;
  final DateTime? value;
  final String? id;
  final String collection;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(name),
      subtitle: Row(
        children: <Widget>[
          Expanded(
            child: Text(value?.toDurationString() ?? ''),
          ),
          Text(
              value != null
                  ? DateFormat('yyyy/M/d   h:m a', 'ar-EG').format(
                      value!,
                    )
                  : '',
              style: Theme.of(context).textTheme.overline),
        ],
      ),
      trailing: IconButton(
        tooltip: 'السجل',
        icon: const Icon(Icons.history),
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) => Dialog(
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              child: StreamBuilder<List<HistoryRecord>>(
                stream: User.loggedInStream.switchMap(
                  (user) {
                    Stream<List<HistoryRecord>> _completeQuery(
                        QueryOfJson query) {
                      return query
                          .orderBy('Time', descending: true)
                          .snapshots()
                          .asyncMap((s) => Future.wait(s.docs
                              .map((d) async => HistoryRecord.fromDoc(
                                  d.reference.parent.parent!.parent.id ==
                                          'ServantsHistory'
                                      ? await ServantsHistoryDay.fromId(
                                          d.reference.parent.parent!.id)
                                      : await HistoryDay.fromId(
                                          d.reference.parent.parent!.id),
                                  d))
                              .toList()))
                          .map((event) =>
                              event.whereType<HistoryRecord>().toList());
                    }

                    final query = GetIt.I<DatabaseRepository>()
                        .collectionGroup(collection)
                        .where('ID', isEqualTo: id);

                    if (!user.permissions.superAccess) {
                      if (collection == 'Meeting' ||
                          collection == 'Kodas' ||
                          collection == 'Confession') {
                        return Class.getAllForUser().switchMap(
                          (classes) {
                            if (classes.isEmpty) return Stream.value([]);
                            if (classes.length <= 10)
                              return _completeQuery(
                                query.where(
                                  'ClassId',
                                  whereIn: classes.map((c) => c.ref).toList(),
                                ),
                              );

                            return Rx.combineLatest<List<HistoryRecord>,
                                List<HistoryRecord>>(
                              classes.split(10).map(
                                    (chunk) => _completeQuery(
                                      query.where(
                                        'ClassId',
                                        whereIn:
                                            chunk.map((c) => c.ref).toList(),
                                      ),
                                    ),
                                  ),
                              (values) => values
                                  .expand((e) => e)
                                  .sortedByCompare<Timestamp>(
                                      (r) => r.time, (o, n) => -o.compareTo(n))
                                  .toList(),
                            );
                          },
                        );
                      }
                      return Service.getAllForUser().switchMap(
                        (services) {
                          if (services.isEmpty) return Stream.value([]);
                          if (services.length <= 10)
                            return _completeQuery(
                              query.where(
                                'Services',
                                arrayContainsAny:
                                    services.map((c) => c.ref).toList(),
                              ),
                            );

                          return Rx.combineLatest<List<HistoryRecord>,
                              List<HistoryRecord>>(
                            services.split(10).map(
                                  (chunk) => _completeQuery(
                                    query.where(
                                      'Services',
                                      arrayContainsAny:
                                          chunk.map((c) => c.ref).toList(),
                                    ),
                                  ),
                                ),
                            (values) => values
                                .expand((e) => e)
                                .sortedByCompare<Timestamp>(
                                    (r) => r.time, (o, n) => -o.compareTo(n))
                                .toList(),
                          );
                        },
                      );
                    }

                    return _completeQuery(query);
                  },
                ),
                builder: (context, history) {
                  if (history.hasError) return ErrorWidget(history.error!);
                  if (!history.hasData)
                    return const Center(child: CircularProgressIndicator());
                  if (history.data!.isEmpty)
                    return const Center(child: Text('لا يوجد سجل'));
                  return ListView.builder(
                    itemCount: history.data!.length,
                    itemBuilder: (context, i) => Card(
                      child: ListTile(
                        onTap: () => GetIt.I<MHDataObjectTapHandler>()
                            .historyTap(history.data![i].parent),
                        title: Text(DateFormat('yyyy/M/d h:m a', 'ar-EG')
                            .format(history.data![i].time.toDate())),
                        subtitle: FutureBuilder<JsonDoc>(
                          future: history.data![i].recordedBy != null
                              ? GetIt.I<DatabaseRepository>()
                                  .doc('Users/' + history.data![i].recordedBy!)
                                  .get()
                              : null,
                          builder: (context, user) {
                            return user.hasData
                                ? Text(user.data!.data()!['Name'] +
                                    (history.data![i].notes != null
                                        ? '\n${history.data![i].notes}'
                                        : ''))
                                : Text(history.data![i].notes ?? '');
                          },
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}
