import SwiftUI
import UIKit

/// 居中卡片呈现器：以 overFullScreen 真实 UIKit 呈现（不受键盘残留层影响），
/// 浅色遮罩可点击关闭，卡片以淡入+轻微缩放出现——无底部滑入、无整屏压暗。
struct CenterCardPresenter<Card: View>: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let onTapOutside: () -> Void
    @ViewBuilder let card: () -> Card

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIViewController(context: Context) -> AnchorViewController {
        let anchor = AnchorViewController()
        context.coordinator.anchor = anchor
        return anchor
    }

    func updateUIViewController(_ anchor: AnchorViewController, context: Context) {
        context.coordinator.parent = self
        if isPresented {
            context.coordinator.presentIfNeeded()
        } else {
            context.coordinator.dismissIfNeeded()
        }
    }

    @MainActor
    final class Coordinator {
        var parent: CenterCardPresenter
        weak var anchor: AnchorViewController?
        private(set) var cardContainer: CardContainerViewController<Card>?

        init(_ parent: CenterCardPresenter) {
            self.parent = parent
        }

        func presentIfNeeded() {
            guard cardContainer == nil, let anchor, anchor.presentedViewController == nil else { return }
            let container = CardContainerViewController(
                card: parent.card(),
                onTapOutside: { [weak self] in
                    self?.parent.onTapOutside()
                }
            )
            cardContainer = container
            anchor.present(container, animated: false)
        }

        func dismissIfNeeded() {
            guard let container = cardContainer else { return }
            cardContainer = nil
            container.dismissAnimated()
        }
    }

    /// 隐形锚点控制器，仅用于作为呈现宿主。
    final class AnchorViewController: UIViewController {
        override func viewDidLoad() {
            view.backgroundColor = .clear
            view.isUserInteractionEnabled = false
        }
    }
}

/// 容器：浅色遮罩 + 居中卡片（淡入 + 缩放入场）。
@MainActor
final class CardContainerViewController<Card: View>: UIViewController {
    private let hosting: UIHostingController<Card>
    private let dimView = UIView()
    private let onTapOutside: () -> Void
    private var appeared = false

    init(card: Card, onTapOutside: @escaping () -> Void) {
        self.hosting = UIHostingController(rootView: card)
        self.onTapOutside = onTapOutside
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .overFullScreen
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) 未实现")
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        hosting.preferredStatusBarStyle
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear

        dimView.backgroundColor = UIColor.black.withAlphaComponent(0.25)
        dimView.alpha = 0
        dimView.translatesAutoresizingMaskIntoConstraints = false
        dimView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(dimTapped)))
        view.addSubview(dimView)

        addChild(hosting)
        hosting.view.backgroundColor = .clear
        hosting.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(hosting.view)
        hosting.didMove(toParent: self)

        // 卡片居中、宽取 min(320, 视图宽 − 48)、高依内容自适应且不超出视图高 − 120；
        // 高优先级 =320 让宽度在空间充足时取上限、不足时被 required 上限压到自适应
        let widthPreferred = hosting.view.widthAnchor.constraint(equalToConstant: 320)
        widthPreferred.priority = UILayoutPriority(999)
        NSLayoutConstraint.activate([
            dimView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            dimView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            dimView.topAnchor.constraint(equalTo: view.topAnchor),
            dimView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            hosting.view.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            hosting.view.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            widthPreferred,
            hosting.view.widthAnchor.constraint(lessThanOrEqualTo: view.widthAnchor, constant: -48),
            hosting.view.heightAnchor.constraint(lessThanOrEqualTo: view.heightAnchor, constant: -120),
        ])

        // 入场前状态：轻微缩小 + 透明
        hosting.view.transform = CGAffineTransform(scaleX: 0.94, y: 0.94)
        hosting.view.alpha = 0
    }

    @objc private func dimTapped() {
        onTapOutside()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !appeared else { return }
        appeared = true
        UIView.animate(withDuration: 0.22, delay: 0, options: [.curveEaseOut]) {
            self.dimView.alpha = 1
        }
        UIView.animate(
            withDuration: 0.32,
            delay: 0,
            usingSpringWithDamping: 0.85,
            initialSpringVelocity: 0.4,
            options: [.allowUserInteraction]
        ) {
            self.hosting.view.transform = .identity
            self.hosting.view.alpha = 1
        }
    }

    /// 退场动画（淡出 + 轻微缩小），完成后自行 dismiss。
    func dismissAnimated() {
        UIView.animate(
            withDuration: 0.2,
            delay: 0,
            options: [.curveEaseIn],
            animations: {
                self.dimView.alpha = 0
                self.hosting.view.transform = CGAffineTransform(scaleX: 0.96, y: 0.96)
                self.hosting.view.alpha = 0
            },
            completion: { _ in
                self.dismiss(animated: false)
            }
        )
    }
}
