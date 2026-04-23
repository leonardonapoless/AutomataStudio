import Foundation
import SwiftUI

struct ExportUtilities {
    
    // MARK: - DOT Export
    
    static func exportToDOT(_ automaton: Automaton) -> String {
        var dot = "digraph \(automaton.name.replacingOccurrences(of: " ", with: "_")) {\n"
        dot += "  rankdir=LR;\n"
        dot += "  node [shape=circle];\n\n"
        
        for state in automaton.states {
            let shape = state.isAccepting ? "doublecircle" : "circle"
            let label = state.displayName
            dot += "  \"\(state.id)\" [shape=\(shape), label=\"\(label)\"];\n"
        }
        
        if let startState = automaton.getStartState() {
            dot += "  \"start\" [shape=point];\n"
            dot += "  \"start\" -> \"\(startState.id)\";\n"
        }
        
        dot += "\n"
        
        for transition in automaton.transitions {
            let fromState = automaton.getState(by: transition.fromStateId)
            let toState = automaton.getState(by: transition.toStateId)
            
            if let from = fromState, let to = toState {
                let label = transition.displaySymbols
                dot += "  \"\(from.id)\" -> \"\(to.id)\" [label=\"\(label)\"];\n"
            }
        }
        
        dot += "}\n"
        return dot
    }
    
    // MARK: - Image Export
    
    static func exportToPNG(_ automaton: Automaton, size: CGSize = CGSize(width: 800, height: 600)) -> Data? {
        return "PNG placeholder".data(using: .utf8)
    }
    
    static func exportToSVG(_ automaton: Automaton, size: CGSize = CGSize(width: 800, height: 600)) -> String {
        var svg = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
        svg += "<svg width=\"\(Int(size.width))\" height=\"\(Int(size.height))\" xmlns=\"http://www.w3.org/2000/svg\">\n"
        
        svg += "  <defs>\n"
        svg += "    <marker id=\"arrowhead\" markerWidth=\"10\" markerHeight=\"7\" refX=\"9\" refY=\"3.5\" orient=\"auto\">\n"
        svg += "      <polygon points=\"0 0, 10 3.5, 0 7\" fill=\"black\"/>\n"
        svg += "    </marker>\n"
        svg += "  </defs>\n"
        
        for state in automaton.states {
            let x = Int(state.position.x)
            let y = Int(state.position.y)
            let radius = 20
            
            if state.isAccepting {
                svg += "  <circle cx=\"\(x)\" cy=\"\(y)\" r=\"\(radius + 5)\" fill=\"none\" stroke=\"black\" stroke-width=\"2\"/>\n"
            }
            
            svg += "  <circle cx=\"\(x)\" cy=\"\(y)\" r=\"\(radius)\" fill=\"lightblue\" stroke=\"black\" stroke-width=\"2\"/>\n"
            
            svg += "  <text x=\"\(x)\" y=\"\(y + 5)\" text-anchor=\"middle\" font-family=\"Arial\" font-size=\"12\">\(state.displayName)</text>\n"
            
            if state.isStart {
                svg += "  <circle cx=\"\(x - 30)\" cy=\"\(y)\" r=\"5\" fill=\"blue\"/>\n"
                svg += "  <line x1=\"\(x - 25)\" y1=\"\(y)\" x2=\"\(x - 20)\" y2=\"\(y)\" stroke=\"black\" stroke-width=\"2\"/>\n"
            }
        }
        
        for transition in automaton.transitions {
            let fromState = automaton.getState(by: transition.fromStateId)
            let toState = automaton.getState(by: transition.toStateId)
            
            if let from = fromState, let to = toState {
                let x1 = Int(from.position.x)
                let y1 = Int(from.position.y)
                let x2 = Int(to.position.x)
                let y2 = Int(to.position.y)
                
                svg += "  <line x1=\"\(x1)\" y1=\"\(y1)\" x2=\"\(x2)\" y2=\"\(y2)\" stroke=\"black\" stroke-width=\"2\" marker-end=\"url(#arrowhead)\"/>\n"
                
                let midX = (x1 + x2) / 2
                let midY = (y1 + y2) / 2
                svg += "  <text x=\"\(midX)\" y=\"\(midY - 5)\" text-anchor=\"middle\" font-family=\"Arial\" font-size=\"10\">\(transition.displaySymbols)</text>\n"
            }
        }
        
        svg += "</svg>"
        return svg
    }
    
