//
//  PearlOrbView.swift
//  IRIS-I
//
//  Photorealistic 3D Pearlescent Liquid Glass Sphere inspired by Apple design language.
//  Features multi-layered optical depth, specular gloss crests, internal chromatic caustics,
//  subtle idle breathing, audio-reactive acoustic ripple rings, and dynamic state reactivity.
//

import SwiftUI

public struct PearlOrbView: View {
    public let size: CGFloat
    public let audioLevel: Float
    public let isListening: Bool
    public let isThinking: Bool
    public let isResponding: Bool
    public let isError: Bool
    public let action: (() -> Void)?

    @State private var breathingPhase: Double = 0.0
    @State private var shimmerAngle: Double = 0.0
    @State private var pulsePhase: Double = 0.0
    @State private var isPressed: Bool = false

    public init(
        size: CGFloat = 240,
        audioLevel: Float = 0.0,
        isListening: Bool = false,
        isThinking: Bool = false,
        isResponding: Bool = false,
        isError: Bool = false,
        action: (() -> Void)? = nil
    ) {
        self.size = size
        self.audioLevel = audioLevel
        self.isListening = isListening
        self.isThinking = isThinking
        self.isResponding = isResponding
        self.isError = isError
        self.action = action
    }

    public var body: some View {
        Button {
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            action?()
        } label: {
            ZStack {
                // 1. Multi-Layer Ambient Atmosphere Halo
                if isError {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.red.opacity(0.35), Color.orange.opacity(0.15), Color.clear],
                                center: .center,
                                startRadius: size * 0.2,
                                endRadius: size * 0.7
                            )
                        )
                        .frame(width: size * 1.4, height: size * 1.4)
                        .blur(radius: size * 0.1)
                } else if isListening {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color(red: 0.38, green: 0.65, blue: 1.00).opacity(0.40 + Double(audioLevel) * 0.25),
                                    Color(red: 0.75, green: 0.52, blue: 1.00).opacity(0.25),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: size * 0.2,
                                endRadius: size * 0.75
                            )
                        )
                        .frame(width: size * 1.5, height: size * 1.5)
                        .blur(radius: size * 0.12)
                } else if isThinking {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color(red: 0.60, green: 0.40, blue: 1.00).opacity(0.40),
                                    Color(red: 0.20, green: 0.80, blue: 1.00).opacity(0.20),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: size * 0.2,
                                endRadius: size * 0.7
                            )
                        )
                        .frame(width: size * 1.4, height: size * 1.4)
                        .blur(radius: size * 0.1)
                } else {
                    // Idle gentle iridescent glow
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color(red: 0.50, green: 0.75, blue: 1.00).opacity(0.22),
                                    Color(red: 0.80, green: 0.65, blue: 1.00).opacity(0.18),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: size * 0.25,
                                endRadius: size * 0.68
                            )
                        )
                        .frame(width: size * 1.35, height: size * 1.35)
                        .blur(radius: size * 0.14)
                }

                // 2. Expanding Acoustic Ripple Waves (Active when listening)
                if isListening {
                    ForEach(0..<3) { i in
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.40, green: 0.70, blue: 1.00).opacity(0.45 - Double(i) * 0.12),
                                        Color(red: 0.85, green: 0.55, blue: 1.00).opacity(0.30 - Double(i) * 0.08),
                                        Color.clear
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2.2 - CGFloat(i) * 0.5
                            )
                            .frame(
                                width: size * (1.12 + CGFloat(i) * 0.20 + CGFloat(audioLevel) * 0.35),
                                height: size * (1.12 + CGFloat(i) * 0.20 + CGFloat(audioLevel) * 0.35)
                            )
                            .blur(radius: CGFloat(i) * 1.2)
                            .animation(.easeOut(duration: 0.15), value: audioLevel)
                    }
                }

                // 3. Ground Occlusion Shadow
                Circle()
                    .fill(Color.black.opacity(0.10))
                    .frame(width: size * 0.85, height: size * 0.85)
                    .blur(radius: size * 0.10)
                    .offset(y: size * 0.10)

                // 4. Base Pearlescent Volume Sphere
                Circle()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(stops: [
                                .init(color: Color.white, location: 0.0),
                                .init(color: Color(red: 0.94, green: 0.96, blue: 0.99), location: 0.30),
                                .init(color: Color(red: 0.85, green: 0.89, blue: 0.97), location: 0.60),
                                .init(color: Color(red: 0.72, green: 0.78, blue: 0.92), location: 0.85),
                                .init(color: Color(red: 0.58, green: 0.64, blue: 0.82), location: 1.0)
                            ]),
                            center: UnitPoint(x: 0.35, y: 0.28),
                            startRadius: size * 0.02,
                            endRadius: size * 0.58
                        )
                    )
                    .frame(width: size, height: size)

                // 5. Iridescent Violet-Blue Chromatic Caustics
                Circle()
                    .fill(
                        AngularGradient(
                            gradient: Gradient(colors: [
                                Color(red: 0.60, green: 0.80, blue: 1.00).opacity(0.65), // Soft Cyan
                                Color(red: 0.85, green: 0.65, blue: 1.00).opacity(0.60), // Lavender
                                Color(red: 1.00, green: 0.75, blue: 0.85).opacity(0.55), // Rose
                                Color(red: 0.75, green: 0.85, blue: 1.00).opacity(0.60), // Ice Blue
                                Color(red: 0.80, green: 0.60, blue: 0.95).opacity(0.65), // Violet
                                Color(red: 0.60, green: 0.80, blue: 1.00).opacity(0.65)  // Soft Cyan
                            ]),
                            center: .center,
                            angle: .degrees(shimmerAngle)
                        )
                    )
                    .frame(width: size * 0.96, height: size * 0.96)
                    .blur(radius: size * 0.05)
                    .blendMode(.colorDodge)

                // 6. Internal Light Refraction Ring
                Circle()
                    .strokeBorder(
                        LinearGradient(
                            stops: [
                                .init(color: Color.white.opacity(0.95), location: 0.0),
                                .init(color: Color(red: 0.70, green: 0.85, blue: 1.00).opacity(0.75), location: 0.25),
                                .init(color: Color(red: 0.85, green: 0.70, blue: 1.00).opacity(0.60), location: 0.60),
                                .init(color: Color.black.opacity(0.20), location: 1.0)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: size * 0.03
                    )
                    .frame(width: size, height: size)

                // 7. Ground Bounce Luminous Reflection
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(red: 0.80, green: 0.85, blue: 1.00).opacity(0.40),
                                Color.clear
                            ],
                            center: UnitPoint(x: 0.65, y: 0.82),
                            startRadius: size * 0.05,
                            endRadius: size * 0.35
                        )
                    )
                    .frame(width: size, height: size)
                    .blendMode(.screen)

                // 8. Razor-Sharp Apple Key Light Crest (Top-Left Specular)
                Ellipse()
                    .fill(
                        LinearGradient(
                            stops: [
                                .init(color: Color.white.opacity(0.98), location: 0.0),
                                .init(color: Color.white.opacity(0.45), location: 0.45),
                                .init(color: Color.white.opacity(0.0), location: 1.0)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: size * 0.42, height: size * 0.26)
                    .rotationEffect(.degrees(-32))
                    .offset(x: -size * 0.16, y: -size * 0.18)
                    .blur(radius: 0.8)

                // 9. Pinpoint Glint Reflection
                Circle()
                    .fill(Color.white)
                    .frame(width: size * 0.05, height: size * 0.05)
                    .offset(x: -size * 0.21, y: -size * 0.21)

                // 10. Razor-Thin Specular Glass Perimeter Outline
                Circle()
                    .strokeBorder(
                        LinearGradient(
                            stops: [
                                .init(color: Color.white.opacity(0.95), location: 0.0),
                                .init(color: Color(red: 0.70, green: 0.85, blue: 1.00).opacity(0.80), location: 0.35),
                                .init(color: Color(red: 0.85, green: 0.70, blue: 1.00).opacity(0.75), location: 0.70),
                                .init(color: Color.white.opacity(0.40), location: 1.0)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.2
                    )
                    .frame(width: size, height: size)
            }
            .scaleEffect(
                isPressed ? 0.94 : (
                    isListening ? 1.0 + CGFloat(audioLevel * 0.10) : (
                        isThinking ? 1.0 + CGFloat(sin(breathingPhase * 2.0) * 0.02) : (
                            1.0 + CGFloat(sin(breathingPhase) * 0.015)
                        )
                    )
                )
            )
            .animation(.spring(response: 0.28, dampingFraction: 0.65), value: isPressed)
            .animation(.easeOut(duration: 0.08), value: audioLevel)
        }
        .buttonStyle(PearlOrbButtonStyle(isPressed: $isPressed))
        .onAppear {
            withAnimation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true)) {
                breathingPhase = .pi * 2
            }
            withAnimation(.linear(duration: isThinking ? 6.0 : 18.0).repeatForever(autoreverses: false)) {
                shimmerAngle = 360
            }
        }
    }
}

fileprivate struct PearlOrbButtonStyle: ButtonStyle {
    @Binding var isPressed: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .onChange(of: configuration.isPressed) { _, pressed in
                self.isPressed = pressed
            }
    }
}

#Preview {
    ZStack {
        Color(red: 0.96, green: 0.97, blue: 0.99).ignoresSafeArea()
        PearlOrbView(size: 240, audioLevel: 0.2, isListening: true)
    }
}
