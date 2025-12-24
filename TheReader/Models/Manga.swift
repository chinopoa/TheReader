import Foundation
import SwiftData

@Model
final class Manga {
    @Attribute(.unique) var id: String
    var title: String
    var author: String
    var artist: String
    var status: MangaStatus
    var synopsis: String
    var coverURL: String?
    var source: MangaSource
    var genres: [String]
    var lastUpdated: Date
    var isFollowed: Bool
    var rating: Double?

    @Relationship(deleteRule: .cascade, inverse: \Chapter.manga)
    var chapters: [Chapter] = []

    var unreadCount: Int {
        chapters.filter { !$0.isRead }.count
    }

    var latestChapter: Chapter? {
        chapters.sorted { $0.number > $1.number }.first
    }

    init(
        id: String = UUID().uuidString,
        title: String,
        author: String = "Unknown",
        artist: String = "Unknown",
        status: MangaStatus = .ongoing,
        synopsis: String = "",
        coverURL: String? = nil,
        source: MangaSource = .mangadex,
        genres: [String] = [],
        lastUpdated: Date = .now,
        isFollowed: Bool = false,
        rating: Double? = nil
    ) {
        self.id = id
        self.title = title
        self.author = author
        self.artist = artist
        self.status = status
        self.synopsis = synopsis
        self.coverURL = coverURL
        self.source = source
        self.genres = genres
        self.lastUpdated = lastUpdated
        self.isFollowed = isFollowed
        self.rating = rating
    }
}

enum MangaStatus: String, Codable, CaseIterable {
    case ongoing = "Ongoing"
    case completed = "Completed"
    case hiatus = "Hiatus"
    case cancelled = "Cancelled"

    var color: String {
        switch self {
        case .ongoing: return "green"
        case .completed: return "blue"
        case .hiatus: return "orange"
        case .cancelled: return "red"
        }
    }
}

enum MangaSource: String, Codable, CaseIterable {
    case mangadex = "MangaDex"
    case mangakakalot = "Mangakakalot"
    case webtoons = "Webtoons"
    case asurascans = "Asura Scans"

    var iconName: String {
        switch self {
        case .mangadex: return "book.fill"
        case .mangakakalot: return "book.closed.fill"
        case .webtoons: return "scroll.fill"
        case .asurascans: return "flame.fill"
        }
    }
}
