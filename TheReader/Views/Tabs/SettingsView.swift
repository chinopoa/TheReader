import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.colorScheme) var colorScheme

    @State private var showingClearCacheAlert = false
    @State private var showingClearDownloadsAlert = false
    @State private var cacheSize: String = "Calculating..."
    @State private var downloadSize: String = "Calculating..."

    var body: some View {
        NavigationStack {
            List {
                appearanceSection
                storageSection
                readerSection
                aboutSection
            }
            .scrollContentBackground(.hidden)
            .background(themeManager.backgroundColor)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                calculateStorageSizes()
            }
        }
        .tint(.blue)
    }

    private var appearanceSection: some View {
        Section {
            ForEach(AppTheme.allCases, id: \.self) { theme in
                ThemeOptionRow(
                    theme: theme,
                    isSelected: themeManager.currentTheme == theme
                ) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        themeManager.currentTheme = theme
                    }
                }
            }
        } header: {
            Label("Appearance", systemImage: "paintbrush.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
        } footer: {
            Text("Choose how TheReader looks. System follows your device settings.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
    }

    private var storageSection: some View {
        Section {
            Button {
                showingClearCacheAlert = true
            } label: {
                HStack {
                    Label("Clear Image Cache", systemImage: "photo.stack")
                    Spacer()
                    Text(cacheSize)
                        .foregroundStyle(.secondary)
                }
            }
            .foregroundStyle(colorScheme == .dark ? .white : .black)
            .alert("Clear Image Cache", isPresented: $showingClearCacheAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Clear", role: .destructive) {
                    clearImageCache()
                }
            } message: {
                Text("This will remove all cached images. They will be downloaded again when needed.")
            }

            Button {
                showingClearDownloadsAlert = true
            } label: {
                HStack {
                    Label("Clear All Downloads", systemImage: "arrow.down.circle")
                    Spacer()
                    Text(downloadSize)
                        .foregroundStyle(.secondary)
                }
            }
            .foregroundStyle(colorScheme == .dark ? .white : .black)
            .alert("Clear All Downloads", isPresented: $showingClearDownloadsAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Delete All", role: .destructive) {
                    clearAllDownloads()
                }
            } message: {
                Text("This will delete all downloaded chapters. You'll need to download them again for offline reading.")
            }
        } header: {
            Label("Storage", systemImage: "internaldrive.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
        }
    }

    private var readerSection: some View {
        Section {
            NavigationLink {
                ReaderSettingsView()
            } label: {
                Label("Reader Settings", systemImage: "book.fill")
            }

            NavigationLink {
                DefaultsSettingsView()
            } label: {
                Label("Default Reading Mode", systemImage: "rectangle.split.2x1")
            }
        } header: {
            Label("Reader", systemImage: "book.closed.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
        }
    }

    private var aboutSection: some View {
        Section {
            HStack {
                Label("Version", systemImage: "info.circle")
                Spacer()
                Text("1.0.0")
                    .foregroundStyle(.secondary)
            }

            Link(destination: URL(string: "https://github.com/TheReader")!) {
                Label("GitHub", systemImage: "link")
            }
        } header: {
            Label("About", systemImage: "questionmark.circle.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
        }
    }

    private func calculateStorageSizes() {
        Task {
            cacheSize = await DownloadManager.shared.getCacheSize()
            downloadSize = await DownloadManager.shared.getDownloadSize()
        }
    }

    private func clearImageCache() {
        Task {
            await DownloadManager.shared.clearImageCache()
            cacheSize = "0 MB"
        }
    }

    private func clearAllDownloads() {
        Task {
            await DownloadManager.shared.clearAllDownloads()
            downloadSize = "0 MB"
        }
    }
}

struct ThemeOptionRow: View {
    let theme: AppTheme
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(themeBackground)
                        .frame(width: 36, height: 36)

                    Image(systemName: theme.icon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(themeIconColor)
                }

                Text(theme.rawValue)
                    .font(.system(size: 16))
                    .foregroundStyle(colorScheme == .dark ? .white : .black)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(.blue)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var themeBackground: Color {
        switch theme {
        case .system:
            return Color.gray.opacity(0.2)
        case .light:
            return Color.yellow.opacity(0.2)
        case .dark:
            return Color.indigo.opacity(0.2)
        }
    }

    private var themeIconColor: Color {
        switch theme {
        case .system:
            return .gray
        case .light:
            return .orange
        case .dark:
            return .indigo
        }
    }
}

struct ReaderSettingsView: View {
    @AppStorage("keepScreenOn") private var keepScreenOn = true
    @AppStorage("showPageNumber") private var showPageNumber = true
    @AppStorage("tapToNavigate") private var tapToNavigate = true
    @AppStorage("backgroundColor") private var backgroundColor = 0

    var body: some View {
        List {
            Section {
                Toggle("Keep Screen On", isOn: $keepScreenOn)
                Toggle("Show Page Number", isOn: $showPageNumber)
                Toggle("Tap to Navigate", isOn: $tapToNavigate)
            } header: {
                Text("Behavior")
            }

            Section {
                Picker("Background Color", selection: $backgroundColor) {
                    Text("Black").tag(0)
                    Text("White").tag(1)
                    Text("Sepia").tag(2)
                }
            } header: {
                Text("Appearance")
            }
        }
        .navigationTitle("Reader Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct DefaultsSettingsView: View {
    @AppStorage("defaultReadingMode") private var defaultReadingMode = 0

    var body: some View {
        List {
            Section {
                Picker("Default Mode", selection: $defaultReadingMode) {
                    Text("Webtoon (Vertical)").tag(0)
                    Text("Manga (Horizontal)").tag(1)
                }
                .pickerStyle(.inline)
                .labelsHidden()
            } footer: {
                Text("This setting determines the default reading mode for new manga. Individual manga will remember their preferred mode.")
            }
        }
        .navigationTitle("Default Reading Mode")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    SettingsView()
        .environmentObject(ThemeManager())
}
