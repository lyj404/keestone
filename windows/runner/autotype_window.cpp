#include "autotype_window.h"

#include <windows.h>

#include <flutter/encodable_value.h>
#include <flutter/binary_messenger.h>

#include <string>

namespace {

const wchar_t kClassName[] = L"KeeStoneAutoTypeWindow";
const int kHotKeyId = 1;
// Ctrl + Alt + A
const UINT kHotKeyModifiers = MOD_CONTROL | MOD_ALT;
const UINT kHotKeyVk = 'A';

// Messages sent from WndProc into the channel.
const char kMethodHotkeyPressed[] = "hotkeyPressed";

void SendUnicodeChar(const std::string& utf8) {
  // Convert UTF-8 to UTF-16 so wide-characters (CJK etc.) can be typed.
  const int wide_len =
      MultiByteToWideChar(CP_UTF8, 0, utf8.c_str(), -1, nullptr, 0);
  if (wide_len <= 0) return;
  std::wstring wide(static_cast<size_t>(wide_len), L'\0');
  MultiByteToWideChar(CP_UTF8, 0, utf8.c_str(), -1, &wide[0], wide_len);

  for (const wchar_t ch : wide) {
    if (ch == L'\0') break;
    INPUT input = {};
    input.type = INPUT_KEYBOARD;
    input.ki.wScan = static_cast<WORD>(ch);
    input.ki.dwFlags = KEYEVENTF_UNICODE;
    SendInput(1, &input, sizeof(INPUT));

    INPUT up = input;
    up.ki.dwFlags = KEYEVENTF_UNICODE | KEYEVENTF_KEYUP;
    SendInput(1, &up, sizeof(INPUT));
  }
}

WORD VirtualKeyForName(const std::string& key) {
  if (key == "tab") return VK_TAB;
  if (key == "enter") return VK_RETURN;
  if (key == "space") return VK_SPACE;
  if (key == "up") return VK_UP;
  if (key == "down") return VK_DOWN;
  if (key == "left") return VK_LEFT;
  if (key == "right") return VK_RIGHT;
  if (key == "home") return VK_HOME;
  if (key == "end") return VK_END;
  if (key == "insert") return VK_INSERT;
  if (key == "delete") return VK_DELETE;
  if (key == "backspace") return VK_BACK;
  if (key == "escape") return VK_ESCAPE;
  if (key == "pgup") return VK_PRIOR;
  if (key == "pgdn") return VK_NEXT;
  if (key == "add") return VK_ADD;
  if (key == "subtract") return VK_SUBTRACT;
  if (key == "multiply") return VK_MULTIPLY;
  if (key == "divide") return VK_DIVIDE;
  if (key == "capslock") return VK_CAPITAL;
  return 0;
}

AutoTypeWindow* g_instance = nullptr;

}  // namespace

bool AutoTypeWindow::Initialize(flutter::BinaryMessenger* messenger) {
  if (g_instance != nullptr) return true;
  g_instance = new AutoTypeWindow();

  HINSTANCE instance = GetModuleHandle(nullptr);

  WNDCLASSEXW wc = {};
  wc.cbSize = sizeof(WNDCLASSEXW);
  wc.lpfnWndProc = AutoTypeWindow::WndProc;
  wc.hInstance = instance;
  wc.lpszClassName = kClassName;
  RegisterClassExW(&wc);

  g_instance->hwnd_ =
      CreateWindowExW(0, kClassName, L"", 0, 0, 0, 0, 0, HWND_MESSAGE,
                      nullptr, instance, nullptr);
  if (g_instance->hwnd_ == nullptr) return false;

  g_instance->hotkey_registered_ =
      RegisterHotKey(g_instance->hwnd_, kHotKeyId, kHotKeyModifiers, kHotKeyVk);

  g_instance->channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          messenger, "keestone/autotype",
          &flutter::StandardMethodCodec::GetInstance());
  g_instance->channel_->SetMethodCallHandler(
      [instance](const flutter::MethodCall<flutter::EncodableValue>& call,
                 std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
                     result) {
        g_instance->HandleMethodCall(call, std::move(result));
      });

  return true;
}

LRESULT CALLBACK AutoTypeWindow::WndProc(HWND hwnd, UINT message,
                                         WPARAM wParam, LPARAM lParam) {
  if (message == WM_HOTKEY && wParam == kHotKeyId && g_instance != nullptr &&
      g_instance->channel_ != nullptr) {
    g_instance->channel_->InvokeMethod(
        kMethodHotkeyPressed,
        std::make_unique<flutter::EncodableValue>(true));
    return 0;
  }
  return DefWindowProc(hwnd, message, wParam, lParam);
}

void AutoTypeWindow::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue>& call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  const std::string& method = call.method_name();

  if (method == "isHotkeyRegistered") {
    result->Success(flutter::EncodableValue(hotkey_registered_));
    return;
  }

  if (method == "typeText") {
    const auto* args = std::get_if<std::string>(call.arguments());
    if (args == nullptr) {
      result->Error("bad_args", "Expected a string argument.");
      return;
    }
    TypeText(*args);
    result->Success(flutter::EncodableValue(true));
    return;
  }

  if (method == "pressKey") {
    const auto* args = std::get_if<std::string>(call.arguments());
    if (args == nullptr) {
      result->Error("bad_args", "Expected a string argument.");
      return;
    }
    PressKey(*args);
    result->Success(flutter::EncodableValue(true));
    return;
  }

  if (method == "clearField") {
    ClearCurrentField();
    result->Success(flutter::EncodableValue(true));
    return;
  }

  result->NotImplemented();
}

void AutoTypeWindow::SendKey(WORD vk, bool up) {
  INPUT input = {};
  input.type = INPUT_KEYBOARD;
  input.ki.wVk = vk;
  input.ki.dwFlags = up ? KEYEVENTF_KEYUP : 0;
  SendInput(1, &input, sizeof(INPUT));
}

void AutoTypeWindow::TypeText(const std::string& text) {
  SendUnicodeChar(text);
}

void AutoTypeWindow::PressKey(const std::string& key) {
  WORD vk = VirtualKeyForName(key);
  if (vk == 0) return;
  SendKey(vk, false);
  SendKey(vk, true);
}

void AutoTypeWindow::ClearCurrentField() {
  // Select all (Ctrl+A) then delete; this covers standard text fields.
  SendKey(VK_CONTROL, false);
  SendKey('A', false);
  SendKey('A', true);
  SendKey(VK_CONTROL, true);
  SendKey(VK_DELETE, false);
  SendKey(VK_DELETE, true);
}
