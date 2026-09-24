import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

/// Windows-specific notification implementation using Win32 Shell_NotifyIcon.
/// The window class and window are created once and reused for all notifications.
///
/// This file is also linked on non-Windows `dart:io` targets via conditional
/// import; every entry point must no-op unless [Platform.isWindows].
class WindowsNotificationHelper {
  static final WindowsNotificationHelper _instance =
      WindowsNotificationHelper._();
  factory WindowsNotificationHelper() => _instance;
  WindowsNotificationHelper._();

  HWND _hWnd = HWND(nullptr);
  bool _classRegistered = false;
  late final HINSTANCE _hInstance;
  late final PCWSTR _classNamePtr;
  late final PCWSTR _windowTitlePtr;
  Pointer<NativeFunction<WNDPROC>>? _wndProc;

  void _ensureInitialized() {
    if (!Platform.isWindows) return;
    if (_classRegistered) return;

    _hInstance = HINSTANCE(GetModuleHandle(null).value);
    _classNamePtr = 'KeeStoneNotifyWnd'.toPcwstr();
    _windowTitlePtr = 'KeeStone Notify'.toPcwstr();
    _wndProc = Pointer.fromFunction<WNDPROC>(_defWindowProc, 0);

    final wc = calloc<WNDCLASS>();
    try {
      wc.ref.lpfnWndProc = _wndProc!;
      wc.ref.hInstance = _hInstance;
      wc.ref.lpszClassName = PWSTR(_classNamePtr.cast());
      RegisterClass(wc);
      _classRegistered = true;

      final result = CreateWindowEx(
        WINDOW_EX_STYLE(0),
        _classNamePtr,
        _windowTitlePtr,
        WINDOW_STYLE(0),
        0,
        0,
        0,
        0,
        HWND_MESSAGE,
        null,
        _hInstance,
        nullptr,
      );
      _hWnd = result.value;
    } finally {
      calloc.free(wc);
    }
  }

  void showBalloon(String title, String body) {
    if (!Platform.isWindows) return;
    _ensureInitialized();

    if (_hWnd.isNull) return;

    final nid = calloc<NOTIFYICONDATA>();
    try {
      nid.ref.cbSize = sizeOf<NOTIFYICONDATA>();
      nid.ref.hWnd = _hWnd;
      nid.ref.uID = 1;
      nid.ref.uCallbackMessage = WM_APP + 1;
      // The balloon notification is attached to a notification-area icon, so
      // it must be added first and kept alive while the balloon shows. The
      // previous NIM_ADD(NIF_INFO) + immediate NIM_DELETE made Explorer
      // cancel the balloon before it was visible.
      nid.ref.uFlags = NIF_MESSAGE;
      if (Shell_NotifyIcon(NIM_ADD, nid)) {
        nid.ref.uFlags = NIF_INFO;
        nid.ref.dwInfoFlags = NIIF_INFO;
        nid.ref.Anonymous.uTimeout = 10000;
        nid.ref.szInfoTitle = title;
        nid.ref.szInfo = body;
        Shell_NotifyIcon(NIM_MODIFY, nid);

        // Remove the (invisible) icon once the balloon has had time to show.
        Timer(const Duration(seconds: 15), () {
          final cleanup = calloc<NOTIFYICONDATA>();
          try {
            cleanup.ref.cbSize = sizeOf<NOTIFYICONDATA>();
            cleanup.ref.hWnd = _hWnd;
            cleanup.ref.uID = 1;
            Shell_NotifyIcon(NIM_DELETE, cleanup);
          } finally {
            calloc.free(cleanup);
          }
        });
      }
    } finally {
      calloc.free(nid);
    }
  }

  static int _defWindowProc(
    Pointer hWnd,
    int uMsg,
    int wParam,
    int lParam,
  ) {
    return DefWindowProc(HWND(hWnd), uMsg, WPARAM(wParam), LPARAM(lParam));
  }

  void dispose() {
    if (!Platform.isWindows) return;
    if (!_hWnd.isNull) {
      DestroyWindow(_hWnd);
      _hWnd = HWND(nullptr);
    }
    if (_classRegistered) {
      UnregisterClass(_classNamePtr, _hInstance);
      free(_classNamePtr);
      free(_windowTitlePtr);
      _classRegistered = false;
    }
  }
}
