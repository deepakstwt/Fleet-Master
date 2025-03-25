import SwiftUI

struct SplashScreenView: View {
    @State private var isActive = false
    @State private var size = 0.8
    @State private var opacity = 0.5
    @State private var rotation = 0.0
    @State private var scale = 1.0
    
    var body: some View {
        if isActive {
            LoginView()
        } else {
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
                
                // Animated background circles
                Circle()
                    .fill(.white.opacity(0.1))
                    .frame(width: 400, height: 400)
                    .blur(radius: 50)
                    .offset(x: -100, y: -200)
                    .scaleEffect(scale)
                
                Circle()
                    .fill(.white.opacity(0.1))
                    .frame(width: 300, height: 300)
                    .blur(radius: 40)
                    .offset(x: 100, y: 200)
                    .scaleEffect(scale)
                
                VStack(spacing: 24) {
                    Spacer()
                    
                    // Logo with animation
                    ZStack {
                        Circle()
                            .fill(.white)
                            .frame(width: 160, height: 160)
                            .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                        
                        Image(systemName: "car.fill")
                            .font(.system(size: 70))
                            .foregroundColor(Color(#colorLiteral(red: 0.36, green: 0.57, blue: 0.98, alpha: 1)))
                            .rotationEffect(.degrees(rotation))
                    }
                    .padding(.bottom, 40)
                    
                    // App name with animation
                    Text("Fleet Master")
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .scaleEffect(size)
                        .opacity(opacity)
                    
                    // Tagline with animation
                    Text("Your comprehensive fleet\nmanagement solution")
                        .font(.system(size: 20))
                        .foregroundColor(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .lineSpacing(6)
                        .scaleEffect(size)
                        .opacity(opacity)
                    
                    Spacer()
                    
                    // Version info
                    Text("Version 1.0")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            .onAppear {
                // Start animations
                withAnimation(.easeIn(duration: 1.2)) {
                    self.size = 1.0
                    self.opacity = 1.0
                }
                
                // Rotate the car icon
                withAnimation(.linear(duration: 2.0).repeatForever(autoreverses: false)) {
                    self.rotation = 360
                }
                
                // Pulse the background circles
                withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                    self.scale = 1.2
                }
                
                // Transition to LoginView after delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                    withAnimation {
                        self.isActive = true
                    }
                }
            }
        }
    }
}

#Preview {
    SplashScreenView()
} 