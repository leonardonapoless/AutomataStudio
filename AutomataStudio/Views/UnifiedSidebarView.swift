import SwiftUI

struct UnifiedSidebarView: View {
    let automaton: Automaton
    @Binding var selectedStates: Set<UUID>
    @Binding var selectedTransitions: Set<UUID>
    @ObservedObject var inspectorViewModel: InspectorViewModel
    
    @State private var selectedTab: SidebarTab = .inspector
    @State private var searchText = ""
    
    enum SidebarTab: String, CaseIterable {
        case navigator = "Navigator"
        case inspector = "Inspector"
    }
    
    var body: some View {
        VStack(spacing: 0) {
            Picker("Mode", selection: $selectedTab) {
                ForEach(SidebarTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal)
            .padding(.vertical, 8)
            
            Divider()
            
            switch selectedTab {
            case .navigator:
                NavigatorView(
                    automaton: automaton,
                    selectedStates: $selectedStates,
                    selectedTransitions: $selectedTransitions,
                    searchText: $searchText
                )
            case .inspector:
                InspectorContentView(
                    automaton: automaton,
                    selectedStates: $selectedStates,
                    selectedTransitions: $selectedTransitions,
                    viewModel: inspectorViewModel
                )
            }
        }
        .onChange(of: selectedStates) { _, new in
            if !new.isEmpty { selectedTab = .inspector }
        }
        .onChange(of: selectedTransitions) { _, new in
            if !new.isEmpty { selectedTab = .inspector }
        }
        .navigationTitle(selectedTab.rawValue)
    }
}

// MARK: - Navigator Components

struct NavigatorView: View {
    let automaton: Automaton
    @Binding var selectedStates: Set<UUID>
    @Binding var selectedTransitions: Set<UUID>
    @Binding var searchText: String
    
    var filteredStates: [AutomatonState] {
        if searchText.isEmpty {
            return automaton.states
        } else {
            return automaton.states.filter { state in
                state.name.localizedCaseInsensitiveContains(searchText) ||
                state.displayName.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search states", text: $searchText)
                    .textFieldStyle(.plain)
            }
            .padding(10)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(8)
            .padding(.horizontal)
            .padding(.vertical, 8)
            
            List(selection: $selectedStates) {
                Section("States (\(filteredStates.count))") {
                    ForEach(filteredStates) { state in
                        StateRowView(state: state)
                            .tag(state.id)
                    }
                }
                
                Section("Transitions (\(automaton.transitions.count))") {
                    ForEach(automaton.transitions) { transition in
                        TransitionRowView(transition: transition, automaton: automaton)
                            .tag(transition.id)
                    }
                }
            }
            .listStyle(.sidebar)
        }
    }
}

struct StateRowView: View {
    let state: AutomatonState
    
    var body: some View {
        HStack {
            Circle()
                .fill(stateColor)
                .frame(width: 8, height: 8)
            
            Text(state.displayName)
                .font(.system(.body, design: .monospaced))
            
            Spacer()
            
            if state.isStart {
                Image(systemName: "play.fill").font(.caption2).foregroundColor(.blue)
            }
            if state.isAccepting {
                Image(systemName: "checkmark.circle.fill").font(.caption2).foregroundColor(.green)
            }
        }
    }
    
    private var stateColor: Color {
        if state.isStart { return .blue }
        if state.isAccepting { return .green }
        return .secondary
    }
}

struct TransitionRowView: View {
    let transition: Transition
    let automaton: Automaton
    
    var body: some View {
        HStack {
            Text(transitionDescription)
                .font(.system(.caption, design: .monospaced))
            Spacer()
            Text(transition.displaySymbols)
                .font(.system(.caption2, design: .monospaced))
                .foregroundColor(.secondary)
                .padding(.horizontal, 4)
                .background(.secondary.opacity(0.1))
                .cornerRadius(4)
        }
    }
    
