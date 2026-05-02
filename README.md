# AutomataStudio

A native macOS app for designing and simulating finite automata. I started building this towards the end of 2025 because the simulator we used in my Theory of Computation class was ugly, archaic, and had horrible UX. So I'm building my own.

Very much a work in progress.

## What you can do with it

- Draw states on a canvas, connect them with transitions, label them with symbols
- Simulate input strings step-by-step. The transitions animate so you can see what the automaton is actually doing
- Auto-play simulations at adjustable speed, or step through manually
- Works with both DFAs and NFAs (epsilon transitions, multiple active states, the whole thing)
- Convert NFA → DFA and minimize DFAs
- Export to JFLAP (.jff), Graphviz (.dot), and SVG
- Save and load `.automata` files (they're just JSON, so you can open them in any text editor if you want)

Keyboard shortcuts: `V` for Select mode, `S` for Add State, `T` for Transition, `⌘R` to open simulation, `Delete` to remove stuff, double-click canvas to add a state, right-click for context menus.

## What doesn't work yet

- **Turing Machines**
- **PNG export**
- **Menu bar commands**

## File format

`.automata` files are plain JSON (UTI conforms to `public.json`). The schema matches whatever the `Automaton` struct serializes to: states with names and positions, transitions with symbols, alphabet, and some metadata. Nothing fancy.
