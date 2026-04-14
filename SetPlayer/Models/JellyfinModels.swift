import Foundation

struct QueueEntry: Identifiable, Codable {
    let id = UUID()
    let item: JellyfinItem
    let streamURL: URL
    let imageURL: URL?
}

struct JellyfinItem: Identifiable, Hashable, Codable {
    let id: String
    let name: String
    let year: Int?
    let overview: String?
    let runtime: Int? // minutes
    let premiereDate: Date?
    let genres: [String]
    let tags: [String]
    let studios: [String]
    let people: [JellyfinPerson]
    let chapters: [JellyfinChapter]
    let imageTags: [String: String]
    let serverId: String?

    var artist: String {
        let parts = name.split(separator: " - ", maxSplits: 1)
        return parts.count == 2 ? String(parts[0]) : name
    }

    var festival: String {
        let parts = name.split(separator: " - ", maxSplits: 1)
        return parts.count == 2 ? String(parts[1]) : ""
    }
}

struct JellyfinChapter: Identifiable, Hashable, Codable {
    let id = UUID()
    let startTicks: Int64
    let name: String
    let imageTag: String?

    var startSeconds: Double {
        Double(startTicks) / 10_000_000
    }

    var startFormatted: String {
        let total = Int(startSeconds)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%d:%02d", m, s)
    }
}

struct JellyfinPerson: Hashable, Codable {
    let name: String
    let role: String?
}

struct JellyfinCollection: Identifiable, Hashable, Codable {
    let id: String
    let name: String
}
