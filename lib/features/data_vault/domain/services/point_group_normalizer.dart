/// Normalizes free-text knowledge-point group labels (`Nhom_Cung_Diem`).
abstract final class PointGroupNormalizer {
  static final RegExp _whitespaceRegex = RegExp(r'[\s\u00A0]+');

  /// Returns a trimmed, single-spaced, lowercased key, or `null` if blank.
  static String? normalizeKey(String? raw) {
    final display = normalizeDisplayLabel(raw);
    return display?.toLowerCase();
  }

  /// Returns a trimmed, single-spaced display label preserving casing, or `null`.
  static String? normalizeDisplayLabel(String? raw) {
    if (raw == null) return null;
    final collapsed = raw.replaceAll(_whitespaceRegex, ' ').trim();
    if (collapsed.isEmpty) return null;
    return collapsed;
  }
}

