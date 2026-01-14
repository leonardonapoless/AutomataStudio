import SwiftUI

struct ContentView: View {
    @Binding var document: AutomataDocument
    @State private var selectedStates: Set<UUID> = []
    @State private var canvasMode: AutomataStudio.CanvasMode = .view
    
    var body: some View {
        NavigationSplitView {
            // sidebar
            VStack(alignment: .leading, spacing: 8) {
                Text("Automaton")
                    .font(.headline)
                
                Text(document.automaton.type.rawValue)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text("\(document.automaton.states.count) states • \(document.automaton.transitions.count) transitions")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            .padding()
            .navigationSplitViewColumnWidth(min: 200, ideal: 250)
        } content: {
            // main canvas area
            VStack(spacing: 0) {
                // simple toolbar
                HStack {
                    Picker("Mode", selection: $canvasMode) {
                        ForEach(AutomataStudio.CanvasMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 400)
                    
                    Spacer()
                    
                    Button("Add State") {
                        addState()
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
                .background(.regularMaterial)
                
                Divider()
                
                // simple canvas
                GeometryReader { geometry in
                    ZStack {
                        Rectangle()
                            .fill(.ultraThinMaterial)
                        
                        // draw states
                        ForEach(document.automaton.states) { state in
                            StateView(state: state, isSelected: selectedStates.contains(state.id))
                                .onTapGesture {
                                    handleStateTap(state)
                                }
                                .contextMenu {
                                    StateContextMenu(
                                        state: state,
                                        automaton: document.automaton,
                                        onSetInitial: { setAsInitial(state) },
                                        onToggleFinal: { toggleFinal(state) },
                                        onRename: { renameState(state) },
                                        onDelete: { deleteState(state) },
                                        onCopy: { copyState(state) },
                                        onPaste: { pasteState() }
                                    )
                                }
                        }
                    }
                }
            }
        } detail: {
            // inspector
            VStack(alignment: .leading, spacing: 12) {
                Text("Inspector")
                    .font(.headline)
                
                if selectedStates.count == 1, let stateId = selectedStates.first {
                    if let state = document.automaton.getState(by: stateId) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("State: \(state.displayName)")
                                .font(.subheadline)
                            
                            Toggle("Start State", isOn: Binding(
                                get: { state.isStart },
                                set: { _ in toggleStartState(state) }
                            ))
                            
                            Toggle("Accepting State", isOn: Binding(
                                get: { state.isAccepting },
                                set: { _ in toggleAcceptingState(state) }
                            ))
                        }
                    }
                } else {
                    Text("Select a state to edit properties")
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding()
            .navigationSplitViewColumnWidth(min: 250, ideal: 300)
        }
        .navigationTitle(document.automaton.name)
    }
    
    private func addState() {
        let newState = document.automaton.addState(at: CGPoint(x: 200, y: 200))
        selectedStates = [newState.id]
    }
    
    private func toggleStartState(_ state: AutomatonState) {
        var updatedState = state
        updatedState.isStart.toggle()
        document.automaton.updateState(updatedState)
    }
    
    private func toggleAcceptingState(_ state: AutomatonState) {
        var updatedState = state
        updatedState.isAccepting.toggle()
        document.automaton.updateState(updatedState)
    }
    
    // MARK: - Context Menu Actions
    
    private func handleStateTap(_ state: AutomatonState) {
        if canvasMode == .view {
            selectedStates = [state.id]
        } else if canvasMode == .delete {
            document.automaton.removeState(state.id)
            selectedStates.remove(state.id)
        }
    }
    
    private func setAsInitial(_ state: AutomatonState) {
        // remove start from all other states
        for var otherState in document.automaton.states {
            if otherState.isStart && otherState.id != state.id {
                otherState.isStart = false
                document.automaton.updateState(otherState)
            }
        }
        
        // set this state as start
        var updatedState = state
        updatedState.isStart = true
        document.automaton.updateState(updatedState)
    }
    
    private func toggleFinal(_ state: AutomatonState) {
        var updatedState = state
        updatedState.isAccepting.toggle()
        document.automaton.updateState(updatedState)
    }
    
    private func renameState(_ state: AutomatonState) {
        // TODO: implement rename dialog
        print("Rename state: \(state.name)")
    }
    
    private func deleteState(_ state: AutomatonState) {
        document.automaton.removeState(state.id)
        selectedStates.remove(state.id)
    }
    
    private func copyState(_ state: AutomatonState) {
        // TODO: implement clipboard functionality
        print("Copy state: \(state.name)")
    }
    
    private func pasteState() {
        // TODO: implement clipboard functionality
        print("Paste state")
    }
}

struct StateView: View {
    let state: AutomatonState
    let isSelected: Bool
    
    var body: some View {
        ZStack {
            // state circle
            Circle()
                .fill(stateColor)
                .frame(width: 40, height: 40)
                .overlay(
                    Circle()
                        .stroke(.primary, lineWidth: isSelected ? 3 : 1)
                )
            
            // start state indicator
            if state.isStart {
                Circle()
                    .fill(.blue)
                    .frame(width: 8, height: 8)
                    .offset(x: -30, y: 0)
            }
            
            // accepting state indicator
            if state.isAccepting {
                Circle()
                    .stroke(.green, lineWidth: 2)
                    .frame(width: 44, height: 44)
            }
            
            // state label
            Text(state.displayName)
                .font(.caption)
                .fontWeight(.medium)
                .offset(y: 25)
        }
        .position(state.position)
    }
    
    private var stateColor: Color {
        if state.isStart && state.isAccepting {
            return .purple.opacity(0.3)
        } else if state.isStart {
            return .blue.opacity(0.3)
        } else if state.isAccepting {
            return .green.opacity(0.3)
        } else {
            return .gray.opacity(0.2)
        }
    }
}

#Preview {
    ContentView(document: .constant(AutomataDocument()))
}
