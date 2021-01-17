import 'package:fluent_reader_lite/utils/global.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

class TabletBasePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    var b = Global.currentBrightness(context) == Brightness.light;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: b ? SystemUiOverlayStyle.dark : SystemUiOverlayStyle.light,
      child: Container(
        color: CupertinoColors.systemBackground.resolveFrom(context),
        child: Center(
          child: Image.asset(
            "assets/icons/logo-outline${b?'':'-dark'}.png",
            width: 120, height: 120,
          ),
        ),
      ),
    );
  }
}