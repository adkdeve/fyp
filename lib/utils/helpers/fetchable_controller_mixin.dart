import 'package:get/get.dart';

mixin FetchableController on GetxController {
  /// Child controllers should implement this to fetch data.
  /// - `force` when true must bypass any client-side caches.
  Future<void> fetchIfNeeded({bool force = false});
}
