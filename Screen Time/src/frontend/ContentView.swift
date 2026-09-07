//
//  ContentView.swift
//  Screen Time
//
//  Created by BUQI DONG on 31/8/2026.
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers

extension Color {
    static var dynamicBackground: Color {
        Color(NSColor(name: nil, dynamicProvider: { appearance in
            if appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua {
                return NSColor(Color(hex: "#083763"))
            } else {
                return NSColor(Color(hex: "#90D5FF"))
            }
        }))
    }
}

extension URL {
    /// Returns the exact, case-correct path on disk, resolving case mismatches.
    var realPathURL: URL {
        // Fetch the canonical path key directly from the file system
        if let resourceValues = try? self.resourceValues(forKeys: [.canonicalPathKey]),
           let canonicalPath = resourceValues.canonicalPath {
            return URL(fileURLWithPath: canonicalPath)
        }
        
        // Fallback: Resolving symlinks also normalizes path components
        return self.resolvingSymlinksInPath()
    }
    
    /// Returns the exact case-correct display name on disk (without extension)
    var realAppName: String {
        let exactURL = self.realPathURL
        return exactURL.deletingPathExtension().lastPathComponent
    }
}

struct AppItem: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let icon: NSImage
    let bundlePath: String
}

struct ContentView: View {
    @State private var selectedSeconds: Int = 25
    @State private var searchAppName: String = ""
    @State private var allowedApps: [AppItem] = []
    
    @State private var hours: String = ""
    @State private var minutes: String = ""
    @State private var seconds: String = ""
    
    @FocusState private var focusedField: TimeField?
    
    @StateObject private var manager = SessionManager()
    
    @State private var isShowingAlert: Bool = false
    @State private var alertMessage: String = ""
    @State private var alertTitle: String = ""
    
    enum TimeField {
        case hours, minutes, seconds
    }

