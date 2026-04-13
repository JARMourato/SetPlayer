import Foundation

enum SortOption: String, CaseIterable, Identifiable {
    case recentFirst = "Recent First"
    case oldestFirst = "Oldest First"
    case nameAZ = "Name A-Z"
    case nameZA = "Name Z-A"
    case artistAZ = "Artist A-Z"

    var id: String { rawValue }
}

@Observable @MainActor
final class LibraryViewModel {
    var items: [JellyfinItem] = []
    var recentlyPlayed: [JellyfinItem] = []
    var mostPlayed: [JellyfinItem] = []
    var collections: [JellyfinCollection] = []
    var selectedCollection: JellyfinCollection?
    var searchText: String = ""
    var sortOption: SortOption = .recentFirst
    var isLoading = false
    var error: String?

    private let jellyfin: JellyfinService

    init(jellyfin: JellyfinService) {
        self.jellyfin = jellyfin
    }

    var filteredItems: [JellyfinItem] {
        let base: [JellyfinItem]
        if searchText.isEmpty {
            base = items
        } else {
            let query = searchText.lowercased()
            base = items.filter { item in
                item.name.lowercased().contains(query)
                    || item.chapters.contains { $0.name.lowercased().contains(query) }
                    || item.tags.contains { $0.lowercased().contains(query) }
            }
        }
        return sorted(base)
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
            async let fetchedItems = jellyfin.fetchLibraryItems()
            async let fetchedCollections = jellyfin.fetchCollections()
            async let fetchedRecent = jellyfin.fetchRecentlyPlayed()
            async let fetchedMost = jellyfin.fetchMostPlayed()
            items = try await fetchedItems
            collections = try await fetchedCollections
            recentlyPlayed = (try? await fetchedRecent) ?? []
            mostPlayed = (try? await fetchedMost) ?? []
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

    // MARK: - Sorting

    private func sorted(_ items: [JellyfinItem]) -> [JellyfinItem] {
        switch sortOption {
        case .recentFirst:
            return items.sorted { ($0.year ?? 0) > ($1.year ?? 0) }
        case .oldestFirst:
            return items.sorted { ($0.year ?? 0) < ($1.year ?? 0) }
        case .nameAZ:
            return items.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .nameZA:
            return items.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedDescending }
        case .artistAZ:
            return items.sorted {
                let cmp = $0.artist.localizedCaseInsensitiveCompare($1.artist)
                if cmp == .orderedSame { return ($0.year ?? 0) > ($1.year ?? 0) }
                return cmp == .orderedAscending
            }
        }
    }
}
