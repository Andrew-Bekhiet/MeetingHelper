import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

class ColorsList extends StatelessWidget {
  final List<Color>? colors;

  final Color? selectedColor;
  final void Function(Color) onSelect;
  const ColorsList({
    required this.onSelect,
    super.key,
    this.colors,
    this.selectedColor,
  });

  @override
  Widget build(BuildContext context) {
    if (colors == null) {
      return BlockPicker(
        pickerColor: selectedColor ?? Colors.transparent,
        onColorChanged: onSelect,
      );
    } else {
      return BlockPicker(
        pickerColor: selectedColor ?? Colors.transparent,
        onColorChanged: onSelect,
        availableColors: colors!,
      );
    }
  }
}
