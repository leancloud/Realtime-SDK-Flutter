import UIKit
import Flutter
import LeanCloud

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        do {
            LCApplication.logLevel = .all
            try LCApplication.default.set(
                id: "heQFQ0SwoQqiI3gEAcvKXjeR-gzGzoHsz",
                key: "lNSjPPPDohJjYMJcQSxi9qAm",
                serverURL: "https://heqfq0sw.lc-cn-n1-shared.com")
            GeneratedPluginRegistrant.register(with: self)
            return super.application(application, didFinishLaunchingWithOptions: launchOptions)
        } catch {
            fatalError("\(error)")
        }
    }
}
