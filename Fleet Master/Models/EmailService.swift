import Foundation
import SwiftSMTP

class EmailService {
    static let shared = EmailService()
    
    private let smtp: SMTP
    private let fromUser: Mail.User
    
    private init() {
        // Configure SMTP settings (secure these in a production app)
        self.smtp = SMTP(
            hostname: "smtp.gmail.com",     // Your SMTP server
            email: "fleetmanagementsystem3@gmail.com",  // Your email address
            password: "ebwsaocyeowejrbe"   // Your app password
        )
        
        self.fromUser = Mail.User(
            name: "noreply@fleetmaster.com",
            email: "fleetmanagementsystem3@gmail.com"
        )
    }
    
    func sendPasswordEmail(to recipient: String, name: String, password: String) {
        // Create recipient user
        let toUser = Mail.User(name: name, email: recipient)
        
        // Create mail content
        let subject = "Welcome to Fleet Master - Your Temporary Password"
        let body = """
        Hello \(name),
        
        Welcome to Fleet Master! Your account has been created successfully.
        
        Your temporary password is: \(password)
        
        Please log in and change your password as soon as possible.
        
        Best regards,
        The Fleet Master Team
        """
        
        // Create the mail object
        let mail = Mail(
            from: fromUser,
            to: [toUser],
            subject: subject,
            text: body
        )
        
        // Send the email
        smtp.send(mail) { error in
            if let error = error {
                print("Failed to send email: \(error)")
            } else {
                print("Successfully sent password email to \(recipient)")
            }
        }
    }
}
