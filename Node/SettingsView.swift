//
//  SettingsView.swift
//  Node
//
//  Created by Andrew Hurlbut on 3/2/25.
//

import SwiftUI
import Foundation


// View for the window content
struct SettingsView: View {

    var body: some View {
        VStack(spacing: 10) {
            // Header
            Text("Settings Page")
                .font(.headline)
                .padding(.top, 10)

            // Close button
            Button("Close") {
                NSApp.keyWindow?.close()
            }
            .padding(.bottom, 10)
        }
    }

}

