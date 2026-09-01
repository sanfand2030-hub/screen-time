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
    
    private func addAppByName(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        
        var foundURL: URL?
        
        let tempURL = URL(fileURLWithPath: "/Applications/\(trimmed).app")
        if FileManager.default.fileExists(atPath: tempURL.path) {
            foundURL = tempURL
        } else {
            let systemURL = URL(fileURLWithPath: "/System/Applications/\(trimmed).app")
            if FileManager.default.fileExists(atPath: systemURL.path) {
                foundURL = systemURL
            }
        }
        
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
        print("Starting \(Int(hours) ?? 0) hours, \(Int(minutes) ?? 0) minutes, and \(Int(seconds) ?? 0) seconds session with allowed paths: \(allowedApps.map { $0.bundlePath })")
    }
}
