import 'package:flutter/cupertino.dart';

class Badge extends StatelessWidget {
  Badge(int count, {this.color : CupertinoColors.systemRed, Key key}) :
    label = count >= 1000 ? "999+" : count.toString(),
    super(key: key);

  final String label;
  final CupertinoDynamicColor color;
  final labelStyle = TextStyle(
    color: CupertinoColors.white,
    fontSize: 12
  );

  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.all(3),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 16,
        color: color.resolveFrom(context),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          child: Text(label, style: labelStyle,),
        ),
      ),
    )
  );
}