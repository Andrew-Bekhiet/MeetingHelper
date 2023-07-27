import 'package:churchdata_core/churchdata_core.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:meetinghelper/models.dart';
import 'package:meetinghelper/repositories/database_repository.dart';
import 'package:meetinghelper/utils/globals.dart';

class UsersPage extends StatefulWidget {
  const UsersPage({super.key});

  @override
  _UsersPageState createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> {
  bool _showSearch = false;
  late final ListController<Class?, UserWithPerson> _listOptions;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions: [
          if (!_showSearch)
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: () => setState(() => _showSearch = true),
            ),
          IconButton(
            icon: const Icon(Icons.link),
            tooltip: 'لينكات الدعوة',
            onPressed: () => navigator.currentState!.pushNamed('Invitations'),
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
                  hintStyle: Theme.of(context).primaryTextTheme.titleLarge,
                  hintText: 'بحث ...',
                ),
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
              style: Theme.of(context).primaryTextTheme.bodyLarge,
            );
          },
        ),
      ),
      body: DataObjectListView<Class?, UserWithPerson>(
        autoDisposeController: true,
        controller: _listOptions,
        onTap: GetIt.I<MHViewableObjectService>().userTap,
      ),
    );
  }

  @override
  void initState() {
    super.initState();

    _listOptions = ListController<Class?, UserWithPerson>(
      objectsPaginatableStream: PaginatableStream.loadAll(
        stream: MHDatabaseRepo.instance.users.getAllUsersData().map(
              (users) => users.where((u) => u.uid != User.emptyUID).toList(),
            ),
      ),
      groupByStream: (u) => MHDatabaseRepo.I.users.groupUsersByClass(u).map(
            (event) => event.map(
              (key, value) => MapEntry(
                key,
                value.cast<UserWithPerson>(),
              ),
            ),
          ),
      groupingStream: Stream.value(true),
    );
  }
}
