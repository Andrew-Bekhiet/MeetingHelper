import 'package:async/async.dart';
import 'package:flutter/material.dart';
import 'package:meetinghelper/utils/helpers.dart';
import 'package:meetinghelper/models/models.dart';
import 'package:meetinghelper/models/super_classes.dart';
import 'package:tinycolor/tinycolor.dart';

class DataObjectWidget<T extends DataObject> extends StatelessWidget {
  final T current;

  final void Function()? onLongPress;
  final void Function()? onTap;
  final Widget? trailing;
  final Widget? photo;
  final Widget? subtitle;
  final Widget? title;
  final bool wrapInCard;
  final bool isDense;
  final bool showSubTitle;

  final _memoizer = AsyncMemoizer<String?>();

  DataObjectWidget(this.current,
      {Key? key,
      this.isDense = false,
      this.onLongPress,
      this.onTap,
      this.trailing,
      this.subtitle,
      this.title,
      this.wrapInCard = true,
      this.photo,
      this.showSubTitle = true})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    final Widget tile = ListTile(
      tileColor: wrapInCard ? null : _getColor(context),
      dense: isDense,
      onLongPress: onLongPress,
      onTap: onTap ?? () => dataObjectTap(current),
      trailing: trailing,
      title: title ?? Text(current.name),
      subtitle: showSubTitle
          ? subtitle ??
              FutureBuilder<String?>(
                future: _memoizer.runOnce(current.getSecondLine),
                builder: (cont, subT) {
                  if (subT.hasData) {
                    return Text(subT.data ?? '',
                        maxLines: 1, overflow: TextOverflow.ellipsis);
                  } else {
                    return LinearProgressIndicator(
                      backgroundColor: current.color,
                      valueColor: AlwaysStoppedAnimation(current.color),
                    );
                  }
                },
              )
          : null,
      leading: photo ??
          (current is PhotoObject
              ? (current as PhotoObject).photo(cropToCircle: current is Person)
              : null),
    );
    return wrapInCard
        ? Card(
            color: _getColor(context),
            child: tile,
          )
        : tile;
  }

  Color? _getColor(BuildContext context) {
    if (current.color == Colors.transparent) return null;
    if (current.color.brightness > 170 &&
        Theme.of(context).brightness == Brightness.dark) {
      //refers to the contrasted text theme color
      return current.color
          .darken(((265 - current.color.brightness) / 255 * 100).toInt());
    } else if (current.color.brightness < 85 &&
        Theme.of(context).brightness == Brightness.light) {
      return current.color
          .lighten(((265 - current.color.brightness) / 255 * 100).toInt());
    }
    return current.color;
  }
}
