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

    var body: some View {
        TabView {
            WorkoutView()
                .tabItem { Label("Antrenman", systemImage: "figure.strengthtraining.traditional") }
            HistoryView()
                .tabItem { Label("Geçmiş", systemImage: "chart.xyaxis.line") }
            ProgramView()
                .tabItem { Label("Program", systemImage: "list.bullet.rectangle") }
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
