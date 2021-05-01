import 'package:flutter/material.dart';
import 'package:meetinghelper/models/list_options.dart';
import 'package:meetinghelper/models/user.dart';
import 'package:meetinghelper/utils/globals.dart';
import 'package:meetinghelper/utils/helpers.dart';
import 'package:rxdart/rxdart.dart';

import 'lists/users_list.dart';

class UsersPage extends StatefulWidget {
  UsersPage({Key key}) : super(key: key);
  @override
  _UsersPageState createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> {
  bool _showSearch = false;
  final BehaviorSubject<String> _search = BehaviorSubject<String>.seeded('');

  @override
  Widget build(BuildContext context) {
    var _listOptions = DataObjectListOptions<User>(
      itemsStream: User.getAllForUserForEdit(),
      searchQuery: _search,
      tap: (u) => userTap(u, context),
    );
    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
              icon: Icon(Icons.link),
              tooltip: 'لينكات الدعوة',
              onPressed: () => navigator.currentState.pushNamed('Invitations')),
          if (!_showSearch)
            IconButton(
                icon: Icon(Icons.search),
                onPressed: () => setState(() => _showSearch = true)),
        ],
        title: _showSearch
            ? TextField(
                decoration: InputDecoration(
                    suffixIcon: IconButton(
                      icon: Icon(Icons.close),
                      onPressed: () => setState(
                        () {
                          _search.add('');
                          _showSearch = false;
                        },
                      ),
                    ),
                    hintStyle: Theme.of(context).primaryTextTheme.headline6,
                    hintText: 'بحث ...'),
                onChanged: _search.add,
              )
            : Text('المستخدمون'),
      ),
      bottomNavigationBar: BottomAppBar(
        color: Theme.of(context).primaryColor,
        shape: const CircularNotchedRectangle(),
        child: StreamBuilder(
          stream: _listOptions.objectsData,
          builder: (context, snapshot) {
            return Text(
              (snapshot.data?.length ?? 0).toString() + ' مستخدم',
              textAlign: TextAlign.center,
              strutStyle: StrutStyle(height: IconTheme.of(context).size / 7.5),
              style: Theme.of(context).primaryTextTheme.bodyText1,
            );
          },
        ),
      ),
      body: UsersList(
        listOptions: _listOptions,
      ),
    );
  }
}