    // MARK: - JFLAP Export .jff
    static func exportToJFLAP(_ automaton: Automaton) -> String {
        var xml = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"no\"?><!--Created with AutomataStudio--><structure>\n"
        
        let type = switch automaton.type {
        case .dfa, .nfa: "fa"
        case .turingMachine: "turing"
        }
        
        xml += "\t<type>\(type)</type>\n"
        xml += "\t<automaton>\n"
        xml += "\t\t<!--The list of states.-->\n"
        
        var idMap: [UUID: Int] = [:]
        for (index, state) in automaton.states.enumerated() {
            idMap[state.id] = index
            
            xml += "\t\t<state id=\"\(index)\" name=\"\(state.name)\">\n"
            xml += "\t\t\t<x>\(state.position.x)</x>\n"
            xml += "\t\t\t<y>\(state.position.y)</y>\n"
            if state.isStart {
                xml += "\t\t\t<initial/>\n"
            }
            if state.isAccepting {
                xml += "\t\t\t<final/>\n"
            }
            xml += "\t\t</state>\n"
        }
        
        xml += "\t\t<!--The list of transitions.-->\n"
        for transition in automaton.transitions {
            guard let fromId = idMap[transition.fromStateId],
                  let toId = idMap[transition.toStateId] else { continue }
            
            if transition.isEpsilon {
                xml += "\t\t<transition>\n"
                xml += "\t\t\t<from>\(fromId)</from>\n"
                xml += "\t\t\t<to>\(toId)</to>\n"
                xml += "\t\t\t<read/>\n"
                xml += "\t\t</transition>\n"
            } else {
                for symbol in transition.symbols {
                    xml += "\t\t<transition>\n"
                    xml += "\t\t\t<from>\(fromId)</from>\n"
                    xml += "\t\t\t<to>\(toId)</to>\n"
                    xml += "\t\t\t<read>\(symbol)</read>\n"
                    xml += "\t\t</transition>\n"
                }
                
                if transition.symbols.isEmpty && !transition.isEpsilon {
                    xml += "\t\t<transition>\n"
                    xml += "\t\t\t<from>\(fromId)</from>\n"
                    xml += "\t\t\t<to>\(toId)</to>\n"
                    xml += "\t\t\t<read/>\n"
                    xml += "\t\t</transition>\n"
                }
            }
        }
        
        xml += "\t</automaton>\n"
        xml += "</structure>"
        
        return xml
    }
    
    static func exportProject(_ automaton: Automaton) -> Data? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        do {
            return try encoder.encode(automaton)
        } catch {
            print("Failed to encode automaton: \(error)")
            return nil
        }
    }
    
    static func importProject(from data: Data) -> Automaton? {
        let decoder = JSONDecoder()
        
        do {
            return try decoder.decode(Automaton.self, from: data)
        } catch {
            print("Failed to decode automaton: \(error)")
            return nil
        }
    }
}

// MARK: - Export Menu Commands

extension Automaton {
    func exportToDOT() -> String {
        return ExportUtilities.exportToDOT(self)
    }
    
    func exportToSVG() -> String {
        return ExportUtilities.exportToSVG(self)
    }
    
    func exportToPNG() -> Data? {
        return ExportUtilities.exportToPNG(self)
    }
    
    func exportToJFLAP() -> String {
        return ExportUtilities.exportToJFLAP(self)
    }
}
