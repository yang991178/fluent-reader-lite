import 'package:cached_network_image/cached_network_image.dart';
import 'package:fluent_reader_lite/models/source.dart';
import 'package:flutter/cupertino.dart';

class Favicon extends StatelessWidget {
  final RSSSource source;
  final double size;

  const Favicon(this.source, {this.size: 16, Key key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final _textStyle = TextStyle(
      fontSize: size - 5,
      color: CupertinoColors.systemGrey6,
    );
    
    if (source.iconUrl != null && source.iconUrl.length > 0) {
      return CachedNetworkImage(
        imageUrl: source.iconUrl,
        width: size,
        height: size,
      );
    } else {
      return Container(
        width: size,
        height: size,
        color: CupertinoColors.systemGrey.resolveFrom(context),
        child: Center(child: Text(
          source.name.length > 0 ? source.name[0] : "?",
          style: _textStyle,
        )),
      );
    }
  }
}