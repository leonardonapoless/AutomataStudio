import SwiftUI

struct AppCommands: Commands {
    @State private var showInspector = true
    @State private var showSidebar = true
    
    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Automaton") {
            }
            .keyboardShortcut("n", modifiers: .command)
        }
        
        CommandGroup(after: .newItem) {
            Divider()
            
            Button("New DFA") {
            }
            .keyboardShortcut("n", modifiers: [.command, .shift])
            
            Button("New NFA") {
            }
            .keyboardShortcut("n", modifiers: [.command, .option])
        }
        
        CommandGroup(after: .importExport) {
            Divider()
            
            Button("Export DOT") {
            }
            .keyboardShortcut("e", modifiers: [.command, .option])
            
            Button("Export PNG") {
            }
            .keyboardShortcut("e", modifiers: [.command, .shift])
            
            Button("Export SVG") {
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
            }
            .keyboardShortcut("r", modifiers: .command)
            
            Button("Step Simulation") {
            }
            .keyboardShortcut("t", modifiers: [.command, .shift])
            
            Button("Reset Simulation") {
            }
            .keyboardShortcut("r", modifiers: [.command, .option])
        }
        
        CommandGroup(after: .textEditing) {
            Divider()
            
            Menu("Algorithms") {
                Button("Convert NFA to DFA") {
                }
                .keyboardShortcut("c", modifiers: [.command, .shift])
                
                Button("Minimize DFA") {
                }
                .keyboardShortcut("m", modifiers: [.command, .shift])
                
                Button("Regex to NFA") {
                }
                .keyboardShortcut("r", modifiers: [.command, .shift])
                
                Divider()
                
                Button("Check Equivalence") {
                }
                .keyboardShortcut("=", modifiers: [.command, .shift])
                
                Button("Check Emptiness") {
                }
                .keyboardShortcut("0", modifiers: [.command, .shift])
            }
        }
        
        CommandGroup(after: .help) {
            Divider()
            
            Button("Keyboard Shortcuts") {
            }
            .keyboardShortcut("?", modifiers: .command)
        }
    }
}
