import SwiftUI
import AppKit

struct CanvasView: View {
    let automaton: Automaton
    @Binding var canvasMode: CanvasMode
    @Binding var selectedStates: Set<UUID>
    @Binding var selectedTransitions: Set<UUID>
    @ObservedObject var viewModel: CanvasViewModel
    
    var onRenameState: ((UUID) -> Void)?
    var onEditTransition: ((UUID) -> Void)?
    
    @State private var isDraggingState = false
    @State private var isPanning = false
    @State private var hoveredState: UUID?
    @State private var hoveredTransition: UUID?
    
    @State private var tempTransitionSource: UUID?
    @State private var tempTransitionEnd: CGPoint?
    
    @State private var isMarqueeSelecting = false
    @State private var marqueeStart: CGPoint?
    @State private var marqueeCurrent: CGPoint?
    
    @State private var lastMagnification: CGFloat = 1.0
    
    @State private var scrollMonitor: Any?
    @State private var rightClickMonitor: Any?
    @State private var canvasFrame: CGRect = .zero
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Rectangle()
                    .fill(Color(nsColor: .windowBackgroundColor))
                    .ignoresSafeArea()
                
                if viewModel.showGrid {
                    GridView(
                        gridSize: viewModel.gridSize,
                        zoomLevel: viewModel.zoomLevel,
                        panOffset: viewModel.panOffset
                    )
                }
                
