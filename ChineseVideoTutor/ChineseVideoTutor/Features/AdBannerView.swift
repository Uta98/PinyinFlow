import GoogleMobileAds
import SwiftUI
import UIKit

@MainActor
private enum AdMobRuntime {
    private static var didStart = false

    static func startIfNeeded() {
        guard didStart == false else { return }
        didStart = true
        MobileAds.shared.start()
    }
}

struct AdBannerView: UIViewControllerRepresentable {
    let adUnitID: String

    func makeUIViewController(context: Context) -> BannerViewController {
        let viewController = BannerViewController()
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
    private let bannerView = BannerView(adSize: AdSizeMediumRectangle)
    private var didLoadAd = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear

        bannerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(bannerView)

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
