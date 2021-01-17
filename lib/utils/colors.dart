import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class MyColors {
  static const background = CupertinoDynamicColor.withBrightness(
    color: CupertinoColors.extraLightBackgroundGray,
    darkColor: CupertinoColors.black,
  );

  static const tileBackground = CupertinoDynamicColor.withBrightness(
    color: CupertinoColors.white,
    darkColor: CupertinoColors.darkBackgroundGray,
  );

  static const barDivider = CupertinoDynamicColor.withBrightness(
    color: CupertinoColors.systemGrey2,
    darkColor: CupertinoColors.black,
  );

  static const dynamicBlack = CupertinoDynamicColor.withBrightness(
    color: CupertinoColors.black,
    darkColor: CupertinoColors.white,
  );

  static const dynamicDarkGrey = CupertinoDynamicColor.withBrightness(
    color: Colors.black87,
    darkColor: Colors.white70,
  );

  static const indicatorOrange = Color.fromRGBO(255, 170, 68, 1);
}