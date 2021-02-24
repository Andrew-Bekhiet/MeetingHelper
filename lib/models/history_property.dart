import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:feature_discovery/feature_discovery.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:meetinghelper/models/history_record.dart';
import 'package:meetinghelper/utils/globals.dart';
import 'package:meetinghelper/utils/helpers.dart';

import 'mini_models.dart';

class HistoryProperty extends StatelessWidget {
  const HistoryProperty(this.name, this.value, this.historyRef,
      {Key key, this.showTime = true})
      : assert(name != null),
        super(key: key);

  final String name;
  final Timestamp value;
  final bool showTime;
  final CollectionReference historyRef;

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
                      value.toDate(),
                    )
                  : '',
              style: Theme.of(context).textTheme.overline),
        ],
      ),
      trailing: IconButton(
        tooltip: 'السجل',
        icon: Icon(Icons.history),
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) => Dialog(
              child: FutureBuilder<List<History>>(
                future: History.getAllFromRef(historyRef),
                builder: (context, history) {
                  if (!history.hasData)
                    return const Center(child: CircularProgressIndicator());
                  if (history.hasError) return ErrorWidget(history.error);
                  if (history.data.isEmpty)
                    return const Center(child: Text('لا يوجد سجل'));
                  return ListView.builder(
                    itemCount: history.data.length,
                    itemBuilder: (context, i) => ListTile(
                      title: FutureBuilder<DocumentSnapshot>(
                        future: FirebaseFirestore.instance
                            .doc('Users/' + history.data[i].byUser)
                            .get(dataSource),
                        builder: (context, user) {
                          return user.hasData
                              ? Text(user.data.data()['Name'])
                              : LinearProgressIndicator();
                        },
                      ),
                      subtitle: Text(DateFormat(
                              showTime ? 'yyyy/M/d h:m a' : 'yyyy/M/d', 'ar-EG')
                          .format(history.data[i].time.toDate())),
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
      {Key key, this.showTime = true, this.discoverFeature = false})
      : assert(name != null),
        super(key: key);

  final String name;
  final String user;
  final bool showTime;
  final bool discoverFeature;
  final CollectionReference historyRef;

  @override
  Widget build(BuildContext context) {
    var icon = IconButton(
      tooltip: 'السجل',
      icon: Icon(Icons.history),
      onPressed: () {
        showDialog(
          context: context,
          builder: (context) => Dialog(
            child: FutureBuilder<List<History>>(
              future: History.getAllFromRef(historyRef),
              builder: (context, history) {
                if (!history.hasData)
                  return const Center(child: CircularProgressIndicator());
                if (history.hasError) return ErrorWidget(history.error);
                if (history.data.isEmpty)
                  return const Center(child: Text('لا يوجد سجل'));
                return ListView.builder(
                  itemCount: history.data.length,
                  itemBuilder: (context, i) => ListTile(
                    title: FutureBuilder<DocumentSnapshot>(
                      future: FirebaseFirestore.instance
                          .doc('Users/' + history.data[i].byUser)
                          .get(dataSource),
                      builder: (context, user) {
                        return user.hasData
                            ? Text(user.data.data()['Name'])
                            : LinearProgressIndicator();
                      },
                    ),
                    subtitle: Text(DateFormat(
                            showTime ? 'yyyy/M/d h:m a' : 'yyyy/M/d', 'ar-EG')
                        .format(history.data[i].time.toDate())),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
    return ListTile(
      title: Text(name),
      subtitle: user != null
          ? FutureBuilder<List>(
              future: Future.wait([
                FirebaseFirestore.instance.doc('Users/' + user).get(dataSource),
                historyRef
                    .orderBy('Time', descending: true)
                    .limit(1)
                    .get(dataSource)
              ]),
              builder: (context, future) {
                return future.hasData
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            flex: 5,
                            child: Text(future.data[0].data()['Name']),
                          ),
                          if ((future.data[1] as QuerySnapshot).docs.isNotEmpty)
                            Flexible(
                              flex: 5,
                              child: Text(
                                  DateFormat(
                                          showTime
                                              ? 'yyyy/M/d   h:m a'
                                              : 'yyyy/M/d',
                                          'ar-EG')
                                      .format(
                                    (future.data[1] as QuerySnapshot)
                                        .docs[0]
                                        .data()['Time']
                                        .toDate(),
                                  ),
                                  style: Theme.of(context).textTheme.overline),
                            ),
                        ],
                      )
                    : LinearProgressIndicator();
              },
            )
          : Text(''),
      trailing: discoverFeature
          ? DescribedFeatureOverlay(
              barrierDismissible: false,
              contentLocation: ContentLocation.above,
              featureId: 'EditHistory',
              tapTarget: Icon(Icons.history),
              title: Text('سجل التعديل'),
              description: Column(
                children: <Widget>[
                  Text('يمكنك الاطلاع على سجل التعديلات من هنا'),
                  OutlinedButton.icon(
                    icon: Icon(Icons.forward),
                    label: Text(
                      'التالي',
                      style: TextStyle(
                        color: Theme.of(context).textTheme.bodyText2.color,
                      ),
                    ),
                    onPressed: () =>
                        FeatureDiscovery.completeCurrentStep(context),
                  ),
                  OutlinedButton(
                    child: Text(
                      'تخطي',
                      style: TextStyle(
                        color: Theme.of(context).textTheme.bodyText2.color,
                      ),
                    ),
                    onPressed: () => FeatureDiscovery.dismissAll(context),
                  ),
                ],
              ),
              backgroundColor: Theme.of(context).accentColor,
              targetColor: Colors.transparent,
              textColor: Theme.of(context).primaryTextTheme.bodyText1.color,
              child: icon)
          : icon,
    );
  }
}

class TimeHistoryProperty extends StatelessWidget {
  const TimeHistoryProperty(this.name, this.value, this.historyRef,
      {Key key, this.showTime = true})
      : assert(name != null),
        super(key: key);

  final String name;
  final Timestamp value;
  final bool showTime;
  final CollectionReference historyRef;

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
                      value.toDate(),
                    )
                  : '',
              style: Theme.of(context).textTheme.overline),
        ],
      ),
      trailing: IconButton(
        tooltip: 'السجل',
        icon: Icon(Icons.history),
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) => Dialog(
              child: FutureBuilder<List<History>>(
                future: History.getAllFromRef(historyRef),
                builder: (context, history) {
                  if (!history.hasData)
                    return const Center(child: CircularProgressIndicator());
                  if (history.hasError) return ErrorWidget(history.error);
                  if (history.data.isEmpty)
                    return const Center(child: Text('لا يوجد سجل'));
                  return ListView.builder(
                    itemCount: history.data.length,
                    itemBuilder: (context, i) => ListTile(
                      title: Text(DateFormat(
                              showTime ? 'yyyy/M/d h:m a' : 'yyyy/M/d', 'ar-EG')
                          .format(history.data[i].time.toDate())),
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
      {Key key})
      : assert(name != null),
        super(key: key);

  final String name;
  final Timestamp value;
  final String id;
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
                      value.toDate(),
                    )
                  : '',
              style: Theme.of(context).textTheme.overline),
        ],
      ),
      trailing: IconButton(
        tooltip: 'السجل',
        icon: Icon(Icons.history),
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) => Dialog(
              // title: Text('السجل'),
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              child: StreamBuilder<List<HistoryRecord>>(
                stream: FirebaseFirestore.instance
                    .collectionGroup(collection)
                    .where('ID', isEqualTo: id)
                    .orderBy('Time', descending: true)
                    .snapshots()
                    .asyncMap((s) async => await Future.wait(s.docs
                        .map((d) async => HistoryRecord.fromDoc(
                            await HistoryDay.fromId(
                                d.reference.parent.parent.id),
                            d))
                        .toList())),
                builder: (context, history) {
                  if (history.hasError) return ErrorWidget(history.error);
                  if (!history.hasData)
                    return const Center(child: CircularProgressIndicator());
                  if (history.data.isEmpty)
                    return const Center(child: Text('لا يوجد سجل'));
                  return ListView.builder(
                    itemCount: history.data.length,
                    itemBuilder: (context, i) => Card(
                      child: ListTile(
                        onTap: () =>
                            historyTap(history.data[i].parent, context),
                        title: Text(DateFormat('yyyy/M/d h:m a', 'ar-EG')
                            .format(history.data[i].time.toDate())),
                        subtitle: history.data[i].recordedBy != null
                            ? FutureBuilder<DocumentSnapshot>(
                                future: FirebaseFirestore.instance
                                    .doc('Users/' + history.data[i].recordedBy)
                                    .get(dataSource),
                                builder: (context, user) {
                                  return user.hasData
                                      ? Text(user.data.data()['Name'] +
                                          (history.data[i].notes != null
                                              ? '\n${history.data[i].notes}'
                                              : ''))
                                      : Text(history.data[i].notes ?? '');
                                },
                              )
                            : Text(history.data[i].notes ?? ''),
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
