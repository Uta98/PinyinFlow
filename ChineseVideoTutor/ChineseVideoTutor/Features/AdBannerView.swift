import GoogleMobileAds
import SwiftUI
import UIKit

@MainActor
enum AdMobRuntime {
    private static var didStart = false

    static func startIfNeeded() {
        guard didStart == false else { return }
        didStart = true
        MobileAds.shared.start()
    }
}

enum AdMobAdUnits {
    #if DEBUG
    static let banner = "ca-app-pub-3940256099942544/2934735716"
    static let interstitial = "ca-app-pub-3940256099942544/4411468910"
    static let native = "ca-app-pub-3940256099942544/3986624511"
    #else
    static let banner = "ca-app-pub-2083362073572230/5681513186"
    static let interstitial = "ca-app-pub-2083362073572230/6597316054"
    static let native = "ca-app-pub-2083362073572230/9031907705"
    #endif
}

struct InterstitialAdTriggerView: UIViewControllerRepresentable {
    let adUnitID: String
    let triggerID: UUID

    func makeUIViewController(context: Context) -> InterstitialAdViewController {
        let viewController = InterstitialAdViewController()
        viewController.adUnitID = adUnitID
        viewController.triggerID = triggerID
        return viewController
    }

    func updateUIViewController(_ viewController: InterstitialAdViewController, context: Context) {
        viewController.adUnitID = adUnitID
        viewController.updateTrigger(triggerID)
        viewController.loadAndPresentIfNeeded()
    }
}

final class InterstitialAdViewController: UIViewController, FullScreenContentDelegate {
    var adUnitID: String = ""
    var triggerID = UUID()
    private var interstitialAd: InterstitialAd?
    private var lastRequestedTriggerID: UUID?
    private var didRequestAd = false

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        loadAndPresentIfNeeded()
    }

    func updateTrigger(_ id: UUID) {
        guard triggerID != id else { return }
        triggerID = id
        didRequestAd = false
    }

    func loadAndPresentIfNeeded() {
        guard
            didRequestAd == false,
            lastRequestedTriggerID != triggerID,
            adUnitID.isEmpty == false,
            isViewLoaded
        else { return }
        didRequestAd = true
        lastRequestedTriggerID = triggerID
        AdMobRuntime.startIfNeeded()
        InterstitialAd.load(with: adUnitID, request: Request()) { [weak self] ad, error in
            guard let self else { return }
            if let error {
                print("AdMob: failed to load interstitial ad: \(error.localizedDescription)")
                return
            }
            interstitialAd = ad
            interstitialAd?.fullScreenContentDelegate = self
            presentLoadedAd()
        }
    }

    private func presentLoadedAd() {
        guard let interstitialAd else { return }
        let presenter = UIApplication.shared.topMostViewController ?? self
        interstitialAd.present(from: presenter)
    }

    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        interstitialAd = nil
    }

    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        print("AdMob: failed to present interstitial ad: \(error.localizedDescription)")
        interstitialAd = nil
    }
}

private extension UIApplication {
    var topMostViewController: UIViewController? {
        connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }?
            .rootViewController?
            .topMostPresentedViewController
    }
}

private extension UIViewController {
    var topMostPresentedViewController: UIViewController {
        if let presentedViewController {
            return presentedViewController.topMostPresentedViewController
        }
        if let navigationController = self as? UINavigationController {
            return navigationController.visibleViewController?.topMostPresentedViewController ?? navigationController
        }
        if let tabBarController = self as? UITabBarController {
            return tabBarController.selectedViewController?.topMostPresentedViewController ?? tabBarController
        }
        return self
    }
}

struct AdBannerView: UIViewControllerRepresentable {
    let adUnitID: String

    func makeUIViewController(context: Context) -> BannerViewController {
        let viewController = BannerViewController(adSize: AdSizeMediumRectangle)
        viewController.adUnitID = adUnitID
        return viewController
    }

