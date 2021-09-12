import 'package:flutter/material.dart';
import 'package:meetinghelper/models/data/user.dart';
import 'package:meetinghelper/models/list_controllers.dart';
import 'package:meetinghelper/utils/globals.dart';
import 'package:meetinghelper/utils/helpers.dart';

import 'lists/users_list.dart';

class UsersPage extends StatefulWidget {
  const UsersPage({Key? key}) : super(key: key);

  @override
  _UsersPageState createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> {
  bool _showSearch = false;
  late final DataObjectListController<User> _listOptions;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
              icon: const Icon(Icons.link),
              tooltip: 'لينكات الدعوة',
              onPressed: () =>
                  navigator.currentState!.pushNamed('Invitations')),
          if (!_showSearch)
            IconButton(
                icon: const Icon(Icons.search),
                onPressed: () => setState(() => _showSearch = true)),
        ],
        title: _showSearch
            ? TextField(
                decoration: InputDecoration(
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(
                        () {
                          _listOptions.searchQuery.add('');
                          _showSearch = false;
                        },
                      ),
                    ),
                    hintStyle: Theme.of(context).primaryTextTheme.headline6,
                    hintText: 'بحث ...'),
                onChanged: _listOptions.searchQuery.add,
              )
            : const Text('المستخدمون'),
      ),
      bottomNavigationBar: BottomAppBar(
        color: Theme.of(context).colorScheme.primary,
        shape: const CircularNotchedRectangle(),
        child: StreamBuilder<List>(
          stream: _listOptions.objectsData,
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
      body: UsersList(
        autoDisposeController: true,
        listOptions: _listOptions,
      ),
    );
  }

  @override
  void initState() {
    super.initState();

    _listOptions = DataObjectListController<User>(
      itemsStream: User.getAllForUserForEdit()
          .map((users) => users.where((u) => u.uid != null).toList()),
      tap: userTap,
    );
  }
}
