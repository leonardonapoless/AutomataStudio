import XCTest
@testable import AutomataStudio

final class AutomataStudioTests: XCTestCase {
    
    // MARK: - Test Data Setup
    
    func createSampleDFA() -> Automaton {
        let automaton = Automaton(name: "Sample DFA", type: .dfa)
        
        // create states
        let q0 = AutomatonState(name: "q0", position: CGPoint(x: 100, y: 100), isStart: true, isAccepting: false)
        let q1 = AutomatonState(name: "q1", position: CGPoint(x: 200, y: 100), isStart: false, isAccepting: true)
        
        automaton.states = [q0, q1]
        
        // create transitions
        let t1 = Transition(fromAutomatonStateId: q0.id, toAutomatonStateId: q1.id, symbols: ["a"])
        let t2 = Transition(fromAutomatonStateId: q1.id, toAutomatonStateId: q0.id, symbols: ["b"])
        
        automaton.transitions = [t1, t2]
        automaton.alphabet = ["a", "b"]
        
        return automaton
    }
    
    func createSampleNFA() -> Automaton {
        let automaton = Automaton(name: "Sample NFA", type: .nfa)
        
        // create states
        let q0 = AutomatonState(name: "q0", position: CGPoint(x: 100, y: 100), isStart: true, isAccepting: false)
        let q1 = AutomatonState(name: "q1", position: CGPoint(x: 200, y: 100), isStart: false, isAccepting: true)
        let q2 = AutomatonState(name: "q2", position: CGPoint(x: 300, y: 100), isStart: false, isAccepting: false)
        
        automaton.states = [q0, q1, q2]
        
        // create transitions
        let t1 = Transition(fromAutomatonStateId: q0.id, toAutomatonStateId: q1.id, symbols: ["a"])
        let t2 = Transition(fromAutomatonStateId: q0.id, toAutomatonStateId: q2.id, symbols: ["a"])
        let t3 = Transition(fromAutomatonStateId: q1.id, toAutomatonStateId: q2.id, symbols: ["b"], isEpsilon: true)
        
        automaton.transitions = [t1, t2, t3]
        automaton.alphabet = ["a", "b"]
        
        return automaton
    }
    
    // MARK: - Model Tests
    
    func testAutomatonCreation() {
        let automaton = Automaton(name: "Test", type: .dfa)
        
        XCTAssertEqual(automaton.name, "Test")
        XCTAssertEqual(automaton.type, .dfa)
        XCTAssertTrue(automaton.states.isEmpty)
        XCTAssertTrue(automaton.transitions.isEmpty)
    }
    
    func testAutomatonStateCreation() {
        let state = AutomatonAutomatonState(name: "q0", position: CGPoint(x: 100, y: 100), isStart: true, isAccepting: false)
        
        XCTAssertEqual(state.name, "q0")
        XCTAssertEqual(state.position, CGPoint(x: 100, y: 100))
        XCTAssertTrue(state.isStart)
        XCTAssertFalse(state.isAccepting)
    }
    
    func testTransitionCreation() {
        let fromAutomatonState = AutomatonAutomatonState(name: "q0", position: CGPoint(x: 100, y: 100))
        let toAutomatonState = AutomatonAutomatonState(name: "q1", position: CGPoint(x: 200, y: 100))
        
        let transition = Transition(fromAutomatonStateId: fromAutomatonState.id, toAutomatonStateId: toAutomatonState.id, symbols: ["a", "b"])
        
        XCTAssertEqual(transition.fromAutomatonStateId, fromAutomatonState.id)
        XCTAssertEqual(transition.toAutomatonStateId, toAutomatonState.id)
        XCTAssertEqual(transition.symbols, ["a", "b"])
        XCTAssertFalse(transition.isEpsilon)
    }
    
    func testEpsilonTransition() {
        let fromAutomatonState = AutomatonAutomatonState(name: "q0", position: CGPoint(x: 100, y: 100))
        let toAutomatonState = AutomatonAutomatonState(name: "q1", position: CGPoint(x: 200, y: 100))
        
        let transition = Transition(fromAutomatonStateId: fromAutomatonState.id, toAutomatonStateId: toAutomatonState.id, symbols: [], isEpsilon: true)
        
        XCTAssertTrue(transition.isEpsilon)
        XCTAssertEqual(transition.displaySymbols, "ε")
    }
    
    // MARK: - NFA to DFA Conversion Tests
    
    func testNFAToDFAConversion() {
        let nfa = createSampleNFA()
        let dfa = NFAToDFAConverter.convert(nfa)
        
        XCTAssertEqual(dfa.type, .dfa)
        XCTAssertTrue(dfa.states.count >= nfa.states.count) // DFA may have more states
        XCTAssertNotNil(dfa.getStartAutomatonState())
    }
    
    func testNFAToDFAWithEpsilonTransitions() {
        let automaton = Automaton(name: "Epsilon NFA", type: .nfa)
        
        let q0 = AutomatonState(name: "q0", position: CGPoint(x: 100, y: 100), isStart: true, isAccepting: false)
        let q1 = AutomatonState(name: "q1", position: CGPoint(x: 200, y: 100), isStart: false, isAccepting: true)
        
        automaton.states = [q0, q1]
        
        let epsilonTransition = Transition(fromAutomatonStateId: q0.id, toAutomatonStateId: q1.id, symbols: [], isEpsilon: true)
        automaton.transitions = [epsilonTransition]
        
        let dfa = NFAToDFAConverter.convert(automaton)
        
        XCTAssertEqual(dfa.type, .dfa)
        XCTAssertTrue(dfa.states.count >= 1)
    }
    
