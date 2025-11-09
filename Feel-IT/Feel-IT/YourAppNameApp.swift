import SwiftUI

@main
struct YourAppNameApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    init() {
        // --- NEW: Load the sound store once when the app boots ---
        SoundStore.shared.loadSelection()
    }

    var body: some Scene {
        WindowGroup {
            // --- CHANGED: Load the new HomeView ---
            HomeView()
        }
    }
}
