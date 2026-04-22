import SwiftUI
import UniformTypeIdentifiers

struct AutomataStudioView: View {
    @Binding var document: AutomataDocument
    @StateObject private var canvasViewModel = CanvasViewModel()
    @StateObject private var inspectorViewModel = InspectorViewModel()
    
    @State private var selectedStates: Set<UUID> = []
    @State private var selectedTransitions: Set<UUID> = []
    @State private var canvasMode: CanvasMode = .select
    
    @State private var isSimulationPanelVisible = false
    @State private var simulationInput = ""
    
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
                CanvasView(
                    automaton: document.automaton,
                    canvasMode: $canvasMode,
                    selectedStates: $selectedStates,
                    selectedTransitions: $selectedTransitions,
                    viewModel: canvasViewModel,
                    onRenameState: { stateId in
                        if let state = document.automaton.getState(by: stateId) {
                            inspectorViewModel.selectState(state)
                        }
                    },
                    onEditTransition: { transitionId in
                        if let transition = canvasViewModel.automaton.transitions.first(where: { $0.id == transitionId }) {
                            inspectorViewModel.selectTransition(transition)
                        }
                    }
                )
                
                if isSimulationPanelVisible {
                    SimulationBottomPanel(viewModel: canvasViewModel, input: $simulationInput)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .zIndex(100)
                }
            }
            .background(Color(nsColor: .windowBackgroundColor))
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    ControlGroup {
                        ForEach(CanvasMode.allCases, id: \.self) { mode in
                            modeToggle(for: mode)
                        }
                    }
                    .controlGroupStyle(.navigation)
                    
                    Button {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                            isSimulationPanelVisible.toggle()
                            if !isSimulationPanelVisible {
                                canvasViewModel.resetSimulation()
                            }
                        }
                    } label: {
                        Label("Simulation", systemImage: "play.fill")
                            .foregroundStyle(isSimulationPanelVisible ? Color.accentColor : Color.primary)
                    }
                    .keyboardShortcut("R", modifiers: .command)
                    .help("Toggle Simulation Panel (⌘R)")
                    
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
        .background {
            ZStack {
                Button("") { canvasMode = .select }.keyboardShortcut("v", modifiers: [])
                Button("") { canvasMode = .addState }.keyboardShortcut("s", modifiers: [])
                Button("") { canvasMode = .transition }.keyboardShortcut("t", modifiers: [])
                
                Button("") {
                    deleteSelectedItems()
                }.keyboardShortcut(.delete, modifiers: [])
                
                Button("") {
                    selectedStates = []
                    selectedTransitions = []
                    canvasMode = .select
                }.keyboardShortcut(.escape, modifiers: [])
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
    
    @ViewBuilder
    private func modeToggle(for mode: CanvasMode) -> some View {
        let shortcut = shortcutLabel(for: mode)
        Toggle(isOn: Binding(
            get: { canvasMode == mode },
            set: { _ in canvasMode = mode }
        )) {
            Label(mode.rawValue, systemImage: mode.systemImage)
        }
        .help("\(mode.rawValue) Mode (\(shortcut))")
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
        guard !selectedStates.isEmpty || !selectedTransitions.isEmpty else { return }
        
        for stateId in selectedStates {
            canvasViewModel.removeState(stateId)
        }
        for transitionId in selectedTransitions {
            canvasViewModel.removeTransition(transitionId)
        }
        selectedStates.removeAll()
        selectedTransitions.removeAll()
    }
    
    private func shortcutLabel(for mode: CanvasMode) -> String {
        switch mode {
        case .select: return "V"
        case .addState: return "S"
        case .transition: return "T"
        }
    }
}

#Preview {
    AutomataStudioView(document: .constant(AutomataDocument()))
}
