/// Utility methods for string casing and text transformations across ADVT APP.
class TextUtils {
  /// Converts input text to Title Case (capitalizes the first character of each word).
  /// Handles spaces, hyphens, and multiple words cleanly.
  /// Example: "mani kumar" -> "Mani Kumar", "software developer" -> "Software Developer".
  static String capitalizeWords(String? text) {
    if (text == null) return '';
    final trimmed = text.trim();
    if (trimmed.isEmpty) return '';

    // Split on whitespace while preserving words
    return trimmed.split(RegExp(r'\s+')).map((word) {
      if (word.isEmpty) return word;

      // If word contains hyphens (e.g. co-founder)
      if (word.contains('-')) {
        return word.split('-').map((sub) => _capitalizeSingle(sub)).join('-');
      }

      // If word contains slashes (e.g. boutique/tailor)
      if (word.contains('/')) {
        return word.split('/').map((sub) => _capitalizeSingle(sub)).join('/');
      }

      return _capitalizeSingle(word);
    }).join(' ');
  }

  static String _capitalizeSingle(String s) {
    if (s.isEmpty) return s;
    if (s.length == 1) return s.toUpperCase();
    return s[0].toUpperCase() + s.substring(1).toLowerCase();
  }
}

extension StringCasingExtension on String {
  /// Returns title-cased representation of this string.
  String toTitleCase() => TextUtils.capitalizeWords(this);
}
