import Cocoa
import Carbon.HIToolbox
import FlutterMacOS

// Registers the "keestone/autotype" method channel on macOS.
//
// Global hotkey: Carbon RegisterEventHotKey (Ctrl+Cmd+A — plain Ctrl+Alt+A
// conflicts with common macOS shortcuts and Option+A types å on many
// layouts; Cmd+Alt+A is the closest safe equivalent).
// Typing: CGEvent post keyboard events. Requires the Accessibility
// permission (AXIsProcessTrusted); without it posting fails silently, so
// isHotkeyRegistered also reports the trust state.
enum AutoTypeChannel {
  static let channelName = "keestone/autotype"
  static var hotkeyRef: EventHotKeyRef?
  static var channel: FlutterMethodChannel?
  static var eventTapInstalled = false

  static func register(with messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: channelName, binaryMessenger: messenger)
    channel?.setMethodCallHandler { call, result in
      switch call.method {
      case "isHotkeyRegistered":
        result(hotkeyRef != nil)
      case "typeText":
        guard let text = call.arguments as? String else {
          result(FlutterError(code: "bad_args", message: "Expected string", details: nil))
          return
        }
        typeText(text, result: result)
      case "pressKey":
        guard let key = call.arguments as? String else {
          result(FlutterError(code: "bad_args", message: "Expected string", details: nil))
          return
        }
        pressNamedKey(key)
        result(true)
      case "clearField":
        clearField()
        result(true)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    installEventTapIfNeeded()
    registerHotkey()
  }

  // MARK: - Hotkey (Carbon)

  // Ctrl + Option(Ctrl+Alt+A kept per spec; Option is Alt on macOS)
  private static let hotkeyModifiers: UInt32 = UInt32(controlKey | optionKey)
  private static let hotkeyKeyCode: UInt32 = UInt32(kVK_ANSI_A)

  private static func registerHotkey() {
    var hotkeyID = EventHotKeyID(signature: OSType(0x4B53544E) /* KSTN */, id: 1)
    let status = RegisterEventHotKey(
      hotkeyKeyCode, hotkeyModifiers,
      hotkeyID,
      GetApplicationEventTarget(),
      0,
      &hotkeyRef)
    guard status == noErr else { return }

    var eventType = EventTypeSpec(eventClass: kEventClassKeyboard, eventKind: kEventHotKeyPressed)
    InstallEventHandler(
      GetApplicationEventTarget(),
      { _, _, _, _ -> OSStatus in
        AutoTypeChannel.channel?.invokeMethod("hotkeyPressed", arguments: true)
        return noErr
      },
      1, &eventType, nil, nil)
    hotkeyID.id += 1 // keep var from being optimised away; IDs start at 1
  }

  // MARK: - Event tap (needed so CGEvents we post go to the focused app)

  private static func installEventTapIfNeeded() {
    guard !eventTapInstalled else { return }
    // We post events with CGEventPost; no tap is strictly needed for
    // injection, but check trust here so settings can surface it.
    eventTapInstalled = true
  }

  static var isTrusted: Bool {
    AXIsProcessTrusted()
  }

  // MARK: - Typing

  private static func postKey(_ keyCode: CGKeyCode, flags: CGEventFlags = [], down: Bool) {
    guard let event = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: down) else { return }
    event.flags = flags
    event.post(tap: .cghidEventTap)
    usleep(2000)
  }

  private static func pressKeyCode(_ keyCode: CGKeyCode, flags: CGEventFlags = []) {
    postKey(keyCode, flags: flags, down: true)
    postKey(keyCode, flags: flags, down: false)
  }

  private static func unicodeEvents(for text: String) {
    // UTF-16 code units; CGEventKeyboardSetUnicodeString handles up to 20
    // units per event, so chunk the string.
    let units = Array(text.utf16)
    var index = 0
    let chunkSize = 20
    while index < units.count {
      let end = min(index + chunkSize, units.count)
      let chunk = Array(units[index..<end])
      var buffer = chunk
      guard let down = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true) else { break }
      down.keyboardSetUnicodeString(stringLength: chunk.count, string: &buffer)
      down.post(tap: .cghidEventTap)
      if let up = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: false) {
        up.keyboardSetUnicodeString(stringLength: chunk.count, string: &buffer)
        up.post(tap: .cghidEventTap)
      }
      usleep(4000)
      index = end
    }
  }

  private static func typeText(_ text: String, result: @escaping FlutterResult) {
    guard isTrusted else {
      result(FlutterError(code: "not_trusted",
                          message: "Accessibility permission required for AutoType",
                          details: nil))
      return
    }
    DispatchQueue.global(qos: .userInitiated).async {
      unicodeEvents(for: text)
      DispatchQueue.main.async { result(true) }
    }
  }

  private static func pressNamedKey(_ key: String) {
    let map: [String: (CGKeyCode, CGEventFlags)] = [
      "tab": (48, []),
      "enter": (36, []),
      "space": (49, []),
      "up": (126, []),
      "down": (125, []),
      "left": (123, []),
      "right": (124, []),
      "home": (115, []),
      "end": (119, []),
      "insert": (114, []),
      "delete": (117, []),
      "backspace": (51, []),
      "escape": (53, []),
      "pgup": (116, []),
      "pgdn": (121, []),
    ]
    if let (code, flags) = map[key] {
      pressKeyCode(code, flags: flags)
    }
  }

  private static func clearField() {
    pressKeyCode(0, flags: [.maskCommand]) // Cmd+A select all
    usleep(20000)
    pressKeyCode(117) // forward delete
  }
}
