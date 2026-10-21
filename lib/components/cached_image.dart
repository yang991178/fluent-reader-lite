import 'package:cached_network_image/cached_network_image.dart';
import 'package:fluent_reader_lite/utils/image.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Disk-cached images with support for SVG favicons and thumbnails.
class CachedImage extends StatefulWidget {
  final String imageUrl;
  final double width;
  final double height;
  final BoxFit fit;
  final WidgetBuilder? placeholderBuilder;
  final WidgetBuilder? errorBuilder;
  final BaseCacheManager? cacheManager;

  const CachedImage({
    super.key,
    required this.imageUrl,
    required this.width,
    required this.height,
    this.fit = BoxFit.contain,
    this.placeholderBuilder,
    this.errorBuilder,
    this.cacheManager,
  });

  @override
  State<CachedImage> createState() => _CachedImageState();
}

class _CachedImageState extends State<CachedImage> {
  Future<String>? _svgData;

  @override
  void initState() {
    super.initState();
    _loadSvg();
  }

  @override
  void didUpdateWidget(CachedImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl ||
        oldWidget.cacheManager != widget.cacheManager) {
      _loadSvg();
    }
  }

  void _loadSvg() {
    // Inspect the path so query strings on favicon URLs do not affect decoding.
    final path = Uri.tryParse(widget.imageUrl)?.path.toLowerCase();
    _svgData = path != null && path.endsWith('.svg') ? _readSvg() : null;
  }

  Future<String> _readSvg() async {
    final cache =
        widget.cacheManager ?? CachedNetworkImageProvider.defaultCacheManager;
    final file = await cache.getSingleFile(
      widget.imageUrl,
      headers: imageRequestHeaders,
    );
    return prepareSvgImage(await file.readAsString());
  }

  Widget _error(BuildContext context) =>
      widget.errorBuilder?.call(context) ?? const SizedBox.shrink();

  @override
  Widget build(BuildContext context) {
    if (_svgData == null) {
      return CachedNetworkImage(
        imageUrl: widget.imageUrl,
        httpHeaders: imageRequestHeaders,
        cacheManager: widget.cacheManager,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        placeholder: widget.placeholderBuilder == null
            ? null
            : (context, _) => widget.placeholderBuilder!(context),
        errorWidget: (context, _, error) => _error(context),
      );
    }

    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: FutureBuilder<String>(
        key: ValueKey(widget.imageUrl),
        future: _svgData,
        builder: (context, snapshot) {
          if (snapshot.hasError) return _error(context);
          if (!snapshot.hasData) {
            return widget.placeholderBuilder?.call(context) ??
                const SizedBox.shrink();
          }
          return SvgPicture.string(
            snapshot.data!,
            width: widget.width,
            height: widget.height,
            fit: widget.fit,
            errorBuilder: (context, error, stackTrace) => _error(context),
          );
        },
      ),
    );
  }
}
