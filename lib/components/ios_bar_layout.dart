import 'dart:async';
import 'dart:math' as math;

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// UIKit's suggested frame for a horizontal toolbar, in window coordinates.
class IosBarLayout {
  const IosBarLayout({
    required this.size,
    required this.topInset,
    this.toolbar,
    this.division,
  });

  factory IosBarLayout.fromEvent(dynamic event) {
    Rect? rect(dynamic frame) => frame == null
        ? null
        : Rect.fromLTWH(
            (frame[0] as num).toDouble(),
            (frame[1] as num).toDouble(),
            (frame[2] as num).toDouble(),
            (frame[3] as num).toDouble(),
          );
    return IosBarLayout(
      size: Size(
        (event['width'] as num).toDouble(),
        (event['height'] as num).toDouble(),
      ),
      topInset: (event['topInset'] as num).toDouble(),
      division: rect(event['division']),
      toolbar: rect(event['toolbar']),
    );
  }

  final Size size;
  final double topInset;
  final Rect? toolbar;

  /// The active vertical fold region reported by UIKit, if it divides the view.
  final Rect? division;
}

class IosBarLayoutProvider extends StatefulWidget {
  const IosBarLayoutProvider({super.key, required this.child});
  final Widget child;

  @override
  State<IosBarLayoutProvider> createState() => _IosBarLayoutProviderState();
}

class _IosBarLayoutProviderState extends State<IosBarLayoutProvider> {
  static const _channel = EventChannel(
    'me.hyliu.fluent_reader_lite/ios_bar_layout',
  );
  StreamSubscription<dynamic>? _subscription;
  IosBarLayout? _layout;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      _subscription = _channel.receiveBroadcastStream().listen(
        (event) {
          setState(() => _layout = IosBarLayout.fromEvent(event));
        },
        onError: (Object error) {
          // Older hosts and tests can keep using the standard safe-area layout.
          if (mounted) setState(() => _layout = null);
        },
      );
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IosBarLayoutScope(
    layout: _layout,
    bounds: Offset.zero & MediaQuery.sizeOf(context),
    child: widget.child,
  );
}

/// A pane's bounds in UIKit window coordinates. Keeping this explicit avoids
/// guessing global positions during layout or applying the cutout to both panes.
class IosBarLayoutScope extends InheritedWidget {
  const IosBarLayoutScope({
    super.key,
    required this.layout,
    required this.bounds,
    required super.child,
  });
  final IosBarLayout? layout;
  final Rect bounds;

  static IosBarLayoutScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<IosBarLayoutScope>();

  static Widget pane(
    BuildContext context, {
    required Rect bounds,
    required Widget child,
  }) => IosBarLayoutScope(
    layout: maybeOf(context)?.layout,
    bounds: bounds,
    child: child,
  );

  /// Null also covers stale geometry during a fold/rotation and inset-consuming
  /// modal sheets. Wait for matching window metrics before sharing the row.
  IosNavigationRow? row(BuildContext context) {
    final data = layout;
    if (data == null || defaultTargetPlatform != TargetPlatform.iOS)
      return null;
    final media = MediaQuery.of(context);
    if (media.size != data.size ||
        (media.padding.top - data.topInset).abs() > 1 ||
        bounds.top != 0) {
      return null;
    }
    final toolbar = data.toolbar;
    // UIKit places a normal iPhone/iPad toolbar below the status area. On Duo
    // it fits inside that area, even when a compact Live Activity crosses the
    // screen midpoint. Expanded activities remain temporary system overlays.
    if (toolbar == null ||
        toolbar.isEmpty ||
        toolbar.height < kMinInteractiveDimensionCupertino ||
        toolbar.top < 0 ||
        toolbar.bottom > data.topInset) {
      return null;
    }
    return IosNavigationRow(
      data.topInset,
      math.max(media.padding.left, toolbar.left - bounds.left),
      math.max(media.padding.right, bounds.right - toolbar.right),
      toolbar.center.dy,
    );
  }

  @override
  bool updateShouldNotify(IosBarLayoutScope oldWidget) =>
      layout != oldWidget.layout || bounds != oldWidget.bounds;
}

class IosNavigationRow {
  const IosNavigationRow(this.height, this.left, this.right, this.centerY);
  final double height;
  final double left;
  final double right;
  final double centerY;
}
