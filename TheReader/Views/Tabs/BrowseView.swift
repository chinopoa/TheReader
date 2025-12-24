import SwiftUI
import SwiftData

struct BrowseView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var themeManager: ThemeManager

    @Query(sort: \RecentSearch.timestamp, order: .reverse)
    private var recentSearches: [RecentSearch]

    @State private var searchText = ""
    @State private var isSearching = false
    @State private var selectedSource: MangaSource = .mangadex
    @State private var searchResults: [Manga] = []
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                sourceSelector

                if isSearching && searchText.isEmpty {
                    recentSearchesView
                } else if !searchResults.isEmpty {
                    searchResultsView
                } else if isLoading {
                    loadingView
                } else {
                    browseContent
                }
            }
            .background(themeManager.backgroundColor)
            .navigationTitle("Browse")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $searchText, isPresented: $isSearching, prompt: "Search \(selectedSource.rawValue)...")
            .onSubmit(of: .search) {
                performSearch()
            }
            .onChange(of: searchText) { _, newValue in
                if newValue.isEmpty {
                    searchResults = []
                }
            }
        }
        .tint(.blue)
    }

    private var sourceSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(MangaSource.allCases, id: \.self) { source in
                    SourceChip(
                        source: source,
                        isSelected: selectedSource == source
                    ) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedSource = source
                            if !searchText.isEmpty {
                                performSearch()
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    private var recentSearchesView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if !recentSearches.isEmpty {
                    HStack {
                        Text("Recent Searches")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)

                        Spacer()

                        Button("Clear All") {
                            clearAllRecentSearches()
                        }
                        .font(.system(size: 13))
                        .foregroundStyle(.blue)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                    ForEach(recentSearches) { search in
                        RecentSearchRow(search: search) {
                            searchText = search.query
                            selectedSource = search.source
                            performSearch()
                        } onDelete: {
                            deleteRecentSearch(search)
                        }
                    }
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 40))
                            .foregroundStyle(.tertiary)

                        Text("No Recent Searches")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 60)
                }
            }
            .padding(.bottom, 100)
        }
    }

    private var searchResultsView: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(searchResults) { manga in
                    NavigationLink {
                        MangaDetailView(manga: manga)
                    } label: {
                        SearchResultRow(manga: manga)
                    }
                    .buttonStyle(.plain)

                    Divider()
                        .padding(.leading, 88)
                }
            }
            .padding(.bottom, 100)
        }
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView()
                .scaleEffect(1.2)
            Text("Searching...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }

    private var browseContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Start searching to discover manga from \(selectedSource.rawValue)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 60)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 100)
        }
    }

    private func performSearch() {
        guard !searchText.trimmingCharacters(in: .whitespaces).isEmpty else { return }

        saveRecentSearch()
        isLoading = true

        Task {
            try? await Task.sleep(for: .seconds(1))
            await MainActor.run {
                searchResults = MangaService.shared.mockSearchResults(query: searchText)
                isLoading = false
            }
        }
    }

    private func saveRecentSearch() {
        let trimmedQuery = searchText.trimmingCharacters(in: .whitespaces)
        if let existing = recentSearches.first(where: {
            $0.query.lowercased() == trimmedQuery.lowercased() && $0.source == selectedSource
        }) {
            existing.timestamp = .now
        } else {
            let search = RecentSearch(query: trimmedQuery, source: selectedSource)
            modelContext.insert(search)
        }
        try? modelContext.save()
    }

    private func deleteRecentSearch(_ search: RecentSearch) {
        modelContext.delete(search)
        try? modelContext.save()
    }

    private func clearAllRecentSearches() {
        for search in recentSearches {
            modelContext.delete(search)
        }
        try? modelContext.save()
    }
}

struct SourceChip: View {
    let source: MangaSource
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: source.iconName)
                    .font(.system(size: 12, weight: .medium))
                Text(source.rawValue)
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundStyle(isSelected ? .white : (colorScheme == .dark ? .white : .black))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background {
                if isSelected {
                    Capsule()
                        .fill(Color.blue)
                } else {
                    Capsule()
                        .fill(colorScheme == .dark
                            ? Color.white.opacity(0.1)
                            : Color.black.opacity(0.06))
                }
            }
        }
        .buttonStyle(.plain)
    }
}

struct RecentSearchRow: View {
    let search: RecentSearch
    let onTap: () -> Void
    let onDelete: () -> Void

    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onTap) {
                HStack(spacing: 12) {
                    Image(systemName: "clock")
                        .font(.system(size: 16))
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(search.query)
                            .font(.system(size: 15))
                            .foregroundStyle(colorScheme == .dark ? .white : .black)

                        Text(search.source.rawValue)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                }
            }
            .buttonStyle(.plain)

            Button(action: onDelete) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(8)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}

struct SearchResultRow: View {
    let manga: Manga
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack(spacing: 12) {
            AsyncImageView(url: manga.coverURL)
                .frame(width: 64, height: 96)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(manga.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(colorScheme == .dark ? .white : .black)
                    .lineLimit(2)

                Text(manga.author)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    StatusBadge(status: manga.status)

                    if let rating = manga.rating {
                        HStack(spacing: 2) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(.yellow)
                            Text(String(format: "%.1f", rating))
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}

struct StatusBadge: View {
    let status: MangaStatus

    var color: Color {
        switch status {
        case .ongoing: return .green
        case .completed: return .blue
        case .hiatus: return .orange
        case .cancelled: return .red
        }
    }

    var body: some View {
        Text(status.rawValue)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                Capsule()
                    .fill(color.opacity(0.15))
            )
    }
}

#Preview {
    BrowseView()
        .environmentObject(ThemeManager())
        .modelContainer(for: [Manga.self, Chapter.self, RecentSearch.self])
}
