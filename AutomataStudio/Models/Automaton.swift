import Foundation
import CoreGraphics

// MARK: - Simulation Result

struct SimulationResult: Codable, Equatable, Hashable, Sendable {
    let accepted: Bool
    let finalStates: Set<UUID>
    let steps: Int
}

// MARK: - Canvas Mode

enum CanvasMode: String, CaseIterable, Identifiable, Codable, Sendable {
    case select = "Select"
    case addState = "Add State"
    case transition = "Transition"
    
    var id: String { self.rawValue }
    
    var systemImage: String {
        switch self {
        case .select: return "cursorarrow"
        case .addState: return "plus.circle"
        case .transition: return "arrow.right.circle"
        }
    }
}

// MARK: - Automaton Types

enum AutomatonType: String, CaseIterable, Codable, Sendable {
    case dfa = "DFA"
    case nfa = "NFA"
    case turingMachine = "Turing Machine"
    
    var description: String {
        switch self {
        case .dfa: return "Deterministic Finite Automaton"
        case .nfa: return "Non-deterministic Finite Automaton"
        case .turingMachine: return "Turing Machine"
        }
    }
}

// MARK: - AutomatonState Model

struct AutomatonState: Identifiable, Codable, Equatable, Hashable, Sendable {
    let id: UUID
    var name: String
    var position: CGPoint
    var isStart: Bool
    var isAccepting: Bool
    var customColor: String? 
    var label: String? 
    
    init(id: UUID = UUID(), name: String, position: CGPoint, isStart: Bool = false, isAccepting: Bool = false, customColor: String? = nil, label: String? = nil) {
        self.id = id
        self.name = name
        self.position = position
        self.isStart = isStart
        self.isAccepting = isAccepting
        self.customColor = customColor
        self.label = label
    }
    
    var displayName: String {
        return name.isEmpty ? "q\(id.uuidString.prefix(4))" : name
    }
}

// MARK: - Transition Model

struct Transition: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    var fromStateId: UUID
    var toStateId: UUID
    var symbols: [String]
    var isEpsilon: Bool
    
    init(id: UUID = UUID(), fromStateId: UUID, toStateId: UUID, symbols: [String] = [], isEpsilon: Bool = false) {
        self.id = id
        self.fromStateId = fromStateId
        self.toStateId = toStateId
        self.symbols = symbols
        self.isEpsilon = isEpsilon
    }
    
    var displaySymbols: String {
        if isEpsilon {
            return "ε"
        }
        return symbols.isEmpty ? "λ" : symbols.joined(separator: ",")
    }
}

// MARK: - Main Automaton Model

struct Automaton: Codable, Equatable, Sendable {
    var id: UUID
    var name: String
    var type: AutomatonType
    var states: [AutomatonState]
    var transitions: [Transition]
    var alphabet: Set<String>
    var createdDate: Date
    var modifiedDate: Date
    var author: String?
    var description: String?
    
    var tapeAlphabet: Set<String>?
    var blankSymbol: String?
    
    nonisolated init(id: UUID = UUID(), name: String, type: AutomatonType, states: [AutomatonState] = [], transitions: [Transition] = [], alphabet: Set<String> = [], author: String? = nil, description: String? = nil) {
        self.id = id
        self.name = name
        self.type = type
        self.states = states
        self.transitions = transitions
        self.alphabet = alphabet
        self.createdDate = Date()
        self.modifiedDate = Date()
        self.author = author
        self.description = description
        
        if type == .turingMachine {
            self.tapeAlphabet = Set(["0", "1", "B"])
            self.blankSymbol = "B"
        }
    }
    
    // MARK: - Codable
    
