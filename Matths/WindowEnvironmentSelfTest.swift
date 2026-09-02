#if DEBUG
import SwiftUI
import UIKit

/// 실제 UIWindow 환경에서 창 폭, safe area, 소프트웨어 키보드 가림, 시스템
/// action sheet 배치를 측정한다. `SizeHarness`처럼 폭을 흉내 내지 않으며,
/// `-windowEnvironmentSelfTest`로 명시 실행한 DEBUG 빌드에서만 동작한다.
struct WindowEnvironmentSelfTestView: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> WindowEnvironmentProbeController {
        WindowEnvironmentProbeController()
    }

    func updateUIViewController(
        _ uiViewController: WindowEnvironmentProbeController,
        context: Context
    ) {}
}

@MainActor
final class WindowEnvironmentProbeController: UIViewController {
    private struct RectValue: Codable {
        let x: Double
        let y: Double
        let width: Double
        let height: Double

        init(_ rect: CGRect) {
            x = rect.origin.x
            y = rect.origin.y
            width = rect.size.width
            height = rect.size.height
        }
    }

    private struct Report: Codable {
        let schemaVersion: String
        let result: String
        let observedAt: String
        let deviceModel: String
        let osVersion: String
        let windowBounds: RectValue
        let safeAreaInsets: [String: Double]
        let horizontalSizeClass: String
        let keyboardFrame: RectValue?
        let keyboardIntersectionHeight: Double
        let actionSheetFrame: RectValue?
        let actionSheetPresentationStyle: String
        let compactWidthObserved: Bool
        let splitViewEvidenceEligible: Bool
        let checks: [String: Bool]
    }

    private let textField = UITextField()
    private var keyboardObserver: NSObjectProtocol?
    private var continuedAfterKeyboard = false
    private var keyboardFrame: CGRect?
    private var keyboardIntersectionHeight: CGFloat = 0
    private var started = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.systemBackground

        let title = UILabel()
        title.translatesAutoresizingMaskIntoConstraints = false
        title.text = "창·키보드·팝오버 진단"
        title.font = .preferredFont(forTextStyle: .title2)
        title.adjustsFontForContentSizeCategory = true

        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.placeholder = "소프트웨어 키보드 측정"
        textField.borderStyle = .roundedRect
        textField.accessibilityLabel = "진단용 답 입력"

        let note = UILabel()
        note.translatesAutoresizingMaskIntoConstraints = false
        note.numberOfLines = 0
        note.text = "실제 창 크기와 시스템 오버레이를 측정하고 Documents에 비식별 JSON을 저장합니다."
        note.font = .preferredFont(forTextStyle: .body)
        note.adjustsFontForContentSizeCategory = true

