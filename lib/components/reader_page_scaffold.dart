import 'dart:math' as math;

import 'package:cupertino_ui/cupertino_ui.dart';

import 'package:flutter/rendering.dart';

import 'ios_bar_layout.dart';
import 'reader_bar.dart';

Border? _resolvedNavigationBorder(BuildContext context, Border? border) {
  if (border == null || border.runtimeType != Border) return border;
  BorderSide resolve(BorderSide side) =>
      side.copyWith(color: CupertinoDynamicColor.resolve(side.color, context));
  return Border(
    top: resolve(border.top),
    right: resolve(border.right),
    bottom: resolve(border.bottom),
    left: resolve(border.left),
  );
}

/// Retains Cupertino's keyboard, scrolling and safe-area behavior while
/// adapting navigation to UIKit's status-area and window-control frames.
class ReaderPageScaffold extends StatelessWidget {
  const ReaderPageScaffold({
    super.key,
    this.navigationBar,
    this.backgroundColor,
    this.resizeToAvoidBottomInset = true,
    this.keepMiddle = false,
    this.underlapNavigationBar = false,
    required this.child,
  });

  final CupertinoNavigationBar? navigationBar;
  final Color? backgroundColor;
  final bool resizeToAvoidBottomInset;
  // Interactive content, such as the reader's view selector, is not a title.
  final bool keepMiddle;

