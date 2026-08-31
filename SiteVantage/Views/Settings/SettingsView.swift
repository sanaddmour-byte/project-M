//
//  SettingsView.swift
//  SiteVantage
//
//  App-level settings: current user (no multi-user auth in this build,
//  spec §7), high-contrast mode for gloved/sunlight field use (spec §6),
//  and the single-device evidentiary-chain disclaimer (spec §3).
//

import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var settings: AppSettings

    var body: some View {
        Form {
            Section("Current User") {
                TextField("Your Name", text: $settings.currentUserName)
                    .onChange(of: settings.currentUserName) { persist() }
                TextField("Your Title", text: $settings.currentUserTitle)
                    .onChange(of: settings.currentUserTitle) { persist() }
                Text("SiteVantage is single-foreman, single-device for this build \u{2014} there is no login system. This name labels tickets you create.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Accessibility") {
                Toggle("High-Contrast Mode", isOn: $settings.highContrastModeEnabled)
                    .fieldTapTarget()
                    .onChange(of: settings.highContrastModeEnabled) { persist() }
                Text("Higher-contrast colors and forced dark mode for gloved-hand, direct-sunlight field use.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("About This Build") {
                Text("This app stores everything locally on this device only. There is no backend server, no PM web dashboard, and no live ERP sync. Photo/ticket timestamps are the device's own clock — device-reported and unverified, not an independently notarized server receipt time. Notice drafts are never sent automatically; there is no email/SMS/portal send capability in this build.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func persist() {
        try? modelContext.save()
    }
}
