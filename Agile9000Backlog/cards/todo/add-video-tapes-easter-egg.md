---
title: Add video tapes and Patrick Bateman easter eggs
column: todo
position: zzb
created: 2026-01-10T12:00:00Z
modified: 2026-01-10T12:00:00Z
labels: [phase-6, fx, shared]
---

## Description

Implement the American Psycho / Patrick Bateman easter eggs. When users create a task about "video tapes," special things happen. Also includes the business card styling for certain cards.

## Acceptance Criteria

- [ ] Detect "video tape" or "video tapes" in task title
- [ ] Apply special cream/off-white card styling
- [ ] Add tooltip: "Look at that subtle off-white coloring..."
- [ ] Unlock the VIDEO TAPES achievement
- [ ] Create "Bateman" card theme variant
- [ ] Business card style: cream background, tasteful typography
- [ ] Optional: play quote audio on special interaction
- [ ] Hidden achievement for discovering this

## Technical Notes

```swift
// Detection and styling
extension Card {
    var isBatemanCard: Bool {
        let lowered = title.lowercased()
        return lowered.contains("video tape") ||
               lowered.contains("video tapes") ||
               lowered.contains("paul allen") ||
               lowered.contains("business card")
    }
}

// Special card styling
struct BatemanCardStyle {
    // "Bone" color palette from the movie
    static let bone = Color(hex: "#E8E0D5")
    static let eggshell = Color(hex: "#F0EAE0")
    static let cream = Color(hex: "#FFFDD0")
    static let ivory = Color(hex: "#FFFFF0")

    // Tasteful font
    static let font = Font.custom("Silian Rail", size: 14)  // Joke - use Garamond or similar
    static let actualFont = Font.system(.body, design: .serif)
}

struct BatemanCardView: View {
    let card: Card

    @State private var showQuote: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(card.title)
                .font(BatemanCardStyle.actualFont)
                .foregroundColor(.black)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(BatemanCardStyle.bone)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(Color.gray.opacity(0.3), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.1), radius: 2, y: 1)
        .help(batemanTooltip)
        .onTapGesture(count: 3) {
            showQuote = true
        }
        .sheet(isPresented: $showQuote) {
            BatemanQuoteView()
        }
    }

    private var batemanTooltip: String {
        [
            "Look at that subtle off-white coloring.",
            "The tasteful thickness of it.",
            "Oh my God, it even has a watermark.",
            "Is something wrong, Patrick? You're sweating."
        ].randomElement()!
    }
}

struct BatemanQuoteView: View {
    @Environment(\.dismiss) var dismiss

    private let quotes = [
        "I have to return some videotapes.",
        "I'm into, uh, well, murders and executions, mostly.",
        "Do you like Huey Lewis and the News?",
        "I live in the American Gardens Building on W. 81st Street.",
        "Let's see Paul Allen's card.",
        "That's bone. And the lettering is something called Silian Rail.",
    ]

    var body: some View {
        VStack(spacing: 24) {
            // Business card mockup
            VStack(spacing: 8) {
                Text("PATRICK BATEMAN")
                    .font(.system(.headline, design: .serif))
                    .foregroundColor(.black)

                Text("Vice President")
                    .font(.system(.caption, design: .serif))
                    .foregroundColor(.gray)

                Text("PIERCE & PIERCE")
                    .font(.system(.caption2, design: .serif))
                    .foregroundColor(.gray)
            }
            .padding(20)
            .background(BatemanCardStyle.bone)
            .cornerRadius(4)
            .shadow(radius: 5)

            // Random quote
            Text("\"\(quotes.randomElement()!)\"")
                .font(.system(.body, design: .serif))
                .italic()
                .multilineTextAlignment(.center)
                .foregroundColor(TaskBusterColors.textSecondary)
                .padding()

            Button("Impressive. Very nice.") {
                dismiss()
            }
            .buttonStyle(TaskBusterSecondaryButtonStyle())
        }
        .padding(40)
        .background(TaskBusterColors.darkMatter)
    }
}

// In task creation flow
func onTaskCreated(_ card: Card) {
    if card.isBatemanCard {
        AchievementManager.shared.unlock(.videoTapes)

        // Maybe play a sound
        // SoundManager.shared.play(.horrorSting, volume: 0.3)
    }
}
```

File: `TaskBuster/EasterEggs/BatemanEasterEgg.swift`

## Platform Notes

Works on both platforms. The serif font styling might look slightly different on iOS vs macOS, but that's fine.

## Legal Note

These are parody references to a well-known film. The quotes and styling are used for satirical/humorous purposes.

## Alternative Triggers

Also trigger on:
- "paul allen"
- "business card"
- "huey lewis"
- "dorsia"
