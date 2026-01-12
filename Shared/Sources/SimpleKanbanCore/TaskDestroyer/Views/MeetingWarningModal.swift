// MeetingWarningModal.swift
// Warning modal when users try to create tasks about meetings.
//
// Gently (or not so gently, depending on violence level) suggests
// that maybe, just maybe, that meeting could be an email.

import SwiftUI

// MARK: - Meeting Detector

/// Detects meeting-related keywords in task titles.
public struct MeetingDetector {

    /// Keywords that trigger the meeting warning.
    /// Note: "call" intentionally omitted - too many false positives (function call, api call)
    public static let keywords: Set<String> = [
        "meeting", "standup", "stand-up", "sync",
        "check-in", "checkin", "touchbase", "touch base",
        "retro", "retrospective", "planning", "refinement",
        "grooming", "ceremony", "1:1", "1-1", "one-on-one"
    ]

    /// Check if a title contains meeting-related keywords.
    ///
    /// - Parameter title: The task title to check.
    /// - Returns: true if the title contains a meeting keyword.
    public static func containsMeetingKeyword(_ title: String) -> Bool {
        let lowered: String = title.lowercased()
        return keywords.contains { lowered.contains($0) }
    }

    /// Get which keyword was detected (for display).
    ///
    /// - Parameter title: The task title to check.
    /// - Returns: The detected keyword, or nil if none found.
    public static func detectedKeyword(_ title: String) -> String? {
        let lowered: String = title.lowercased()
        return keywords.first { lowered.contains($0) }
    }
}

// MARK: - Meeting Warning Modal

/// Modal that appears when a user tries to create a meeting task.
///
/// Usage:
/// ```swift
/// .sheet(isPresented: $showMeetingWarning) {
///     MeetingWarningModal(
///         taskTitle: pendingTitle,
///         onConfirm: { createTaskAnyway() },
///         onCancel: { cancelTask() }
///     )
/// }
/// ```
public struct MeetingWarningModal: View {

    /// The title of the task being created.
    public let taskTitle: String

    /// Called when user confirms they want to create the meeting task anyway.
    public let onConfirm: () -> Void

    /// Called when user cancels and doesn't create the task.
    public let onCancel: () -> Void

    @ObservedObject private var settings: TaskDestroyerSettings = TaskDestroyerSettings.shared
    @Environment(\.dismiss) private var dismiss

    @State private var hasPlayedSound: Bool = false

    public init(taskTitle: String, onConfirm: @escaping () -> Void, onCancel: @escaping () -> Void) {
        self.taskTitle = taskTitle
        self.onConfirm = onConfirm
        self.onCancel = onCancel
    }

    public var body: some View {
        VStack(spacing: 24) {
            // Warning icon
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 48))
                .foregroundColor(TaskDestroyerColors.warning)

            // Header text
            Text(headerText)
                .font(TaskDestroyerTypography.heading)
                .foregroundColor(TaskDestroyerColors.warning)
                .multilineTextAlignment(.center)

            // Message
            Text(messageText)
                .font(TaskDestroyerTypography.body)
                .foregroundColor(TaskDestroyerColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            // Alternatives
            VStack(alignment: .leading, spacing: 8) {
                Text("Consider instead:")
                    .font(TaskDestroyerTypography.caption)
                    .foregroundColor(TaskDestroyerColors.textMuted)

                ForEach(alternatives, id: \.self) { alt in
                    HStack {
                        Image(systemName: "checkmark.circle")
                            .foregroundColor(TaskDestroyerColors.success)
                        Text(alt)
                            .font(TaskDestroyerTypography.body)
                            .foregroundColor(TaskDestroyerColors.textPrimary)
                    }
                }
            }
            .padding()
            .background(TaskDestroyerColors.elevated)
            .cornerRadius(8)

            // Buttons
            HStack(spacing: 16) {
                Button("CREATE ANYWAY") {
                    settings.meetingsNotPrevented += 1
                    onConfirm()
                    dismiss()
                }
                .buttonStyle(MeetingSecondaryButtonStyle())

                Button("YOU'RE RIGHT, CANCEL") {
                    settings.meetingsPrevented += 1
                    onCancel()
                    dismiss()
                }
                .buttonStyle(MeetingPrimaryButtonStyle())
            }
        }
        .padding(40)
        .background(TaskDestroyerColors.darkMatter)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(TaskDestroyerColors.warning, lineWidth: 2)
        )
        .onAppear {
            playWarningSound()
        }
    }

    // MARK: - Sound

    private func playWarningSound() {
        guard !hasPlayedSound else { return }
        hasPlayedSound = true

        // Play airhorn sound for meetings
        // ALWAYS MAX VOLUME. NO EXCEPTIONS. MEETINGS MUST BE PUNISHED.
        SoundManager.shared.play(.airhorn, volume: 1.0, ignoreSettings: true)
    }

    // MARK: - Content

    private var headerText: String {
        switch settings.violenceLevel {
        case .corporateSafe:
            return "Meeting Detected"
        case .maximumDestruction:
            return "OH HELL NO, A MEETING?"
        }
    }

    private var messageText: String {
        switch settings.violenceLevel {
        case .corporateSafe:
            return "We noticed you're creating a task about a meeting. Studies show most meetings could be emails."
        case .maximumDestruction:
            return "You're about to waste precious shipping time on \"\(taskTitle)\". The AGILE9000 gods are disappointed."
        }
    }

    private var alternatives: [String] {
        switch settings.violenceLevel {
        case .corporateSafe:
            return [
                "Send a brief email instead",
                "Post an update in Slack",
                "Just make the decision"
            ]
        case .maximumDestruction:
            return [
                "Send an email (3 sentences max)",
                "Just do the thing without discussing it",
                "Make the decision yourself",
                "Ship code instead of talking about code"
            ]
        }
    }
}

// MARK: - Button Styles

struct MeetingPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(TaskDestroyerTypography.button)
            .foregroundColor(TaskDestroyerColors.textPrimary)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(TaskDestroyerColors.success)
            .cornerRadius(8)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
    }
}

struct MeetingSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(TaskDestroyerTypography.button)
            .foregroundColor(TaskDestroyerColors.textSecondary)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(TaskDestroyerColors.elevated)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(TaskDestroyerColors.border, lineWidth: 1)
            )
            .cornerRadius(8)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
    }
}

// MARK: - Preview

#if DEBUG
struct MeetingWarningModal_Previews: PreviewProvider {
    static var previews: some View {
        MeetingWarningModal(
            taskTitle: "Weekly team sync meeting",
            onConfirm: {},
            onCancel: {}
        )
        .frame(width: 450)
        .padding()
        .background(Color.black)
    }
}
#endif
