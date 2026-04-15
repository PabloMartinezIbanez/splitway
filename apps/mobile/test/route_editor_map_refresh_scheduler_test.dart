import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:splitway_mobile/src/features/editor/widgets/route_editor_map_refresh_scheduler.dart';

void main() {
  group('RouteEditorMapRefreshScheduler', () {
    test('queues refreshes until the map style is ready', () async {
      var refreshCalls = 0;
      final scheduler = RouteEditorMapRefreshScheduler(
        onRefresh: (_) async {
          refreshCalls++;
        },
      );

      scheduler.requestRefresh();
      await Future<void>.delayed(Duration.zero);

      expect(refreshCalls, 0);

      scheduler.markStyleReady();
      await Future<void>.delayed(Duration.zero);

      expect(refreshCalls, 1);
    });

    test(
      'runs one more pass when a new refresh is requested mid-flight',
      () async {
        final firstRefresh = Completer<void>();
        var refreshCalls = 0;
        late final RouteEditorMapRefreshScheduler scheduler;
        scheduler = RouteEditorMapRefreshScheduler(
          onRefresh: (_) async {
            refreshCalls++;
            if (refreshCalls == 1) {
              await firstRefresh.future;
            }
          },
        );

        scheduler.markStyleReady();
        scheduler.requestRefresh();
        await Future<void>.delayed(Duration.zero);

        expect(refreshCalls, 1);

        scheduler.requestRefresh();
        await Future<void>.delayed(Duration.zero);

        expect(refreshCalls, 1);

        firstRefresh.complete();
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        expect(refreshCalls, 2);
      },
    );

    test('waits for the next style load after the map is recreated', () async {
      var refreshCalls = 0;
      final scheduler = RouteEditorMapRefreshScheduler(
        onRefresh: (_) async {
          refreshCalls++;
        },
      );

      scheduler.markStyleReady();
      scheduler.requestRefresh();
      await Future<void>.delayed(Duration.zero);

      expect(refreshCalls, 1);

      scheduler.markMapRecreated();
      scheduler.requestRefresh();
      await Future<void>.delayed(Duration.zero);

      expect(refreshCalls, 1);

      scheduler.markStyleReady();
      await Future<void>.delayed(Duration.zero);

      expect(refreshCalls, 2);
    });
  });
}
