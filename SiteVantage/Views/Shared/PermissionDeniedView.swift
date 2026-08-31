//
//  PermissionDeniedView.swift
//  SiteVantage
//
//  Shared "permission denied" explainer with a direct path to Settings.
//  Spec §8 requires denied camera/location/speech permissions to show a
//  clear in-app explanation rather than a silent failure.
//

import SwiftUI
import UIKit

struct PermissionDeniedView: View {
    let iconName: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: iconName)
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.title3.bold())
                .multilineTextAlignment(.center)
            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                Text("Open Settings")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .fieldTapTarget()
            .padding(.horizontal, 32)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
