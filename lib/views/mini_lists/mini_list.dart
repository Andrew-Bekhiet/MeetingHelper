import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:meetinghelper/utils/globals.dart';

class MiniList extends StatefulWidget {
  final CollectionReference? parent;
  final String? pageTitle;
  final String? itemSubtitle;
  final void Function()? onAdd;
  const MiniList(
      {Key? key, this.parent, this.pageTitle, this.itemSubtitle, this.onAdd})
      : super(key: key);

  @override
  State<MiniList> createState() => _MiniListState();
}

class _MiniListState extends State<MiniList> {
  List<QueryDocumentSnapshot>? _documentsData;
  bool _showSearch = false;
  FocusNode searchFocus = FocusNode();

  String _filter = '';

  String _oldFilter = '';
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: widget.parent!.orderBy('Name').snapshots(),
      builder: (context, stream) {
        if (stream.hasError) return Center(child: ErrorWidget(stream.error!));
        if (!stream.hasData)
          return const Center(child: CircularProgressIndicator());
        if (_documentsData == null ||
            _documentsData!.length != stream.data!.docs.length)
          _documentsData = stream.data!.docs;
        return StatefulBuilder(
          builder: (context, setState) => Scaffold(
            appBar: AppBar(
              actions: <Widget>[
                if (!_showSearch)
                  IconButton(
                      icon: const Icon(Icons.search),
                      onPressed: () => setState(() {
                            searchFocus.requestFocus();
                            _showSearch = true;
                          })),
                IconButton(
                  icon: const Icon(Icons.notifications),
                  tooltip: 'الإشعارات',
                  onPressed: () {
                    navigator.currentState!.pushNamed('Notifications');
                  },
                ),
              ],
              title: _showSearch
                  ? TextField(
                      focusNode: searchFocus,
                      decoration: InputDecoration(
                          suffixIcon: IconButton(
                            icon: Icon(Icons.close,
                                color: Theme.of(context)
                                    .primaryTextTheme
                                    .headline6!
                                    .color),
                            onPressed: () => setState(
                              () {
                                _filter = '';
                                _showSearch = false;
                              },
                            ),
                          ),
                          hintText: 'بحث ...'),
                      onChanged: (t) => setState(() => _filter = t),
                    )
                  : Text(widget.pageTitle!),
            ),
            body: Builder(
              builder: (context) {
                if (_filter.isNotEmpty) {
                  if (_oldFilter.length < _filter.length &&
                      _filter.startsWith(_oldFilter)) {
                    _documentsData = _documentsData!
                        .where((d) => (d.data()['Name'] as String)
                            .toLowerCase()
                            .replaceAll(
                                RegExp(
                                  r'[أإآ]',
                                ),
                                'ا')
                            .replaceAll(
                                RegExp(
                                  r'[ى]',
                                ),
                                'ي')
                            .contains(_filter))
                        .toList();
                  } else {
                    _documentsData = stream.data!.docs
                        .where((d) => (d.data()['Name'] as String)
                            .toLowerCase()
                            .replaceAll(
                                RegExp(
                                  r'[أإآ]',
                                ),
                                'ا')
                            .replaceAll(
                                RegExp(
                                  r'[ى]',
                                ),
                                'ي')
                            .contains(_filter))
                        .toList();
                  }
                } else {
                  _documentsData = stream.data!.docs;
                }
                _oldFilter = _filter;
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  addAutomaticKeepAlives: (_documentsData?.length ?? 0) < 300,
                  cacheExtent: 200,
                  itemCount: _documentsData?.length ?? 0,
                  itemBuilder: (context, i) {
                    return Card(
                      child: ListTile(
                        title: Text(_documentsData![i].data()['Name']),
                        subtitle: widget.itemSubtitle != null
                            ? Text(
                                _documentsData![i].data()[widget.itemSubtitle!])
                            : null,
                        onLongPress: () async {
                          //TODO: implement deletion
                        },
                      ),
                    );
                  },
                );
              },
            ),
            floatingActionButtonLocation:
                FloatingActionButtonLocation.endDocked,
            floatingActionButton: FloatingActionButton(
              tooltip: 'اضافة',
              onPressed: widget.onAdd ??
                  () async {
                    TextEditingController name =
                        TextEditingController(text: '');
                    if (await showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            actions: [
                              TextButton.icon(
                                  icon: const Icon(Icons.save),
                                  label: const Text('حفظ'),
                                  onPressed: () =>
                                      navigator.currentState!.pop(name.text)),
                            ],
                            title: TextField(
                              controller: name,
                            ),
                          ),
                        ) !=
                        null)
                      await widget.parent!.doc().set({'Name': name.text});
                  },
              child: const Icon(Icons.add),
            ),
          ),
        );
      },
    );
  }
}
