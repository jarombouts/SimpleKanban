---
title: Define TaskDestroyerTypography
column: done
position: h
created: 2026-01-10T12:00:00Z
modified: 2026-01-10T12:00:00Z
labels: [phase-2, ui, shared]
---

## Description

Create the typography system for TaskDestroyer. Everything is monospace because we're developers, not designers. Headers are heavy, condensed, and ALL CAPS.

The typography should feel like reading a terminal or an industrial warning sign.

## Acceptance Criteria

- [ ] Create `TaskDestroyerTypography` enum with font definitions
- [ ] Define display font (large, black weight, monospace)
- [ ] Define heading font (medium size, bold, monospace)
- [ ] Define body font (standard size, regular, monospace)
- [ ] Define caption font (small, medium weight, monospace)
- [ ] Define code font (for any code snippets)
- [ ] Add kerning/tracking values for each
- [ ] Create helper methods for styled text
- [ ] Add line height specifications
- [ ] Document usage guidelines

## Technical Notes

```swift
import SwiftUI

enum TaskDestroyerTypography {
    // ═══════════════════════════════════════════════════════════
    // FONT DEFINITIONS
    // ═══════════════════════════════════════════════════════════

    /// Large headers, titles - BLACK weight, aggressive
    static let display: Font = .system(size: 32, weight: .black, design: .monospaced)

    /// Section headers
    static let heading: Font = .system(size: 20, weight: .bold, design: .monospaced)

    /// Subheadings, card titles
    static let subheading: Font = .system(size: 16, weight: .semibold, design: .monospaced)

    /// Body text
    static let body: Font = .system(size: 14, weight: .regular, design: .monospaced)

    /// Small labels, timestamps
    static let caption: Font = .system(size: 12, weight: .medium, design: .monospaced)

    /// Tiny text, legal BS
    static let micro: Font = .system(size: 10, weight: .regular, design: .monospaced)

    // ═══════════════════════════════════════════════════════════
    // KERNING / TRACKING
    // ═══════════════════════════════════════════════════════════

    static let displayKerning: CGFloat = 3.0
    static let headingKerning: CGFloat = 2.0
    static let bodyKerning: CGFloat = 0.5

    // ═══════════════════════════════════════════════════════════
    // HELPER FUNCTIONS
    // ═══════════════════════════════════════════════════════════

    /// Creates display-style text (ALL CAPS, wide kerning)
    static func displayText(_ string: String) -> Text {
        Text(string.uppercased())
            .font(display)
            .kerning(displayKerning)
    }

    /// Creates heading-style text
    static func headingText(_ string: String) -> Text {
        Text(string.uppercased())
            .font(heading)
            .kerning(headingKerning)
    }

    /// Creates body text with standard formatting
    static func bodyText(_ string: String) -> Text {
        Text(string)
            .font(body)
            .kerning(bodyKerning)
    }
}

// ═══════════════════════════════════════════════════════════
// VIEW MODIFIERS
// ═══════════════════════════════════════════════════════════

extension View {
    func shipprDisplayStyle() -> some View {
        self
            .font(TaskDestroyerTypography.display)
            .kerning(TaskDestroyerTypography.displayKerning)
            .textCase(.uppercase)
    }

    func shipprHeadingStyle() -> some View {
        self
            .font(TaskDestroyerTypography.heading)
            .kerning(TaskDestroyerTypography.headingKerning)
            .textCase(.uppercase)
    }

    func shipprBodyStyle() -> some View {
        self
            .font(TaskDestroyerTypography.body)
            .kerning(TaskDestroyerTypography.bodyKerning)
    }
}
```

File: `TaskDestroyer/Theme/TaskDestroyerTypography.swift`

## Platform Notes

Uses system monospace font which is SF Mono on both platforms. Font sizes might need slight adjustments for iOS (smaller screens), but should work as-is initially.
