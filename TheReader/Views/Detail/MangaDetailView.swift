import SwiftUI
import SwiftData

struct MangaDetailView: View {
    @Bindable var manga: Manga
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var themeManager: ThemeManager

    @State private var showingDescription = false
    @State private var selectedChapter: Chapter?
    @State private var sortAscending = false

    private var sortedChapters: [Chapter] {
        manga.chapters.sorted {
            sortAscending ? $0.number < $1.number : $0.number > $1.number
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                parallaxHeader

                VStack(alignment: .leading, spacing: 20) {
                    metadataSection
                    actionButtons
                    descriptionSection
                    chapterListSection
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 100)
            }
        }
        .background(themeManager.backgroundColor)
        .ignoresSafeArea(edges: .top)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(10)
                        .background(Circle().fill(.ultraThinMaterial))
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        manga.isFollowed.toggle()
                        try? modelContext.save()
                    } label: {
                        Label(
                            manga.isFollowed ? "Remove from Library" : "Add to Library",
                            systemImage: manga.isFollowed ? "bookmark.slash" : "bookmark"
                        )
                    }

                    Button {
                        // Share action
                    } label: {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(10)
                        .background(Circle().fill(.ultraThinMaterial))
                }
            }
        }
        .fullScreenCover(item: $selectedChapter) { chapter in
            ReaderView(manga: manga, chapter: chapter)
        }
    }

    private var parallaxHeader: some View {
        GeometryReader { geometry in
            let minY = geometry.frame(in: .global).minY
            let height = max(300, 300 + (minY > 0 ? minY : 0))

            ZStack(alignment: .bottom) {
                AsyncImageView(url: manga.coverURL)
                    .frame(width: geometry.size.width, height: height)
                    .clipped()
                    .offset(y: minY > 0 ? -minY : 0)

                LinearGradient(
                    colors: [
                        .clear,
                        themeManager.backgroundColor.opacity(0.5),
                        themeManager.backgroundColor
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        }
        .frame(height: 300)
    }

    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(manga.title)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(colorScheme == .dark ? .white : .black)

            HStack(spacing: 12) {
                Label(manga.author, systemImage: "person.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)

                StatusBadge(status: manga.status)

                if let rating = manga.rating {
                    HStack(spacing: 2) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.yellow)
                        Text(String(format: "%.1f", rating))
                            .font(.system(size: 14, weight: .medium))
                    }
                }
            }

            if !manga.genres.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(manga.genres, id: \.self) { genre in
                            Text(genre)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule()
                                        .fill(colorScheme == .dark
                                            ? Color.white.opacity(0.1)
                                            : Color.black.opacity(0.06))
                                )
                        }
                    }
                }
                .padding(.top, 4)
            }
        }
    }

    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button {
                if let firstUnread = sortedChapters.last(where: { !$0.isRead }) ?? sortedChapters.last {
                    selectedChapter = firstUnread
                }
            } label: {
                HStack {
                    Image(systemName: "book.fill")
                    Text("Start Reading")
                }
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.blue)
                )
            }

            Button {
                manga.isFollowed.toggle()
                try? modelContext.save()
            } label: {
                Image(systemName: manga.isFollowed ? "bookmark.fill" : "bookmark")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(manga.isFollowed ? .blue : (colorScheme == .dark ? .white : .black))
                    .frame(width: 52, height: 52)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(colorScheme == .dark
                                ? Color.white.opacity(0.1)
                                : Color.black.opacity(0.06))
                    )
            }
        }
    }

    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Synopsis")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(colorScheme == .dark ? .white : .black)

            Text(manga.synopsis)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .lineLimit(showingDescription ? nil : 4)

            if manga.synopsis.count > 200 {
                Button {
                    withAnimation {
                        showingDescription.toggle()
                    }
                } label: {
                    Text(showingDescription ? "Show Less" : "Show More")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.blue)
                }
            }
        }
    }

    private var chapterListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("\(manga.chapters.count) Chapters")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(colorScheme == .dark ? .white : .black)

                Spacer()

                Button {
                    withAnimation {
                        sortAscending.toggle()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: sortAscending ? "arrow.up" : "arrow.down")
                        Text(sortAscending ? "Oldest" : "Newest")
                    }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.blue)
                }
            }

            LazyVStack(spacing: 0) {
                ForEach(sortedChapters) { chapter in
                    ChapterRowView(
                        chapter: chapter,
                        onTap: {
                            selectedChapter = chapter
                        },
                        onDownload: {
                            downloadChapter(chapter)
                        }
                    )

                    if chapter.id != sortedChapters.last?.id {
                        Divider()
                            .padding(.leading, 16)
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(colorScheme == .dark
                        ? Color.white.opacity(0.05)
                        : Color.black.opacity(0.03))
            )
        }
    }

    private func downloadChapter(_ chapter: Chapter) {
        Task {
            await DownloadManager.shared.downloadChapter(chapter, manga: manga)
            chapter.isDownloaded = true
            try? modelContext.save()
        }
    }
}

struct ChapterRowView: View {
    let chapter: Chapter
    let onTap: () -> Void
    let onDownload: () -> Void

    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(chapter.displayTitle)
                        .font(.system(size: 15, weight: chapter.isRead ? .regular : .semibold))
                        .foregroundStyle(chapter.isRead
                            ? .secondary
                            : (colorScheme == .dark ? .white : .black))
                        .lineLimit(1)

                    HStack(spacing: 8) {
                        Text(chapter.relativeDate)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)

                        if let scanlator = chapter.scanlator {
                            Text("• \(scanlator)")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }

                Spacer()

                if chapter.isDownloaded {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.green)
                } else {
                    Button(action: onDownload) {
                        Image(systemName: "arrow.down.circle")
                            .font(.system(size: 18))
                            .foregroundStyle(.blue)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    let manga = Manga(
        title: "Solo Leveling",
        author: "Chugong",
        artist: "DUBU",
        status: .completed,
        synopsis: "In a world where hunters — humans who possess magical abilities — must battle deadly monsters to protect the human race from certain annihilation, a notoriously weak hunter named Sung Jinwoo finds himself in a seemingly endless struggle for survival.",
        coverURL: "https://uploads.mangadex.org/covers/32d76d19-8a05-4db0-9fc2-e0b0648fe9d0/e90bdc47-c8b9-4df7-b2c0-17641b645ee1.jpg",
        genres: ["Action", "Adventure", "Fantasy"],
        rating: 9.2
    )

    NavigationStack {
        MangaDetailView(manga: manga)
    }
    .environmentObject(ThemeManager())
}
