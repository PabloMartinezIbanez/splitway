import 'dart:async';

class RouteEditorMapRefreshScheduler {
  RouteEditorMapRefreshScheduler({required this.onRefresh});

  final Future<void> Function(int generation) onRefresh;

  int _generation = 0;
  bool _styleReady = false;
  bool _refreshInProgress = false;
  bool _refreshPending = false;
  bool _disposed = false;

  int get currentGeneration => _generation;

  bool isActiveGeneration(int generation) =>
      !_disposed && generation == _generation;

  bool isRefreshAllowed(int generation) =>
      !_disposed && _styleReady && generation == _generation;

  void markMapRecreated() {
    if (_disposed) {
      return;
    }
    _generation++;
    _styleReady = false;
  }

  void markStyleReady() {
    if (_disposed) {
      return;
    }
    _styleReady = true;
    _schedulePump();
  }

  void requestRefresh() {
    if (_disposed) {
      return;
    }
    _refreshPending = true;
    _schedulePump();
  }

  void dispose() {
    _disposed = true;
    _styleReady = false;
    _refreshPending = false;
  }

  void _schedulePump() {
    if (_disposed || _refreshInProgress || !_styleReady || !_refreshPending) {
      return;
    }
    unawaited(_pump());
  }

  Future<void> _pump() async {
    if (_disposed || _refreshInProgress || !_styleReady || !_refreshPending) {
      return;
    }

    _refreshInProgress = true;
    final generation = _generation;
    try {
      while (!_disposed &&
          _styleReady &&
          generation == _generation &&
          _refreshPending) {
        _refreshPending = false;
        await onRefresh(generation);
      }
    } finally {
      _refreshInProgress = false;
      _schedulePump();
    }
  }
}
