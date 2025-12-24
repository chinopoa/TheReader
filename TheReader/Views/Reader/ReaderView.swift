import SwiftUI
import SwiftData

enum ReadingMode: String, CaseIterable {
    case webtoon = "Webtoon"
    case manga = "Manga"

    var icon: String {
        switch self {
        case .webtoon: return "arrow.up.arrow.down"
        case .manga: return "arrow.left.arrow.right"
        }
    }

    var description: String {
        switch self {
        case .webtoon: return "Vertical Scroll"
        case .manga: return "Horizontal (RTL)"
        }
    }
}

struct ReaderView: View {
    let manga: Manga
    @Bindable var chapter: Chapter

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var readingMode: ReadingMode = .webtoon
    @State private var currentPage: Int = 1
    @State private var showHUD = true
    @State private var showSettings = false

    @AppStorage("defaultReadingMode") private var defaultReadingMode = 0

    private let totalPages = 20

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            Group {
                switch readingMode {
                case .webtoon:
                    WebtoonReader(
                        currentPage: $currentPage,
                        totalPages: totalPages,
                        onTap: { toggleHUD() }
                    )
                case .manga:
                    MangaReader(
                        currentPage: $currentPage,
                        totalPages: totalPages,
                        onTap: { toggleHUD() }
                    )
                }
            }

            if showHUD {
                ReaderHUD(
                    chapterTitle: chapter.displayTitle,
                    mangaTitle: manga.title,
                    currentPage: currentPage,
                    totalPages: totalPages,
                    readingMode: $readingMode,
                    showSettings: $showSettings,
                    onDismiss: { saveProgressAndDismiss() },
                    onPreviousChapter: { goToPreviousChapter() },
                    onNextChapter: { goToNextChapter() },
                    onPageChange: { page in currentPage = page }
                )
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .statusBarHidden(!showHUD)
        .persistentSystemOverlays(showHUD ? .automatic : .hidden)
        .onAppear {
            readingMode = defaultReadingMode == 0 ? .webtoon : .manga
        }
        .onDisappear {
            saveProgress()
        }
        .sheet(isPresented: $showSettings) {
            ReaderSettingsSheet(readingMode: $readingMode)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
    }

    private func toggleHUD() {
        withAnimation(.easeInOut(duration: 0.2)) {
            showHUD.toggle()
        }
    }

    private func saveProgress() {
        chapter.isRead = currentPage >= totalPages

        let historyItem = HistoryItem(
            mangaId: manga.id,
            mangaTitle: manga.title,
            mangaCoverURL: manga.coverURL,
            chapterId: chapter.id,
            chapterNumber: chapter.number,
            chapterTitle: chapter.title,
            lastReadPage: currentPage,
            totalPages: totalPages
        )

        modelContext.insert(historyItem)
        try? modelContext.save()
    }

    private func saveProgressAndDismiss() {
        saveProgress()
        dismiss()
    }

    private func goToPreviousChapter() {
        guard let currentIndex = manga.chapters.firstIndex(where: { $0.id == chapter.id }),
              currentIndex > 0 else { return }
        // Would navigate to previous chapter
    }

    private func goToNextChapter() {
        guard let currentIndex = manga.chapters.firstIndex(where: { $0.id == chapter.id }),
              currentIndex < manga.chapters.count - 1 else { return }
        // Would navigate to next chapter
    }
}

struct WebtoonReader: View {
    @Binding var currentPage: Int
    let totalPages: Int
    let onTap: () -> Void

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(1...totalPages, id: \.self) { page in
                        MockPageView(pageNumber: page, isWebtoon: true)
                            .id(page)
                    }
                }
            }
            .scrollIndicators(.hidden)
            .onTapGesture(perform: onTap)
            .onChange(of: currentPage) { _, newPage in
                withAnimation {
                    proxy.scrollTo(newPage, anchor: .top)
                }
            }
        }
    }
}

struct MangaReader: View {
    @Binding var currentPage: Int
    let totalPages: Int
    let onTap: () -> Void

