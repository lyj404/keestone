import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import 'password_strength_indicator.dart';

class PasswordTextField extends StatefulWidget {
  final TextEditingController? controller;
  final String? labelText;
  final String? hintText;
  final String? Function(String?)? validator;
  final bool autofocus;
  final bool showPrefixIcon;
  final bool showStrengthIndicator;
  final ValueChanged<String>? onFieldSubmitted;

  const PasswordTextField({
    super.key,
    this.controller,
    this.labelText,
    this.hintText,
    this.validator,
    this.autofocus = false,
    this.showPrefixIcon = true,
    this.showStrengthIndicator = false,
    this.onFieldSubmitted,
  });

  @override
  State<PasswordTextField> createState() => _PasswordTextFieldState();
}

class _PasswordTextFieldState extends State<PasswordTextField> {
  bool _obscure = true;
  late TextEditingController _controller;
  bool _ownsController = false;
  late final FocusNode _focusNode;

  // Workaround for Flutter Linux GTK not handling numpad keys (KP_0..KP_9)
  static final _numpadLogicalMap = {
    LogicalKeyboardKey.numpad0: '0',
    LogicalKeyboardKey.numpad1: '1',
    LogicalKeyboardKey.numpad2: '2',
    LogicalKeyboardKey.numpad3: '3',
    LogicalKeyboardKey.numpad4: '4',
    LogicalKeyboardKey.numpad5: '5',
    LogicalKeyboardKey.numpad6: '6',
    LogicalKeyboardKey.numpad7: '7',
    LogicalKeyboardKey.numpad8: '8',
    LogicalKeyboardKey.numpad9: '9',
    LogicalKeyboardKey.numpadDecimal: '.',
    LogicalKeyboardKey.numpadAdd: '+',
    LogicalKeyboardKey.numpadSubtract: '-',
    LogicalKeyboardKey.numpadMultiply: '*',
    LogicalKeyboardKey.numpadDivide: '/',
  };
  // Physical key codes as fallback (USB HID, consistent across platforms)
  static final _numpadPhysicalMap = {
    0x00090062: '0', // Numpad 0
    0x00090059: '1', // Numpad 1
    0x0009005a: '2', // Numpad 2
    0x0009005b: '3', // Numpad 3
    0x0009005c: '4', // Numpad 4
    0x0009005d: '5', // Numpad 5
    0x0009005e: '6', // Numpad 6
    0x0009005f: '7', // Numpad 7
    0x00090060: '8', // Numpad 8
    0x00090061: '9', // Numpad 9
    0x00090063: '.', // Numpad Decimal
    0x00090057: '+', // Numpad Add
    0x00090056: '-', // Numpad Subtract
    0x00090055: '*', // Numpad Multiply
    0x00090054: '/', // Numpad Divide
  };

  bool _listenerAttached = false;

  @override
  void initState() {
    super.initState();
    if (widget.controller != null) {
      _controller = widget.controller!;
    } else {
      _controller = TextEditingController();
      _ownsController = true;
    }
    _focusNode = FocusNode(onKeyEvent: _handleKeyEvent);
    if (widget.showStrengthIndicator) {
      _controller.addListener(_onTextChanged);
      _listenerAttached = true;
    }
  }

  @override
  void didUpdateWidget(PasswordTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.showStrengthIndicator && !_listenerAttached) {
      _controller.addListener(_onTextChanged);
      _listenerAttached = true;
    } else if (!widget.showStrengthIndicator && _listenerAttached) {
      _controller.removeListener(_onTextChanged);
      _listenerAttached = false;
    }
  }

  @override
  void dispose() {
    if (_listenerAttached) {
      _controller.removeListener(_onTextChanged);
    }
    _focusNode.dispose();
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    // Try logical key first, then physical key code as fallback
    final char =
        _numpadLogicalMap[event.logicalKey] ??
        _numpadPhysicalMap[event.physicalKey.usbHidUsage];
    if (char == null) return KeyEventResult.ignored;
    final sel = _controller.selection;
    final text = _controller.text;
    final start = sel.start >= 0 ? sel.start : text.length;
    final end = sel.end >= 0 ? sel.end : text.length;
    _controller.text = text.replaceRange(start, end, char);
    _controller.selection = TextSelection.collapsed(
      offset: start + char.length,
    );
    return KeyEventResult.handled;
  }

  void _onTextChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: _controller,
          focusNode: _focusNode,
          obscureText: _obscure,
          autofocus: widget.autofocus,
          validator: widget.validator,
          onFieldSubmitted: widget.onFieldSubmitted,
          decoration: InputDecoration(
            labelText: widget.labelText,
            hintText: widget.hintText,
            prefixIcon: widget.showPrefixIcon
                ? const Icon(Icons.lock_outline_rounded)
                : null,
            suffixIcon: IconButton(
              icon: Icon(
                _obscure
                    ? Icons.visibility_off_rounded
                    : Icons.visibility_rounded,
                size: 18,
              ),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
          ),
        ),
        if (widget.showStrengthIndicator)
          PasswordStrengthIndicator(password: _controller.text),
      ],
    );
  }
}