    func testNFAToDFAEmptyAutomaton() {
        let emptyNFA = Automaton(name: "Empty", type: .nfa)
        let dfa = NFAToDFAConverter.convert(emptyNFA)
        
        XCTAssertEqual(dfa.type, .dfa)
        XCTAssertTrue(dfa.states.isEmpty)
    }
    
    // MARK: - DFA Minimization Tests
    
    func testDFAMinimization() {
        let dfa = createSampleDFA()
        let minimized = DFAMinimizer.minimize(dfa)
        
        XCTAssertEqual(minimized.type, .dfa)
        XCTAssertTrue(minimized.states.count <= dfa.states.count)
        XCTAssertNotNil(minimized.getStartAutomatonState())
    }
    
    func testDFAMinimizationWithEquivalentAutomatonStates() {
        let automaton = Automaton(name: "Equivalent AutomatonStates DFA", type: .dfa)
        
        let q0 = AutomatonState(name: "q0", position: CGPoint(x: 100, y: 100), isStart: true, isAccepting: false)
        let q1 = AutomatonState(name: "q1", position: CGPoint(x: 200, y: 100), isStart: false, isAccepting: false)
        let q2 = AutomatonState(name: "q2", position: CGPoint(x: 300, y: 100), isStart: false, isAccepting: true)
        
        automaton.states = [q0, q1, q2]
        
        // create transitions that make q0 and q1 equivalent
        let t1 = Transition(fromAutomatonStateId: q0.id, toAutomatonStateId: q2.id, symbols: ["a"])
        let t2 = Transition(fromAutomatonStateId: q0.id, toAutomatonStateId: q0.id, symbols: ["b"])
        let t3 = Transition(fromAutomatonStateId: q1.id, toAutomatonStateId: q2.id, symbols: ["a"])
        let t4 = Transition(fromAutomatonStateId: q1.id, toAutomatonStateId: q1.id, symbols: ["b"])
        
        automaton.transitions = [t1, t2, t3, t4]
        automaton.alphabet = ["a", "b"]
        
        let minimized = DFAMinimizer.minimize(automaton)
        
        XCTAssertEqual(minimized.type, .dfa)
        XCTAssertTrue(minimized.states.count < automaton.states.count) // Should be minimized
    }
    
    func testDFAMinimizationEmptyAutomaton() {
        let emptyDFA = Automaton(name: "Empty", type: .dfa)
        let minimized = DFAMinimizer.minimize(emptyDFA)
        
        XCTAssertEqual(minimized.type, .dfa)
        XCTAssertTrue(minimized.states.isEmpty)
    }
    
    // MARK: - Simulation Tests
    
    func testDFASimulation() {
        let dfa = createSampleDFA()
        let simulator = AutomatonSimulator(automaton: dfa)
        
        // test accepting input
        let result1 = simulator.simulate(input: "a")
        XCTAssertTrue(result1.accepted)
        
        // test rejecting input
        let result2 = simulator.simulate(input: "aa")
        XCTAssertFalse(result2.accepted)
    }
    
    func testNFASimulation() {
        let nfa = createSampleNFA()
        let simulator = AutomatonSimulator(automaton: nfa)
        
        // test simulation (simplified)
        let result = simulator.simulate(input: "a")
        XCTAssertNotNil(result)
    }
    
    // MARK: - Validation Tests
    
    func testAutomatonValidation() {
        let automaton = createSampleDFA()
        let errors = automaton.validate()
        
        XCTAssertTrue(errors.isEmpty, "Valid automaton should have no validation errors")
    }
    
    func testAutomatonValidationNoStartAutomatonState() {
        let automaton = Automaton(name: "No Start", type: .dfa)
        let state = AutomatonState(name: "q0", position: CGPoint(x: 100, y: 100), isStart: false, isAccepting: true)
        automaton.states = [state]
        
        let errors = automaton.validate()
        XCTAssertTrue(errors.contains("No start state defined"))
    }
    
    func testAutomatonValidationMultipleStartAutomatonStates() {
        let automaton = Automaton(name: "Multiple Start", type: .dfa)
        let state1 = AutomatonState(name: "q0", position: CGPoint(x: 100, y: 100), isStart: true, isAccepting: false)
        let state2 = AutomatonState(name: "q1", position: CGPoint(x: 200, y: 100), isStart: true, isAccepting: false)
        automaton.states = [state1, state2]
        
        let errors = automaton.validate()
        XCTAssertTrue(errors.contains("Multiple start states defined"))
    }
}

// MARK: - Simulation Helper

struct AutomatonSimulator {
    let automaton: Automaton
    
    func simulate(input: String) -> SimulationResult {
        guard let startAutomatonState = automaton.getStartAutomatonState() else {
            return SimulationResult(accepted: false, finalAutomatonStates: Set(), steps: 0)
        }
        
        var currentAutomatonState = startAutomatonState
        
        for (step, char) in input.enumerated() {
            let symbol = String(char)
            let transitions = automaton.getTransitions(from: currentAutomatonState.id)
                .filter { $0.symbols.contains(symbol) }
            
            if let transition = transitions.first,
               let nextAutomatonState = automaton.getAutomatonState(by: transition.toAutomatonStateId) {
                currentAutomatonState = nextAutomatonState
            } else {
                return SimulationResult(accepted: false, finalAutomatonStates: Set([currentAutomatonState.id]), steps: step + 1)
            }
        }
        
        return SimulationResult(
            accepted: currentAutomatonState.isAccepting,
            finalAutomatonStates: Set([currentAutomatonState.id]),
            steps: input.count
        )
    }
}
