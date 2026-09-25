//
//  Compat16.swift — iOS 16 compatibility shims (auto-added for ios16 build)
//  Provides LegacyUnavailableView (drop-in for ContentUnavailableView)
//  and a widgetBG() modifier (containerBackground is iOS17+).
//

import SwiftUI

struct LegacyUnavailableView<Label: View, Description: View, Actions: View>: View {
    @ViewBuilder var label: () -> Label
    @ViewBuilder var description: () -> Description
    @ViewBuilder var actions: () -> Actions

    var body: some View {
        VStack(spacing: 12) {
            label()
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
            description()
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            actions()
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
    }
}

// simple (title, systemImage) init
extension LegacyUnavailableView where Description == Text, Actions == EmptyView {
    init(_ title: String, systemImage: String) {
        label = { Label(title, systemImage: systemImage) }
        description = { Text("") }
        actions = { EmptyView() }
    }
}

// label + description, no actions
extension LegacyUnavailableView where Actions == EmptyView {
    init(
        @ViewBuilder label: @escaping () -> Label,
        @ViewBuilder description: @escaping () -> Description
    ) {
        self.label = label
        self.description = description
        self.actions = { EmptyView() }
    }
}

extension View {
    /// containerBackground(for: .widget) is iOS 17+; no-op below.
    @ViewBuilder func widgetBG() -> some View {
        if #available(iOS 17.0, *) {
            self.containerBackground(.fill.tertiary, for: .widget)
        } else {
            self
        }
    }

    @ViewBuilder func iconBounce(_ v: Bool) -> some View {
        if #available(iOS 17.0, *) {
            self.symbolEffect(.bounce, value: v)
        } else {
            self
        }
    }

    @ViewBuilder func iconReplace() -> some View {
        if #available(iOS 17.0, *) {
            self.contentTransition(.symbolEffect(.replace))
        } else {
            self
        }
    }
}

// Shadow SwiftUI.ContentUnavailableView (iOS 17) with a module-local iOS16 build.
// Same generic name; local declaration wins name lookup within this module.
@available(iOS, introduced: 16.0, deprecated: 100.0)
struct ContentUnavailableView<Label: View, Description: View, Actions: View>: View {
    @ViewBuilder var label: () -> Label
    @ViewBuilder var description: () -> Description
    @ViewBuilder var actions: () -> Actions

    init(@ViewBuilder label: () -> Label,
         @ViewBuilder description: () -> Description,
         @ViewBuilder actions: () -> Actions) {
        self.label = label
        self.description = description
        self.actions = actions
    }

    var body: some View {
        VStack(spacing: 12) {
            label()
                .font(.title2)
                .fontWeight(.semibold)
            description()
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            actions()
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
    }
}

extension ContentUnavailableView where Description == Text, Actions == EmptyView {
    init(_ title: String, systemImage: String) {
        self.init(label: { Label(title, systemImage: systemImage) },
                  description: { Text("") },
                  actions: { EmptyView() })
    }
}

extension ContentUnavailableView where Actions == EmptyView {
    init(@ViewBuilder label: () -> Label,
         @ViewBuilder description: () -> Description) {
        self.label = label
        self.description = description
        self.actions = { EmptyView() }
    }
}
