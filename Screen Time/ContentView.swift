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

// Model to hold Application data and native icon
struct AppItem: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let icon: NSImage
    let bundlePath: String
}

struct ContentView: View {
    @State private var selectedMinutes: Int = 25
    @State private var searchAppName: String = ""
    @State private var allowedApps: [AppItem] = []
    
    let timerOptions = [15, 25, 45, 60, 90]

    var body: some View {
        ZStack(alignment: .leading) {
            Color.dynamicBackground
                .ignoresSafeArea()
            
            VStack(alignment: .leading, spacing: 16) {
                Text("Screen Time")
                    .font(.title)
                    .bold()
                
                Text("Stop your procrastination now. Begin your productive day.")
                    .font(.subheadline)
                
                // Timer Selection Row
                HStack {
                    Text("Set your timer:")
                        .bold()
                    
                    Picker("Duration", selection: $selectedMinutes) {
                        ForEach(timerOptions, id: \.self) { minutes in
                            Text("\(minutes) minutes").tag(minutes)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 140)
                    
                    Spacer()
                }
                
                Divider()
                
                // Allowed Apps Section
                VStack(alignment: .leading, spacing: 8) {
                    Text("List of allowed applications:")
                        .bold()
                    
                    // Input bar to search system or browse disk
                    HStack {
                        TextField("Enter app name (e.g. Calculator)...", text: $searchAppName)
                            .textFieldStyle(.roundedBorder)
                        
                        Button("Add") {
                            addAppByName(searchAppName)
                        }
                        .disabled(searchAppName.trimmingCharacters(in: .whitespaces).isEmpty)
                        
                        Button("Browse...") {
                            openAppFileImporter()
                        }
                    }
                    
                    // List displaying actual app icons
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
                
                // Action Button
                Button(action: startSession) {
                    Text("Start Focus Session")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            .padding()
        }
        .frame(minWidth: 480, minHeight: 480)
        .onAppear {
            // Seed defaults with real macOS icons on load
            addAppByName("Xcode")
            addAppByName("Calculator")
        }
    }
    
    // MARK: - App Fetching Logic
    
    /// Finds application by name on macOS and fetches its official NSImage icon
    /// Finds application by name on macOS using modern non-deprecated NSWorkspace APIs
    private func addAppByName(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        
        var foundURL: URL?
        
        // 1. Try resolving using system application lookup URL
        let tempURL = URL(fileURLWithPath: "/Applications/\(trimmed).app")
        if FileManager.default.fileExists(atPath: tempURL.path) {
            foundURL = tempURL
        } else {
            // Fallback search in /System/Applications/
            let systemURL = URL(fileURLWithPath: "/System/Applications/\(trimmed).app")
            if FileManager.default.fileExists(atPath: systemURL.path) {
                foundURL = systemURL
            }
        }
        
        // 2. Extract icon and path if URL was located
        if let appURL = foundURL {
            let appIcon = NSWorkspace.shared.icon(forFile: appURL.path)
            let appName = appURL.deletingPathExtension().lastPathComponent
            let newApp = AppItem(name: appName, icon: appIcon, bundlePath: appURL.path)
            
            if !allowedApps.contains(where: { $0.bundlePath == appURL.path }) {
                allowedApps.append(newApp)
            }
            searchAppName = ""
        } else {
            print("Could not locate app path for: \(trimmed)")
        }
    }
    
    /// Presents NSOpenPanel for selecting .app files directly from disk
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
        print("Starting \(selectedMinutes) minute session with allowed paths: \(allowedApps.map { $0.bundlePath })")
    }
}

#Preview {
    ContentView()
}
