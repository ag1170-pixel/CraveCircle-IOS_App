//
// ==============================================================================
// CRAVECIRCLE iOS - CODE REVIEW REFERENCE
// FILE: ContentView.swift
// ==============================================================================
//
// 1. PURPOSE:
//    SwiftUI presentation component managing the ContentView user interface.
//
// 2. ARCHITECTURAL ROLE:
//    Renders UI layouts, binds to AppEnvironment state, and handles user interactions.
//
// 3. MENTOR EXPLANATION (15-Second Verbal Summary):
//    "ContentView is a SwiftUI view responsible for rendering this section of the app and communicating user actions to AppEnvironment."
//
// ==============================================================================
//

//
//  ContentView.swift
//  AICookBook
//
//  Created by Aniket Anand on 27/04/26.
//

import SwiftUI

// MARK: - SwiftUI View Component
struct ContentView: View {
    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("Hello, world!")
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
