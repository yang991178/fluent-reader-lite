import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:fluent_reader_lite/components/ios_bar_layout.dart';

/// The list pane keeps the same width in the reader and its modal sheets.
double readerListPaneWidth(BuildContext context, {required bool focusMode}) {
  final size = MediaQuery.sizeOf(context);
  final layout = IosBarLayoutScope.maybeOf(context)?.layout;
  final equalSplit =
      layout?.size == size &&
      layout?.division != null &&
      size.width > size.height;
  if (equalSplit) return (size.width - 1) / 2;
  return size.width >= 1160 || focusMode ? 375 : 320;
}
