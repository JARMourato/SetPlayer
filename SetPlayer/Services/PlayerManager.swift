import AVFoundation
import Combine
import SwiftUI

@Observable @MainActor
final class PlayerManager {
    let player = AVPlayer()

    private(set) var currentItem: JellyfinItem?
    private(set) var chapters: [JellyfinChapter] = []
    private(set) var currentChapterIndex: Int = 0
    private(set) var isPlaying: Bool = false
    private(set) var currentTime: Double = 0
    private(set) var duration: Double = 0
    private(set) var videoSize: CGSize = .zero
    var artworkAccentColor: Color = .accentColor
    var jellyfinService: JellyfinService?

    private(set) var queue: [QueueEntry] = []
    var shuffleEnabled = false
    var repeatMode: RepeatMode = .off
    private var currentStreamURL: URL?

    var upNext: QueueEntry? { queue.first }

    enum RepeatMode: String, CaseIterable {
        case off
        case repeatAll
        case repeatOne
    }

    private var timeObserver: Any?
    private var statusObservation: NSKeyValueObservation?
    private var videoSizeObservation: NSKeyValueObservation?
    private var endOfPlaybackObserver: NSObjectProtocol?

    var currentChapter: JellyfinChapter? {
        guard chapters.indices.contains(currentChapterIndex) else { return nil }
        return chapters[currentChapterIndex]
    }

    var progress: Double {
        guard duration > 0 else { return 0 }
        return currentTime / duration
    }

    init() {
        setupTimeObserver()
        restoreQueue()
    }

    nonisolated deinit {
    }

    // MARK: - Persistence

    private static let savedItemIdKey = "PlayerManager.savedItemId"
    private static let savedTimeKey = "PlayerManager.savedTime"
    private static let savedQueueKey = "PlayerManager.savedQueue"

    func saveState() {
        guard let item = currentItem else { return }
        UserDefaults.standard.set(item.id, forKey: Self.savedItemIdKey)
        UserDefaults.standard.set(currentTime, forKey: Self.savedTimeKey)
    }

    var savedItemId: String? {
        UserDefaults.standard.string(forKey: Self.savedItemIdKey)
    }

    var savedTime: Double {
        UserDefaults.standard.double(forKey: Self.savedTimeKey)
    }

    func restoreState(item: JellyfinItem, streamURL: URL) {
        let savedTime = self.savedTime
        play(item: item, streamURL: streamURL)

        // Seek to saved position once ready
        if savedTime > 0 {
            let statusObs = player.currentItem?.observe(\.status) { [weak self] observed, _ in
                guard observed.status == .readyToPlay else { return }
                let time = CMTime(seconds: savedTime, preferredTimescale: 600)
                Task { @MainActor in
                    self?.player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
                    self?.player.pause()
                    self?.isPlaying = false
                }
            }
            // Keep a reference so it doesn't get deallocated
            self.statusObservation = statusObs
        } else {
            player.pause()
            isPlaying = false
        }
    }

    // MARK: - Playback

