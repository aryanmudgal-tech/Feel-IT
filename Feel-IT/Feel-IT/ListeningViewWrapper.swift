//
//  ListeningViewWrapper.swift
//  Feel-IT
//
//  Created by Aryan Mudgal on 11/9/25.
//

import SwiftUI
import UIKit

/// This struct is a bridge that allows our UIKit `ViewController`
/// to be displayed from our new SwiftUI `HomeView`.
struct ListeningViewWrapper: UIViewControllerRepresentable {
    
    func makeUIViewController(context: Context) -> ViewController {
        // Just create and return your existing ViewController
        return ViewController()
    }
    
    func updateUIViewController(_ uiViewController: ViewController, context: Context) {
        // No update logic needed
    }
}
