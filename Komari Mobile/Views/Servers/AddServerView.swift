//
//  AddServerView.swift
//  Komari Mobile
//
//  Created by Junhui Lou on 2/24/26.
//

import SwiftUI

struct AddServerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(KMState.self) private var state

    @State private var serverName: String = ""
    @State private var isAdding: Bool = false
    @State private var errorMessage: String?

    // Post-add state
    @State private var addedNode: AdminNodeData?
    @State private var showInstallCommand: Bool = false

    var body: some View {
        NavigationStack {
            Group {
                if showInstallCommand, let node = addedNode {
                    InstallCommandView(node: node)
                } else {
                    addServerForm
                }
            }
            .navigationTitle(showInstallCommand ? "Install Agent" : "Add Server")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    if #available(iOS 26.0, *) {
                        Button("Done", systemImage: "checkmark", role: .confirm) {
                            if showInstallCommand {
                                Task { await state.refreshAll() }
                            }
                            dismiss()
                        }
                    }
                    else {
                        Button("Done") {
                            if showInstallCommand {
                                Task { await state.refreshAll() }
                            }
                            dismiss()
                        }
                    }
                }
            }
        }
    }

    private var addServerForm: some View {
        Form {
            Section {
                TextField("Server Name", text: $serverName)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            } footer: {
                Text("Enter a name for the new server. You can leave it empty.")
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }

            Section {
                Button {
                    addServer()
                } label: {
                    HStack {
                        Spacer()
                        if isAdding {
                            ProgressView()
                        } else {
                            Text("Add Server")
                        }
                        Spacer()
                    }
                }
                .disabled(isAdding)
            }
        }
    }

    private func addServer() {
        isAdding = true
        errorMessage = nil

        Task {
            do {
                try await AdminHandler.addClient(name: serverName)
                let adminNodes = try await AdminHandler.getAdminNodes()

                // Find the newly added node (most recent by created_at, or last in list)
                if let newNode = adminNodes.sorted(by: {
                    ($0.createdAt ?? "") > ($1.createdAt ?? "")
                }).first(where: { serverName.isEmpty || $0.name == serverName }) ?? adminNodes.last {
                    addedNode = newNode
                    withAnimation {
                        showInstallCommand = true
                    }
                } else {
                    await state.refreshAll()
                    dismiss()
                }
            } catch {
                errorMessage = error.localizedDescription
            }
            isAdding = false
        }
    }
}

// MARK: - Install Command View

private enum InstallPlatform: String, CaseIterable {
    case linux = "Linux"
    case windows = "Windows"
    case macos = "macOS"
}

private struct InstallCommandView: View {
    let node: AdminNodeData
    @State private var platform: InstallPlatform = .linux
    @State private var copied: Bool = false

    // Options
    @State private var disableWebSsh: Bool = false
    @State private var disableAutoUpdate: Bool = false
    @State private var ignoreUnsafeCert: Bool = false
    @State private var memoryIncludeCache: Bool = false
    @State private var enableGhProxy: Bool = false
    @State private var ghProxy: String = ""
    @State private var enableCustomDir: Bool = false
    @State private var customDir: String = ""
    @State private var enableCustomServiceName: Bool = false
    @State private var customServiceName: String = ""
    @State private var enableIncludeNics: Bool = false
    @State private var includeNics: String = ""
    @State private var enableExcludeNics: Bool = false
    @State private var excludeNics: String = ""
    @State private var enableIncludeMountpoints: Bool = false
    @State private var includeMountpoints: String = ""
    @State private var enableMonthRotate: Bool = false
    @State private var monthRotate: String = "1"

    @State private var showOptions: Bool = false

