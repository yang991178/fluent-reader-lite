import 'package:xml/xml.dart';

// Some image hosts reject Dart's default user agent
const imageRequestHeaders = {
  'User-Agent':
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) '
      'AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Safari/605.1.15',
};

String prepareSvgImage(String svg) {
  final document = XmlDocument.parse(svg);
  final root = document.rootElement;
  if (root.name.local != 'svg' || root.getAttribute('viewBox') != null) {
    return svg;
  }

  // Attempt to transform nested SVGs to a supported format
  final drawings = root.childElements
      .where(
        (element) => !const {
          'defs',
          'style',
          'title',
          'desc',
          'metadata',
        }.contains(element.name.local),
      )
      .toList();
  if (drawings.length != 1 || drawings.single.name.local != 'svg') return svg;
  final nested = drawings.single;
  final viewBox = nested.getAttribute('viewBox');
  if (viewBox == null ||
      ![null, '0'].contains(nested.getAttribute('x')) ||
      ![null, '0'].contains(nested.getAttribute('y')) ||
      ![null, '100%'].contains(nested.getAttribute('width')) ||
      ![null, '100%'].contains(nested.getAttribute('height'))) {
    return svg;
  }

  root.setAttribute('viewBox', viewBox);
  root.setAttribute(
    'preserveAspectRatio',
    nested.getAttribute('preserveAspectRatio') ?? 'xMidYMid meet',
  );
  nested.replace(
    XmlElement(
      XmlName.parts('g'),
      nested.attributes
          .where(
            (attribute) => !const {
              'viewBox',
              'preserveAspectRatio',
              'x',
              'y',
              'width',
              'height',
            }.contains(attribute.name.local),
          )
          .map((attribute) => attribute.copy()),
      nested.children.map((child) => child.copy()),
    ),
  );
  return document.toXmlString();
}
