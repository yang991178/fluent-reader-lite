import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
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

  @available(iOS 27.1, *)
  override var preferredVerticalBarBehavior: UIVerticalBarBehavior { .disabled }

  override func viewDidLoad() {
    super.viewDidLoad()
    layoutChannel = FlutterEventChannel(
      name: "me.hyliu.fluent_reader_lite/ios_bar_layout", binaryMessenger: binaryMessenger)
    layoutChannel?.setStreamHandler(self)
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
      avoidsWindowControls = insets.left > safe.left + 1 || insets.right > safe.right + 1
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
    ]
    guard lastLayout != layout else { return }
    lastLayout = layout
    sink(layout)
  }
}
