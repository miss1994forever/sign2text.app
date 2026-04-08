//
//  CameraPreview.swift
//  sign2text-app
//
//  Created by haojun on 2025/9/3.
//

import AVFoundation
import SwiftUI

// MARK: - Camera Preview UIViewRepresentable

#if canImport(UIKit)
    import UIKit

    struct CameraPreview: UIViewRepresentable {
        let previewLayer: AVCaptureVideoPreviewLayer

        init(previewLayer: AVCaptureVideoPreviewLayer) {
            self.previewLayer = previewLayer
            previewLayer.videoGravity = .resizeAspectFill
        }

        func makeUIView(context: Context) -> CameraPreviewView {
            let view = CameraPreviewView()
            // Add the layer as soon as the view is made
            view.layer.addSublayer(previewLayer)
            return view
        }

        func updateUIView(_ uiView: CameraPreviewView, context: Context) {
            // The frame will be updated by the layoutSubviews in the CameraPreviewView
        }
    }

    // MARK: - Custom UIView for Camera Preview

    class CameraPreviewView: UIView {
        override func layoutSubviews() {
            super.layoutSubviews()

            // Update all sublayers to match the view bounds
            layer.sublayers?.forEach { sublayer in
                if let previewLayer = sublayer as? AVCaptureVideoPreviewLayer {
                    previewLayer.frame = bounds
                }
            }
        }

        override class var layerClass: AnyClass {
            return CALayer.self
        }
    }

#else
    // MARK: - macOS Fallback

    struct CameraPreview: View {
        let previewLayer: AVCaptureVideoPreviewLayer
        @Binding var isActive: Bool

        var body: some View {
            Rectangle()
                .fill(Color.black)
                .overlay(
                    VStack {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.white.opacity(0.6))

                        Text("Camera Preview")
                            .foregroundColor(.white.opacity(0.8))
                            .font(.headline)

                        Text("Not Available on this platform")
                            .foregroundColor(.white.opacity(0.6))
                            .font(.caption)
                    }
                )
                .cornerRadius(12)
        }
    }
#endif

// MARK: - Camera Overlay Components

struct CameraOverlay: View {
    let isTranslating: Bool
    let isRecording: Bool
    let frameCount: Int
    let fps: Double

    var body: some View {
        VStack {
            // Top overlay - Status indicators
            HStack {
                // Translation status
                if isTranslating {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 12, height: 12)
                            .scaleEffect(isRecording ? 1.2 : 1.0)
                            .animation(
                                .easeInOut(duration: 0.6).repeatForever(autoreverses: true),
                                value: isRecording)

                        Text("Translating...")
                            .font(.caption.weight(.medium))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(20)
                } else {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color.gray)
                            .frame(width: 12, height: 12)

                        Text("Ready")
                            .font(.caption.weight(.medium))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(20)
                }

                Spacer()

                // Performance indicator
                if isTranslating {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("FPS: \(Int(fps))")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.8))

                        Text("Frames: \(frameCount)")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.black.opacity(0.5))
                    .cornerRadius(8)
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)

            Spacer()

            // Bottom overlay - Camera controls hint
            HStack {
                Spacer()

                VStack(spacing: 4) {
                    Image(systemName: "viewfinder")
                        .font(.title2)
                        .foregroundColor(.white.opacity(0.8))

                    Text("Keep hands in frame")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding()
                .background(Color.black.opacity(0.4))
                .cornerRadius(12)

                Spacer()
            }
            .padding(.bottom, 20)
        }
    }
}

// MARK: - Camera Focus Indicator

struct CameraFocusIndicator: View {
    @State private var isVisible = false
    @State private var scale: CGFloat = 1.0
    let position: CGPoint

    var body: some View {
        Circle()
            .stroke(Color.yellow, lineWidth: 2)
            .frame(width: 80, height: 80)
            .scaleEffect(scale)
            .opacity(isVisible ? 1.0 : 0.0)
            .position(position)
            .onAppear {
                showFocusAnimation()
            }
    }

    private func showFocusAnimation() {
        isVisible = true
        scale = 1.5

        withAnimation(.easeOut(duration: 0.2)) {
            scale = 1.0
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.easeOut(duration: 0.3)) {
                isVisible = false
            }
        }
    }
}

// MARK: - Camera Permission View

struct CameraPermissionView: View {
    let onSettingsButtonTapped: () -> Void
    let onRetryButtonTapped: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.85)
                .edgesIgnoringSafeArea(.all)

            VStack(spacing: 20) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.white)

                Text("Camera Permission Required")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)

                Text(
                    "SignScribe needs camera access to translate sign language into text in real-time. Please enable camera access in your device settings."
                )
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal)

                VStack(spacing: 12) {
                    Button(action: onSettingsButtonTapped) {
                        HStack {
                            Image(systemName: "gear")
                            Text("Open Settings")
                        }
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(width: 200, height: 50)
                        .background(Color.blue)
                        .cornerRadius(10)
                    }

                    Button(action: onRetryButtonTapped) {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                            Text("Try Again")
                        }
                        .fontWeight(.medium)
                        .foregroundColor(.blue)
                        .frame(width: 200, height: 50)
                        .background(Color.clear)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.blue, lineWidth: 1)
                        )
                    }
                }
                .padding(.top, 10)
            }
            .padding()
        }
    }
}

// MARK: - Preview Provider

struct CameraPreview_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            // Mock camera preview
            Rectangle()
                .fill(Color.black)
                .frame(height: 400)
                .overlay(
                    CameraOverlay(
                        isTranslating: true,
                        isRecording: true,
                        frameCount: 1250,
                        fps: 29.8
                    )
                )
                .cornerRadius(12)

            Spacer()

            // Permission view preview
            CameraPermissionView(
                onSettingsButtonTapped: {},
                onRetryButtonTapped: {}
            )
            .frame(height: 300)
        }
        .previewLayout(.sizeThatFits)
        .previewDisplayName("Camera Components")
    }
}


