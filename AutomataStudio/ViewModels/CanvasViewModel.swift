import SwiftUI
import Combine

class CanvasViewModel: ObservableObject {
    @Published var automaton: Automaton
    @Published var zoomLevel: CGFloat = 1.0
    @Published var panOffset: CGSize = .zero
    @Published var showGrid: Bool = true
    @Published var gridSize: CGFloat = 20.0
    @Published var snapToGrid: Bool = true
    
    // simulation state
    @Published var isSimulating: Bool = false
    @Published var simulationStep: Int = 0
    @Published var activeStates: Set<UUID> = []
    @Published var simulationInput: String = ""
    @Published var simulationResult: SimulationResult?
    
    // drag and selection state
    @Published var draggedState: UUID?
    @Published var dragOffset: CGSize = .zero
    @Published var isDragging: Bool = false
    @Published var selectionBox: CGRect?
    @Published var isSelecting: Bool = false
    
    private var cancellables = Set<AnyCancellable>()
    
    init(automaton: Automaton = Automaton(name: "Untitled", type: .dfa)) {
        self.automaton = automaton
    }
    
    // MARK: - Canvas Operations
    
    func zoomIn() {
        withAnimation(.easeInOut(duration: 0.2)) {
            zoomLevel = min(zoomLevel * 1.2, 5.0)
        }
    }
    
    func zoomOut() {
        withAnimation(.easeInOut(duration: 0.2)) {
            zoomLevel = max(zoomLevel / 1.2, 0.1)
        }
    }
    
    func resetZoom() {
        withAnimation(.easeInOut(duration: 0.3)) {
            zoomLevel = 1.0
            panOffset = .zero
        }
    }
    
    func zoomToFit() {
        guard !automaton.states.isEmpty else { return }
        
        let bounds = calculateAutomatonBounds()
        let canvasSize = CGSize(width: 800, height: 600) // default canvas size
        
        let scaleX = canvasSize.width / bounds.width
        let scaleY = canvasSize.height / bounds.height
        let scale = min(scaleX, scaleY) * 0.8 // 80% to add some padding
        
        withAnimation(.easeInOut(duration: 0.5)) {
            zoomLevel = max(scale, 0.1)
            panOffset = CGSize(
                width: (canvasSize.width - bounds.width * scale) / 2 - bounds.minX * scale,
                height: (canvasSize.height - bounds.height * scale) / 2 - bounds.minY * scale
            )
        }
    }
    
    func panCanvas(by offset: CGSize) {
        panOffset.width += offset.width
        panOffset.height += offset.height
    }
    
    func snapToGrid(_ point: CGPoint) -> CGPoint {
        guard snapToGrid else { return point }
        
        let snappedX = round(point.x / gridSize) * gridSize
        let snappedY = round(point.y / gridSize) * gridSize
        return CGPoint(x: snappedX, y: snappedY)
    }
    
    // MARK: - State Management
    
    func addState(at location: CGPoint) -> AutomatonState {
        let snappedLocation = snapToGrid(location)
        let newState = automaton.addState(at: snappedLocation)
        return newState
    }
    
    func removeState(_ stateId: UUID) {
        automaton.removeState(stateId)
    }
    
    func updateState(_ state: AutomatonState) {
        automaton.updateState(state)
    }
    
    func moveState(_ stateId: UUID, to location: CGPoint) {
        guard var state = automaton.getState(by: stateId) else { return }
        
        let snappedLocation = snapToGrid(location)
        state.position = snappedLocation
        automaton.updateState(state)
    }
    
    func startDraggingState(_ stateId: UUID, from location: CGPoint) {
        draggedState = stateId
        isDragging = true
        
        if let state = automaton.getState(by: stateId) {
            dragOffset = CGSize(
                width: location.x - state.position.x,
                height: location.y - state.position.y
            )
        }
    }
    
    func updateDragState(to location: CGPoint) {
        guard let stateId = draggedState else { return }
        
        let newPosition = CGPoint(
            x: location.x - dragOffset.width,
            y: location.y - dragOffset.height
        )
        
        moveState(stateId, to: newPosition)
    }
    
    func endDraggingState() {
        draggedState = nil
        isDragging = false
        dragOffset = .zero
    }
    
    // MARK: - Transition Management
    
