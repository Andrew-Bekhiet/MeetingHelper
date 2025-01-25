import 'package:churchdata_core/churchdata_core.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:meetinghelper/models.dart';
import 'package:meetinghelper/repositories.dart';

class BirthdaysBanner extends StatefulWidget {
  const BirthdaysBanner({super.key});

  @override
  State<BirthdaysBanner> createState() => _BirthdaysBannerState();
}

class _BirthdaysBannerState extends State<BirthdaysBanner>
    with SingleTickerProviderStateMixin {
  DateTime get today => DateTime.now().truncateToDay();

  bool get hideForToday => Hive.box('BirthdaysShownDates')
      .get(today.toIso8601String(), defaultValue: false);

  late final AnimationController _animationController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500),
    value: 0,
  );

  late final _fadeAnimation = _animationController.view;
  late final _sizeAnimation =
      _animationController.view.drive(CurveTween(curve: Curves.easeInOutCubic));

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SizeTransition(
        axisAlignment: -1,
        sizeFactor: _sizeAnimation,
        child: FutureBuilder<List<Person>>(
          future: hideForToday
              ? null
              : MHDatabaseRepo.instance.persons.todaysBirthdays(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              _ensureExpanded();

              return ErrorWidget.builder(
                FlutterErrorDetails(exception: snapshot.error!),
              );
            }

            if (!snapshot.hasData) {
              _ensureCollapsed();

              return const SizedBox();
            }

            final persons = snapshot.data!;

            if (persons.isEmpty) {
              _ensureCollapsed();

              return const SizedBox();
            }

            _ensureExpanded();

            return MaterialBanner(
              content: ListTile(
                title: Text(
                  'أعياد ميلاد اليوم',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                subtitle: Text(persons.map((p) => p.name).join('، ')),
              ),
              leading: const Icon(Icons.cake),
              actions: [
                FilledButton.icon(
                  onPressed: () {
                    GetIt.I<MHViewableObjectService>().onTap(
                      QueryInfo(
                        collection: MHDatabaseRepo.I.collection('Persons'),
                        fieldPath: 'BirthDateMonthDay',
                        operator: '=',
                        queryValue: '${today.month}-${today.day}',
                        order: true,
                        orderBy: 'BirthDateMonthDay',
                        descending: false,
                      ),
                    );
                  },
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('فتح'),
                ),
                TextButton(
                  onPressed: () {
                    Hive.box('BirthdaysShownDates')
                        .put(today.toIso8601String(), true);

                    _ensureCollapsed();
                  },
                  child: const Text('إخفاء'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _ensureExpanded() {
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _animationController.forward());
  }

  void _ensureCollapsed() {
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _animationController.reverse());
  }
}
