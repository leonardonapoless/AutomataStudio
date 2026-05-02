import AppKit

/// Action target that wraps a closure for use with NSMenuItem.
/// Avoids NSMenuItem subclassing issues with Swift strict concurrency.
final class MenuActionTarget: NSObject {
    let closure: () -> Void
    
    init(closure: @escaping () -> Void) {
        self.closure = closure
        super.init()
    }
    
    @objc func executeAction() {
        closure()
    }
}

final class ContextMenuBuilder {
    private var targets: [MenuActionTarget] = []
    let menu = NSMenu()
    
    func addItem(_ title: String, icon: String? = nil, action: @escaping () -> Void) {
        let target = MenuActionTarget(closure: action)
        targets.append(target)
        
        let item = NSMenuItem(title: title, action: #selector(MenuActionTarget.executeAction), keyEquivalent: "")
        item.target = target
        item.representedObject = target
        if let icon = icon {
            item.image = NSImage(systemSymbolName: icon, accessibilityDescription: title)
        }
        menu.addItem(item)
    }
    
    func addDestructiveItem(_ title: String, icon: String? = nil, action: @escaping () -> Void) {
        let target = MenuActionTarget(closure: action)
        targets.append(target)
        
        let item = NSMenuItem(title: title, action: #selector(MenuActionTarget.executeAction), keyEquivalent: "")
        item.target = target
        item.representedObject = target
        item.attributedTitle = NSAttributedString(
            string: title,
            attributes: [.foregroundColor: NSColor.systemRed]
        )
        if let icon = icon {
            item.image = NSImage(systemSymbolName: icon, accessibilityDescription: title)
        }
        menu.addItem(item)
    }
    
    func addSeparator() {
        menu.addItem(.separator())
    }
}
