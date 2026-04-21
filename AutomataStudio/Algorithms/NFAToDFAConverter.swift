import Foundation
import CoreGraphics

struct NFAToDFAConverter {
    
    // MARK: - Public Interface
    
    static func convert(_ nfa: Automaton) -> Automaton {
        guard nfa.type == .nfa else {
            return nfa // already a DFA
        }
        
        var converter = NFAToDFAConverter(nfa: nfa)
        return converter.performConversion()
    }
    
    // MARK: - Private Implementation
    
    private let nfa: Automaton
    private var stateMap: [Set<UUID>: UUID] = [:]
    private var dfaStates: [AutomatonState] = []
    private var dfaTransitions: [Transition] = []
    
    private init(nfa: Automaton) {
        self.nfa = nfa
    }
    
    private mutating func performConversion() -> Automaton {
        guard let startState = nfa.getStartState() else {
            return createEmptyDFA()
        }
        
        let startClosure = epsilonClosure(of: [startState.id])
        
        var worklist: [Set<UUID>] = [startClosure]
        stateMap[startClosure] = UUID()
        
        while !worklist.isEmpty {
            let currentStateSet = worklist.removeFirst()
            let currentDFAStateId = stateMap[currentStateSet]!
            
            let dfaState = createDFAState(from: currentStateSet, id: currentDFAStateId)
            dfaStates.append(dfaState)
            
            var targetMap: [UUID: Set<String>] = [:]
            
            for symbol in nfa.alphabet {
                let nextStateSet = move(currentStateSet, on: symbol)
                let epsilonClosureNext = epsilonClosure(of: nextStateSet)
                
                if !epsilonClosureNext.isEmpty {
                    if stateMap[epsilonClosureNext] == nil {
                        let newDFAStateId = UUID()
                        stateMap[epsilonClosureNext] = newDFAStateId
                        worklist.append(epsilonClosureNext)
                    }
                    
                    let targetId = stateMap[epsilonClosureNext]!
                    targetMap[targetId, default: []].insert(symbol)
                }
            }
            
            for (targetId, symbols) in targetMap {
                let transition = Transition(
                    fromStateId: currentDFAStateId,
                    toStateId: targetId,
                    symbols: Array(symbols).sorted()
                )
                dfaTransitions.append(transition)
            }
        }
        
        return createFinalDFA()
    }
    
    private func epsilonClosure(of states: Set<UUID>) -> Set<UUID> {
        var closure = states
        var worklist = Array(states)
        
        while !worklist.isEmpty {
            let currentState = worklist.removeFirst()
            
            let epsilonTransitions = nfa.getTransitions(from: currentState)
                .filter { $0.isEpsilon }
            
            for transition in epsilonTransitions {
                if !closure.contains(transition.toStateId) {
                    closure.insert(transition.toStateId)
                    worklist.append(transition.toStateId)
                }
            }
        }
        
        return closure
    }
    
    private func move(_ states: Set<UUID>, on symbol: String) -> Set<UUID> {
        var result: Set<UUID> = []
        
        for stateId in states {
            let transitions = nfa.getTransitions(from: stateId)
                .filter { $0.symbols.contains(symbol) }
            
            for transition in transitions {
                result.insert(transition.toStateId)
            }
        }
        
        return result
    }
    
    private func createDFAState(from stateSet: Set<UUID>, id: UUID) -> AutomatonState {
        let nfaStates = stateSet.compactMap { nfa.getState(by: $0) }
        
        let isStart = stateSet.contains(nfa.getStartState()?.id ?? UUID())
        
        let acceptingStates = Set(nfa.getAcceptingStates().map { $0.id })
        let isAccepting = !stateSet.intersection(acceptingStates).isEmpty
        
        let stateNames = nfaStates.map { $0.displayName }.sorted()
        let name = "{\(stateNames.joined(separator: ","))}"
        
        let positions = nfaStates.map { $0.position }
        let count = max(positions.count, 1)
        let avgX = positions.map { $0.x }.reduce(0, +) / CGFloat(count)
        let avgY = positions.map { $0.y }.reduce(0, +) / CGFloat(count)
        
        return AutomatonState(
            id: id,
            name: name,
            position: CGPoint(x: avgX, y: avgY),
            isStart: isStart,
            isAccepting: isAccepting
        )
    }
    
    private func createFinalDFA() -> Automaton {
        let dfa = Automaton(
            name: "\(nfa.name) (DFA)",
            type: .dfa,
            states: dfaStates,
            transitions: dfaTransitions,
            alphabet: nfa.alphabet,
            author: nfa.author,
            description: "DFA converted from NFA using subset construction"
        )
        
        return dfa
    }
    
    private func createEmptyDFA() -> Automaton {
        return Automaton(
            name: "Empty DFA",
            type: .dfa,
            description: "Empty DFA (no start state in original NFA)"
        )
    }
}

// MARK: - Extension for Automaton

extension Automaton {
    func convertToDFA() -> Automaton {
        return NFAToDFAConverter.convert(self)
    }
}
