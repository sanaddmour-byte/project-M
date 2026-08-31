//
//  Theme.swift
//  SiteVantage
//
//  Minimum touch-target and a high-contrast palette for gloved/sunlight
//  field use, per spec §6. High contrast is a user toggle in Settings
//  (AppSettings.highContrastModeEnabled), read here via @Query so any view
//  in the tree can react to it without prop-drilling.
//

import SwiftUI

enum FieldTouchTarget {
    static let minimum: CGFloat = 44
}

struct FieldTapTarget: ViewModifier {
    func body(content: Content) -> some View {
        content
            .frame(minWidth: FieldTouchTarget.minimum, minHeight: FieldTouchTarget.minimum)
            .contentShape(Rectangle())
    }
}

extension View {
    /// Ensures a minimum 44x44pt hit target, per Apple HIG and this app's
    /// gloved-hand/sunlight requirement.
    func fieldTapTarget() -> some View {
        modifier(FieldTapTarget())
    }
}

enum FieldPalette {
    static func background(highContrast: Bool) -> Color {
        highContrast ? .black : Color(.systemGroupedBackground)
    }

    static func primaryText(highContrast: Bool) -> Color {
        highContrast ? .yellow : .primary
    }

    static func accent(highContrast: Bool) -> Color {
        highContrast ? .yellow : .accentColor
    }

    static func cardBackground(highContrast: Bool) -> Color {
        highContrast ? Color(white: 0.08) : Color(.secondarySystemGroupedBackground)
    }

    static func destructive(highContrast: Bool) -> Color {
        highContrast ? .orange : .red
    }
}
