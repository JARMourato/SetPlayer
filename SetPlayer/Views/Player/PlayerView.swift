import AVKit
import SwiftUI

/// PlayerView is retained for potential standalone use or video display.
/// The primary playback UI is now the BottomPlayerBar in LibraryView.
struct PlayerView: View {
    @Environment(PlayerManager.self) private var player
    @Environment(JellyfinService.self) private var jellyfin

    var body: some View {
        if player.currentItem != nil {
            VStack(spacing: 0) {
                VideoPlayer(player: player.player)
                    .frame(minHeight: 200)
            }
        } else {
            ContentUnavailableView("No Set Playing", systemImage: "play.slash",
                                   description: Text("Select a set and press play"))
        }
    }
}
