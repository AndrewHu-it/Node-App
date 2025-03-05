import SwiftUI
import AppKit
import Foundation

struct WindowAccessor: ViewModifier {
    let onWindow: (NSWindow) -> Void
    
    func body(content: Content) -> some View {
        content.background(WindowAccessorView(onWindow: onWindow))
    }
}

private struct WindowAccessorView: NSViewRepresentable {
    let onWindow: (NSWindow) -> Void
    
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                onWindow(window)
            }
        }
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {}
}
