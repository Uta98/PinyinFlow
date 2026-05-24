import GoogleMobileAds
import SwiftUI

@main
struct ChineseVideoTutorApp: App {
    init() {
        MobileAds.shared.start()
    }

    var body: some Scene {
        WindowGroup {
            AppView()
        }
    }
}
