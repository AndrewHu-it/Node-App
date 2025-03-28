//TODO: make this look nicer.
    //Update the settings variables (node id and name) if a node is successfully created.

    //Should close the window once the node is successfully created
    //


import SwiftUI
import Foundation

struct NameInputView: View {
    @EnvironmentObject var appState: AppState
    
    // User input: just the name (mirroring your CLI's "--name")
    @State private var tempName: String = ""
    
    // UI feedback
    @State private var errorMessage: String = ""
    @State private var outputMessage: String = ""
    
    var body: some View {
        VStack(spacing: 10) {
            Text("Enter Your Name")
                .font(.headline)
            
            TextField("Name", text: $tempName)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .frame(width: 200)
            
            HStack {
                Spacer()
                Button(action: {
                    if tempName.isEmpty {
                        errorMessage = "Name cannot be empty."
                        outputMessage = ""
                    } else {
                        errorMessage = ""
                        outputMessage = "Registering node..."
                        registerNodeInSwift()
                    }
                }) {
                    Text("Next")
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 5)
                        .background(Color.blue)
                        .cornerRadius(5)
                }
            }
            
            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .font(.caption)
                    .multilineTextAlignment(.center)
            }
            
            if !outputMessage.isEmpty {
                Text(outputMessage)
                    .foregroundColor(.green)
                    .font(.caption)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
    }
    

    private func registerNodeInSwift() {
        // Basic validation / resetting old messages
        guard !tempName.isEmpty else {
            errorMessage = "Name is required."
            outputMessage = ""
            return
        }
        
        // Usually we'd let the user specify these, or auto-detect them, but
        // to match the Python script's default logic, we define them here.
        let safeCPU = "Not specified"
        let safeGPU = "Not specified"
        let safeCores = 1
        let safeRAM = "Not specified"
        let defaultEndpoint = "https://dcn-server-800570186400.us-east4.run.app/node/register"
        
        // Construct the JSON payload
        let payload: [String: Any] = [
            "name": tempName,
            "compute_specs": [
                "cpu": safeCPU,
                "gpu": safeGPU,
                "cores": safeCores,
                "ram": safeRAM
            ]
        ]
        
        // Convert the payload to raw JSON data
        guard let jsonData = try? JSONSerialization.data(withJSONObject: payload, options: []) else {
            errorMessage = "Failed to encode request data."
            outputMessage = ""
            return
        }
        
        // Build the POST request
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
                    // Success – parse or show the server's response
                    if let data = data, !data.isEmpty {
                        do {
                            // Attempt to parse JSON
                            let jsonObj = try JSONSerialization.jsonObject(with: data, options: [])
                            if let dict = jsonObj as? [String: Any] {
                                // Extract nodeID if present
                                if let nodeID = dict["nodeID"] as? String {
                                    self.appState.nodeID = nodeID
                                    self.appState.hasSetNodeID = true
                                    self.appState.addLog("Node ID received: \(nodeID)")
                                }
                            }
                            
                            // Convert to pretty-printed JSON for display
                            let prettyData = try JSONSerialization.data(withJSONObject: jsonObj, options: .prettyPrinted)
                            let jsonString = String(data: prettyData, encoding: .utf8) ?? "(Could not decode JSON)"
                            
                            self.outputMessage = "Node registration successful:\n\(jsonString)"
                            // Update app state and close the window
                            self.appState.name = self.tempName
                            self.appState.hasSetName = true
                            self.appState.addLog("Name set to \(self.tempName). Registration successful.")
                            self.appState.nameInputWindow?.close() // Close the window
                        } catch {
                            // If response is not parseable JSON
                            let rawString = String(data: data, encoding: .utf8) ?? "(No response body)"
                            self.outputMessage = "Node registration succeeded, but response not JSON:\n\(rawString)"
                            self.appState.name = self.tempName
                            self.appState.hasSetName = true
                            self.appState.addLog("Name set to \(self.tempName). Non-JSON response.")
                            self.appState.nameInputWindow?.close() // Close the window
                        }
                    } else {
                        // 2xx but no body – still success
                        self.outputMessage = "Node registration succeeded (no response body)."
                        self.appState.name = self.tempName
                        self.appState.hasSetName = true
                        self.appState.addLog("Name set to \(self.tempName). No response body.")
                        self.appState.nameInputWindow?.close() // Close the window
                    }
                } else {
                    // Non-2xx error code
                    let serverString = data.flatMap { String(data: $0, encoding: .utf8) } ?? "(No response body)"
                    self.errorMessage = "[ERROR] HTTP \(httpResponse.statusCode). Server says: \(serverString)"
                    self.outputMessage = ""
                    self.appState.addLog("Node registration returned error \(httpResponse.statusCode).")
                }
            }
        }.resume()
    }
}

