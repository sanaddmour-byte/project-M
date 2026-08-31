//
//  SignaturePadView.swift
//  SiteVantage
//
//  Canvas-based signature capture (no PencilKit dependency needed since we
//  only need finger/stylus strokes rendered to a flat image, not markup
//  tools). Renders to a UIImage via ImageRenderer so the caller can persist
//  a rasterized image into signatureImageData, per spec §4 screen 6 Path A.
//

import SwiftUI

struct SignatureCanvasContent: View {
    let strokes: [[CGPoint]]
    var size: CGSize

    var body: some View {
        Canvas { context, canvasSize in
            context.fill(Path(CGRect(origin: .zero, size: canvasSize)), with: .color(.white))
            for stroke in strokes {
                guard stroke.count > 1 else { continue }
                var path = Path()
                path.move(to: stroke[0])
                for point in stroke.dropFirst() {
                    path.addLine(to: point)
                }
                context.stroke(path, with: .color(.black), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
            }
        }
        .frame(width: size.width, height: size.height)
        .background(Color.white)
    }
}

struct SignaturePadView: View {
    @Binding var strokes: [[CGPoint]]
    let canvasSize: CGSize

    @State private var currentStroke: [CGPoint] = []

    var body: some View {
        SignatureCanvasContent(strokes: strokes + (currentStroke.isEmpty ? [] : [currentStroke]), size: canvasSize)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(.systemGray3), lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        currentStroke.append(value.location)
                    }
                    .onEnded { _ in
                        if !currentStroke.isEmpty {
                            strokes.append(currentStroke)
                            currentStroke = []
                        }
                    }
            )
    }
}
