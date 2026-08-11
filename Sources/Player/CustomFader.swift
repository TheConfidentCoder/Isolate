import SwiftUI

struct CustomFader: View {
    @Binding var value: Double
    let label: String
    
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                // Track background
                Rectangle()
                    .fill(Color(white: 0.15))
                    .frame(width: 4)
                
                // Track fill (red)
                Rectangle()
                    .fill(Color.red)
                    .frame(width: 4, height: max(0, geo.size.height * CGFloat(value)))
                
                // Fader thumb
                Rectangle()
                    .fill(Color.white)
                    .frame(width: 40, height: 12)
                    .offset(y: -geo.size.height * CGFloat(value) + 6)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { drag in
                                let delta = -drag.translation.height / geo.size.height
                                let newValue = min(max(value + delta, 0), 1)
                                if abs(value - newValue) > 0.01 {
                                    value = newValue
                                }
                            }
                            .onEnded { _ in
                                Haptics.playAlignment()
                            }
                    )
            }
            .frame(maxWidth: .infinity)
        }
        .frame(height: 200)
    }
}
