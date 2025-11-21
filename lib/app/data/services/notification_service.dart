// // ignore_for_file: avoid_print
//
// // import 'package:firebase_messaging/firebase_messaging.dart';
// import 'package:flutter_local_notifications/flutter_local_notifications.dart';
//
// class NotificationService {
//   static final _firebaseMessaging = FirebaseMessaging.instance;
//   static final _localNotifications = FlutterLocalNotificationsPlugin();
//
//   static Future<void> initialize() async {
//     // Request permission
//     await _firebaseMessaging.requestPermission();
//
//     // Get FCM token
//     final token = await _firebaseMessaging.getToken();
//     print("🔐 FCM Token: $token");
//
//     // Foreground handler
//     FirebaseMessaging.onMessage.listen((RemoteMessage message) {
//       _showLocalNotification(message);
//     });
//
//     // Background + Terminated
//     FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
//       _handleNotificationTap(message);
//     });
//
//     // Also handle when app was completely killed
//     FirebaseMessaging.instance
//         .getInitialMessage()
//         .then((RemoteMessage? message) {
//       if (message != null && message.data.isNotEmpty) {
//         _handleNotificationTap(message);
//       }
//     });
//
//     // Initialize local notifications
//    const AndroidInitializationSettings initializationSettingsAndroid =
//       AndroidInitializationSettings('@mipmap/ic_launcher');
//
//   const InitializationSettings initializationSettings = InitializationSettings(
//     android: initializationSettingsAndroid,
//   );
//
//   await _localNotifications.initialize(initializationSettings);
//   }
//
//   static void _showLocalNotification(RemoteMessage message) {
//     const androidDetails = AndroidNotificationDetails(
//       'default_channel_id',
//       'General Notifications',
//       importance: Importance.max,
//       priority: Priority.high,
//     );
//
//     const platformDetails = NotificationDetails(android: androidDetails);
//
//     _localNotifications.show(
//       message.hashCode,
//       message.notification?.title ?? 'Notification',
//       message.notification?.body ?? '',
//       platformDetails,
//       payload: message.data['route'], // optional
//     );
//   }
//
//   static void _handleNotificationTap(RemoteMessage message) {
//     // final route = message.data['route'];
//     // if (route != null) {
//     //   Get.toNamed(route);
//     // }
//   }
//
//   // static void _handleNotificationTapPayload(String payload) {
//   //   Get.toNamed(payload);
//   // }
// }
