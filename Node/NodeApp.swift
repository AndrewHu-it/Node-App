

import SwiftUI
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    var appState: AppState?
    var openWindow: ((String) -> Void)?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        if let appState = appState, let openWindow = openWindow {
            if !appState.hasSetName || !appState.hasSetNodeID {
                NSApplication.shared.activate(ignoringOtherApps: true)
                openWindow("name-input-window")
                appState.addLog("Opened Name Input window on launch")
            } else {
                appState.addLog("No need to open Name Input window; conditions met")
            }
        }
    }
}

// App State
class AppState: ObservableObject {

    private lazy var taskManager: TaskManager = {
        return TaskManager(appState: self)
    }()
    
    @AppStorage("name") var name: String = ""
    @AppStorage("hasSetName") var hasSetName: Bool = false
    @AppStorage("nodeID") var nodeID: String = ""
    @AppStorage("hasSetNodeID") var hasSetNodeID: Bool = false
    
    @Published var settingsWindow: NSWindow?
    @Published var nameInputWindow: NSWindow?
    @Published var logsWindow: NSWindow?
    
    @Published var running: Bool = false {
        didSet {
            if running {
                taskManager.start() // taskManager is lazily initialized here
            } else {
                taskManager.stop()
            }
        }
    }
    @Published var isProcessing: Bool = false
    @Published var pythonOutput: String = ""
    @Published var logs: [LogEntry] = []
    
    init() {
        reset() // Safe now, because taskManager isn’t accessed yet
        addLog("App started") // Safe, taskManager still not needed
    }

    
    func addLog(_ message: String) {
        DispatchQueue.main.async {
            let newLog = LogEntry(timestamp: Date(), message: message)
            self.logs.append(newLog)
            if self.logs.count > 50 {
                self.logs.removeFirst() // Keep only the most recent 50 logs
            }
        }
    }
    
    func reset() {
        if let bundleID = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleID)
            UserDefaults.standard.synchronize()
        }
        name = ""
        hasSetName = false
        nodeID = ""
        hasSetNodeID = false
        running = false
        isProcessing = false
        pythonOutput = ""
        logs = []
        addLog("App has been reset to default settings.")
    }
    
    func updateNodeAvailability() {
            // Ensure nodeID is set.
            guard hasSetNodeID, !nodeID.isEmpty else {
                addLog("Node ID is not set. Skipping API update.")
                return
            }
            
            // Call the API and handle the response.
            NodeAvailabilityAPI.shared.updateAvailability(nodeID: nodeID, availability: running) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let json):
                        self.addLog("Node availability updated successfully: \(json)")
                    case .failure(let error):
                        self.addLog("Failed to update node availability: \(error.localizedDescription)")
                    }
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




@main
struct NodeApp: App {
    @StateObject private var appState = AppState()
    @Environment(\.openWindow) private var openWindow
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    init() {
        let localOpenWindow = openWindow // Capture the environment's openWindow function
        appDelegate.appState = appState
        appDelegate.openWindow = { id in
            localOpenWindow(id: id) // Use the captured function
        }
    }
    
    var body: some Scene {
        
        // --- Dummy WindowGroup that immediately hides itself ---
        WindowGroup {
            EmptyView()
                .windowAccessor { window in
                    // Explicitly cast nil to Any? to satisfy type inference.
                    window.orderOut(nil as Any?)
                }
        }
        .handlesExternalEvents(matching: [])


        
        WindowGroup("Name Input", id: "name-input-window") {
            NameInputView()
                .environmentObject(appState)
                        .modifier(WindowAccessor { window in
                            appState.nameInputWindow = window
                            window.setContentSize(NSSize(width: 225, height: 275))
                        })
                        .windowAccessor { window in
                            // Restore the standard window style masks for title bar, etc.
                            window.styleMask.remove([.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView])
                            
                            // Make the title bar transparent so we can color behind it.
                             window.titleVisibility = .hidden
                            
                            // Allow the user to drag/move the window by clicking anywhere in the background.
                            window.isMovableByWindowBackground = true
                            
                            
                            // Round window corners. This will apply a rounded corner to the content area.
                            window.contentView?.wantsLayer = true
                            window.contentView?.layer?.cornerRadius = 12
                            window.contentView?.layer?.masksToBounds = true
                        }
                }
                .handlesExternalEvents(matching: [])
        
        WindowGroup("Settings", id: "settings-window") {
            SettingsView()
                .environmentObject(appState)
                .modifier(WindowAccessor { window in
                    // Store the Settings window reference.
                    appState.settingsWindow = window
                    window.setContentSize(NSSize(width: 500, height: 500))
                    // Add an observer to clear the reference when the window closes.
                    NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: window, queue: .main) { _ in
                        appState.settingsWindow = nil
                    }
                })
        }
        .handlesExternalEvents(matching: [])
        
                WindowGroup("Logs", id: "logs-window") {
            LogsView()
                .environmentObject(appState)
                .modifier(WindowAccessor { window in
                    appState.logsWindow = window
                    window.setContentSize(NSSize(width: 600, height: 400))
                    
                    // Clear reference on close
                    NotificationCenter.default.addObserver(
                        forName: NSWindow.willCloseNotification,
                        object: window,
                        queue: .main
                    ) { _ in
                        appState.logsWindow = nil
                    }
                })
        }
        .handlesExternalEvents(matching: [])
        
        

        
        MenuBarExtra("Distributed Computing Network", systemImage: "aqi.medium") {
            MenuBarContentView(appState: appState)
                .environmentObject(appState)  // Inject the AppState into the environment
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
                    appState.addLog("Running state changed to \(appState.running)")
                    appState.running.toggle()
                    appState.updateNodeAvailability()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: appState.running ? "pause.circle" : "play.circle")
                            .foregroundColor(appState.running ? .orange : .green)
                        Text(appState.running ? "Pause" : "Resume")
                            .font(.system(size: 12))
                    }
                }
                .buttonStyle(MenuButtonStyle(compact: true))
                .contentShape(Rectangle())
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
            .background(configuration.isPressed ? Color.secondary.opacity(0.1) : Color.clear)
            .cornerRadius(6)
            .foregroundColor(.primary)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.secondary.opacity(0.5), lineWidth: 1)
            )
            .contentShape(Rectangle())
    }
}

struct SettingsButton: View {
    @Environment(\.openWindow) private var openWindow
    @EnvironmentObject var appState: AppState  // Added to access settingsWindow
    
    var body: some View {
        Button(action: {
            // Check if the Settings window already exists and is visible.
            if let settingsWin = appState.settingsWindow, settingsWin.isVisible {
                settingsWin.makeKeyAndOrderFront(nil)
            } else {
                NSApplication.shared.activate(ignoringOtherApps: true)
                openWindow(id: "settings-window")
            }
        }) {
            HStack(spacing: 8) {
                Image(systemName: "gearshape.fill")
                    .foregroundColor(.secondary)
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
        .contentShape(Rectangle())
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
                    .foregroundColor(.secondary)
                    .font(.system(size: 14, weight: .medium))
                Text("Logs")
                    .font(.system(size: 13))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(MenuButtonStyle())
        .accessibilityLabel("Open logs window")
        .contentShape(Rectangle())
    }
}
