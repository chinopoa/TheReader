import SwiftUI
import SwiftData

struct UpdatesView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var themeManager: ThemeManager

    @Query(filter: #Predicate<Manga> { $0.isFollowed })
    private var followedManga: [Manga]

    @State private var isRefreshing = false
    @State private var selectedChapter: (manga: Manga, chapter: Chapter)?

    private var recentChapters: [(manga: Manga, chapter: Chapter)] {
        var updates: [(manga: Manga, chapter: Chapter)] = []

        for manga in followedManga {
            for chapter in manga.chapters {
                updates.append((manga: manga, chapter: chapter))
            }
        }

        return updates.sorted { $0.chapter.releaseDate > $1.chapter.releaseDate }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                if recentChapters.isEmpty {
                    EmptyUpdatesView()
                } else {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(recentChapters.enumerated()), id: \.element.chapter.id) { index, update in
                            NavigationLink {
                                ReaderView(
                                    manga: update.manga,
                                    chapter: update.chapter
                                )
                            } label: {
                                UpdateRowView(
                                    manga: update.manga,
                                    chapter: update.chapter
                                )
                            }
                            .buttonStyle(.plain)

                            if index < recentChapters.count - 1 {
                                Divider()
                                    .padding(.leading, 88)
                            }
                        }
                    }
                    .padding(.bottom, 100)
                }
            }
            .background(themeManager.backgroundColor)
            .navigationTitle("Updates")
            .navigationBarTitleDisplayMode(.large)
            .refreshable {
                await refreshUpdates()
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await refreshUpdates() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 16, weight: .medium))
                            .rotationEffect(.degrees(isRefreshing ? 360 : 0))
                            .animation(isRefreshing ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: isRefreshing)
                    }
                    .disabled(isRefreshing)
                }
            }
        }
        .tint(.blue)
    }

    private func refreshUpdates() async {
        isRefreshing = true
        try? await Task.sleep(for: .seconds(1.5))
        isRefreshing = false
    }
}

struct UpdateRowView: View {
    let manga: Manga
    let chapter: Chapter
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

                Text(chapter.displayTitle)
                    .font(.system(size: 14))
                    .foregroundStyle(chapter.isRead ? .secondary : .blue)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Text(chapter.relativeDate)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)

                    if let scanlator = chapter.scanlator {
                        Text("•")
                            .foregroundStyle(.secondary)
                        Text(scanlator)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }

            Spacer()

            if !chapter.isRead {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 8, height: 8)
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}

struct EmptyUpdatesView: View {
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "bell.slash")
                .font(.system(size: 64))
                .foregroundStyle(.tertiary)

            Text("No Updates")
                .font(.title2.bold())
                .foregroundStyle(colorScheme == .dark ? .white : .black)

            Text("Pull down to check for new chapters from your library.")
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
    UpdatesView()
        .environmentObject(ThemeManager())
        .modelContainer(for: [Manga.self, Chapter.self])
}
