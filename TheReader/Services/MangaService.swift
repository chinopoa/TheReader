import Foundation

final class MangaService {
    static let shared = MangaService()

    private init() {}

    func mockSearchResults(query: String) -> [Manga] {
        let mockData: [(String, String, String, MangaStatus, Double?, String)] = [
            ("Solo Leveling", "Chugong", "In a world where hunters battle deadly monsters, a weak hunter named Sung Jinwoo finds himself in an endless struggle for survival.", .completed, 9.2, "https://uploads.mangadex.org/covers/32d76d19-8a05-4db0-9fc2-e0b0648fe9d0/e90bdc47-c8b9-4df7-b2c0-17641b645ee1.jpg"),
            ("One Piece", "Eiichiro Oda", "Monkey D. Luffy sets off on an adventure with his pirate crew to find the world's ultimate treasure known as One Piece.", .ongoing, 9.5, "https://uploads.mangadex.org/covers/a1c7c817-4e59-43b7-9365-09675a149a6f/2c9b7d4c-5d7f-4c0b-8c4e-3f7d8e9a0b1c.jpg"),
            ("Tower of God", "SIU", "A young boy enters a mysterious tower to find his best friend and must pass numerous challenges to climb higher.", .ongoing, 8.9, "https://uploads.mangadex.org/covers/tower-god/cover.jpg"),
            ("The Beginning After The End", "TurtleMe", "King Grey has unrivaled strength, wealth, and prestige in a world governed by martial ability. But solitude lingers closely behind those with great power.", .ongoing, 9.0, "https://uploads.mangadex.org/covers/tbate/cover.jpg"),
            ("Omniscient Reader's Viewpoint", "Sing Shong", "The world has become a web novel, and only the protagonist knows the ending.", .ongoing, 9.1, "https://uploads.mangadex.org/covers/orv/cover.jpg"),
            ("Demon Slayer", "Koyoharu Gotouge", "A kind-hearted boy joins the Demon Slayer Corps after his family is slaughtered and his sister is turned into a demon.", .completed, 8.8, "https://uploads.mangadex.org/covers/demon-slayer/cover.jpg"),
            ("Jujutsu Kaisen", "Gege Akutami", "A high school student joins a secret organization of sorcerers to kill a powerful curse.", .ongoing, 8.7, "https://uploads.mangadex.org/covers/jjk/cover.jpg"),
            ("Chainsaw Man", "Tatsuki Fujimoto", "Denji has a simple dream—to live a happy and peaceful life, spending time with a girl he likes. But a debt left behind by his father has left Denji stuck in poverty.", .ongoing, 8.9, "https://uploads.mangadex.org/covers/csm/cover.jpg")
        ]

        let filteredResults = mockData.filter {
            $0.0.localizedCaseInsensitiveContains(query) ||
            $0.1.localizedCaseInsensitiveContains(query)
        }

        return filteredResults.map { item in
            let manga = Manga(
                title: item.0,
                author: item.1,
                status: item.3,
                synopsis: item.2,
                coverURL: item.5,
                genres: ["Action", "Adventure", "Fantasy"],
                rating: item.4
            )

            let chapters = (1...50).map { num in
                Chapter(
                    number: Double(num),
                    releaseDate: Date().addingTimeInterval(-Double(num) * 86400 * 3),
                    pageCount: Int.random(in: 18...35)
                )
            }

            for chapter in chapters {
                chapter.manga = manga
            }
            manga.chapters = chapters

            return manga
        }
    }

    func fetchMangaDetails(id: String) async throws -> Manga {
        try await Task.sleep(for: .seconds(0.5))

        return Manga(
            id: id,
            title: "Solo Leveling",
            author: "Chugong",
            artist: "DUBU",
            status: .completed,
            synopsis: "In a world where hunters — humans who possess magical abilities — must battle deadly monsters to protect the human race from certain annihilation, a notoriously weak hunter named Sung Jinwoo finds himself in a seemingly endless struggle for survival. One day, after a brutal encounter in an overpowered dungeon wipes out his party and leaves him critically wounded, a mysterious program called the System chooses him as its sole player and gives him the extremely rare ability to level up in strength, possibly beyond any known limits.",
            coverURL: "https://uploads.mangadex.org/covers/32d76d19-8a05-4db0-9fc2-e0b0648fe9d0/e90bdc47-c8b9-4df7-b2c0-17641b645ee1.jpg",
            genres: ["Action", "Adventure", "Fantasy", "Supernatural"],
            rating: 9.2
        )
    }

    func fetchChapters(for mangaId: String) async throws -> [Chapter] {
        try await Task.sleep(for: .seconds(0.3))

        return (1...179).map { num in
            Chapter(
                number: Double(num),
                releaseDate: Date().addingTimeInterval(-Double(179 - num) * 86400 * 7),
                pageCount: Int.random(in: 20...40),
                scanlator: "Official"
            )
        }
    }

    func fetchChapterPages(chapterId: String) async throws -> [URL] {
        try await Task.sleep(for: .seconds(0.2))

        return (1...25).compactMap { page in
            URL(string: "https://example.com/chapters/\(chapterId)/\(page).jpg")
        }
    }
}
