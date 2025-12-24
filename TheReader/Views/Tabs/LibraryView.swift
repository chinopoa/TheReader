import SwiftUI
import SwiftData

enum LibrarySortOption: String, CaseIterable {
    case title = "Title"
    case lastUpdated = "Last Updated"
    case lastRead = "Last Read"
    case unreadCount = "Unread"

    var icon: String {
        switch self {
        case .title: return "textformat.abc"
        case .lastUpdated: return "clock.arrow.circlepath"
        case .lastRead: return "book.fill"
        case .unreadCount: return "number.circle.fill"
        }
    }
}

struct LibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var themeManager: ThemeManager

    @Query(filter: #Predicate<Manga> { $0.isFollowed })
    private var followedManga: [Manga]

    @State private var sortOption: LibrarySortOption = .lastUpdated
    @State private var showingSortMenu = false
    @State private var searchText = ""
    @State private var isSearching = false
    @State private var selectedManga: Manga?

    private var sortedManga: [Manga] {
        let filtered = searchText.isEmpty
            ? followedManga
            : followedManga.filter { $0.title.localizedCaseInsensitiveContains(searchText) }

        return filtered.sorted { manga1, manga2 in
            switch sortOption {
            case .title:
                return manga1.title < manga2.title
            case .lastUpdated:
                return manga1.lastUpdated > manga2.lastUpdated
            case .lastRead:
                return manga1.lastUpdated > manga2.lastUpdated
            case .unreadCount:
                return manga1.unreadCount > manga2.unreadCount
            }
        }
    }

    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if sortedManga.isEmpty {
                        EmptyLibraryView()
                    } else {
                        LazyVGrid(columns: columns, spacing: 20) {
                            ForEach(sortedManga) { manga in
                                NavigationLink(value: manga) {
                                    MangaCoverItem(manga: manga)
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    mangaContextMenu(for: manga)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, 100)
            }
            .background(themeManager.backgroundColor)
            .navigationTitle("Library")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $searchText, prompt: "Search library...")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        ForEach(LibrarySortOption.allCases, id: \.self) { option in
                            Button {
                                withAnimation {
                                    sortOption = option
                                }
                            } label: {
                                Label(option.rawValue, systemImage: option.icon)
                                if sortOption == option {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "arrow.up.arrow.down.circle")
                            .font(.system(size: 18))
                            .foregroundStyle(colorScheme == .dark ? .white : .black)
                    }
                }
            }
            .navigationDestination(for: Manga.self) { manga in
                MangaDetailView(manga: manga)
            }
        }
        .tint(.blue)
    }

    @ViewBuilder
    private func mangaContextMenu(for manga: Manga) -> some View {
        Button {
            markAllAsRead(manga)
        } label: {
            Label("Mark All as Read", systemImage: "checkmark.circle.fill")
        }

        Button {
            markAllAsUnread(manga)
        } label: {
            Label("Mark All as Unread", systemImage: "circle")
        }

        Divider()

        Button(role: .destructive) {
            unfollowManga(manga)
        } label: {
            Label("Remove from Library", systemImage: "trash")
        }
    }

    private func markAllAsRead(_ manga: Manga) {
        for chapter in manga.chapters {
            chapter.isRead = true
        }
        try? modelContext.save()
    }

    private func markAllAsUnread(_ manga: Manga) {
        for chapter in manga.chapters {
            chapter.isRead = false
        }
        try? modelContext.save()
    }

    private func unfollowManga(_ manga: Manga) {
        manga.isFollowed = false
        try? modelContext.save()
    }
}

struct EmptyLibraryView: View {
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "books.vertical")
                .font(.system(size: 64))
                .foregroundStyle(.tertiary)

            Text("Your Library is Empty")
                .font(.title2.bold())
                .foregroundStyle(colorScheme == .dark ? .white : .black)

            Text("Start by browsing for manga and adding them to your library.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 100)
    }
}

#Preview {
    LibraryView()
        .environmentObject(ThemeManager())
        .modelContainer(for: [Manga.self, Chapter.self])
}
