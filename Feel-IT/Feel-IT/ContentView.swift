//
//  ContentView.swift
//  Feel-IT
//
//  Created by Aryan Mudgal on 11/8/25.
//

import SwiftUI
import UIKit

/// This struct wraps your existing UIKit ViewController so it can be
/// the main view in your SwiftUI App.
struct ContentView: UIViewControllerRepresentable {
    
    func makeUIViewController(context: Context) -> ViewController {
        // Create and return your main ViewController
        return ViewController()
    }
    
    func updateUIViewController(_ uiViewController: ViewController, context: Context) {
        // No updates needed
    }
}
