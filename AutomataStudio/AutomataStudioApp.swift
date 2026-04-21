//
//  AutomataStudioApp.swift
//  AutomataStudio
//
//  Created by Leonardo Nápoles on 9/24/25.
//

import SwiftUI

@main
struct AutomataStudioApp: App {
    var body: some Scene {
        DocumentGroup(newDocument: AutomataDocument()) { file in
            AutomataStudioView(document: file.$document)
                .frame(minWidth: 800, minHeight: 600)
        }
        .defaultSize(width: 1200, height: 800)
    }
}
