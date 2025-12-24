import Foundation
import SwiftData

@Model
final class Chapter {
    @Attribute(.unique) var id: String
    var title: String
    var number: Double
    var volume: Int?
    var releaseDate: Date
    var isRead: Bool
    var isDownloaded: Bool
    var pageCount: Int
    var scanlator: String?
    var externalURL: String?

    var manga: Manga?

    var displayTitle: String {
        if title.isEmpty {
            return "Chapter \(formattedNumber)"
        }
        return "Ch. \(formattedNumber) - \(title)"
    }

    var formattedNumber: String {
        if number.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", number)
        }
        return String(format: "%.1f", number)
    }

    var relativeDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: releaseDate, relativeTo: .now)
    }

    init(
        id: String = UUID().uuidString,
        title: String = "",
        number: Double,
        volume: Int? = nil,
        releaseDate: Date = .now,
        isRead: Bool = false,
        isDownloaded: Bool = false,
        pageCount: Int = 0,
        scanlator: String? = nil,
        externalURL: String? = nil
    ) {
        self.id = id
        self.title = title
        self.number = number
        self.volume = volume
        self.releaseDate = releaseDate
        self.isRead = isRead
        self.isDownloaded = isDownloaded
        self.pageCount = pageCount
        self.scanlator = scanlator
        self.externalURL = externalURL
    }
}
