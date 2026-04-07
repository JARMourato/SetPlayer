import Foundation

@Observable @MainActor
final class LibraryViewModel {
    var items: [JellyfinItem] = []
    var collections: [JellyfinCollection] = []
    var selectedCollection: JellyfinCollection?
    var searchText: String = ""
    var isLoading = false
    var error: String?

    private let jellyfin: JellyfinService

    init(jellyfin: JellyfinService) {
        self.jellyfin = jellyfin
    }

    var filteredItems: [JellyfinItem] {
        guard !searchText.isEmpty else { return items }
        let query = searchText.lowercased()
        return items.filter { item in
            item.name.lowercased().contains(query)
                || item.chapters.contains { $0.name.lowercased().contains(query) }
                || item.tags.contains { $0.lowercased().contains(query) }
        }
    }

    var artists: [String] {
        let all = items.map(\.artist)
        return Array(Set(all)).sorted()
    }

    var years: [Int] {
        let all = items.compactMap(\.year)
        return Array(Set(all)).sorted(by: >)
    }

    func loadLibrary() async {
        isLoading = true
        error = nil
        do {
            let fetchedItems = try await jellyfin.fetchLibraryItems()
            let fetchedCollections = try await jellyfin.fetchCollections()
            items = fetchedItems
            collections = fetchedCollections
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func loadCollection(_ collection: JellyfinCollection) async {
        selectedCollection = collection
        isLoading = true
        do {
            items = try await jellyfin.fetchCollectionItems(collectionId: collection.id)
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func loadAll() async {
        selectedCollection = nil
        await loadLibrary()
    }

    func items(for artist: String) -> [JellyfinItem] {
        filteredItems.filter { $0.artist == artist }
    }

    func items(for year: Int) -> [JellyfinItem] {
        filteredItems.filter { $0.year == year }
    }
}