    func updateUIViewController(_ viewController: BannerViewController, context: Context) {
        viewController.adUnitID = adUnitID
        viewController.loadAdIfNeeded()
    }
}

final class BannerViewController: UIViewController {
    var adUnitID: String = ""
    private let bannerView: BannerView
    private var didLoadAd = false

    init(adSize: AdSize) {
        bannerView = BannerView(adSize: adSize)
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear

        bannerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(bannerView)
        bannerView.delegate = self

        NSLayoutConstraint.activate([
            bannerView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            bannerView.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])

        loadAdIfNeeded()
    }

    func loadAdIfNeeded() {
        guard didLoadAd == false, adUnitID.isEmpty == false, isViewLoaded else { return }
        didLoadAd = true
        AdMobRuntime.startIfNeeded()
        bannerView.adUnitID = adUnitID
        bannerView.rootViewController = self
        bannerView.load(Request())
    }
}

struct HorizontalAdBannerView: UIViewControllerRepresentable {
    let adUnitID: String

    func makeUIViewController(context: Context) -> BannerViewController {
        let viewController = BannerViewController(adSize: AdSizeBanner)
        viewController.adUnitID = adUnitID
        return viewController
    }

    func updateUIViewController(_ viewController: BannerViewController, context: Context) {
        viewController.adUnitID = adUnitID
        viewController.loadAdIfNeeded()
    }
}

extension BannerViewController: BannerViewDelegate {
    func bannerViewDidReceiveAd(_ bannerView: BannerView) {
        print("AdMob: ad loaded successfully.")
    }

    func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
        print("AdMob: failed to load ad: \(error.localizedDescription)")
    }
}

struct NativeAdCardView: UIViewRepresentable {
    let adUnitID: String

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> PinyinFlowNativeAdView {
        let view = PinyinFlowNativeAdView()
        context.coordinator.nativeAdView = view
        context.coordinator.load(adUnitID: adUnitID, rootViewController: view.parentViewController)
        return view
    }

    func updateUIView(_ uiView: PinyinFlowNativeAdView, context: Context) {
        context.coordinator.nativeAdView = uiView
        context.coordinator.load(adUnitID: adUnitID, rootViewController: uiView.parentViewController)
    }

    final class Coordinator: NSObject, NativeAdLoaderDelegate {
        weak var nativeAdView: PinyinFlowNativeAdView?
        private var adLoader: AdLoader?
        private var loadedAdUnitID = ""

        @MainActor
        func load(adUnitID: String, rootViewController: UIViewController?) {
            guard loadedAdUnitID != adUnitID, adUnitID.isEmpty == false else { return }
            loadedAdUnitID = adUnitID
            AdMobRuntime.startIfNeeded()
            adLoader = AdLoader(
                adUnitID: adUnitID,
                rootViewController: rootViewController,
                adTypes: [.native],
                options: nil
            )
            adLoader?.delegate = self
            adLoader?.load(Request())
        }

        func adLoader(_ adLoader: AdLoader, didReceive nativeAd: NativeAd) {
            nativeAdView?.configure(with: nativeAd)
        }

        func adLoader(_ adLoader: AdLoader, didFailToReceiveAdWithError error: Error) {
            print("AdMob: failed to load native ad: \(error.localizedDescription)")
        }
    }
}

final class PinyinFlowNativeAdView: NativeAdView {
    private let media = MediaView()
    private let headlineLabel = UILabel()
    private let bodyLabel = UILabel()
    private let callToActionLabel = UILabel()
    private let advertiserLabel = UILabel()
    private let adBadgeLabel = UILabel()
    private let stack = UIStackView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(with ad: NativeAd) {
        headlineLabel.text = ad.headline
        bodyLabel.text = ad.body
        advertiserLabel.text = ad.advertiser
        callToActionLabel.text = ad.callToAction
        media.mediaContent = ad.mediaContent
        bodyLabel.isHidden = ad.body == nil
        advertiserLabel.isHidden = ad.advertiser == nil
        callToActionLabel.isHidden = ad.callToAction == nil
        ad.rootViewController = parentViewController
        nativeAd = ad
    }