    var body: some View {
        Form {
            Section("Server") {
                LabeledContent("Name", value: node.name.isEmpty ? "(Unnamed)" : node.name)
                LabeledContent("UUID", value: node.uuid)
                if let token = node.token, !token.isEmpty {
                    LabeledContent("Token") {
                        Text(token)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
            }

            Section("Platform") {
                Picker("Platform", selection: $platform) {
                    ForEach(InstallPlatform.allCases, id: \.self) { p in
                        Text(p.rawValue).tag(p)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section {
                DisclosureGroup("Install Options", isExpanded: $showOptions) {
                    Toggle("Disable Web SSH", isOn: $disableWebSsh)
                    Toggle("Disable Auto Update", isOn: $disableAutoUpdate)
                    Toggle("Ignore Unsafe Cert", isOn: $ignoreUnsafeCert)
                    Toggle("Memory Include Cache", isOn: $memoryIncludeCache)

                    Toggle("GitHub Proxy", isOn: $enableGhProxy)
                    if enableGhProxy {
                        TextField("Proxy", text: $ghProxy)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.URL)
                    }

                    Toggle("Custom Install Directory", isOn: $enableCustomDir)
                    if enableCustomDir {
                        TextField("/opt/komari-agent", text: $customDir)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }

                    Toggle("Custom Service Name", isOn: $enableCustomServiceName)
                    if enableCustomServiceName {
                        TextField("komari-agent", text: $customServiceName)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }

                    Toggle("Include NICs", isOn: $enableIncludeNics)
                    if enableIncludeNics {
                        TextField("eth0,eth1", text: $includeNics)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }

                    Toggle("Exclude NICs", isOn: $enableExcludeNics)
                    if enableExcludeNics {
                        TextField("lo", text: $excludeNics)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }

                    Toggle("Include Mount Points", isOn: $enableIncludeMountpoints)
                    if enableIncludeMountpoints {
                        TextField("/;/home;/var", text: $includeMountpoints)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }

                    Toggle("Monthly Network Reset", isOn: $enableMonthRotate)
                    if enableMonthRotate {
                        TextField("Day (1-31)", text: $monthRotate)
                            .keyboardType(.numberPad)
                    }
                }
            }

            Section("Command") {
                Text(generatedCommand)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)

                Button {
                    UIPasteboard.general.string = generatedCommand
                    withAnimation {
                        copied = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation {
                            copied = false
                        }
                    }
                } label: {
                    HStack {
                        Spacer()
                        Label(copied ? "Copied!" : "Copy Command", systemImage: copied ? "checkmark" : "doc.on.doc")
                            .iconReplace()
                        Spacer()
                    }
                }
            }
        }
    }

    private var generatedCommand: String {
        let host = KMCore.getBaseURL()
        let token = node.token ?? ""

        var args = ["-e", host, "-t", token]

        if disableWebSsh { args.append("--disable-web-ssh") }
        if disableAutoUpdate { args.append("--disable-auto-update") }
        if ignoreUnsafeCert { args.append("--ignore-unsafe-cert") }
        if memoryIncludeCache { args.append("--memory-include-cache") }

        if enableGhProxy, !ghProxy.isEmpty {
            let finalURL = ghProxy.hasPrefix("http") ? ghProxy : "http://\(ghProxy)"
            args.append(contentsOf: ["--install-ghproxy", finalURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))])
        }
        if enableCustomDir, !customDir.isEmpty {
            args.append(contentsOf: ["--install-dir", customDir])
        }
        if enableCustomServiceName, !customServiceName.isEmpty {
            args.append(contentsOf: ["--install-service-name", customServiceName])
        }
        if enableIncludeNics, !includeNics.isEmpty {
            args.append(contentsOf: ["--include-nics", includeNics])
        }
        if enableExcludeNics, !excludeNics.isEmpty {
            args.append(contentsOf: ["--exclude-nics", excludeNics])
        }
        if enableIncludeMountpoints, !includeMountpoints.isEmpty {
            args.append(contentsOf: ["--include-mountpoint", includeMountpoints])
        }
        if enableMonthRotate {
            let day = monthRotate.trimmingCharacters(in: .whitespaces).isEmpty ? "1" : monthRotate.trimmingCharacters(in: .whitespaces)
            args.append(contentsOf: ["--month-rotate", day])
        }

        let scriptBase = "https://raw.githubusercontent.com/komari-monitor/komari-agent/refs/heads/main"
        var scriptURL: String

        switch platform {
        case .linux:
            scriptURL = "\(scriptBase)/install.sh"
            if enableGhProxy, !ghProxy.isEmpty {
                scriptURL = applyGhProxy(to: scriptURL)
            }
            return "wget -qO- \(scriptURL) | sudo bash -s -- \(args.joined(separator: " "))"

        case .windows:
            scriptURL = "\(scriptBase)/install.ps1"
            if enableGhProxy, !ghProxy.isEmpty {
                scriptURL = applyGhProxy(to: scriptURL)
            }
            let argsStr = args.map { "'\($0)'" }.joined(separator: " ")
            return "powershell.exe -NoProfile -ExecutionPolicy Bypass -Command \"iwr '\(scriptURL)' -UseBasicParsing -OutFile 'install.ps1'; & '.\\install.ps1' \(argsStr)\""

        case .macos:
            scriptURL = "\(scriptBase)/install.sh"
            if enableGhProxy, !ghProxy.isEmpty {
                scriptURL = applyGhProxy(to: scriptURL)
            }
            return "zsh <(curl -sL \(scriptURL)) \(args.joined(separator: " "))"
        }
    }

    private func applyGhProxy(to url: String) -> String {
        let stripped = url.replacingOccurrences(of: "https://", with: "")
        let proxy = ghProxy.hasSuffix("/") ? ghProxy : "\(ghProxy)/"
        let base = proxy.hasPrefix("http") ? proxy : "http://\(proxy)"
        return "\(base)\(stripped)"
    }
}
