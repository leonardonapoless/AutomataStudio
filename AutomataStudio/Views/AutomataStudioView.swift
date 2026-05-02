import SwiftUI
import UniformTypeIdentifiers

struct AutomataStudioView: View {
    @Environment(\.undoManager) var undoManager
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
            SidebarView(
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
                        if let transition = document.automaton.transitions.first(where: { $0.id == transitionId }) {
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
                ToolbarItem(placement: .primaryAction) {
                    ControlGroup {
                        ForEach(CanvasMode.allCases, id: \.self) { mode in
                            modeToggle(for: mode)
                        }
                    }
                    .controlGroupStyle(.navigation)
                }
                
                ToolbarItem(placement: .primaryAction) {
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
                }
                
                ToolbarItem(placement: .primaryAction) {
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
                
                ToolbarItem(placement: .primaryAction) {
                    ControlGroup {
                        Button {
                            NSApp.sendAction(#selector(NSDocument.save(_:)), to: nil, from: nil)
                        } label: {
                            Label("Save", systemImage: "square.and.arrow.down")
                        }
                        .help("Save Project (⌘S)")
                        
                        Menu {
                            Button("JFLAP (.jff)") {
                                exportJFLAP()
                            }
                            Button("SVG Image") {
                                exportSVG()
                            }
                            Button("Graphviz (.dot)") {
                                exportDOT()
                            }
                        } label: {
                            Label("Export", systemImage: "square.and.arrow.up")
                        }
                    }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        ForEach(ExampleAutomata.allExamples(), id: \.id) { example in
                            Button(example.name) {
                                loadExample(example)
                            }
                        }
                    } label: {
                        Label("Examples", systemImage: "book")
                    }
                    .help("Load Example Automaton")
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
    
    // MARK: - Export Actions
    
    private func exportJFLAP() {
        let content = document.automaton.exportToJFLAP()
        saveFile(content: content, defaultName: document.automaton.name, extension: "jff")
    }
    
    private func exportSVG() {
        let content = document.automaton.exportToSVG()
        saveFile(content: content, defaultName: document.automaton.name, extension: "svg")
    }
    
    private func exportDOT() {
        let content = document.automaton.exportToDOT()
        saveFile(content: content, defaultName: document.automaton.name, extension: "dot")
    }
    
    private func saveFile(content: String, defaultName: String, extension ext: String) {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [UTType(filenameExtension: ext) ?? .xml]
        savePanel.canCreateDirectories = true
        savePanel.isExtensionHidden = false
        savePanel.title = "Export Automaton"
        savePanel.message = "Choose a location to save the exported file."
        savePanel.nameFieldStringValue = "\(defaultName).\(ext)"
        
        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                do {
                    try content.write(to: url, atomically: true, encoding: .utf8)
                } catch {
                    print("Failed to save file: \(error)")
                }
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
        canvasViewModel.undoManager = undoManager
        
        inspectorViewModel.automaton = document.automaton
        inspectorViewModel.undoManager = undoManager
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
    
    private func loadExample(_ example: Automaton) {
        canvasViewModel.resetSimulation()
        document.automaton = example
        selectedStates.removeAll()
        selectedTransitions.removeAll()
        canvasViewModel.zoomToFit()
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
