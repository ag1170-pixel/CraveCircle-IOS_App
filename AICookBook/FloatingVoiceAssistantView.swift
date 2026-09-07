//
//  FloatingVoiceAssistantView.swift
//  CraveCircle (AICookBook)
//
//  Floating interactive chef mascot companion for hands-free cooking.
//  Bobs gently, winks, and displays speech status when the user says "Hey Crave".
//

import SwiftUI

struct FloatingVoiceAssistantView: View {
    @ObservedObject var voice: VoiceCommandController
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var isWinking = false
    @State private var isBobbing = false
    @State private var winkTimer: Timer?
    @State private var dragOffset: CGSize = .zero

    var body: some View {
        HStack(spacing: 10) {
            // Mascot Avatar with live wink & bob
            ZStack {
                Circle()
                    .fill(Color.white)
                    .frame(width: 52, height: 52)
                    .shadow(color: .black.opacity(0.12), radius: 6, x: 0, y: 3)

                Image(isWinking ? "ChefAssistantWink" : "ChefAssistantOpen")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 48, height: 48)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(voice.wakeActive ? AppTheme.accent : Color.white, lineWidth: voice.wakeActive ? 2 : 1))

                // Glow ring when "Hey Crave" is active
                if voice.wakeActive {
                    Circle()
                        .stroke(AppTheme.accent.opacity(0.6), lineWidth: 3)
                        .frame(width: 58, height: 58)
                        .scaleEffect(isBobbing ? 1.15 : 1.0)
                        .opacity(isBobbing ? 0.3 : 0.8)
                }
            }
            .offset(y: isBobbing ? -3 : 3)

            // Speech Bubble / Guidance
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(bubbleTitle)
                        .font(AppFont.body(13, weight: .bold))
                        .foregroundStyle(voice.wakeActive ? AppTheme.accentInk : AppTheme.textPrimary)

                    if voice.wakeActive {
                        Image(systemName: "waveform")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(AppTheme.accentInk)
                    }
                }

                Text(bubbleSubtitle)
                    .font(AppFont.body(11, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(voice.wakeActive ? AppTheme.accent.opacity(0.4) : AppTheme.hairline, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 3)
            .onTapGesture {
                if voice.permissionDenied {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .offset(x: dragOffset.width, y: dragOffset.height)
        .gesture(
            DragGesture()
                .onChanged { val in dragOffset = val.translation }
                .onEnded { _ in
                    withAnimation(AppMotion.snappy) {
                        dragOffset = .zero
                    }
                }
        )
        .onAppear {
            startAnimations()
        }
        .onDisappear {
            winkTimer?.invalidate()
        }
        .onChange(of: voice.wakeActive) { active in
            if active {
                // Happy wink when wake word is recognized!
                triggerWink(duration: 0.8)
            }
        }
    }

    private var bubbleTitle: String {
        if voice.permissionDenied {
            return "Mic / Speech Off"
        }
        if !voice.lastHeard.isEmpty && (voice.lastHeard == "Next" || voice.lastHeard == "Back") {
            return "\(voice.lastHeard) Step! ✨"
        }
        if voice.wakeActive {
            return "I'm listening!"
        }
        if !voice.isListening {
            return "Warming up…"
        }
        return "Hey Crave"
    }

    private var bubbleSubtitle: String {
        if voice.permissionDenied {
            return "Enable in Settings > CraveCircle"
        }
        if voice.wakeActive {
            return "Say “Next” or “Back”"
        }
        return "Say “Hey Crave” to activate"
    }

    private func startAnimations() {
        guard !reduceMotion else { return }
        withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
            isBobbing = true
        }

        winkTimer = Timer.scheduledTimer(withTimeInterval: 3.5, repeats: true) { _ in
            triggerWink(duration: 0.35)
        }
    }

    private func triggerWink(duration: Double) {
        withAnimation(.easeInOut(duration: 0.15)) {
            isWinking = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            withAnimation(.easeInOut(duration: 0.15)) {
                isWinking = false
            }
        }
    }
}
