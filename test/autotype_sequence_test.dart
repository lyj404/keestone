import 'package:flutter_test/flutter_test.dart';
import 'package:keestone/features/autotype/data/autotype_sequence.dart';

void main() {
  group('parseAutoTypeSequence', () {
    test('parses default sequence into fields and keys', () {
      final tokens = parseAutoTypeSequence('{USERNAME}{TAB}{PASSWORD}{ENTER}');
      expect(tokens, hasLength(4));
      expect(tokens[0], isA<FieldPlaceholder>().having(
        (t) => t.field,
        'field',
        'username',
      ));
      expect(tokens[1], isA<KeyPress>().having((t) => t.key, 'key', 'tab'));
      expect(tokens[2], isA<FieldPlaceholder>().having(
        (t) => t.field,
        'field',
        'password',
      ));
      expect(tokens[3], isA<KeyPress>().having((t) => t.key, 'key', 'enter'));
    });

    test('parses literal text between placeholders', () {
      final tokens = parseAutoTypeSequence('user: {USERNAME}!');
      expect(tokens, hasLength(3));
      expect((tokens[0] as LiteralText).text, 'user: ');
      expect((tokens[1] as FieldPlaceholder).field, 'username');
      expect((tokens[2] as LiteralText).text, '!');
    });

    test('parses {DELAY ms} with parameter', () {
      final tokens = parseAutoTypeSequence('{USERNAME}{DELAY 250}{PASSWORD}');
      expect(tokens[1], isA<Delay>().having(
        (t) => t.milliseconds,
        'ms',
        250,
      ));
    });

    test('treats unknown placeholders as literal text', () {
      final tokens = parseAutoTypeSequence('{VKEY 13}{USERNAME}');
      expect((tokens[0] as LiteralText).text, '{VKEY 13}');
      expect(tokens[1], isA<FieldPlaceholder>());
    });

    test('handles unterminated placeholder as literal', () {
      final tokens = parseAutoTypeSequence('abc{USERNAME');
      expect((tokens.single as LiteralText).text, 'abc{USERNAME');
    });

    test('parses {CLEARFIELD}', () {
      final tokens = parseAutoTypeSequence('{CLEARFIELD}{PASSWORD}');
      expect(tokens.first, isA<ClearField>());
    });

    test('normalizes BS and ESC aliases', () {
      final tokens = parseAutoTypeSequence('{BS}{ESC}');
      expect((tokens[0] as KeyPress).key, 'backspace');
      expect((tokens[1] as KeyPress).key, 'escape');
    });
  });

  group('buildAutoTypeActions', () {
    test('expands placeholders to typed text, skips empty fields', () {
      final actions = buildAutoTypeActions(
        tokens: parseAutoTypeSequence('{USERNAME}{TAB}{PASSWORD}'),
        username: 'alice',
        password: '',
        title: null,
        url: null,
        notes: null,
        totp: null,
      );
      expect(actions, hasLength(2));
      expect((actions[0] as TypeText).text, 'alice');
      expect((actions[1] as PressKey).key, 'tab');
    });

    test('does not type password in clear text via placeholder', () {
      final actions = buildAutoTypeActions(
        tokens: parseAutoTypeSequence('{PASSWORD}'),
        username: null,
        password: 'hunter2',
        title: null,
        url: null,
        notes: null,
        totp: null,
      );
      expect((actions.single as TypeText).text, 'hunter2');
    });

    test('keeps Delay and ClearField actions', () {
      final actions = buildAutoTypeActions(
        tokens: parseAutoTypeSequence('{DELAY 100}{CLEARFIELD}{ENTER}'),
        username: null,
        password: null,
        title: null,
        url: null,
        notes: null,
        totp: null,
      );
      expect(actions[0], isA<Pause>());
      expect(actions[1], isA<ClearCurrentField>());
      expect(actions[2], isA<PressKey>());
    });
  });
}
