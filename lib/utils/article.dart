import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

String decodeArticleResponse(http.Response response) {
  final contentType = response.headers['content-type'];
  final charset = contentType == null
      ? null
      : ContentType.parse(contentType).parameters['charset'];
  final encoding = Encoding.getByName(charset);
  if (encoding != null) return encoding.decode(response.bodyBytes);

  // Response.body defaults HTML without a charset to Latin-1. Most pages use
  // UTF-8, where decoding a non-breaking space as Latin-1 introduces an extra Â.
  try {
    return utf8.decode(response.bodyBytes);
  } on FormatException {
    return latin1.decode(response.bodyBytes);
  }
}

String buildArticleDocument(String template, Map<String, Object?> article) {
  final theme = article['theme'];
  if (theme != null) {
    final scheme = theme == 1 ? 'light' : 'dark';
    final background = theme == 1 ? '#fff' : '#000';
    // Set the first paint before loading the stylesheet or parser scripts.
    template = template.replaceFirst(
      '<html>',
      '<html class="$scheme" style="color-scheme: $scheme; '
          'background-color: $background">',
    );
  }
  // Keep HTML (including </script>) inside the non-executable JSON data block.
  final data = jsonEncode(article).replaceAll('<', r'\u003c');
  return template.replaceFirst('<!-- ARTICLE_DATA -->', data);
}
