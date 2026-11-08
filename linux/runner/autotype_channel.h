#ifndef RUNNER_AUTOTYPE_CHANNEL_H_
#define RUNNER_AUTOTYPE_CHANNEL_H_

#include <flutter_linux/flutter_linux.h>

G_BEGIN_DECLS

// Registers the "keestone/autotype" method channel on Linux.
//
// X11: binds Ctrl+Alt+A via XGrabKey on the root window, types with XTEST
// FakeInput events and reports hotkey presses back to Dart.
// Wayland: input injection and global grabs are not permitted by the
// protocol; the channel still registers so Dart can query availability and
// report the limitation in settings.
void register_autotype_channel(FlBinaryMessenger* messenger);

G_END_DECLS

#endif  // RUNNER_AUTOTYPE_CHANNEL_H_
