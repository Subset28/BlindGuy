import SwiftUI

struct RadarView: View {
    @State private var pulse: CGFloat = 1.0
    @State private var rotation: Double = 0
    
    var body: some View {
        ZStack {
            // Static Outer Rings
            ForEach(0..<4) { i in
                Circle()
                    .stroke(Color.green.opacity(0.1), lineWidth: 1)
                    .scaleEffect(CGFloat(i + 1) * 0.4)
            }
            
            // Pulsing Scanning Ring
            Circle()
                .stroke(Color.green.opacity(0.3), lineWidth: 2)
                .scaleEffect(pulse)
                .opacity(2.0 - Double(pulse))
                .onAppear {
                    withAnimation(Animation.easeInOut(duration: 2).repeatForever(autoreverses: false)) {
                        pulse = 2.0
                    }
                }
            
            // Scanning Beam
            AngularGradient(gradient: Gradient(colors: [.green.opacity(0.5), .clear]), center: .center)
                .mask(Circle().stroke(lineWidth: 40))
                .rotationEffect(.degrees(rotation))
                .onAppear {
                    withAnimation(Animation.linear(duration: 4).repeatForever(autoreverses: false)) {
                        rotation = 360
                    }
                }
            
            // Center Dot (The Listener)
            Circle()
                .fill(Color.green)
                .frame(width: 12, height: 12)
                .shadow(color: .green, radius: 10)
        }
        .frame(width: 300, height: 300)
    }
}

#Preview {
    ZStack {
        Color.black.edgesIgnoringSafeArea(.all)
        RadarView()
    }
}
