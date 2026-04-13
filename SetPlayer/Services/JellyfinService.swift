import Foundation

@Observable
final class JellyfinService: @unchecked Sendable {
    let serverURL: String
    let apiKey: String
    let userId: String

    private let session = URLSession.shared
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    init(serverURL: String = "", apiKey: String = "", userId: String = "") {
        self.serverURL = serverURL
        self.apiKey = apiKey
        self.userId = userId
    }

    // MARK: - Library

    func fetchLibraryItems(parentId: String? = nil, searchTerm: String? = nil) async throws -> [JellyfinItem] {
        var components = urlComponents(path: "/Users/\(userId)/Items")
        var queryItems = [
            URLQueryItem(name: "Recursive", value: "true"),
            URLQueryItem(name: "Fields", value: "Overview,Genres,Tags,Studios,People,Chapters"),
            URLQueryItem(name: "SortBy", value: "SortName"),
            URLQueryItem(name: "SortOrder", value: "Ascending"),
            URLQueryItem(name: "IncludeItemTypes", value: "Movie"),
        ]
        if let parentId {
            queryItems.append(URLQueryItem(name: "ParentId", value: parentId))
        }
        if let searchTerm, !searchTerm.isEmpty {
            queryItems.append(URLQueryItem(name: "SearchTerm", value: searchTerm))
        }
        components.queryItems = queryItems
        let data = try await fetch(components)
        let response = try decoder.decode(ItemsResponse.self, from: data)
        return response.items.map { $0.toDomain(serverURL: serverURL, apiKey: apiKey) }
    }

    func fetchCollections() async throws -> [JellyfinCollection] {
        var components = urlComponents(path: "/Users/\(userId)/Items")
        components.queryItems = [
            URLQueryItem(name: "Recursive", value: "true"),
            URLQueryItem(name: "IncludeItemTypes", value: "BoxSet"),
        ]
        let data = try await fetch(components)
        let response = try decoder.decode(CollectionsResponse.self, from: data)
        return response.items.map { JellyfinCollection(id: $0.id, name: $0.name) }
    }

    func fetchCollectionItems(collectionId: String) async throws -> [JellyfinItem] {
        var components = urlComponents(path: "/Users/\(userId)/Items")
        components.queryItems = [
            URLQueryItem(name: "ParentId", value: collectionId),
            URLQueryItem(name: "Fields", value: "Overview,Genres,Tags,Studios,People,Chapters"),
            URLQueryItem(name: "SortBy", value: "ProductionYear,SortName"),
            URLQueryItem(name: "SortOrder", value: "Descending"),
        ]
        let data = try await fetch(components)
        let response = try decoder.decode(ItemsResponse.self, from: data)
        return response.items.map { $0.toDomain(serverURL: serverURL, apiKey: apiKey) }
    }

    func fetchRecentlyPlayed(limit: Int = 20) async throws -> [JellyfinItem] {
        var components = urlComponents(path: "/Users/\(userId)/Items")
        components.queryItems = (components.queryItems ?? []) + [
            URLQueryItem(name: "Recursive", value: "true"),
            URLQueryItem(name: "Fields", value: "Overview,Genres,Tags,Studios,People,Chapters"),
            URLQueryItem(name: "SortBy", value: "DatePlayed"),
            URLQueryItem(name: "SortOrder", value: "Descending"),
            URLQueryItem(name: "Filters", value: "IsPlayed"),
            URLQueryItem(name: "IncludeItemTypes", value: "Movie"),
            URLQueryItem(name: "Limit", value: "\(limit)"),
        ]
        let data = try await fetch(components)
        let response = try decoder.decode(ItemsResponse.self, from: data)
        return response.items.map { $0.toDomain(serverURL: serverURL, apiKey: apiKey) }
    }

    func fetchMostPlayed(limit: Int = 20) async throws -> [JellyfinItem] {
        var components = urlComponents(path: "/Users/\(userId)/Items")
        components.queryItems = (components.queryItems ?? []) + [
            URLQueryItem(name: "Recursive", value: "true"),
            URLQueryItem(name: "Fields", value: "Overview,Genres,Tags,Studios,People,Chapters"),
            URLQueryItem(name: "SortBy", value: "PlayCount"),
            URLQueryItem(name: "SortOrder", value: "Descending"),
            URLQueryItem(name: "Filters", value: "IsPlayed"),
            URLQueryItem(name: "IncludeItemTypes", value: "Movie"),
            URLQueryItem(name: "Limit", value: "\(limit)"),
        ]
        let data = try await fetch(components)
        let response = try decoder.decode(ItemsResponse.self, from: data)
        return response.items.map { $0.toDomain(serverURL: serverURL, apiKey: apiKey) }
    }

