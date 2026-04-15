import 'package:flutter/material.dart';

class MapBottomSheetScaffold extends StatelessWidget {
  const MapBottomSheetScaffold({
    required this.background,
    required this.compactChild,
    required this.expandedChildBuilder,
    this.initialChildSize = 0.24,
    this.maxChildSize = 0.9,
    super.key,
  }) : assert(initialChildSize > 0 && initialChildSize < 1),
       assert(maxChildSize > initialChildSize && maxChildSize <= 1);

  static const dragHandleKey = Key('map-bottom-sheet-drag-handle');

  final Widget background;
  final Widget compactChild;
  final Widget Function(ScrollController scrollController) expandedChildBuilder;
  final double initialChildSize;
  final double maxChildSize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(child: background),
        Positioned.fill(
          child: DraggableScrollableSheet(
            initialChildSize: initialChildSize,
            minChildSize: initialChildSize,
            maxChildSize: maxChildSize,
            snap: true,
            snapSizes: [initialChildSize, maxChildSize],
            builder: (context, scrollController) {
              return DecoratedBox(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(28),
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x26000000),
                      blurRadius: 24,
                      offset: Offset(0, -8),
                    ),
                  ],
                ),
                child: SafeArea(
                  top: false,
                  child: Column(
                    children: [
                      const SizedBox(height: 8),
                      Container(
                        key: dragHandleKey,
                        width: 48,
                        height: 5,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.outlineVariant,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                        child: compactChild,
                      ),
                      const Divider(height: 1),
                      Expanded(child: expandedChildBuilder(scrollController)),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
