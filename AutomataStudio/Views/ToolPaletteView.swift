import SwiftUI

struct ToolPaletteView: View {
    @Binding var selectedTool: CanvasTool
    @Binding var canvasMode: CanvasMode
    
    var body: some View {
        VStack(spacing: 8) {
            Text("Tools")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 8)
            
            VStack(spacing: 4) {
                ToolButton(
                    icon: "hand.point.up.left",
                    tool: .select,
                    isSelected: selectedTool == .select
                ) {
                    selectedTool = .select
                    canvasMode = .view
                }
                
                ToolButton(
                    icon: "hand.point.up.left.fill",
                    tool: .pan,
                    isSelected: selectedTool == .pan
                ) {
                    selectedTool = .pan
                    canvasMode = .view
                }
                
                ToolButton(
                    icon: "circle",
                    tool: .state,
                    isSelected: selectedTool == .state
                ) {
                    selectedTool = .state
                    canvasMode = .state
                }
                
                ToolButton(
                    icon: "arrow.right",
                    tool: .transition,
                    isSelected: selectedTool == .transition
                ) {
                    selectedTool = .transition
                    canvasMode = .transition
                }
                
                ToolButton(
                    icon: "trash",
                    tool: .delete,
                    isSelected: selectedTool == .delete
                ) {
                    selectedTool = .delete
                    canvasMode = .delete
                }
            }
            
            Spacer()
        }
        .frame(width: 60)
        .background(.regularMaterial)
    }
}

struct ToolButton: View {
    let icon: String
    let tool: CanvasTool
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .frame(width: 32, height: 32)
                .background(isSelected ? Color.accentColor : Color.clear)
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }
}

enum CanvasTool: String, CaseIterable {
    case select = "Select"
    case pan = "Pan"
    case state = "State"
    case transition = "Transition"
    case delete = "Delete"
    
    var systemImage: String {
        switch self {
        case .select: return "hand.point.up.left"
        case .pan: return "hand.point.up.left.fill"
        case .state: return "circle"
        case .transition: return "arrow.right"
        case .delete: return "trash"
        }
    }
}

#Preview {
    ToolPaletteView(
        selectedTool: .constant(.select),
        canvasMode: .constant(.view)
    )
}
