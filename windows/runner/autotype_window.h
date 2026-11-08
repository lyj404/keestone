#ifndef RUNNER_AUTOTYPE_WINDOW_H_
#define RUNNER_AUTOTYPE_WINDOW_H_

#include <windows.h>

#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include <memory>

// Owns the global AutoType hotkey and native text typing. A hidden window is
// created to receive WM_HOTKEY messages; keystrokes are injected with
// SendInput and reported back to Dart over the "keestone/autotype" channel.
class AutoTypeWindow {
 public:
  // Installs the hotkey (Ctrl+Alt+A) and returns the hidden message window
  // handle. Returns nullptr on failure.
  static bool Initialize(flutter::BinaryMessenger* messenger);

  AutoTypeWindow(const AutoTypeWindow&) = delete;
  AutoTypeWindow& operator=(const AutoTypeWindow&) = delete;

 private:
  AutoTypeWindow() = default;

  static LRESULT CALLBACK WndProc(HWND hwnd, UINT message, WPARAM wParam,
                                  LPARAM lParam);

  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  void TypeText(const std::string& text);
  void PressKey(const std::string& key);
  void ClearCurrentField();

  void SendKey(WORD vk, bool up);

  flutter::MethodChannel<flutter::EncodableValue>* channel() {
    return channel_.get();
  }

  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
  HWND hwnd_ = nullptr;
  bool hotkey_registered_ = false;
};

#endif  // RUNNER_AUTOTYPE_WINDOW_H_
