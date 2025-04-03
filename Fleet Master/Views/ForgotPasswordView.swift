import SwiftUI

struct ForgotPasswordView: View {
    @ObservedObject var viewModel: LoginViewModel
    @Environment(\.dismiss) private var dismiss
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
                                
                                Image(systemName: "lock.open.fill")
                                    .font(.system(size: 70))
                                    .foregroundColor(Color(#colorLiteral(red: 0.2, green: 0.4, blue: 0.8, alpha: 1)))
                            }
                            .padding(.bottom, 10)
                            
                            Text("Forgot Password")
                                .font(.system(size: 32, weight: .bold))
                                .multilineTextAlignment(.center)
                            
                            Text("Enter your email address to receive\na verification code")
                                .font(.system(size: 18))
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.horizontal, 30)
                        
                        // Email input
                        VStack(spacing: 24) {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Email Address")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.primary)
                                
                                HStack {
                                    Image(systemName: "envelope.fill")
                                        .foregroundColor(.secondary)
                                        .frame(width: 30, height: 30)
                                        .font(.system(size: 20))
                                    
                                    TextField("Enter your email", text: $viewModel.email)
                                        .font(.system(size: 18))
                                        .frame(height: 60)
                                        .keyboardType(.emailAddress)
                                        .autocapitalization(.none)
                                        .autocorrectionDisabled()
                                        .textContentType(.emailAddress)
                                }
                                .padding(.horizontal, 20)
                                .background(Color(.systemGray6))
                                .cornerRadius(16)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                                )
                            }
                            .frame(maxWidth: horizontalSizeClass == .regular ? 550 : .infinity)
                            .padding(.horizontal, horizontalSizeClass == .regular ? 0 : 30)
                        }
                        
                        // Send Verification Code button
                        Button(action: {
                            // Send verification code and navigate to OTP view
                            viewModel.forgotPassword()
                        }) {
                            HStack {
                                if viewModel.isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(1.2)
                                } else {
                                    Text("Send Verification Code")
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
                                .opacity(viewModel.isValidEmail ? 1 : 0.6)
                            )
                            .foregroundColor(.white)
                            .cornerRadius(16)
                            .shadow(color: Color(#colorLiteral(red: 0.36, green: 0.57, blue: 0.98, alpha: 0.3)), radius: 8, x: 0, y: 4)
                        }
                        .disabled(viewModel.isLoading || !viewModel.isValidEmail)
                        .padding(.horizontal, horizontalSizeClass == .regular ? 0 : 30)
                        
                        // Back to Login
                        Button(action: {
                            dismiss()
                        }) {
                            Text("Back to Login")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(Color(#colorLiteral(red: 0.36, green: 0.57, blue: 0.98, alpha: 1)))
                                .padding(.vertical, 12)
                                .padding(.horizontal, 24)
                        }
                        .buttonStyle(PlainButtonStyle())
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
        .navigationBarBackButtonHidden(true)
        .navigationBarItems(leading: Button(action: {
            dismiss()
        }) {
            HStack {
                Image(systemName: "chevron.left")
                Text("Back")
            }
            .foregroundColor(.blue)
        })
        .navigationBarTitleDisplayMode(.inline)
    }
} 