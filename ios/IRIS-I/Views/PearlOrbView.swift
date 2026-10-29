//
//  PearlOrbView.swift
//  IRIS-I
//
//  Photorealistic 3D Pearlescent Liquid Glass Sphere inspired by Apple design language.
//  Features multi-layered optical depth, specular gloss crests, internal chromatic caustics,
//  subtle idle breathing, and audio-reactive acoustic ripple rings.
//

import SwiftUI

public struct PearlOrbView: View {
    public let size: CGFloat
    public let audioLevel: Float
    public let isListening: Bool
    public let isThinking: Bool
    public let action: (() -> Void)?

    @State private var breathingPhase: Double = 0.0
    @State private var shimmerAngle: Double = 0.0
    @State private var isPressed: Bool = false

    public init(
        size: CGFloat = 240,
        audioLevel: Float = 0.0,
        isListening: Bool = false,
        isThinking: Bool = false,
        action: (() -> Void)? = nil
    ) {
        self.size = size
        self.audioLevel = audioLevel
        self.isListening = isListening
        self.isThinking = isThinking
        self.action = action
    }

    public var body: some View {
        Button {
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            action?()
        } label: {
            ZStack {
                // 1. Expanding Acoustic Ripple Waves (Active when listening)
                if isListening {
                    ForEach(0..<3) { i in
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.65, green: 0.85, blue: 1.0).opacity(0.35 - Double(i) * 0.10),
                                        Color(red: 0.90, green: 0.75, blue: 1.0).opacity(0.20 - Double(i) * 0.06),
                                        Color.clear
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2.0 - CGFloat(i) * 0.5
                            )
                            .frame(
                                width: size * (1.15 + CGFloat(i) * 0.22 + CGFloat(audioLevel) * 0.4),
                                height: size * (1.15 + CGFloat(i) * 0.22 + CGFloat(audioLevel) * 0.4)
                            )
                            .blur(radius: CGFloat(i) * 1.5)
                            .animation(.easeOut(duration: 0.2), value: audioLevel)
                    }
                }

                // 2. Ambient Ground Soft Shadow (Creates elevation from the surface)
                Circle()
                    .fill(Color.black.opacity(0.14))
                    .frame(width: size * 0.82, height: size * 0.82)
                    .blur(radius: size * 0.12)
                    .offset(y: size * 0.12)

                // 3. Diffuse Pearlescent Core (Base optical sphere)
                Circle()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(stops: [
                                .init(color: Color(white: 0.99), location: 0.0),
                                .init(color: Color(white: 0.95), location: 0.45),
                                .init(color: Color(red: 0.88, green: 0.90, blue: 0.94), location: 0.78),
                                .init(color: Color(red: 0.76, green: 0.79, blue: 0.85), location: 1.0)
                            ]),
                            center: UnitPoint(x: 0.35, y: 0.30),
                            startRadius: size * 0.05,
                            endRadius: size * 0.55
                        )
                    )
                    .frame(width: size, height: size)

                // 4. Internal Opalescent Chromatic Caustics (Subtle pastel iridescence)
                Circle()
                    .fill(
                        AngularGradient(
                            gradient: Gradient(colors: [
                                Color(red: 1.00, green: 0.82, blue: 0.90).opacity(0.35), // Rose
                                Color(red: 0.80, green: 0.92, blue: 1.00).opacity(0.40), // Cyan
                                Color(red: 0.92, green: 0.84, blue: 1.00).opacity(0.35), // Lavender
                                Color(red: 0.98, green: 0.94, blue: 0.82).opacity(0.30), // Opal Gold
                                Color(red: 1.00, green: 0.82, blue: 0.90).opacity(0.35)  // Rose
                            ]),
                            center: .center,
                            angle: .degrees(shimmerAngle)
                        )
                    )
                    .frame(width: size * 0.92, height: size * 0.92)
                    .blur(radius: size * 0.08)
                    .blendMode(.overlay)

                // 5. Internal Ambient Occlusion Depth Ring
                Circle()
                    .strokeBorder(
                        LinearGradient(
                            stops: [
                                .init(color: Color.white.opacity(0.9), location: 0.0),
                                .init(color: Color.white.opacity(0.3), location: 0.3),
                                .init(color: Color.black.opacity(0.18), location: 0.7),
                                .init(color: Color.black.opacity(0.40), location: 1.0)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: size * 0.04
                    )
                    .frame(width: size, height: size)
                    .blur(radius: size * 0.015)

                // 6. Secondary Warm Ground Bounce Light (Simulates reflection from table/hand)
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(red: 0.95, green: 0.92, blue: 0.85).opacity(0.55),
                                Color.clear
                            ],
                            center: UnitPoint(x: 0.65, y: 0.85),
                            startRadius: size * 0.05,
                            endRadius: size * 0.35
                        )
                    )
                    .frame(width: size, height: size)
                    .blendMode(.screen)

                // 7. Razor-Sharp Top-Left Specular Key Light (Apple Key Light Crest)
                Ellipse()
                    .fill(
                        LinearGradient(
                            stops: [
                                .init(color: Color.white.opacity(0.95), location: 0.0),
                                .init(color: Color.white.opacity(0.40), location: 0.5),
                                .init(color: Color.white.opacity(0.0), location: 1.0)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: size * 0.44, height: size * 0.28)
                    .rotationEffect(.degrees(-32))
                    .offset(x: -size * 0.16, y: -size * 0.18)
                    .blur(radius: size * 0.01)

                // 8. Secondary Pinpoint Specular Glint
                Circle()
                    .fill(Color.white.opacity(0.98))
                    .frame(width: size * 0.065, height: size * 0.065)
                    .offset(x: -size * 0.22, y: -size * 0.22)
                    .blur(radius: 0.5)

                // 9. Outer Razor-Thin Chromatic Rim
                Circle()
                    .strokeBorder(
                        LinearGradient(
                            stops: [
                                .init(color: Color.white.opacity(0.95), location: 0.0),
                                .init(color: Color(red: 0.6, green: 0.9, blue: 1.0).opacity(0.7), location: 0.35),
                                .init(color: Color(red: 0.9, green: 0.6, blue: 1.0).opacity(0.7), location: 0.65),
                                .init(color: Color.white.opacity(0.4), location: 1.0)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.2
                    )
                    .frame(width: size, height: size)
            }
            .scaleEffect(isPressed ? 0.94 : (isListening ? 1.0 + CGFloat(audioLevel * 0.12) : 1.0 + CGFloat(sin(breathingPhase) * 0.02)))
            .animation(.spring(response: 0.28, dampingFraction: 0.65), value: isPressed)
            .animation(.easeOut(duration: 0.08), value: audioLevel)
        }
        .buttonStyle(PearlOrbButtonStyle(isPressed: $isPressed))
        .onAppear {
            withAnimation(.easeInOut(duration: 3.2).repeatForever(autoreverses: true)) {
                breathingPhase = .pi * 2
            }
            withAnimation(.linear(duration: 16.0).repeatForever(autoreverses: false)) {
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
        Color(white: 0.96).ignoresSafeArea()
        PearlOrbView(size: 240, audioLevel: 0.2, isListening: true)
    }
}