    enum CodingKeys: String, CodingKey {
        case id, name, type, states, transitions, alphabet, createdDate, modifiedDate, author, description, tapeAlphabet, blankSymbol
    }
    
    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.name = try container.decode(String.self, forKey: .name)
        self.type = try container.decode(AutomatonType.self, forKey: .type)
        self.states = try container.decode([AutomatonState].self, forKey: .states)
        self.transitions = try container.decode([Transition].self, forKey: .transitions)
        self.alphabet = try container.decode(Set<String>.self, forKey: .alphabet)
        self.createdDate = try container.decode(Date.self, forKey: .createdDate)
        self.modifiedDate = try container.decode(Date.self, forKey: .modifiedDate)
        self.author = try container.decodeIfPresent(String.self, forKey: .author)
        self.description = try container.decodeIfPresent(String.self, forKey: .description)
        self.tapeAlphabet = try container.decodeIfPresent(Set<String>.self, forKey: .tapeAlphabet)
        self.blankSymbol = try container.decodeIfPresent(String.self, forKey: .blankSymbol)
    }
    
    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(type, forKey: .type)
        try container.encode(states, forKey: .states)
        try container.encode(transitions, forKey: .transitions)
        try container.encode(alphabet, forKey: .alphabet)
        try container.encode(createdDate, forKey: .createdDate)
        try container.encode(modifiedDate, forKey: .modifiedDate)
        try container.encodeIfPresent(author, forKey: .author)
        try container.encodeIfPresent(description, forKey: .description)
        try container.encodeIfPresent(tapeAlphabet, forKey: .tapeAlphabet)
        try container.encodeIfPresent(blankSymbol, forKey: .blankSymbol)
    }
    
    // MARK: - State Management
    
    mutating func addState(at position: CGPoint) -> AutomatonState {
        var index = states.count
        var candidateName = "q\(index)"
        while states.contains(where: { $0.name == candidateName }) {
            index += 1
            candidateName = "q\(index)"
        }
        
        let newState = AutomatonState(
            name: candidateName,
            position: position,
            isStart: states.isEmpty,
            isAccepting: false
        )
        states.append(newState)
        updateModifiedDate()
        return newState
    }
    
    mutating func removeState(_ stateId: UUID) {
        states.removeAll { $0.id == stateId }
        transitions.removeAll { $0.fromStateId == stateId || $0.toStateId == stateId }
        syncAlphabet()
        updateModifiedDate()
    }
    
    mutating func updateState(_ state: AutomatonState) {
        if let index = states.firstIndex(where: { $0.id == state.id }) {
            states[index] = state
            updateModifiedDate()
        }
    }
    
    // MARK: - Transition Management
    
    mutating func addTransition(from fromStateId: UUID, to toStateId: UUID, symbols: [String] = [], isEpsilon: Bool = false) -> Transition {
        let newTransition = Transition(
            fromStateId: fromStateId,
            toStateId: toStateId,
            symbols: symbols,
            isEpsilon: isEpsilon
        )
        transitions.append(newTransition)
        syncAlphabet()
        updateModifiedDate()
        return newTransition
    }
    
    mutating func removeTransition(_ transitionId: UUID) {
        transitions.removeAll { $0.id == transitionId }
        syncAlphabet()
        updateModifiedDate()
    }
    
    mutating func updateTransition(_ transition: Transition) {
        if let index = transitions.firstIndex(where: { $0.id == transition.id }) {
            transitions[index] = transition
            syncAlphabet()
            updateModifiedDate()
        }
    }
    
    // MARK: - Utility Methods
    
    func getState(by id: UUID) -> AutomatonState? {
        return states.first { $0.id == id }
    }
    
    func getStartState() -> AutomatonState? {
        return states.first { $0.isStart }
    }
    
    func getAcceptingStates() -> [AutomatonState] {
        return states.filter { $0.isAccepting }
    }
    
    func getTransitions(from stateId: UUID) -> [Transition] {
        return transitions.filter { $0.fromStateId == stateId }
    }
    
    func getTransitions(to stateId: UUID) -> [Transition] {
        return transitions.filter { $0.toStateId == stateId }
    }
    
    func getTransitions(from fromStateId: UUID, to toStateId: UUID) -> [Transition] {
        return transitions.filter { $0.fromStateId == fromStateId && $0.toStateId == toStateId }
    }
    
    private mutating func syncAlphabet() {
        var usedSymbols = Set<String>()
        for t in transitions {
            if !t.isEpsilon {
                usedSymbols.formUnion(t.symbols)
            }
        }
        self.alphabet = usedSymbols
    }
    
    private mutating func updateModifiedDate() {
        modifiedDate = Date()
    }
    
    // MARK: - Validation
    
    func validate() -> [String] {
        var errors: [String] = []
        
        if getStartState() == nil {
            errors.append("No start state defined")
        }
        
        let startStates = states.filter { $0.isStart }
        if startStates.count > 1 {
            errors.append("Multiple start states defined")
        }
        
        for transition in transitions {
            if getState(by: transition.fromStateId) == nil {
                errors.append("Transition references non-existent from state")
            }
            if getState(by: transition.toStateId) == nil {
                errors.append("Transition references non-existent to state")
            }
        }
        
        return errors
    }
    
    // MARK: - Equatable
    
    static func == (lhs: Automaton, rhs: Automaton) -> Bool {
        return lhs.id == rhs.id &&
               lhs.name == rhs.name &&
               lhs.type == rhs.type &&
               lhs.states == rhs.states &&
               lhs.transitions == rhs.transitions &&
               lhs.alphabet == rhs.alphabet &&
               lhs.createdDate == rhs.createdDate &&
               lhs.modifiedDate == rhs.modifiedDate &&
               lhs.author == rhs.author &&
               lhs.description == rhs.description &&
               lhs.tapeAlphabet == rhs.tapeAlphabet &&
               lhs.blankSymbol == rhs.blankSymbol
    }
}
