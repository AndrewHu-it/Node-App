import SwiftUI
import AppKit






// App State
class AppState: ObservableObject {
    @Published var running: Bool = true
    @Published var isProcessing: Bool = false
    @Published var pythonOutput: String = ""
    @Published var logs: [LogEntry] = [] // Add logs array
    
    init() {
        addLog("App started") // Log app initialization
    }
    
    func addLog(_ message: String) {
        DispatchQueue.main.async {
            let newLog = LogEntry(timestamp: Date(), message: message) // Reordered arguments
            self.logs.append(newLog)
            if self.logs.count > 50 {
                self.logs.removeFirst() // Keep only the most recent 50 logs
            }
        }
    }
}


struct LogEntry: Identifiable, Equatable {
    let id = UUID()
    let timestamp: Date
    let message: String
    
    static func ==(lhs: LogEntry, rhs: LogEntry) -> Bool {
        return lhs.id == rhs.id
    }
}



//App, Scene, View
//State Object --> Observed Object that is passed in.
//some View vs some Scene

@main
struct NodeApp: App {
    @StateObject private var appState = AppState()
    
    var body: some Scene {
        Window("Settings", id: "settings-window") {
            SettingsView()
                .environmentObject(appState)
                .modifier(WindowAccessor { window in
                    window.setContentSize(NSSize(width: 500, height: 500)) // Set exact content size
                })
        }
        
        Window("Logs", id: "logs-window") {
            LogsView()
                .environmentObject(appState)
                .modifier(WindowAccessor { window in
                    window.setContentSize(NSSize(width: 600, height: 400)) // Set exact content size
                })
        }
        
        MenuBarExtra("Distributed Computing Network", systemImage: "aqi.medium") {
            MenuBarContentView(appState: appState)
                .frame(minWidth: 250)
        }
        .menuBarExtraStyle(.window)
        .defaultSize(width: 250, height: 180)
    }
}

// Separate View for MenuBar content
struct MenuBarContentView: View {
    @ObservedObject var appState: AppState
    
    var body: some View {
        VStack(spacing: 10) {
            // Header
            HStack {
                Image(systemName: "network")
                    .foregroundColor(.blue)
                Text("Compute Node")
                    .font(.headline)
                Spacer()
            }
            .padding(.top, 10)
            
            // Status and Toggle Section
            HStack(alignment: .center, spacing: 12) {
                // Status Indicator
                HStack(spacing: 6) {
                    Circle()
                        .frame(width: 8, height: 8)
                        .foregroundColor(appState.running ? .green : .red)
                    Text(appState.running ? "Running" : "Paused")
                        .font(.system(size: 12))
                }
                
                Spacer()
                
                // Toggle Button
                Button(action: {
                    appState.addLog("Running state changed to \(appState.running)") // Add log
                    appState.running.toggle()
                    
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: appState.running ? "pause.circle" : "play.circle")
                            .foregroundColor(appState.running ? .orange : .green)
                        Text(appState.running ? "Pause" : "Resume")
                            .font(.system(size: 12))
                    }
                }
                .buttonStyle(MenuButtonStyle(compact: true))
                .contentShape(Rectangle()) // Added this line
                //make a max size
            }
            .padding(.horizontal, 8)
            
            Divider()
            
            // Window Buttons
            SettingsButton()
            LogsButton()
            
            
        }
        .padding(.horizontal)
        .padding(.bottom, 10)
    }
}

// Custom Button Style with compact option
struct MenuButtonStyle: ButtonStyle {
    var compact: Bool = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.vertical, compact ? 4 : 6)
            .padding(.horizontal, compact ? 8 : 10)
            // Remove .frame(maxWidth: .infinity) to keep button content-sized
            .background(configuration.isPressed ? Color.gray.opacity(0.2) : Color.clear)
            .cornerRadius(6)
            .foregroundColor(.primary)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
            )
            .contentShape(Rectangle()) // Keep this for hit area
    }
}
struct SettingsButton: View {
    @Environment(\.openWindow) private var openWindow
    
    var body: some View {
        Button(action: {
            NSApplication.shared.activate(ignoringOtherApps: true)
            openWindow(id: "settings-window")
        }) {
            HStack(spacing: 8) {
                Image(systemName: "gearshape.fill")
                    .foregroundColor(.gray)
                    .symbolRenderingMode(.hierarchical)
                    .font(.system(size: 14, weight: .medium))
                Text("Settings")
                    .font(.system(size: 13))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(MenuButtonStyle())
        .scaleEffect(1.0)
        .animation(.easeInOut(duration: 0.2), value: false)
        .accessibilityLabel("Open settings window")
        .contentShape(Rectangle()) // Added this line
    }
}

struct LogsButton: View {
    @Environment(\.openWindow) private var openWindow
    
    var body: some View {
        Button(action: {
            NSApplication.shared.activate(ignoringOtherApps: true)
            openWindow(id: "logs-window")
        }) {
            HStack(spacing: 8) {
                Image(systemName: "doc.text")
                    .foregroundColor(.gray)
                    .font(.system(size: 14, weight: .medium))
                Text("Logs")
                    .font(.system(size: 13))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(MenuButtonStyle())
        .accessibilityLabel("Open logs window")
        .contentShape(Rectangle()) // Added this line
    }
}



//AUXILARY:
