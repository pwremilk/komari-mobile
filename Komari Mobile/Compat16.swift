//
//  Compat16.swift - iOS 16 compatibility shims (auto-added for ios16 build)
//

import SwiftUI

// Module-local replacement for SwiftUI.ContentUnavailableView (iOS 17+).
// Local declaration wins name lookup within this module.
struct ContentUnavailableView<Lbl: View, Desc: View, Act: View>: View {
    @ViewBuilder var label: () -> Lbl
    @ViewBuilder var description: () -> Desc
    @ViewBuilder var actions: () -> Act

    init(@ViewBuilder label: @escaping () -> Lbl,
         @ViewBuilder description: @escaping () -> Desc,
         @ViewBuilder actions: @escaping () -> Act) {
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

extension ContentUnavailableView where Desc == Text, Act == EmptyView {
    init(_ title: String, systemImage: String) {
        self.init(label: { SwiftUI.Label(title, systemImage: systemImage) },
                  description: { Text("") },
                  actions: { EmptyView() })
    }
}

extension ContentUnavailableView where Act == EmptyView {
    init(@ViewBuilder label: @escaping () -> Lbl,
         @ViewBuilder description: @escaping () -> Desc) {
        self.label = label
        self.description = description
        self.actions = { EmptyView() }
    }
}

extension View {
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
