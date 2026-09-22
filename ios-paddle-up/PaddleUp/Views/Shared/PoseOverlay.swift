//
//  PoseOverlay.swift
//  PaddleUp
//
//  Live skeleton overlay drawn over the camera feed and replay clips.
//

import SwiftUI

struct PoseSkeletonOverlay: View {
    let frame: PoseFrame?
    var color: Color = PUColor.lime
    var lineWidth: CGFloat = 3
    var jointRadius: CGFloat = 5
    var showsJoints: Bool = true

    private static let bones: [(PoseJoint, PoseJoint)] = [
        (.leftShoulder, .rightShoulder),
        (.leftShoulder, .leftElbow), (.leftElbow, .leftWrist),
        (.rightShoulder, .rightElbow), (.rightElbow, .rightWrist),
        (.leftShoulder, .leftHip), (.rightShoulder, .rightHip),
        (.leftHip, .rightHip),
        (.leftHip, .leftKnee), (.leftKnee, .leftAnkle),
        (.rightHip, .rightKnee), (.rightKnee, .rightAnkle),
        (.nose, .neck), (.neck, .leftShoulder), (.neck, .rightShoulder)
    ]

    var body: some View {
        Canvas { context, size in
            guard let frame else { return }

            for (start, end) in Self.bones {
                guard let a = frame.point(start, minConfidence: 0.25),
                      let b = frame.point(end, minConfidence: 0.25) else { continue }
                var path = Path()
                path.move(to: CGPoint(x: a.x * size.width, y: a.y * size.height))
                path.addLine(to: CGPoint(x: b.x * size.width, y: b.y * size.height))
                context.stroke(path, with: .color(color),
                               style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            }

            guard showsJoints else { return }
            for (_, point) in frame.joints where point.confidence > 0.25 {
                let rect = CGRect(
                    x: point.x * size.width - jointRadius,
                    y: point.y * size.height - jointRadius,
                    width: jointRadius * 2,
                    height: jointRadius * 2
                )
                context.fill(Circle().path(in: rect), with: .color(color))
            }
        }
        .allowsHitTesting(false)
    }
}

/// Framing brackets drawn at the corners of the capture area.
struct FramingBrackets: View {
    var color: Color = PUColor.lime
    var isValid: Bool = true

    var body: some View {
        GeometryReader { geo in
            let length = min(geo.size.width, geo.size.height) * 0.09
            ZStack {
                bracket(length: length, corners: [.topLeading])
                bracket(length: length, corners: [.topTrailing])
                bracket(length: length, corners: [.bottomLeading])
                bracket(length: length, corners: [.bottomTrailing])
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .foregroundStyle(isValid ? color : PUColor.amber)
        .allowsHitTesting(false)
    }

    private enum Corner { case topLeading, topTrailing, bottomLeading, bottomTrailing }

    private func bracket(length: CGFloat, corners: [Corner]) -> some View {
        GeometryReader { geo in
            Path { path in
                let inset: CGFloat = 16
                let w = geo.size.width, h = geo.size.height
                for corner in corners {
                    switch corner {
                    case .topLeading:
                        path.move(to: CGPoint(x: inset, y: inset + length))
                        path.addLine(to: CGPoint(x: inset, y: inset))
                        path.addLine(to: CGPoint(x: inset + length, y: inset))
                    case .topTrailing:
                        path.move(to: CGPoint(x: w - inset - length, y: inset))
                        path.addLine(to: CGPoint(x: w - inset, y: inset))
                        path.addLine(to: CGPoint(x: w - inset, y: inset + length))
                    case .bottomLeading:
                        path.move(to: CGPoint(x: inset, y: h - inset - length))
                        path.addLine(to: CGPoint(x: inset, y: h - inset))
                        path.addLine(to: CGPoint(x: inset + length, y: h - inset))
                    case .bottomTrailing:
                        path.move(to: CGPoint(x: w - inset - length, y: h - inset))
                        path.addLine(to: CGPoint(x: w - inset, y: h - inset))
                        path.addLine(to: CGPoint(x: w - inset, y: h - inset - length))
                    }
                }
            }
            .stroke(style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
        }
    }
}
