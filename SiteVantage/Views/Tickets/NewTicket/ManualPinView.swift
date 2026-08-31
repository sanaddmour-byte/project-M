//
//  ManualPinView.swift
//  SiteVantage
//
//  Shown when no GPS/network fix arrives within the ~5s timeout. The
//  foreman drops a pin on a simple pannable/zoomable placeholder floor-plan
//  grid to positively acknowledge "I am declaring my location manually"
//  rather than the app silently recording nothing. This build ships one
//  generic placeholder grid image since no real per-project floor plans
//  exist yet (see DECISIONS.md) -- the pin's on-image position is not
//  persisted as georeference data, only the act of confirming a manual pin
//  is recorded (source = .manualPin, confidence = .declared).
//

import SwiftUI
import UIKit

struct ManualPinView: View {
    var locationPermissionDenied: Bool = false
    let onConfirm: () -> Void
    let onCancel: () -> Void

    @State private var pinLocation: CGPoint?

    var body: some View {
        VStack(spacing: 16) {
            Text("No GPS Fix Available")
                .font(.title3.bold())
            if locationPermissionDenied {
                Text("Location access is denied for SiteVantage. Enable it in Settings for GPS-tagged evidence, or continue with a manual pin now.")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .buttonStyle(.bordered)
                .fieldTapTarget()
            }
            Text("Pinch to zoom and drag to pan, then tap the approximate location on this generic site grid. This confirms a manually declared location for this photo.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            GeometryReader { geometry in
                ScrollView([.horizontal, .vertical], showsIndicators: true) {
                    ZStack(alignment: .topLeading) {
                        Image("PlaceholderFloorplan")
                            .resizable()
                            .aspectRatio(1, contentMode: .fit)
                            .frame(width: geometry.size.width * 2, height: geometry.size.width * 2)
                            .onTapGesture { location in
                                pinLocation = location
                            }

                        if let pinLocation {
                            Image(systemName: "mappin.circle.fill")
                                .font(.system(size: 32))
                                .foregroundStyle(.red)
                                .offset(x: pinLocation.x - 16, y: pinLocation.y - 32)
                        }
                    }
                }
                .background(Color(.tertiarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal)

            HStack(spacing: 12) {
                Button("Cancel", action: onCancel)
                    .buttonStyle(.bordered)
                    .fieldTapTarget()
                Button {
                    onConfirm()
                } label: {
                    Text("Confirm Manual Pin")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .fieldTapTarget()
                .disabled(pinLocation == nil)
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
    }
}
