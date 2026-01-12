---
title: Respect system mute and platform audio
column: todo
position: yc
created: 2026-01-10T12:00:00Z
modified: 2026-01-12T12:41:38Z
labels: [phase-3, integration, ios, macos]
---

## Description

Ensure TaskBuster9000 audio plays nicely with system audio settings. When the system is muted or the ringer is off, sounds should respect that. Also handle audio focus/interruptions properly.

## Acceptance Criteria

- [ ] Detect and respect system mute on macOS
- [ ] Detect and respect ringer switch on iOS
- [ ] Handle audio interruptions (phone call, Siri, etc.)
- [ ] Resume playback after interruption if appropriate
- [ ] Don't play sounds when screen is locked (iOS)
- [ ] Consider "Do Not Disturb" mode
- [ ] Add "Play sounds in background" option
- [ ] Use appropriate audio session category on iOS

## Technical Notes

### iOS Implementation

```swift
// Audio session configuration
func configureAudioSession() {
    let session = AVAudioSession.sharedInstance()

    do {
        // .ambient - respects ringer, mixes with other audio
        try session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        try session.setActive(true)
    } catch {
        print("Failed to configure audio session: \(error)")
    }

    // Listen for interruptions
    NotificationCenter.default.addObserver(
        self,
        selector: #selector(handleInterruption),
        name: AVAudioSession.interruptionNotification,
        object: session
    )
}

@objc func handleInterruption(_ notification: Notification) {
    guard let userInfo = notification.userInfo,
          let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
          let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
        return
    }

    switch type {
    case .began:
        // Pause/stop audio
        break
    case .ended:
        // Resume if appropriate
        if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt,
           AVAudioSession.InterruptionOptions(rawValue: optionsValue).contains(.shouldResume) {
            // Resume playback
        }
    @unknown default:
        break
    }
}

// Check if ringer is off (approximate - no direct API)
// Can check if AVAudioSession outputVolume is 0
var isRingerOff: Bool {
    // Note: This isn't 100% reliable but gives an indication
    AVAudioSession.sharedInstance().outputVolume == 0
}
```

### macOS Implementation

```swift
import CoreAudio

func isSystemMuted() -> Bool {
    var propertyAddress = AudioObjectPropertyAddress(
        mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
        mScope: kAudioDevicePropertyScopeOutput,
        mElement: kAudioObjectPropertyElementMain
    )

    var deviceID = AudioDeviceID()
    var size = UInt32(MemoryLayout.size(ofValue: deviceID))

    // Get default output device
    var defaultAddress = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDefaultOutputDevice,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )

    AudioObjectGetPropertyData(
        AudioObjectID(kAudioObjectSystemObject),
        &defaultAddress,
        0,
        nil,
        &size,
        &deviceID
    )

    // Check mute status
    var muteAddress = AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyMute,
        mScope: kAudioDevicePropertyScopeOutput,
        mElement: kAudioObjectPropertyElementMain
    )

    var muted: UInt32 = 0
    size = UInt32(MemoryLayout.size(ofValue: muted))

    AudioObjectGetPropertyData(deviceID, &muteAddress, 0, nil, &size, &muted)

    return muted != 0
}
```

File: `TaskBuster/Sound/SystemAudioHandler.swift`

## Platform Notes

**iOS:**
- Use `.ambient` category to respect ringer
- `.playback` category would ignore ringer (not recommended for UI sounds)
- Handle interruptions from calls, Siri, alarms

**macOS:**
- Use CoreAudio to check system mute
- Consider menu bar volume indicator
- Less interruption handling needed

## Testing

- Test with ringer off (iOS)
- Test with system muted (macOS)
- Test during phone call (iOS)
- Test with Do Not Disturb enabled
- Test with AirPods connected/disconnected