                TimelineView(.animation) { timeline in
                    Canvas { context, size in
                        drawAutomaton(context: context, size: size, date: timeline.date)
                        
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
                            
                            if let targetState = findStateAt(endPoint) {
                                let targetRect = CGRect(
                                    x: targetState.position.x - 22,
                                    y: targetState.position.y - 22,
                                    width: 44, height: 44
                                )
                                context.stroke(
                                    Circle().path(in: targetRect),
                                    with: .color(.accentColor),
                                    lineWidth: 2.5
                                )
                            }
                        }
                        
                        if isMarqueeSelecting, let start = marqueeStart, let current = marqueeCurrent {
                            let rect = CGRect(
                                x: min(start.x, current.x),
                                y: min(start.y, current.y),
                                width: abs(current.x - start.x),
                                height: abs(current.y - start.y)
                            )
                            context.fill(Path(rect), with: .color(Color.accentColor.opacity(0.1)))
                            context.stroke(Path(rect), with: .color(Color.accentColor), style: StrokeStyle(lineWidth: 1, dash: [5, 5]))
                        }
                    }
                }
                .drawingGroup()
                .scaleEffect(viewModel.zoomLevel)
                .offset(viewModel.panOffset)
                // MARK: - Gestures
                .gesture(primaryDragGesture)
                .gesture(magnifyGesture)
                .onTapGesture(count: 2) { location in
                    handleDoubleTap(at: location)
                }
                .onTapGesture(count: 1) { location in
                    handleSingleTap(at: location)
                }
                .onContinuousHover { phase in
                    handleHover(phase)
                }
            }
            .background(
                GeometryReader { geo in
                    Color.clear
                        .onAppear { canvasFrame = geo.frame(in: .global) }
                        .onChange(of: geo.frame(in: .global)) { _, newFrame in
                            canvasFrame = newFrame
                        }
                }
            )
        }
        .onAppear { installEventMonitors() }
        .onDisappear { removeEventMonitors() }
    }
    
    // MARK: - Primary Drag Gesture
    
    private var primaryDragGesture: some Gesture {
        DragGesture(minimumDistance: 3)
            .onChanged { value in
                let canvasStart = convertToCanvasLocation(value.startLocation)
                let canvasCurrent = convertToCanvasLocation(value.location)
                
                if NSEvent.modifierFlags.contains(.option) {
                    isMarqueeSelecting = true
                    marqueeStart = canvasStart
                    marqueeCurrent = canvasCurrent
                    
                    let rect = CGRect(
                        x: min(canvasStart.x, canvasCurrent.x),
                        y: min(canvasStart.y, canvasCurrent.y),
                        width: abs(canvasCurrent.x - canvasStart.x),
                        height: abs(canvasCurrent.y - canvasStart.y)
                    )
                    
                    let newSelection = automaton.states.filter { rect.contains($0.position) }.map { $0.id }
                    selectedStates = Set(newSelection)
                    selectedTransitions = []
                    return
                }
                
                switch canvasMode {
                case .select:
                    if !isDraggingState && !viewModel.isDragging && !isPanning {
                        if let state = findStateAt(canvasStart) {
                            viewModel.startDraggingState(state.id, from: canvasStart)
                            isDraggingState = true
                            selectedStates = [state.id]
                            selectedTransitions = []
                        } else {
                            isPanning = true
                        }
                    }
                    
                    if viewModel.isDragging {
                        viewModel.updateDragState(to: canvasCurrent)
                    } else if isPanning {
                        viewModel.panCanvas(by: value.translation)
                    }
                    
                case .transition:
                    var currentSource = tempTransitionSource
                    if currentSource == nil {
                        if let state = findStateAt(canvasStart) {
                            currentSource = state.id
                            tempTransitionSource = state.id
                        }
                    }
                    if currentSource != nil {
                        tempTransitionEnd = canvasCurrent
                    }
                    
                case .addState:
                    if !isPanning {
                        if findStateAt(canvasStart) == nil {
                            isPanning = true
                        }
                    }
                    if isPanning {
                        viewModel.panCanvas(by: value.translation)
                    }
                }
            }
            .onEnded { value in
                let canvasEnd = convertToCanvasLocation(value.location)
                
                if isMarqueeSelecting {
                    isMarqueeSelecting = false
                    marqueeStart = nil
                    marqueeCurrent = nil
                    return
                }
                
                switch canvasMode {
                case .select:
                    if viewModel.isDragging {
                        viewModel.endDraggingState()
                    }
                    if isPanning {
                        viewModel.endPan()
                    }
                    isDraggingState = false
                    isPanning = false
                    
                case .transition:
                    if let sourceId = tempTransitionSource {
                        if let targetState = findStateAt(canvasEnd) {
                            let newTransition = viewModel.addTransition(from: sourceId, to: targetState.id)
                            selectedStates = []
                            selectedTransitions = [newTransition.id]
                            onEditTransition?(newTransition.id)
                        }
                    }
                    tempTransitionSource = nil
                    tempTransitionEnd = nil
                    
                case .addState:
                    if isPanning {
                        viewModel.endPan()
                    }
                    isPanning = false
                }
            }
    }
    
    // MARK: - Magnify Gesture (pinch to zoom)
    
    private var magnifyGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                let scale = value.magnification / lastMagnification
                lastMagnification = value.magnification
                
                let anchor = value.startAnchor
                let anchorPoint = CGPoint(
                    x: canvasFrame.width * anchor.x,
                    y: canvasFrame.height * anchor.y
                )
                viewModel.applyMagnification(scale, anchor: anchorPoint)
            }
            .onEnded { _ in
                lastMagnification = 1.0
            }
    }
    
    // MARK: - Scroll Wheel Monitor 
    
    private func installEventMonitors() {
        scrollMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { event in
            let windowPoint = event.locationInWindow
            guard let window = event.window else { return event }
            
            let screenPoint = window.convertPoint(toScreen: windowPoint)
            let globalPoint = CGPoint(x: screenPoint.x, y: NSScreen.main!.frame.height - screenPoint.y)
            
            guard canvasFrame.contains(globalPoint) else { return event }
            
            if event.modifierFlags.contains(.command) {
                let zoomDelta = -event.scrollingDeltaY
                let localPoint = CGPoint(
                    x: globalPoint.x - canvasFrame.minX,
                    y: globalPoint.y - canvasFrame.minY
                )
                viewModel.applyScrollZoom(zoomDelta, at: localPoint)
                return nil
            } else {
                let dx = event.scrollingDeltaX
                let dy = event.scrollingDeltaY
                viewModel.applyScrollPan(CGSize(width: dx, height: dy))
                return nil
            }
        }
        
        rightClickMonitor = NSEvent.addLocalMonitorForEvents(matching: .rightMouseDown) { event in
            let windowPoint = event.locationInWindow
            guard let window = event.window else { return event }
            
            let screenPoint = window.convertPoint(toScreen: windowPoint)
            let globalPoint = CGPoint(x: screenPoint.x, y: NSScreen.main!.frame.height - screenPoint.y)
            
            guard canvasFrame.contains(globalPoint) else { return event }
            
            let localPoint = CGPoint(
                x: globalPoint.x - canvasFrame.minX,
                y: globalPoint.y - canvasFrame.minY
            )
            let canvasLocation = convertToCanvasLocation(localPoint)
            
            if let state = findStateAt(canvasLocation) {
                selectedStates = [state.id]
                selectedTransitions = []
                showContextMenu(for: .state(state), event: event)
            } else if let transition = findTransitionAt(canvasLocation) {
                selectedStates = []
                selectedTransitions = [transition.id]
                showContextMenu(for: .transition(transition), event: event)
            } else {
                selectedStates = []
                selectedTransitions = []
                showContextMenu(for: .canvas(canvasLocation), event: event)
            }
            
            return nil // consume the event
        }
    }
    
    private func removeEventMonitors() {
        if let monitor = scrollMonitor {
            NSEvent.removeMonitor(monitor)
            scrollMonitor = nil
        }
        if let monitor = rightClickMonitor {
            NSEvent.removeMonitor(monitor)
            rightClickMonitor = nil
        }
    }
    
    // MARK: - Native Context Menu
    
    private enum ContextMenuTarget {
        case state(AutomatonState)
        case transition(Transition)
        case canvas(CGPoint)
    }
    
    private func showContextMenu(for target: ContextMenuTarget, event: NSEvent) {
        let builder = ContextMenuBuilder()
        
        switch target {
        case .state(let state):
            builder.addItem("Edit State", icon: "pencil") {
                self.onRenameState?(state.id)
            }
            
            builder.addSeparator()
            
            builder.addItem(
                state.isStart ? "Remove Start" : "Set as Start",
                icon: "play.fill"
            ) {
                var updated = state
                if !state.isStart {
                    for var s in self.automaton.states where s.isStart {
                        s.isStart = false
                        self.viewModel.updateState(s)
                    }
                }
                updated.isStart.toggle()
                self.viewModel.updateState(updated)
            }
            
            builder.addItem(
                state.isAccepting ? "Remove Accepting" : "Set as Accepting",
                icon: "checkmark.circle"
            ) {
                var updated = state
                updated.isAccepting.toggle()
                self.viewModel.updateState(updated)
            }
            
            builder.addSeparator()
            
            builder.addDestructiveItem("Delete State", icon: "trash") {
                self.viewModel.removeState(state.id)
                self.selectedStates.remove(state.id)
            }
            
        case .transition(let transition):
            builder.addItem("Edit Symbols", icon: "pencil") {
                self.onEditTransition?(transition.id)
            }
            
            builder.addSeparator()
            
            builder.addDestructiveItem("Delete Transition", icon: "trash") {
                self.viewModel.removeTransition(transition.id)
                self.selectedTransitions.remove(transition.id)
            }
            
        case .canvas(let location):
            builder.addItem("Add State Here", icon: "circle.badge.plus") {
                let newState = self.viewModel.addState(at: location)
                self.selectedStates = [newState.id]
                self.selectedTransitions = []
                self.onRenameState?(newState.id)
            }
        }
        
        guard let window = event.window,
              let contentView = window.contentView else { return }
        NSMenu.popUpContextMenu(builder.menu, with: event, for: contentView)
    }
    
    // MARK: - Tap Handlers
    
    private func handleSingleTap(at location: CGPoint) {
        let canvasLocation = convertToCanvasLocation(location)
        
        switch canvasMode {
        case .select:
            if let state = findStateAt(canvasLocation) {
                selectedStates = [state.id]
                selectedTransitions = []
            } else if let transition = findTransitionAt(canvasLocation) {
                selectedStates = []
                selectedTransitions = [transition.id]
            } else {
                selectedStates = []
                selectedTransitions = []
            }
            
        case .addState:
            let newState = viewModel.addState(at: canvasLocation)
            selectedStates = [newState.id]
            selectedTransitions = []
            onRenameState?(newState.id)
            
        case .transition:
            break
        }
    }
    
    private func handleDoubleTap(at location: CGPoint) {
        let canvasLocation = convertToCanvasLocation(location)
        
        if let state = findStateAt(canvasLocation) {
            selectedStates = [state.id]
            selectedTransitions = []
            onRenameState?(state.id)
        } else if let transition = findTransitionAt(canvasLocation) {
            selectedStates = []
            selectedTransitions = [transition.id]
            onEditTransition?(transition.id)
        } else {
            let newState = viewModel.addState(at: canvasLocation)
            selectedStates = [newState.id]
            selectedTransitions = []
            onRenameState?(newState.id)
        }
    }
    
    // MARK: - Hover
    
    private func handleHover(_ phase: HoverPhase) {
        switch phase {
        case .active(let location):
            let canvasLocation = convertToCanvasLocation(location)
            if let state = findStateAt(canvasLocation) {
                if hoveredState != state.id {
                    if hoveredState != nil || hoveredTransition != nil {
                        NSCursor.pop()
                    }
                    hoveredState = state.id
                    hoveredTransition = nil
                    NSCursor.pointingHand.push()
                }
            } else if let transition = findTransitionAt(canvasLocation) {
                if hoveredTransition != transition.id {
                    if hoveredState != nil || hoveredTransition != nil {
                        NSCursor.pop()
                    }
                    hoveredTransition = transition.id
                    hoveredState = nil
                    NSCursor.pointingHand.push()
                }
            } else {
                if hoveredState != nil || hoveredTransition != nil {
                    NSCursor.pop()
                }
                hoveredState = nil
                hoveredTransition = nil
            }
        case .ended:
            if hoveredState != nil || hoveredTransition != nil {
                NSCursor.pop()
            }
            hoveredState = nil
            hoveredTransition = nil
        }
    }
    
    // MARK: - Drawing
    
    private func drawAutomaton(context: GraphicsContext, size: CGSize, date: Date) {
        for transition in automaton.transitions {
            drawTransition(transition, context: context, date: date)
        }
        
        for state in automaton.states {
            drawState(state, context: context, date: date)
        }
    }
    
    private func drawState(_ state: AutomatonState, context: GraphicsContext, date: Date) {
        let isSelected = selectedStates.contains(state.id)
        let isHovered = hoveredState == state.id
        
        // Dynamic animation duration based on playback speed
        let animationDuration = 0.5 / viewModel.playbackSpeed
        let progress = min(1.0, max(0, date.timeIntervalSince(viewModel.lastStepTime) / animationDuration))
        
        let isArrivalActive = viewModel.activeStates.contains(state.id) && (progress >= 1.0 || viewModel.simulationStep == 0)
        let isFailureActive = viewModel.isCurrentStepInvalid && viewModel.previousActiveStates.contains(state.id)
        
        let isActive = isArrivalActive || isFailureActive
        
        var simulationColor: Color = .green
        if let result = viewModel.simulationResult, !result.accepted {
            simulationColor = .red
        } else if isFailureActive {
            simulationColor = .orange
        }
        
        let stateSize: CGFloat = 40
        let stateRect = CGRect(
            x: state.position.x - stateSize/2,
            y: state.position.y - stateSize/2,
            width: stateSize,
            height: stateSize
        )
        
        let fillColor = stateColor(for: state, isActive: isActive, simulationColor: simulationColor)
        context.fill(Circle().path(in: stateRect), with: .color(fillColor))
        
        let strokeColor: Color = isSelected ? .accentColor : (isHovered ? .accentColor.opacity(0.6) : (isActive ? simulationColor : .primary))
        let lineWidth: CGFloat = isSelected ? 3 : 2
        context.stroke(Circle().path(in: stateRect), with: .color(strokeColor), lineWidth: lineWidth)
        
        if state.isStart {
            drawStartStateIndicator(at: state.position, context: context)
        }
        
        if state.isAccepting {
            drawAcceptingStateIndicator(at: state.position, context: context)
        }
        
        drawStateLabel(state, context: context)
    }
    
    private func drawTransition(_ transition: Transition, context: GraphicsContext, date: Date) {
        guard let fromState = automaton.getState(by: transition.fromStateId),
              let toState = automaton.getState(by: transition.toStateId) else { return }
        
        let isSelected = selectedTransitions.contains(transition.id)
        let isActive = viewModel.lastActiveTransitions.contains(transition.id)
        let isSelfLoop = fromState.id == toState.id
        
        let path = transitionPath(from: fromState.position, to: toState.position, isSelfLoop: isSelfLoop)
        
        // base line
        let baseColor: Color = isSelected ? .accentColor : .primary
        let lineWidth: CGFloat = isSelected ? 3 : 2
        context.stroke(path, with: .color(baseColor), lineWidth: lineWidth)
        
        // simulation fill animation
        if isActive {
            let animationDuration = 0.5 / viewModel.playbackSpeed
            let progress = min(1.0, max(0, date.timeIntervalSince(viewModel.lastStepTime) / animationDuration))
            let trimmedPath = path.trimmedPath(from: 0, to: progress)
            
            var simulationColor: Color = .green
            if let result = viewModel.simulationResult, !result.accepted {
                simulationColor = .red
            } else if viewModel.isCurrentStepInvalid {
                simulationColor = .orange
            }
            
            context.stroke(trimmedPath, with: .color(simulationColor), style: StrokeStyle(lineWidth: lineWidth + 1, lineCap: .round))
        }
        
        var simulationColor: Color = .green
        if let result = viewModel.simulationResult, !result.accepted {
            simulationColor = .red
        } else if viewModel.isCurrentStepInvalid {
            simulationColor = .orange
        }
        
        drawArrowhead(on: path, isSelfLoop: isSelfLoop, color: isActive ? simulationColor : baseColor, context: context)
        
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
        guard let fromState = automaton.getState(by: transition.fromStateId),
              let toState = automaton.getState(by: transition.toStateId) else { return }
        
        let text = Text(transition.displaySymbols)
            .font(.system(.caption2, design: .monospaced))
            .fontWeight(.medium)
        
        let labelPosition: CGPoint
        if fromState.id == toState.id {
            labelPosition = CGPoint(x: fromState.position.x, y: fromState.position.y - stateRadius - 48)
        } else {
            let midX = (fromState.position.x + toState.position.x) / 2
            let midY = (fromState.position.y + toState.position.y) / 2
            
            let dx = toState.position.x - fromState.position.x
            let dy = toState.position.y - fromState.position.y
            let length = sqrt(dx * dx + dy * dy)
            let normalX = length > 0 ? -dy / length : 0
            let normalY = length > 0 ? dx / length : -1
            
            labelPosition = CGPoint(x: midX + normalX * 12, y: midY + normalY * 12)
        }
        
        context.draw(text, at: labelPosition)
    }
    
    private func drawArrowhead(on path: Path, isSelfLoop: Bool, color: Color, context: GraphicsContext) {
        let points = extractEndpoints(from: path)
        guard let end = points.end else { return }
        
        let arrowLength: CGFloat = 10
        let arrowAngle: CGFloat = .pi / 6
        
        let angle: CGFloat
        if isSelfLoop {
            if let control = points.lastControl {
                angle = atan2(end.y - control.y, end.x - control.x)
            } else {
                angle = .pi / 4
            }
        } else {
            guard let start = points.start, start != end else { return }
            angle = atan2(end.y - start.y, end.x - start.x)
        }
        
        let tip = end
        
        let left = CGPoint(
            x: tip.x - arrowLength * cos(angle - arrowAngle),
            y: tip.y - arrowLength * sin(angle - arrowAngle)
        )
        let right = CGPoint(
            x: tip.x - arrowLength * cos(angle + arrowAngle),
            y: tip.y - arrowLength * sin(angle + arrowAngle)
        )
        
        var arrowPath = Path()
        arrowPath.move(to: tip)
        arrowPath.addLine(to: left)
        arrowPath.addLine(to: right)
        arrowPath.closeSubpath()
        
        context.fill(arrowPath, with: .color(color))
    }
    
    private func extractEndpoints(from path: Path) -> (start: CGPoint?, end: CGPoint?, lastControl: CGPoint?) {
        var start: CGPoint?
        var end: CGPoint?
        var lastControl: CGPoint?
        
        path.forEach { element in
            switch element {
            case .move(to: let point):
                if start == nil { start = point }
                end = point
                lastControl = nil
            case .line(to: let point):
                end = point
                lastControl = nil
            case .quadCurve(to: let point, control: let ctrl):
                end = point
                lastControl = ctrl
            case .curve(to: let point, control1: _, control2: let ctrl2):
                end = point
                lastControl = ctrl2
            case .closeSubpath:
                break
            }
        }
        
        return (start, end, lastControl)
    }
    
    // MARK: - Helper Methods
    
    private func stateColor(for state: AutomatonState, isActive: Bool, simulationColor: Color) -> Color {
        if isActive {
            return simulationColor.opacity(0.7)
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
    
    private let stateRadius: CGFloat = 20
    
    private func transitionPath(from start: CGPoint, to end: CGPoint, isSelfLoop: Bool) -> Path {
        var path = Path()
        
        if isSelfLoop {
            let loopHeight: CGFloat = 35
            let spread: CGFloat = 14
            
            let exitAngle: CGFloat = 2.0 * .pi / 3.0
            let enterAngle: CGFloat = .pi / 3.0
            
            let exitPoint = CGPoint(
                x: start.x + stateRadius * cos(exitAngle),
                y: start.y - stateRadius * sin(exitAngle)
            )
            let enterPoint = CGPoint(
                x: start.x + stateRadius * cos(enterAngle),
                y: start.y - stateRadius * sin(enterAngle)
            )
            
            let cp1 = CGPoint(x: exitPoint.x - spread, y: start.y - stateRadius - loopHeight)
            let cp2 = CGPoint(x: enterPoint.x + spread, y: start.y - stateRadius - loopHeight)
            
            path.move(to: exitPoint)
            path.addCurve(to: enterPoint, control1: cp1, control2: cp2)
        } else {
            let dx = end.x - start.x
            let dy = end.y - start.y
            let length = sqrt(dx * dx + dy * dy)
            guard length > 0 else { return path }
            
            let unitX = dx / length
            let unitY = dy / length
            
            let clippedStart = CGPoint(
                x: start.x + unitX * stateRadius,
                y: start.y + unitY * stateRadius
            )
            let clippedEnd = CGPoint(
                x: end.x - unitX * stateRadius,
                y: end.y - unitY * stateRadius
            )
            
            path.move(to: clippedStart)
            path.addLine(to: clippedEnd)
        }
        
        return path
    }
    
    // MARK: - Coordinate Conversion & Hit Testing
    
    private func convertToCanvasLocation(_ location: CGPoint) -> CGPoint {
        return CGPoint(
            x: (location.x - viewModel.panOffset.width) / viewModel.zoomLevel,
            y: (location.y - viewModel.panOffset.height) / viewModel.zoomLevel
        )
    }
    
    private func findStateAt(_ location: CGPoint) -> AutomatonState? {
        let tolerance: CGFloat = 25
        
        return automaton.states.first { state in
            let distance = sqrt(
                pow(state.position.x - location.x, 2) +
                pow(state.position.y - location.y, 2)
            )
            return distance <= tolerance
        }
    }
    
    private func findTransitionAt(_ location: CGPoint) -> Transition? {
        let tolerance: CGFloat = 12
        
        return automaton.transitions.first { transition in
            guard let fromState = automaton.getState(by: transition.fromStateId),
                  let toState = automaton.getState(by: transition.toStateId) else { return false }
            
            if fromState.id == toState.id {
                return distanceToSelfLoop(location, center: fromState.position) <= tolerance
            } else {
                let p1 = fromState.position
                let p2 = toState.position
                return distancePointToSegment(location, p1, p2) <= tolerance
            }
        }
    }
    
    private func distanceToSelfLoop(_ point: CGPoint, center: CGPoint) -> CGFloat {
        let loopHeight: CGFloat = 35
        let spread: CGFloat = 14
        let exitAngle: CGFloat = 2.0 * .pi / 3.0
        let enterAngle: CGFloat = .pi / 3.0
        
        let exitPoint = CGPoint(
            x: center.x + stateRadius * cos(exitAngle),
            y: center.y - stateRadius * sin(exitAngle)
        )
        let enterPoint = CGPoint(
            x: center.x + stateRadius * cos(enterAngle),
            y: center.y - stateRadius * sin(enterAngle)
        )
        let cp1 = CGPoint(x: exitPoint.x - spread, y: center.y - stateRadius - loopHeight)
        let cp2 = CGPoint(x: enterPoint.x + spread, y: center.y - stateRadius - loopHeight)
        
        var minDist: CGFloat = .greatestFiniteMagnitude
        let samples = 20
        for i in 0...samples {
            let t = CGFloat(i) / CGFloat(samples)
            let bezierPoint = cubicBezier(t: t, p0: exitPoint, p1: cp1, p2: cp2, p3: enterPoint)
            let d = distance(point, bezierPoint)
            if d < minDist { minDist = d }
        }
        return minDist
    }
    
    private func cubicBezier(t: CGFloat, p0: CGPoint, p1: CGPoint, p2: CGPoint, p3: CGPoint) -> CGPoint {
        let mt = 1.0 - t
        let mt2 = mt * mt
        let t2 = t * t
        return CGPoint(
            x: mt2 * mt * p0.x + 3 * mt2 * t * p1.x + 3 * mt * t2 * p2.x + t2 * t * p3.x,
            y: mt2 * mt * p0.y + 3 * mt2 * t * p1.y + 3 * mt * t2 * p2.y + t2 * t * p3.y
        )
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
            guard scaledGridSize > 2 else { return } // don't draw grid when too zoomed out
            
            var x: CGFloat = panOffset.width.truncatingRemainder(dividingBy: scaledGridSize)
            while x < size.width {
                context.stroke(
                    Path { path in
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: size.height))
                    },
                    with: .color(.secondary.opacity(0.15)),
                    lineWidth: 0.5
                )
                x += scaledGridSize
            }
            
            var y: CGFloat = panOffset.height.truncatingRemainder(dividingBy: scaledGridSize)
            while y < size.height {
                context.stroke(
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: size.width, y: y))
                    },
                    with: .color(.secondary.opacity(0.15)),
                    lineWidth: 0.5
                )
                y += scaledGridSize
            }
        }
    }
}

#Preview {
    CanvasView(
        automaton: Automaton(name: "Sample", type: .dfa),
        canvasMode: Binding<CanvasMode>.constant(CanvasMode.select),
        selectedStates: Binding<Set<UUID>>.constant(Set<UUID>()),
        selectedTransitions: Binding<Set<UUID>>.constant(Set<UUID>()),
        viewModel: CanvasViewModel()
    )
}
