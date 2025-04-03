import Foundation
import Supabase
import Security

/// Custom error type for Supabase operations
enum SupabaseError: Error, LocalizedError {
    case noSession
    case userNotFound
    case invalidCredentials
    case networkError(Error)
    
    var errorDescription: String? {
        switch self {
        case .noSession:
            return "No active session found"
        case .userNotFound:
            return "User not found"
        case .invalidCredentials:
            return "Invalid credentials"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}

/// Manager class for all Supabase operations
final class SupabaseManager {
    /// Shared instance (singleton)
    static let shared = SupabaseManager()
    
    /// Supabase client instance
    let supabase: SupabaseClient
    
    /// Private initializer for singleton
    private init() {
        // Initialize Supabase client
        supabase = SupabaseClient(
            supabaseURL: URL(string: "https://wqgyynzvuvsxqnvnibim.supabase.co")!,
            supabaseKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6IndxZ3l5bnp2dXZzeHFudm5pYmltIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDI0NDk1NDIsImV4cCI6MjA1ODAyNTU0Mn0.riECKe0wkDYW5th2L1glPq6IOfQ76NIrK67A-2hrDZM",
            options: SupabaseClientOptions(
                auth: .init(
                    flowType: .pkce,
                    autoRefreshToken: true
                )
            )
        )
    }
    
    // MARK: - Authentication Methods
    
    func signIn(email: String, password: String) async throws -> Session {
        do {
            return try await supabase.auth.signIn(email: email, password: password)
        } catch {
            throw mapAuthError(error)
        }
    }
        
    /// Sign out the current user
    func signOut() async throws {
        do {
            try await supabase.auth.signOut()
        } catch {
            throw mapAuthError(error)
        }
    }
    
    /// Sign out the current user and clear keychain data (for complete reset)
    func signOutAndClearKeychain() async throws {
        do {
            try await supabase.auth.signOut()
            
            clearKeychainData()
        } catch {
            throw mapAuthError(error)
        }
    }
    
    func sendOTP(email: String) async throws {
        do {
            try await supabase.auth.signInWithOTP(
                email: email,
                shouldCreateUser: true
            )
        } catch {
            throw mapAuthError(error)
        }
    }
    
    func verifyOTP(email: String, token: String) async throws -> AuthResponse {
        do {
            return try await supabase.auth.verifyOTP(
                email: email,
                token: token,
                type: .email
            )
        } catch {
            throw mapAuthError(error)
        }
    }
    
    func getSession() async throws -> Session? {
        do {
            return try await supabase.auth.session
        } catch {
            throw mapAuthError(error)
        }
    }
    
    func getCurrentUser() async throws -> User? {
        do {
            let session = try await supabase.auth.session
            return session.user
        } catch {
            throw mapAuthError(error)
        }
    }
    
    func resetPassword(email: String) async throws {
        do {
            try await supabase.auth.resetPasswordForEmail(email)
        } catch {
            throw mapAuthError(error)
        }
    }
    
    func updatePassword(password: String, completion: (() -> Void)? = nil) async throws {
        do {
            let attributes = UserAttributes(password: password)
            try await supabase.auth.update(user: attributes)
            completion?()
        } catch {
            throw mapAuthError(error)
        }
    }
    
    func updatePasswordAndNavigate(password: String, navigateToDashboard: @escaping () -> Void) async throws {
        do {
            let attributes = UserAttributes(password: password)
            try await supabase.auth.update(user: attributes)
            // Password update successful, trigger navigation
            navigateToDashboard()
        } catch {
            throw mapAuthError(error)
        }
    }
    
    private func clearKeychainData() {
        clearKeychainDataSync()
    }
    
    /// Clear all keychain data associated with this app synchronously
    func clearKeychainDataSync() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Bundle.main.bundleIdentifier ?? "com.fleetmaster.app"
        ]
        
        // First try to delete all existing items
        SecItemDelete(query as CFDictionary)
        
        // Also clear internet password items which might be used for authorization
        let internetQuery: [String: Any] = [
            kSecClass as String: kSecClassInternetPassword,
            kSecAttrServer as String: "wqgyynzvuvsxqnvnibim.supabase.co" // Your Supabase URL domain
        ]
        
        SecItemDelete(internetQuery as CFDictionary)
        
        // Also clear generic password items without specific service attribute
        let genericQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword
        ]
        
        SecItemDelete(genericQuery as CFDictionary)
        
        // Also delete any access tokens or items stored by the Supabase client
        let accessTokenQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrLabel as String: "supabase.session"
        ]
        
        SecItemDelete(accessTokenQuery as CFDictionary)
        
        // Keychain data cleared synchronously
    }
        
        
    // MARK: - Maintenance Vehicle Operations
    
    /// Get the last ticket number from the database
    private func getLastTicketNumber() async throws -> Int {
        let response = try await supabase
            .from("Maintenance_Vehicle")
            .select("ticketNo")
            .order("ticketNo", ascending: false)
            .limit(1)
            .execute()
            .data
        
        let decoder = JSONDecoder()
        
        struct TicketResponse: Codable {
            let ticketNo: String
        }
        
        do {
            let tickets = try decoder.decode([TicketResponse].self, from: response)
            if let lastTicket = tickets.first?.ticketNo,
               let number = Int(lastTicket.replacingOccurrences(of: "TKT", with: "")) {
                return number
            }
        } catch {
            print("Error decoding ticket response: \(error)")
        }
        
        return 0
    }
    
    /// Generate the next ticket number
    private func generateNextTicketNumber() async throws -> String {
        let lastNumber = try await getLastTicketNumber()
        let nextNumber = lastNumber + 1
        return String(format: "TKT%07d", nextNumber)
    }
    
    /// Schedule a new maintenance task for a vehicle
    func scheduleMaintenance(_ maintenanceVehicle: inout MaintenanceVehicle) async throws {
        // Generate the next ticket number
        let ticketNo = try await generateNextTicketNumber()
        
        // Update the ticket number
        maintenanceVehicle.ticketNo = ticketNo
        
        try await supabase
            .from("Maintenance_Vehicle")
            .insert(maintenanceVehicle)
            .execute()
    }
    
    // MARK: - Helper Methods
    private func mapAuthError(_ error: Error) -> Error {
        // Check if error is an AuthError
            // Use string-based error handling as a fallback
            let errorString = String(describing: error)
            
            if errorString.contains("Invalid credentials") {
                return SupabaseError.invalidCredentials
            } else if errorString.contains("User not found") || errorString.contains("404") {
                return SupabaseError.userNotFound
            } else if errorString.contains("Missing session") || errorString.contains("No session") {
                return SupabaseError.noSession
            }
            
            return error
    }
}
