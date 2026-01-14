import SwiftUI

struct SimulationPanelView: View {
    let automaton: Automaton
    @Binding var input: String
    @Environment(\.dismiss) private var dismiss
    
    @State private var simulationResult: SimulationResult?
    @State private var isRunning = false
    
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                // input section
                VStack(alignment: .leading, spacing: 8) {
                    Text("Input String")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    
                    TextField("enter input string", text: $input)
                        .textFieldStyle(.plain)
                        .padding(10)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .font(.system(.body, design: .monospaced))
                }
                
                // controls
                HStack(spacing: 12) {
                    Button {
                        runSimulation()
                    } label: {
                        Label("Run", systemImage: "play.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glass)
                    .controlSize(.large)
                    .disabled(input.isEmpty || isRunning)
                    
                    Button {
                        stepSimulation()
                    } label: {
                        Label("Step", systemImage: "chevron.right")
                    }
                    .buttonStyle(.glass)
                    .controlSize(.large)
                    .disabled(input.isEmpty || isRunning)
                    
                    Button {
                        input = ""
                        simulationResult = nil
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.glass)
                    .controlSize(.large)
                }
                
                // results area
                if let result = simulationResult {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: result.accepted ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .font(.title2)
                                .foregroundStyle(result.accepted ? .green : .red)
                                .symbolEffect(.bounce, value: result.accepted)
                            
                            Text(result.accepted ? "Accepted" : "Rejected")
                                .font(.title3)
                                .fontWeight(.semibold)
                            
                            Spacer()
                        }
                        
                        Divider()
                        
                        Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 8) {
                            GridRow {
                                Text("Steps taken")
                                    .foregroundStyle(.secondary)
                                Text("\(result.steps)")
                                    .fontWeight(.medium)
                                    .monospacedDigit()
                            }
                            
                            if !result.finalStates.isEmpty {
                                GridRow {
                                    Text("Final states")
                                        .foregroundStyle(.secondary)
                                    Text("\(result.finalStates.count)")
                                        .fontWeight(.medium)
                                        .monospacedDigit()
                                }
                            }
                        }
                        .font(.callout)
                    }
                    .padding()
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                
                Spacer()
            }
            .padding(24)
            .navigationTitle("Simulation")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .presentationBackground(.regularMaterial)
        .frame(width: 400, height: 500)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.hidden)
    }
    
    // simulation logic below
    // keeping it simple for now, would be better to move this to a dedicated engine later
    
    private func runSimulation() {
        isRunning = true
        
        // simulate some thinking time for better ux
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            let accepted = simulateAutomaton(input: input)
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                simulationResult = SimulationResult(
                    accepted: accepted,
                    finalStates: Set(),
                    steps: input.count
                )
                isRunning = false
            }
        }
    }
    
    private func stepSimulation() {
        // TODO: implement step-by-step
    }
    
    private func simulateAutomaton(input: String) -> Bool {
        guard let startState = automaton.getStartState() else { return false }
        
        var currentState = startState
        
        for char in input {
            let symbol = String(char)
            let transitions = automaton.getTransitions(from: currentState.id)
            
            if let transition = transitions.first(where: { $0.symbols.contains(symbol) }) {
                if let nextState = automaton.getState(by: transition.toStateId) {
                    currentState = nextState
                } else {
                    return false
                }
            } else {
                return false
            }
        }
        
        return currentState.isAccepting
    }
}
