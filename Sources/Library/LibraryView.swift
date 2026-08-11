import SwiftUI

struct LibraryView: View {
    var body: some View {
        List {
            Section("LIBRARY") {
                Text("Drag & Drop Audio Files Here")
                    .font(.custom("DotGothic16-Regular", size: 14))
                    .foregroundColor(.gray)
            }
        }
        .background(Color(white: 0.1))
        .scrollContentBackground(.hidden)
    }
}
