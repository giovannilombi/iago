import AVFoundation
import Foundation
import IAGOStore
import Observation

/// Plays one encrypted track (FR-52). One player for the whole app, so the audio keeps going in every
/// section and the playback bar can control it. The track is decrypted to `tmp/scratch/playback/` and removed
/// when another track is loaded or the player is closed; the scratch folder is also emptied at launch (9.4).
@MainActor
@Observable
final class AudioPlayerModel {
    private(set) var asset: Asset?
    /// The item the loaded track belongs to.
    private(set) var itemID: String?
    /// True from the first play until the bar is closed: the playback bar is shown meanwhile.
    private(set) var isActive = false
    private(set) var duration: Double = 0
    private(set) var currentTime: Double = 0
    private(set) var isPlaying = false
    private(set) var isLoading = false
    var error: String?

    private var player: AVAudioPlayer?
    private var file: URL?
    private var timer: Timer?
    private let archive: Archive
    private let folder: URL

    init(archive: Archive, scratch: URL) {
        self.archive = archive
        self.folder = scratch.appendingPathComponent("playback", isDirectory: true)
    }

    func load(_ asset: Asset, itemID: String) async {
        guard asset.id != self.asset?.id else { return }
        release()
        self.asset = asset
        self.itemID = itemID
        isLoading = true
        defer { isLoading = false }
        let destination = folder.appendingPathComponent("\(UUID().uuidString).m4a")
        let archive = self.archive
        let folder = self.folder
        do {
            try await Task.detached(priority: .userInitiated) {
                try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                try archive.readAsset(asset, to: destination)
            }.value
            guard self.asset?.id == asset.id else {
                try? FileManager.default.removeItem(at: destination)
                return
            }
            let player = try AVAudioPlayer(contentsOf: destination)
            player.prepareToPlay()
            self.player = player
            self.file = destination
            duration = player.duration
            currentTime = 0
        } catch {
            self.error = ErrorText.describe(error)
            try? FileManager.default.removeItem(at: destination)
        }
    }

    func togglePlay() {
        guard let player else { return }
        if player.isPlaying {
            player.pause()
            stopTimer()
        } else {
            player.play()
            startTimer()
            isActive = true
        }
        isPlaying = player.isPlaying
    }

    /// Another track of the same item, at the same position and in the same play state.
    func switchTrack(to asset: Asset) async {
        guard let itemID else { return }
        let position = currentTime
        let wasPlaying = isPlaying
        await load(asset, itemID: itemID)
        seek(to: position, play: wasPlaying)
    }

    func skip(by seconds: Double) {
        guard let player else { return }
        seek(to: player.currentTime + seconds, play: false)
    }

    /// Clickable timestamps jump here (FR-52).
    func seek(to seconds: Double, play: Bool = true) {
        guard let player else { return }
        player.currentTime = max(0, min(seconds, player.duration))
        currentTime = player.currentTime
        if play, !player.isPlaying {
            player.play()
            startTimer()
            isPlaying = true
            isActive = true
        }
    }

    /// The bar's X: stops the audio and hides the bar.
    func close() {
        release()
        isActive = false
    }

    private func release() {
        stopTimer()
        player?.stop()
        player = nil
        if let file { try? FileManager.default.removeItem(at: file) }
        file = nil
        asset = nil
        itemID = nil
        isPlaying = false
        currentTime = 0
        duration = 0
    }

    private func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, let player = self.player else { return }
                self.currentTime = player.currentTime
                if !player.isPlaying {
                    self.isPlaying = false
                    self.stopTimer()
                }
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}
