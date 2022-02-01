import 'package:churchdata_core/churchdata_core.dart';
import 'package:flutter/material.dart';

class MHThemeNotifier extends ThemeNotifier {
  static ThemeData getDefault({
    bool? darkTheme,
    bool? greatFeastThemeOverride,
  }) {
    return ThemeNotifier.getDefault(
      primaryOverride: Colors.amber,
      secondaryOverride: Colors.amberAccent,
      darkTheme: darkTheme,
      greatFeastThemeOverride: greatFeastThemeOverride,
    );
  }

  factory MHThemeNotifier() =>
      MHThemeNotifier.withInitialThemeata(getDefault());

  MHThemeNotifier.withInitialThemeata(ThemeData initialTheme)
      : super.withInitialThemeata(initialTheme);

  @override
  void switchTheme(bool darkTheme) {
    theme = getDefault(darkTheme: darkTheme);
  }
}
