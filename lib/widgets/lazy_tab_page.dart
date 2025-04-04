import 'package:flutter/material.dart';

class LazyTabPage extends StatelessWidget {
  const LazyTabPage({
    required this.builder,
    required this.index,
    this.tabController,
    this.placeholder,
    super.key,
  });

  final TabController? tabController;
  final Widget Function(BuildContext) builder;
  final int index;
  final Widget? placeholder;

  @override
  Widget build(BuildContext context) {
    final tabController =
        this.tabController ?? DefaultTabController.of(context);

    return AnimatedBuilder(
      animation: tabController,
      builder: (context, _) => tabController.index == index ||
              tabController.animation?.value.ceil() == index ||
              tabController.animation?.value.floor() == index
          ? builder(context)
          : placeholder ?? const Center(child: CircularProgressIndicator()),
    );
  }
}
