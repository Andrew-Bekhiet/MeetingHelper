import 'package:churchdata_core/churchdata_core.dart';
import 'package:flutter/material.dart';
import 'package:meetinghelper/models/data/class.dart';
import 'package:meetinghelper/models/data/user.dart';
import 'package:meetinghelper/repositories/database_repository.dart';
import 'package:meetinghelper/utils/globals.dart';
import 'package:meetinghelper/utils/helpers.dart';

class UsersPage extends StatefulWidget {
  const UsersPage({Key? key}) : super(key: key);

  @override
  _UsersPageState createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> {
  bool _showSearch = false;
  late final ListController<Class?, User> _listOptions;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            icon: const Icon(Icons.link),
            tooltip: 'لينكات الدعوة',
            onPressed: () => navigator.currentState!.pushNamed('Invitations'),
          ),
          if (!_showSearch)
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: () => setState(() => _showSearch = true),
            ),
        ],
        title: _showSearch
            ? TextField(
                decoration: InputDecoration(
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(
                        () {
                          _listOptions.searchSubject.add('');
                          _showSearch = false;
                        },
                      ),
                    ),
                    hintStyle: Theme.of(context).primaryTextTheme.headline6,
                    hintText: 'بحث ...'),
                onChanged: _listOptions.searchSubject.add,
              )
            : const Text('المستخدمون'),
      ),
      bottomNavigationBar: BottomAppBar(
        color: Theme.of(context).colorScheme.primary,
        shape: const CircularNotchedRectangle(),
        child: StreamBuilder<List>(
          stream: _listOptions.objectsStream,
          builder: (context, snapshot) {
            return Text(
              (snapshot.data?.length ?? 0).toString() + ' مستخدم',
              textAlign: TextAlign.center,
              strutStyle: StrutStyle(height: IconTheme.of(context).size! / 7.5),
              style: Theme.of(context).primaryTextTheme.bodyText1,
            );
          },
        ),
      ),
      body: DataObjectListView(
        autoDisposeController: true,
        controller: _listOptions,
      ),
    );
  }

  @override
  void initState() {
    super.initState();

    _listOptions = ListController<Class?, User>(
      objectsPaginatableStream: PaginatableStream.loadAll(
        stream: MHDatabaseRepo.instance.getAllUsers().map(
              (users) => users.where((u) => u.uid != User.emptyUID).toList(),
            ),
      ),
      groupByStream: usersByClass,
      groupingStream: Stream.value(true),
    );
  }
}
