// TaskDestroyerCardView.swift
// The TaskDestroyer-styled card view with dark theme, neon accents,
// shame timers, and hover glow effects.
//
// When TaskDestroyer is enabled, cards become dangerous, actionable
// items with visual indicators of age/urgency.

import SwiftUI

// MARK: - TaskDestroyer Card View

/// A card view with TaskDestroyer styling.
///
/// Features:
/// - Dark background with neon border
/// - Border color based on card age (shame level)
/// - Hover glow effect (macOS)
/// - Shame timer display
/// - Smooth transitions
///
/// Usage:
/// ```swift
/// TaskDestroyerCardView(card: card, isSelected: isSelected)
/// ```
public struct TaskDestroyerCardView: View {

    /// The card to display
    public let card: Card

    /// Whether this card is selected
    public let isSelected: Bool

    /// Available labels from the board (for display)
    public let boardLabels: [CardLabel]

    /// Callback for selecting this card
    public let onSelect: () -> Void

    @State private var isHovering: Bool = false
    @ObservedObject private var settings: TaskDestroyerSettings = TaskDestroyerSettings.shared

    public init(
        card: Card,
        isSelected: Bool,
        boardLabels: [CardLabel] = [],
        onSelect: @escaping () -> Void = {}
    ) {
        self.card = card
        self.isSelected = isSelected
        self.boardLabels = boardLabels
        self.onSelect = onSelect
    }

    // MARK: - Computed Properties

    private var shameLevel: ShameLevel {
        ShameLevel.from(created: card.created)
    }

    private var borderColor: Color {
        if isSelected {
            return TaskDestroyerColors.primary
        }
        switch shameLevel {
        case .fresh:
            return TaskDestroyerColors.border
        case .normal:
            return TaskDestroyerColors.border
        case .stale:
            return TaskDestroyerColors.warning.opacity(0.6)
        case .rotting:
            return TaskDestroyerColors.danger.opacity(0.8)
        case .decomposing:
            return TaskDestroyerColors.danger
        }
    }

    private var glowColor: Color {
        if isSelected {
            return TaskDestroyerColors.primaryGlow
        }
        return borderColor
    }

    // MARK: - Body

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Title
            Text(card.title)
                .font(TaskDestroyerTypography.subheading)
                .foregroundColor(TaskDestroyerColors.textPrimary)
                .lineLimit(2)

            // Labels
            if !card.labels.isEmpty {
                labelsView
            }

            // Body snippet (if present)
            if !card.body.isEmpty {
                Text(card.body.prefix(80) + (card.body.count > 80 ? "..." : ""))
                    .font(TaskDestroyerTypography.caption)
                    .foregroundColor(TaskDestroyerColors.textSecondary)
                    .lineLimit(2)
            }

            // Shame timer
            HStack {
                Spacer()
                CompactShameTimerView(createdDate: card.created)
            }
        }
        .padding(12)
        .background(cardBackground)
        .overlay(cardBorder)
        .shadow(
            color: (isHovering || isSelected) ? glowColor.opacity(0.4) : .clear,
            radius: (isHovering || isSelected) ? 8 : 0
        )
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
        .onTapGesture {
            onSelect()
        }
        // Overlay shame effects for rotting tasks
        .overlay(
            ShameOverlay(shameLevel: shameLevel)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .opacity(settings.enabled && settings.particlesEnabled ? 1 : 0)
        )
    }

    // MARK: - Subviews

    private var labelsView: some View {
        HStack(spacing: 4) {
            ForEach(card.labels.prefix(3), id: \.self) { labelId in
                if let label = boardLabels.first(where: { $0.id == labelId }) {
                    TaskDestroyerLabelPill(label: label)
                }
            }
            if card.labels.count > 3 {
                Text("+\(card.labels.count - 3)")
                    .font(TaskDestroyerTypography.micro)
                    .foregroundColor(TaskDestroyerColors.textMuted)
            }
        }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(TaskDestroyerColors.cardBackground)
    }

    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: 8)
            .stroke(
                borderColor,
                lineWidth: (isHovering || isSelected) ? 2 : 1
            )
    }
}

// MARK: - Label Pill

/// A neon-styled label pill for TaskDestroyer mode.
public struct TaskDestroyerLabelPill: View {

    public let label: CardLabel

    public init(label: CardLabel) {
        self.label = label
    }

    private var labelColor: Color {
        Color(hex: label.color)
    }

