/// Result of parsing a single `.env` file.
class DotenvParseResult {
  /// Creates a [DotenvParseResult].
  const DotenvParseResult({required this.values, required this.warnings});

  /// Parsed key-value pairs, in declaration order.
  final Map<String, String> values;

  /// Non-fatal issues found during parsing (e.g. duplicate keys).
  final List<String> warnings;
}

/// Parses `.env` file content into a `Map<String, String>`.
///
/// Follows the de-facto dotenv spec:
/// - Blank lines and `#`-prefixed comment lines are skipped.
/// - `export KEY=VALUE` prefix is stripped.
/// - Values may be unquoted, double-quoted, or single-quoted.
/// - Double-quoted values process `\"` and `\\` escape sequences.
/// - Unquoted values have trailing inline ` # comment` stripped.
/// - `KEY=` (empty value) is valid.
/// - The first `=` delimits key from value; `KEY=a=b` is valid.
/// - Duplicate keys emit a warning; the last value wins.
class DotenvParser {
  /// Parses [content] (the full text of a `.env` file).
  DotenvParseResult parse(String content) {
    final values = <String, String>{};
    final warnings = <String>[];
    final lines = content.split(RegExp(r'\r\n|\r|\n'));

    for (final rawLine in lines) {
      final line = rawLine.trim();

      // Skip blank lines and comment lines.
      if (line.isEmpty || line.startsWith('#')) continue;

      // Strip optional `export ` prefix.
      final stripped = line.startsWith('export ')
          ? line.substring(7).trimLeft()
          : line;

      // Must contain `=`.
      final eqIndex = stripped.indexOf('=');
      if (eqIndex < 1) continue;

      final key = stripped.substring(0, eqIndex).trim();
      if (key.isEmpty) continue;

      final rawValue = stripped.substring(eqIndex + 1);
      final value = _parseValue(rawValue);

      if (values.containsKey(key)) {
        warnings.add("Duplicate key '$key' — using last value.");
      }
      values[key] = value;
    }

    return DotenvParseResult(values: values, warnings: warnings);
  }

  String _parseValue(String raw) {
    final trimmed = raw.trim();

    // Double-quoted: process escape sequences in a single pass, strip quotes.
    if (trimmed.startsWith('"') && trimmed.length >= 2) {
      final inner = _findClosingQuote(trimmed, '"');
      if (inner != null) return _processEscapes(inner);
    }

    // Single-quoted: literal content, no escape processing.
    if (trimmed.startsWith("'") && trimmed.length >= 2) {
      final inner = _findClosingQuote(trimmed, "'");
      if (inner != null) return inner;
    }

    // Unquoted: strip trailing inline comment (` #` or ` # text`).
    final commentMatch = RegExp(r'\s+#').firstMatch(trimmed);
    if (commentMatch != null) {
      return trimmed.substring(0, commentMatch.start).trim();
    }

    return trimmed;
  }

  /// Processes escape sequences in a double-quoted value in a single pass.
  ///
  /// Supported: `\"` → `"`, `\\` → `\`, `\n` → newline, `\t` → tab.
  /// Unknown escape sequences are left as-is.
  String _processEscapes(String inner) {
    final sb = StringBuffer();
    var i = 0;
    while (i < inner.length) {
      if (inner[i] == r'\' && i + 1 < inner.length) {
        switch (inner[i + 1]) {
          case '"':
            sb.write('"');
          case r'\':
            sb.write(r'\');
          case 'n':
            sb.write('\n');
          case 't':
            sb.write('\t');
          default:
            sb.write(inner[i]);
            i++;
            continue;
        }
        i += 2;
      } else {
        sb.write(inner[i]);
        i++;
      }
    }
    return sb.toString();
  }

  /// Returns the content between the outer quotes, or `null` if the closing
  /// quote is missing.
  String? _findClosingQuote(String s, String quote) {
    // s starts with [quote]; find matching closing quote (not escaped).
    var i = 1;
    while (i < s.length) {
      if (s[i] == r'\' && quote == '"') {
        i += 2; // skip escaped character
        continue;
      }
      if (s[i] == quote) {
        return s.substring(1, i);
      }
      i++;
    }
    return null; // unterminated — fall through to unquoted handling
  }
}
