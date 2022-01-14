import 'package:churchdata_core/churchdata_core.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:meetinghelper/models/data/invitation.dart';
import 'package:meetinghelper/utils/globals.dart';
import 'package:meetinghelper/views/list.dart';

class InvitationsPage extends StatefulWidget {
  const InvitationsPage({Key? key}) : super(key: key);

  @override
  _InvitationsPageState createState() => _InvitationsPageState();
}

class _InvitationsPageState extends State<InvitationsPage> {
  final options = ListController<Invitation>(
    searchQuery: Stream.value(''),
    itemsStream: GetIt.I<DatabaseRepository>()
        .collection('Invitations')
        .snapshots()
        .map((s) => s.docs.map(Invitation.fromQueryDoc).toList()),
    tap: (dynamic i) =>
        navigator.currentState!.pushNamed('InvitationInfo', arguments: i),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('لينكات الدعوة')),
      body: DataObjectList<Invitation>(
        disposeController: true,
        options: options,
      ),
      extendBody: true,
      floatingActionButtonLocation: FloatingActionButtonLocation.endDocked,
      bottomNavigationBar: BottomAppBar(
        color: Theme.of(context).colorScheme.primary,
        shape: const CircularNotchedRectangle(),
        child: StreamBuilder<List<Invitation?>>(
          stream: options.objectsData,
          builder: (context, snapshot) {
            return Text((snapshot.data?.length ?? 0).toString() + ' دعوة',
                textAlign: TextAlign.center,
                strutStyle:
                    StrutStyle(height: IconTheme.of(context).size! / 7.5),
                style: Theme.of(context).primaryTextTheme.bodyText1);
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'اضافة دعوة',
        onPressed: () => navigator.currentState!.pushNamed('EditInvitation'),
        child: const Icon(Icons.add_link),
      ),
    );
  }
}
