#include "autotype_channel.h"

#include <X11/Xlib.h>
#include <X11/XF86keysym.h>
#include <X11/keysym.h>
#include <X11/extensions/XTest.h>
#include <gdk/gdk.h>
#include <gdk/gdkx.h>

#include <string>

namespace {

const char kChannelName[] = "keestone/autotype";
const int kHotkeyKeycodeMask = (ControlMask | Mod1Mask);
const KeySym kHotkeyKeysym = XK_a;

struct AutotypeState {
  FlMethodChannel* channel = nullptr;
  Display* display = nullptr;
  Window root = 0;
  bool x11 = false;
  bool hotkey_grabbed = false;
};

AutotypeState g_state;

// --- X11 error handling: XGrabKey on an already-grabbed key raises an
// error asynchronously; install a handler that just records failure.
bool g_grab_failed = false;
int grab_error_handler(Display*, XErrorEvent*) {
  g_grab_failed = true;
  return 0;
}

gboolean dispatch_hotkey(gpointer) {
  if (g_state.channel != nullptr) {
    fl_method_channel_invoke_method(g_state.channel, "hotkeyPressed", nullptr,
                                    nullptr, nullptr, nullptr);
  }
  return G_SOURCE_CONTINUE;
}

void bind_hotkey_to_glib() {
  // Xlib on its own requires polling; use the GDK display connection which
  // already integrates with the GLib main loop, so X GrabKey events reach us
  // through the normal GDK event dispatch.
  Display* display = g_state.display;
  Window root = g_state.root;

  XErrorHandler previous = XSetErrorHandler(grab_error_handler);
  g_grab_failed = false;
  XGrabKey(display, XKeysymToKeycode(display, kHotkeyKeysym), kHotkeyKeycodeMask,
           root, True, GrabModeAsync, GrabModeAsync);
  // Also grab for NumLock/CapsLock variants, the common blocker of global
  // hotkeys on X11.
  XGrabKey(display, XKeysymToKeycode(display, kHotkeyKeysym),
           kHotkeyKeycodeMask | LockMask, root, True, GrabModeAsync,
           GrabModeAsync);
  XSync(display, False);
  XSetErrorHandler(previous);
  g_state.hotkey_grabbed = !g_grab_failed;
}

// Watches the root window for the grabbed key. Because GDK does not expose
// root-window key events to us directly, run a small poll thread that checks
// the X event queue for KeyPress matching our hotkey.
gboolean poll_x_events(gpointer) {
  Display* display = g_state.display;
  if (display == nullptr) return G_SOURCE_CONTINUE;
  while (XPending(display) > 0) {
    XEvent event;
    XNextEvent(display, &event);
    if (event.type == KeyPress &&
        (event.xkey.state & (ControlMask | Mod1Mask)) ==
            (ControlMask | Mod1Mask) &&
        XLookupKeysym(&event.xkey, 0) == kHotkeyKeysym) {
      dispatch_hotkey(nullptr);
    }
  }
  return G_SOURCE_CONTINUE;
}

void send_key(Display* display, KeyCode keycode, bool up) {
  XTestFakeKeyEvent(display, keycode, up ? True : False, CurrentTime);
}

void press_keycode(Display* display, KeyCode keycode) {
  send_key(display, keycode, false);
  send_key(display, keycode, true);
  XSync(display, False);
}

void type_text(Display* display, const std::string& utf8) {
  // Decode UTF-8 into code points, map each to a keysym, then feed through
  // XTEST. Latin-1 characters use direct keysyms; everything else uses the
  // Unicode keysym range (0x1000000 + codepoint), which works with XIM/IBus
  // and most modern toolkits.
  size_t i = 0;
  while (i < utf8.size()) {
    unsigned int cp = static_cast<unsigned char>(utf8[i]);
    size_t extra;
    if (cp < 0x80) extra = 0;
    else if ((cp >> 5) == 0x6) { cp &= 0x1F; extra = 1; }
    else if ((cp >> 4) == 0xE) { cp &= 0x0F; extra = 2; }
    else if ((cp >> 3) == 0x1E) { cp &= 0x07; extra = 3; }
    else { i++; continue; }
    if (i + extra >= utf8.size()) { i++; continue; }
    bool valid = true;
    for (size_t k = 1; k <= extra; k++) {
      unsigned char c = static_cast<unsigned char>(utf8[i + k]);
      if ((c & 0xC0) != 0x80) { valid = false; break; }
      cp = (cp << 6) | (c & 0x3F);
    }
    if (!valid) { i++; continue; }
    i += extra + 1;

    KeySym keysym = cp <= 0xFF ? cp : 0x01000000 + cp;
    KeyCode keycode = XKeysymToKeycode(display, keysym);
    if (keycode == 0) continue;  // Not on the current keymap; skip.
    press_keycode(display, keycode);
  }
}

void press_named_key(Display* display, const std::string& key) {
  KeySym sym;
  if (key == "tab") sym = XK_Tab;
  else if (key == "enter") sym = XK_Return;
  else if (key == "space") sym = XK_space;
  else if (key == "up") sym = XK_Up;
  else if (key == "down") sym = XK_Down;
  else if (key == "left") sym = XK_Left;
  else if (key == "right") sym = XK_Right;
  else if (key == "home") sym = XK_Home;
  else if (key == "end") sym = XK_End;
  else if (key == "insert") sym = XK_Insert;
  else if (key == "delete") sym = XK_Delete;
  else if (key == "backspace") sym = XK_BackSpace;
  else if (key == "escape") sym = XK_Escape;
  else if (key == "pgup") sym = XK_Prior;
  else if (key == "pgdn") sym = XK_Next;
  else if (key == "add") sym = XK_plus;
  else if (key == "subtract") sym = XK_minus;
  else if (key == "multiply") sym = XK_asterisk;
  else if (key == "divide") sym = XK_slash;
  else return;
  KeyCode keycode = XKeysymToKeycode(display, sym);
  if (keycode == 0) return;
  press_keycode(display, keycode);
}

void clear_field(Display* display) {
  KeyCode ctrl = XKeysymToKeycode(display, XK_Control_L);
  KeyCode a = XKeysymToKeycode(display, XK_a);
  KeyCode del = XKeysymToKeycode(display, XK_Delete);
  if (ctrl == 0 || a == 0 || del == 0) return;
  send_key(display, ctrl, false);
  press_keycode(display, a);
  send_key(display, ctrl, true);
  XSync(display, False);
  press_keycode(display, del);
}

FlMethodResponse* handle_method_call(FlMethodCall* call) {
  const gchar* name = fl_method_call_get_name(call);
  FlValue* args = fl_method_call_get_args(call);

  if (g_strcmp0(name, "isHotkeyRegistered") == 0) {
    if (!g_state.x11) {
      // Wayland or no X display.
      FlValue* details = fl_value_new_string(
          "Wayland sessions do not allow global hotkeys or input injection");
      return FL_METHOD_RESPONSE(
          fl_method_error_response_new("unsupported", "wayland", details));
    }
    return FL_METHOD_RESPONSE(fl_method_success_response_new(
        fl_value_new_bool(g_state.hotkey_grabbed)));
  }

  if (!g_state.x11 || g_state.display == nullptr) {
    return FL_METHOD_RESPONSE(
        fl_method_error_response_new("unsupported", "wayland", nullptr));
  }

  if (g_strcmp0(name, "typeText") == 0) {
    if (fl_value_get_type(args) == FL_VALUE_TYPE_STRING) {
      type_text(g_state.display, fl_value_get_string(args));
    }
    return FL_METHOD_RESPONSE(fl_method_success_response_new(fl_value_new_bool(TRUE)));
  }
  if (g_strcmp0(name, "pressKey") == 0) {
    if (fl_value_get_type(args) == FL_VALUE_TYPE_STRING) {
      press_named_key(g_state.display, fl_value_get_string(args));
    }
    return FL_METHOD_RESPONSE(fl_method_success_response_new(fl_value_new_bool(TRUE)));
  }
  if (g_strcmp0(name, "clearField") == 0) {
    clear_field(g_state.display);
    return FL_METHOD_RESPONSE(fl_method_success_response_new(fl_value_new_bool(TRUE)));
  }

  return FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
}

void method_call_cb(FlMethodChannel* channel, FlMethodCall* call,
                    gpointer) {
  FlMethodResponse* response = handle_method_call(call);
  fl_method_call_respond(call, response, nullptr);
  g_object_unref(response);
}

}  // namespace

void register_autotype_channel(FlBinaryMessenger* messenger) {
  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  g_state.channel = fl_method_channel_new(messenger, kChannelName,
                                          FL_METHOD_CODEC(codec));

  // Detect the session type: X11 via GDK, Wayland otherwise.
  GdkDisplay* gdk_display = gdk_display_get_default();
  gboolean is_x11 = gdk_display != nullptr &&
                    GDK_IS_X11_DISPLAY(gdk_display);
  if (is_x11) {
    g_state.display = GDK_DISPLAY_XDISPLAY(gdk_display);
    g_state.root = DefaultRootWindow(g_state.display);
    g_state.x11 = true;
    bind_hotkey_to_glib();
    // Poll the dedicated X connection for root-window key grabs. A 40ms
    // interval is cheap and keeps hotkey latency imperceptible.
    g_timeout_add(40, poll_x_events, nullptr);
  } else {
    g_state.x11 = false;
  }

  fl_method_channel_set_method_call_handler(g_state.channel, method_call_cb,
                                            nullptr, nullptr);
}
