import SwiftUI
import UniformTypeIdentifiers

struct AutomataStudioView: View {
    @Binding var document: AutomataDocument
    @StateObject private var canvasViewModel = CanvasViewModel()
    @StateObject private var inspectorViewModel = InspectorViewModel()
    
    // selection state
    @State private var selectedStates: Set<UUID> = []
    @State private var selectedTransitions: Set<UUID> = []
    @State private var canvasMode: CanvasMode = .view
    
    // ui state
    @State private var showInspector = true
    @State private var showSimulation = false
    @State private var simulationInput = ""
    @State private var showDeleteConfirmation = false
    @State private var itemToDelete: DeleteTarget?
    
    private enum DeleteTarget {
        case selection
        case specific(at: CGPoint)
    }
    
    var body: some View {
        NavigationSplitView {
            UnifiedSidebarView(
                automaton: document.automaton,
                selectedStates: $selectedStates,
                selectedTransitions: $selectedTransitions,
                inspectorViewModel: inspectorViewModel
            )
            .navigationSplitViewColumnWidth(min: 250, ideal: 300)
        } detail: {
            ZStack {
                AutomataCanvasView(
                    automaton: document.automaton,
                    canvasMode: $canvasMode,
                    selectedStates: $selectedStates,
                    selectedTransitions: $selectedTransitions,
                    viewModel: canvasViewModel,
                    onRenameState: { stateId in
                        // no need to set showInspector anymore, unified view handles it
                        if let state = document.automaton.getState(by: stateId) {
                            inspectorViewModel.selectState(state)
                        }
                    },
                    onEditTransition: { transitionId in
                        if let transition = document.automaton.getTransitions(from: UUID(), to: UUID()).first(where: { $0.id == transitionId }) ?? document.automaton.transitions.first(where: { $0.id == transitionId }) {
                            inspectorViewModel.selectTransition(transition)
                        }
                    }
                )
                .background(Color(nsColor: .windowBackgroundColor))
                
                // mode indicator overlay
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        ModeIndicator(mode: canvasMode)
                            .padding()
                    }
                }
            }
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    ControlGroup {
                        ForEach(CanvasMode.allCases, id: \.self) { mode in
                            Toggle(isOn: Binding(
                                get: { canvasMode == mode },
                                set: { _ in canvasMode = mode }
                            )) {
                                Label(mode.rawValue, systemImage: mode.systemImage)
                            }
                            .help("\(mode.rawValue) Mode (\(getShortcut(for: mode)))")
                        }
                    }
                    .controlGroupStyle(.navigation)
                    
                    Divider()
                    
                    Button {
                        showSimulation.toggle()
                    } label: {
                        Label("Simulate", systemImage: "play")
                    }
                    .buttonStyle(.glass)
                    .keyboardShortcut("R", modifiers: .command)
                    .help("Run Simulation (Cmd+R)")
                    
                    ControlGroup {
                        Button {
                            canvasViewModel.zoomOut()
                        } label: {
                            Label("Zoom Out", systemImage: "minus.magnifyingglass")
                        }
                        
                        Button {
                            canvasViewModel.zoomIn()
                        } label: {
                            Label("Zoom In", systemImage: "plus.magnifyingglass")
                        }
                        
                        Button {
                            canvasViewModel.zoomToFit()
                        } label: {
                            Label("Fit", systemImage: "arrow.up.left.and.down.right.magnifyingglass")
                        }
                    }
                }
            }
        }
        .navigationTitle(document.automaton.name)
        .sheet(isPresented: $showSimulation) {
            SimulationPanelView(automaton: document.automaton, input: $simulationInput)
        }
        .alert("Are you sure you want to delete?", isPresented: $showDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                deleteSelectedItems()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This action cannot be undone.")
        }
        // keyboard shortcuts (hidden buttons to capture keys)
        .background {
            ZStack {
                Button("") { canvasMode = .view }.keyboardShortcut("v", modifiers: [])
                Button("") { canvasMode = .state }.keyboardShortcut("s", modifiers: [])
                Button("") { canvasMode = .transition }.keyboardShortcut("t", modifiers: [])
                Button("") { canvasMode = .edit }.keyboardShortcut("e", modifiers: [])
                Button("") { 
                    canvasMode = .delete 
                    // optional: if user hits D and something is selected, maybe ask to delete?
                }.keyboardShortcut("d", modifiers: [])
                
                // global delete shortcut
                Button("") {
                    if !selectedStates.isEmpty || !selectedTransitions.isEmpty {
                        showDeleteConfirmation = true
                    }
                }.keyboardShortcut(.delete, modifiers: [])
            }
            .opacity(0)
        }
        .onAppear {
            syncViewModels()
        }
        .onChange(of: document.automaton) { _, newAutomaton in
            updateViewModels(with: newAutomaton)
        }
        .onChange(of: canvasViewModel.automaton) { _, newAutomaton in
            if document.automaton != newAutomaton {
                document.automaton = newAutomaton
            }
        }
        .onChange(of: inspectorViewModel.automaton) { _, newAutomaton in
            if document.automaton != newAutomaton {
                document.automaton = newAutomaton
            }
        }
    }
    
    private func syncViewModels() {
        canvasViewModel.automaton = document.automaton
        inspectorViewModel.automaton = document.automaton
    }
    
    private func updateViewModels(with automaton: Automaton) {
        if canvasViewModel.automaton != automaton {
            canvasViewModel.automaton = automaton
        }
        if inspectorViewModel.automaton != automaton {
            inspectorViewModel.automaton = automaton
        }
    }
    
    private func deleteSelectedItems() {
        for stateId in selectedStates {
            canvasViewModel.removeState(stateId)
        }
        for transitionId in selectedTransitions {
            canvasViewModel.removeTransition(transitionId)
        }
        selectedStates.removeAll()
        selectedTransitions.removeAll()
    }
    
    private func getShortcut(for mode: CanvasMode) -> String {
        switch mode {
        case .view: return "V"
        case .state: return "S"
        case .transition: return "T"
        case .delete: return "D"
        case .edit: return "E"
        }
    }
}

struct ModeIndicator: View {
    let mode: CanvasMode
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: mode.systemImage)
            Text(mode.rawValue)
                .font(.subheadline)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .glassEffect()
        .opacity(0.9)
    }
}

#Preview {
    AutomataStudioView(document: .constant(AutomataDocument()))
}
