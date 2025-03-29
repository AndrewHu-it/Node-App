import Foundation
import CoreGraphics
import AppKit

class TaskManager {
    private weak var appState: AppState?
    private var taskLoopTask: Task<Void, Never>?

    init(appState: AppState) {
        self.appState = appState
    }

    // MARK: - Public Methods

    func start() {
        guard let appState = appState else { return }
        guard !appState.nodeID.isEmpty else {
            DispatchQueue.main.async {
                appState.addLog("Cannot start task loop: nodeID is not set.")
            }
            return
        }
        guard taskLoopTask == nil else { return }
        taskLoopTask = Task { [weak self] in
            await self?.taskLoop()
        }
    }

    func stop() {
        taskLoopTask?.cancel()
        taskLoopTask = nil
    }

    // MARK: - Private Methods

    private func taskLoop() async {
        guard let appState = appState else { return }
        while !Task.isCancelled && appState.running {
            do {
                // Fetch task data
                let taskData = try await fetchTask(nodeID: appState.nodeID)
                let instruction = taskData.instruction_data
                let taskID = taskData.task_id

                DispatchQueue.main.async {
                    appState.isProcessing = true
                    appState.addLog("Task data received for task \(taskID)...")
                }

                // Generate Mandelbrot image
                let imageData = generateMandelbrotImage(
                    xMin: instruction.x_min,
                    xMax: instruction.x_max,
                    yMin: instruction.y_min,
                    yMax: instruction.y_max,
                    width: instruction.width,
                    height: instruction.height,
                    maxIter: 100
                )
                DispatchQueue.main.async {
                    appState.addLog("Image successfully created for task \(taskID)...")
                }

                // Prepare metadata
                let metadata: [String: Any] = [
                    "uploaded_by": appState.nodeID,
                    "task_id": taskID,
                    "instruction_data": [
                        "x_min": instruction.x_min,
                        "x_max": instruction.x_max,
                        "y_min": instruction.y_min,
                        "y_max": instruction.y_max,
                        "width": instruction.width,
                        "height": instruction.height
                    ],
                    "filename": "\(taskID).png"
                ]

                // Submit image
                DispatchQueue.main.async {
                    appState.addLog("About to stream image for task \(taskID)...")
                }
                try await submitImage(imageData: imageData, metadata: metadata, nodeID: appState.nodeID, taskID: taskID)
                DispatchQueue.main.async {
                    appState.addLog("Successfully processed and submitted task \(taskID)")
                    appState.isProcessing = false
                }
            } catch let error as NSError {
                if error.domain == "DataError" && error.code == 2 {
                    // No tasks available
                    DispatchQueue.main.async {
                        appState.addLog("[INFO]: No tasks available, waiting 10 seconds...")
                        appState.isProcessing = false
                    }
                    try? await Task.sleep(nanoseconds: 10_000_000_000) // 10 seconds
                } else {
                    // Other errors
                    DispatchQueue.main.async {
                        appState.addLog("[ERROR]: Failed to process task - \(error.localizedDescription)")
                        appState.isProcessing = false
                    }
                    // Optional: Add a small delay to prevent rapid retries on other errors
                    try? await Task.sleep(nanoseconds: 10_000_000_000) // 1 second
                }
            }
        }
    }

    private func fetchTask(nodeID: String) async throws -> TaskData {
        let url = URL(string: "https://dcn-server-800570186400.us-east4.run.app/node/task/\(nodeID)")!
        let (data, response) = try await URLSession.shared.data(from: url)
        
        // Check HTTP status code
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NSError(domain: "NetworkError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to fetch task"])
        }
        
        let taskData = try JSONDecoder().decode(TaskData.self, from: data)
        if taskData.task_id.isEmpty {
            throw NSError(domain: "DataError", code: 2, userInfo: [NSLocalizedDescriptionKey: "No tasks available"])
        }
        return taskData
    }

    private func generateMandelbrotImage(xMin: Double, xMax: Double, yMin: Double, yMax: Double, width: Int, height: Int, maxIter: Int) -> Data {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: colorSpace, bitmapInfo: bitmapInfo.rawValue)!
        
        // Generate Mandelbrot set pixel by pixel
        for py in 0..<height {
            let y0 = yMin + (Double(py) / Double(height)) * (yMax - yMin)
            for px in 0..<width {
                let x0 = xMin + (Double(px) / Double(width)) * (xMax - xMin)
                var x: Double = 0.0
                var y: Double = 0.0
                var iteration = 0
                while x*x + y*y <= 4.0 && iteration < maxIter {
                    let xTemp = x*x - y*y + x0
                    y = 2.0 * x * y + y0
                    x = xTemp
                    iteration += 1
                }
                let hue = CGFloat(255 - Int(Double(iteration) * 255.0 / Double(maxIter))) / 255.0
                context.setFillColor(red: hue, green: hue, blue: hue, alpha: 1.0)
                context.fill(CGRect(x: px, y: py, width: 1, height: 1))
            }
        }
        
        // Convert to PNG data
        let cgImage = context.makeImage()!
        let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: width, height: height))
        let imageData = nsImage.tiffRepresentation!
        let bitmap = NSBitmapImageRep(data: imageData)!
        return bitmap.representation(using: .png, properties: [:])!
    }

    private func submitImage(imageData: Data, metadata: [String: Any], nodeID: String, taskID: String) async throws {
        let url = URL(string: "https://dcn-server-800570186400.us-east4.run.app/node/submit-image")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        // Construct multipart form data
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"image\"; filename=\"image.png\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/png\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n".data(using: .utf8)!)
        
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"node_id\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(nodeID)\r\n".data(using: .utf8)!)
        
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"task_id\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(taskID)\r\n".data(using: .utf8)!)
        
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"metadata\"\r\n\r\n".data(using: .utf8)!)
        body.append(try JSONSerialization.data(withJSONObject: metadata))
        body.append("\r\n".data(using: .utf8)!)
        
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        // Perform the request
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NSError(domain: "NetworkError", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to submit image"])
        }
        
        let responseData = try JSONDecoder().decode([String: String].self, from: data)
        guard responseData["image_id"] != nil else {
            throw NSError(domain: "ServerError", code: 4, userInfo: [NSLocalizedDescriptionKey: "Server did not return an image_id"])
        }
    }
}

// MARK: - Data Structures

struct TaskData: Codable {
    let task_id: String
    let instruction_data: InstructionData
}

struct InstructionData: Codable {
    let x_min: Double
    let x_max: Double
    let y_min: Double
    let y_max: Double
    let width: Int
    let height: Int
    
    // Coding keys to match JSON structure
    enum CodingKeys: String, CodingKey {
        case x_min
        case x_max
        case y_min
        case y_max
        case width
        case height
    }
}
