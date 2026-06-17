import '../domain/policy_document.dart';

class PolicyDocumentParser {
  const PolicyDocumentParser._();

  static PolicyDocument parse(String source) {
    if (source.trim().isEmpty) {
      return const PolicyDocument(policies: []);
    }

    final normalized = source.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final lines = normalized.split('\n');
    final header = <String>[];
    final sections = <List<String>>[];
    List<String>? current;

    for (final line in lines) {
      final trimmed = line.trim();
      if (_isPolicyHeader(trimmed)) {
        current = [line];
        sections.add(current);
      } else if (current == null) {
        header.add(line);
      } else {
        current.add(line);
      }
    }

    final meta = _parseHeaderMeta(header);
    final policies = <PolicyItem>[];
    for (final section in sections) {
      final policy = _parsePolicy(section);
      if (policy != null) policies.add(policy);
    }

    return PolicyDocument(
      version: meta.version,
      updatedAt: meta.updatedAt,
      policies: policies,
    );
  }

  static bool _isPolicyHeader(String line) {
    return RegExp(r'^CHÍNH SÁCH\s+\d{2}:', caseSensitive: false).hasMatch(line);
  }

  static _DocumentMeta _parseHeaderMeta(List<String> lines) {
    String? version;
    String? updatedAt;
    for (final raw in lines) {
      final line = raw.trim();
      if (line.startsWith('Phiên bản')) {
        final parts = line.split('|');
        version = parts.first.trim();
        if (parts.length > 1) {
          updatedAt = parts.sublist(1).join('|').trim();
        }
      }
    }
    return _DocumentMeta(version: version, updatedAt: updatedAt);
  }

  static PolicyItem? _parsePolicy(List<String> section) {
    final header = section.first.trim();
    final idMatch = RegExp(
      r'CHÍNH SÁCH\s+(\d+)',
      caseSensitive: false,
    ).firstMatch(header);
    final id = idMatch?.group(1) ?? '';
    final title = _firstNonEmptyAfterHeader(section);
    if (title == null) return null;

    final content = section.join('\n').trim();
    if (content.isEmpty) return null;

    return PolicyItem(
      id: id,
      slug: _slugify(title),
      title: title,
      content: content,
      appliesTo: _fieldValue(section, 'Áp dụng cho:'),
      effectiveDate: _fieldValue(section, 'Hiệu lực:'),
    );
  }

  static String? _firstNonEmptyAfterHeader(List<String> section) {
    for (var i = 1; i < section.length; i++) {
      final value = section[i].trim();
      if (value.isNotEmpty) return value;
    }
    return null;
  }

  static String? _fieldValue(List<String> section, String prefix) {
    for (final raw in section) {
      final line = raw.trim();
      if (line.startsWith(prefix)) {
        return line.substring(prefix.length).trim();
      }
    }
    return null;
  }

  static String _slugify(String value) {
    final normalized = _stripVietnamese(value).toLowerCase();
    return normalized
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
  }

  static String _stripVietnamese(String value) {
    const replacements = {
      'à': 'a',
      'á': 'a',
      'ạ': 'a',
      'ả': 'a',
      'ã': 'a',
      'â': 'a',
      'ầ': 'a',
      'ấ': 'a',
      'ậ': 'a',
      'ẩ': 'a',
      'ẫ': 'a',
      'ă': 'a',
      'ằ': 'a',
      'ắ': 'a',
      'ặ': 'a',
      'ẳ': 'a',
      'ẵ': 'a',
      'è': 'e',
      'é': 'e',
      'ẹ': 'e',
      'ẻ': 'e',
      'ẽ': 'e',
      'ê': 'e',
      'ề': 'e',
      'ế': 'e',
      'ệ': 'e',
      'ể': 'e',
      'ễ': 'e',
      'ì': 'i',
      'í': 'i',
      'ị': 'i',
      'ỉ': 'i',
      'ĩ': 'i',
      'ò': 'o',
      'ó': 'o',
      'ọ': 'o',
      'ỏ': 'o',
      'õ': 'o',
      'ô': 'o',
      'ồ': 'o',
      'ố': 'o',
      'ộ': 'o',
      'ổ': 'o',
      'ỗ': 'o',
      'ơ': 'o',
      'ờ': 'o',
      'ớ': 'o',
      'ợ': 'o',
      'ở': 'o',
      'ỡ': 'o',
      'ù': 'u',
      'ú': 'u',
      'ụ': 'u',
      'ủ': 'u',
      'ũ': 'u',
      'ư': 'u',
      'ừ': 'u',
      'ứ': 'u',
      'ự': 'u',
      'ử': 'u',
      'ữ': 'u',
      'ỳ': 'y',
      'ý': 'y',
      'ỵ': 'y',
      'ỷ': 'y',
      'ỹ': 'y',
      'đ': 'd',
    };
    final buffer = StringBuffer();
    for (final rune in value.runes) {
      final char = String.fromCharCode(rune);
      final lower = char.toLowerCase();
      buffer.write(replacements[lower] ?? lower);
    }
    return buffer.toString();
  }
}

class _DocumentMeta {
  const _DocumentMeta({this.version, this.updatedAt});

  final String? version;
  final String? updatedAt;
}
