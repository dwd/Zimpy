import 'dart:convert';

const String _websocketRel = 'urn:xmpp:alt-connections:websocket';

Uri? parseHostMetaJson(String payload) {
  final data = jsonDecode(payload);
  if (data is! Map) {
    return null;
  }
  final links = data['links'];
  if (links is! List) {
    return null;
  }
  for (final entry in links) {
    if (entry is! Map) {
      continue;
    }
    final rel = entry['rel']?.toString() ?? '';
    if (rel != _websocketRel) {
      continue;
    }
    final href = entry['href']?.toString();
    final template = entry['template']?.toString();
    final candidate = href ?? template;
    if (candidate == null || candidate.isEmpty) {
      continue;
    }
    return Uri.tryParse(candidate);
  }
  return null;
}

Uri? parseHostMetaXml(String payload) {
  final linkPattern = RegExp(r'<Link\s+[^>]*>', caseSensitive: false);
  final relPattern = RegExp('rel\\s*=\\s*["\\\']([^"\\\']+)["\\\']', caseSensitive: false);
  final hrefPattern = RegExp('href\\s*=\\s*["\\\']([^"\\\']+)["\\\']', caseSensitive: false);
  final templatePattern =
      RegExp('template\\s*=\\s*["\\\']([^"\\\']+)["\\\']', caseSensitive: false);
  for (final match in linkPattern.allMatches(payload)) {
    final tag = match.group(0) ?? '';
    final relMatch = relPattern.firstMatch(tag);
    final rel = relMatch?.group(1) ?? '';
    if (rel != _websocketRel) {
      continue;
    }
    final hrefMatch = hrefPattern.firstMatch(tag);
    final templateMatch = templatePattern.firstMatch(tag);
    final candidate = hrefMatch?.group(1) ?? templateMatch?.group(1);
    if (candidate == null || candidate.isEmpty) {
      continue;
    }
    return Uri.tryParse(candidate);
  }
  return null;
}
