import Foundation
import CoreGraphics

struct DFAMinimizer {
    
    // MARK: - Public Interface
    
    static func minimize(_ dfa: Automaton) -> Automaton {
        guard dfa.type == .dfa else {
            return dfa // not a DFA
        }
        
        var minimizer = DFAMinimizer(dfa: dfa)
        return minimizer.performMinimization()
    }
    
    // MARK: - Private Implementation
    
    private let dfa: Automaton
    private var partitions: [Set<UUID>] = []
    private var partitionMap: [UUID: Int] = [:]
    private var reachableStates: Set<UUID> = []
    
    private init(dfa: Automaton) {
        self.dfa = dfa
    }
    
    private mutating func performMinimization() -> Automaton {
        pruneUnreachableStates()
        initializePartitions()
        
        refinePartitions()
        
        return createMinimizedDFA()
    }
    
    private mutating func pruneUnreachableStates() {
        guard let start = dfa.getStartState() else {
            reachableStates = []
            return
        }
        
        var reachable: Set<UUID> = [start.id]
        var worklist: [UUID] = [start.id]
        
        while !worklist.isEmpty {
            let state = worklist.removeFirst()
            let transitions = dfa.getTransitions(from: state)
            for t in transitions {
                if !reachable.contains(t.toStateId) {
                    reachable.insert(t.toStateId)
                    worklist.append(t.toStateId)
                }
            }
        }
        
        self.reachableStates = reachable
    }
    
    private mutating func initializePartitions() {
        let validStates = dfa.states.filter { reachableStates.contains($0.id) }
        let acceptingStates = Set(validStates.filter { $0.isAccepting }.map { $0.id })
        let nonAcceptingStates = Set(validStates.map { $0.id }).subtracting(acceptingStates)
        
        partitions = []
        partitionMap = [:]
        
        if !acceptingStates.isEmpty {
            partitions.append(acceptingStates)
            for stateId in acceptingStates {
                partitionMap[stateId] = partitions.count - 1
            }
        }
        
        if !nonAcceptingStates.isEmpty {
            partitions.append(nonAcceptingStates)
            for stateId in nonAcceptingStates {
                partitionMap[stateId] = partitions.count - 1
            }
        }
    }
    
    private mutating func refinePartitions() {
        var changed = true
        while changed {
            changed = false
            var newPartitions: [Set<UUID>] = []
            
            for partition in partitions {
                var splitResult: [Set<UUID>] = []
                
                for symbol in dfa.alphabet {
                    splitResult = splitPartition(partition, on: symbol)
                    if splitResult.count > 1 {
                        break
                    }
                }
                
                if splitResult.count > 1 {
                    changed = true
                    newPartitions.append(contentsOf: splitResult)
                } else {
                    newPartitions.append(partition)
                }
            }
            
            if changed {
                partitions = newPartitions
                for (i, p) in partitions.enumerated() {
                    updatePartitionMap(p, partitionIndex: i)
                }
            }
        }
    }
    
    private func splitPartition(_ partition: Set<UUID>, on symbol: String) -> [Set<UUID>] {
        var groups: [String: Set<UUID>] = [:]
        
        for stateId in partition {
            let nextPartition = getNextPartition(for: stateId, on: symbol)
            let key = nextPartition.map { String($0) }.sorted().joined(separator: ",")
            
            if groups[key] == nil {
                groups[key] = Set<UUID>()
            }
            groups[key]?.insert(stateId)
        }
        
        return Array(groups.values)
    }
    
    private func getNextPartition(for stateId: UUID, on symbol: String) -> Set<Int> {
        let transitions = dfa.getTransitions(from: stateId)
            .filter { $0.symbols.contains(symbol) }
        
        var nextPartitions: Set<Int> = []
        
        for transition in transitions {
            if let partitionIndex = partitionMap[transition.toStateId] {
                nextPartitions.insert(partitionIndex)
            }
        }
        
        return nextPartitions
    }
    
    private mutating func updatePartitionMap(_ partition: Set<UUID>, partitionIndex: Int) {
        for stateId in partition {
            partitionMap[stateId] = partitionIndex
        }
    }
    
    private func createMinimizedDFA() -> Automaton {
        var minimizedStates: [AutomatonState] = []
        var minimizedTransitions: [Transition] = []
        var stateIdMap: [Int: UUID] = [:]
        
        for (index, partition) in partitions.enumerated() {
            let newStateId = UUID()
            stateIdMap[index] = newStateId
            
            let isStart = partition.contains(dfa.getStartState()?.id ?? UUID())
            let isAccepting = !partition.intersection(Set(dfa.getAcceptingStates().map { $0.id })).isEmpty
            
            let partitionStates = partition.compactMap { dfa.getState(by: $0) }
            let positions = partitionStates.map { $0.position }
            let count = max(positions.count, 1)
            let avgX = positions.map { $0.x }.reduce(0, +) / CGFloat(count)
            let avgY = positions.map { $0.y }.reduce(0, +) / CGFloat(count)
            
            let stateNames = partitionStates.map { $0.displayName }.sorted()
            let name = stateNames.count == 1 ? stateNames[0] : "{\(stateNames.joined(separator: ","))}"
            
            let state = AutomatonState(
                id: newStateId,
                name: name,
                position: CGPoint(x: avgX, y: avgY),
                isStart: isStart,
                isAccepting: isAccepting
            )
            
            minimizedStates.append(state)
        }
        
        for (index, partition) in partitions.enumerated() {
            guard let fromStateId = stateIdMap[index] else { continue }
            
            guard let representativeState = partition.first else { continue }
            
            let transitions = dfa.getTransitions(from: representativeState)
            
            for transition in transitions {
                if let targetPartitionIndex = partitionMap[transition.toStateId],
                   let toStateId = stateIdMap[targetPartitionIndex] {
                    
                    let existingTransition = minimizedTransitions.first { t in
                        t.fromStateId == fromStateId && t.toStateId == toStateId && t.symbols == transition.symbols
                    }
                    
                    if existingTransition == nil {
                        let newTransition = Transition(
                            fromStateId: fromStateId,
                            toStateId: toStateId,
                            symbols: transition.symbols
                        )
                        minimizedTransitions.append(newTransition)
                    }
                }
            }
        }
        
        return Automaton(
            name: "\(dfa.name) (Minimized)",
            type: .dfa,
            states: minimizedStates,
            transitions: minimizedTransitions,
            alphabet: dfa.alphabet,
            author: dfa.author,
            description: "Minimized DFA using Hopcroft's algorithm"
        )
    }
}

// MARK: - Extension for Automaton

extension Automaton {
    func minimize() -> Automaton {
        return DFAMinimizer.minimize(self)
    }
}
