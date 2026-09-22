import SwiftUI
import SwiftData

@main
struct CookJotApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: Recipe.self)
    }
}
