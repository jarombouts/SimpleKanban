---
title: Add particles toggle in settings
column: todo
position: zf
created: 2026-01-10T12:00:00Z
modified: 2026-01-10T12:00:00Z
labels: [phase-4, ui, shared]
---

## Description

Add UI controls for particle effect settings. Users should be able to toggle particles on/off, adjust intensity, and potentially disable specific particle types.

Some users may want the sounds without the visual effects (or vice versa), and older devices may need particles disabled for performance.

## Acceptance Criteria

- [ ] Add master particles toggle in settings
- [ ] Add intensity/quality selector (low/medium/high)
- [ ] Add per-effect toggles (explosions, embers, confetti)
- [ ] Add "Reduce Particles" for performance mode
- [ ] Preview particle effect when toggling on
- [ ] Respect "Reduce Motion" accessibility setting
- [ ] Settings integrate with existing TaskBuster settings section
- [ ] Persist settings via AppStorage

## Technical Notes

```swift
struct ParticleSettingsView: View {
    @ObservedObject var settings = TaskBusterSettings.shared
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    var body: some View {
        Section {
            // Master toggle
            Toggle("Enable Particles", isOn: $settings.particlesEnabled)
                .disabled(reduceMotion)

            if reduceMotion {
                Text("Particles disabled due to Reduce Motion setting")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if settings.particlesEnabled && !reduceMotion {
                // Quality selector
                Picker("Particle Quality", selection: $settings.particleQuality) {
                    Text("Low").tag(ParticleQuality.low)
                    Text("Medium").tag(ParticleQuality.medium)
                    Text("High").tag(ParticleQuality.high)
                }
                .pickerStyle(.segmented)

                // Per-effect toggles
                DisclosureGroup("Particle Effects") {
                    Toggle("Explosions", isOn: $settings.explosionParticlesEnabled)
                    Toggle("Embers", isOn: $settings.emberParticlesEnabled)
                    Toggle("Smoke", isOn: $settings.smokeParticlesEnabled)
                    Toggle("Confetti", isOn: $settings.confettiParticlesEnabled)
                }

                // Preview button
                Button("Preview Effects") {
                    previewParticles()
                }
                .buttonStyle(.bordered)
            }
        } header: {
            Label("Particles", systemImage: "sparkles")
        } footer: {
            Text("Particles use GPU acceleration. Disable on older devices if performance is poor.")
                .font(.caption)
        }
    }

    private func previewParticles() {
        // Spawn a test explosion at center of screen
        ParticleSystem.shared.spawnExplosion(
            at: CGPoint(x: 400, y: 300),
            intensity: .normal
        )
    }
}

// Particle quality enum
enum ParticleQuality: String, CaseIterable {
    case low = "low"
    case medium = "medium"
    case high = "high"

    var particleMultiplier: Double {
        switch self {
        case .low: return 0.3
        case .medium: return 0.7
        case .high: return 1.0
        }
    }

    var displayName: String {
        switch self {
        case .low: return "Low (Better Performance)"
        case .medium: return "Medium"
        case .high: return "High (Best Quality)"
        }
    }
}

// Add to TaskBusterSettings
extension TaskBusterSettings {
    @AppStorage("taskbuster_particles_enabled") var particlesEnabled: Bool = true
    @AppStorage("taskbuster_particle_quality") var particleQualityRaw: String = ParticleQuality.medium.rawValue

    var particleQuality: ParticleQuality {
        get { ParticleQuality(rawValue: particleQualityRaw) ?? .medium }
        set { particleQualityRaw = newValue.rawValue }
    }

    @AppStorage("taskbuster_explosion_particles") var explosionParticlesEnabled: Bool = true
    @AppStorage("taskbuster_ember_particles") var emberParticlesEnabled: Bool = true
    @AppStorage("taskbuster_smoke_particles") var smokeParticlesEnabled: Bool = true
    @AppStorage("taskbuster_confetti_particles") var confettiParticlesEnabled: Bool = true
}
```

File: `TaskBuster/Views/ParticleSettingsView.swift`

## Platform Notes

Works on both platforms.

**Performance considerations by platform:**

**macOS:**
- Generally more GPU headroom
- Default to High quality
- Particles rarely need disabling

**iOS:**
- Older devices (iPhone 8 and earlier) may struggle
- Default to Medium quality
- Consider auto-detecting device capability

```swift
#if os(iOS)
var defaultQuality: ParticleQuality {
    // Check device capability
    if ProcessInfo.processInfo.thermalState == .critical {
        return .low
    }
    // Could also check device model
    return .medium
}
#endif
```

## Dependencies

- Requires: TaskBusterSettings
- Requires: ParticleSystem
