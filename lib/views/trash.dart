import 'package:churchdata_core/churchdata_core.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:meetinghelper/models.dart';
import 'package:meetinghelper/repositories.dart';
import 'package:meetinghelper/utils/globals.dart';
import 'package:meetinghelper/widgets.dart';
import 'package:rxdart/rxdart.dart';
import 'package:tuple/tuple.dart';

class Trash extends StatelessWidget {
  const Trash({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('سلة المحذوفات')),
      body: DataObjectListView<void, TrashDay>(
        autoDisposeController: true,
        onLongPress: (_) {},
        onTap: (day) {
          navigator.currentState!.push(
            MaterialPageRoute(builder: (context) => TrashDayScreen(day)),
          );
        },
        controller: ListController(
          objectsPaginatableStream: PaginatableStream.query(
            query: GetIt.I<DatabaseRepository>()
                .collection('Deleted')
                .orderBy('Time', descending: true),
            mapper: (d) => TrashDay(d.data()['Time'].toDate(), d.reference),
          ),
        ),
      ),
    );
  }
}

class TrashDay extends DataObject {
  final DateTime date;
  TrashDay(this.date, JsonRef ref)
      : super(ref, date.toUtc().toIso8601String().split('T')[0]);

  @override
  Json toJson() {
    return {'Time': Timestamp.fromDate(date)};
  }

  @override
  Future<String?> getSecondLine() async {
    return name;
  }
}

class TrashDayScreen extends StatefulWidget {
  final TrashDay day;
  const TrashDayScreen(this.day, {super.key});

  @override
  _TrashDayScreenState createState() => _TrashDayScreenState();
}

