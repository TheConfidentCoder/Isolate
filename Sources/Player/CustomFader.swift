import SwiftUI

struct CustomFader: View {
    @Binding var value: Double
    let label: String
    @State private var startValue: Double? = nil
    @State private var hitTop = false
    @State private var hitBottom = false
    
    var body: some View {
        GeometryReader { geo in
            let trackHeight = max(1, geo.size.height)
            
            ZStack(alignment: .bottom) {
                // Track background slot
                Rectangle()
                    .fill(Color(white: 0.12))
                    .frame(width: 4)
                
                // Track fill (active level)
                Rectangle()
                    .fill(Color.red)
                    .frame(width: 4, height: max(0, trackHeight * CGFloat(value)))
                
                // Fader thumb (Hardware Style)
                ZStack {
                    Rectangle()
                        .fill(Color.white)
                        .frame(width: 36, height: 12)
                        .overlay(
                            Rectangle()
                                .stroke(Color.white.opacity(0.4), lineWidth: 1)
                        )
                    
                    // Red center line marker
                    Rectangle()
                        .fill(Color.red)
                        .frame(width: 20, height: 1.5)
                }
                .offset(y: -trackHeight * CGFloat(value) + 6)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .onTapGesture(count: 2) {
                Haptics.playClick()
                withAnimation(.easeOut(duration: 0.12)) {
                    value = 1.0
                }
            }
            .gesture(
                DragGesture(minimumDistance: 2)
                    .onChanged { drag in
                        if startValue == nil {
                            startValue = value
                            Haptics.playClick()
                            hitTop = (value >= 0.999)
                            hitBottom = (value <= 0.001)
                        }
                        let delta = -drag.translation.height / trackHeight
                        let targetVal = min(max((startValue ?? value) + delta, 0.0), 1.0)
                        
                        if targetVal >= 0.999 && !hitTop {
                            hitTop = true
                            Haptics.playAlignment()
                        } else if targetVal < 0.999 {
                            hitTop = false
                        }
                        
                        if targetVal <= 0.001 && !hitBottom {
                            hitBottom = true
                            Haptics.playAlignment()
                        } else if targetVal > 0.001 {
                            hitBottom = false
                        }
                        
                        if abs(value - targetVal) > 0.0005 {
                            value = targetVal
                        }
                    }
                    .onEnded { _ in
                        startValue = nil
                        hitTop = false
                        hitBottom = false
                    }
            )
        }
        .frame(minHeight: 160, maxHeight: .infinity)
    }
}
