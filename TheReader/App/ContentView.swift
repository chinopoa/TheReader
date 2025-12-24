import SwiftUI

struct ContentView: View {
    @State private var selectedTab: TabItem = .library
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch selectedTab {
                case .library:
                    LibraryView()
                case .updates:
                    UpdatesView()
                case .browse:
                    BrowseView()
                case .history:
                    HistoryView()
                case .settings:
                    SettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            FloatingTabBar(selectedTab: $selectedTab)
                .padding(.bottom, 8)
        }
        .background(themeManager.backgroundColor)
        .ignoresSafeArea(.keyboard)
    }
}

enum TabItem: String, CaseIterable {
    case library = "Library"
    case updates = "Updates"
    case browse = "Browse"
    case history = "History"
    case settings = "Settings"

    var icon: String {
        switch self {
        case .library: return "books.vertical.fill"
        case .updates: return "bell.fill"
        case .browse: return "magnifyingglass"
        case .history: return "clock.fill"
        case .settings: return "gearshape.fill"
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(ThemeManager())
}
