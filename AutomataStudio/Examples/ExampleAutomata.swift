import Foundation

struct ExampleAutomata {
    
    // MARK: - Binary Divisible by 3 DFA
    
    static func binaryDivisibleByThree() -> Automaton {
        var automaton = Automaton(
            name: "Binary Divisible by 3",
            type: .dfa,
        )
        
        let q0 = AutomatonState(name: "q0", position: CGPoint(x: 150, y: 150), isStart: true, isAccepting: true)  // remainder 0
        let q1 = AutomatonState(name: "q1", position: CGPoint(x: 300, y: 150), isStart: false, isAccepting: false) // remainder 1
        let q2 = AutomatonState(name: "q2", position: CGPoint(x: 450, y: 150), isStart: false, isAccepting: false) // remainder 2
        
        automaton.states = [q0, q1, q2]
        
        let transitions = [
            Transition(fromStateId: q0.id, toStateId: q0.id, symbols: ["0"]), // 0*2+0 = 0
            Transition(fromStateId: q0.id, toStateId: q1.id, symbols: ["1"]), // 0*2+1 = 1
            Transition(fromStateId: q1.id, toStateId: q2.id, symbols: ["0"]), // 1*2+0 = 2
            Transition(fromStateId: q1.id, toStateId: q0.id, symbols: ["1"]), // 1*2+1 = 3 ≡ 0
            Transition(fromStateId: q2.id, toStateId: q1.id, symbols: ["0"]), // 2*2+0 = 4 ≡ 1
            Transition(fromStateId: q2.id, toStateId: q2.id, symbols: ["1"])  // 2*2+1 = 5 ≡ 2
        ]
        
        automaton.transitions = transitions
        automaton.alphabet = ["0", "1"]
        
        return automaton
    }
    
    // MARK: - (a|b)*abb NFA
    
    static func abbPatternNFA() -> Automaton {
        var automaton = Automaton(
            name: "Pattern (a|b)*abb",
            type: .nfa,
        )
        
        let q0 = AutomatonState(name: "q0", position: CGPoint(x: 100, y: 150), isStart: true, isAccepting: false)
        let q1 = AutomatonState(name: "q1", position: CGPoint(x: 250, y: 150), isStart: false, isAccepting: false)
        let q2 = AutomatonState(name: "q2", position: CGPoint(x: 400, y: 150), isStart: false, isAccepting: false)
        let q3 = AutomatonState(name: "q3", position: CGPoint(x: 550, y: 150), isStart: false, isAccepting: true)
        
        automaton.states = [q0, q1, q2, q3]
        
        let transitions = [
            Transition(fromStateId: q0.id, toStateId: q0.id, symbols: ["a"]),
            Transition(fromStateId: q0.id, toStateId: q0.id, symbols: ["b"]),
            Transition(fromStateId: q0.id, toStateId: q1.id, symbols: ["a"]),
            Transition(fromStateId: q1.id, toStateId: q2.id, symbols: ["b"]),
            Transition(fromStateId: q2.id, toStateId: q3.id, symbols: ["b"])
        ]
        
        automaton.transitions = transitions
        automaton.alphabet = ["a", "b"]
        
        return automaton
    }
    
    // MARK: - Simple Turing Machine
    
    static func binaryIncrementTM() -> Automaton {
        var automaton = Automaton(
            name: "Binary Increment",
            type: .turingMachine,
        )
        
        let q0 = AutomatonState(name: "q0", position: CGPoint(x: 150, y: 150), isStart: true, isAccepting: false)
        let q1 = AutomatonState(name: "q1", position: CGPoint(x: 300, y: 150), isStart: false, isAccepting: false)
        let q2 = AutomatonState(name: "q2", position: CGPoint(x: 450, y: 150), isStart: false, isAccepting: true)
        
        automaton.states = [q0, q1, q2]
        
        let transitions = [
            Transition(fromStateId: q0.id, toStateId: q1.id, symbols: ["0"]),
            Transition(fromStateId: q0.id, toStateId: q2.id, symbols: ["1"]),
            Transition(fromStateId: q1.id, toStateId: q2.id, symbols: ["1"])
        ]
        
        automaton.transitions = transitions
        automaton.alphabet = ["0", "1"]
        automaton.tapeAlphabet = ["0", "1", "B"]
        automaton.blankSymbol = "B"
        
        return automaton
    }
    
    // MARK: - Palindrome DFA (simplified)
    
    static func palindromeDFA() -> Automaton {
        var automaton = Automaton(
            name: "Palindrome (Length ≤ 3)",
            type: .dfa,
        )
        
        let q0 = AutomatonState(name: "q0", position: CGPoint(x: 100, y: 150), isStart: true, isAccepting: true)  // empty string
        let q1 = AutomatonState(name: "q1", position: CGPoint(x: 250, y: 150), isStart: false, isAccepting: true) // single char
        let q2 = AutomatonState(name: "q2", position: CGPoint(x: 400, y: 150), isStart: false, isAccepting: true) // two chars
        let q3 = AutomatonState(name: "q3", position: CGPoint(x: 550, y: 150), isStart: false, isAccepting: true) // three chars
        let q4 = AutomatonState(name: "q4", position: CGPoint(x: 400, y: 300), isStart: false, isAccepting: false) // reject
        
        automaton.states = [q0, q1, q2, q3, q4]
        
        let transitions = [
            Transition(fromStateId: q0.id, toStateId: q1.id, symbols: ["a"]),
            Transition(fromStateId: q0.id, toStateId: q1.id, symbols: ["b"]),
            Transition(fromStateId: q1.id, toStateId: q2.id, symbols: ["a"]),
            Transition(fromStateId: q1.id, toStateId: q2.id, symbols: ["b"]),
            Transition(fromStateId: q2.id, toStateId: q3.id, symbols: ["a"]),
            Transition(fromStateId: q2.id, toStateId: q3.id, symbols: ["b"]),
            Transition(fromStateId: q3.id, toStateId: q4.id, symbols: ["a"]),
            Transition(fromStateId: q3.id, toStateId: q4.id, symbols: ["b"]),
            Transition(fromStateId: q4.id, toStateId: q4.id, symbols: ["a"]),
            Transition(fromStateId: q4.id, toStateId: q4.id, symbols: ["b"])
        ]
        
        automaton.transitions = transitions
        automaton.alphabet = ["a", "b"]
        
        return automaton
    }
    
    // MARK: - All Examples
    
    static func allExamples() -> [Automaton] {
        return [
            binaryDivisibleByThree(),
            abbPatternNFA(),
            binaryIncrementTM(),
            palindromeDFA()
        ]
    }
}
