import SwiftUI
import UIKit

struct TwoFingerDoubleTapCapture: UIViewRepresentable {
    var onDetected: () -> Void

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = true
        let g = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handle))
        g.numberOfTapsRequired = 2
        g.numberOfTouchesRequired = 2
        g.cancelsTouchesInView = false
        g.delaysTouchesBegan = false
        view.addGestureRecognizer(g)
        return view
    }

    func updateUIView(_: UIView, context _: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onDetected: onDetected)
    }

    final class Coordinator: NSObject {
        let onDetected: () -> Void
        init(onDetected: @escaping () -> Void) {
            self.onDetected = onDetected
        }

        @objc func handle() {
            onDetected()
        }
    }
}
