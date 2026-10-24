import 'package:material_ui/material_ui.dart';

import '../../l10n/app_localizations.dart';

enum PasswordStrengthLevel {
  weak,
  fair,
  good,
  strong;

  String getLabel(AppLocalizations l10n) {
    switch (this) {
      case PasswordStrengthLevel.weak:
        return l10n.strengthWeak;
      case PasswordStrengthLevel.fair:
        return l10n.strengthFair;
      case PasswordStrengthLevel.good:
        return l10n.strengthGood;
      case PasswordStrengthLevel.strong:
        return l10n.strengthStrong;
    }
  }

  Color get color {
    switch (this) {
      case PasswordStrengthLevel.weak:
        return const Color(0xFFDC2626);
      case PasswordStrengthLevel.fair:
        return const Color(0xFFF59E0B);
      case PasswordStrengthLevel.good:
        return const Color(0xFF16A34A);
      case PasswordStrengthLevel.strong:
        return const Color(0xFF0284C7);
    }
  }

  double get fraction {
    switch (this) {
      case PasswordStrengthLevel.weak:
        return 0.25;
      case PasswordStrengthLevel.fair:
        return 0.5;
      case PasswordStrengthLevel.good:
        return 0.75;
      case PasswordStrengthLevel.strong:
        return 1.0;
    }
  }
}

PasswordStrengthLevel evaluatePasswordStrength(String password) {
  if (password.isEmpty) return PasswordStrengthLevel.weak;

  int score = 0;

  // Length
  if (password.length >= 8) score++;
  if (password.length >= 12) score++;
  if (password.length >= 16) score++;

  // Character variety
  if (RegExp(r'[a-z]').hasMatch(password)) score++;
  if (RegExp(r'[A-Z]').hasMatch(password)) score++;
  if (RegExp(r'[0-9]').hasMatch(password)) score++;
  if (RegExp(r'[!@#$%^&*()_+\-=\[\]{};:"\\|,.<>/?~`]').hasMatch(password)) {
    score++;
  }

  // Bonus for mixing types
  int types = 0;
  if (RegExp(r'[a-z]').hasMatch(password)) types++;
  if (RegExp(r'[A-Z]').hasMatch(password)) types++;
  if (RegExp(r'[0-9]').hasMatch(password)) types++;
  if (RegExp(r'[^a-zA-Z0-9]').hasMatch(password)) types++;
  if (types >= 3) score++;

  // Penalty for repeated chars
  if (RegExp(r'(.)\1{2,}').hasMatch(password)) score--;

  // Penalty for sequential chars
  if (_hasSequentialChars(password)) score--;

  if (score <= 2) return PasswordStrengthLevel.weak;
  if (score <= 4) return PasswordStrengthLevel.fair;
  if (score <= 6) return PasswordStrengthLevel.good;
  return PasswordStrengthLevel.strong;
}

bool _hasSequentialChars(String password) {
  for (int i = 0; i < password.length - 2; i++) {
    final a = password.codeUnitAt(i);
    final b = password.codeUnitAt(i + 1);
    final c = password.codeUnitAt(i + 2);
    if (b - a == 1 && c - b == 1) return true;
    if (a - b == 1 && b - c == 1) return true;
  }
  return false;
}
