import 'package:churchdata_core/churchdata_core.dart';
import 'package:flutter/material.dart';
import 'package:meetinghelper/utils/globals.dart';
import 'package:meetinghelper/utils/helpers.dart';
import 'package:rxdart/rxdart.dart';

class FilterButton extends StatelessWidget {
  final Type type;
  final ListController? controller;
  final BehaviorSubject<OrderOptions>? orderOptions;
  final bool disableOrdering;
  const FilterButton(
    this.type,
    this.controller,
    this.orderOptions, {
    super.key,
    this.disableOrdering = false,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.filter_list),
      onPressed: () {
        showDialog(
          context: context,
          builder: (context) => SimpleDialog(
            children: [
              TextButton.icon(
                icon: const Icon(Icons.select_all),
                label: const Text('تحديد الكل'),
                onPressed: () {
                  controller!.selectAll();
                  navigator.currentState!.pop();
                },
              ),
              TextButton.icon(
                icon: const Icon(Icons.select_all),
                label: const Text('تحديد لا شئ'),
                onPressed: () {
                  controller!.deselectAll();
                  navigator.currentState!.pop();
                },
              ),
              if (!disableOrdering)
                const Text(
                  'ترتيب حسب:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              if (!disableOrdering) ...getOrderingOptions(orderOptions!, type),
            ],
          ),
        );
      },
    );
  }
}

class SearchField extends StatelessWidget {
  SearchField({
    required this.textStyle,
    required this.searchStream,
    super.key,
    this.showSuffix = true,
  });
  final TextStyle? textStyle;
  final TextEditingController _textController = TextEditingController();
  final BehaviorSubject<String> searchStream;
  final bool showSuffix;

  @override
  Widget build(BuildContext context) {
    return TextField(
      style: textStyle,
      controller: _textController,
      decoration: InputDecoration(
        suffixIcon: showSuffix
            ? IconButton(
                icon: Icon(Icons.close, color: textStyle!.color),
                onPressed: () {
                  _textController.text = '';
                  searchStream.add('');
                },
              )
            : null,
        hintStyle: textStyle,
        icon: Icon(Icons.search, color: textStyle!.color),
        hintText: 'بحث ...',
      ),
      onChanged: searchStream.add,
    );
  }
}

class SearchFilters extends StatelessWidget {
  final Type type;
  final TextStyle? textStyle;
  final ListController options;
  final BehaviorSubject<OrderOptions>? orderOptions;
  final bool disableOrdering;
  const SearchFilters(
    this.type, {
    required this.textStyle,
    required this.options,
    super.key,
    this.disableOrdering = false,
    this.orderOptions,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: SearchField(
            searchStream: options.searchSubject,
            textStyle: textStyle ??
                Theme.of(context).textTheme.titleLarge!.copyWith(
                      color:
                          Theme.of(context).primaryTextTheme.titleLarge!.color,
                    ),
          ),
        ),
        FilterButton(
          type,
          options,
          orderOptions,
          disableOrdering: disableOrdering,
        ),
      ],
    );
  }
}
