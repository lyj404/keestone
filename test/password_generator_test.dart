import 'package:flutter_test/flutter_test.dart';
import 'package:keestone/core/utils/password_generator.dart';

void main() {
  group('PasswordGenerator.generate', () {
    test('produces the requested length', () {
      for (final length in [4, 8, 20, 64]) {
        final pw = PasswordGenerator.generate(length: length);
        expect(pw.length, length);
      }
    });

    test('only uses characters from the enabled categories', () {
      final pw = PasswordGenerator.generate(
        length: 40,
        useUppercase: false,
        useLowercase: true,
        useDigits: true,
        useSymbols: false,
        useHyphen: false,
        useSpace: false,
        useUnderscore: false,
        useParentheses: false,
        excludeAmbiguous: false,
      );
      final allowed = RegExp(r'^[a-z0-9]+$');
      expect(allowed.hasMatch(pw), true, reason: pw);
    });

    test('excludeAmbiguous removes every ambiguous glyph', () {
      const ambiguous = {'0', 'O', '1', 'l', 'I', '|', '`'};
      for (var i = 0; i < 50; i++) {
        final pw = PasswordGenerator.generate(
          length: 60,
          excludeAmbiguous: true,
          ensureEachType: false,
        );
        for (final c in pw.split('')) {
          expect(ambiguous.contains(c), false, reason: 'ambiguous $c in $pw');
        }
      }
    });

    test('ensureEachType guarantees at least one char per enabled category', () {
      for (var i = 0; i < 50; i++) {
        final pw = PasswordGenerator.generate(
          length: 16,
          useUppercase: true,
          useLowercase: true,
          useDigits: true,
          useSymbols: true,
          useHyphen: false,
          useSpace: false,
          useUnderscore: true,
          useParentheses: false,
          excludeAmbiguous: false,
          ensureEachType: true,
        );
        expect(RegExp(r'[A-Z]').hasMatch(pw), true, reason: 'no uppercase in $pw');
        expect(RegExp(r'[a-z]').hasMatch(pw), true, reason: 'no lowercase in $pw');
        expect(RegExp(r'[0-9]').hasMatch(pw), true, reason: 'no digit in $pw');
        expect(pw.contains('_'), true, reason: 'no underscore in $pw');
        // symbols set contains at least one non-alphanumeric
        expect(RegExp(r'[^A-Za-z0-9_]').hasMatch(pw), true, reason: 'no symbol in $pw');
      }
    });

    test('falls back to lowercase when nothing is enabled', () {
      final pw = PasswordGenerator.generate(
        length: 10,
        useUppercase: false,
        useLowercase: false,
        useDigits: false,
        useSymbols: false,
        useHyphen: false,
        useSpace: false,
        useUnderscore: false,
        useParentheses: false,
      );
      expect(RegExp(r'^[a-z]+$').hasMatch(pw), true);
    });

    test('incorporates custom symbols', () {
      final pw = PasswordGenerator.generate(
        length: 200,
        customSymbols: 'Q',
        useUppercase: false,
        useLowercase: false,
        useDigits: false,
        useSymbols: false,
        useHyphen: false,
        useSpace: false,
        useUnderscore: false,
        useParentheses: false,
        ensureEachType: false,
      );
      expect(pw.contains('Q'), true);
    });
  });

  group('PasswordGenerator.generatePassphrase', () {
    test('yields the requested number of words separated by the separator', () {
      final pp = PasswordGenerator.generatePassphrase(
        wordCount: 4,
        separator: '-',
        appendDigit: false,
      );
      expect(pp.split('-').length, 4);
    });

    test('appends a single digit when requested', () {
      final pp = PasswordGenerator.generatePassphrase(
        wordCount: 3,
        separator: '-',
        appendDigit: true,
      );
      final parts = pp.split('-');
      expect(parts.length, 4);
      expect(int.tryParse(parts.last), isNotNull);
    });

    test('never emits empty tokens for a non-empty separator', () {
      for (var i = 0; i < 20; i++) {
        final pp = PasswordGenerator.generatePassphrase(
          wordCount: 5,
          separator: '.',
          appendDigit: false,
        );
        for (final token in pp.split('.')) {
          expect(token.isNotEmpty, true, reason: 'empty token in $pp');
        }
      }
    });

    test('word list has no duplicates', () {
      final words = PasswordGenerator.passphraseWords;
      expect(words.toSet().length, words.length);
    });
  });
}
