import SwiftUI
import AppKit



struct LogsView: View {
    @EnvironmentObject var appState: AppState
    
    private let logDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()

    
    var body: some View {
        // Setting the ZStack alignment to topLeading makes all its children start at the top left.
        ZStack(alignment: .topLeading) {
            // Black background that extends under the title bar
            Color.black
                .edgesIgnoringSafeArea(.all)
            
            // Scrollable log display
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 5) {
                        ForEach(appState.logs) { log in
                            Text("[\(log.timestamp, formatter: logDateFormatter)] \(log.message)")
                                .font(.custom("Menlo", size: 11)) // Use Menlo font, size 11 for a terminal-like look.
                                .foregroundColor(.white)         // White text for contrast.
                                .id(log.id)                      // Unique identifier for auto-scrolling.
                        }
                    }
                    .padding() // Padding around the text for a clean, terminal-like appearance.
                }
                .onChange(of: appState.logs) { _ in
                    // Auto-scroll to the latest log entry.
                    if let lastLog = appState.logs.last {
                        proxy.scrollTo(lastLog.id, anchor: .bottom)
                    }
                }
            }
        }
        .modifier(WindowAccessor { window in
            window.titlebarAppearsTransparent = true  // Makes the title bar transparent.
            window.titleVisibility = .hidden           // Hides the title text.
            window.backgroundColor = NSColor.black       // Sets the window's background to black.
        })
    }
}