    // MARK: - Playback Reporting

    func reportPlaybackStart(itemId: String, positionTicks: Int64 = 0) async {
        let components = urlComponents(path: "/Sessions/Playing")
        try? await post(components, body: [
            "ItemId": itemId,
            "PositionTicks": positionTicks,
            "CanSeek": true,
            "MediaSourceId": itemId,
            "PlayMethod": "DirectStream",
        ])
    }

    func reportPlaybackProgress(itemId: String, positionTicks: Int64, isPaused: Bool) async {
        let components = urlComponents(path: "/Sessions/Playing/Progress")
        try? await post(components, body: [
            "ItemId": itemId,
            "PositionTicks": positionTicks,
            "IsPaused": isPaused,
            "CanSeek": true,
            "MediaSourceId": itemId,
            "PlayMethod": "DirectStream",
        ])
    }

    func reportPlaybackStopped(itemId: String, positionTicks: Int64) async {
        let components = urlComponents(path: "/Sessions/Playing/Stopped")
        try? await post(components, body: [
            "ItemId": itemId,
            "PositionTicks": positionTicks,
            "MediaSourceId": itemId,
        ])
    }

    // MARK: - URLs

    func streamURL(for itemId: String) -> URL? {
        var components = urlComponents(path: "/Videos/\(itemId)/stream.mp4")
        components.queryItems = [
            URLQueryItem(name: "Static", value: "true"),
        ]
        return components.url
    }

    func imageURL(for itemId: String, tag: String, maxWidth: Int = 400) -> URL? {
        var components = urlComponents(path: "/Items/\(itemId)/Images/Primary")
        components.queryItems = [
            URLQueryItem(name: "maxWidth", value: "\(maxWidth)"),
            URLQueryItem(name: "tag", value: tag),
        ]
        return components.url
    }

    func chapterImageURL(for itemId: String, chapterIndex: Int) -> URL? {
        var components = urlComponents(path: "/Items/\(itemId)/Images/Chapter/\(chapterIndex)")
        components.queryItems = [
            URLQueryItem(name: "maxWidth", value: "200"),
        ]
        return components.url
    }

    // MARK: - Authentication

    static func authenticate(serverURL: String, username: String, password: String) async throws -> ServerConfig {
        guard var components = URLComponents(string: serverURL) else {
            throw JellyfinError.invalidURL
        }
        components.path = "/Users/AuthenticateByName"

        guard let url = components.url else {
            throw JellyfinError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let deviceId = Host.current().localizedName ?? "macOS"
        let authHeader = "MediaBrowser Client=\"SetPlayer\", Device=\"macOS\", DeviceId=\"\(deviceId)\", Version=\"1.0\""
        request.setValue(authHeader, forHTTPHeaderField: "X-Emby-Authorization")

        let body: [String: String] = ["Username": username, "Pw": password]
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            if code == 401 {
                throw JellyfinError.invalidCredentials
            }
            throw JellyfinError.requestFailed
        }

        let authResponse = try JSONDecoder().decode(AuthResponse.self, from: data)
        return ServerConfig(
            serverURL: serverURL,
            apiKey: authResponse.accessToken,
            userId: authResponse.user.id
        )
    }

    // MARK: - Private

    private func urlComponents(path: String) -> URLComponents {
        var components = URLComponents(string: serverURL)!
        components.path = path
        if components.queryItems == nil {
            components.queryItems = []
        }
        components.queryItems?.append(URLQueryItem(name: "api_key", value: apiKey))
        return components
    }

