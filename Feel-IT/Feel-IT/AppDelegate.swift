import UIKit

// Not an entry point. Just a helper bridged into SwiftUI.
final class AppDelegate: NSObject, UIApplicationDelegate {

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        // init stuff if you need it (logging, permissions priming, etc.)
        return true
    }
}
