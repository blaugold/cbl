import 'dart:convert';
import 'dart:io';

import 'package:cbl/src/fleece/fleece.dart';
import 'package:collection/collection.dart';
import 'package:test/test.dart';

import 'fleece_coding.dart';

// === isDirectory Matcher =====================================================

final isDirectory = const _IsDirectory();

class _IsDirectory extends Matcher {
  const _IsDirectory();

  @override
  Description describe(Description description) =>
      description.add('is directory');

  @override
  bool matches(final dynamic item, Map matchState) {
    final String path;
    if (item is FileSystemEntity) {
      path = item.path;
    } else if (item is Uri) {
      path = item.path;
    } else {
      path = item.toString();
    }

    return FileSystemEntity.isDirectorySync(path);
  }
}

// === JSON Matcher ============================================================

/// Returns a [Matcher] wich matches plain Dart objects, JSON strings and
/// Fleece data (in [Slice]s) against [expected], which can be a JSON string or
/// plain Dart objects.
Matcher json(Object? expected) => _JsonMatcher(expected);

class _JsonMatcher extends Matcher {
  static const _actualDecodedKey = 'actualDecoded';

  _JsonMatcher(this.expected);

  final Object? expected;

  late final dynamic _decodedExpected =
      expected is String ? _tryToDecodeJson(expected as String) : expected;

  @override
  Description describe(Description description) {
    return description.add('matches JSON\n${_formatJson(_decodedExpected)}');
  }

  @override
  Description describeMismatch(
    dynamic item,
    Description mismatchDescription,
    Map matchState,
    bool verbose,
  ) {
    if (!matchState.containsKey(_actualDecodedKey)) {
      return mismatchDescription;
    }
    final dynamic actualDecoded = matchState[_actualDecodedKey];
    return mismatchDescription
        .add('was decoded as\n${_formatJson(actualDecoded)}');
  }

  @override
  bool matches(dynamic item, Map matchState) {
    dynamic actual;
    if (item is String) {
      actual = _tryToDecodeJson(item);
      if (item != actual) {
        matchState[_actualDecodedKey] = actual;
      }
    } else if (item is Slice) {
      actual = fleeceDecode(item);
      if (actual == null) return false;
      matchState[_actualDecodedKey] = actual;
    }

    return const DeepCollectionEquality().equals(actual, _decodedExpected);
  }

  String _formatJson(dynamic json) {
    return const JsonEncoder.withIndent('  ').convert(json);
  }

  Object? _tryToDecodeJson(String json) {
    try {
      return jsonDecode(json);
    } catch (e) {
      return json;
    }
  }
}