    func play(item: JellyfinItem, streamURL: URL) {
        currentItem = item
        currentStreamURL = streamURL
        chapters = item.chapters
        currentChapterIndex = 0

        let playerItem = AVPlayerItem(url: streamURL)
        player.replaceCurrentItem(with: playerItem)

        statusObservation?.invalidate()
        videoSizeObservation?.invalidate()

        statusObservation = playerItem.observe(\.status) { [weak self] observed, _ in
            guard observed.status == .readyToPlay else { return }
            let dur = observed.duration.seconds
            Task { @MainActor in
                self?.duration = dur
            }
        }

        videoSizeObservation = playerItem.observe(\.tracks) { [weak self] observed, _ in
            if let track = observed.tracks.first(where: { $0.assetTrack?.mediaType == .video }),
               let size = track.assetTrack?.naturalSize,
               size.width > 0, size.height > 0 {
                let transform = track.assetTrack?.preferredTransform ?? .identity
                let transformed = size.applying(transform)
                let finalSize = CGSize(width: abs(transformed.width), height: abs(transformed.height))
                Task { @MainActor in
                    self?.videoSize = finalSize
                }
            }
        }

        // Observe end of playback for queue auto-advance
        if let observer = endOfPlaybackObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        endOfPlaybackObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: playerItem,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.advanceQueue()
            }
        }

        player.play()
        isPlaying = true

        // Report playback start to Jellyfin
        if let service = jellyfinService {
            let id = item.id
            Task { await service.reportPlaybackStart(itemId: id) }
        }
    }

    func togglePlayPause() {
        if isPlaying {
            player.pause()
        } else {
            player.play()
        }
        isPlaying.toggle()
        reportPlaybackProgress()
    }

    func pause() {
        player.pause()
        isPlaying = false
        reportPlaybackProgress()
    }

    func stop() {
        // Report playback stopped to Jellyfin
        if let service = jellyfinService, let item = currentItem {
            let ticks = Int64(currentTime * 10_000_000)
            let id = item.id
            Task { await service.reportPlaybackStopped(itemId: id, positionTicks: ticks) }
        }

        player.pause()
        player.replaceCurrentItem(with: nil)
        if let observer = endOfPlaybackObserver {
            NotificationCenter.default.removeObserver(observer)
            endOfPlaybackObserver = nil
        }
        isPlaying = false
        currentItem = nil
        chapters = []
        currentChapterIndex = 0
        currentTime = 0
        duration = 0
        artworkAccentColor = .accentColor
    }

    // MARK: - Queue

    func addToQueue(_ item: JellyfinItem, streamURL: URL, imageURL: URL? = nil) {
        queue.append(QueueEntry(item: item, streamURL: streamURL, imageURL: imageURL))
        saveQueue()
    }

    func playNext(_ item: JellyfinItem, streamURL: URL, imageURL: URL? = nil) {
        queue.insert(QueueEntry(item: item, streamURL: streamURL, imageURL: imageURL), at: 0)
        saveQueue()
    }

    func removeFromQueue(at offsets: IndexSet) {
        queue.remove(atOffsets: offsets)
        saveQueue()
    }

    func moveInQueue(from source: IndexSet, to destination: Int) {
        queue.move(fromOffsets: source, toOffset: destination)
        saveQueue()
    }

    func clearQueue() {
        queue.removeAll()
        saveQueue()
    }

    func toggleShuffle() {
        shuffleEnabled.toggle()
        if shuffleEnabled && !queue.isEmpty {
            queue.shuffle()
            saveQueue()
        }
    }

    func cycleRepeatMode() {
        switch repeatMode {
        case .off: repeatMode = .repeatAll
        case .repeatAll: repeatMode = .repeatOne
        case .repeatOne: repeatMode = .off
        }
    }

    private func advanceQueue() {
        // Repeat one: replay current set from the start
        if repeatMode == .repeatOne {
            player.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero)
            player.play()
            isPlaying = true
            currentChapterIndex = 0
            if let service = jellyfinService, let item = currentItem {
                let id = item.id
                Task { await service.reportPlaybackStart(itemId: id) }
            }
            return
        }

        // Repeat all: re-add current to end of queue before advancing
        if repeatMode == .repeatAll, let current = currentItem, let streamURL = currentStreamURL {
            queue.append(QueueEntry(item: current, streamURL: streamURL, imageURL: nil))
        }

        guard !queue.isEmpty else {
            isPlaying = false
            return
        }
        let next = queue.removeFirst()
        saveQueue()
        play(item: next.item, streamURL: next.streamURL)
    }

    private func saveQueue() {
        if let data = try? JSONEncoder().encode(queue) {
            UserDefaults.standard.set(data, forKey: Self.savedQueueKey)
        }
    }

    private func restoreQueue() {
        guard let data = UserDefaults.standard.data(forKey: Self.savedQueueKey) else { return }
        queue = (try? JSONDecoder().decode([QueueEntry].self, from: data)) ?? []
    }

    func resume() {
        player.play()
        isPlaying = true
    }

    // MARK: - Chapter Navigation

    func seekToChapter(at index: Int) {
        guard chapters.indices.contains(index) else { return }
        currentChapterIndex = index
        let time = CMTime(seconds: chapters[index].startSeconds, preferredTimescale: 600)
        player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
        if !isPlaying {
            resume()
        }
    }

    func nextChapter() {
        let next = currentChapterIndex + 1
        if chapters.indices.contains(next) {
            seekToChapter(at: next)
        }
    }

    func previousChapter() {
        // If more than 3 seconds into current chapter, restart it
        if let chapter = currentChapter, currentTime - chapter.startSeconds > 3 {
            seekToChapter(at: currentChapterIndex)
        } else {
            let prev = currentChapterIndex - 1
            if chapters.indices.contains(prev) {
                seekToChapter(at: prev)
            }
        }
    }

    func seek(to seconds: Double) {
        let time = CMTime(seconds: seconds, preferredTimescale: 600)
        player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
    }

    // MARK: - Private

    private func setupTimeObserver() {
        let interval = CMTime(seconds: 0.25, preferredTimescale: 600)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.currentTime = time.seconds

                // Ensure duration is set — KVO callback can miss on fast loads
                if self.duration <= 0, let item = self.player.currentItem {
                    let dur = item.duration.seconds
                    if dur.isFinite && dur > 0 {
                        self.duration = dur
                    }
                }

                self.updateCurrentChapter()
                if Int(time.seconds) % 5 == 0 {
                    self.saveState()
                }
                if Int(time.seconds) % 10 == 0 {
                    self.reportPlaybackProgress()
                }
            }
        }
    }

    private func reportPlaybackProgress() {
        guard let service = jellyfinService, let item = currentItem else { return }
        let ticks = Int64(currentTime * 10_000_000)
        let paused = !isPlaying
        let id = item.id
        Task { await service.reportPlaybackProgress(itemId: id, positionTicks: ticks, isPaused: paused) }
    }

    private func updateCurrentChapter() {
        for (index, chapter) in chapters.enumerated().reversed() {
            if currentTime >= chapter.startSeconds {
                if index != currentChapterIndex {
                    currentChapterIndex = index
                }
                return
            }
        }
    }
}
