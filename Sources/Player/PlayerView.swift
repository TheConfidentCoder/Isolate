import SwiftUI

struct PlayerView: View {
    var body: some View {
        VStack {
            Text("ISOLATE MIXER")
                .font(.custom("DotGothic16-Regular", size: 36))
                .foregroundColor(Color(red: 1.0, green: 0, blue: 0))
            
            HStack(spacing: 40) {
                StemChannelView(title: "VOCALS")
                StemChannelView(title: "BASS")
                StemChannelView(title: "DRUMS")
                StemChannelView(title: "OTHER")
            }
            .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
    }
}

struct StemChannelView: View {
    let title: String
    @State private var volume: Double = 0.8
    
    var body: some View {
        VStack(spacing: 20) {
            Text(title)
                .font(.custom("DotGothic16-Regular", size: 18))
                .foregroundColor(.white)
            
            Slider(value: $volume, in: 0...1)
                .frame(height: 200)
                // In a real app we'd use a custom vertical slider to match the "Nothing" design
            
            HStack {
                Button("M") { }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                Button("S") { }
                    .buttonStyle(.bordered)
            }
        }
        .padding()
        .border(Color.gray.opacity(0.3))
    }
}
