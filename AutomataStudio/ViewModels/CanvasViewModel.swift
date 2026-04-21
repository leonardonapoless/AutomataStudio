import SwiftUI
import Combine

class CanvasViewModel: ObservableObject {
    @Published var automaton: Automaton
    @Published var zoomLevel: CGFloat = 1.0
    @Published var panOffset: CGSize = .zero
    @Published var showGrid: Bool = true
    @Published var gridSize: CGFloat = 20.0
    @Published var snapToGrid: Bool = true
    
    @Published var isSimulating: Bool = false
    @Published var simulationStep: Int = 0
    @Published var activeStates: Set<UUID> = []
    @Published var simulationInput: String = ""
    @Published var simulationResult: SimulationResult?
    
    @Published var draggedState: UUID?
    @Published var dragOffset: CGSize = .zero
    @Published var isDragging: Bool = false
    @Published var selectionBox: CGRect?
    @Published var isSelecting: Bool = false
    
    var lastPanTranslation: CGSize = .zero
    
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
        let canvasSize = CGSize(width: 800, height: 600) 
        
        let scaleX = canvasSize.width / bounds.width
        let scaleY = canvasSize.height / bounds.height
        let scale = min(scaleX, scaleY) * 0.8 
        
        withAnimation(.easeInOut(duration: 0.5)) {
            zoomLevel = max(scale, 0.1)
            panOffset = CGSize(
                width: (canvasSize.width - bounds.width * scale) / 2 - bounds.minX * scale,
                height: (canvasSize.height - bounds.height * scale) / 2 - bounds.minY * scale
            )
        }
    }
    
    func panCanvas(by translation: CGSize) {
        let delta = CGSize(
            width: translation.width - lastPanTranslation.width,
            height: translation.height - lastPanTranslation.height
        )
        panOffset.width += delta.width
        panOffset.height += delta.height
        lastPanTranslation = translation
    }
    
    func endPan() {
        lastPanTranslation = .zero
    }
    
    // MARK: - Trackpad Gesture Support
    
    func applyMagnification(_ scale: CGFloat, anchor: CGPoint) {
        let newZoom = max(0.1, min(zoomLevel * scale, 5.0))
        let factor = newZoom / zoomLevel
        
        panOffset.width = anchor.x - factor * (anchor.x - panOffset.width)
        panOffset.height = anchor.y - factor * (anchor.y - panOffset.height)
        
        zoomLevel = newZoom
    }
    
    func applyScrollPan(_ delta: CGSize) {
        panOffset.width += delta.width
        panOffset.height += delta.height
    }
    
    func applyScrollZoom(_ scrollDelta: CGFloat, at anchor: CGPoint) {
        let factor: CGFloat = 1.0 + scrollDelta * 0.01
        applyMagnification(factor, anchor: anchor)
    }
    
    func snappedPosition(_ point: CGPoint) -> CGPoint {
        guard snapToGrid else { return point }
        
        let snappedX = round(point.x / gridSize) * gridSize
        let snappedY = round(point.y / gridSize) * gridSize
        return CGPoint(x: snappedX, y: snappedY)
    }
    
    // MARK: - State Management
    
    func addState(at location: CGPoint) -> AutomatonState {
        let snappedLocation = snappedPosition(location)
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
        
        let snappedLocation = snappedPosition(location)
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
        
        let closedStates = epsilonClosure(of: activeStates)
        
        var newActiveStates: Set<UUID> = []
        for stateId in closedStates {
            let transitions = automaton.getTransitions(from: stateId)
            for transition in transitions {
                if !transition.isEpsilon && transition.symbols.contains(currentSymbol) {
                    newActiveStates.insert(transition.toStateId)
                }
            }
        }
        
        activeStates = epsilonClosure(of: newActiveStates)
        simulationStep += 1
        
        if simulationStep >= simulationInput.count {
            finishSimulation()
        }
    }
    
    private func epsilonClosure(of states: Set<UUID>) -> Set<UUID> {
        var closure = states
        var worklist = Array(states)
        
        while !worklist.isEmpty {
            let current = worklist.removeFirst()
            for transition in automaton.getTransitions(from: current) where transition.isEpsilon {
                if !closure.contains(transition.toStateId) {
                    closure.insert(transition.toStateId)
                    worklist.append(transition.toStateId)
                }
            }
        }
        
        return closure
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
    case select = "Select"
    case addState = "Add State"
    case transition = "Transition"
    
    var systemImage: String {
        switch self {
        case .select: return "cursorarrow"
        case .addState: return "circle.badge.plus"
        case .transition: return "arrow.right"
        }
    }
    
    var keyboardShortcut: KeyEquivalent? {
        switch self {
        case .select: return .init("v")
        case .addState: return .init("s")
        case .transition: return .init("t")
        }
    }
}
