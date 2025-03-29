import Foundation

/// A singleton class to handle node availability API calls.
class NodeAvailabilityAPI {
    // Shared instance for easy access across the app.
    static let shared = NodeAvailabilityAPI()
    
    // The URL to the Flask endpoint that updates node availability.
    let availabilityURL = URL(string: "http://127.0.0.1:5001/node/availability")!
    
    /// Updates the node's availability status by sending a PATCH request.
    /// - Parameters:
    ///   - nodeID: The unique identifier for the node.
    ///   - availability: A Boolean indicating whether the node is available.
    ///   - completion: A closure that handles the result of the API call.
    func updateAvailability(nodeID: String, availability: Bool, completion: @escaping (Result<[String: Any], Error>) -> Void) {
        // Create the URLRequest with the endpoint URL.
        var request = URLRequest(url: availabilityURL)
        request.httpMethod = "PATCH"  // PATCH is used to partially update resources.
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Construct the JSON body.
        let json: [String: Any] = [
            "node_id": nodeID,
            "availability": availability
        ]
        
        // Convert the dictionary into JSON data.
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: json, options: [])
            request.httpBody = jsonData
        } catch {
            completion(.failure(error))
            return
        }
        
        // Create and start a data task to send the request.
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            // Handle network error.
            if let error = error {
                completion(.failure(error))
                return
            }
            
            // Ensure a valid HTTP response.
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode),
                  let data = data else {
                let statusError = NSError(domain: "NodeAvailabilityAPI", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid response from server"])
                completion(.failure(statusError))
                return
            }
            
            // Parse the JSON response.
            do {
                let jsonResponse = try JSONSerialization.jsonObject(with: data, options: [])
                if let jsonDict = jsonResponse as? [String: Any] {
                    completion(.success(jsonDict))
                } else {
                    let parsingError = NSError(domain: "NodeAvailabilityAPI", code: 0, userInfo: [NSLocalizedDescriptionKey: "Unexpected JSON format"])
                    completion(.failure(parsingError))
                }
            } catch {
                completion(.failure(error))
            }
        }
        task.resume()  // Start the network request.
    }
}
