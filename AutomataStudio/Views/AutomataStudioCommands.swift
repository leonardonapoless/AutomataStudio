import SwiftUI

struct AutomataStudioCommands: Commands {
    @State private var showInspector = true
    @State private var showSidebar = true
    
    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Automaton") {
                // this will be handled by DocumentGroup
            }
            .keyboardShortcut("n", modifiers: .command)
        }
        
        CommandGroup(after: .newItem) {
            Divider()
            
            Button("New DFA") {
                // create new DFA document
            }
            .keyboardShortcut("n", modifiers: [.command, .shift])
            
            Button("New NFA") {
                // create new NFA document
            }
            .keyboardShortcut("n", modifiers: [.command, .option])
        }
        
        CommandGroup(after: .importExport) {
            Divider()
            
            Button("Export DOT") {
                // export to Graphviz DOT format
            }
            .keyboardShortcut("e", modifiers: [.command, .option])
            
            Button("Export PNG") {
                // export canvas as PNG
            }
            .keyboardShortcut("e", modifiers: [.command, .shift])
            
            Button("Export SVG") {
                // export canvas as SVG
            }
            .keyboardShortcut("e", modifiers: [.command, .control])
        }
        
        CommandGroup(after: .toolbar) {
            Divider()
            
            Button("Toggle Inspector") {
                showInspector.toggle()
            }
            .keyboardShortcut("i", modifiers: [.command, .option])
            
            Button("Toggle Sidebar") {
                showSidebar.toggle()
            }
            .keyboardShortcut("s", modifiers: [.command, .option])
        }
        
        CommandGroup(after: .undoRedo) {
            Divider()
            
            Button("Run Simulation") {
                // start simulation
            }
            .keyboardShortcut("r", modifiers: .command)
            
            Button("Step Simulation") {
                // step through simulation
            }
            .keyboardShortcut("r", modifiers: [.command, .shift])
            
            Button("Reset Simulation") {
                // Reset simulation
            }
            .keyboardShortcut("r", modifiers: [.command, .option])
        }
        
        CommandGroup(after: .textEditing) {
            Divider()
            
            Menu("Algorithms") {
                Button("Convert NFA to DFA") {
                    // convert NFA to DFA
                }
                .keyboardShortcut("c", modifiers: [.command, .shift])
                
                Button("Minimize DFA") {
                    // minimize DFA
                }
                .keyboardShortcut("m", modifiers: [.command, .shift])
                
                Button("Regex to NFA") {
                    // convert regex to NFA
                }
                .keyboardShortcut("r", modifiers: [.command, .shift])
                
                Divider()
                
                Button("Check Equivalence") {
                    // check automaton equivalence
                }
                .keyboardShortcut("=", modifiers: [.command, .shift])
                
                Button("Check Emptiness") {
                    // check language emptiness
                }
                .keyboardShortcut("e", modifiers: [.command, .shift])
            }
        }
        
        CommandGroup(after: .help) {
            Divider()
            
            Button("Keyboard Shortcuts") {
                // show shortcuts help
            }
            .keyboardShortcut("?", modifiers: .command)
        }
    }
}
