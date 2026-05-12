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
        let session: AVCaptureSession

        init(previewLayer: AVCaptureVideoPreviewLayer) {
            // Unused, but kept for compatibility. We extract the session.
            self.session = previewLayer.session!
        }

        func makeUIView(context: Context) -> CameraPreviewView {
            let view = CameraPreviewView()
            view.videoPreviewLayer.session = session
            view.videoPreviewLayer.videoGravity = .resizeAspectFill
            return view
        }

        func updateUIView(_ uiView: CameraPreviewView, context: Context) {
        }
    }

    // MARK: - Custom UIView for Camera Preview

    class CameraPreviewView: UIView {
        override class var layerClass: AnyClass {
            return AVCaptureVideoPreviewLayer.self
        }
        
        var videoPreviewLayer: AVCaptureVideoPreviewLayer {
            return layer as! AVCaptureVideoPreviewLayer
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

struct SkeletonOverlay: View {
    let skeletonFrame: SkeletonOverlayFrame
    let isMirrored: Bool

    private let bodyConnections: [(Int, Int)] = [
        (0, 1), (0, 2),
        (1, 3), (2, 4),
        (5, 6),
        (5, 7), (7, 9),
        (6, 8), (8, 10),
        (5, 11), (6, 12),
        (11, 12),
        (11, 13), (13, 15),
        (12, 14), (14, 16)
    ]

    private let leftHandConnections: [(Int, Int)] = [
        (91, 92), (92, 93), (93, 94), (94, 95),
        (91, 96), (96, 97), (97, 98), (98, 99),
        (91, 100), (100, 101), (101, 102), (102, 103),
        (91, 104), (104, 105), (105, 106), (106, 107),
        (91, 108), (108, 109), (109, 110), (110, 111)
    ]

    private let rightHandConnections: [(Int, Int)] = [
        (112, 113), (113, 114), (114, 115), (115, 116),
        (112, 117), (117, 118), (118, 119), (119, 120),
        (112, 121), (121, 122), (122, 123), (123, 124),
        (112, 125), (125, 126), (126, 127), (127, 128),
        (112, 129), (129, 130), (130, 131), (131, 132)
    ]

    var body: some View {
        GeometryReader { _ in
            Canvas { context, size in
                let mappedPoints = mapPoints(to: size)
                drawConnections(bodyConnections, with: mappedPoints, color: Color(red: 0.2, green: 0.95, blue: 0.7), lineWidth: 2.5, in: &context)
                drawConnections(leftHandConnections, with: mappedPoints, color: Color(red: 1.0, green: 0.8, blue: 0.3), lineWidth: 1.6, in: &context)
                drawConnections(rightHandConnections, with: mappedPoints, color: Color(red: 0.35, green: 0.75, blue: 1.0), lineWidth: 1.6, in: &context)

                for point in mappedPoints where point.confidence > 0.15 {
                    let radius: CGFloat = point.isHandPoint ? 2.4 : 3.5
                    let rect = CGRect(x: point.location.x - radius, y: point.location.y - radius, width: radius * 2, height: radius * 2)
                    context.fill(Path(ellipseIn: rect), with: .color(point.color.opacity(0.95)))
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func mapPoints(to canvasSize: CGSize) -> [RenderedSkeletonPoint] {
        let sourceSize = skeletonFrame.sourceSize
        let scale = max(canvasSize.width / sourceSize.width, canvasSize.height / sourceSize.height)
        let scaledWidth = sourceSize.width * scale
        let scaledHeight = sourceSize.height * scale
        let xOffset = (canvasSize.width - scaledWidth) / 2
        let yOffset = (canvasSize.height - scaledHeight) / 2

        return skeletonFrame.keypoints.enumerated().map { index, point in
            let location = CGPoint(
                x: xOffset + point.x * scale,
                y: yOffset + point.y * scale
            )
            let isHandPoint = (91 ... 132).contains(index)
            let color = isHandPoint
                ? ((91 ... 111).contains(index) ? Color(red: 1.0, green: 0.8, blue: 0.3) : Color(red: 0.35, green: 0.75, blue: 1.0))
                : Color(red: 0.2, green: 0.95, blue: 0.7)
            return RenderedSkeletonPoint(location: location, confidence: point.confidence, color: color, isHandPoint: isHandPoint)
        }
    }

    private func drawConnections(
        _ connections: [(Int, Int)],
        with mappedPoints: [RenderedSkeletonPoint],
        color: Color,
        lineWidth: CGFloat,
        in context: inout GraphicsContext
    ) {
        for (startIndex, endIndex) in connections {
            guard mappedPoints.indices.contains(startIndex), mappedPoints.indices.contains(endIndex) else { continue }
            let start = mappedPoints[startIndex]
            let end = mappedPoints[endIndex]
            guard start.confidence > 0.15, end.confidence > 0.15 else { continue }

            var path = Path()
            path.move(to: start.location)
            path.addLine(to: end.location)
            context.stroke(path, with: .color(color.opacity(0.9)), lineWidth: lineWidth)
        }
    }
}

private struct RenderedSkeletonPoint {
    let location: CGPoint
    let confidence: CGFloat
    let color: Color
    let isHandPoint: Bool
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


