import SwiftUI
import Foundation

//Could use this class later to store default values related to the user, such as node_id. 

class SessionManager: ObservableObject {
    @Published var isLoggedIn: Bool = false
    
    @Published var username: String = ""
    @Published var password: String = ""
    
    init() {
        loadCredentials()
    }
    
    func loadCredentials() {
        // Attempt to read from UserDefaults
        let storedUsername = UserDefaults.standard.string(forKey: "storedUsername") ?? ""
        let storedPassword = UserDefaults.standard.string(forKey: "storedPassword") ?? ""
        
        // If we have something, set them in memory
        if !storedUsername.isEmpty && !storedPassword.isEmpty {
            username = storedUsername
            password = storedPassword
            isLoggedIn = true
        } else {
            isLoggedIn = false
        }
    }
    
    func saveCredentials(username: String, password: String) {
        UserDefaults.standard.set(username, forKey: "storedUsername")
        UserDefaults.standard.set(password, forKey: "storedPassword")
        
        self.username = username
        self.password = password
        self.isLoggedIn = true
    }
    
    func clearCredentials() {
        UserDefaults.standard.removeObject(forKey: "storedUsername")
        UserDefaults.standard.removeObject(forKey: "storedPassword")
        
        username = ""
        password = ""
        isLoggedIn = false
    }
    
    func login(username: String, password: String) -> Bool {
        // In a real app, you'd verify these credentials via network or other means.
        // For now, let's assume any non-empty credentials are valid for demonstration:
        guard !username.isEmpty, !password.isEmpty else {
            return false
        }
        
        // If "valid", save them
        saveCredentials(username: username, password: password)
        return true
    }
    
    func logout() {
        clearCredentials()
    }
}
