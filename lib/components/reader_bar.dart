import 'dart:ui';

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter/foundation.dart';

import 'ios_bar_layout.dart';

// Keep the underlap layout stable when the accessibility preference changes.
bool get readerBarBlurEnabled => defaultTargetPlatform == TargetPlatform.iOS;

bool readerReduceTransparency(BuildContext context) =>
    defaultTargetPlatform == TargetPlatform.iOS &&
    IosBarLayoutScope.maybeOf(context)?.layout?.reduceTransparency == true;

Color readerBarColor(BuildContext context, [Color? background]) {
  final color = CupertinoDynamicColor.resolve(
    background ?? CupertinoColors.systemBackground,
    context,
  );
  return color.withValues(
    alpha: readerBarBlurEnabled && !readerReduceTransparency(context) ? 0.8 : 1,
  );
}

/// Applies the preference to default Cupertino bars, including settings pages.
class ReaderTransparencyTheme extends StatelessWidget {
  const ReaderTransparencyTheme({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = CupertinoTheme.of(context);
    return CupertinoTheme(
      data: readerReduceTransparency(context)
          ? theme.copyWith(
              barBackgroundColor: CupertinoDynamicColor.resolve(
                theme.barBackgroundColor,
                context,
              ).withValues(alpha: 1),
            )
          : theme,
      child: child,
    );
  }
}

Border readerBarBorder(BuildContext context) => Border(
  bottom: BorderSide(
    color: CupertinoDynamicColor.resolve(CupertinoColors.separator, context),
    // Paint inside the bar instead of centering a hairline on its clipped edge.
    width: 1 / MediaQuery.devicePixelRatioOf(context),
  ),
);

/// Clips the filter to its own bar, including when it overlays a WKWebView.
class ReaderBarBackground extends StatelessWidget {
  const ReaderBarBackground({
    super.key,
    required this.color,
    required this.child,
    this.blur = true,
    this.border,
  });

  final Color color;
  final Widget child;
  final bool blur;
  final Border? border;

  @override
  Widget build(BuildContext context) {
    final reduceTransparency = readerReduceTransparency(context);
    // Transparent inner bars only arrange controls; the outer bar owns its fill.
    final background = reduceTransparency && color.a > 0
        ? color.withValues(alpha: 1)
        : color;
    return ClipRect(
      child: BackdropFilter(
        enabled: blur && !reduceTransparency && background.a < 1,
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: BoxDecoration(border: border),
          child: ColoredBox(color: background, child: child),
        ),
      ),
    );
  }
}

/// Keeps the surrounding layout and hit region fixed while allowing scrolling
/// content to paint under a bar. The child receives the covered area as padding.
class ReaderBarUnderlap extends StatelessWidget {
  const ReaderBarUnderlap({
    super.key,
    required this.insets,
    required this.child,
  });

  final EdgeInsets insets;
  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => OverflowBox(
      alignment: insets.top > 0 ? Alignment.bottomCenter : Alignment.topCenter,
      minHeight: constraints.maxHeight + insets.vertical,
      maxHeight: constraints.maxHeight + insets.vertical,
      child: MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(padding: MediaQuery.paddingOf(context) + insets),
        child: child,
      ),
    ),
  );
}

/// The list paints below the tab bar while its scrollbar stays above it.
/// The pinned header's inset applies only to the scrollbar, keeping list
/// positions, scroll range and viewport dimensions unchanged.
class ReaderListScrollbar extends StatelessWidget {
  const ReaderListScrollbar({super.key, required this.slivers, this.topInset});

  final List<Widget> slivers;

  /// Height covered by the pinned navigation bar, including the status area.
  final double? topInset;

  @override
  Widget build(BuildContext context) {
    final bottom = readerBarBlurEnabled
        ? MediaQuery.paddingOf(context).bottom
        : 0.0;
    final contentMediaQuery = MediaQuery.of(context)
        .removePadding(removeBottom: bottom > 0);
    final scrollbarMediaQuery = readerBarBlurEnabled && topInset != null
        ? contentMediaQuery.copyWith(
            padding: contentMediaQuery.padding.copyWith(top: topInset),
          )
        : contentMediaQuery;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: MediaQuery(
        data: scrollbarMediaQuery,
        child: CupertinoScrollbar(
          child: MediaQuery(
            data: contentMediaQuery,
            child: Builder(
              builder: (scrollbarContext) =>
                  NotificationListener<ScrollMetricsNotification>(
                    onNotification: (notification) {
                      if (bottom == 0 || notification.depth != 0) return false;
                      ScrollMetricsNotification(
                        metrics: _metrics(notification.metrics, bottom),
                        context: notification.context,
                      ).dispatch(scrollbarContext);
                      return true;
                    },
                    child: NotificationListener<ScrollNotification>(
                      onNotification: (notification) {
                        if (bottom == 0 || notification.depth != 0)
                          return false;
                        final metrics = _metrics(notification.metrics, bottom);
                        final origin = notification.context ?? scrollbarContext;
                        final ScrollNotification adjusted;
                        if (notification is ScrollStartNotification) {
                          adjusted = ScrollStartNotification(
                            metrics: metrics,
                            context: origin,
                            dragDetails: notification.dragDetails,
                          );
                        } else if (notification is ScrollUpdateNotification) {
                          adjusted = ScrollUpdateNotification(
                            metrics: metrics,
                            context: origin,
                            dragDetails: notification.dragDetails,
                            scrollDelta: notification.scrollDelta,
                          );
                        } else if (notification is OverscrollNotification) {
                          adjusted = OverscrollNotification(
                            metrics: metrics,
                            context: origin,
                            dragDetails: notification.dragDetails,
                            overscroll: notification.overscroll,
                            velocity: notification.velocity,
                          );
                        } else if (notification is ScrollEndNotification) {
                          adjusted = ScrollEndNotification(
                            metrics: metrics,
                            context: origin,
                            dragDetails: notification.dragDetails,
                          );
                        } else if (notification is UserScrollNotification) {
                          adjusted = UserScrollNotification(
                            metrics: metrics,
                            context: origin,
                            direction: notification.direction,
                          );
                        } else {
                          return false;
                        }
                        adjusted.dispatch(scrollbarContext);
                        return true;
                      },
                      child: ReaderBarUnderlap(
                        insets: EdgeInsets.only(bottom: bottom),
                        child: CustomScrollView(
                          slivers: [
                            ...slivers,
                            if (bottom > 0)
                              SliverToBoxAdapter(
                                child: SizedBox(height: bottom),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
            ),
          ),
        ),
      ),
    );
  }

  ScrollMetrics _metrics(ScrollMetrics metrics, double bottom) =>
      metrics.copyWith(viewportDimension: metrics.viewportDimension - bottom);
}
