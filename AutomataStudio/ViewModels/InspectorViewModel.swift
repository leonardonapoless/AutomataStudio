import SwiftUI
import Combine

class InspectorViewModel: ObservableObject {
    @Published var automaton: Automaton
    @Published var selectedState: AutomatonState?
    @Published var selectedTransition: Transition?
    @Published var editingStateName: String = ""
    @Published var editingTransitionSymbols: String = ""
    @Published var isEditingState: Bool = false
    @Published var isEditingTransition: Bool = false
    
    private var cancellables = Set<AnyCancellable>()
    
    var undoManager: UndoManager?
    
    init(automaton: Automaton = Automaton(name: "Untitled", type: .dfa)) {
        self.automaton = automaton
    }
    
    func registerUndo(oldAutomaton: Automaton) {
        guard let undoManager = undoManager else { return }
        undoManager.registerUndo(withTarget: self) { target in
            target.registerUndo(oldAutomaton: target.automaton)
            target.automaton = oldAutomaton
        }
        if !undoManager.isUndoing && !undoManager.isRedoing {
            undoManager.setActionName("Inspector Edit")
        }
    }
    
    // MARK: - State Editing
    
    func selectState(_ state: AutomatonState?) {
        selectedState = state
        selectedTransition = nil
        
        if let state = state {
            editingStateName = state.name
            isEditingState = true
        } else {
            isEditingState = false
        }
    }
    
    func updateSelectedState() {
        guard var state = selectedState else { return }
        registerUndo(oldAutomaton: automaton)
        
        state.name = editingStateName
        automaton.updateState(state)
        selectedState = state
    }
    
    func toggleStartState() {
        guard var state = selectedState else { return }
        registerUndo(oldAutomaton: automaton)
        
        if !state.isStart {
            for var otherState in automaton.states {
                if otherState.isStart {
                    otherState.isStart = false
                    automaton.updateState(otherState)
                }
            }
        }
        
        state.isStart.toggle()
        automaton.updateState(state)
        selectedState = state
    }
    
    func toggleAcceptingState() {
        guard var state = selectedState else { return }
        registerUndo(oldAutomaton: automaton)
        
        state.isAccepting.toggle()
        automaton.updateState(state)
        selectedState = state
    }
    
    // MARK: - Transition Editing
    
    func selectTransition(_ transition: Transition?) {
        selectedTransition = transition
        selectedState = nil
        
        if let transition = transition {
            editingTransitionSymbols = transition.symbols.joined(separator: ",")
            isEditingTransition = true
        } else {
            isEditingTransition = false
        }
    }
    
    func updateSelectedTransition() {
        guard var transition = selectedTransition else { return }
        registerUndo(oldAutomaton: automaton)
        
        let symbols = editingTransitionSymbols
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        
        transition.symbols = symbols
        
        automaton.updateTransition(transition)
        selectedTransition = transition
    }
    
    func addEpsilonTransition() {
        guard var transition = selectedTransition else { return }
        registerUndo(oldAutomaton: automaton)
        
        transition.isEpsilon.toggle()
        if transition.isEpsilon {
            transition.symbols = []
            editingTransitionSymbols = ""
        }
        
        automaton.updateTransition(transition)
        selectedTransition = transition
    }
    
    // MARK: - Automaton Properties
    
    func updateAutomatonName(_ name: String) {
        registerUndo(oldAutomaton: automaton)
        automaton.name = name
    }
    
    func updateAutomatonType(_ type: AutomatonType) {
        registerUndo(oldAutomaton: automaton)
        automaton.type = type
    }
    
    func updateAutomatonDescription(_ description: String) {
        registerUndo(oldAutomaton: automaton)
        automaton.description = description
    }
    
    func updateAutomatonAuthor(_ author: String) {
        registerUndo(oldAutomaton: automaton)
        automaton.author = author
    }
    
    // MARK: - Validation
    
    func validateAutomaton() -> [String] {
        return automaton.validate()
    }
    
    func getAutomatonStatistics() -> AutomatonStatistics {
        return AutomatonStatistics(
            stateCount: automaton.states.count,
            transitionCount: automaton.transitions.count,
            alphabetSize: automaton.alphabet.count,
            acceptingStateCount: automaton.getAcceptingStates().count,
            hasStartState: automaton.getStartState() != nil
        )
    }
}

// MARK: - Automaton Statistics

struct AutomatonStatistics {
    let stateCount: Int
    let transitionCount: Int
    let alphabetSize: Int
    let acceptingStateCount: Int
    let hasStartState: Bool
}
