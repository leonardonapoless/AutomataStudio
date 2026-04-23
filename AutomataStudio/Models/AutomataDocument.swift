import SwiftUI
import UniformTypeIdentifiers

struct AutomataDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.automata] }
    static var writableContentTypes: [UTType] { [.automata] }
    
    var automaton: Automaton
    
    init() {
        self.automaton = Automaton(name: "Untitled", type: .dfa)
    }
    
    init(automaton: Automaton) {
        self.automaton = automaton
    }
    
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        
        let decoder = JSONDecoder()
        self.automaton = try decoder.decode(Automaton.self, from: data)
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        let data = try encoder.encode(automaton)
        return .init(regularFileWithContents: data)
    }
}

// MARK: - UTType Extension

extension UTType {
    nonisolated static var automata: UTType {
        UTType(exportedAs: "com.automatastudio.project", conformingTo: .json)
    }
}
