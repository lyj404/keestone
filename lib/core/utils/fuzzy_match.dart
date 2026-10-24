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
/// Supports:
///   - Exact substring match (highest priority)
///   - Prefix match
///   - Word-boundary match
///   - Fuzzy character-by-character match
FuzzyMatchResult? fuzzyMatch(String text, String query) {
  if (query.isEmpty) return FuzzyMatchResult(1.0, []);
  if (text.isEmpty) return null;
  final lowerText = text.toLowerCase();
  final lowerQuery = query.toLowerCase();
  // 1. Exact substring match
  final subIdx = lowerText.indexOf(lowerQuery);
  if (subIdx >= 0) {
    final pos = List.generate(query.length, (i) => subIdx + i);
    double score = 1.0;
    if (subIdx == 0) score = 1.2;
    return FuzzyMatchResult(score, pos);
  }
  // 2. Fuzzy character-by-character match
  return _fuzzyMatchPositions(text, query);
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
