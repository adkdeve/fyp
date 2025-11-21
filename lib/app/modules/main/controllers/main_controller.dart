import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../utils/helpers/tab_fetch_manager.dart';

class MainController extends GetxController {
  final index = 0.obs;

  // Tab fetch manager
  late final TabFetchManager _tabFetchManager;

  List<Widget> get currentView => const [];

  @override
  void onInit() {
    super.onInit();

    // Initialize tab fetch manager and register controller fetchers.
    _tabFetchManager = TabFetchManager(defaultTTL: const Duration(minutes: 5));

    // Register fetchers. Controllers can be registered lazily; check Get.isRegistered
    _tabFetchManager.registerFetcher(AppTab.home, ({bool force = false}) async {
      // if (Get.isRegistered<HomeController>()) {
      //   await Get.find<HomeController>().fetchIfNeeded(force: force);
      // }
    });

    // Listen to index changes and ask manager to maybeFetch
    ever(index, (i) async {
      final tab = AppTab.values[i];
      await _tabFetchManager.maybeFetch(tab);
    });
  }

  /// Expose method for manual refresh (e.g. pull-to-refresh in UI)
  Future<void> refreshTab(AppTab tab) async {
    await _tabFetchManager.forceFetch(tab);
  }

  /// Helper to clear caches on logout or major state changes
  void resetCaches() {
    _tabFetchManager.resetAll();
  }

}
