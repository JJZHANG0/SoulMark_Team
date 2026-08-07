import SwiftUI
import UIKit

struct GlobalKeyboardDismissalInstaller: UIViewControllerRepresentable {
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIViewController(context: Context) -> InstallerViewController {
        let controller = InstallerViewController()
        controller.onDidAppear = { [weak coordinator = context.coordinator] window in
            coordinator?.install(on: window)
        }
        return controller
    }

    func updateUIViewController(
        _ uiViewController: InstallerViewController,
        context: Context
    ) {
        if let window = uiViewController.viewIfLoaded?.window {
            context.coordinator.install(on: window)
        }
    }

    static func dismantleUIViewController(
        _ uiViewController: InstallerViewController,
        coordinator: Coordinator
    ) {
        coordinator.uninstall()
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        private weak var installedWindow: UIWindow?
        private lazy var tapRecognizer: UITapGestureRecognizer = {
            let recognizer = UITapGestureRecognizer(
                target: self,
                action: #selector(didTapOutsideInput)
            )
            recognizer.cancelsTouchesInView = false
            recognizer.delegate = self
            return recognizer
        }()

        func install(on window: UIWindow) {
            guard installedWindow !== window else { return }
            uninstall()
            window.addGestureRecognizer(tapRecognizer)
            installedWindow = window
        }

        func uninstall() {
            installedWindow?.removeGestureRecognizer(tapRecognizer)
            installedWindow = nil
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldReceive touch: UITouch
        ) -> Bool {
            var view = touch.view
            while let current = view {
                if current is UITextField || current is UITextView {
                    return false
                }
                view = current.superview
            }
            return true
        }

        @objc private func didTapOutsideInput() {
            installedWindow?.endEditing(true)
        }
    }
}

final class InstallerViewController: UIViewController {
    var onDidAppear: ((UIWindow) -> Void)?

    override func loadView() {
        let view = UIView(frame: .zero)
        view.backgroundColor = .clear
        self.view = view
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if let window = view.window {
            onDidAppear?(window)
        }
    }
}
