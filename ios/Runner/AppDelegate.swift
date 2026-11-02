import Flutter
import UIKit
import WebKit
import webview_flutter_wkwebview

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var articleInsetsChannel: FlutterMethodChannel?
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    guard let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "ReaderArticleInsets") else {
      return
    }
    articleInsetsChannel = FlutterMethodChannel(
      name: "me.hyliu.fluent_reader_lite/article_insets", binaryMessenger: registrar.messenger())
    articleInsetsChannel?.setMethodCallHandler { call, result in
      guard call.method == "setInsets" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard let args = call.arguments as? [String: Any],
        let identifier = args["id"] as? Int64,
        let top = args["top"] as? Double, let bottom = args["bottom"] as? Double,
        let webView = FWFWebViewFlutterWKWebViewExternalAPI.webView(
          forIdentifier: identifier, withPluginRegistrar: registrar)
      else {
        result(FlutterError(code: "article_insets", message: "Missing article WebView", details: nil))
        return
      }
      // Earlier WebKit versions cannot shrink the layout viewport for bars
      // painted over the WebView using public API. Keep their original frame.
      guard #available(iOS 26.0, *) else {
        result(false)
        return
      }
      let layout = webView.subviews.compactMap { $0 as? ReaderArticleInsets }.first
        ?? ReaderArticleInsets(webView)
      layout.update(top: top, bottom: bottom)
      result(true)
    }
  }
}

/// A platform view can still have zero native bounds in Dart's post-frame
/// callback. Wait for UIKit layout before applying the initial reading offset;
/// WebKit otherwise resets it when the view first acquires its frame.
private class ReaderArticleInsets: UIView {
  private weak var webView: WKWebView?
  private var insets = UIEdgeInsets.zero
  private var pendingOffset: CGPoint?
  private var insetObservation: NSKeyValueObservation?
  private var applying = false

  init(_ webView: WKWebView) {
    self.webView = webView
    super.init(frame: webView.bounds)
    autoresizingMask = [.flexibleWidth, .flexibleHeight]
    isOpaque = false
    backgroundColor = .clear
    isUserInteractionEnabled = false
    accessibilityElementsHidden = true
    webView.addSubview(self)
    // The WebView plugin clears contentInset in its frame setter. Capture the
    // reading offset before that reset and restore our insets after layout.
    insetObservation = webView.scrollView.observe(\.contentInset, options: [.prior]) {
      [weak self] scrollView, change in
      guard let self = self, !self.applying else { return }
      if change.isPrior {
        if self.pendingOffset == nil { self.pendingOffset = scrollView.contentOffset }
      } else {
        self.scheduleApply()
      }
    }
  }

  required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

  override func layoutSubviews() {
    super.layoutSubviews()
    scheduleApply()
  }

  func update(top: Double, bottom: Double) {
    guard let scrollView = webView?.scrollView else { return }
    // Preserve the visible reading position across adaptive header changes.
    let readingY = (pendingOffset?.y ?? scrollView.contentOffset.y) + insets.top
    insets = UIEdgeInsets(top: top, left: 0, bottom: bottom, right: 0)
    pendingOffset = CGPoint(x: scrollView.contentOffset.x, y: readingY - top)
    scheduleApply()
  }

  private func scheduleApply() {
    DispatchQueue.main.async { [weak self] in self?.apply() }
  }

  private func apply() {
    guard let webView = webView, !webView.bounds.isEmpty else { return }
    let scrollView = webView.scrollView
    guard pendingOffset != nil || scrollView.contentInset != insets else { return }
    let offset = pendingOffset ?? scrollView.contentOffset
    applying = true
    webView.layoutIfNeeded()
    scrollView.contentInsetAdjustmentBehavior = .never
    scrollView.automaticallyAdjustsScrollIndicatorInsets = false
    if #available(iOS 26.0, *) {
      // Scroll insets alone add empty scroll range to a short document and do
      // not define WebKit's logical scroll origin when images finish loading.
      webView.obscuredContentInsets = insets
    }
    scrollView.contentInset = insets
    scrollView.verticalScrollIndicatorInsets = insets
    scrollView.contentOffset = offset
    pendingOffset = nil
    applying = false
  }
}

