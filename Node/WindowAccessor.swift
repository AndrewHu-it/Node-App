import SwiftUI
import AppKit

// A public view modifier that gives you access to the underlying NSWindow.
public struct WindowAccessor: ViewModifier {
    public let callback: (NSWindow) -> Void

    // Public initializer allows external usage.
    public init(callback: @escaping (NSWindow) -> Void) {
        self.callback = callback
    }

    // The body function applies our helper view.
    public func body(content: Content) -> some View {
        content.background(WindowAccessorRepresentable(callback: callback))
    }
}

// A helper NSViewRepresentable to bridge SwiftUI with AppKit's NSWindow.
public struct WindowAccessorRepresentable: NSViewRepresentable {
    public let callback: (NSWindow) -> Void

    // Public initializer.
    public init(callback: @escaping (NSWindow) -> Void) {
        self.callback = callback
    }

    // Creates an empty NSView and asynchronously retrieves its window.
    public func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                self.callback(window)
            }
        }
        return view
    }

    // No updates are needed for this NSView.
    public func updateNSView(_ nsView: NSView, context: Context) {}
}

// Public extension on View to provide a convenient windowAccessor() modifier.
public extension View {
    func windowAccessor(callback: @escaping (NSWindow) -> Void) -> some View {
        self.modifier(WindowAccessor(callback: callback))
    }
}
