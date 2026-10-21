import 'dart:convert';
import 'dart:io';

import 'package:fluent_reader_lite/utils/article.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html;
import 'package:http/http.dart' as http;

void main() {
  group('Article response decoding', () {
    const content = '<p>One\u00a0space — café 中文 Â</p>';

    for (final contentType in [null, 'text/html', 'text/html; charset=UTF-8']) {
      test('Preserves UTF-8 with Content-Type $contentType', () {
        final response = http.Response.bytes(
          utf8.encode(content),
          200,
          headers: {if (contentType != null) 'content-type': contentType},
        );
        expect(decodeArticleResponse(response), content);
      });
    }

    test('Honors a declared Latin-1 charset', () {
      final response = http.Response.bytes(
        latin1.encode('<p>café\u00a0Â</p>'),
        200,
        headers: {'content-type': 'text/html; charset=iso-8859-1'},
      );
      expect(decodeArticleResponse(response), '<p>café\u00a0Â</p>');
    });

    test('Retains legacy Latin-1 pages without a charset', () {
      final response = http.Response.bytes(
        latin1.encode('<p>café</p>'),
        200,
        headers: {'content-type': 'text/html'},
      );
      expect(decodeArticleResponse(response), '<p>café</p>');
    });

    test('Strips a UTF-8 byte order mark', () {
      final response = http.Response.bytes([
        0xef,
        0xbb,
        0xbf,
        ...utf8.encode(content),
      ], 200);
      expect(decodeArticleResponse(response), content);
    });
  });

  test(
    'Article data survives large pages, URL punctuation and script tags',
    () {
      final template = File('assets/article/article.html').readAsStringSync();
      final article = <String, Object?>{
        'content':
            '<p>${'A\u00a0space — 中文 ' * 60000}</p>'
            '<script>ignored()</script><script>alsoIgnored()</script>',
        'url': 'https://www.theverge.com/article?a=1&b=2#section',
        'header': '<p id="title">An article</p><article></article>',
        'fontSize': 16,
        'theme': null,
        'fullContent': true,
      };
      final document = html.parse(buildArticleDocument(template, article));
      final data = document.querySelector('#article-data')!;
      expect(jsonDecode(data.text), article);
      // Publisher scripts remain data, rather than escaping into the reader.
      expect(document.querySelectorAll('script').length, 3);
      expect(document.querySelector('#main')!.innerHtml, isEmpty);
    },
  );
}
