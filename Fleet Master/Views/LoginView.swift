import SwiftUI
import Combine

struct LoginView: View {
    @StateObject private var viewModel = LoginViewModel()
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @EnvironmentObject private var appStateManager: AppStateManager
    
    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                HStack(spacing: 0) {
                    // Left panel with image/branding (iPad only)
                    if horizontalSizeClass == .regular {
                        ZStack {
                            // Background gradient
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color(#colorLiteral(red: 0.36, green: 0.57, blue: 0.98, alpha: 1)),
                                    Color(#colorLiteral(red: 0.2, green: 0.4, blue: 0.8, alpha: 1))
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            .ignoresSafeArea()
                            
                            // Subtle pattern overlay
                            Circle()
                                .fill(.white.opacity(0.1))
                                .frame(width: 400, height: 400)
                                .blur(radius: 50)
                                .offset(x: -100, y: -200)
                            
                            Circle()
                                .fill(.white.opacity(0.1))
                                .frame(width: 300, height: 300)
                                .blur(radius: 40)
                                .offset(x: 100, y: 200)
                            
                            // Branding elements
                            VStack(spacing: 24) {
                                Spacer()
                                
                                ZStack {
                                    Circle()
                                        .fill(.white)
                                        .frame(width: 160, height: 160)
                                        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                                    
                                    Image(systemName: "car.fill")
                                        .font(.system(size: 70))
                                        .foregroundColor(Color(#colorLiteral(red: 0.36, green: 0.57, blue: 0.98, alpha: 1)))
                                }
                                .padding(.bottom, 40)
                                
                                Text("Fleet Master")
                                    .font(.system(size: 44, weight: .bold))
                                    .foregroundColor(.white)
                                
                                Text("Your comprehensive fleet\nmanagement solution")
                                    .font(.system(size: 20))
                                    .foregroundColor(.white.opacity(0.9))
                                    .multilineTextAlignment(.center)
                                    .lineSpacing(6)
                                
                                Spacer()
                                
                                // Version info
                                Text("Version 1.0")
                                    .font(.system(size: 14))
                                    .foregroundColor(.white.opacity(0.7))
                            }
                            .padding(60)
                        }
                        .frame(width: geometry.size.width * 0.45)
                    }
                    
                    // Right panel with login form
                    ZStack {
                        // Light background with subtle gradient
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color(.systemBackground),
                                Color(.systemBackground).opacity(0.95)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .ignoresSafeArea()
                        
                        // Center form using ZStack approach
                        ScrollView(.vertical) {
                            ZStack {
                                // Reserve space matching scrollview height for proper centering
                                Color.clear
                                    .frame(height: geometry.size.height)
                                
                                VStack(spacing: 32) {
                                    // For iPad show welcoming header
                                    if horizontalSizeClass == .regular {
                                        VStack(spacing: 12) {
                                            Text("Welcome Back")
                                                .font(.system(size: 36, weight: .bold))
                                                .frame(maxWidth: .infinity, alignment: .center)
                                            
                                            Text("Sign in to your account")
                                                .font(.system(size: 18))
                                                .foregroundColor(.secondary)
                                        }
                                        .padding(.bottom, 40)
                                    }
                                    
                                    // Login form
                                    VStack(spacing: 32) {
                                        // Email field
                                        VStack(alignment: .leading, spacing: 12) {
                                            Text("Email")
                                                .font(.system(size: 16, weight: .medium))
                                                .foregroundColor(.primary)
                                            
                                            HStack {
                                                Image(systemName: "envelope.fill")
                                                    .foregroundColor(.secondary)
                                                    .frame(width: 30, height: 30)
                                                    .font(.system(size: 20))
                                                
                                                TextField("Enter your email", text: $viewModel.email)
                                                    .textContentType(.emailAddress)
                                                    .keyboardType(.emailAddress)
                                                    .autocapitalization(.none)
                                                    .font(.system(size: 18))
                                                    .frame(height: 60)
                                            }
                                            .padding(.horizontal, 20)
                                            .background(Color(.systemGray6))
                                            .cornerRadius(16)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 16)
                                                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                                            )
                                        }
                                        
                                        // Password field
                                        VStack(alignment: .leading, spacing: 12) {
                                            Text("Password")
                                                .font(.system(size: 16, weight: .medium))
                                                .foregroundColor(.primary)
                                            
                                            HStack {
                                                Image(systemName: "lock.fill")
                                                    .foregroundColor(.secondary)
                                                    .frame(width: 30, height: 30)
                                                    .font(.system(size: 20))
                                                
                                                if viewModel.showPassword {
                                                    TextField("Enter your password", text: $viewModel.password)
                                                        .textContentType(.password)
                                                        .font(.system(size: 18))
                                                        .frame(height: 60)
                                                } else {
                                                    SecureField("Enter your password", text: $viewModel.password)
                                                        .textContentType(.password)
                                                        .font(.system(size: 18))
                                                        .frame(height: 60)
                                                }
                                                
                                                Button(action: {
                                                    viewModel.showPassword.toggle()
                                                }) {
                                                    Image(systemName: viewModel.showPassword ? "eye.slash.fill" : "eye.fill")
                                                        .foregroundColor(.secondary)
                                                        .frame(width: 30, height: 30)
                                                        .font(.system(size: 20))
                                                        .contentShape(Rectangle())
                                                }
                                                .buttonStyle(PlainButtonStyle())
                                            }
                                            .padding(.horizontal, 20)
                                            .background(Color(.systemGray6))
                                            .cornerRadius(16)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 16)
                                                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                                            )
                                        }
                                        
                                        // Forgot password link
                                        HStack {
                                            Spacer()
                                            Button(action: {
                                                // Handle forgot password
                                            }) {
                                                Text("Forgot Password?")
                                                    .font(.system(size: 16, weight: .medium))
                                                    .foregroundColor(Color(#colorLiteral(red: 0.36, green: 0.57, blue: 0.98, alpha: 1)))
                                            }
                                        }
                                        .padding(.top, -5)
                                        
                                        // Login button
                                        Button(action: {
                                            viewModel.login()
                                        }) {
                                            HStack {
                                                if viewModel.isLoading {
                                                    ProgressView()
                                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                                        .scaleEffect(1.2)
                                                } else {
                                                    Text("Sign In")
                                                        .font(.system(size: 18, weight: .semibold))
                                                }
                                            }
                                            .frame(maxWidth: .infinity)
                                            .frame(height: 60)
                                            .background(
                                                LinearGradient(
                                                    gradient: Gradient(colors: [
                                                        Color(#colorLiteral(red: 0.36, green: 0.57, blue: 0.98, alpha: 1)),
                                                        Color(#colorLiteral(red: 0.2, green: 0.4, blue: 0.8, alpha: 1))
                                                    ]),
                                                    startPoint: .leading,
                                                    endPoint: .trailing
                                                )
                                            )
                                            .foregroundColor(.white)
                                            .cornerRadius(16)
                                            .shadow(color: Color(#colorLiteral(red: 0.36, green: 0.57, blue: 0.98, alpha: 0.3)), radius: 8, x: 0, y: 4)
                                        }
                                        .disabled(viewModel.isLoading || !viewModel.isValidInput)
                                        .padding(.top, 10)
                                    }
                                    .padding(.horizontal, 50)
                                    .padding(.vertical, 50)
                                    .frame(maxWidth: 550)
                                }
                            }
                            .scrollBounceBehavior(.basedOnSize)
                        }
                    }
                    .frame(width: horizontalSizeClass == .regular ? geometry.size.width * 0.55 : geometry.size.width)
                }
            }
            .navigationDestination(isPresented: $viewModel.showTwoFactorAuth) {
                TwoFactorAuthView(viewModel: viewModel)
            }
            .navigationDestination(isPresented: $viewModel.showPasswordChange) {
                PasswordChangeView(viewModel: viewModel)
            }
            .navigationDestination(isPresented: $viewModel.navigateToMainView) {
                MainView()
            }
            .alert(viewModel.alertMessage, isPresented: $viewModel.showAlert) {
                Button("OK", role: .cancel) { }
            }
            .navigationBarHidden(true)
            .onAppear {
                // Connect the view model with the app state manager
                viewModel.appStateManager = appStateManager
            }
        }
    }
}

struct TwoFactorAuthView: View {
    @ObservedObject var viewModel: LoginViewModel
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                ZStack {
                    // Reserve space matching scrollview height for proper centering
                    Color.clear
                        .frame(height: geometry.size.height)
                    
                    VStack(spacing: 40) {
                        // Header
                        VStack(spacing: 20) {
                            // Icon with gradient background
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            gradient: Gradient(colors: [
                                                Color.gray.opacity(0.2),
                                                Color.gray.opacity(0.1)
                                            ]),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 160, height: 160)
                                
                                Image(systemName: "lock.shield.fill")
                                    .font(.system(size: 70))
                                    .foregroundColor(Color(#colorLiteral(red: 0.2, green: 0.4, blue: 0.8, alpha: 1)))
                            }
                            .padding(.bottom, 10)
                            
                            Text("Two-Factor Authentication")
                                .font(.system(size: 32, weight: .bold))
                                .multilineTextAlignment(.center)
                            
                            Text("We've sent a verification code to\n\(viewModel.email)")
                                .font(.system(size: 18))
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .lineSpacing(4)
                        }
                        .padding(.top, 0)
                        .padding(.horizontal, 30)
                        
                        // OTP input
                        VStack(spacing: 35) {
                            // OTP digits
                            VStack(spacing: 16) {
                                HStack(spacing: horizontalSizeClass == .regular ? 20 : 16) {
                                    ForEach(0..<6) { index in
                                        OTPDigitField(
                                            text: $viewModel.otpDigits[index],
                                            isFocused: viewModel.focusedOTPDigit == index,
                                            onFocus: { viewModel.focusedOTPDigit = index },
                                            index: index,
                                            onTextChange: { currentIndex, newValue in
                                                if !newValue.isEmpty {
                                                    // A digit was entered
                                                    if currentIndex < 5 {
                                                        // Move to next box
                                                        viewModel.focusedOTPDigit = currentIndex + 1
                                                    } else {
                                                        // Last digit entered, close keyboard
                                                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), 
                                                                                      to: nil, 
                                                                                      from: nil, 
                                                                                      for: nil)
                                                    }
                                                } else {
                                                    // Backspace was pressed and current field is empty
                                                    if currentIndex > 0 {
                                                        // Move to previous field
                                                        viewModel.focusedOTPDigit = currentIndex - 1
                                                    }
                                                }
                                            }
                                        )
                                    }
                                }
                                .frame(maxWidth: horizontalSizeClass == .regular ? 450 : .infinity)
                                .padding(.horizontal, horizontalSizeClass == .regular ? 0 : 20)
                                // Add menu context for paste action
                                .contextMenu {
                                    Button("Paste") {
                                        pasteOTP()
                                    }
                                }
                                // Add long press gesture for paste
                                .onLongPressGesture(minimumDuration: 1) {
                                    pasteOTP()
                                }
                            }
                            
                            // Resend button only (removed timer)
                            Button(action: {
                                viewModel.resendOTP()
                            }) {
                                Text("Send new code")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(Color(#colorLiteral(red: 0.36, green: 0.57, blue: 0.98, alpha: 1)))
                                    .padding(.vertical, 12)
                                    .padding(.horizontal, 24)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color(#colorLiteral(red: 0.36, green: 0.57, blue: 0.98, alpha: 1)), lineWidth: 1)
                                    )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        .padding(.horizontal, 30)
                        
                        // Verify button - keep same size and style as login button
                        Button(action: {
                            viewModel.verifyOTP()
                        }) {
                            HStack {
                                if viewModel.isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(1.2)
                                } else {
                                    Text("Verify Code")
                                        .font(.system(size: 18, weight: .semibold))
                                }
                            }
                            .frame(maxWidth: horizontalSizeClass == .regular ? 450 : .infinity)
                            .frame(height: 60)
                            .background(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color(#colorLiteral(red: 0.36, green: 0.57, blue: 0.98, alpha: 1)),
                                        Color(#colorLiteral(red: 0.2, green: 0.4, blue: 0.8, alpha: 1))
                                    ]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                                .opacity(viewModel.isValidOTP ? 1 : 0.6)
                            )
                            .foregroundColor(.white)
                            .cornerRadius(16)
                            .shadow(color: Color(#colorLiteral(red: 0.36, green: 0.57, blue: 0.98, alpha: 0.3)), radius: 8, x: 0, y: 4)
                        }
                        .disabled(viewModel.isLoading || !viewModel.isValidOTP)
                        .padding(.horizontal, 30)

                        // Add a paste button below the input fields for better usability
                        Button(action: {
                            pasteOTP()
                        }) {
                            Label("Paste Code", systemImage: "doc.on.clipboard")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(Color(#colorLiteral(red: 0.36, green: 0.57, blue: 0.98, alpha: 1)))
                                .padding(.vertical, 12)
                                .padding(.horizontal, 24)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color(#colorLiteral(red: 0.36, green: 0.57, blue: 0.98, alpha: 1)), lineWidth: 1)
                                )
                        }
                        .buttonStyle(PlainButtonStyle())
                        .padding(.top, -10)
                        .padding(.horizontal, 30)
                    }
                    .padding(.horizontal, 50)
                    .padding(.vertical, 50)
                    .frame(maxWidth: horizontalSizeClass == .regular ? 600 : .infinity)
                }
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .alert(viewModel.alertMessage, isPresented: $viewModel.showAlert) {
            Button("OK", role: .cancel) { }
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    private func pasteOTP() {
        if let pastedString = UIPasteboard.general.string?.trimmingCharacters(in: .whitespacesAndNewlines) {
            // Extract only digits from pasted string
            let digits = pastedString.filter { "0123456789".contains($0) }
            
            // If we have at least the required number of digits
            if digits.count >= 6 {
                // Take only the first 6 digits
                let otpDigits = Array(digits.prefix(6))
                
                // Fill the OTP fields
                for (index, digit) in otpDigits.enumerated() where index < 6 {
                    viewModel.otpDigits[index] = String(digit)
                }
                
                // Move focus to the last field (or dismiss keyboard if all are filled)
                viewModel.focusedOTPDigit = 5
                
                // If all digits are filled, dismiss keyboard
                if viewModel.isValidOTP {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                                      to: nil,
                                                      from: nil,
                                                      for: nil)
                    }
                }
            }
        }
    }
}

struct PasswordChangeView: View {
    @ObservedObject var viewModel: LoginViewModel
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                ZStack {
                    // Reserve space matching scrollview height for proper centering
                    Color.clear
                        .frame(height: geometry.size.height)
                    
                    VStack(spacing: 40) {
                        // Header
                        VStack(spacing: 20) {
                            // Icon with gradient background
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            gradient: Gradient(colors: [
                                                Color.gray.opacity(0.2),
                                                Color.gray.opacity(0.1)
                                            ]),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 160, height: 160)
                                
                                Image(systemName: "key.fill")
                                    .font(.system(size: 70))
                                    .foregroundColor(Color(#colorLiteral(red: 0.2, green: 0.4, blue: 0.8, alpha: 1)))
                            }
                            .padding(.bottom, 10)
                            
                            Text("Create New Password")
                                .font(.system(size: 32, weight: .bold))
                                .multilineTextAlignment(.center)
                            
                            Text("Your password must meet all of the\nrequirements below")
                                .font(.system(size: 18))
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .lineSpacing(4)
                        }
                        .padding(.top, 0)
                        
                        // Password fields
                        VStack(spacing: 35) {
                            // Form fields container
                            VStack(spacing: 24) {
                                // New password
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("New Password")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.primary)
                                    
                                    HStack {
                                        Image(systemName: "lock.fill")
                                            .foregroundColor(.secondary)
                                            .frame(width: 30, height: 30)
                                            .font(.system(size: 20))
                                        
                                        if viewModel.showNewPassword {
                                            TextField("Enter new password", text: $viewModel.newPassword)
                                                .font(.system(size: 18))
                                                .frame(height: 60)
                                        } else {
                                            SecureField("Enter new password", text: $viewModel.newPassword)
                                                .font(.system(size: 18))
                                                .frame(height: 60)
                                        }
                                        
                                        Button(action: {
                                            viewModel.showNewPassword.toggle()
                                        }) {
                                            Image(systemName: viewModel.showNewPassword ? "eye.slash.fill" : "eye.fill")
                                                .foregroundColor(.secondary)
                                                .frame(width: 30, height: 30)
                                                .font(.system(size: 20))
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                    }
                                    .padding(.horizontal, 20)
                                    .background(Color(.systemGray6))
                                    .cornerRadius(16)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                                    )
                                }
                                
                                // Confirm password
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Confirm Password")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.primary)
                                    
                                    HStack {
                                        Image(systemName: "lock.fill")
                                            .foregroundColor(.secondary)
                                            .frame(width: 30, height: 30)
                                            .font(.system(size: 20))
                                        
                                        if viewModel.showConfirmPassword {
                                            TextField("Confirm new password", text: $viewModel.confirmPassword)
                                                .font(.system(size: 18))
                                                .frame(height: 60)
                                        } else {
                                            SecureField("Confirm new password", text: $viewModel.confirmPassword)
                                                .font(.system(size: 18))
                                                .frame(height: 60)
                                        }
                                        
                                        Button(action: {
                                            viewModel.showConfirmPassword.toggle()
                                        }) {
                                            Image(systemName: viewModel.showConfirmPassword ? "eye.slash.fill" : "eye.fill")
                                                .foregroundColor(.secondary)
                                                .frame(width: 30, height: 30)
                                                .font(.system(size: 20))
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                    }
                                    .padding(.horizontal, 20)
                                    .background(Color(.systemGray6))
                                    .cornerRadius(16)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                                    )
                                }
                            }
                            .frame(maxWidth: horizontalSizeClass == .regular ? 550 : .infinity)
                            .padding(.horizontal, horizontalSizeClass == .regular ? 0 : 30)
                            
                            // Password requirements
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Password Requirements")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.primary)
                                
                                VStack(alignment: .leading, spacing: 12) {
                                    RequirementRow(text: "At least 8 characters", isMet: viewModel.newPassword.count >= 8)
                                    RequirementRow(text: "Contains uppercase letter", isMet: viewModel.newPassword.contains(where: { $0.isUppercase }))
                                    RequirementRow(text: "Contains lowercase letter", isMet: viewModel.newPassword.contains(where: { $0.isLowercase }))
                                    RequirementRow(text: "Contains number", isMet: viewModel.newPassword.contains(where: { $0.isNumber }))
                                    RequirementRow(text: "Contains special character", isMet: viewModel.newPassword.contains(where: { !$0.isLetter && !$0.isNumber }))
                                    RequirementRow(text: "Passwords match", isMet: !viewModel.confirmPassword.isEmpty && viewModel.newPassword == viewModel.confirmPassword)
                                }
                                .padding(20)
                                .background(Color(.systemGray6).opacity(0.5))
                                .cornerRadius(16)
                            }
                            .frame(maxWidth: horizontalSizeClass == .regular ? 550 : .infinity)
                            .padding(.horizontal, horizontalSizeClass == .regular ? 0 : 30)
                        }
                        
                        // Change password button - keep same size and style as login button
                        Button(action: {
                            viewModel.changePassword()
                        }) {
                            HStack {
                                if viewModel.isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(1.2)
                                } else {
                                    Text("Change Password")
                                        .font(.system(size: 18, weight: .semibold))
                                }
                            }
                            .frame(maxWidth: horizontalSizeClass == .regular ? 550 : .infinity)
                            .frame(height: 60)
                            .background(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color(#colorLiteral(red: 0.36, green: 0.57, blue: 0.98, alpha: 1)),
                                        Color(#colorLiteral(red: 0.2, green: 0.4, blue: 0.8, alpha: 1))
                                    ]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                                .opacity(viewModel.isValidNewPassword ? 1 : 0.6)
                            )
                            .foregroundColor(.white)
                            .cornerRadius(16)
                            .shadow(color: Color(#colorLiteral(red: 0.36, green: 0.57, blue: 0.98, alpha: 0.3)), radius: 8, x: 0, y: 4)
                        }
                        .disabled(viewModel.isLoading || !viewModel.isValidNewPassword)
                        .padding(.horizontal, horizontalSizeClass == .regular ? 0 : 30)
                    }
                    .padding(.horizontal, 50)
                    .padding(.vertical, 50)
                    .frame(maxWidth: horizontalSizeClass == .regular ? 600 : .infinity)
                }
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .alert(viewModel.alertMessage, isPresented: $viewModel.showAlert) {
            Button("OK", role: .cancel) { }
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct OTPDigitField: View {
    @Binding var text: String
    let isFocused: Bool
    let onFocus: () -> Void
    @FocusState private var focused: Bool
    var index: Int // Add index to know position
    var onTextChange: (Int, String) -> Void // Add callback for text changes
    
    var body: some View {
        TextField("", text: $text)
            .keyboardType(.numberPad)
            .textContentType(index == 0 ? .oneTimeCode : nil) // Only set on first field
            .multilineTextAlignment(.center)
            .font(.system(size: 24, weight: .bold))
            .frame(width: 54, height: 60)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isFocused ? Color.blue : Color.gray.opacity(0.3), lineWidth: 2)
            )
            .focused($focused)
            .onChange(of: text) { newValue in
                // Handle digit entered
                if newValue.count > 0 {
                    // Ensure only one digit
                    if newValue.count > 1 {
                        text = String(newValue.prefix(1))
                    }
                    
                    // Notify parent that text changed
                    onTextChange(index, text)
                } else if newValue.isEmpty {
                    // If text was deleted (backspace), notify parent
                    onTextChange(index, "")
                }
            }
            .onAppear {
                if isFocused {
                    focused = true
                }
            }
            .onChange(of: isFocused) { newValue in
                focused = newValue
            }
            .onTapGesture {
                onFocus()
            }
            // Filter to only allow digits
            .onReceive(Just(text)) { newValue in
                let filtered = newValue.filter { "0123456789".contains($0) }
                if filtered != newValue {
                    text = filtered
                }
            }
            // Add paste menu item to individual fields
            .contextMenu {
                Button("Paste") {
                    if let pastedString = UIPasteboard.general.string?.trimmingCharacters(in: .whitespacesAndNewlines) {
                        // Extract only digits from pasted string
                        let digits = pastedString.filter { "0123456789".contains($0) }
                        if !digits.isEmpty {
                            // Take the first digit for this field
                            text = String(digits.first!)
                            onTextChange(index, text)
                        }
                    }
                }
            }
    }
}

struct RequirementRow: View {
    let text: String
    let isMet: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isMet ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 20))
                .foregroundColor(isMet ? .green : .gray.opacity(0.7))
            
            Text(text)
                .font(.callout)
                .foregroundColor(isMet ? .primary : .secondary)
        }
        .contentShape(Rectangle())
    }
}

struct SplashScreenView: View {
    @State private var isActive = false
    @State private var size = 0.8
    @State private var opacity = 0.5
    
    var body: some View {
        if isActive {
            LoginView()
        } else {
            ZStack {
                Color(.systemBackground)
                    .ignoresSafeArea()
                
                VStack {
                    Image(systemName: "car.circle.fill")
                        .font(.system(size: 120))
                        .foregroundColor(.blue)
                    
                    Text("Fleet Master")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                        .padding(.top, 10)
                }
                .scaleEffect(size)
                .opacity(opacity)
                .onAppear {
                    withAnimation(.easeIn(duration: 1.2)) {
                        self.size = 1.0
                        self.opacity = 1.0
                    }
                }
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    withAnimation {
                        self.isActive = true
                    }
                }
            }
        }
    }
}

#Preview {
    LoginView()
}

#Preview("Splash") {
    SplashScreenView()
}

#Preview("2FA") {
    TwoFactorAuthView(viewModel: LoginViewModel())
}

#Preview("Password Change") {
    PasswordChangeView(viewModel: LoginViewModel())
} 
