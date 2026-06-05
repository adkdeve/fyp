import 'dart:async';
import 'dart:convert';
import 'package:get/get.dart';
import 'package:logger/logger.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../../app/core/config/app_config.dart';
import 'auth_service.dart';

class WebSocketService extends GetxService {
  static const String _tag = 'WebSocketService';
  final Logger _logger = Logger();

  AuthService? _auth; // Make nullable instead of late
  WebSocketChannel? _channel;
  final _controller = StreamController<Map<String, dynamic>>.broadcast();
  bool _isConnected = false;
  bool _isConnecting = false;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;
  static const Duration _reconnectDelay = Duration(seconds: 3);

  /// GetX singleton accessor
  static WebSocketService get to => Get.find<WebSocketService>();

  /// Stream of violation events from the backend
  Stream<Map<String, dynamic>> get violationStream => _controller.stream;

  /// Connection status
  bool get isConnected => _isConnected;

  @override
  void onInit() {
    super.onInit();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      // Wait for AuthService to be available
      await Future.delayed(Duration(milliseconds: 100));

      if (Get.isRegistered<AuthService>()) {
        _auth = Get.find<AuthService>();
        _logger.i('[$_tag] AuthService found and initialized');

        // Auto-connect after auth is ready
        await connect();
      } else {
        _logger.w('[$_tag] AuthService not registered yet, will retry');
        // Retry initialization after delay
        Future.delayed(const Duration(seconds: 1), () {
          _initialize();
        });
      }
    } catch (e) {
      _logger.e('[$_tag] Initialization error: $e');
    }
  }

  /// Ensure auth is available before proceeding
  Future<bool> _ensureAuth() async {
    if (_auth != null) return true;

    // Try to get auth service
    if (Get.isRegistered<AuthService>()) {
      _auth = Get.find<AuthService>();
      return true;
    }

    // Wait and retry
    await Future.delayed(Duration(milliseconds: 500));
    if (Get.isRegistered<AuthService>()) {
      _auth = Get.find<AuthService>();
      return true;
    }

    _logger.e('[$_tag] AuthService still not available');
    return false;
  }

  /// Initialize WebSocket connection
  Future<void> connect() async {
    if (_isConnecting || _isConnected) return;

    // Ensure auth is available
    if (!await _ensureAuth()) {
      _logger.w('[$_tag] Cannot connect - AuthService not available');
      return;
    }

    _isConnecting = true;

    try {
      final token = await _auth!.getToken();
      if (token == null) {
        _logger.w('[$_tag] No token available for WebSocket connection');
        _isConnecting = false;
        return;
      }

      final wsUrl = '${AppConfig.wsBaseUrl}?token=$token';
      _logger.i('[$_tag] Connecting to WebSocket: $wsUrl');

      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      _isConnected = true;
      _reconnectAttempts = 0;
      _isConnecting = false;

      _logger.i('[$_tag] WebSocket connected successfully');

      // Listen to incoming messages
      _channel!.stream.listen(
        (message) => _handleMessage(message),
        onError: (error) => _handleError(error),
        onDone: _handleDone,
      );
    } catch (e) {
      _logger.e('[$_tag] WebSocket connection error: $e');
      _isConnected = false;
      _isConnecting = false;
      _scheduleReconnect();
    }
  }

  /// Disconnect WebSocket
  Future<void> disconnect() async {
    _logger.i('[$_tag] Disconnecting WebSocket');
    _reconnectTimer?.cancel();
    await _channel?.sink.close();
    _isConnected = false;
    _isConnecting = false;
  }

  /// Schedule automatic reconnection
  void _scheduleReconnect() {
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      _logger.w('[$_tag] Max reconnect attempts reached');
      return;
    }

    _reconnectAttempts++;
    _logger.w('[$_tag] Scheduling reconnect (attempt $_reconnectAttempts/$_maxReconnectAttempts)');

    _reconnectTimer = Timer(_reconnectDelay, () async {
      try {
        await connect();
      } catch (e) {
        _logger.e('[$_tag] Reconnect attempt failed: $e');
      }
    });
  }

  /// Handle incoming WebSocket message
  void _handleMessage(dynamic message) {
    try {
      if (message is String) {
        final json = jsonDecode(message) as Map<String, dynamic>;
        _logger.i('[$_tag] Received message: ${json['type']}');
        _controller.add(json);
      }
    } catch (e) {
      _logger.e('[$_tag] Error parsing message: $e');
    }
  }

  /// Handle WebSocket error
  void _handleError(dynamic error) {
    _logger.e('[$_tag] WebSocket error: $error');
    _isConnected = false;
    _scheduleReconnect();
  }

  /// Handle WebSocket close
  void _handleDone() {
    _logger.i('[$_tag] WebSocket connection closed');
    _isConnected = false;
    _scheduleReconnect();
  }

  /// Send message to WebSocket
  void send(Map<String, dynamic> message) {
    if (!_isConnected || _channel == null) {
      _logger.w('[$_tag] WebSocket not connected, cannot send message');
      return;
    }

    try {
      _channel!.sink.add(jsonEncode(message));
      _logger.i('[$_tag] Message sent: ${message['type']}');
    } catch (e) {
      _logger.e('[$_tag] Error sending message: $e');
    }
  }

  @override
  void onClose() {
    disconnect();
    _controller.close();
    super.onClose();
  }
}