    var body: some View {
        TabView(selection: $currentPage) {
            ForEach((1...totalPages).reversed(), id: \.self) { page in
                MockPageView(pageNumber: page, isWebtoon: false)
                    .tag(page)
                    .onTapGesture(perform: onTap)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .environment(\.layoutDirection, .rightToLeft)
    }
}

struct MockPageView: View {
    let pageNumber: Int
    let isWebtoon: Bool

    private var gradientColors: [Color] {
        let hue = Double(pageNumber % 10) / 10.0
        return [
            Color(hue: hue, saturation: 0.3, brightness: 0.2),
            Color(hue: hue + 0.1, saturation: 0.4, brightness: 0.15)
        ]
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                LinearGradient(
                    colors: gradientColors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                VStack(spacing: 8) {
                    Text("Page \(pageNumber)")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(.white.opacity(0.8))

                    Text("Swipe to navigate")
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
            .frame(
                width: geometry.size.width,
                height: isWebtoon ? geometry.size.width * 1.5 : geometry.size.height
            )
        }
        .frame(height: isWebtoon ? nil : UIScreen.main.bounds.height)
    }
}

struct ReaderHUD: View {
    let chapterTitle: String
    let mangaTitle: String
    let currentPage: Int
    let totalPages: Int
    @Binding var readingMode: ReadingMode
    @Binding var showSettings: Bool
    let onDismiss: () -> Void
    let onPreviousChapter: () -> Void
    let onNextChapter: () -> Void
    let onPageChange: (Int) -> Void

    @State private var sliderValue: Double = 1

    var body: some View {
        VStack {
            topBar
            Spacer()
            bottomBar
        }
    }

    private var topBar: some View {
        HStack(spacing: 16) {
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(mangaTitle)
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(1)

                Text(chapterTitle)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
            }

            Spacer()

            Button {
                showSettings = true
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(.white)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .padding(.top, 44)
        .background(
            LinearGradient(
                colors: [.black.opacity(0.8), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private var bottomBar: some View {
        VStack(spacing: 16) {
            HStack(spacing: 20) {
                Button(action: onPreviousChapter) {
                    Image(systemName: "chevron.left.2")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(.white)
                }

                Slider(
                    value: $sliderValue,
                    in: 1...Double(totalPages),
                    step: 1
                ) { editing in
                    if !editing {
                        onPageChange(Int(sliderValue))
                    }
                }
                .tint(.white)
                .onChange(of: currentPage) { _, newValue in
                    sliderValue = Double(newValue)
                }
                .onAppear {
                    sliderValue = Double(currentPage)
                }

                Button(action: onNextChapter) {
                    Image(systemName: "chevron.right.2")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(.white)
                }
            }

            HStack {
                Text("Page \(currentPage) of \(totalPages)")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.8))

                Spacer()

                HStack(spacing: 4) {
                    Image(systemName: readingMode.icon)
                    Text(readingMode.description)
                }
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.6))
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .padding(.bottom, 24)
        .background(
            LinearGradient(
                colors: [.clear, .black.opacity(0.8)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
}

struct ReaderSettingsSheet: View {
    @Binding var readingMode: ReadingMode
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(ReadingMode.allCases, id: \.self) { mode in
                        Button {
                            readingMode = mode
                            dismiss()
                        } label: {
                            HStack {
                                Image(systemName: mode.icon)
                                    .frame(width: 24)

                                VStack(alignment: .leading) {
                                    Text(mode.rawValue)
                                        .font(.system(size: 16, weight: .medium))
                                    Text(mode.description)
                                        .font(.system(size: 13))
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                if readingMode == mode {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.blue)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text("Reading Mode")
                }
            }
            .navigationTitle("Reader Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    let manga = Manga(title: "Solo Leveling", author: "Chugong")
    let chapter = Chapter(number: 1)

    return ReaderView(manga: manga, chapter: chapter)
        .modelContainer(for: [Manga.self, Chapter.self, HistoryItem.self])
}
