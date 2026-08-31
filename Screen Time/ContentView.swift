//
//  ContentView.swift
//  Screen Time
//
//  Created by BUQI DONG on 31/8/2026.
//

import SwiftUI
import AppKit

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

struct ContentView: View {
    var body: some View {
        ZStack(alignment: .leading) {
            Color.dynamicBackground
                .ignoresSafeArea()
            
            VStack(alignment: .leading) {
                Text("Screen Time")
                    .font(.title)
                    .bold()
                    .padding(.bottom, 12)
                Text("Stop your procrastination now. Begin your productive day.")
                Spacer()
            }
            .padding()
        }
    }
}
#Preview("(Totally not) Screen Time") {
    ContentView()
        .preferredColorScheme(.dark)
}
