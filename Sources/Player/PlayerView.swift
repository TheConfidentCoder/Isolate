import SwiftUI

struct GridBackground: View {
    var body: some View {
        ZStack {
            Color(white: 0.05).ignoresSafeArea()
            GeometryReader { geometry in
                Path { path in
                    let step: CGFloat = 20
                    for x in stride(from: 0, to: geometry.size.width, by: step) {
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: geometry.size.height))
                    }
                    for y in stride(from: 0, to: geometry.size.height, by: step) {
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: geometry.size.width, y: y))
                    }
                }
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
            }
        }
    }
}

struct PlayerView: View {
    @Environment(AudioEngineManager.self) private var engineManager

    var body: some View {
        VStack(spacing: 0) {
            VStack {
                HStack {
                    Text(engineManager.currentTrackName)
                        .font(.custom("DotGothic16-Regular", size: 24))
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    OscilloscopePlaceholder()
                }
                .padding()
                
                HStack(spacing: 40) {
                    StemChannelView(title: "VOCALS")
                    StemChannelView(title: "BASS")
                    StemChannelView(title: "DRUMS")
                    StemChannelView(title: "OTHER")
                }
                .padding()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            TransportBar()
        }
        .background(GridBackground())
    }
}

struct StemChannelView: View {
    let title: String
    @State private var volume: Double = 0.8
    
    var body: some View {
        VStack(spacing: 16) {
            Text(title)
                .font(.custom("DotGothic16-Regular", size: 18))
                .foregroundColor(.white)
            
            Text("\(Int(volume * 100))")
                .font(.custom("DotGothic16-Regular", size: 16))
                .foregroundColor(.gray)
            
            CustomFader(value: $volume, label: title)
            
            HStack(spacing: 8) {
                Button("M") { Haptics.playClick() }
                    .font(.custom("DotGothic16-Regular", size: 14))
                    .frame(width: 32, height: 32)
                    .background(Color.clear)
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.gray, lineWidth: 1))
                    .foregroundColor(.white)
                
                Button("S") { Haptics.playClick() }
                    .font(.custom("DotGothic16-Regular", size: 14))
                    .frame(width: 32, height: 32)
                    .background(Color.clear)
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.gray, lineWidth: 1))
                    .foregroundColor(.white)
            }
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 10)
        .background(Color.black.opacity(0.4))
        .border(Color.white.opacity(0.1), width: 1)
    }
}

struct OscilloscopePlaceholder: View {
    @State private var isAnimating = false
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<20, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.red)
                    .frame(width: 4, height: isAnimating ? CGFloat.random(in: 5...30) : 5)
                    .animation(.easeInOut(duration: 0.2).repeatForever(), value: isAnimating)
            }
        }
        .frame(height: 40)
        .onAppear {
            isAnimating = true
        }
    }
}

struct TransportBar: View {
    @Environment(AudioEngineManager.self) private var engineManager
    
    var body: some View {
        HStack {
            Text("00:00")
                .font(.custom("DotGothic16-Regular", size: 18))
                .foregroundColor(.red)
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 2)
                    Rectangle()
                        .fill(Color.red)
                        .frame(width: geo.size.width * engineManager.playbackProgress, height: 2)
                }
                .frame(maxHeight: .infinity)
            }
            .frame(height: 40)
            
            Button(action: {
                Haptics.playClick()
                engineManager.togglePlayback()
            }) {
                Image(systemName: engineManager.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.black)
                    .frame(width: 48, height: 48)
                    .background(Color.red)
                    .clipShape(Circle())
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 30)
        .padding(.vertical, 15)
        .background(Color.black)
        .border(Color.white.opacity(0.1), width: 1)
    }
}
