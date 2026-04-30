import SwiftUI

struct SimulationBottomPanel: View {
    @ObservedObject var viewModel: CanvasViewModel
    @Binding var input: String
    @State private var isCollapsed = false
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            VStack(spacing: 0) {
                // MARK: - Drag / Toggle Handle
                HStack {
                    Spacer()
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                            isCollapsed.toggle()
                        }
                    } label: {
                        VStack(spacing: 4) {
                            Capsule()
                                .fill(.secondary.opacity(0.3))
                                .frame(width: 36, height: 4)
                            
                            if isCollapsed {
                                Text("Simulation")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.secondary)
                                    .transition(.opacity)
                            }
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 20)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }
                
                if !isCollapsed {
                    VStack(spacing: 20) {
                        // MARK: - Input & Status
                        HStack(spacing: 16) {
                            HStack {
                                Image(systemName: "keyboard")
                                    .foregroundStyle(.secondary)
                                TextField("Enter input string...", text: $input)
                                    .textFieldStyle(.plain)
                                    .font(.system(.body, design: .monospaced))
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(Color.primary.opacity(0.05))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            
                            if let result = viewModel.simulationResult {
                                HStack(spacing: 8) {
                                    Image(systemName: result.accepted ? "checkmark.seal.fill" : "xmark.seal.fill")
                                        .foregroundStyle(result.accepted ? .green : .red)
                                        .symbolEffect(.bounce, value: result.accepted)
                                    
                                    Text(result.accepted ? "ACCEPTED" : "REJECTED")
                                        .font(.caption)
                                        .fontWeight(.black)
                                        .foregroundStyle(result.accepted ? .green : .red)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background((result.accepted ? Color.green : Color.red).opacity(0.1))
                                .clipShape(Capsule())
                                .transition(.scale.combined(with: .opacity))
                            }
                        }
                        
                        // MARK: - Tape View
                        if viewModel.isSimulating || viewModel.simulationResult != nil {
                            ScrollViewReader { proxy in
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 6) {
                                        ForEach(0..<max(input.count, 1), id: \.self) { index in
                                            let char = index < input.count ? String(input[input.index(input.startIndex, offsetBy: index)]) : "_"
                                            
                                            TapeCell(char: char, isActive: index == viewModel.simulationStep, isInvalid: viewModel.isCurrentStepInvalid)
                                                .id(index)
                                        }
                                    }
                                    .padding(.horizontal, 2)
                                    .padding(.vertical, 8)
                                }
                                .onChange(of: viewModel.simulationStep) { _, newValue in
                                    withAnimation {
                                        proxy.scrollTo(newValue, anchor: .center)
                                    }
                                }
                            }

                            .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                        
                        // MARK: - Controls
                        HStack(spacing: 30) {
                            Button {
                                viewModel.resetSimulation()
                            } label: {
                                VStack(spacing: 4) {
                                    Image(systemName: "arrow.counterclockwise")
                                        .font(.title3)
                                    Text("Reset")
                                        .font(.caption2)
                                }
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.secondary)
                            
                            HStack(spacing: 20) {
                                Button {
                                    if viewModel.isSimulating {
                                        viewModel.toggleAutoSimulation()
                                    } else {
                                        viewModel.startSimulation(input: input)
                                        viewModel.startAutoSimulation()
                                    }
                                } label: {
                                    let isPlaying = viewModel.isSimulating && (viewModel.simulationStep < input.count) && !viewModel.isCurrentStepInvalid
                                    Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                        .font(.system(size: 48))
                                        .foregroundStyle(.tint)
                                        .symbolRenderingMode(.monochrome)
                                }
                                .buttonStyle(.plain)
                                .pressAnimation()
                                
                                Button {
                                    if !viewModel.isSimulating {
                                        viewModel.startSimulation(input: input)
                                    }
                                    viewModel.stepSimulation()
                                } label: {
                                    VStack(spacing: 4) {
                                        Image(systemName: "forward.end.fill")
                                            .font(.title2)
                                        Text("Step")
                                            .font(.caption2)
                                    }
                                }
                                .buttonStyle(.plain)
                                .disabled(viewModel.simulationStep >= input.count && viewModel.simulationResult != nil)
                            }
                            
                            VStack(spacing: 4) {
                                Text("\(String(format: "%.1fx", viewModel.playbackSpeed))")
                                    .font(.system(.body, design: .monospaced))
                                    .fontWeight(.bold)
                                Slider(value: $viewModel.playbackSpeed, in: 0.5...4.0, step: 0.5)
                                    .frame(width: 120)
                                    .sensoryFeedback(.levelChange, trigger: viewModel.playbackSpeed)
                                Text("Speed")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.bottom, 12)
                    }
                    .padding(24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .background {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.regularMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(Color.primary.opacity(0.1), lineWidth: 0.5)
                    }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, isCollapsed ? 8 : 24)
            .frame(maxWidth: 800)
        }
    }
}

struct TapeCell: View {
    let char: String
    let isActive: Bool
    let isInvalid: Bool
    
    var body: some View {
        Text(char)
            .font(.system(.title3, design: .monospaced))
            .fontWeight(isActive ? .bold : .regular)
            .frame(width: 36, height: 44)
            .background {
                let color = isActive ? (isInvalid ? Color.orange : Color.accentColor) : Color.primary.opacity(0.05)
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(color)
            }
            .foregroundStyle(isActive ? .white : .primary)
            .scaleEffect(isActive ? 1.1 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isActive)
    }
}

// MARK: - View Modifiers

extension View {
    func pressAnimation() -> some View {
        self.modifier(PressAnimationModifier())
    }
}

struct PressAnimationModifier: ViewModifier {
    @State private var isPressed = false
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed ? 0.92 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isPressed)
            .onLongPressGesture(minimumDuration: .infinity, pressing: { pressing in
                isPressed = pressing
            }, perform: {})
    }
}