    private var transitionDescription: String {
        let from = automaton.getState(by: transition.fromStateId)?.displayName ?? "?"
        let to = automaton.getState(by: transition.toStateId)?.displayName ?? "?"
        return "\(from) → \(to)"
    }
}

// MARK: - Inspector Components

struct InspectorContentView: View {
    let automaton: Automaton
    @Binding var selectedStates: Set<UUID>
    @Binding var selectedTransitions: Set<UUID>
    @ObservedObject var viewModel: InspectorViewModel
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // If nothing selected, show Automaton Properties
                if selectedStates.isEmpty && selectedTransitions.isEmpty {
                    AutomatonPropertiesSection(automaton: automaton, viewModel: viewModel)
                    Divider()
                    StatisticsSection(automaton: automaton, viewModel: viewModel)
                } else {
                    if !selectedStates.isEmpty {
                        if selectedStates.count == 1, let state = automaton.getState(by: selectedStates.first!) {
                            StatePropertiesSection(state: state, viewModel: viewModel)
                        } else {
                            Text("\(selectedStates.count) states selected").foregroundStyle(.secondary)
                        }
                    }
                    
                    if !selectedTransitions.isEmpty {
                        if !selectedStates.isEmpty { Divider() }
                        if selectedTransitions.count == 1, let transition = automaton.transitions.first(where: { $0.id == selectedTransitions.first! }) {
                            TransitionPropertiesSection(transition: transition, viewModel: viewModel)
                        } else {
                             Text("\(selectedTransitions.count) transitions selected").foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .padding()
        }
        .onChange(of: selectedStates) { _, new in
            if new.count == 1 {
                viewModel.selectState(automaton.getState(by: new.first!))
            } else {
                viewModel.selectState(nil)
            }
        }
        .onChange(of: selectedTransitions) { _, new in
            if new.count == 1 {
                viewModel.selectTransition(automaton.transitions.first { $0.id == new.first! })
            } else {
                viewModel.selectTransition(nil)
            }
        }
    }
}

struct AutomatonPropertiesSection: View {
    let automaton: Automaton
    @ObservedObject var viewModel: InspectorViewModel
    
    var body: some View {
        GroupBox("Automaton") {
            VStack(alignment: .leading, spacing: 12) {
                LabeledContent("Name") {
                    TextField("Name", text: Binding(
                        get: { automaton.name },
                        set: { viewModel.updateAutomatonName($0) }
                    ))
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.trailing)
                }
                
                LabeledContent("Type") {
                    Picker("", selection: Binding(
                        get: { automaton.type },
                        set: { viewModel.updateAutomatonType($0) }
                    )) {
                        ForEach(AutomatonType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .labelsHidden()
                }
                
                LabeledContent("Author") {
                    TextField("Author", text: Binding(
                        get: { automaton.author ?? "" },
                        set: { viewModel.updateAutomatonAuthor($0) }
                    ))
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.trailing)
                }
            }
            .padding(.vertical, 4)
        }
        .groupBoxStyle(GlassGroupBoxStyle())
    }
}

struct StatePropertiesSection: View {
    let state: AutomatonState
    @ObservedObject var viewModel: InspectorViewModel
    
    var body: some View {
        GroupBox("State: \(state.displayName)") {
            VStack(alignment: .leading, spacing: 12) {
                LabeledContent("Name") {
                    TextField("Name", text: $viewModel.editingStateName)
                        .onSubmit { viewModel.updateSelectedState() }
                        .textFieldStyle(.plain)
                        .multilineTextAlignment(.trailing)
                }

                Divider()
                
                Toggle("Start State", isOn: Binding(
                    get: { state.isStart },
                    set: { _ in viewModel.toggleStartState() }
                ))
                
                Toggle("Accepting", isOn: Binding(
                    get: { state.isAccepting },
                    set: { _ in viewModel.toggleAcceptingState() }
                ))
            }
            .padding(.vertical, 4)
        }
        .groupBoxStyle(GlassGroupBoxStyle())
    }
}

struct TransitionPropertiesSection: View {
    let transition: Transition
    @ObservedObject var viewModel: InspectorViewModel
    
    var body: some View {
        GroupBox("Transition") {
            VStack(alignment: .leading, spacing: 12) {
                LabeledContent("Symbols") {
                    TextField("e.g. a,b", text: $viewModel.editingTransitionSymbols)
                        .onSubmit { viewModel.updateSelectedTransition() }
                        .textFieldStyle(.plain)
                        .multilineTextAlignment(.trailing)
                }
                
                Toggle("Epsilon (ε)", isOn: Binding(
                    get: { transition.isEpsilon },
                    set: { _ in viewModel.addEpsilonTransition() }
                ))
            }
            .padding(.vertical, 4)
        }
        .groupBoxStyle(GlassGroupBoxStyle())
    }
}

struct StatisticsSection: View {
    let automaton: Automaton
    @ObservedObject var viewModel: InspectorViewModel
    
    var body: some View {
        GroupBox("Statistics") {
            let stats = viewModel.getAutomatonStatistics()
            VStack(spacing: 8) {
                StatRow(key: "States", value: "\(stats.stateCount)")
                StatRow(key: "Transitions", value: "\(stats.transitionCount)")
                StatRow(key: "Alphabet", value: "\(stats.alphabetSize)")
                StatRow(key: "Accepting", value: "\(stats.acceptingStateCount)")
            }
            .padding(.vertical, 4)
        }
        .groupBoxStyle(GlassGroupBoxStyle())
    }
    
    struct StatRow: View {
        let key: String
        let value: String
        var body: some View {
            HStack {
                Text(key).foregroundStyle(.secondary)
                Spacer()
                Text(value).fontWeight(.medium).monospacedDigit()
            }
        }
    }
}

// MARK: - Styles
struct GlassGroupBoxStyle: GroupBoxStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            configuration.label
                .font(.headline)
                .foregroundStyle(.primary)
            
            configuration.content
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
