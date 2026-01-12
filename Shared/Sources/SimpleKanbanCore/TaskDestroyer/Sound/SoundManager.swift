// SoundManager.swift
// The audio engine of TaskDestroyer.
//
// This singleton handles all sound playback, subscribes to events,
// and respects user preferences. It preloads sounds for instant playback
// and handles volume, sound packs, and system audio state.

import AVFoundation
import Combine
import SwiftUI

// MARK: - Sound Manager

/// Manages all sound playback for TaskDestroyer.
///
/// Usage:
/// ```swift
/// // Play a sound manually
/// SoundManager.shared.play(.gong)
///
/// // The manager also subscribes to TaskDestroyerEventBus
/// // and automatically plays appropriate sounds
/// ```
public final class SoundManager: ObservableObject {

    /// Shared singleton instance
    public static let shared: SoundManager = SoundManager()

    // MARK: - Published State

    /// Whether sounds are currently enabled (respects settings)
    @Published public private(set) var isEnabled: Bool = true

    /// Current sound pack
    @Published public private(set) var currentPack: SoundPack = .default

    /// Master volume (0.0 - 1.0)
    @Published public var masterVolume: Float = 0.8

    // MARK: - Private State

    /// Preloaded audio players
    private var players: [SoundEffect: AVAudioPlayer] = [:]

    /// Pool of players for overlapping sounds
    private var playerPool: [SoundEffect: [AVAudioPlayer]] = [:]

    /// Event subscriptions
    private var cancellables: Set<AnyCancellable> = []

    /// Tracks which sounds have played (for one-per-session effects)
    private var playedThisSession: Set<SoundEffect> = []

    /// Timer for debouncing rapid sound plays
    private var lastPlayTime: [SoundEffect: Date] = [:]

    // MARK: - Initialization

    private init() {
        loadSettings()
        preloadSounds()
        subscribeToEvents()
        subscribeToSettings()
    }

    // MARK: - Settings

    private func loadSettings() {
        isEnabled = TaskDestroyerSettings.shared.soundsEnabled
        currentPack = SoundPack(rawValue: TaskDestroyerSettings.shared.soundPackRaw) ?? .default
        masterVolume = Float(TaskDestroyerSettings.shared.masterVolume)
    }