class _TrashDayScreenState extends State<TrashDayScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  TabController? _tabController;
  bool dialogsNotShown = true;

  final BehaviorSubject<bool> _showSearch = BehaviorSubject<bool>.seeded(false);
  final FocusNode _searchFocus = FocusNode();

  final BehaviorSubject<OrderOptions> _personsOrder =
      BehaviorSubject.seeded(const OrderOptions());
  final BehaviorSubject<String> _searchQuery =
      BehaviorSubject<String>.seeded('');

  late final ListController<void, Person> _personsOptions;
  late final ListController<void, Class> _classesOptions;
  late final ListController<void, Service> _servicesOptions;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions: <Widget>[
          StreamBuilder<bool>(
            initialData: false,
            stream: _showSearch,
            builder: (context, data) => data.data!
                ? AnimatedBuilder(
                    animation: _tabController!,
                    builder: (context, child) =>
                        _tabController!.index == 1 ? child! : Container(),
                    child: IconButton(
                      icon: const Icon(Icons.filter_list),
                      onPressed: () async {
                        await showDialog(
                          context: context,
                          builder: (context) => SimpleDialog(
                            children: [
                              TextButton.icon(
                                icon: const Icon(Icons.select_all),
                                label: const Text('تحديد الكل'),
                                onPressed: () {
                                  _personsOptions.selectAll();
                                  navigator.currentState!.pop();
                                },
                              ),
                              TextButton.icon(
                                icon: const Icon(Icons.select_all),
                                label: const Text('تحديد لا شئ'),
                                onPressed: () {
                                  _personsOptions.deselectAll();
                                  navigator.currentState!.pop();
                                },
                              ),
                              const Text(
                                'ترتيب حسب:',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              ...Person.propsMetadata().entries.map(
                                    (e) => RadioListTile(
                                      value: e.key,
                                      groupValue: _personsOrder.value.orderBy,
                                      title: Text(e.value.label),
                                      onChanged: (dynamic value) {
                                        _personsOrder.add(
                                          OrderOptions(
                                            orderBy: value,
                                            asc: _personsOrder.value.asc,
                                          ),
                                        );
                                        navigator.currentState!.pop();
                                      },
                                    ),
                                  ),
                              RadioListTile(
                                value: true,
                                groupValue: _personsOrder.value.asc,
                                title: const Text('تصاعدي'),
                                onChanged: (dynamic value) {
                                  _personsOrder.add(
                                    OrderOptions(
                                      orderBy: _personsOrder.value.orderBy,
                                      asc: value,
                                    ),
                                  );
                                  navigator.currentState!.pop();
                                },
                              ),
                              RadioListTile(
                                value: false,
                                groupValue: _personsOrder.value.asc,
                                title: const Text('تنازلي'),
                                onChanged: (dynamic value) {
                                  _personsOrder.add(
                                    OrderOptions(
                                      orderBy: _personsOrder.value.orderBy,
                                      asc: value,
                                    ),
                                  );
                                  navigator.currentState!.pop();
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  )
                : IconButton(
                    icon: const Icon(Icons.search),
                    onPressed: () {
                      _searchFocus.requestFocus();
                      _showSearch.add(true);
                    },
                  ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(
              text: 'الخدمات',
              icon: Icon(Icons.miscellaneous_services),
            ),
            Tab(
              text: 'الفصول',
              icon: Icon(Icons.group),
            ),
            Tab(
              text: 'المخدومين',
              icon: Icon(Icons.person),
            ),
          ],
        ),
        title: StreamBuilder<bool>(
          initialData: _showSearch.value,
          stream: _showSearch,
          builder: (context, data) => data.data!
              ? TextField(
                  focusNode: _searchFocus,
                  style: Theme.of(context).textTheme.titleLarge!.copyWith(
                        color: Theme.of(context)
                            .primaryTextTheme
                            .titleLarge!
                            .color,
                      ),
                  decoration: InputDecoration(
                    suffixIcon: IconButton(
                      icon: Icon(
                        Icons.close,
                        color: Theme.of(context)
                            .primaryTextTheme
                            .titleLarge!
                            .color,
                      ),
                      onPressed: () {
                        _searchQuery.add('');
                        _showSearch.add(false);
                      },
                    ),
                    hintStyle: Theme.of(context).textTheme.titleLarge!.copyWith(
                          color: Theme.of(context)
                              .primaryTextTheme
                              .titleLarge!
                              .color,
                        ),
                    icon: Icon(
                      Icons.search,
                      color:
                          Theme.of(context).primaryTextTheme.titleLarge!.color,
                    ),
                    hintText: 'بحث ...',
                  ),
                  onChanged: _searchQuery.add,
                )
              : const Text('البيانات'),
        ),
      ),
      bottomNavigationBar: BottomAppBar(
        color: Theme.of(context).colorScheme.primary,
        shape: const CircularNotchedRectangle(),
        child: AnimatedBuilder(
          animation: _tabController!,
          builder: (context, _) => StreamBuilder<List>(
            stream: _tabController!.index == 0
                ? _servicesOptions.objectsStream
                : _tabController!.index == 1
                    ? _classesOptions.objectsStream
                    : _personsOptions.objectsStream,
            builder: (context, snapshot) {
              return Text(
                (snapshot.data?.length ?? 0).toString() +
                    ' ' +
                    (_tabController!.index != 2 ? 'خدمة' : 'مخدوم'),
                textAlign: TextAlign.center,
                strutStyle:
                    StrutStyle(height: IconTheme.of(context).size! / 7.5),
                style: Theme.of(context).primaryTextTheme.bodyLarge,
              );
            },
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          if (User.instance.permissions.superAccess)
            DataObjectListView<void, Service>(
              autoDisposeController: true,
              controller: _servicesOptions,
            )
          else
            const Center(
              child: Text('يلزم صلاحية رؤية جميع البيانات لاسترجاع الخدمات'),
            ),
          DataObjectListView<void, Class>(
            autoDisposeController: true,
            controller: _classesOptions,
          ),
          DataObjectListView<void, Person>(
            autoDisposeController: true,
            controller: _personsOptions,
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(vsync: this, length: 3, initialIndex: 1);
    WidgetsBinding.instance.addObserver(this);

    _servicesOptions = ListController<void, Service>(
      searchStream: _searchQuery,
      objectsPaginatableStream: PaginatableStream.query(
        query: widget.day.ref.collection('Services'),
        mapper: Service.fromQueryDoc,
      ),
    );

    _classesOptions = ListController<void, Class>(
      searchStream: _searchQuery,
      objectsPaginatableStream: PaginatableStream.query(
        query: User.instance.permissions.superAccess
            ? widget.day.ref.collection('Classes')
            : GetIt.I<DatabaseRepository>().collection('Classes').where(
                  'Allowed',
                  arrayContains: User.instance.uid,
                ),
        mapper: Class.fromDoc,
      ),
    );

    _personsOptions = ListController<void, Person>(
      searchStream: _searchQuery,
      objectsPaginatableStream: PaginatableStream.loadAll(
        stream: Rx.combineLatest2<User, List<Class>, Tuple2<User, List<Class>>>(
          User.loggedInStream,
          MHDatabaseRepo.I.classes.getAll(),
          Tuple2.new,
        ).switchMap(
          (u) {
            if (u.item1.permissions.superAccess) {
              return widget.day.ref
                  .collection('Persons')
                  .snapshots()
                  .map((p) => p.docs.map(Person.fromDoc).toList());
            } else if (u.item2.length <= 10) {
              return widget.day.ref
                  .collection('Persons')
                  .where('ClassId', whereIn: u.item2.map((e) => e.ref).toList())
                  .snapshots()
                  .map((p) => p.docs.map(Person.fromDoc).toList());
            }
            return Rx.combineLatestList<JsonQuery>(
              u.item2.split(10).map(
                    (c) => widget.day.ref
                        .collection('Persons')
                        .where('ClassId', whereIn: c.map((e) => e.ref).toList())
                        .snapshots(),
                  ),
            ).map(
              (s) => s.expand((n) => n.docs).map(Person.fromDoc).toList(),
            );
          },
        ),
      ),
    );
  }

  @override
  Future<void> dispose() async {
    super.dispose();
    WidgetsBinding.instance.removeObserver(this);
    await _showSearch.close();
    await _personsOrder.close();
    await _searchQuery.close();
  }
}
