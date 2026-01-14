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
    
    private init(dfa: Automaton) {
        self.dfa = dfa
    }
    
    private mutating func performMinimization() -> Automaton {
        // step 1: initial partition (accepting vs non-accepting states)
        initializePartitions()
        
        // step 2: refine partitions using Hopcroft's algorithm
        refinePartitions()
        
        // Step 3: Create minimized DFA
        return createMinimizedDFA()
    }
    
    private mutating func initializePartitions() {
        let acceptingStates = Set(dfa.getAcceptingStates().map { $0.id })
        let nonAcceptingStates = Set(dfa.states.map { $0.id }).subtracting(acceptingStates)
        
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
        var worklist: [Int] = []
        
        // initialize worklist with smaller partition
        if partitions.count >= 2 {
            let smallerPartitionIndex = partitions[0].count <= partitions[1].count ? 0 : 1
            worklist.append(smallerPartitionIndex)
        }
        
        while !worklist.isEmpty {
            let partitionIndex = worklist.removeFirst()
            let currentPartition = partitions[partitionIndex]
            
            // for each symbol in alphabet
            for symbol in dfa.alphabet {
                let splitResult = splitPartition(currentPartition, on: symbol)
                
                if splitResult.count > 1 {
                    // replace current partition with split results
                    partitions[partitionIndex] = splitResult[0]
                    updatePartitionMap(splitResult[0], partitionIndex: partitionIndex)
                    
                    // add remaining splits as new partitions
                    for i in 1..<splitResult.count {
                        let newPartitionIndex = partitions.count
                        partitions.append(splitResult[i])
                        updatePartitionMap(splitResult[i], partitionIndex: newPartitionIndex)
                        
                        // add to worklist if it's smaller than current partition
                        if splitResult[i].count <= currentPartition.count {
                            worklist.append(newPartitionIndex)
                        } else {
                            worklist.append(partitionIndex)
                        }
                    }
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
        
        // create states for each partition
        for (index, partition) in partitions.enumerated() {
            let newStateId = UUID()
            stateIdMap[index] = newStateId
            
            // determine state properties
            let isStart = partition.contains(dfa.getStartState()?.id ?? UUID())
            let isAccepting = !partition.intersection(Set(dfa.getAcceptingStates().map { $0.id })).isEmpty
            
            // calculate position (center of partition states)
            let partitionStates = partition.compactMap { dfa.getState(by: $0) }
            let positions = partitionStates.map { $0.position }
            let count = max(positions.count, 1)
            let avgX = positions.map { $0.x }.reduce(0, +) / CGFloat(count)
            let avgY = positions.map { $0.y }.reduce(0, +) / CGFloat(count)
            
            // create state name
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
        
        // create transitions
        for (index, partition) in partitions.enumerated() {
            guard let fromStateId = stateIdMap[index] else { continue }
            
            // get a representative state from this partition
            guard let representativeState = partition.first else { continue }
            
            // find transitions from representative state
            let transitions = dfa.getTransitions(from: representativeState)
            
            for transition in transitions {
                // find which partition the target state belongs to
                if let targetPartitionIndex = partitionMap[transition.toStateId],
                   let toStateId = stateIdMap[targetPartitionIndex] {
                    
                    // check if transition already exists
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
