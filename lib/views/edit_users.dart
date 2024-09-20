import 'package:churchdata_core/churchdata_core.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:meetinghelper/models.dart';
import 'package:meetinghelper/repositories/database_repository.dart';
import 'package:meetinghelper/utils/globals.dart';
import 'package:rxdart/rxdart.dart';

class UsersPage extends StatefulWidget {
  const UsersPage({super.key});

  @override
  _UsersPageState createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> {
  late final ListController<Class?, UserWithPerson> _listController;
  final BehaviorSubject<bool> isGroupingSubject = BehaviorSubject.seeded(true);
  final BehaviorSubject<bool> isShowingSearch = BehaviorSubject.seeded(false);

  bool wasGroupingBeforeSearch = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions: [
          StreamBuilder<bool>(
            stream: isShowingSearch,
            builder: (context, snapshot) {
              if (!(snapshot.data ?? false)) {
                return IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () {
                    wasGroupingBeforeSearch = isGroupingSubject.value;
                    isShowingSearch.add(true);
                    isGroupingSubject.add(false);
                  },
                );
              }

              return const SizedBox.shrink();
            },
          ),
          // Toggle grouping button
          StreamBuilder<bool>(
            initialData: isGroupingSubject.value,
            stream: isGroupingSubject,
            builder: (context, snapshot) {
              return IconButton(
                icon: snapshot.requireData
                    ? const Icon(Icons.list)
                    : const Icon(Icons.segment),
                tooltip: snapshot.requireData
                    ? 'عرض المستخدمين فقط'
                    : 'تصنيف حسب الفصل',
                onPressed: () => isGroupingSubject.add(!snapshot.data!),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.link),
            tooltip: 'لينكات الدعوة',
            onPressed: () => navigator.currentState!.pushNamed('Invitations'),
          ),
        ],
        title: StreamBuilder<bool>(
          stream: isShowingSearch,
          builder: (context, snapshot) {
            if (snapshot.data ?? false) {
              return TextField(
                autofocus: true,
                decoration: InputDecoration(
                  border: InputBorder.none,
                  suffixIcon: IconButton(
                    color: Theme.of(context).primaryTextTheme.titleLarge!.color,
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      _listController.searchSubject.add('');
                      isShowingSearch.add(false);
                      isGroupingSubject.add(wasGroupingBeforeSearch);
                    },
                  ),
                  hintStyle: Theme.of(context).primaryTextTheme.titleLarge,
                  hintText: 'بحث ...',
                ),
                onChanged: _listController.searchSubject.add,
              );
            }

            return const Text('المستخدمون');
          },
        ),
      ),
      bottomNavigationBar: BottomAppBar(
        color: Theme.of(context).colorScheme.primary,
        shape: const CircularNotchedRectangle(),
        child: StreamBuilder<List>(
          stream: _listController.objectsStream,
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
        autoDisposeController: false,
        controller: _listController,
        onTap: GetIt.I<MHViewableObjectService>().userTap,
      ),
    );
  }

  @override
  void initState() {
    super.initState();

    _listController = ListController<Class?, UserWithPerson>(
      objectsPaginatableStream: PaginatableStream.loadAll(
        stream: MHDatabaseRepo.instance.users.getAllUsersData().map(
              (users) => users.where((u) => u.uid != User.emptyUID).toList(),
            ),
      ),
      groupByStream: MHDatabaseRepo.I.users.groupUsersByClass,
      groupingStream: isGroupingSubject,
    );
  }

  @override
  void dispose() {
    isGroupingSubject.close();
    _listController.dispose();

    super.dispose();
  }
}
