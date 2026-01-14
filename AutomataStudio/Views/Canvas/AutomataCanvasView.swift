import SwiftUI

struct AutomataCanvasView: View {
    let automaton: Automaton
    @Binding var canvasMode: CanvasMode
    @Binding var selectedStates: Set<UUID>
    @Binding var selectedTransitions: Set<UUID>
    @ObservedObject var viewModel: CanvasViewModel
    
    var onRenameState: ((UUID) -> Void)?
    var onEditTransition: ((UUID) -> Void)?
    
    @State private var dragStartLocation: CGPoint = .zero
    @State private var isPanning = false
    @State private var hoveredState: UUID?
    @State private var hoveredTransition: UUID?
    
    // transition creation state
    @State private var tempTransitionSource: UUID?
    @State private var tempTransitionEnd: CGPoint?
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // background
                Rectangle()
                    .fill(Color(nsColor: .windowBackgroundColor))
                    .ignoresSafeArea()
                
                // grid
                if viewModel.showGrid {
                    GridView(
                        gridSize: viewModel.gridSize,
                        zoomLevel: viewModel.zoomLevel,
                        panOffset: viewModel.panOffset
                    )
                }
                
                // canvas content
                Canvas { context, size in
                    drawAutomaton(context: context, size: size)
                    
                    // draw temp transition line
                    if let sourceId = tempTransitionSource,
                       let endPoint = tempTransitionEnd,
                       let sourceState = automaton.getState(by: sourceId) {
                        
                        var path = Path()
                        path.move(to: sourceState.position)
                        path.addLine(to: endPoint)
                        
                        context.stroke(
                            path,
                            with: .color(.primary.opacity(0.5)),
                            style: StrokeStyle(lineWidth: 2, dash: [5, 5])
                        )
                        
                        // draw target indicator if hovering over a valid target
                        if let targetState = findStateAt(convertToCanvasLocation(endPoint)) { 
                             let targetRect = CGRect(x: targetState.position.x - 20, y: targetState.position.y - 20, width: 40, height: 40)
                             context.stroke(Circle().path(in: targetRect), with: .color(.blue), lineWidth: 2)
                        }
                    }
                }
                .drawingGroup() 
                .scaleEffect(viewModel.zoomLevel)
                .offset(viewModel.panOffset)
                .gesture(
                    SimultaneousGesture(
                        // pan and drag gesture
                        DragGesture(minimumDistance: 1)
                            .onChanged { value in
                                if canvasMode == .view {
                                    if !isPanning && !viewModel.isDragging {
                                        let canvasLocation = convertToCanvasLocation(value.startLocation)
                                        if let state = findStateAt(canvasLocation) {
                                            viewModel.startDraggingState(state.id, from: canvasLocation)
                                        } else {
                                            isPanning = true
                                            dragStartLocation = value.startLocation
                                        }
                                    }
                                    
                                    if viewModel.isDragging {
                                        let canvasLocation = convertToCanvasLocation(value.location)
                                        viewModel.updateDragState(to: canvasLocation)
                                    } else if isPanning {
                                        viewModel.panCanvas(by: CGSize(
                                            width: value.translation.width,
                                            height: value.translation.height
                                        ))
                                    }
                                } else if canvasMode == .transition {
                                    let canvasStart = convertToCanvasLocation(value.startLocation)
                                    let canvasCurrent = convertToCanvasLocation(value.location)
                                    
                                    if tempTransitionSource == nil {
                                        if let state = findStateAt(canvasStart) {
                                            tempTransitionSource = state.id
                                        }
                                    }
                                    
                                    if tempTransitionSource != nil {
                                        tempTransitionEnd = canvasCurrent
                                    }
                                }
                            }
                            .onEnded { value in
                                if viewModel.isDragging {
                                    viewModel.endDraggingState()
                                }
                                isPanning = false
                                
                                if canvasMode == .transition, let sourceId = tempTransitionSource, let endPoint = tempTransitionEnd {
                                    // finish transition creation
                                    if let targetState = findStateAt(endPoint) {
                                        let _ = viewModel.addTransition(from: sourceId, to: targetState.id)
                                    }
                                }
                                
                                // reset temp transition
                                tempTransitionSource = nil
                                tempTransitionEnd = nil
                            },
                        
                        // tap gesture for selection
                        DragGesture(minimumDistance: 0)
                            .onEnded { value in
                                if !viewModel.isDragging && !isPanning && tempTransitionSource == nil {
                                    handleCanvasTap(at: value.startLocation)
                                }
                            }
                    )
                )
                .onTapGesture(count: 2) { location in
                     handleDoubleTap(at: location)
                }
                .onContinuousHover { phase in
                    switch phase {
                    case .active(let location):
                        let canvasLocation = convertToCanvasLocation(location)
                        if let state = findStateAt(canvasLocation) {
                            if hoveredState != state.id {
                                hoveredState = state.id
                                NSCursor.pointingHand.push()
                            }
                            hoveredTransition = nil
                        } else if let transition = findTransitionAt(canvasLocation) {
                            if hoveredTransition != transition.id {
                                hoveredTransition = transition.id
                                NSCursor.pointingHand.push()
                            }
                            hoveredState = nil
                        } else {
                            if hoveredState != nil || hoveredTransition != nil {
                                hoveredState = nil
                                hoveredTransition = nil
                                NSCursor.pop()
                            }
                        }
                    case .ended:
                        hoveredState = nil
                        hoveredTransition = nil
                        NSCursor.pop()
                    }
                }
            }
        }
        .clipped()
        .background(Color(nsColor: .windowBackgroundColor))
    }
    
    // MARK: - Drawing Methods
    
    private func drawAutomaton(context: GraphicsContext, size: CGSize) {
        // draw transitions first (so they appear behind states)
        for transition in automaton.transitions {
            drawTransition(transition, context: context)
        }
        
        // draw states
        for state in automaton.states {
            drawState(state, context: context)
        }
    }
    
    private func drawState(_ state: AutomatonState, context: GraphicsContext) {
        let isSelected = selectedStates.contains(state.id)
        let isHovered = hoveredState == state.id
        let isActive = viewModel.activeStates.contains(state.id)
        
        // state circle
        let circleSize: CGFloat = 40
        let circleRect = CGRect(
            x: state.position.x - circleSize/2,
            y: state.position.y - circleSize/2,
            width: circleSize,
            height: circleSize
        )
        
        // hover glow
        if isHovered {
            context.fill(
                Circle().path(in: circleRect),
                with: .color(.blue.opacity(0.1))
            )
            context.stroke(
                Circle().path(in: circleRect),
                with: .color(.blue.opacity(0.5)),
                lineWidth: 4
            )
        }
        
        // background circle
        context.fill(
            Circle().path(in: circleRect),
            with: .color(stateColor(for: state, isActive: isActive))
        )
        
        let borderWidth: CGFloat = isSelected ? 3 : 1
        context.stroke(
            Circle().path(in: circleRect),
            with: .color(.primary),
            lineWidth: borderWidth
        )
        
        if state.isStart {
            drawStartStateIndicator(at: state.position, context: context)
        }
        
        if state.isAccepting {
            drawAcceptingStateIndicator(at: state.position, context: context)
        }
        
        drawStateLabel(state, context: context)
    }
    
    private func drawTransition(_ transition: Transition, context: GraphicsContext) {
        guard let fromState = automaton.getState(by: transition.fromStateId),
              let toState = automaton.getState(by: transition.toStateId) else { return }
        
        let isSelected = selectedTransitions.contains(transition.id)
        let _ = hoveredTransition == transition.id // isHovered - for future hover effects
        
        // calculate transition path
        let path = transitionPath(from: fromState.position, to: toState.position, isSelfLoop: fromState.id == toState.id)
        
        // draw transition line
        let lineWidth: CGFloat = isSelected ? 3 : 2
        context.stroke(
            path,
            with: .color(.primary),
            lineWidth: lineWidth
        )
        
        drawArrowhead(on: path, context: context)
        
        drawTransitionLabel(transition, path: path, context: context)
    }
    
    private func drawStartStateIndicator(at position: CGPoint, context: GraphicsContext) {
        let indicatorSize: CGFloat = 8
        let indicatorRect = CGRect(
            x: position.x - 30,
            y: position.y - indicatorSize/2,
            width: indicatorSize,
            height: indicatorSize
        )
        
        context.fill(
            Circle().path(in: indicatorRect),
            with: .color(.blue)
        )
        
        context.stroke(
            Circle().path(in: indicatorRect),
            with: .color(.primary),
            lineWidth: 1
        )
    }
    
    private func drawAcceptingStateIndicator(at position: CGPoint, context: GraphicsContext) {
        let outerSize: CGFloat = 40
        let innerSize: CGFloat = 32
        
        let outerRect = CGRect(
            x: position.x - outerSize/2,
            y: position.y - outerSize/2,
            width: outerSize,
            height: outerSize
        )
        
        let innerRect = CGRect(
            x: position.x - innerSize/2,
            y: position.y - innerSize/2,
            width: innerSize,
            height: innerSize
        )
        
        context.stroke(
            Circle().path(in: outerRect),
            with: .color(.green),
            lineWidth: 2
        )
        
        context.stroke(
            Circle().path(in: innerRect),
            with: .color(.green),
            lineWidth: 2
        )
    }
    
    private func drawStateLabel(_ state: AutomatonState, context: GraphicsContext) {
        let text = Text(state.displayName)
            .font(.system(.caption, design: .monospaced))
            .fontWeight(.medium)
        
        context.draw(text, at: CGPoint(x: state.position.x, y: state.position.y + 25))
    }
    
    private func drawTransitionLabel(_ transition: Transition, path: Path, context: GraphicsContext) {
        let text = Text(transition.displaySymbols)
            .font(.system(.caption2, design: .monospaced))
            .fontWeight(.medium)
        
        // calculate label position along the path
        let labelPosition = CGPoint(x: transition.fromStateId == transition.toStateId ? 0 : 0, y: 0) // Simplified
        
        context.draw(text, at: labelPosition)
    }
    
    private func drawArrowhead(on path: Path, context: GraphicsContext) {


    }
    
    // MARK: - Helper Methods
    
    private func stateColor(for state: AutomatonState, isActive: Bool) -> Color {
        if isActive {
            return .yellow.opacity(0.7)
        } else if state.isStart && state.isAccepting {
            return .purple.opacity(0.3)
        } else if state.isStart {
            return .blue.opacity(0.3)
        } else if state.isAccepting {
            return .green.opacity(0.3)
        } else {
            return .gray.opacity(0.2)
        }
    }
    
    private func transitionPath(from start: CGPoint, to end: CGPoint, isSelfLoop: Bool) -> Path {
        var path = Path()
        
        if isSelfLoop {
            // self-loop transition
            let radius: CGFloat = 30
            let center = CGPoint(x: start.x, y: start.y - radius)
            
            path.addArc(
                center: center,
                radius: radius,
                startAngle: .degrees(0),
                endAngle: .degrees(360),
                clockwise: false
            )
        } else {
            // regular transition
            path.move(to: start)
            path.addLine(to: end)
        }
        
        return path
    }
    
    private func handleCanvasTap(at location: CGPoint) {
        switch canvasMode {
        case .state:
            addState(at: location)
        case .view:
            selectAtLocation(location)
        case .delete:
            deleteAtLocation(location)
        case .edit:
            editAtLocation(location)
        case .transition:
            // transition mode handled by drag gestures
            break
        }
    }
    
    private func handleDoubleTap(at location: CGPoint) {
        let canvasLocation = convertToCanvasLocation(location)
        if let state = findStateAt(canvasLocation) {
            selectedStates = [state.id]
            viewModel.selectionBox = nil
            onRenameState?(state.id)
        } else if let transition = findTransitionAt(canvasLocation) {
            selectedTransitions = [transition.id]
            onEditTransition?(transition.id)
        }
    }
    
    private func addState(at location: CGPoint) {
        let canvasLocation = convertToCanvasLocation(location)
        let newState = viewModel.addState(at: canvasLocation)
        selectedStates = [newState.id]
    }
    
    private func selectAtLocation(_ location: CGPoint) {
        let canvasLocation = convertToCanvasLocation(location)
        
        if let state = findStateAt(canvasLocation) {
            selectedStates = [state.id]
            selectedTransitions = []
            
            // start dragging if in view mode
            viewModel.startDraggingState(state.id, from: canvasLocation)
        } else if let transition = findTransitionAt(canvasLocation) {
            selectedStates = []
            selectedTransitions = [transition.id]
        } else {
            selectedStates = []
            selectedTransitions = []
            // start selection box logic if needed, or pan
        }
    }
    
    private func deleteAtLocation(_ location: CGPoint) {
        let canvasLocation = convertToCanvasLocation(location)
        
        if let state = findStateAt(canvasLocation) {
            viewModel.removeState(state.id)
            selectedStates.remove(state.id)
        } else if let transition = findTransitionAt(canvasLocation) {
            viewModel.removeTransition(transition.id)
            selectedTransitions.remove(transition.id)
        }
    }
    
    private func editAtLocation(_ location: CGPoint) {
        let canvasLocation = convertToCanvasLocation(location)
        
        if let state = findStateAt(canvasLocation) {
            selectedStates = [state.id]
            onRenameState?(state.id)
        } else if let transition = findTransitionAt(canvasLocation) {
            selectedTransitions = [transition.id]
            onEditTransition?(transition.id)
        }
    }
    
    private func convertToCanvasLocation(_ location: CGPoint) -> CGPoint {
        return CGPoint(
            x: (location.x - viewModel.panOffset.width) / viewModel.zoomLevel,
            y: (location.y - viewModel.panOffset.height) / viewModel.zoomLevel
        )
    }
    
    private func findStateAt(_ location: CGPoint) -> AutomatonState? {
        let tolerance: CGFloat = 25
        
        return viewModel.automaton.states.first { state in
            let distance = sqrt(
                pow(state.position.x - location.x, 2) +
                pow(state.position.y - location.y, 2)
            )
            return distance <= tolerance
        }
    }
    
    private func findTransitionAt(_ location: CGPoint) -> Transition? {
        // simple hit testing for transitions
        
        let tolerance: CGFloat = 10
        
        return viewModel.automaton.transitions.first { transition in
            guard let fromState = viewModel.automaton.getState(by: transition.fromStateId),
                  let toState = viewModel.automaton.getState(by: transition.toStateId) else { return false }
            
            // check if point is near the line segment
            let p1 = fromState.position
            let p2 = toState.position
            
            let distance = distancePointToSegment(location, p1, p2)
            return distance <= tolerance
        }
    }
    
    private func distancePointToSegment(_ p: CGPoint, _ v: CGPoint, _ w: CGPoint) -> CGFloat {
        let l2 = pow(v.x - w.x, 2) + pow(v.y - w.y, 2)
        if l2 == 0 { return distance(p, v) }
        
        var t = ((p.x - v.x) * (w.x - v.x) + (p.y - v.y) * (w.y - v.y)) / l2
        t = max(0, min(1, t))
        
        let projection = CGPoint(
            x: v.x + t * (w.x - v.x),
            y: v.y + t * (w.y - v.y)
        )
        
        return distance(p, projection)
    }
    
    private func distance(_ p1: CGPoint, _ p2: CGPoint) -> CGFloat {
        return sqrt(pow(p1.x - p2.x, 2) + pow(p1.y - p2.y, 2))
    }
}