    func addTransition(from fromStateId: UUID, to toStateId: UUID, symbols: [String] = [], isEpsilon: Bool = false) -> Transition {
        return automaton.addTransition(from: fromStateId, to: toStateId, symbols: symbols, isEpsilon: isEpsilon)
    }
    
    func removeTransition(_ transitionId: UUID) {
        automaton.removeTransition(transitionId)
    }
    
    func updateTransition(_ transition: Transition) {
        automaton.updateTransition(transition)
    }
    
    // MARK: - Selection Management
    
    func startSelection(at location: CGPoint) {
        isSelecting = true
        selectionBox = CGRect(origin: location, size: .zero)
    }
    
    func updateSelection(to location: CGPoint) {
        guard let startPoint = selectionBox?.origin else { return }
        
        let minX = min(startPoint.x, location.x)
        let minY = min(startPoint.y, location.y)
        let maxX = max(startPoint.x, location.x)
        let maxY = max(startPoint.y, location.y)
        
        selectionBox = CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
    
    func endSelection() {
        isSelecting = false
        selectionBox = nil
    }
    
    func getStatesInSelection(_ selection: CGRect) -> Set<UUID> {
        return Set(automaton.states.compactMap { state in
            selection.contains(state.position) ? state.id : nil
        })
    }
    
    // MARK: - Simulation
    
    func startSimulation(input: String) {
        simulationInput = input
        simulationStep = 0
        isSimulating = true
        
        // initialize with start state
        if let startState = automaton.getStartState() {
            activeStates = [startState.id]
        }
        
        simulationResult = nil
    }
    
    func stepSimulation() {
        guard isSimulating && simulationStep < simulationInput.count else {
            finishSimulation()
            return
        }
        
        let currentSymbol = String(simulationInput[simulationInput.index(simulationInput.startIndex, offsetBy: simulationStep)])
        
        var newActiveStates: Set<UUID> = []
        
        for stateId in activeStates {
            let transitions = automaton.getTransitions(from: stateId)
            for transition in transitions {
                if transition.symbols.contains(currentSymbol) || transition.isEpsilon {
                    newActiveStates.insert(transition.toStateId)
                }
            }
        }
        
        activeStates = newActiveStates
        simulationStep += 1
        
        // check if simulation is complete
        if simulationStep >= simulationInput.count {
            finishSimulation()
        }
    }
    
    func finishSimulation() {
        isSimulating = false
        
        let acceptingStates = Set(automaton.getAcceptingStates().map { $0.id })
        let hasAcceptingState = !activeStates.intersection(acceptingStates).isEmpty
        
        simulationResult = SimulationResult(
            accepted: hasAcceptingState,
            finalStates: activeStates,
            steps: simulationStep
        )
    }
    
    func resetSimulation() {
        isSimulating = false
        simulationStep = 0
        activeStates = []
        simulationResult = nil
    }
    
    // MARK: - Utility Methods
    
    private func calculateAutomatonBounds() -> CGRect {
        guard !automaton.states.isEmpty else {
            return CGRect(x: 0, y: 0, width: 100, height: 100)
        }
        
        let positions = automaton.states.map { $0.position }
        let minX = positions.map { $0.x }.min() ?? 0
        let maxX = positions.map { $0.x }.max() ?? 0
        let minY = positions.map { $0.y }.min() ?? 0
        let maxY = positions.map { $0.y }.max() ?? 0
        
        return CGRect(x: minX - 50, y: minY - 50, width: maxX - minX + 100, height: maxY - minY + 100)
    }
}

// MARK: - Simulation Result

struct SimulationResult {
    let accepted: Bool
    let finalStates: Set<UUID>
    let steps: Int
}

// MARK: - Canvas Modes

enum CanvasMode: String, CaseIterable {
    case view = "View"
    case state = "State"
    case transition = "Transition"
    case delete = "Delete"
    case edit = "Edit"
    
    var systemImage: String {
        switch self {
        case .view: return "hand.point.up.left"
        case .state: return "circle"
        case .transition: return "arrow.right"
        case .delete: return "trash"
        case .edit: return "pencil"
        }
    }
    
    var keyboardShortcut: KeyEquivalent? {
        switch self {
        case .view: return .init("v")
        case .state: return .init("s")
        case .transition: return .init("t")
        case .delete: return .init("d")
        case .edit: return .init("e")
        }
    }
}
