import 'package:fluent_reader_lite/components/cached_image.dart';
import 'package:fluent_reader_lite/models/source.dart';
import 'package:cupertino_ui/cupertino_ui.dart';

class Favicon extends StatelessWidget {
  final RSSSource? source;
  final double size;

  const Favicon(this.source, {this.size = 16, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final _textStyle = TextStyle(
      fontSize: size - 5,
      color: CupertinoColors.systemGrey6,
    );

    Widget fallback(BuildContext context) => Container(
      width: size,
      height: size,
      color: CupertinoColors.systemGrey.resolveFrom(context),
      child: Center(
        child: Text(
          source != null && source!.name.isNotEmpty ? source!.name[0] : "?",
          style: _textStyle,
        ),
      ),
    );

    final iconUrl = source?.iconUrl;
    if (iconUrl == null || iconUrl.isEmpty) return fallback(context);
    return CachedImage(
      imageUrl: iconUrl,
      width: size,
      height: size,
      errorBuilder: fallback,
    );
  }
}