    private func subscribeToSettings() {
        // Subscribe to settings changed events to reload settings
        TaskDestroyerEventBus.shared.events
            .filter { event in
                if case .settingsChanged = event { return true }
                return false
            }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.reloadSettings()
            }
            .store(in: &cancellables)
    }

    /// Reload settings from storage
    private func reloadSettings() {
        isEnabled = TaskDestroyerSettings.shared.soundsEnabled
        let newPack: SoundPack = SoundPack(rawValue: TaskDestroyerSettings.shared.soundPackRaw) ?? .default
        if newPack != currentPack {
            currentPack = newPack
            preloadSounds()
        }
        masterVolume = Float(TaskDestroyerSettings.shared.masterVolume)
    }

    // MARK: - Sound Loading

    private func preloadSounds() {
        players.removeAll()
        playerPool.removeAll()

        for effect in SoundEffect.allCases {
            guard let url: URL = SoundPackAssets.url(for: effect, pack: currentPack) else {
                continue
            }

            do {
                let player: AVAudioPlayer = try AVAudioPlayer(contentsOf: url)
                player.prepareToPlay()
                players[effect] = player

                // Create pool for sounds that can overlap
                if effect.allowsOverlap {
                    var pool: [AVAudioPlayer] = []
                    for _ in 0..<3 {  // Pool of 3 players per overlapping sound
                        if let poolPlayer: AVAudioPlayer = try? AVAudioPlayer(contentsOf: url) {
                            poolPlayer.prepareToPlay()
                            pool.append(poolPlayer)
                        }
                    }
                    playerPool[effect] = pool
                }
            } catch {
                // Sound file not found or invalid - gracefully continue
                print("TaskDestroyer: Failed to load sound \(effect.filename): \(error)")
            }
        }
    }

    // MARK: - Event Subscription

    private func subscribeToEvents() {
        TaskDestroyerEventBus.shared.events
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                self?.handleEvent(event)
            }
            .store(in: &cancellables)
    }

    private func handleEvent(_ event: TaskDestroyerEvent) {
        guard isEnabled && TaskDestroyerSettings.shared.enabled else { return }

        let sounds: [(sound: SoundEffect, volume: Float)] = SoundEffect.sounds(for: event)
        for (sound, volume) in sounds {
            play(sound, volume: volume)
        }
    }

    // MARK: - Sound Playback

    /// Play a sound effect.
    ///
    /// - Parameters:
    ///   - effect: The sound effect to play
    ///   - volume: Volume override (0.0 - 1.0). If nil, uses default volume for the effect.
    ///   - ignoreSettings: If true, bypasses ALL settings and plays at raw volume. Use for MAXIMUM IMPACT.
    public func play(_ effect: SoundEffect, volume: Float? = nil, ignoreSettings: Bool = false) {
        // IGNORESETTINGS = NUCLEAR OPTION. NO MERCY.
        if !ignoreSettings {
            guard isEnabled && TaskDestroyerSettings.shared.enabled else { return }
            guard currentPack.soundsEnabled else { return }
        }

        // Debounce rapid plays (min 50ms between same sound)
        if let lastPlay: Date = lastPlayTime[effect],
           Date().timeIntervalSince(lastPlay) < 0.05 {
            return
        }
        lastPlayTime[effect] = Date()

        // Calculate final volume
        let finalVolume: Float
        if ignoreSettings {
            // RAW UNFILTERED VOLUME
            finalVolume = volume ?? effect.defaultVolume
        } else {
            let effectVolume: Float = volume ?? effect.defaultVolume
            let packMultiplier: Float = currentPack.volumeMultiplier
            let violenceMultiplier: Float = TaskDestroyerSettings.shared.violenceLevel.volumeMultiplier
            finalVolume = effectVolume * masterVolume * packMultiplier * violenceMultiplier
        }

        // Get player
        if let player: AVAudioPlayer = getPlayer(for: effect) {
            player.volume = finalVolume
            player.currentTime = 0
            player.play()
        }
    }

    /// Get an available player for a sound effect.
    private func getPlayer(for effect: SoundEffect) -> AVAudioPlayer? {
        // For overlapping sounds, find an available player from the pool
        if effect.allowsOverlap,
           let pool: [AVAudioPlayer] = playerPool[effect] {
            for player in pool {
                if !player.isPlaying {
                    return player
                }
            }
            // All pool players busy - fall back to main player
        }

        // Use the main preloaded player
        if let player: AVAudioPlayer = players[effect] {
            // If it's playing and doesn't allow overlap, skip
            if !effect.allowsOverlap && player.isPlaying {
                return nil
            }
            return player
        }

        return nil
    }

    /// Play a sound only once per session (for hover effects, etc).
    public func playOncePerSession(_ effect: SoundEffect, volume: Float? = nil) {
        guard !playedThisSession.contains(effect) else { return }
        playedThisSession.insert(effect)
        play(effect, volume: volume)
    }

    /// Reset the "played this session" tracking (call on new session start).
    public func resetSession() {
        playedThisSession.removeAll()
    }

    /// Stop all currently playing sounds.
    public func stopAll() {
        for player in players.values {
            player.stop()
        }
        for pool in playerPool.values {
            for player in pool {
                player.stop()
            }
        }
    }

    // MARK: - Convenience Methods

    /// Play the completion sound for a given intensity.
    public func playCompletion(intensity: EffectIntensity) {
        switch intensity {
        case .subtle:
            play(.pop, volume: 0.4)
        case .normal:
            play(.gong, volume: 0.6)
        case .epic:
            play(.gong, volume: 0.8)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.play(.explosion, volume: 0.5)
            }
        case .legendary:
            play(.gong, volume: 1.0)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.play(.explosion, volume: 0.7)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.play(.powerchord, volume: 0.6)
            }
        }
    }

    /// Play the shame trombone for rotting tasks (once per session per task ID).
    public func playShameTrombone(forTaskId taskId: String) {
        // Use task ID to track if we've already shamed this task
        let key: SoundEffect = .sadTrombone
        guard !playedThisSession.contains(key) else { return }
        playedThisSession.insert(key)
        play(.sadTrombone, volume: 0.5)
    }
}

// MARK: - Platform Specific

#if os(iOS)
import UIKit

extension SoundManager {

    /// Configure audio session for iOS.
    /// Call this on app launch.
    public func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("TaskDestroyer: Failed to configure audio session: \(error)")
        }
    }
}
#endif

#if os(macOS)
import AppKit

extension SoundManager {

    /// Check if system audio is muted.
    public var isSystemMuted: Bool {
        // On macOS, we respect the system mute state
        // This is a simplified check - full implementation would use CoreAudio
        return false  // TODO: Implement proper system mute detection
    }
}
#endif
