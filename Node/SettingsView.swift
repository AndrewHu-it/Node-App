import SwiftUI
import AppKit

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var errorMessage = ""
    
    var body: some View {
        VStack(spacing: 10) {
            // Name section
            VStack(alignment: .leading) {
                Text("Name")
                    .font(.headline)
                Text(appState.hasSetName ? appState.name : "Not set")
                    .foregroundColor(appState.hasSetName ? .gray : .secondary)
            }
            .padding(.bottom, 10)
            
            // Node ID section
            VStack(alignment: .leading) {
                Text("Node ID")
                    .font(.headline)
                Text(appState.hasSetNodeID ? appState.nodeID : "Not set")
                    .foregroundColor(appState.hasSetNodeID ? .gray : .secondary)
            }
            .padding(.bottom, 10)
            
            // Error message
            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .padding(.top, 10)
            }
            
            // Push the following content to the bottom
            Spacer()
            
            // Visual separator
            Divider()
            
            // Quit button aligned to the right
            HStack {
                Spacer()
                Button(action: {
                    NSApplication.shared.terminate(nil)
                }) {
                    Text("Quit Application")
                        .foregroundColor(.red)
                }
            }
        }
        .padding()
    }
}
