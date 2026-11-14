import SwiftUI

@main
struct PPLApp: App {
    @StateObject private var store = Store()
    @StateObject private var hr = HeartRateManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .environmentObject(hr)
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var hr: HeartRateManager
    @State private var tab = UserDefaults.standard.integer(forKey: "screenTab")

    var body: some View {
        TabView(selection: $tab) {
            WorkoutView()
                .tabItem { Label("Antrenman", systemImage: "figure.strengthtraining.traditional") }
                .tag(0)
            HistoryView()
                .tabItem { Label("Geçmiş", systemImage: "chart.xyaxis.line") }
                .tag(1)
            ProgramView()
                .tabItem { Label("Program", systemImage: "list.bullet.rectangle") }
                .tag(2)
        }
        .onChange(of: hr.running) { _, running in
            UIApplication.shared.isIdleTimerDisabled = running
        }
    }
}

func hideKeyboard() {
    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
}

extension Array {
    subscript(safe i: Int) -> Element? { indices.contains(i) ? self[i] : nil }
}