        view.addSubview(title)
        view.addSubview(textField)
        view.addSubview(note)
        NSLayoutConstraint.activate([
            title.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 28),
            title.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 24),
            title.trailingAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -24),
            textField.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 28),
            textField.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 24),
            textField.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -24),
            textField.heightAnchor.constraint(greaterThanOrEqualToConstant: 44),
            note.topAnchor.constraint(equalTo: textField.bottomAnchor, constant: 20),
            note.leadingAnchor.constraint(equalTo: textField.leadingAnchor),
            note.trailingAnchor.constraint(equalTo: textField.trailingAnchor),
        ])
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !started else { return }
        started = true
        view.layoutIfNeeded()
        observeKeyboardAndBegin()
    }

    deinit {
        if let keyboardObserver {
            NotificationCenter.default.removeObserver(keyboardObserver)
        }
    }

    private func observeKeyboardAndBegin() {
        keyboardObserver = NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardDidShowNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            MainActor.assumeIsolated {
                self?.keyboardDidShow(notification)
            }
        }
        textField.becomeFirstResponder()

        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(2))
            self?.continueAfterKeyboardObservation()
        }
    }

    private func keyboardDidShow(_ notification: Notification) {
        guard let screenFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey]
                as? CGRect,
              let window = view.window else { return }
        let frame = window.convert(screenFrame, from: nil)
        keyboardFrame = frame
        keyboardIntersectionHeight = window.bounds.intersection(frame).height
        continueAfterKeyboardObservation()
    }

    private func continueAfterKeyboardObservation() {
        guard !continuedAfterKeyboard else { return }
        continuedAfterKeyboard = true
        if let keyboardObserver {
            NotificationCenter.default.removeObserver(keyboardObserver)
            self.keyboardObserver = nil
        }
        textField.resignFirstResponder()

        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(250))
            self?.presentActionSheetProbe()
        }
    }

    private func presentActionSheetProbe() {
        let sheet = UIAlertController(
            title: "제출 확인",
            message: "시스템 확인 화면이 현재 창 안에 표시되는지 측정합니다.",
            preferredStyle: .actionSheet
        )
        sheet.addAction(UIAlertAction(title: "계속", style: .default))
        sheet.addAction(UIAlertAction(title: "취소", style: .cancel))
        if let popover = sheet.popoverPresentationController {
            popover.sourceView = textField
            popover.sourceRect = textField.bounds
            popover.permittedArrowDirections = [.up, .down]
        }
        present(sheet, animated: false) { [weak self, weak sheet] in
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(120))
                guard let self, let sheet else { return }
                self.captureAndWrite(actionSheet: sheet)
                sheet.dismiss(animated: false)
            }
        }
    }

    private func captureAndWrite(actionSheet: UIAlertController) {
        guard let window = view.window else { return }
        window.layoutIfNeeded()
        actionSheet.view.layoutIfNeeded()

        let windowBounds = window.bounds
        let sheetFrame = actionSheet.view.convert(actionSheet.view.bounds, to: window)
        let safeInsets = window.safeAreaInsets
        let horizontalClass = traitCollection.horizontalSizeClass
        let compactWidth = windowBounds.width <= 400
        let compactTrait = horizontalClass == .compact
        let sheetVisible = !sheetFrame.isNull
            && sheetFrame.width > 0
            && sheetFrame.height > 0
            && windowBounds.intersects(sheetFrame)
        let checks: [String: Bool] = [
            "windowMeasured": windowBounds.width > 0 && windowBounds.height > 0,
            "safeAreaMeasured": safeInsets.top >= 0 && safeInsets.bottom >= 0,
            "softwareKeyboardObserved": keyboardFrame != nil,
            "keyboardOccludesWindow": keyboardIntersectionHeight > 0,
            "inputRemainsAboveKeyboard": textField.frame.maxY
                < windowBounds.height - keyboardIntersectionHeight,
            "actionSheetPresented": presentedViewController === actionSheet,
            "actionSheetVisibleInWindow": sheetVisible,
        ]
        let functionalPassed = checks.values.allSatisfy { $0 }
        let report = Report(
            schemaVersion: "MATTHS_WINDOW_ENVIRONMENT_SELFTEST_V1",
            result: functionalPassed ? "PASS" : "FAIL",
            observedAt: ISO8601DateFormatter().string(from: Date()),
            deviceModel: UIDevice.current.model,
            osVersion: UIDevice.current.systemVersion,
            windowBounds: RectValue(windowBounds),
            safeAreaInsets: [
                "top": safeInsets.top,
                "left": safeInsets.left,
                "bottom": safeInsets.bottom,
                "right": safeInsets.right,
            ],
            horizontalSizeClass: compactTrait ? "compact" : "regular",
            keyboardFrame: keyboardFrame.map(RectValue.init),
            keyboardIntersectionHeight: keyboardIntersectionHeight,
            actionSheetFrame: RectValue(sheetFrame),
            actionSheetPresentationStyle: presentationStyleName(actionSheet.modalPresentationStyle),
            compactWidthObserved: compactWidth,
            splitViewEvidenceEligible: functionalPassed && compactWidth && compactTrait,
            checks: checks
        )
        write(report)
    }

    private func presentationStyleName(_ style: UIModalPresentationStyle) -> String {
        switch style {
        case .popover: return "popover"
        case .pageSheet: return "pageSheet"
        case .formSheet: return "formSheet"
        case .automatic: return "automatic"
        default: return "other-\(style.rawValue)"
        }
    }

    private func write(_ report: Report) {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(report)
            let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("window-environment-selftest.json")
            try data.write(to: url, options: .atomic)
        } catch {
            NSLog("WindowEnvironmentSelfTest report write failed: %@", String(describing: error))
        }
    }
}
#endif