    private func post(_ components: URLComponents, body: [String: Any]) async throws {
        guard let url = components.url else { throw JellyfinError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("MediaBrowser Token=\"\(apiKey)\"", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (_, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            print("[JellyfinService] POST \(components.path) failed: HTTP \((response as? HTTPURLResponse)?.statusCode ?? -1)")
            throw JellyfinError.requestFailed
        }
    }

    private func fetch(_ components: URLComponents) async throws -> Data {
        guard let url = components.url else {
            throw JellyfinError.invalidURL
        }
        print("[JellyfinService] GET \(url.absoluteString.prefix(120))")
        var request = URLRequest(url: url)
        request.setValue("MediaBrowser Token=\"\(apiKey)\"", forHTTPHeaderField: "Authorization")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            print("[JellyfinService] HTTP \((response as? HTTPURLResponse)?.statusCode ?? -1)")
            throw JellyfinError.requestFailed
        }
        print("[JellyfinService] OK - \(data.count) bytes")
        return data
    }
}

enum JellyfinError: Error, LocalizedError {
    case invalidURL
    case requestFailed
    case invalidCredentials

    var errorDescription: String? {
        switch self {
        case .invalidURL: "Invalid server URL"
        case .requestFailed: "Request failed"
        case .invalidCredentials: "Invalid username or password"
        }
    }
}

// MARK: - Auth Response

private struct AuthResponse: Decodable {
    let accessToken: String
    let user: AuthUser

    struct AuthUser: Decodable {
        let id: String
        enum CodingKeys: String, CodingKey { case id = "Id" }
    }

    enum CodingKeys: String, CodingKey {
        case accessToken = "AccessToken"
        case user = "User"
    }
}

// MARK: - API Response Models

private struct ItemsResponse: Decodable {
    let items: [ItemDTO]
    let totalRecordCount: Int

    enum CodingKeys: String, CodingKey {
        case items = "Items"
        case totalRecordCount = "TotalRecordCount"
    }
}

private struct CollectionsResponse: Decodable {
    let items: [CollectionDTO]

    enum CodingKeys: String, CodingKey {
        case items = "Items"
    }
}

private struct CollectionDTO: Decodable {
    let id: String
    let name: String

    enum CodingKeys: String, CodingKey {
        case id = "Id"
        case name = "Name"
    }
}

private struct ItemDTO: Decodable {
    let id: String
    let name: String
    let productionYear: Int?
    let overview: String?
    let runTimeTicks: Int64?
    let premiereDate: String?
    let genres: [String]?
    let tags: [String]?
    let studios: [StudioDTO]?
    let people: [PersonDTO]?
    let chapters: [ChapterDTO]?
    let imageTags: [String: String]?
    let serverId: String?

    enum CodingKeys: String, CodingKey {
        case id = "Id"
        case name = "Name"
        case productionYear = "ProductionYear"
        case overview = "Overview"
        case runTimeTicks = "RunTimeTicks"
        case premiereDate = "PremiereDate"
        case genres = "Genres"
        case tags = "Tags"
        case studios = "Studios"
        case people = "People"
        case chapters = "Chapters"
        case imageTags = "ImageTags"
        case serverId = "ServerId"
    }

    func toDomain(serverURL: String, apiKey: String) -> JellyfinItem {
        let runtime: Int? = runTimeTicks.map { Int($0 / 600_000_000) }
        let date: Date? = premiereDate.flatMap { ISO8601DateFormatter().date(from: $0) }

        return JellyfinItem(
            id: id,
            name: name,
            year: productionYear,
            overview: overview,
            runtime: runtime,
            premiereDate: date,
            genres: genres ?? [],
            tags: tags ?? [],
            studios: (studios ?? []).map(\.name),
            people: (people ?? []).map { JellyfinPerson(name: $0.name, role: $0.role) },
            chapters: (chapters ?? []).map {
                JellyfinChapter(startTicks: $0.startPositionTicks, name: $0.name, imageTag: $0.imageTag)
            },
            imageTags: imageTags ?? [:],
            serverId: serverId
        )
    }
}

private struct StudioDTO: Decodable {
    let name: String
    enum CodingKeys: String, CodingKey { case name = "Name" }
}

private struct PersonDTO: Decodable {
    let name: String
    let role: String?
    enum CodingKeys: String, CodingKey {
        case name = "Name"
        case role = "Role"
    }
}

private struct ChapterDTO: Decodable {
    let startPositionTicks: Int64
    let name: String
    let imageTag: String?

    enum CodingKeys: String, CodingKey {
        case startPositionTicks = "StartPositionTicks"
        case name = "Name"
        case imageTag = "ImageTag"
    }
}
