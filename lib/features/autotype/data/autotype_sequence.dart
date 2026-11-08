import 'dart:async';

/// Parsed token of an AutoType sequence.
///
/// Play commands are modeled after the KeePass AutoType standard subset:
/// field placeholders ({USERNAME}, {TITLE}, {URL}, {PASSWORD}, {NOTES},
/// {TOTP}), keys ({TAB}, {ENTER}, {SPACE}, ...), {DELAY ms} pauses and
/// {CLEARFIELD}. Literal text is typed verbatim.
sealed class AutoTypeToken {
  const AutoTypeToken();
}

class LiteralText extends AutoTypeToken {
  final String text;
  const LiteralText(this.text);
}

class FieldPlaceholder extends AutoTypeToken {
  /// Canonical field name: username/title/url/password/notes/totp.
  final String field;
  const FieldPlaceholder(this.field);
}

class KeyPress extends AutoTypeToken {
  /// Canonical key name: tab/enter/space/up/down/left/right/home/end/
  /// insert/delete/backspace/escape/pgup/pgdn/add/subtract/multiply/divide.
  final String key;
  const KeyPress(this.key);
}

class Delay extends AutoTypeToken {
  final int milliseconds;
  const Delay(this.milliseconds);
}

class ClearField extends AutoTypeToken {
  const ClearField();
}

/// Default sequence used when an entry does not define a custom one.
const String defaultAutoTypeSequence =
    '{USERNAME}{TAB}{PASSWORD}{ENTER}';

/// Parses a KeePass-style AutoType sequence into tokens.
///
/// Unknown placeholders are kept as literal text so a malformed sequence
/// never silently drops content. A lone closing brace is also literal.
List<AutoTypeToken> parseAutoTypeSequence(String sequence) {
  final tokens = <AutoTypeToken>[];
  final buffer = StringBuffer();
  void flush() {
    if (buffer.isNotEmpty) {
      tokens.add(LiteralText(buffer.toString()));
      buffer.clear();
    }
  }

  for (var i = 0; i < sequence.length; i++) {
    final ch = sequence[i];
    if (ch != '{') {
      buffer.write(ch);
      continue;
    }
    final close = sequence.indexOf('}', i + 1);
    if (close < 0) {
      buffer.write(sequence.substring(i));
      break;
    }
    final inner = sequence.substring(i + 1, close);
    final upper = inner.toUpperCase();

    switch (upper) {
      case 'USERNAME':
      case 'TITLE':
      case 'URL':
      case 'PASSWORD':
      case 'NOTES':
      case 'TOTP':
        flush();
        tokens.add(FieldPlaceholder(upper.toLowerCase()));
        break;
      case 'CLEARFIELD':
        flush();
        tokens.add(const ClearField());
        break;
      case 'DELAY':
        // {DELAY ms} with the parameter inside braces (KeePass style 2).
        // A bare {DELAY} is treated as a short 100ms pause.
        flush();
        tokens.add(const Delay(100));
        break;
      case 'TAB':
      case 'ENTER':
      case 'SPACE':
      case 'UP':
      case 'DOWN':
      case 'LEFT':
      case 'RIGHT':
      case 'HOME':
      case 'END':
      case 'INSERT':
      case 'DELETE':
      case 'BACKSPACE':
      case 'BS':
      case 'ESC':
      case 'ESCAPE':
      case 'PGUP':
      case 'PGDN':
      case 'ADD':
      case 'SUBTRACT':
      case 'MULTIPLY':
      case 'DIVIDE':
      case 'CAPSLOCK':
        flush();
        tokens.add(KeyPress(_canonicalKey(upper)));
        break;
      default:
        // {DELAY 250}, {VKEY ...}, unknown: keep literal.
        if (upper.startsWith('DELAY ')) {
          final ms = int.tryParse(inner.substring(6).trim());
          flush();
          tokens.add(Delay(ms != null && ms > 0 ? ms : 100));
        } else {
          buffer.write(sequence.substring(i, close + 1));
        }
    }
    i = close;
  }
  flush();
  return tokens;
}

String _canonicalKey(String upper) {
  switch (upper) {
    case 'BS':
      return 'backspace';
    case 'ESC':
    case 'ESCAPE':
      return 'escape';
    case 'PGDN':
      return 'pgdn';
    default:
      return upper.toLowerCase();
  }
}

/// A single low-level action the native typer must perform.
sealed class AutoTypeAction {
  const AutoTypeAction();
}

class TypeText extends AutoTypeAction {
  final String text;
  const TypeText(this.text);
}

class PressKey extends AutoTypeAction {
  /// Canonical key name matching [KeyPress.key].
  final String key;
  const PressKey(this.key);
}

class Pause extends AutoTypeAction {
  final int milliseconds;
  const Pause(this.milliseconds);
}

class ClearCurrentField extends AutoTypeAction {
  const ClearCurrentField();
}

/// Resolves placeholders against an entry snapshot and expands the parsed
/// sequence into a flat, executable action list.
List<AutoTypeAction> buildAutoTypeActions({
  required List<AutoTypeToken> tokens,
  required String? username,
  required String? password,
  required String? title,
  required String? url,
  required String? notes,
  required String? totp,
  bool useClipboardForPassword = false,
}) {
  String valueFor(String field) {
    switch (field) {
      case 'username':
        return username ?? '';
      case 'password':
        return password ?? '';
      case 'title':
        return title ?? '';
      case 'url':
        return url ?? '';
      case 'notes':
        return notes ?? '';
      case 'totp':
        return totp ?? '';
      default:
        return '';
    }
  }

  final actions = <AutoTypeAction>[];
  for (final token in tokens) {
    switch (token) {
      case LiteralText(:final text):
        actions.add(TypeText(text));
      case FieldPlaceholder(:final field):
        final value = valueFor(field);
        if (value.isNotEmpty) actions.add(TypeText(value));
      case KeyPress(:final key):
        actions.add(PressKey(key));
      case Delay(:final milliseconds):
        actions.add(Pause(milliseconds));
      case ClearField():
        actions.add(const ClearCurrentField());
    }
  }
  return actions;
}

/// Executes an action list by delegating to a native type callback, with
/// pacing delays between actions so slow dialogs can keep up.
Future<void> runAutoTypeActions(
  List<AutoTypeAction> actions,
  Future<void> Function(AutoTypeAction action) perform,
) async {
  for (final action in actions) {
    if (action is Pause) {
      await Future<void>.delayed(Duration(milliseconds: action.milliseconds));
      continue;
    }
    await perform(action);
    // Small inter-action pause keeps target apps responsive; password
    // characters get a slightly longer pause for virtual keyboard / IME
    // heavy environments.
    await Future<void>.delayed(
      Duration(
        milliseconds: action is TypeText && action.text.length == 1 ? 8 : 20,
      ),
    );
  }
}