  /// Paint below the header while retaining the original body layout bounds.
  final bool underlapNavigationBar;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final row = IosBarLayoutScope.maybeOf(context)?.row(context);
    if (navigationBar == null) {
      return CupertinoPageScaffold(
        backgroundColor: backgroundColor,
        resizeToAvoidBottomInset: resizeToAvoidBottomInset,
        child: child,
      );
    }
    // Keep the body at the same keyed position across fold/rotation changes.
    // The header measures its center in the same layout pass as the body, so an
    // overflowing selector can add a row without clipping or a deferred resize.
    final underlap = underlapNavigationBar && readerBarBlurEnabled;
    final keyboard = resizeToAvoidBottomInset
        ? MediaQuery.viewInsetsOf(context).bottom
        : 0.0;
    return LayoutBuilder(
      builder: (context, pageConstraints) => MediaQuery(
        data: MediaQuery.of(context).removePadding(removeTop: row != null),
        child: CupertinoPageScaffold(
          navigationBar: row == null
              ? (underlap
                    ? _ObstructingNavigationBar(navigationBar!)
                    : navigationBar)
              : null,
          backgroundColor: backgroundColor,
          resizeToAvoidBottomInset: resizeToAvoidBottomInset,
          child: Column(
            // Paint the header last so the body's upward underlap stays behind it.
            verticalDirection: VerticalDirection.up,
            children: [
              Expanded(
                key: const ValueKey('reader-body'),
                child: Semantics(
                  sortKey: row == null ? null : const OrdinalSortKey(1),
                  child: LayoutBuilder(
                    builder: (context, bodyConstraints) {
                      final top = underlap
                          ? math.max(
                              0.0,
                              pageConstraints.maxHeight -
                                  keyboard -
                                  bodyConstraints.maxHeight,
                            )
                          : 0.0;
                      return ReaderBarUnderlap(
                        insets: EdgeInsets.only(top: top),
                        child: child,
                      );
                    },
                  ),
                ),
              ),
              if (row != null)
                MediaQuery.withNoTextScaling(
                  child: Semantics(
                    sortKey: const OrdinalSortKey(0),
                    child: _CornerNavigationBar(
                      navigationBar: navigationBar!,
                      row: row,
                      keepMiddle: keepMiddle,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// Retain the scaffold's original body bounds while drawing a translucent bar.
class _ObstructingNavigationBar extends StatelessWidget
    implements ObstructingPreferredSizeWidget {
  const _ObstructingNavigationBar(this.bar);
  final CupertinoNavigationBar bar;
  @override
  Size get preferredSize => bar.preferredSize;
  @override
  bool shouldFullyObstruct(BuildContext context) => true;
  @override
  Widget build(BuildContext context) => bar;
}

/// Keeps the expanding large title below Duo's shared status/navigation row.
class ReaderSliverNavigationBar extends StatelessWidget {
  const ReaderSliverNavigationBar(this.navigationBar, {super.key});
  final CupertinoSliverNavigationBar navigationBar;

  double persistentHeight(BuildContext context) =>
      IosBarLayoutScope.maybeOf(context)?.row(context)?.height ??
      MediaQuery.paddingOf(context).top + kMinInteractiveDimensionCupertino;

  @override
  Widget build(BuildContext context) {
    final row = IosBarLayoutScope.maybeOf(context)?.row(context);
    if (row == null) return navigationBar;
    return SliverPersistentHeader(
      pinned: true,
      delegate: _CornerHeaderDelegate(
        navigationBar,
        row,
        MediaQuery.textScalerOf(context)
            .clamp(minScaleFactor: 1, maxScaleFactor: 1.235),
      ),
    );
  }
}

class _CornerHeaderDelegate extends SliverPersistentHeaderDelegate {
  _CornerHeaderDelegate(this.bar, this.row, this.textScaler);
  final CupertinoSliverNavigationBar bar;
  final IosNavigationRow row;
  final TextScaler textScaler;
  double get largeTitleHeight => textScaler.scale(52);
  @override
  double get minExtent => row.height;
  @override
  double get maxExtent => minExtent + largeTitleHeight;
  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final showLargeTitle = shrinkOffset < largeTitleHeight - 10;
    final color =
        CupertinoDynamicColor.maybeResolve(bar.backgroundColor, context) ??
        CupertinoTheme.of(context).barBackgroundColor;
    // Match Cupertino's scroll-under divider: reveal it over the first ten
    // points after the large-title area has fully collapsed.
    final borderProgress = ((shrinkOffset - largeTitleHeight) / 10).clamp(
      0.0,
      1.0,
    );
    return ClipRect(
      child: ReaderBarBackground(
        color: color,
        border: Border.lerp(
          null,
          _resolvedNavigationBorder(context, bar.border),
          borderProgress,
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              top: row.height,
              child: ClipRect(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      top: -shrinkOffset,
                      left: 0,
                      right: 0,
                      height: largeTitleHeight,
                      child: Padding(
                        padding: const EdgeInsetsDirectional.only(
                          start: 16,
                          end: 16,
                          bottom: 8,
                        ),
                        child: Align(
                          alignment: AlignmentDirectional.bottomStart,
                          child: IgnorePointer(
                            ignoring: !showLargeTitle,
                            child: AnimatedOpacity(
                              opacity: showLargeTitle ? 1 : 0,
                              duration: const Duration(milliseconds: 150),
                              child: Semantics(
                                header: true,
                                child: MediaQuery.withClampedTextScaling(
                                  minScaleFactor: 1,
                                  maxScaleFactor: 1.235,
                                  child: DefaultTextStyle(
                                    style: CupertinoTheme.of(context)
                                        .textTheme
                                        .navLargeTitleTextStyle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    child: bar.largeTitle!,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: row.height,
              child: _CornerNavigationBar(
                row: row,
                navigationBar: CupertinoNavigationBar(
                  leading: bar.leading,
                  automaticallyImplyLeading: bar.automaticallyImplyLeading,
                  automaticallyImplyMiddle: false,
                  middle:
                      bar.middle ?? (showLargeTitle ? null : bar.largeTitle),
                  trailing: bar.trailing,
                  border: null,
                  backgroundColor: bar.backgroundColor,
                  brightness: bar.brightness,
                  padding: bar.padding,
                  transitionBetweenRoutes: false,
                ),
                blurBackground: false,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(_CornerHeaderDelegate oldDelegate) => true;
}

class _CornerNavigationBar extends StatelessWidget {
  const _CornerNavigationBar({
    required this.navigationBar,
    required this.row,
    this.keepMiddle = false,
    this.blurBackground = true,
  });
  final CupertinoNavigationBar navigationBar;
  final IosNavigationRow row;
  final bool keepMiddle;
  final bool blurBackground;

  @override
  Widget build(BuildContext context) {
    final bar = navigationBar;
    final color =
        CupertinoDynamicColor.maybeResolve(bar.backgroundColor, context) ??
        CupertinoTheme.of(context).barBackgroundColor;
    final route = ModalRoute.of(context);
    Widget? leading = bar.leading;
    var padding = bar.padding;
    if (leading == null &&
        bar.automaticallyImplyLeading &&
        route?.canPop == true) {
      if (route is PageRoute && route.fullscreenDialog) {
        leading = CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.of(context).maybePop(),
          child: Text(CupertinoLocalizations.of(context).cancelButtonLabel),
        );
      } else {
        leading = const CupertinoNavigationBarBackButton(previousPageTitle: '');
        padding = EdgeInsetsDirectional.only(
          end: padding?.end ?? 16,
          top: padding?.top ?? 0,
          bottom: padding?.bottom ?? 0,
        );
      }
    }
    final measurements = _ToolbarMeasurements();
    final direction = Directionality.of(context);
    final edgePadding =
        (padding ?? const EdgeInsetsDirectional.symmetric(horizontal: 16))
            .resolve(direction);
    final hasLeftAction = direction == TextDirection.ltr
        ? leading != null
        : bar.trailing != null;
    final hasRightAction = direction == TextDirection.ltr
        ? bar.trailing != null
        : leading != null;
    // The shared status toolbar includes UIKit's standard 16-point margins.
    // Replace those margins with the bar's requested padding, including the
    // smaller inset used by back buttons and trailing icon buttons.
    final toolbarRow = IosNavigationRow(
      row.height,
      math.max(
        0,
        row.left -
            (hasLeftAction
                ? (row.sharesStatusArea ? 16 : edgePadding.left)
                : 0),
      ),
      math.max(
        0,
        row.right -
            (hasRightAction
                ? (row.sharesStatusArea ? 16 : edgePadding.right)
                : 0),
      ),
      row.centerY,
    );
    return ReaderBarBackground(
      color: blurBackground ? color : CupertinoColors.transparent,
      blur: blurBackground && bar.enableBackgroundFilterBlur,
      border: blurBackground
          ? _resolvedNavigationBorder(context, bar.border)
          : null,
      child: _AdaptiveToolbar(
        row: toolbarRow,
        measurements: measurements,
        keepMiddle: keepMiddle,
        textDirection: direction,
        leadingPadding: leading == null ? 0 : padding?.start ?? 16,
        trailingPadding: bar.trailing == null ? 0 : padding?.end ?? 16,
        toolbar: MediaQuery(
          data: MediaQuery.of(context).copyWith(padding: EdgeInsets.zero),
          child: CupertinoNavigationBar(
            leading: leading == null
                ? null
                : _WidthProbe(
                    measurements: measurements,
                    leading: true,
                    child: leading,
                  ),
            automaticallyImplyLeading: false,
            automaticallyImplyMiddle: false,
            trailing: bar.trailing == null
                ? null
                : _WidthProbe(
                    measurements: measurements,
                    leading: false,
                    child: bar.trailing!,
                  ),
            border: null,
            // The full adaptive header owns the background. This inner bar
            // only lays out buttons; another tint/filter produces a solid strip.
            backgroundColor: CupertinoColors.transparent,
            automaticBackgroundVisibility: false,
            enableBackgroundFilterBlur: false,
            brightness:
                bar.brightness ??
                (color.computeLuminance() < 0.179
                    ? Brightness.dark
                    : Brightness.light),
            padding: padding,
            transitionBetweenRoutes: false,
          ),
        ),
        middle: DefaultTextStyle(
          style: CupertinoTheme.of(context).textTheme.navTitleTextStyle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          child: Semantics(
            header: !keepMiddle,
            child: bar.middle ?? const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }
}

class _ToolbarMeasurements {
  RenderBox? leading;
  RenderBox? trailing;

  double width(RenderBox? slot, double availableWidth) =>
      slot
          ?.getDryLayout(
            BoxConstraints(
              maxWidth: availableWidth,
              minHeight: 44,
              maxHeight: 44,
            ),
          )
          .width ??
      0;
}

class _WidthProbe extends SingleChildRenderObjectWidget {
  const _WidthProbe({
    required this.measurements,
    required this.leading,
    required super.child,
  });
  final _ToolbarMeasurements measurements;
  final bool leading;

  void _bind(RenderProxyBox renderObject) {
    if (leading) {
      measurements.leading = renderObject;
    } else {
      measurements.trailing = renderObject;
    }
  }

  @override
  RenderProxyBox createRenderObject(BuildContext context) {
    final renderObject = RenderProxyBox();
    _bind(renderObject);
    return renderObject;
  }

  @override
  void updateRenderObject(BuildContext context, RenderProxyBox renderObject) =>
      _bind(renderObject);
}

/// The stock Cupertino bar still lays out and styles the edge buttons. The
/// center is measured separately so it can move below the shared status row.
class _AdaptiveToolbar extends MultiChildRenderObjectWidget {
  _AdaptiveToolbar({
    required this.row,
    required this.measurements,
    required this.keepMiddle,
    required this.textDirection,
    required this.leadingPadding,
    required this.trailingPadding,
    required Widget toolbar,
    required Widget middle,
  }) : super(children: [toolbar, middle]);
  final IosNavigationRow row;
  final _ToolbarMeasurements measurements;
  final bool keepMiddle;
  final TextDirection textDirection;
  final double leadingPadding, trailingPadding;
  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderAdaptiveToolbar(this);
  @override
  void updateRenderObject(
    BuildContext context,
    covariant _RenderAdaptiveToolbar renderObject,
  ) {
    renderObject.configuration = this;
    renderObject.markNeedsLayout();
  }
}

class _ToolbarParentData extends ContainerBoxParentData<RenderBox> {}

class _RenderAdaptiveToolbar extends RenderBox
    with ContainerRenderObjectMixin<RenderBox, _ToolbarParentData> {
  _RenderAdaptiveToolbar(this.configuration);
  _AdaptiveToolbar configuration;
  bool _showMiddle = true;

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _ToolbarParentData) {
      child.parentData = _ToolbarParentData();
    }
  }

  @override
  void performLayout() {
    final config = configuration;
    final row = config.row;
    final width = constraints.maxWidth;
    var toolbarWidth = math.max(0.0, width - row.left - row.right);
    var toolbarLeft = row.left;
    var toolbarCenterY = row.centerY;
    var height = row.height;
    final toolbar = firstChild!, middle = lastChild!;
    toolbar.layout(
      BoxConstraints.tightFor(width: toolbarWidth, height: 44),
      parentUsesSize: true,
    );
    final naturalMiddle = middle.getDryLayout(
      const BoxConstraints(maxHeight: 44),
    );
    // Read the mounted slots even when the stock bar reuses its cached layout.
    // Resetting numbers in a layout callback leaves them zero on fold updates
    // whose button constraints did not change.
    final leading =
        config.measurements.width(config.measurements.leading, width) +
        config.leadingPadding;
    final trailing =
        config.measurements.width(config.measurements.trailing, width) +
        config.trailingPadding;
    // A Live Activity can leave too little of the shared row for both edge
    // buttons. Move the toolbar below it so the buttons never overlap.
    if (config.keepMiddle && leading + trailing > toolbarWidth) {
      toolbarWidth = width;
      toolbarLeft = 0;
      toolbarCenterY = row.height + 22;
      height += 44;
      toolbar.layout(
        BoxConstraints.tightFor(width: toolbarWidth, height: 44),
        parentUsesSize: true,
      );
    }
    (toolbar.parentData as BoxParentData).offset = Offset(
      toolbarLeft,
      toolbarCenterY - 22,
    );
    final fits =
        naturalMiddle.width <=
        math.max(0.0, toolbarWidth - leading - trailing - 12);
    final overflow = !fits && config.keepMiddle;
    final showMiddle = fits || overflow;
    final visibilityChanged = _showMiddle != showMiddle;
    _showMiddle = showMiddle;
    if (visibilityChanged) markNeedsSemanticsUpdate();
    if (overflow) {
      middle.layout(
        BoxConstraints(maxWidth: math.max(0.0, width - 32), maxHeight: 44),
        parentUsesSize: true,
      );
      (middle.parentData as BoxParentData).offset = Offset(
        (width - middle.size.width) / 2,
        height + (44 - middle.size.height) / 2,
      );
      height += 44;
    } else {
      middle.layout(
        BoxConstraints(
          maxWidth: config.keepMiddle
              ? toolbarWidth
              : math.max(0.0, toolbarWidth - leading - trailing - 12),
          maxHeight: 44,
        ),
        parentUsesSize: true,
      );
      var start = (toolbarWidth - middle.size.width) / 2;
      if (start + middle.size.width > toolbarWidth - trailing) {
        start = toolbarWidth - trailing - middle.size.width - 6;
      } else if (start < leading + 6) {
        start = leading + 6;
      }
      final x = config.textDirection == TextDirection.ltr
          ? start
          : toolbarWidth - middle.size.width - start;
      (middle.parentData as BoxParentData).offset = Offset(
        toolbarLeft + x,
        toolbarCenterY - middle.size.height / 2,
      );
    }
    size = constraints.constrain(Size(width, height));
  }

  @override
  bool paintsChild(RenderBox child) => child == firstChild || _showMiddle;

  @override
  void paint(PaintingContext context, Offset offset) {
    for (final child in [firstChild!, if (_showMiddle) lastChild!]) {
      context.paintChild(
        child,
        offset + (child.parentData as BoxParentData).offset,
      );
    }
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    for (final child in [if (_showMiddle) lastChild!, firstChild!]) {
      if (result.addWithPaintOffset(
        offset: (child.parentData as BoxParentData).offset,
        position: position,
        hitTest: (result, position) =>
            child.hitTest(result, position: position),
      ))
        return true;
    }
    return false;
  }

  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) {
    visitor(firstChild!);
    if (_showMiddle) visitor(lastChild!);
  }
}