    public var body: some View {
        Text(label.name)
            .font(TaskDestroyerTypography.micro)
            .foregroundColor(TaskDestroyerColors.textPrimary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                Capsule()
                    .fill(labelColor.opacity(0.3))
            )
            .overlay(
                Capsule()
                    .stroke(labelColor.opacity(0.7), lineWidth: 1)
            )
    }
}

// MARK: - Theme-Aware Card Wrapper

/// A card view that automatically switches between standard and TaskDestroyer themes.
///
/// Usage:
/// ```swift
/// ThemedCardView(card: card, isSelected: isSelected, boardLabels: labels) {
///     viewModel.selectCard(card)
/// }
/// ```
public struct ThemedCardView: View {

    public let card: Card
    public let isSelected: Bool
    public let boardLabels: [CardLabel]
    public let onSelect: () -> Void

    @ObservedObject private var settings: TaskDestroyerSettings = TaskDestroyerSettings.shared

    public init(
        card: Card,
        isSelected: Bool,
        boardLabels: [CardLabel] = [],
        onSelect: @escaping () -> Void = {}
    ) {
        self.card = card
        self.isSelected = isSelected
        self.boardLabels = boardLabels
        self.onSelect = onSelect
    }

    public var body: some View {
        if settings.enabled {
            TaskDestroyerCardView(
                card: card,
                isSelected: isSelected,
                boardLabels: boardLabels,
                onSelect: onSelect
            )
        } else {
            // Standard card view - just a placeholder styled similarly
            // The actual app will use its own CardView here
            standardCardView
        }
    }

    private var standardCardView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(card.title)
                .font(.headline)
                .lineLimit(2)

            if !card.labels.isEmpty {
                HStack(spacing: 4) {
                    ForEach(card.labels.prefix(3), id: \.self) { labelId in
                        if let label = boardLabels.first(where: { $0.id == labelId }) {
                            Text(label.name)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color(hex: label.color).opacity(0.2))
                                .cornerRadius(4)
                        }
                    }
                }
            }

            if !card.body.isEmpty {
                Text(card.body.prefix(80) + (card.body.count > 80 ? "..." : ""))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(12)
        #if os(macOS)
        .background(Color(nsColor: .textBackgroundColor))
        #else
        .background(Color(uiColor: .secondarySystemBackground))
        #endif
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.accentColor : Color.gray.opacity(0.3), lineWidth: isSelected ? 2 : 1)
        )
        .onTapGesture {
            onSelect()
        }
    }
}

// MARK: - Preview

#if DEBUG
struct TaskDestroyerCardView_Previews: PreviewProvider {
    static let sampleCard: Card = Card(
        slug: "sample-card",
        title: "Implement TaskDestroyer Effects",
        column: "todo",
        position: "n",
        created: Date().addingTimeInterval(-10 * 24 * 60 * 60),  // 10 days old
        modified: Date(),
        labels: ["feature", "urgent"],
        body: "Add particle effects, screen shake, and sound effects when completing tasks."
    )

    static let sampleLabels: [CardLabel] = [
        CardLabel(id: "feature", name: "Feature", color: "#3498db"),
        CardLabel(id: "urgent", name: "Urgent", color: "#e74c3c"),
        CardLabel(id: "bug", name: "Bug", color: "#e67e22")
    ]

    static var previews: some View {
        VStack(spacing: 20) {
            // Fresh card
            TaskDestroyerCardView(
                card: Card(
                    slug: "fresh",
                    title: "Fresh Task",
                    column: "todo",
                    position: "n",
                    created: Date(),
                    modified: Date(),
                    labels: [],
                    body: ""
                ),
                isSelected: false,
                boardLabels: sampleLabels
            )

            // Rotting card
            TaskDestroyerCardView(
                card: sampleCard,
                isSelected: false,
                boardLabels: sampleLabels
            )

            // Selected card
            TaskDestroyerCardView(
                card: sampleCard,
                isSelected: true,
                boardLabels: sampleLabels
            )

            // Decomposing card
            TaskDestroyerCardView(
                card: Card(
                    slug: "decomposing",
                    title: "This has been sitting here for months",
                    column: "todo",
                    position: "n",
                    created: Date().addingTimeInterval(-60 * 24 * 60 * 60),
                    modified: Date(),
                    labels: ["bug"],
                    body: "Someone should really do something about this."
                ),
                isSelected: false,
                boardLabels: sampleLabels
            )
        }
        .padding(20)
        .frame(width: 300)
        .background(TaskDestroyerColors.void)
        .previewDisplayName("TaskDestroyer Cards")
    }
}
#endif
