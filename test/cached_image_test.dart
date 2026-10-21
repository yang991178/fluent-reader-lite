import 'dart:convert';
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:fluent_reader_lite/components/cached_image.dart';
import 'package:fluent_reader_lite/components/favicon.dart';
import 'package:fluent_reader_lite/models/source.dart';
import 'package:fluent_reader_lite/utils/image.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

const _svg =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 16 16">'
    '<path fill="#ff0000" d="M0 0h16v16H0z"/></svg>';
const _png =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJ'
    'AAAADUlEQVR4nGP4z8DwHwAFAAH/iZk9HQAAAABJRU5ErkJggg==';

class _ImageCache extends Fake implements BaseCacheManager {
  final fs = MemoryFileSystem();
  final Map<String, File> files = {};
  final List<Map<String, String>?> requests = [];

  void add(String url, List<int> bytes) {
    files[url] = fs.file('/image-${files.length}')..writeAsBytesSync(bytes);
  }

  @override
  Future<File> getSingleFile(
    String url, {
    String? key,
    Map<String, String>? headers,
  }) async {
    requests.add(headers);
    if (!files.containsKey(url)) {
      throw HttpExceptionWithStatus(403, 'Forbidden', uri: Uri.parse(url));
    }
    return files[url]!;
  }

  @override
  Stream<FileResponse> getFileStream(
    String url, {
    String? key,
    Map<String, String>? headers,
    bool withProgress = false,
  }) async* {
    final file = await getSingleFile(url, headers: headers);
    yield FileInfo(file, FileSource.Cache, DateTime(2100), url);
  }
}

void main() {
  late _ImageCache cache;

  setUp(() {
    cache = _ImageCache();
    CachedNetworkImageProvider.defaultCacheManager = cache;
  });

  tearDown(() {
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
  });

  testWidgets('Raster images use browser headers and decode cached bytes', (
    tester,
  ) async {
    const url = 'https://img.chuapp.com/favicon.ico?_15';
    cache.add(url, base64Decode(_png));
    await tester.pumpWidget(
      const CupertinoApp(
        home: CachedImage(imageUrl: url, width: 16, height: 16),
      ),
    );
    await tester.runAsync(() async {
      await precacheImage(
        CachedNetworkImageProvider(url, headers: imageRequestHeaders),
        tester.element(find.byType(CachedImage)),
      );
    });
    await tester.pumpAndSettle();

    expect(cache.requests.single, imageRequestHeaders);
    expect(cache.requests.single!['User-Agent'], startsWith('Mozilla/5.0'));
    final image = tester.widget<RawImage>(find.byType(RawImage));
    expect(image.image, isNotNull);
    expect(tester.takeException(), isNull);
  });

  for (final wrapped in [false, true]) {
    testWidgets('SVG favicons render cached vector data (wrapped: $wrapped)', (
      tester,
    ) async {
      const url = 'https://kotaku.com/favicon.svg?_15';
      cache.add(
        url,
        utf8.encode(
          wrapped
              ? '<svg xmlns="http://www.w3.org/2000/svg" width="96" height="96">'
                    '$_svg</svg>'
              : _svg,
        ),
      );
      final source = RSSSource('1', 'https://kotaku.com', 'Kotaku')
        ..iconUrl = url;
      final boundaryKey = GlobalKey();
      await tester.pumpWidget(
        CupertinoApp(
          home: Center(
            child: RepaintBoundary(key: boundaryKey, child: Favicon(source)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(cache.requests.single, imageRequestHeaders);
      expect(find.byType(SvgPicture), findsOneWidget);
      expect(find.byType(CachedNetworkImage), findsNothing);
      final boundary =
          boundaryKey.currentContext!.findRenderObject()
              as RenderRepaintBoundary;
      final image = await tester.runAsync(() => boundary.toImage());
      final pixels = await tester.runAsync(
        () => image!.toByteData(format: ui.ImageByteFormat.rawRgba),
      );
      // A rendered red pixel proves decoding and painting completed.
      expect(pixels!.buffer.asUint8List().sublist(0, 4), [255, 0, 0, 255]);
      image!.dispose();
      expect(tester.takeException(), isNull);

      await tester.pump();
      expect(cache.requests, hasLength(1));
    });
  }

  testWidgets('Changing an SVG URL replaces the displayed image', (
    tester,
  ) async {
    cache.add('https://example.com/one.svg', utf8.encode(_svg));
    cache.add(
      'https://example.com/two.svg',
      utf8.encode(_svg.replaceFirst('#ff0000', '#00ff00')),
    );
    Widget image(String url) =>
        CupertinoApp(home: CachedImage(imageUrl: url, width: 16, height: 16));
    await tester.pumpWidget(image('https://example.com/one.svg'));
    await tester.pumpAndSettle();
    final first = tester
        .widget<SvgPicture>(find.byType(SvgPicture))
        .bytesLoader;
    await tester.pumpWidget(image('https://example.com/two.svg'));
    await tester.pumpAndSettle();
    final second = tester
        .widget<SvgPicture>(find.byType(SvgPicture))
        .bytesLoader;
    expect(second, isNot(first));
    expect(cache.requests, hasLength(2));
    expect(tester.takeException(), isNull);
  });

  for (final suffix in ['ico', 'svg', 'invalid.svg']) {
    testWidgets('Failed $suffix favicons show source initials', (tester) async {
      final url = 'https://example.com/favicon.$suffix';
      if (suffix == 'invalid.svg') cache.add(url, utf8.encode('invalid SVG'));
      final source = RSSSource('1', 'https://example.com', 'Example')
        ..iconUrl = url;
      await tester.pumpWidget(CupertinoApp(home: Favicon(source)));
      await tester.pumpAndSettle();

      expect(find.text('E'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
