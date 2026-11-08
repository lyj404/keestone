import 'package:kpasslib/kpasslib.dart';

/// Fuzzy matching utility with match position tracking.
class FuzzyMatchResult {
  final double score;
  final List<int> positions;
  const FuzzyMatchResult(this.score, this.positions);
  bool get isMatch => score > 0;
}

/// Matches [query] against [text] using fuzzy logic.
/// Returns a [FuzzyMatchResult] with score and matched character positions.
/// Positions always refer to the *original* [text], even when case-folding
/// changes its length (e.g. 'İ' expands to two UTF-16 units), by tracking
/// matches on runes that round-trip case folding unchanged.
/// Supports:
///   - Exact substring match (highest priority)
///   - Prefix match
///   - Word-boundary match
///   - Fuzzy character-by-character match
FuzzyMatchResult? fuzzyMatch(String text, String query) {
  if (query.isEmpty) return FuzzyMatchResult(1.0, []);
  if (text.isEmpty) return null;
  // Case-fold each rune; keep null for runes whose folding changes length
  // (they can still be matched by the fuzzy branch using fold-agnostic
  // positions computed on the folded string mapped back is unsafe, so they
  // are skipped in exact matching).
  final lowerQuery = query.toLowerCase();
  final lowerText = text.toLowerCase();
  if (lowerText.length == text.length && lowerQuery.length == query.length) {
    // Common fast path: case folding is length-preserving, positions align.
    final subIdx = lowerText.indexOf(lowerQuery);
    if (subIdx >= 0) {
      final pos = List.generate(lowerQuery.length, (i) => subIdx + i);
      double score = 1.0;
      if (subIdx == 0) score = 1.2;
      return FuzzyMatchResult(score, pos);
    }
    return _fuzzyMatchPositions(text, query);
  }
  // Length changed under case folding: match rune-by-rune on folded runes so
  // positions remain valid in the original text.
  return _foldedMatch(text, query);
}

/// Case-folds a rune, returning null when folding changes its unit length.
int? _foldRune(int rune) {
  final s = String.fromCharCode(rune);
  final folded = s.toLowerCase();
  if (folded.length != s.length) return null;
  final code = folded.runes.first;
  return folded.runes.length == 1 ? code : null;
}

/// Rune-wise match that survives case-folding length changes. Exact
/// substring run first, then fuzzy fallback; positions index the original
/// text's UTF-16 units.
FuzzyMatchResult? _foldedMatch(String text, String query) {
  final textRunes = text.runes.toList();
  final queryRunes = query.runes.toList();
  final foldedText = <int?>[for (final r in textRunes) _foldRune(r)];
  final foldedQuery = <int?>[for (final r in queryRunes) _foldRune(r)];

  // Rune offsets → UTF-16 offsets in the original text.
  final runeOffset = List.generate(textRunes.length + 1, (i) {
    var units = 0;
    for (var k = 0; k < i; k++) {
      units += textRunes[k] > 0xFFFF ? 2 : 1;
    }
    return units;
  });

  bool runesEqual(int start, int len) {
    if (start + len > foldedText.length) return false;
    for (var i = 0; i < len; i++) {
      final a = foldedText[start + i];
      final b = foldedQuery[i];
      if (a == null || b == null || a != b) return false;
    }
    return true;
  }

  for (var start = 0; start <= foldedText.length - queryRunes.length; start++) {
    if (runesEqual(start, queryRunes.length)) {
      final pos = [
        for (var i = 0; i < queryRunes.length; i++) runeOffset[start + i],
      ];
      double score = 1.0;
      if (start == 0) score = 1.2;
      return FuzzyMatchResult(score, pos);
    }
  }
  return _foldedFuzzyMatch(textRunes, foldedText, queryRunes, foldedQuery, runeOffset);
}

/// Fuzzy rune-wise fallback for the folded path; mirrors _fuzzyMatchPositions
/// scoring but works on runes and emits UTF-16 positions.
FuzzyMatchResult? _foldedFuzzyMatch(
  List<int> textRunes,
  List<int?> foldedText,
  List<int> queryRunes,
  List<int?> foldedQuery,
  List<int> runeOffset,
) {
  final positions = <int>[];
  int ti = 0;
  for (final qc in foldedQuery) {
    bool found = false;
    while (ti < foldedText.length) {
      final tc = foldedText[ti];
      if (qc != null && tc == qc) {
        positions.add(runeOffset[ti]);
        ti++;
        found = true;
        break;
      }
      ti++;
    }
    if (!found) return null;
  }
  if (positions.isEmpty) return null;
  int consecutiveBonus = 0;
  for (int i = 1; i < positions.length; i++) {
    if (positions[i] == positions[i - 1] + 1) consecutiveBonus += 6;
  }
  int gapPenalty = 0;
  for (int i = 1; i < positions.length; i++) {
    gapPenalty += (positions[i] - positions[i - 1] - 1);
  }
  double score = queryRunes.length * 10.0 + consecutiveBonus - gapPenalty * 0.5;
  if (positions[0] == 0) score += 5;
  score /= (textRunes.length * 1.5);
  return FuzzyMatchResult(score.clamp(0.01, 1.0), positions);
}

/// Returns all fields of an entry as (originalText, fieldName) pairs.
/// The Password field is intentionally excluded so secrets never influence
/// search scoring or highlighting.
List<(String, String)> entryFields(KdbxEntry entry) {
  final fields = <(String, String)>[];
  for (final e in entry.fields.entries) {
    if (e.key == 'Password') continue;
    final text = e.value.text;
    if (text.isNotEmpty) fields.add((text, e.key));
  }
  final tags = entry.tags;
  if (tags != null) {
    for (final tag in tags) {
      if (tag.isNotEmpty) fields.add((tag, 'tags'));
    }
  }
  return fields;
}

/// Finds the best match across all entry fields.
/// Returns (score, positionsInFieldText) for the best matching field.
FuzzyMatchResult? fuzzyMatchEntry(KdbxEntry entry, String query) {
  if (query.isEmpty) return FuzzyMatchResult(1.0, []);
  FuzzyMatchResult? best;
  for (final (text, _) in entryFields(entry)) {
    final result = fuzzyMatch(text, query);
    if (result != null && result.isMatch) {
      if (best == null || result.score > best.score) {
        best = result;
      }
    }
  }
  return best;
}

/// Internal: fuzzy character-by-character match with position tracking.
/// Returns null if not all query characters are found.
FuzzyMatchResult? _fuzzyMatchPositions(String text, String query) {
  final lowerText = text.toLowerCase();
  final lowerQuery = query.toLowerCase();
  final positions = <int>[];
  int ti = 0;
  for (int qi = 0; qi < lowerQuery.length; qi++) {
    final qc = lowerQuery[qi];
    bool found = false;
    while (ti < lowerText.length) {
      if (lowerText[ti] == qc) {
        positions.add(ti);
        ti++;
        found = true;
        break;
      }
      ti++;
    }
    if (!found) return null;
  }
  if (positions.isEmpty) return null;
  // Calculate score
  int consecutiveBonus = 0;
  for (int i = 1; i < positions.length; i++) {
    if (positions[i] == positions[i - 1] + 1) consecutiveBonus += 6;
  }
  int gapPenalty = 0;
  for (int i = 1; i < positions.length; i++) {
    gapPenalty += (positions[i] - positions[i - 1] - 1);
  }
  double score = positions.length * 10.0 + consecutiveBonus - gapPenalty * 0.5;
  if (positions[0] == 0) score += 5;
  score /= (text.length * 1.5);
  return FuzzyMatchResult(score.clamp(0.01, 1.0), positions);
}
