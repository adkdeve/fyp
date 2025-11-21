enum AppTab { home, explore, application, heart, profile }

typedef TabFetchFn = Future<void> Function({bool force});

class TabFetchManager {
  final Duration defaultTTL;
  final Map<AppTab, DateTime?> _lastFetch = {};
  final Map<AppTab, TabFetchFn> _fetchers = {};

  TabFetchManager({this.defaultTTL = const Duration(minutes: 5)});

  void registerFetcher(AppTab tab, TabFetchFn fetcher) {
    _fetchers[tab] = fetcher;
  }

  bool _shouldFetch(AppTab tab, {bool force = false}) {
    if (force) return true;
    final last = _lastFetch[tab];
    if (last == null) return true;
    return DateTime.now().difference(last) > defaultTTL;
  }

  /// Called by MainController when tab is selected.
  /// returns true if fetch was triggered.
  Future<bool> maybeFetch(AppTab tab, {bool force = false}) async {
    final fetcher = _fetchers[tab];
    if (fetcher == null) return false;
    if (!_shouldFetch(tab, force: force)) return false;
    await fetcher(force: force);
    _lastFetch[tab] = DateTime.now();
    return true;
  }

  /// Force refresh externally (e.g. pull-to-refresh)
  Future<void> forceFetch(AppTab tab) async {
    final fetcher = _fetchers[tab];
    if (fetcher == null) return;
    await fetcher(force: true);
    _lastFetch[tab] = DateTime.now();
  }

  /// Optional: reset TTL for a tab (e.g. called after user logs out)
  void resetTab(AppTab tab) => _lastFetch.remove(tab);

  void resetAll() => _lastFetch.clear();
}
