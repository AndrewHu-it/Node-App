import SwiftUI
import Foundation

struct NameInputView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.openWindow) private var openWindow


    @State private var tempName: String = ""
    @State private var errorMessage: String = ""
    @State private var outputMessage: String = ""
    @State private var registrationCompleted: Bool = false

    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [Color.black, Color.black.opacity(0.5)]),
                startPoint: .top,
                endPoint: .bottom
            )
            .edgesIgnoringSafeArea(.all)

                if registrationCompleted {
                    RegistrationSuccessView(
                            openSettings: {
                                // Check if the Settings window is already open.
                                if let settingsWin = appState.settingsWindow, settingsWin.isVisible {
                                    settingsWin.orderFrontRegardless()
                                } else {
                                    NSApplication.shared.activate(ignoringOtherApps: true)
                                    openWindow(id: "settings-window")
                                }
                            },
                            closeWindow: {
                                // Close the Name Input window using the stored reference.
                                appState.nameInputWindow?.close()
                            }
                        )
                
                    
                } else {
                    VStack(spacing: 24) {
                        Image(systemName: "person.crop.circle")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 48, height: 48)
                            .foregroundColor(.white.opacity(0.8))

                        Text("Register Node")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    VStack(spacing: 16) {


                            TextField("Name", text: $tempName)
                                .textFieldStyle(.plain)                // Use a plain style, no default border
                                .padding(8)                            // Padding inside the text field
                                .background(Color.white.opacity(0.1))  // Subtle background color
                                .cornerRadius(8)                       // Rounded corners
                                .foregroundColor(.white)               // White text
                                .disableAutocorrection(true)           // Avoid auto-correct
                                .frame(width: 200)                     // Fixed width
                                .frame(height: 20)                     // Fixed height
                                .padding(.vertical, 14)
                        //This thing is good.

                        
                        Button(action: {
                            if tempName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                errorMessage = "Name cannot be empty."
                                outputMessage = ""
                            } else {
                                errorMessage = ""
                                outputMessage = "Registering node..."
                                registerNodeInSwift()
                            }
                        }) {
                            Text("Next")
                                   .font(.headline)
                                   .fontWeight(.semibold)
                                   .foregroundColor(.white)
                                   .padding(.vertical, 14)
                                   .frame(width: 188)  // Fixed width
                                   .frame(height: 30)
                           }
                           .background(
                               LinearGradient(
                                   gradient: Gradient(colors: [
                                    Color(red: 0.25, green: 0.1, blue: 0.5),  // Deeper than the original
                                    Color(red: 0.0, green: 0.3, blue: 0.95)  // Richer and more vibrant
                                   ]),
                                   startPoint: .leading,
                                   endPoint: .trailing
                               )
                           )
                           .cornerRadius(10)
                           .shadow(color: Color.black.opacity(0.15), radius: 5, x: 0, y: 3)
                           .frame(height: 30)
                                
                        
                    }
                }

                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.caption)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            
            }
        
        }
    }

    private func registerNodeInSwift() {
        guard !tempName.isEmpty else {
            errorMessage = "Name is required."
            outputMessage = ""
            return
        }

        let safeCPU = "Not specified"
        let safeGPU = "Not specified"
        let safeCores = 1
        let safeRAM = "Not specified"
        let defaultEndpoint = "https://dcn-server-800570186400.us-east4.run.app/node/register"

        let payload: [String: Any] = [
            "name": tempName,
            "compute_specs": [
                "cpu": safeCPU,
                "gpu": safeGPU,
                "cores": safeCores,
                "ram": safeRAM
            ]
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: payload, options: []) else {
            errorMessage = "Failed to encode request data."
            outputMessage = ""
            return
        }

        guard let url = URL(string: defaultEndpoint) else {
            errorMessage = "Invalid endpoint URL."
            outputMessage = ""
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = jsonData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        appState.isProcessing = true

        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                self.appState.isProcessing = false

                if let error = error {
                    self.errorMessage = "[ERROR] \(error.localizedDescription)"
                    self.outputMessage = ""
                    self.appState.addLog("Node registration request failed: \(error.localizedDescription)")
                    return
                }

                guard let httpResponse = response as? HTTPURLResponse else {
                    self.errorMessage = "[ERROR] Invalid server response."
                    self.outputMessage = ""
                    return
                }

                if (200...299).contains(httpResponse.statusCode) {
                    if let data = data, !data.isEmpty {
                        do {
                            let jsonObj = try JSONSerialization.jsonObject(with: data, options: [])
                            if let dict = jsonObj as? [String: Any],
                               let nodeID = dict["node_id"] as? String {
                                self.appState.nodeID = nodeID
                                self.appState.hasSetNodeID = true
                                self.appState.addLog("Node ID received: \(nodeID)")
                            }

                            let prettyData = try JSONSerialization.data(withJSONObject: jsonObj, options: .prettyPrinted)
                            let jsonString = String(data: prettyData, encoding: .utf8) ?? "(Could not decode JSON)"

                            self.outputMessage = "Node registration successful:\n\(jsonString)"
                            self.appState.name = self.tempName
                            self.appState.hasSetName = true
                            self.appState.addLog("Name set to \(self.tempName). Registration successful.")

                            self.registrationCompleted = true
                        } catch {
                            let rawString = String(data: data, encoding: .utf8) ?? "(No response body)"
                            self.outputMessage = "Node registration succeeded, but response not JSON:\n\(rawString)"
                            self.appState.name = self.tempName
                            self.appState.hasSetName = true
                            self.appState.addLog("Name set to \(self.tempName). Non-JSON response.")
                            self.registrationCompleted = true
                        }
                    } else {
                        self.outputMessage = "Node registration succeeded (no response body)."
                        self.appState.name = self.tempName
                        self.appState.hasSetName = true
                        self.appState.addLog("Name set to \(self.tempName). No response body.")
                        self.registrationCompleted = true
                    }
                } else {
                    let serverString = data.flatMap { String(data: $0, encoding: .utf8) } ?? "(No response body)"
                    self.errorMessage = "[ERROR] HTTP \(httpResponse.statusCode). Server says: \(serverString)"
                    self.outputMessage = ""
                    self.appState.addLog("Node registration returned error \(httpResponse.statusCode).")
                }
            }
        }.resume()
    }
}



struct RegistrationSuccessView: View {
    var openSettings: () -> Void
    var closeWindow: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            // Success header
            Text("Registration Successful!")
                .font(.headline)
                .foregroundColor(.green)
                .padding(.top, 20)
            
            // Guidance text for next steps
            Text("Click on the menu bar application icon to get started.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
            
            Spacer()
            
            // Buttons for closing and opening settings
            HStack {
                Button(action: {
                    closeWindow() // Calls the closure to close the window
                }) {
                    Text("Close")
                        .frame(minWidth: 100)
                        .padding()
                        .background(Color.red.opacity(0.8))
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                
                Spacer()
                
                Button(action: {
                    openSettings() // Calls the closure to open the settings window
                }) {
                    Text("Settings")
                        .frame(minWidth: 100)
                        .padding()
                        .background(Color.gray.opacity(0.6))
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .frame(width: 350, height: 220) // Fixed size for consistent layout
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(12)
        .shadow(radius: 8)
    }
}
