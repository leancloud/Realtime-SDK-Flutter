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
//            try LCApplication.default.set(
//                id: "s0g5kxj7ajtf6n2wt8fqty18p25gmvgrh7b430iuugsde212",
//                key: "hc7jpfubg5vaurjlezxhfr1t9pqb9w8tfw0puz1g83vl9nwz",
//                serverURL: "https://s0g5kxj7.lc-cn-n1-shared.com")
            GeneratedPluginRegistrant.register(with: self)
            return super.application(application, didFinishLaunchingWithOptions: launchOptions)
        } catch {
            fatalError("\(error)")
        }
    }
}
