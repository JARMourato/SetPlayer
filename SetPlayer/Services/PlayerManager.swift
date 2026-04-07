import AVFoundation
import Combine

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

    private var timeObserver: Any?
    private var statusObservation: NSKeyValueObservation?
    private var videoSizeObservation: NSKeyValueObservation?

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
    }

    nonisolated deinit {
    }

    // MARK: - Playback

    func play(item: JellyfinItem, streamURL: URL) {
        currentItem = item
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

        player.play()
        isPlaying = true
    }

    func togglePlayPause() {
        if isPlaying {
            player.pause()
        } else {
            player.play()
        }
        isPlaying.toggle()
    }

    func pause() {
        player.pause()
        isPlaying = false
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
        let interval = CMTime(seconds: 0.5, preferredTimescale: 600)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self else { return }
            self.currentTime = time.seconds
            self.updateCurrentChapter()
        }
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
