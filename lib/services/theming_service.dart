import 'package:churchdata_core/churchdata_core.dart';
import 'package:flutter/material.dart';

class MHThemingService extends ThemingService {
  static ThemeData getDefault({
    bool? darkTheme,
    bool? greatFeastThemeOverride,
  }) {
    return ThemingService.getDefault(
      primaryOverride: Colors.amber,
      secondaryOverride: Colors.amberAccent,
      darkTheme: darkTheme,
      greatFeastThemeOverride: greatFeastThemeOverride,
    );
  }

  factory MHThemingService() =>
      MHThemingService.withInitialThemeata(getDefault());

  MHThemingService.withInitialThemeata(super.initialTheme)
      : super.withInitialThemeata();

  @override
  void switchTheme(bool darkTheme) {
    theme = getDefault(darkTheme: darkTheme);
  }
}