    var body: some View {
        ZStack(alignment: .leading) {
            Color.dynamicBackground
                .ignoresSafeArea()
            
            VStack(alignment: .leading, spacing: 16) {
                Text("Screen Time")
                    .font(.title)
                    .bold()
                
                Text("Stop your procrastination now. Begin your productive day.")
                    .font(.headline)
                    .fontWeight(.regular)
                
                // Timer Selection Row
                HStack(spacing: 12) {
                    Text("Set your timer:")
                        .bold()
                    
                    HStack(spacing: 4) {
                        TextField("__", text: limitInput($hours, maxDigits: 2, maxValue: 23))
                            .focused($focusedField, equals: .hours)
                            .multilineTextAlignment(.center)
                            .frame(width: 45)
                            .textFieldStyle(.plain)
                            .onChange(of: hours) { _, newValue in
                                if newValue.count == 2 {
                                    focusedField = .minutes
                                }
                            }
                        
                        Text(":")
                        
                        TextField("__", text: limitInput($minutes, maxDigits: 2, maxValue: 59))
                            .focused($focusedField, equals: .minutes)
                            .multilineTextAlignment(.center)
                            .frame(width: 45)
                            .textFieldStyle(.plain)
                            .onChange(of: minutes) { oldValue, newValue in
                                if newValue.count == 2 {
                                    focusedField = .seconds
                                } else if newValue.isEmpty && oldValue.isEmpty {
                                    focusedField = .hours
                                }
                            }
                        
                        Text(":")
                        
                        TextField("__", text: limitInput($seconds, maxDigits: 2, maxValue: 59))
                            .focused($focusedField, equals: .seconds)
                            .multilineTextAlignment(.center)
                            .frame(width: 45)
                            .textFieldStyle(.plain)
                            .onChange(of: seconds) { oldValue, newValue in
                                if newValue.isEmpty && oldValue.isEmpty {
                                    focusedField = .minutes
                                }
                            }
                    }
                    .font(.system(size: 28, weight: .bold, design: .monospaced))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(Color.gray.opacity(0.15))
                    .cornerRadius(8)
                    
                    Spacer()
                }
                
                Divider()
                
                // Allowed Apps Section
                VStack(alignment: .leading, spacing: 8) {
                    Text("List of allowed applications:")
                        .bold()
                    
                    HStack {
                        TextField("Enter app name (e.g. Calculator)...", text: $searchAppName)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit {
                                addAppByName(searchAppName)
                            }
                        
                        Button("Add") {
                            addAppByName(searchAppName)
                        }
                        .disabled(searchAppName.trimmingCharacters(in: .whitespaces).isEmpty)
                        
                        Button("Browse...") {
                            openAppFileImporter()
                        }
                    }
                    
                    List {
                        ForEach(allowedApps) { app in
                            HStack(spacing: 10) {
                                Image(nsImage: app.icon)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 20, height: 20)
                                
                                Text(app.name)
                                
                                Spacer()
                                
                                Button(action: { removeApp(app) }) {
                                    Image(systemName: "trash")
                                        .foregroundColor(.red)
                                }
                                .buttonStyle(.borderless)
                            }
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .frame(maxHeight: 200)
                }
                
                Spacer()
                
                // TODO: this is debug code. in release, remove ability to stop focus session until timer runs out
                Button(action: {
                    if manager.isSessionActive {
                        #if DEBUG
                        manager.stopSession()
                        #endif
                    } else {
                        startSession()
                    }
                }) {
                    Text(manager.isSessionActive ? "Stop Focus Session (\(manager.timeRemaining)s)" :
                            "Start Focus Session")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .tint(manager.isSessionActive ? .red : .accentColor)
                .controlSize(.large)
            }
            .padding()
        }
        .frame(minWidth: 480, minHeight: 480)
        .alert(alertTitle, isPresented: $isShowingAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
        .onAppear {
            addAppByName("Xcode")
            addAppByName("Calculator")
        }
    }
    
    // Pure sanitizer binding - zero side-effects
    // Sanitizer binding - enforces both max digits and max numeric value
    private func limitInput(_ binding: Binding<String>, maxDigits: Int, maxValue: Int? = nil) -> Binding<String> {
        Binding(
            get: { binding.wrappedValue },
            set: { newValue in
                // Filter non-numeric characters and constrain string length
                let filtered = String(newValue.filter { $0.isNumber }.prefix(maxDigits))
                
                // Check max numerical value constraints
                if let max = maxValue, let numericValue = Int(filtered), numericValue > max {
                    // If input exceeds max allowed, cap it to maxValue string
                    binding.wrappedValue = String(max)
                } else {
                    binding.wrappedValue = filtered
                }
            }
        )
    }
    
    // MARK: - App Fetching Logic
    private func findAppURL(named appName: String) -> URL? {
        let appFilename = appName.hasSuffix(".app") ? appName : "\(appName).app"
        
        let home = FileManager.default.homeDirectoryForCurrentUser
        let searchPaths: [URL] = [
            // Standard system & user application folders
            FileManager.default.urls(for: .applicationDirectory, in: .localDomainMask).first,
            FileManager.default.urls(for: .applicationDirectory, in: .systemDomainMask).first,
            FileManager.default.urls(for: .applicationDirectory, in: .userDomainMask).first,
            
            // Utilities
            URL(fileURLWithPath: "/System/Applications/Utilities"),
            URL(fileURLWithPath: "/Applications/Utilities"),
            
            // Chrome PWAs and Web Applications
            home.appendingPathComponent("Applications/Chrome Apps.localized"),
            home.appendingPathComponent("Applications/Chrome Apps"),
            home.appendingPathComponent("Applications")
        ].compactMap { $0 }

        for baseURL in searchPaths {
            let candidateURL = baseURL.appendingPathComponent(appFilename)
            if FileManager.default.fileExists(atPath: candidateURL.path) {
                return candidateURL
            }
        }

        return nil
    }
    private func addAppByName(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        let appFilename = trimmed.hasSuffix(".app") ? trimmed : "\(trimmed).app"

        let foundURL = findAppURL(named: appFilename)

        if let rawAppURL = foundURL {
            // Resolve the exact case-correct URL from disk
            let appURL = rawAppURL.realPathURL
            
            let appIcon = NSWorkspace.shared.icon(forFile: appURL.path)
            
            // appURL.deletingPathExtension().lastPathComponent now holds the correct casing
            let appName = appURL.deletingPathExtension().lastPathComponent
            
            let newApp = AppItem(name: appName, icon: appIcon, bundlePath: appURL.path)
            
            if !allowedApps.contains(where: { $0.bundlePath == appURL.path }) {
                allowedApps.append(newApp)
            }
            searchAppName = ""
        } else {
            alertMessage = "Could not find application: \"\(trimmed)\""
            isShowingAlert = true
            alertTitle = "Application not Found"
        }
    }
    
    private func openAppFileImporter() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        
        if panel.runModal() == .OK, let selectedURL = panel.url {
            let appName = selectedURL.deletingPathExtension().lastPathComponent
            let appIcon = NSWorkspace.shared.icon(forFile: selectedURL.path)
            
            let newApp = AppItem(name: appName, icon: appIcon, bundlePath: selectedURL.path)
            if !allowedApps.contains(where: { $0.bundlePath == selectedURL.path }) {
                allowedApps.append(newApp)
            }
        }
    }
    
    private func removeApp(_ app: AppItem) {
        allowedApps.removeAll { $0.id == app.id }
    }
    
    private func startSession() {
        manager.startSession(hoursStr: hours, minutesStr: minutes, secondsStr: seconds, allowedApps: allowedApps)
        {
            title, message in
            self.alertTitle = title
            self.alertMessage = message
            self.isShowingAlert = true
        }
    }
}
