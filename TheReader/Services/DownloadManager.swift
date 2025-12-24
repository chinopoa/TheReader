import Foundation
import UIKit

actor DownloadManager {
    static let shared = DownloadManager()

    private let fileManager = FileManager.default
    private let downloadQueue = OperationQueue()

    private var documentsDirectory: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private var downloadsDirectory: URL {
        documentsDirectory.appendingPathComponent("Downloads", isDirectory: true)
    }

    private var cacheDirectory: URL {
        fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ImageCache", isDirectory: true)
    }

    private init() {
        downloadQueue.maxConcurrentOperationCount = 3
        createDirectoriesIfNeeded()
    }

    private func createDirectoriesIfNeeded() {
        try? fileManager.createDirectory(at: downloadsDirectory, withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }

    func downloadChapter(_ chapter: Chapter, manga: Manga) async {
        let mangaFolder = downloadsDirectory
            .appendingPathComponent(sanitizeFilename(manga.title), isDirectory: true)
        let chapterFolder = mangaFolder
            .appendingPathComponent("Chapter_\(chapter.formattedNumber)", isDirectory: true)

        try? fileManager.createDirectory(at: chapterFolder, withIntermediateDirectories: true)

        // Mock download - in real app, fetch actual page URLs from API
        let mockPages = (1...20).map { page in
            "https://example.com/manga/\(manga.id)/\(chapter.id)/\(page).jpg"
        }

        for (index, pageURL) in mockPages.enumerated() {
            guard let url = URL(string: pageURL) else { continue }

            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                let filename = String(format: "%03d.jpg", index + 1)
                let fileURL = chapterFolder.appendingPathComponent(filename)
                try data.write(to: fileURL)
            } catch {
                print("Failed to download page \(index + 1): \(error)")
            }
        }
    }

    func deleteChapter(_ chapter: Chapter, manga: Manga) async {
        let mangaFolder = downloadsDirectory
            .appendingPathComponent(sanitizeFilename(manga.title), isDirectory: true)
        let chapterFolder = mangaFolder
            .appendingPathComponent("Chapter_\(chapter.formattedNumber)", isDirectory: true)

        try? fileManager.removeItem(at: chapterFolder)

        // Clean up empty manga folder
        if let contents = try? fileManager.contentsOfDirectory(atPath: mangaFolder.path),
           contents.isEmpty {
            try? fileManager.removeItem(at: mangaFolder)
        }
    }

    func getDownloadedPages(for chapter: Chapter, manga: Manga) -> [URL] {
        let mangaFolder = downloadsDirectory
            .appendingPathComponent(sanitizeFilename(manga.title), isDirectory: true)
        let chapterFolder = mangaFolder
            .appendingPathComponent("Chapter_\(chapter.formattedNumber)", isDirectory: true)

        guard let contents = try? fileManager.contentsOfDirectory(
            at: chapterFolder,
            includingPropertiesForKeys: nil
        ) else {
            return []
        }

        return contents
            .filter { $0.pathExtension.lowercased() == "jpg" || $0.pathExtension.lowercased() == "png" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    func isChapterDownloaded(_ chapter: Chapter, manga: Manga) -> Bool {
        let pages = getDownloadedPages(for: chapter, manga: manga)
        return !pages.isEmpty
    }

    func getCacheSize() async -> String {
        return formatSize(directorySize(at: cacheDirectory))
    }

    func getDownloadSize() async -> String {
        return formatSize(directorySize(at: downloadsDirectory))
    }

    func clearImageCache() async {
        try? fileManager.removeItem(at: cacheDirectory)
        createDirectoriesIfNeeded()
    }

    func clearAllDownloads() async {
        try? fileManager.removeItem(at: downloadsDirectory)
        createDirectoriesIfNeeded()
    }

    private func directorySize(at url: URL) -> Int64 {
        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else {
            return 0
        }

        var totalSize: Int64 = 0
        for case let fileURL as URL in enumerator {
            guard let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
                  let fileSize = resourceValues.fileSize else {
                continue
            }
            totalSize += Int64(fileSize)
        }
        return totalSize
    }

    private func formatSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    private func sanitizeFilename(_ name: String) -> String {
        let invalidCharacters = CharacterSet(charactersIn: "\\/:*?\"<>|")
        return name.components(separatedBy: invalidCharacters).joined(separator: "_")
    }
}
