import SwiftUI

struct CustomFader: View {
    @Binding var value: Double
    let label: String
    @State private var startValue: Double? = nil
    
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
                                if startValue == nil {
                                    startValue = value
                                    Haptics.playClick()
                                }
                                let delta = -drag.translation.height / geo.size.height
                                let newValue = min(max((startValue ?? value) + delta, 0), 1)
                                if abs(value - newValue) > 0.001 {
                                    value = newValue
                                }
                            }
                            .onEnded { _ in
                                startValue = nil
                                Haptics.playAlignment()
                            }
                    )
            }
            .frame(maxWidth: .infinity)
        }
        .frame(height: 200)
    }
}
