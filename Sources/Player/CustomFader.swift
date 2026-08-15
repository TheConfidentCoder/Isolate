import SwiftUI
import AppKit

struct CustomFader: View {
    @Binding var value: Double
    let label: String
    
    @State private var startValue: Double? = nil
    @State private var hitTop = false
    @State private var hitBottom = false
    @State private var isHovered = false
    @State private var isDragging = false
    @State private var lastClickTime: Date? = nil
    @State private var isClippingHeld = false
    @State private var clipHoldTask: Task<Void, Never>? = nil
    
    var body: some View {
        GeometryReader { geo in
            let trackHeight = max(1, geo.size.height)
            let thumbCenterY = trackHeight * (1.0 - CGFloat(value))
            
            ZStack(alignment: .top) {
                // 1. Full Track Hit Area for Immediate Dragging and Jump-to-Click
                Color.clear
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0, coordinateSpace: .local)
                            .onChanged { drag in
                                isDragging = true
                                
                                if startValue == nil {
                                    let now = Date()
                                    if let last = lastClickTime, now.timeIntervalSince(last) < 0.30 {
                                        // Double Click Reset to 100%
                                        Haptics.playClick()
                                        withAnimation(.easeOut(duration: 0.12)) {
                                            value = 1.0
                                        }
                                        triggerClipHold()
                                        lastClickTime = nil
                                        startValue = nil
                                        return
                                    }
                                    lastClickTime = now
                                    
                                    // Check if drag started on/near thumb vs track jump
                                    let clickY = drag.startLocation.y
                                    let distFromThumb = abs(clickY - thumbCenterY)
                                    if distFromThumb <= 16 {
                                        startValue = value
                                    } else {
                                        let jumpedVal = min(max(Double(1.0 - (clickY / trackHeight)), 0.0), 1.0)
                                        value = jumpedVal
                                        startValue = jumpedVal
                                        Haptics.playClick()
                                        if jumpedVal >= 0.995 { triggerClipHold() }
                                    }
                                    
                                    hitTop = (value >= 0.999)
                                    hitBottom = (value <= 0.001)
                                }
                                
                                let isOptionHeld = NSEvent.modifierFlags.contains(.option)
                                let multiplier = isOptionHeld ? 0.25 : 1.0
                                let delta = (-drag.translation.height / trackHeight) * multiplier
                                let targetVal = min(max((startValue ?? value) + delta, 0.0), 1.0)
                                
                                if targetVal >= 0.999 && !hitTop {
                                    hitTop = true
                                    Haptics.playAlignment()
                                    triggerClipHold()
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
                                isDragging = false
                                startValue = nil
                                hitTop = false
                                hitBottom = false
                            }
                    )
                
                // 2. Vertical Track Visuals (Centered) with 1.2s Peak-Hold Clip LED
                ZStack(alignment: .top) {
                    let isLit = isClippingHeld || value >= 0.995
                    Circle()
                        .fill(isLit ? Color.red : Color.red.opacity(0.18))
                        .frame(width: 5, height: 5)
                        .shadow(color: isLit ? Color.red : Color.clear, radius: 3)
                        .padding(.bottom, 4)
                        .animation(.easeOut(duration: 0.25), value: isLit)
                    
                    ZStack(alignment: .bottom) {
                        // Track background slot
                        Rectangle()
                            .fill(Color(white: 0.12))
                            .frame(width: 4, height: trackHeight - 12)
                        
                        // Track fill (active level)
                        Rectangle()
                            .fill(Color.red)
                            .frame(width: 4, height: max(0, (trackHeight - 12) * CGFloat(value)))
                    }
                    .padding(.top, 10)
                }
                .frame(width: 6, height: trackHeight)
                .position(x: geo.size.width / 2.0, y: trackHeight / 2.0)
                .allowsHitTesting(false)
                
                // 3. Fader Thumb (Nothing OS Hardware Style) with 48x26pt Generous Hit Target & Red Glow
                ZStack {
                    // Expanded touch target (48x26pt)
                    Color.clear
                        .frame(width: 48, height: 26)
                        .contentShape(Rectangle())
                    
                    // Visual Hardware Thumb
                    ZStack {
                        Rectangle()
                            .fill(Color.white)
                            .frame(width: 36, height: 12)
                            .overlay(
                                Rectangle()
                                    .stroke(
                                        (isHovered || isDragging)
                                            ? Color.red.opacity(0.85)
                                            : Color.white.opacity(0.4),
                                        lineWidth: (isHovered || isDragging) ? 1.5 : 1
                                    )
                            )
                            .shadow(
                                color: Color.red.opacity((isHovered || isDragging) ? 0.6 : 0.0),
                                radius: 4,
                                x: 0,
                                y: 0
                            )
                        
                        // Red center line marker
                        Rectangle()
                            .fill(Color.red)
                            .frame(width: 20, height: 1.5)
                    }
                }
                .position(x: geo.size.width / 2.0, y: thumbCenterY)
                .onHover { hovering in
                    isHovered = hovering
                    if hovering {
                        NSCursor.pointingHand.push()
                    } else {
                        NSCursor.pop()
                    }
                }
                .allowsHitTesting(false)
            }
        }
        .frame(minHeight: 160, maxHeight: .infinity)
    }
    
    private func triggerClipHold() {
        isClippingHeld = true
        clipHoldTask?.cancel()
        clipHoldTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            guard !Task.isCancelled else { return }
            if value < 0.995 {
                withAnimation(.easeOut(duration: 0.35)) {
                    isClippingHeld = false
                }
            }
        }
    }
}
