import SwiftUI

struct StateContextMenu: View {
    let state: AutomatonState
    let automaton: Automaton
    let onSetInitial: () -> Void
    let onToggleFinal: () -> Void
    let onRename: () -> Void
    let onDelete: () -> Void
    let onCopy: () -> Void
    let onPaste: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onSetInitial) {
                Label("Set as Initial", systemImage: "play.circle")
            }
            .disabled(state.isStart)
            
            Button(action: onToggleFinal) {
                Label(state.isAccepting ? "Remove Final" : "Set as Final", 
                      systemImage: state.isAccepting ? "circle" : "checkmark.circle")
            }
            
            Divider()
            
            Menu("Align") {
                Button("Align Horizontally") {
                }
                Button("Align Vertically") {
                }
            }
            
            Divider()
            
            Button(action: onRename) {
                Label("Change Name", systemImage: "pencil")
            }
            
            Divider()
            
            Button(action: onCopy) {
                Label("Copy", systemImage: "doc.on.doc")
            }
            .keyboardShortcut("c", modifiers: .command)
            
            Button(action: onPaste) {
                Label("Paste", systemImage: "doc.on.clipboard")
            }
            .keyboardShortcut("v", modifiers: .command)
            .disabled(true) 
            
            Divider()
            
            Button(action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
            .keyboardShortcut(.delete)
            .foregroundColor(.red)
        }
        .padding(.vertical, 4)
    }
}

struct TransitionContextMenu: View {
    let transition: Transition
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onCopy: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onEdit) {
                Label("Edit Symbols", systemImage: "pencil")
            }
            
            Divider()
            
            Button(action: onCopy) {
                Label("Copy", systemImage: "doc.on.doc")
            }
            .keyboardShortcut("c", modifiers: .command)
            
            Divider()
            
            Button(action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
            .keyboardShortcut(.delete)
            .foregroundColor(.red)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    StateContextMenu(
        state: AutomatonState(name: "q0", position: .zero, isStart: true, isAccepting: false),
        automaton: Automaton(name: "Test", type: .dfa),
        onSetInitial: {},
        onToggleFinal: {},
        onRename: {},
        onDelete: {},
        onCopy: {},
        onPaste: {}
    )
}