@objc(ReaderSceneDelegate)
class ReaderSceneDelegate: FlutterSceneDelegate {
  @available(iOS 26.0, *)
  override func preferredWindowingControlStyle(for scene: UIWindowScene)
    -> UIWindowScene.WindowingControlStyle {
    .minimal
  }
}

// Keep Flutter's horizontal navigation and the system status area on one axis.
// UIKit's toolbar frame accounts for camera/status UI and Live Activities.
@objc(ReaderViewController)
class ReaderViewController: FlutterViewController, FlutterStreamHandler {
  private var layoutChannel: FlutterEventChannel?
  private var layoutSink: FlutterEventSink?
  private var lastLayout: NSDictionary?
  private var transparencyObserver: NSObjectProtocol?

  @available(iOS 27.1, *)
  override var preferredVerticalBarBehavior: UIVerticalBarBehavior { .disabled }

  override func viewDidLoad() {
    super.viewDidLoad()
    layoutChannel = FlutterEventChannel(
      name: "me.hyliu.fluent_reader_lite/ios_bar_layout", binaryMessenger: binaryMessenger)
    layoutChannel?.setStreamHandler(self)
    transparencyObserver = NotificationCenter.default.addObserver(
      forName: UIAccessibility.reduceTransparencyStatusDidChangeNotification,
      object: nil, queue: .main
    ) { [weak self] _ in
      self?.publishLayout()
    }
  }

  deinit {
    if let observer = transparencyObserver {
      NotificationCenter.default.removeObserver(observer)
    }
  }

  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    publishLayout()
  }

  @available(iOS 26.0, *)
  override func updateProperties() {
    super.updateProperties()
    // Register the reserved-region reads with UIKit's observation tracking.
    // A Live Activity can change these without changing the window safe area.
    publishLayout()
  }

  override func viewSafeAreaInsetsDidChange() {
    super.viewSafeAreaInsetsDidChange()
    publishLayout()
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink)
    -> FlutterError? {
    layoutSink = events
    lastLayout = nil
    if #available(iOS 26.0, *) { setNeedsUpdateProperties() }
    publishLayout()
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    layoutSink = nil
    lastLayout = nil
    return nil
  }

  private func publishLayout() {
    guard let sink = layoutSink, isViewLoaded else { return }
    var toolbar: [CGFloat]?
    var division: [CGFloat]?
    var avoidsWindowControls = false
    if #available(iOS 26.0, *) {
      // Custom bars must adapt horizontally around iPad's window controls.
      let insets = view.edgeInsets(for: .safeArea(cornerAdaptation: .horizontal))
      let safe = view.safeAreaInsets
      avoidsWindowControls = UIDevice.current.userInterfaceIdiom == .pad &&
        (insets.left > safe.left + 1 || insets.right > safe.right + 1)
      if avoidsWindowControls {
        toolbar = [insets.left, safe.top, view.bounds.width - insets.left - insets.right, 44]
      }
    }
    if #available(iOS 27.1, *) {
      // Layout follows active reserved regions, not the raw hinge status or
      // angle. Querying in updateProperties subscribes to region changes.
      _ = view.reservedRegions(kind: .occlusion)
      if let region = view.reservedRegions(kind: .division).first(where: {
        $0.frame.height > $0.frame.width && $0.frame.midX > 0 &&
          $0.frame.midX < view.bounds.width
      }) {
        let frame = region.frame
        division = [frame.minX, frame.minY, frame.width, frame.height]
      }
      // UIKit positions a 44-point toolbar beside the status UI, including on
      // the inner display where there is no active camera cutout to align with.
      let barInsets = view.edgeInsets(for: .bar(onEdge: UIRectEdge.top, extent: 44))
      let barFrame = view.bounds.inset(by: barInsets)
      if !barFrame.isEmpty {
        toolbar = [barFrame.minX, barFrame.minY, barFrame.width, barFrame.height]
      }
    }
    let layout: NSDictionary = [
      "width": view.bounds.width, "height": view.bounds.height,
      "topInset": view.safeAreaInsets.top, "toolbar": toolbar ?? NSNull(),
      "division": division ?? NSNull(),
      "avoidsWindowControls": avoidsWindowControls,
      "reduceTransparency": UIAccessibility.isReduceTransparencyEnabled,
    ]
    guard lastLayout != layout else { return }
    lastLayout = layout
    sink(layout)
  }
}
