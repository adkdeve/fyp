import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get/get.dart';
import 'package:logger/logger.dart';
import '../app/data/repositories/repository.dart';
import '../app/data/services/auth_service.dart';
import '../app/data/services/firestore_service.dart';
import '../app/data/services/safety_api_service.dart';
import '../app/data/services/websocket_service.dart';
import '../utils/helpers/easy_loading.dart';

class AppBinding extends Bindings {
  @override
  void dependencies() {
    Get.put<AuthService>(AuthService(), permanent: true);
    Get.put<FirestoreService>(FirestoreService(), permanent: true);
    Get.put<SafetyApiService>(SafetyApiService(), permanent: true);
    // Get.put<WebSocketService>(WebSocketService(), permanent: true);
    Get.put<Repository>(Repository(), permanent: true);
    Get.put<Logger>(Logger(), permanent: true);
    Get.put<MyLoading>(MyLoading(), permanent: true);
    Get.put<FlutterSecureStorage>(const FlutterSecureStorage(), permanent: true);
    // Note: AlertsController/MainController etc. MainBinding mein lazyPut hote hain
    // (MAIN route par), taake AlertsController ka Get.find<MainController>() kaam kare.
  }
}
