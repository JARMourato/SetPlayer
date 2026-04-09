import Foundation

struct ServerConfig: Codable, Hashable {
    var serverURL: String
    var apiKey: String
    var userId: String

    private static let key = "serverConfig"

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: Self.key)
        }
    }

    static func load() -> ServerConfig? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(ServerConfig.self, from: data)
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}
