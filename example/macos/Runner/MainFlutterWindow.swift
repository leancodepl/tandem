import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  private var appleFoundationModels: AppleFoundationModelsChannel?

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    appleFoundationModels = AppleFoundationModelsChannel(
      messenger: flutterViewController.engine.binaryMessenger
    )

    super.awakeFromNib()
  }
}
