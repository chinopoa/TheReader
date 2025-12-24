import SwiftUI
import SwiftData

struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var themeManager: ThemeManager

    @Query(sort: \HistoryItem.lastReadDate, order: .reverse)
    private var historyItems: [HistoryItem]

    @State private var showingClearAlert = false

    private var groupedHistory: [(String, [HistoryItem])] {
        let grouped = Dictionary(grouping: historyItems) { item in
            item.relativeDate
        }

        let order = ["Today", "Yesterday"]
        return grouped.sorted { pair1, pair2 in
            let index1 = order.firstIndex(of: pair1.key) ?? Int.max
            let index2 = order.firstIndex(of: pair2.key) ?? Int.max
            if index1 != index2 {
                return index1 < index2
            }
            return pair1.value.first?.lastReadDate ?? .distantPast > pair2.value.first?.lastReadDate ?? .distantPast
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                if historyItems.isEmpty {
                    EmptyHistoryView()
                } else {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(groupedHistory, id: \.0) { date, items in
                            Section {
                                ForEach(items) { item in
                                    HistoryRowView(item: item) {
                                        resumeReading(item)
                                    }

                                    if item.id != items.last?.id {
                                        Divider()
                                            .padding(.leading, 88)
                                    }
                                }
                            } header: {
                                Text(date)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(.secondary)
                                    .textCase(.uppercase)
                                    .padding(.horizontal, 16)
                                    .padding(.top, 20)
                                    .padding(.bottom, 8)
                            }
                        }
                    }
                    .padding(.bottom, 100)
                }
            }
            .background(themeManager.backgroundColor)
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                if !historyItems.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showingClearAlert = true
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 16))
                        }
                    }
                }
            }
            .alert("Clear History", isPresented: $showingClearAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Clear All", role: .destructive) {
                    clearAllHistory()
                }
            } message: {
                Text("This will remove all reading history. This action cannot be undone.")
            }
        }
        .tint(.blue)
    }

    private func resumeReading(_ item: HistoryItem) {
        // Navigate to reader with saved page
    }

    private func clearAllHistory() {
        for item in historyItems {
            modelContext.delete(item)
        }
        try? modelContext.save()
    }
}

struct HistoryRowView: View {
    let item: HistoryItem
    let onTap: () -> Void

    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                AsyncImageView(url: item.mangaCoverURL)
                    .frame(width: 64, height: 96)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 6) {
                    Text(item.mangaTitle)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(colorScheme == .dark ? .white : .black)
                        .lineLimit(2)

                    Text(item.formattedChapter)
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 4) {
                        ProgressView(value: item.progress)
                            .tint(.blue)

                        HStack {
                            Text("\(item.progressPercentage)% complete")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)

                            Spacer()

                            Text("Page \(item.lastReadPage)/\(item.totalPages)")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
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
        .buttonStyle(.plain)
    }
}

struct EmptyHistoryView: View {
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "clock")
                .font(.system(size: 64))
                .foregroundStyle(.tertiary)

            Text("No Reading History")
                .font(.title2.bold())
                .foregroundStyle(colorScheme == .dark ? .white : .black)

            Text("Manga you've read will appear here so you can easily continue where you left off.")
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
    HistoryView()
        .environmentObject(ThemeManager())
        .modelContainer(for: [HistoryItem.self])
}