// MARK: - Grid View

struct GridView: View {
    let gridSize: CGFloat
    let zoomLevel: CGFloat
    let panOffset: CGSize
    
    var body: some View {
        Canvas { context, size in
            let scaledGridSize = gridSize * zoomLevel
            
            // vertical lines
            var x: CGFloat = panOffset.width.truncatingRemainder(dividingBy: scaledGridSize)
            while x < size.width {
                context.stroke(
                    Path { path in
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: size.height))
                    },
                    with: .color(.secondary.opacity(0.2)),
                    lineWidth: 0.5
                )
                x += scaledGridSize
            }
            
            // horizontal lines
            var y: CGFloat = panOffset.height.truncatingRemainder(dividingBy: scaledGridSize)
            while y < size.height {
                context.stroke(
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: size.width, y: y))
                    },
                    with: .color(.secondary.opacity(0.2)),
                    lineWidth: 0.5
                )
                y += scaledGridSize
            }
        }
    }
}

#Preview {
    AutomataCanvasView(
        automaton: Automaton(name: "Sample", type: .dfa),
        canvasMode: Binding<CanvasMode>.constant(CanvasMode.view),
        selectedStates: Binding<Set<UUID>>.constant(Set<UUID>()),
        selectedTransitions: Binding<Set<UUID>>.constant(Set<UUID>()),
        viewModel: CanvasViewModel()
    )
}
