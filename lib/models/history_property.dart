import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:feature_discovery/feature_discovery.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:meetinghelper/models/history_record.dart';
import 'package:meetinghelper/models/user.dart';
import 'package:meetinghelper/utils/globals.dart';
import 'package:meetinghelper/utils/helpers.dart';
import 'package:meetinghelper/utils/typedefs.dart';

import 'mini_models.dart';

class HistoryProperty extends StatelessWidget {
  const HistoryProperty(this.name, this.value, this.historyRef,
      {Key? key, this.showTime = true})
      : super(key: key);

  final String name;
  final Timestamp? value;
  final bool showTime;
  final JsonCollectionRef historyRef;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(name),
      subtitle: Row(
        children: <Widget>[
          Expanded(
            child: Text(toDurationString(value)),
          ),
          Text(
              value != null
                  ? DateFormat(
                          showTime ? 'yyyy/M/d   h:m a' : 'yyyy/M/d', 'ar-EG')
                      .format(
                      value!.toDate(),
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
                          ? FirebaseFirestore.instance
                              .doc('Users/' + history.data![i].byUser!)
                              .get(dataSource)
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
  const EditHistoryProperty(this.name, this.user, this.historyRef,
      {Key? key, this.showTime = true, this.discoverFeature = false})
      : super(key: key);

  final String name;
  final String? user;
  final bool showTime;
  final bool discoverFeature;
  final JsonCollectionRef historyRef;

  @override
  Widget build(BuildContext context) {
    var icon = IconButton(
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
                  itemBuilder: (context, i) => FutureBuilder<User>(
                    future: User.fromID(history.data![i].byUser!),
                    builder: (context, user) {
                      return ListTile(
                        leading: user.hasData
                            ? IgnorePointer(
                                child:
                                    User.photoFromUID(history.data![i].byUser!),
                              )
                            : const CircularProgressIndicator(),
                        title: user.hasData
                            ? Text(user.data!.name)
                            : const LinearProgressIndicator(),
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
    );
    return FutureBuilder<User>(
        future: user != null ? User.fromID(user!) : null,
        builder: (context, user) {
          return ListTile(
            isThreeLine: true,
            title: Text(name),
            subtitle: FutureBuilder<JsonQuery>(
              future: historyRef
                  .orderBy('Time', descending: true)
                  .limit(1)
                  .get(dataSource),
              builder: (context, future) {
                return future.hasData
                    ? ListTile(
                        leading: this.user != null
                            ? IgnorePointer(
                                child: User.photoFromUID(this.user!),
                              )
                            : null,
                        title: this.user != null
                            ? user.hasData
                                ? Text(user.data!.name)
                                : const LinearProgressIndicator()
                            : future.data!.docs.isNotEmpty
                                ? Text(
                                    DateFormat(
                                            showTime
                                                ? 'yyyy/M/d   h:m a'
                                                : 'yyyy/M/d',
                                            'ar-EG')
                                        .format(
                                      future.data!.docs[0]
                                          .data()['Time']
                                          .toDate(),
                                    ),
                                  )
                                : const LinearProgressIndicator(),
                        subtitle: future.data!.docs.isNotEmpty &&
                                this.user != null
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
                            : null,
                      )
                    : const LinearProgressIndicator();
              },
            ),
            trailing: discoverFeature
                ? DescribedFeatureOverlay(
                    barrierDismissible: false,
                    contentLocation: ContentLocation.above,
                    featureId: 'EditHistory',
                    tapTarget: const Icon(Icons.history),
                    title: const Text('سجل التعديل'),
                    description: Column(
                      children: <Widget>[
                        const Text('يمكنك الاطلاع على سجل التعديلات من هنا'),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.forward),
                          label: Text(
                            'التالي',
                            style: TextStyle(
                              color:
                                  Theme.of(context).textTheme.bodyText2!.color,
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
                              color:
                                  Theme.of(context).textTheme.bodyText2!.color,
                            ),
                          ),
                        ),
                      ],
                    ),
                    backgroundColor: Theme.of(context).colorScheme.secondary,
                    targetColor: Colors.transparent,
                    textColor:
                        Theme.of(context).primaryTextTheme.bodyText1!.color!,
                    child: icon,
                  )
                : icon,
          );
        });
  }
}

class TimeHistoryProperty extends StatelessWidget {
  const TimeHistoryProperty(this.name, this.value, this.historyRef,
      {Key? key, this.showTime = true})
      : super(key: key);

  final String name;
  final Timestamp? value;
  final bool showTime;
  final JsonCollectionRef historyRef;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(name),
      subtitle: Row(
        children: <Widget>[
          Expanded(
            child: Text(toDurationString(value)),
          ),
          Text(
              value != null
                  ? DateFormat(
                          showTime ? 'yyyy/M/d   h:m a' : 'yyyy/M/d', 'ar-EG')
                      .format(
                      value!.toDate(),
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
  final Timestamp? value;
  final String? id;
  final String collection;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(name),
      subtitle: Row(
        children: <Widget>[
          Expanded(
            child: Text(toDurationString(value)),
          ),
          Text(
              value != null
                  ? DateFormat('yyyy/M/d   h:m a', 'ar-EG').format(
                      value!.toDate(),
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
                stream: FirebaseFirestore.instance
                    .collectionGroup(collection)
                    .where('ID', isEqualTo: id)
                    .orderBy('Time', descending: true)
                    .snapshots()
                    .asyncMap((s) => Future.wait(s.docs
                        .map((d) async => HistoryRecord.fromDoc(
                            await HistoryDay.fromId(
                                d.reference.parent.parent!.id),
                            d))
                        .toList()))
                    .map((event) => event.whereType<HistoryRecord>().toList()),
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
                        onTap: () => historyTap(history.data![i].parent),
                        title: Text(DateFormat('yyyy/M/d h:m a', 'ar-EG')
                            .format(history.data![i].time.toDate())),
                        subtitle: FutureBuilder<JsonDoc>(
                          future: history.data![i].recordedBy != null
                              ? FirebaseFirestore.instance
                                  .doc('Users/' + history.data![i].recordedBy!)
                                  .get(dataSource)
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
