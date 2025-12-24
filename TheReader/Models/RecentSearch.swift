import Foundation
import SwiftData

@Model
final class RecentSearch {
    @Attribute(.unique) var id: String
    var query: String
    var source: MangaSource
    var timestamp: Date

    init(
        id: String = UUID().uuidString,
        query: String,
        source: MangaSource = .mangadex,
        timestamp: Date = .now
    ) {
        self.id = id
        self.query = query
        self.source = source
        self.timestamp = timestamp
    }
}