    private func setup() {
        backgroundColor = .clear
        layer.cornerRadius = 14
        clipsToBounds = true

        let content = UIView()
        content.translatesAutoresizingMaskIntoConstraints = false
        content.backgroundColor = UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.16, green: 0.04, blue: 0.052, alpha: 1)
                : UIColor.white
        }
        content.layer.cornerRadius = 14
        content.clipsToBounds = true
        addSubview(content)

        media.translatesAutoresizingMaskIntoConstraints = false
        media.contentMode = .scaleAspectFill
        content.addSubview(media)

        adBadgeLabel.text = "Ad"
        adBadgeLabel.font = .systemFont(ofSize: 10, weight: .bold)
        adBadgeLabel.textColor = .white
        adBadgeLabel.textAlignment = .center
        adBadgeLabel.backgroundColor = UIColor(red: 0.56, green: 0.00, blue: 0.07, alpha: 0.86)
        adBadgeLabel.layer.cornerRadius = 6
        adBadgeLabel.clipsToBounds = true
        adBadgeLabel.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(adBadgeLabel)

        stack.axis = .vertical
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(stack)

        headlineLabel.font = .systemFont(ofSize: 15, weight: .heavy)
        headlineLabel.textColor = UIColor { traits in
            traits.userInterfaceStyle == .dark ? .white : UIColor(red: 0.12, green: 0.05, blue: 0.06, alpha: 1)
        }
        headlineLabel.numberOfLines = 2

        bodyLabel.font = .systemFont(ofSize: 12, weight: .medium)
        bodyLabel.textColor = .secondaryLabel
        bodyLabel.numberOfLines = 2

        advertiserLabel.font = .systemFont(ofSize: 11, weight: .semibold)
        advertiserLabel.textColor = .secondaryLabel
        advertiserLabel.numberOfLines = 1

        callToActionLabel.font = .systemFont(ofSize: 12, weight: .bold)
        callToActionLabel.textColor = .white
        callToActionLabel.textAlignment = .center
        callToActionLabel.backgroundColor = UIColor(red: 0.56, green: 0.00, blue: 0.07, alpha: 1)
        callToActionLabel.layer.cornerRadius = 10
        callToActionLabel.clipsToBounds = true
        callToActionLabel.isUserInteractionEnabled = false

        stack.addArrangedSubview(headlineLabel)
        stack.addArrangedSubview(bodyLabel)
        stack.addArrangedSubview(advertiserLabel)
        stack.addArrangedSubview(callToActionLabel)

        mediaView = media
        headlineView = headlineLabel
        bodyView = bodyLabel
        advertiserView = advertiserLabel
        callToActionView = callToActionLabel

        NSLayoutConstraint.activate([
            content.leadingAnchor.constraint(equalTo: leadingAnchor),
            content.trailingAnchor.constraint(equalTo: trailingAnchor),
            content.topAnchor.constraint(equalTo: topAnchor),
            content.bottomAnchor.constraint(equalTo: bottomAnchor),

            media.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            media.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            media.topAnchor.constraint(equalTo: content.topAnchor),
            media.heightAnchor.constraint(equalTo: content.heightAnchor, multiplier: 0.46),

            adBadgeLabel.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 8),
            adBadgeLabel.topAnchor.constraint(equalTo: content.topAnchor, constant: 8),
            adBadgeLabel.widthAnchor.constraint(equalToConstant: 28),
            adBadgeLabel.heightAnchor.constraint(equalToConstant: 18),

            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 10),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -10),
            stack.topAnchor.constraint(equalTo: media.bottomAnchor, constant: 10),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: content.bottomAnchor, constant: -10),
            callToActionLabel.heightAnchor.constraint(equalToConstant: 30)
        ])
    }
}

private extension UIView {
    var parentViewController: UIViewController? {
        sequence(first: self.next, next: { $0?.next })
            .first { $0 is UIViewController } as? UIViewController
    }
}
