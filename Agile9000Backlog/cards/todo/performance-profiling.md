---
title: Performance profiling for particles and animations
column: todo
position: zzg
created: 2026-01-10T12:00:00Z
modified: 2026-01-10T12:00:00Z
labels: [polish, integration, ios, macos]
---

## Description

Profile TaskBuster9000 performance, especially particle effects and Matrix rain background. Identify and fix any performance issues, set up automatic quality reduction on struggling devices.

## Acceptance Criteria

- [ ] Profile with Instruments (Time Profiler, Core Animation)
- [ ] Measure frame rate during heavy effects
- [ ] Identify CPU/GPU bottlenecks
- [ ] Optimize particle systems if needed
- [ ] Add automatic quality reduction
- [ ] Set performance budgets (target 60fps)
- [ ] Test on oldest supported devices
- [ ] Add performance monitoring (debug builds)
- [ ] Document performance characteristics

## Technical Notes

### Profiling Checklist

```
CPU Profiling:
[ ] Event bus processing time
[ ] Achievement checking overhead
[ ] Stats calculation on completion
[ ] Timer callbacks (Matrix rain, etc.)

GPU Profiling:
[ ] Particle system draw calls
[ ] Matrix rain rendering
[ ] Blur/glow effects
[ ] Animation compositing

Memory Profiling:
[ ] Sound asset memory usage
[ ] Particle texture memory
[ ] Emitter pool sizing
[ ] Subscription leak detection
```

### Automatic Quality Adjustment

```swift
final class PerformanceManager: ObservableObject {
    static let shared = PerformanceManager()

    @Published var effectiveQuality: ParticleQuality = .medium

    private var frameRateHistory: [Double] = []
    private let targetFrameRate: Double = 60.0
    private let minAcceptableFrameRate: Double = 45.0

    func recordFrameTime(_ frameTime: Double) {
        let fps = 1.0 / frameTime
        frameRateHistory.append(fps)

        // Keep last 60 frames
        if frameRateHistory.count > 60 {
            frameRateHistory.removeFirst()
        }

        // Check if we need to reduce quality
        let averageFps = frameRateHistory.reduce(0, +) / Double(frameRateHistory.count)
        adjustQuality(forFps: averageFps)
    }

    private func adjustQuality(forFps fps: Double) {
        if fps < minAcceptableFrameRate && effectiveQuality != .low {
            // Reduce quality
            switch effectiveQuality {
            case .high: effectiveQuality = .medium
            case .medium: effectiveQuality = .low
            default: break
            }
            print("⚠️ Performance: Reduced quality to \(effectiveQuality) (FPS: \(fps))")
        }
    }

    // Check device capability at startup
    func determineBaselineQuality() {
        #if os(iOS)
        if ProcessInfo.processInfo.thermalState == .critical ||
           ProcessInfo.processInfo.thermalState == .serious {
            effectiveQuality = .low
        }

        if ProcessInfo.processInfo.isLowPowerModeEnabled {
            effectiveQuality = .low
        }
        #endif

        // Could also check device model for known slow devices
    }
}
```

### Optimization Strategies

```
Matrix Rain:
- Reduce column count on older devices
- Lower frame rate (15fps → 10fps)
- Reduce character count per column
- Use simpler rendering (no blur)

Particles:
- Cap max simultaneous emitters
- Pool and reuse emitter nodes
- Reduce particle count per effect
- Shorter particle lifetimes
- Simpler blend modes

Animations:
- Reduce animation durations
- Skip secondary animations
- Disable screen shake
- Use simpler easing curves
```

### Performance Budgets

```
Target: 60 FPS (16.67ms per frame)

Effect Budgets:
- Task completion: < 5ms
- Particle update: < 2ms
- Matrix rain frame: < 3ms
- Event processing: < 1ms
- UI rendering: < 8ms
- Buffer: 2ms
```

File: `TaskBuster/Core/PerformanceManager.swift`

## Platform Notes

**iOS:**
- Use `ProcessInfo.thermalState` to detect overheating
- Respect low power mode
- iPhone 8 and earlier are "low tier"

**macOS:**
- Generally more headroom
- Still profile on base model MacBooks
- Consider integrated vs discrete GPU
