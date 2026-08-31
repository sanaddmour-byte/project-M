//
//  ShareSheet.swift
//  SiteVantage
//
//  Thin wrapper around UIActivityViewController. This is the only export
//  path in this build — there is no server upload option.
//

import SwiftUI
import UIKit

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
