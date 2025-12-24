import Foundation
import SwiftData

@Model
final class HistoryItem {
    @Attribute(.unique) var id: String
    var mangaId: String
    var mangaTitle: String
    var mangaCoverURL: String?
    var chapterId: String
    var chapterNumber: Double
    var chapterTitle: String
    var lastReadPage: Int
    var totalPages: Int
    var lastReadDate: Date

    var progress: Double {
        guard totalPages > 0 else { return 0 }
        return Double(lastReadPage) / Double(totalPages)
    }

    var progressPercentage: Int {
        Int(progress * 100)
    }

    var formattedChapter: String {
        if chapterNumber.truncatingRemainder(dividingBy: 1) == 0 {
            return "Chapter \(Int(chapterNumber))"
        }
        return "Chapter \(String(format: "%.1f", chapterNumber))"
    }

    var relativeDate: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(lastReadDate) {
            return "Today"
        } else if calendar.isDateInYesterday(lastReadDate) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            return formatter.string(from: lastReadDate)
        }
    }

    init(
        id: String = UUID().uuidString,
        mangaId: String,
        mangaTitle: String,
        mangaCoverURL: String? = nil,
        chapterId: String,
        chapterNumber: Double,
        chapterTitle: String = "",
        lastReadPage: Int = 1,
        totalPages: Int = 1,
        lastReadDate: Date = .now
    ) {
        self.id = id
        self.mangaId = mangaId
        self.mangaTitle = mangaTitle
        self.mangaCoverURL = mangaCoverURL
        self.chapterId = chapterId
        self.chapterNumber = chapterNumber
        self.chapterTitle = chapterTitle
        self.lastReadPage = lastReadPage
        self.totalPages = totalPages
        self.lastReadDate = lastReadDate
    }
}
