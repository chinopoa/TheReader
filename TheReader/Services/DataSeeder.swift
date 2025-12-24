import Foundation
import SwiftData

@MainActor
final class DataSeeder {
    static func seedIfNeeded(modelContext: ModelContext) {
        let descriptor = FetchDescriptor<Manga>()
        guard let count = try? modelContext.fetchCount(descriptor), count == 0 else {
            return
        }

        let sampleManga = createSampleManga()
        for manga in sampleManga {
            modelContext.insert(manga)
        }

        try? modelContext.save()
    }

    private static func createSampleManga() -> [Manga] {
        let soloLeveling = Manga(
            title: "Solo Leveling",
            author: "Chugong",
            artist: "DUBU",
            status: .completed,
            synopsis: "In a world where hunters — humans who possess magical abilities — must battle deadly monsters to protect the human race from certain annihilation, a notoriously weak hunter named Sung Jinwoo finds himself in a seemingly endless struggle for survival. One day, after a brutal encounter in an overpowered dungeon wipes out his party and leaves him critically wounded, a mysterious program called the System chooses him as its sole player.",
            coverURL: "https://uploads.mangadex.org/covers/32d76d19-8a05-4db0-9fc2-e0b0648fe9d0/e90bdc47-c8b9-4df7-b2c0-17641b645ee1.jpg",
            source: .mangadex,
            genres: ["Action", "Adventure", "Fantasy", "Supernatural"],
            isFollowed: true,
            rating: 9.2
        )

        let soloChapters = (1...179).map { num in
            Chapter(
                title: num == 1 ? "E-Rank Hunter" : "",
                number: Double(num),
                releaseDate: Date().addingTimeInterval(-Double(179 - num) * 86400 * 3),
                isRead: num <= 50,
                pageCount: Int.random(in: 22...38),
                scanlator: "Official"
            )
        }
        for chapter in soloChapters {
            chapter.manga = soloLeveling
        }
        soloLeveling.chapters = soloChapters

        let towerOfGod = Manga(
            title: "Tower of God",
            author: "SIU",
            status: .ongoing,
            synopsis: "What do you desire? Money and wealth? Honor and pride? Authority and power? Revenge? Or something that transcends them all? Whatever you desire—it's here. Tower of God follows the story of Twenty-Fifth Bam, a young boy who spent most of his life trapped beneath a mysterious tower.",
            coverURL: "https://uploads.mangadex.org/covers/towerofgod/cover.jpg",
            source: .webtoons,
            genres: ["Action", "Adventure", "Fantasy", "Drama"],
            isFollowed: true,
            rating: 8.9
        )

        let togChapters = (1...550).map { num in
            Chapter(
                number: Double(num),
                releaseDate: Date().addingTimeInterval(-Double(550 - num) * 86400 * 7),
                isRead: num <= 200,
                pageCount: Int.random(in: 40...80),
                scanlator: "LINE Webtoon"
            )
        }
        for chapter in togChapters {
            chapter.manga = towerOfGod
        }
        towerOfGod.chapters = togChapters

        let omniscient = Manga(
            title: "Omniscient Reader's Viewpoint",
            author: "Sing Shong",
            status: .ongoing,
            synopsis: "Dokja was an average office worker whose sole hobby was reading his favorite web novel 'Three Ways to Survive the Apocalypse.' But when the novel suddenly becomes reality, he is the only person who knows the ending.",
            coverURL: "https://uploads.mangadex.org/covers/orv/cover.jpg",
            source: .asurascans,
            genres: ["Action", "Adventure", "Fantasy", "Drama"],
            isFollowed: true,
            rating: 9.1
        )

        let orvChapters = (1...180).map { num in
            Chapter(
                number: Double(num),
                releaseDate: Date().addingTimeInterval(-Double(180 - num) * 86400 * 4),
                isRead: num <= 100,
                pageCount: Int.random(in: 25...45),
                scanlator: "Asura Scans"
            )
        }
        for chapter in orvChapters {
            chapter.manga = omniscient
        }
        omniscient.chapters = orvChapters

        return [soloLeveling, towerOfGod, omniscient]
    }
}
