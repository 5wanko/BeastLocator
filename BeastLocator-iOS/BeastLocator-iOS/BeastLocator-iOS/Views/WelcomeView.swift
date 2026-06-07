import SwiftUI

struct WelcomeView: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack {
            // Elegant gradient background
            LinearGradient(
                colors: [Color(red: 0.1, green: 0.12, blue: 0.18), Color(red: 0.05, green: 0.06, blue: 0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VSpacer(30)
            
            VStack(spacing: 24) {
                // Large styled compass icon
                Image(systemName: "safari.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(
                        .linearGradient(
                            colors: [.cyan, .blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: .blue.opacity(0.3), radius: 10, x: 0, y: 5)
                
                Text("welcome_title")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                // Content Card
                VStack(spacing: 16) {
                    Text("welcome_message")
                        .font(.body)
                        .foregroundColor(.white.opacity(0.85))
                        .multilineTextAlignment(.center)
                        .lineSpacing(6)
                        .padding()
                }
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white.opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.white.opacity(0.12), lineWidth: 1)
                        )
                )
                .padding(.horizontal, 24)
                
                Spacer()
                
                Button(action: {
                    DestinationStore.shared.welcomeCompleted = true
                    dismiss()
                }) {
                    Text("welcome_start_button")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            LinearGradient(
                                colors: [.cyan, .blue],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(14)
                        .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 30)
            }
        }
    }
}

struct VSpacer: View {
    let size: CGFloat
    init(_ size: CGFloat) { self.size = size }
    var body: some View { Spacer().frame(height: size) }
}
