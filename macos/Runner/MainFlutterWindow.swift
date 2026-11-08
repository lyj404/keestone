import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    // AutoType global hotkey + CGEvent typing (Ctrl+Alt+A).
    AutoTypeChannel.register(with: flutterViewController.engine.binaryMessenger)

    super.awakeFromNib()
  }
}
