import SwiftUI

struct ToolPaletteView: View {
    @Binding var canvasMode: CanvasMode
    
    var body: some View {
        VStack(spacing: 8) {
            Text("Tools")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 8)
            
            VStack(spacing: 4) {
                ForEach(CanvasMode.allCases, id: \.self) { mode in
                    Button {
                        canvasMode = mode
                    } label: {
                        Image(systemName: mode.systemImage)
                            .font(.system(size: 16))
                            .frame(width: 32, height: 32)
                            .background(canvasMode == mode ? Color.accentColor : Color.clear)
                            .foregroundColor(canvasMode == mode ? .white : .primary)
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    .help(mode.rawValue)
                }
            }
            
            Spacer()
        }
        .frame(width: 60)
        .background(.regularMaterial)
    }
}

#Preview {
    ToolPaletteView(canvasMode: .constant(.select))
}
