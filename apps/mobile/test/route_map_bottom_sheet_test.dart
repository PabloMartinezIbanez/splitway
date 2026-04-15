import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:splitway_mobile/src/shared/widgets/map_bottom_sheet_scaffold.dart';

void main() {
  testWidgets('shows compact content before sheet expansion', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MapBottomSheetScaffold(
          background: const ColoredBox(color: Colors.blue),
          compactChild: const Text('Acciones compactas'),
          expandedChildBuilder: (scrollController) => ListView(
            controller: scrollController,
            children: const [Text('Metricas expandidas')],
          ),
        ),
      ),
    );

    expect(find.byType(DraggableScrollableSheet), findsOneWidget);
    expect(find.byKey(MapBottomSheetScaffold.dragHandleKey), findsOneWidget);
    expect(find.text('Acciones compactas'), findsOneWidget);
  });
}
