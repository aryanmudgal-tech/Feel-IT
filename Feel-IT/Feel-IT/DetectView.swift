//
//  DetectView.swift
//  Feel-IT
//
//  Created by Aryan Mudgal on 11/8/25.
//

import SwiftUI
import UIKit

/// This struct is a bridge that allows our old `ViewController` (from UIKit)
/// to be displayed inside our new `HomeView` (from SwiftUI).
struct DetectView: UIViewControllerRepresentable {
    
    typealias UIViewControllerType = ViewController

    /// Tells SwiftUI how to create the ViewController.
    func makeUIViewController(context: Context) -> ViewController {
        // Just create the ViewController as normal.
        return ViewController()
    }
    
    /// Used if you need to pass data from SwiftUI *to* the ViewController.
    /// We don't need it for this, so it's empty.
    func updateUIViewController(_ uiViewController: ViewController, context: Context) {
        // No-op
    }
}
