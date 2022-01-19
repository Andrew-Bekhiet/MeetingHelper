import 'package:churchdata_core/churchdata_core.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:meetinghelper/models/data/invitation.dart';
import 'package:meetinghelper/utils/globals.dart';

class InvitationsPage extends StatefulWidget {
  const InvitationsPage({Key? key}) : super(key: key);

  @override
  _InvitationsPageState createState() => _InvitationsPageState();
}

class _InvitationsPageState extends State<InvitationsPage> {
  final options = ListController<void, Invitation>(
    searchStream: Stream.value(''),
    objectsPaginatableStream: PaginatableStream.query(
      query: GetIt.I<DatabaseRepository>().collection('Invitations'),
      mapper: Invitation.fromQueryDoc,
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('لينكات الدعوة')),
      body: DataObjectListView<void, Invitation>(
        autoDisposeController: true,
        controller: options,
        onTap: (i) =>
            navigator.currentState!.pushNamed('InvitationInfo', arguments: i),
      ),
      extendBody: true,
      floatingActionButtonLocation: FloatingActionButtonLocation.endDocked,
      bottomNavigationBar: BottomAppBar(
        color: Theme.of(context).colorScheme.primary,
        shape: const CircularNotchedRectangle(),
        child: StreamBuilder<List<Invitation?>>(
          stream: options.objectsStream,
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
